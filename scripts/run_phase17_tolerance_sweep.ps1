[CmdletBinding()]
param(
    [string]$InputCsv,
    [switch]$Clean,
    [switch]$Force,
    [switch]$PrepareOnly,
    [switch]$SmokeOnly,
    [switch]$Headless,
    [string[]]$Tolerance = @("15", "10", "7.5", "5"),
    [int]$MaxSamples = 0,
    [int]$TimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"

# Fiji/ImageJ command-line syntax used here:
#   fiji-windows-x64.exe --console -macro <macro.ijm> <argument-string>
#
# The macro argument string is a semicolon-delimited key=value list consumed by
# getArgument(), for example:
#   inputCsv=C:/data/input.csv;outputDir=C:/out;runMode=Full Batch;firstTol=10;firstSmooth=-1;secondTol=15;secondSmooth=-1;maxSamples=0
#
# This macro needs Fiji's GUI runtime for CSV table loading and plot/Spiky work.
# Pass -Headless only for debugging environments where table loading is known to work.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$ConfigPath = Join-Path $RepoRoot "config\local_fiji_config.ps1"
$ToleranceValues = @()
foreach ($toleranceValue in $Tolerance) {
    $ToleranceValues += [double]$toleranceValue
}

function Resolve-LocalPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path $RepoRoot $PathValue)
}

function Require-ConfigValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $variable = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $variable -or [string]::IsNullOrWhiteSpace([string]$variable.Value) -or [string]$variable.Value -like "<*") {
        throw "Missing or placeholder config value: `$$Name"
    }
}

function Get-OptionalConfigValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $variable = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $variable -or [string]::IsNullOrWhiteSpace([string]$variable.Value) -or [string]$variable.Value -like "<*") {
        return ""
    }

    return [string]$variable.Value
}

function Get-ToleranceFolderName {
    param([double]$Value)
    return ("tolerance_" + ([string]$Value).Replace(".", "_"))
}

function Get-SafeInputSourceStem {
    param([Parameter(Mandatory = $true)][string]$InputCsvPath)

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($InputCsvPath)
    $stem = [regex]::Replace($stem, "[^A-Za-z0-9._-]+", "_").Trim('.', '_', '-')
    if ([string]::IsNullOrWhiteSpace($stem)) {
        $stem = "Input_Data"
    }
    if ($stem -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
        $stem += "_dataset"
    }
    if ($stem.Length -gt 80) {
        $stem = $stem.Substring(0, 80).Trim('.', '_', '-')
    }
    if ([string]::IsNullOrWhiteSpace($stem)) {
        $stem = "Input_Data"
    }
    return $stem
}

