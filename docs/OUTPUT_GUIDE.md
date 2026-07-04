# Output Guide

A successful run creates a timestamped folder with three layers.

## Run root

- `<InputFileStem>_Batch_Master_Results.xml`: lightweight Excel 2003 XML workbook with `Sample_QC`, `Peak_Analysis_Summary`, `Baseline_Correction_Master`, and `Processing_Steps_Master` sheets.
- `Run_Log.csv`: one traceable record per processed sample, including warnings and failure reasons.
- `Macro_Used_For_This_Run.ijm`: exact macro copy for provenance.

## Data

`Data/` contains source-aware QC, final-peak, time-series, baseline-correction, and processing-step master tables; `Analysis_Settings.txt`; publication-oriented `Method_Note.txt`; and validation runtime/provenance records when the non-interactive runner is used.

`Method_Note.txt` is a methods skeleton. Use the settings, run log, QC masters, and provenance records for audit detail.

## Plots and Tables

`Plots/` contains raw traces, first-Spiky detections, baseline reconstructions, final peak plots, and the batch overview when available. `Tables/` contains detailed per-sample values, peak tables, anchors, diagnostics, corrected traces, and final peak metrics.

Failed samples may have only the artifacts produced before failure. This is expected when `Run_Log.csv` clearly records the terminal phase and reason.

## Source-aware discovery

The input filename stem prefixes aggregate outputs so related datasets do not collide in Excel. External tools should search by stable suffix, such as `*_Final_Peak_Master.csv`, or read exact paths from `Analysis_Settings.txt`.

If Excel cannot open a valid XML workbook from a deep Windows path, copy it to a short local location such as `C:\Spiky_Output\`.
