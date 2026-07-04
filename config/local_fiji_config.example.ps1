# Copy this file to local_fiji_config.ps1 and edit the copy.
# Do not commit local_fiji_config.ps1.

$FIJI_EXE = "C:\Path\To\Fiji.app\fiji-windows-x64.exe"
$MAIN_MACRO = ".\Batch_Spiky_Baseline_Correction_v0.1.ijm"
$TEST_DATA_DIR = ".\docs\validation"
$TEST_INPUT_CSV = ".\docs\validation\Spiky_Maintenance_Dummy_96well_CalciumFlux_1000tp.csv"
$VALIDATION_OUTPUT_DIR = ".\validation\phase17\outputs"
$SPIKY_MACRO = ".\Spiky.ijm"

$DEFAULT_FIRST_SPIKY_TOLERANCE = 15
$DEFAULT_FIRST_SPIKY_SMOOTHING = -1
$DEFAULT_SECOND_SPIKY_TOLERANCE = 15
$DEFAULT_SECOND_SPIKY_SMOOTHING = -1