function Assert-SourceAwareFullBatchOutputs {
    param(
        [Parameter(Mandatory = $true)][string]$OutputFolder,
        [Parameter(Mandatory = $true)][string]$InputCsvPath,
        [Parameter(Mandatory = $true)][string]$RunMode
    )

    if ($RunMode -ne "Full Batch") {
        return
    }

    $sourceStem = Get-SafeInputSourceStem -InputCsvPath $InputCsvPath
    $requiredDataNames = @(
        "${sourceStem}_Sample_Summary_QC.csv",
        "${sourceStem}_Final_Peak_Master.csv",
        "${sourceStem}_TimeSeries_Master.csv",
        "${sourceStem}_Baseline_Correction_Master.csv",
        "${sourceStem}_Processing_Steps_Master.csv"
    )
    $requiredRootNames = @("${sourceStem}_Batch_Master_Results.xml")
    $rootFileNames = @(Get-ChildItem -LiteralPath $OutputFolder -File -ErrorAction SilentlyContinue | ForEach-Object Name)
    $dataFolder = Join-Path $OutputFolder "Data"
    $dataFileNames = @(Get-ChildItem -LiteralPath $dataFolder -File -ErrorAction SilentlyContinue | ForEach-Object Name)
    $missing = @($requiredRootNames | Where-Object {
        $rootFileNames -cnotcontains $_
    })
    $missing += @($requiredDataNames | Where-Object {
        $dataFileNames -cnotcontains $_
    } | ForEach-Object { "Data/$_" })
    $plotsFolder = Join-Path $OutputFolder "Plots"
    $plotFileNames = @(Get-ChildItem -LiteralPath $plotsFolder -File -ErrorAction SilentlyContinue | ForEach-Object Name)
    $overviewName = "${sourceStem}_Batch_Final_Peak_Analysis_Overview.png"
    if ($plotFileNames -cnotcontains $overviewName) {
        $missing += "Plots/$overviewName"
    }
    if ($missing.Count -gt 0) {
        throw "Source-aware Full Batch output validation failed. Missing: $($missing -join ', ')"
    }

    $legacyFixedNames = @(
        "Sample_Summary_QC.csv",
        "Final_Peak_Master.csv",
        "TimeSeries_Master.csv",
        "Baseline_Correction_Master.csv",
        "Processing_Steps_Master.csv",
        "Batch_Master_Results.xml"
    )
    $unexpectedLegacy = @($legacyFixedNames | Where-Object {
        ($rootFileNames -ccontains $_) -or ($dataFileNames -ccontains $_)
    })
    if ($unexpectedLegacy.Count -gt 0) {
        throw "Unexpected duplicate legacy aggregate filenames were created: $($unexpectedLegacy -join ', ')"
    }

    Write-Host "Source-aware Full Batch output contract: Verified ($sourceStem)"
}

function Convert-ToFijiPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)
    return ([System.IO.Path]::GetFullPath($PathValue)).Replace("\", "/")
}

function Quote-ValidationArg {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -match ";") {
        throw "Validation argument values cannot contain semicolons: $Value"
    }
    return $Value
}

function New-ValidationArgumentString {
    param(
        [Parameter(Mandatory = $true)][string]$InputCsvPath,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][double]$FirstTolerance,
        [Parameter(Mandatory = $true)][string]$RunMode,
        [Parameter(Mandatory = $true)][int]$MaxSamples,
        [Parameter(Mandatory = $true)][string]$ChangeKeyword
    )

    $parts = @(
        "inputCsv=$(Quote-ValidationArg (Convert-ToFijiPath $InputCsvPath))",
        "outputDir=$(Quote-ValidationArg (Convert-ToFijiPath $OutputDir))",
        "runMode=$(Quote-ValidationArg $RunMode)",
        "changeKeyword=$(Quote-ValidationArg $ChangeKeyword)",
        "batchMacro=$(Quote-ValidationArg (Convert-ToFijiPath $ResolvedMainMacro))",
        "batchMacroSha256=$ExecutedMainMacroSha256",
        "firstTol=$FirstTolerance",
        "firstSmooth=$DEFAULT_FIRST_SPIKY_SMOOTHING",
        "secondTol=$DEFAULT_SECOND_SPIKY_TOLERANCE",
        "secondSmooth=$DEFAULT_SECOND_SPIKY_SMOOTHING",
        "maxSamples=$MaxSamples"
    )

    $spikyMacro = Get-OptionalConfigValue "SPIKY_MACRO"
    if (-not [string]::IsNullOrWhiteSpace($spikyMacro)) {
        $resolvedSpikyMacro = Resolve-LocalPath $spikyMacro
        $parts += "spikyMacro=$(Quote-ValidationArg (Convert-ToFijiPath $resolvedSpikyMacro))"
    }

    return ($parts -join ";")
}

function New-FijiArgumentList {
    param(
        [Parameter(Mandatory = $true)][string]$MacroPath,
        [Parameter(Mandatory = $true)][string]$ValidationArgs
    )

    $args = @()
    if ($Headless) {
        $args += "--headless"
    }
    $args += "--console"
    $args += "-macro"
    $args += $MacroPath
    $args += $ValidationArgs
    return $args
}

function Format-CommandPreview {
    param(
        [Parameter(Mandatory = $true)][string]$ExePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList
    )

    $quotedArgs = $ArgumentList | ForEach-Object {
        if ($_ -match "\s|;|=") { '"' + $_.Replace('"', '\"') + '"' } else { $_ }
    }
    return '"' + $ExePath + '" ' + ($quotedArgs -join " ")
}

