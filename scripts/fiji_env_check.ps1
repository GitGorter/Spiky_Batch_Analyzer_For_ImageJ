[CmdletBinding()]
param(
    [switch]$ManualOnly,
    [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$ConfigPath = Join-Path $RepoRoot "config\local_fiji_config.ps1"

function Resolve-LocalPath {
    param(
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path $RepoRoot $PathValue)
}

function Require-ConfigValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )

    $variable = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $variable -or [string]::IsNullOrWhiteSpace([string]$variable.Value) -or [string]$variable.Value -like "<*") {
        throw "Missing or placeholder config value: `$$Name"
    }
}

function Join-ProcessArguments {
    param([Parameter(Mandatory = $true)][string[]]$ArgumentList)

    $quotedArgs = $ArgumentList | ForEach-Object {
        if ($_ -match "\s|;|=") {
            '"' + $_.Replace('"', '\"') + '"'
        } else {
            $_
        }
    }
    return ($quotedArgs -join " ")
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Missing local Fiji config: $ConfigPath"
    Write-Host "Copy config\local_fiji_config.example.ps1 to config\local_fiji_config.ps1 and set local paths."
    exit 2
}

. $ConfigPath

try {
    Require-ConfigValue "FIJI_EXE"
    Require-ConfigValue "MAIN_MACRO"
} catch {
    Write-Host $_.Exception.Message
    Write-Host "Edit config\local_fiji_config.ps1 before running this check."
    exit 2
}

$ResolvedFijiExe = Resolve-LocalPath $FIJI_EXE
$ResolvedMainMacro = Resolve-LocalPath $MAIN_MACRO
$ConfiguredSpikyMacro = Get-Variable -Name "SPIKY_MACRO" -Scope Script -ErrorAction SilentlyContinue
$ResolvedConfiguredSpikyMacro = ""
if ($null -ne $ConfiguredSpikyMacro -and -not [string]::IsNullOrWhiteSpace([string]$ConfiguredSpikyMacro.Value) -and [string]$ConfiguredSpikyMacro.Value -notlike "<*") {
    $ResolvedConfiguredSpikyMacro = Resolve-LocalPath ([string]$ConfiguredSpikyMacro.Value)
}

Write-Host "Repo root: $RepoRoot"
Write-Host "Fiji executable: $ResolvedFijiExe"
Write-Host "Main macro: $ResolvedMainMacro"
if (-not [string]::IsNullOrWhiteSpace($ResolvedConfiguredSpikyMacro)) {
    Write-Host "Configured Spiky macro: $ResolvedConfiguredSpikyMacro"
}

if (-not (Test-Path -LiteralPath $ResolvedFijiExe -PathType Leaf)) {
    Write-Host "Fiji executable was not found."
    exit 3
}

if (-not (Test-Path -LiteralPath $ResolvedMainMacro -PathType Leaf)) {
    Write-Host "Main macro was not found."
    exit 3
}

$FijiRoot = Split-Path -Parent $ResolvedFijiExe
$SpikyCandidates = @(
    (Join-Path $FijiRoot "macros\toolsets\Spiky.ijm"),
    (Join-Path $FijiRoot "plugins\Spiky.ijm"),
    (Join-Path $FijiRoot "macros\Spiky.ijm")
)
$SpikyMatches = $SpikyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }

if ($SpikyMatches.Count -gt 0) {
    Write-Host "Spiky macro appears available:"
    $SpikyMatches | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Spiky macro was not found in common Fiji locations. Check the Fiji installation manually."
}

if (-not [string]::IsNullOrWhiteSpace($ResolvedConfiguredSpikyMacro)) {
    if (Test-Path -LiteralPath $ResolvedConfiguredSpikyMacro -PathType Leaf) {
        Write-Host "Configured modified Spiky macro exists."
    } else {
        Write-Host "Configured modified Spiky macro was not found: $ResolvedConfiguredSpikyMacro"
    }
}

$MacroText = Get-Content -LiteralPath $ResolvedMainMacro -Raw
$DialogDriven = $MacroText -match "Dialog\.create"
$ArgumentAware = $MacroText -match "getArgument"

if ($DialogDriven -and -not $ArgumentAware) {
    Write-Host "Main macro appears dialog-driven and not currently argument-aware."
    Write-Host "Full Phase 17 validation likely requires interactive GUI execution until a runner mode is added."
} elseif ($DialogDriven -and $ArgumentAware) {
    Write-Host "Main macro has dialogs and argument handling. Review exact non-interactive entry points before sweeps."
} else {
    Write-Host "Main macro does not appear to create an ImageJ dialog."
}

if ($ManualOnly) {
    Write-Host "ManualOnly was requested; skipping Fiji launch sanity test."
    exit 0
}

$TempDir = Join-Path $RepoRoot "validation\phase17\outputs\_env_check"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TempMacro = Join-Path $TempDir "fiji_env_check_$Stamp.ijm"
$StdOut = Join-Path $TempDir "fiji_env_check_$Stamp.out.log"
$StdErr = Join-Path $TempDir "fiji_env_check_$Stamp.err.log"

@"
print("Fiji environment check OK");
eval("script", "System.exit(0);");
"@ | Set-Content -LiteralPath $TempMacro -Encoding ASCII

Write-Host "Attempting minimal Fiji sanity launch..."
Write-Host "Temporary macro: $TempMacro"

$FijiArgs = @("--headless", "--ij2", "--run", $TempMacro)
$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName = $ResolvedFijiExe
$ProcessInfo.Arguments = Join-ProcessArguments -ArgumentList $FijiArgs
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.RedirectStandardError = $true
$Process = New-Object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo
[void]$Process.Start()

if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
    try {
        $Process.Kill()
    } catch {
        Write-Host "Fiji process did not exit and could not be killed by this script."
    }

    Write-Host "Fiji did not exit within $TimeoutSeconds seconds."
    Write-Host "Manual check: launch Fiji, then run the main macro from Plugins > Macros > Run."
    Write-Host "Stdout log: $StdOut"
    Write-Host "Stderr log: $StdErr"
    exit 0
}

$Process.StandardOutput.ReadToEnd() | Set-Content -LiteralPath $StdOut -Encoding UTF8
$Process.StandardError.ReadToEnd() | Set-Content -LiteralPath $StdErr -Encoding UTF8

Write-Host "Fiji sanity process exit code: $($Process.ExitCode)"
Write-Host "Stdout log: $StdOut"
Write-Host "Stderr log: $StdErr"

if ($Process.ExitCode -eq 0) {
    Write-Host "Minimal Fiji sanity launch completed."
    Write-Host "Next step: run .\scripts\run_phase17_tolerance_sweep.ps1 -SmokeOnly before a full sweep."
} else {
    Write-Host "Minimal Fiji sanity launch returned a non-zero exit code. Review logs and run Fiji manually if needed."
}