function Join-ProcessArguments {
    param([Parameter(Mandatory = $true)][string[]]$ArgumentList)

    $quotedArgs = $ArgumentList | ForEach-Object {
        if ($_ -match "\s|;|=") { '"' + $_.Replace('"', '\"') + '"' } else { $_ }
    }
    return ($quotedArgs -join " ")
}

function Assert-RunFolderPolicy {
    param([Parameter(Mandatory = $true)][string]$RunFolder)

    if ((Test-Path -LiteralPath $RunFolder) -and $Clean) {
        $resolvedRunFolder = [System.IO.Path]::GetFullPath($RunFolder)
        $resolvedOutputRoot = [System.IO.Path]::GetFullPath($ResolvedValidationOutputDir)
        if (-not $resolvedRunFolder.StartsWith($resolvedOutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean a folder outside validation output root: $resolvedRunFolder"
        }
        Remove-Item -LiteralPath $RunFolder -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $RunFolder)) {
        New-Item -ItemType Directory -Force -Path $RunFolder | Out-Null
        return
    }

    $existingEntries = @(Get-ChildItem -LiteralPath $RunFolder -Force -ErrorAction SilentlyContinue)
    if ($existingEntries.Count -gt 0 -and -not $Force) {
        Write-Host "Output folder already contains files; adding a new timestamped macro run inside it: $RunFolder"
    }
}

function Get-CompletedMacroOutputFolder {
    param(
        [Parameter(Mandatory = $true)][string]$RunFolder,
        [Parameter(Mandatory = $true)][datetime]$NotBefore
    )

    $candidateFolders = @(Get-ChildItem -LiteralPath $RunFolder -Directory -Filter "Spiky_Batch_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    foreach ($folder in $candidateFolders) {
        if ($folder.CreationTime -lt $NotBefore -and $folder.LastWriteTime -lt $NotBefore) {
            continue
        }
        $dataFolder = Join-Path $folder.FullName "Data"
        $analysisSettings = Join-Path $dataFolder "Analysis_Settings.txt"
        $methodNote = Join-Path $dataFolder "Method_Note.txt"
        $runLogs = @(Get-ChildItem -LiteralPath $folder.FullName -File -Filter "Run_Log*" -ErrorAction SilentlyContinue)
        if ((Test-Path -LiteralPath $analysisSettings -PathType Leaf) -and
            (Test-Path -LiteralPath $methodNote -PathType Leaf) -and
            $runLogs.Count -gt 0) {
            return $folder.FullName
        }
    }

    return ""
}

function Write-MacroProvenanceVerification {
    param(
        [Parameter(Mandatory = $true)][string]$OutputFolder,
        [Parameter(Mandatory = $true)][string]$ExecutedMacroPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    $copiedMacroPath = Join-Path $OutputFolder "Macro_Used_For_This_Run.ijm"
    $dataFolder = Join-Path $OutputFolder "Data"
    if (-not (Test-Path -LiteralPath $dataFolder -PathType Container)) {
        throw "Data folder was missing from completed output: $dataFolder"
    }
    $verificationPath = Join-Path $dataFolder "Macro_Provenance_Verification.txt"
    $copiedSha256 = ""
    $status = "Mismatch"
    $detail = "Copied macro file was missing."

    if (Test-Path -LiteralPath $copiedMacroPath -PathType Leaf) {
        $copiedSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $copiedMacroPath).Hash
        if ($copiedSha256 -eq $ExpectedSha256) {
            $status = "Verified"
            $detail = "Copied macro SHA256 matched the exact macro path launched by the runner."
        } else {
            $detail = "Copied macro SHA256 did not match the exact macro path launched by the runner."
        }
    }

    $verificationText = @(
        "Macro_Provenance_Status: $status",
        "Executed_Batch_Macro_Path: $ExecutedMacroPath",
        "Executed_Batch_Macro_SHA256: $ExpectedSha256",
        "Copied_Macro_Path: $copiedMacroPath",
        "Copied_Macro_SHA256: $copiedSha256",
        "Detail: $detail"
    ) -join [Environment]::NewLine
    Set-Content -LiteralPath $verificationPath -Value $verificationText -Encoding UTF8
    Write-Host "Macro provenance verification: $status"
    Write-Host "Macro provenance record: $verificationPath"
    return $status
}

function Invoke-FijiRun {
    param(
        [Parameter(Mandatory = $true)][string]$RunFolder,
        [Parameter(Mandatory = $true)][double]$FirstTolerance,
        [Parameter(Mandatory = $true)][string]$RunMode,
        [Parameter(Mandatory = $true)][int]$MaxSamples,
        [Parameter(Mandatory = $true)][string]$ChangeKeyword
    )

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $stdout = Join-Path $RunFolder "fiji_$stamp.out.log"
    $stderr = Join-Path $RunFolder "fiji_$stamp.err.log"
    $validationArgs = New-ValidationArgumentString -InputCsvPath $ResolvedInputCsv -OutputDir $RunFolder -FirstTolerance $FirstTolerance -RunMode $RunMode -MaxSamples $MaxSamples -ChangeKeyword $ChangeKeyword
    $argumentList = New-FijiArgumentList -MacroPath $ResolvedMainMacro -ValidationArgs $validationArgs
    $commandPreview = Format-CommandPreview -ExePath $ResolvedFijiExe -ArgumentList $argumentList
    $commandPath = Join-Path $RunFolder "fiji_$stamp.command.txt"

    Set-Content -LiteralPath $commandPath -Value $commandPreview -Encoding ASCII
    Write-Host "Command: $commandPreview"

    if ($PrepareOnly) {
        Write-Host "PrepareOnly: command written but not launched: $commandPath"
        return
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $ResolvedFijiExe
    $processInfo.Arguments = Join-ProcessArguments -ArgumentList $argumentList
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    [void]$process.Start()

    $completedOutputFolder = ""
    $runStartedAt = (Get-Date).AddSeconds(-2)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        $completedOutputFolder = Get-CompletedMacroOutputFolder -RunFolder $RunFolder -NotBefore $runStartedAt
        if (-not [string]::IsNullOrWhiteSpace($completedOutputFolder)) {
            Write-Host "Detected completed macro output folder: $completedOutputFolder"
            Write-Host "Stopping Fiji process after output completion."
            try {
                $process.Kill()
                [void]$process.WaitForExit(10000)
            } catch {
                Write-Host "Fiji process had already exited or could not be killed after completion."
            }
            break
        }
    }

    if (-not $process.HasExited) {
        try {
            $process.Kill()
            [void]$process.WaitForExit(10000)
        } catch {
            Write-Host "Fiji process did not exit and could not be killed by this script."
        }
        throw "Fiji did not exit within $TimeoutSeconds seconds. Logs: $stdout ; $stderr"
    }

    $process.StandardOutput.ReadToEnd() | Set-Content -LiteralPath $stdout -Encoding UTF8
    $process.StandardError.ReadToEnd() | Set-Content -LiteralPath $stderr -Encoding UTF8

    Write-Host "Fiji exit code: $($process.ExitCode)"
    Write-Host "Stdout: $stdout"
    Write-Host "Stderr: $stderr"

    if (-not [string]::IsNullOrWhiteSpace($completedOutputFolder)) {
        $provenanceStatus = Write-MacroProvenanceVerification -OutputFolder $completedOutputFolder -ExecutedMacroPath $ResolvedMainMacro -ExpectedSha256 $ExecutedMainMacroSha256
        if ($provenanceStatus -ne "Verified") {
            throw "Macro provenance verification failed for completed output folder: $completedOutputFolder"
        }
        Assert-SourceAwareFullBatchOutputs -OutputFolder $completedOutputFolder -InputCsvPath $ResolvedInputCsv -RunMode $RunMode
        Write-Host "Run completed by output detection: $completedOutputFolder"
        return
    }

    if ($process.ExitCode -ne 0) {
        throw "Fiji returned a non-zero exit code for tolerance $FirstTolerance. See logs in $RunFolder."
    }
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Missing local Fiji config: $ConfigPath"
    Write-Host "Copy config\local_fiji_config.example.ps1 to config\local_fiji_config.ps1 and set local paths."
    exit 2
}

. $ConfigPath

foreach ($requiredName in @("FIJI_EXE", "MAIN_MACRO", "TEST_DATA_DIR", "VALIDATION_OUTPUT_DIR")) {
    try {
        Require-ConfigValue $requiredName
    } catch {
        Write-Host $_.Exception.Message
        Write-Host "Edit config\local_fiji_config.ps1 before running the tolerance sweep."
        exit 2
    }
}

$ResolvedFijiExe = Resolve-LocalPath $FIJI_EXE
$ResolvedMainMacro = Resolve-LocalPath $MAIN_MACRO
$ResolvedTestDataDir = Resolve-LocalPath $TEST_DATA_DIR
$ResolvedValidationOutputDir = Resolve-LocalPath $VALIDATION_OUTPUT_DIR

if ([string]::IsNullOrWhiteSpace($InputCsv)) {
    $InputCsv = Get-OptionalConfigValue "TEST_INPUT_CSV"
}

if ([string]::IsNullOrWhiteSpace($InputCsv)) {
    $candidateCsvs = @(Get-ChildItem -LiteralPath $ResolvedTestDataDir -Filter "*.csv" -File -ErrorAction SilentlyContinue)
    if ($candidateCsvs.Count -eq 1) {
        $InputCsv = $candidateCsvs[0].FullName
    } else {
        Write-Host "No unique input CSV could be selected automatically."
        Write-Host "Pass -InputCsv <path> or set `$TEST_INPUT_CSV in config\local_fiji_config.ps1."
        exit 2
    }
}

$ResolvedInputCsv = Resolve-LocalPath $InputCsv

foreach ($pathCheck in @(
    @{ Label = "Fiji executable"; Path = $ResolvedFijiExe; Type = "Leaf" },
    @{ Label = "Main macro"; Path = $ResolvedMainMacro; Type = "Leaf" },
    @{ Label = "Test data directory"; Path = $ResolvedTestDataDir; Type = "Container" },
    @{ Label = "Input CSV"; Path = $ResolvedInputCsv; Type = "Leaf" }
)) {
    if (-not (Test-Path -LiteralPath $pathCheck.Path -PathType $pathCheck.Type)) {
        Write-Host "$($pathCheck.Label) was not found: $($pathCheck.Path)"
        exit 3
    }
}

$ExecutedMainMacroSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ResolvedMainMacro).Hash
Write-Host "Executed batch macro SHA256: $ExecutedMainMacroSha256"

New-Item -ItemType Directory -Force -Path $ResolvedValidationOutputDir | Out-Null

if ($SmokeOnly) {
    $SmokeFolder = Join-Path $ResolvedValidationOutputDir "_smoke_noninteractive"
    Assert-RunFolderPolicy -RunFolder $SmokeFolder
    Invoke-FijiRun -RunFolder $SmokeFolder -FirstTolerance 15 -RunMode "Dry Run" -MaxSamples 0 -ChangeKeyword "Phase17Smoke"
    exit 0
}

foreach ($tol in $ToleranceValues) {
    $folderName = Get-ToleranceFolderName $tol
    $runFolder = Join-Path $ResolvedValidationOutputDir $folderName
    Assert-RunFolderPolicy -RunFolder $runFolder
}

foreach ($tol in $ToleranceValues) {
    $folderName = Get-ToleranceFolderName $tol
    $runFolder = Join-Path $ResolvedValidationOutputDir $folderName
    Write-Host "Running First Spiky tolerance $tol -> $runFolder"
    Invoke-FijiRun -RunFolder $runFolder -FirstTolerance $tol -RunMode "Full Batch" -MaxSamples $MaxSamples -ChangeKeyword ("Phase17Tolerance_" + $folderName)
}
