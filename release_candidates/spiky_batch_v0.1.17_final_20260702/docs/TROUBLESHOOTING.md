# Troubleshooting

Start with `Run_Log.csv`, then `Data/Analysis_Settings.txt`, the sample's baseline reconstruction plot, and its final peak plot.

## Spiky command is unavailable

Copy the packaged `Spiky.ijm` into Fiji's `macros/toolsets` folder and restart Fiji. Optional Spiky modules are not required.

## No raw peaks or too few anchors

This may be an expected conservative failure for weak, flat, artifact-heavy, or sparsely beating traces. Confirm the input column and inspect raw/first-Spiky plots. Do not lower thresholds merely to force a pass.

## Excel cannot access the XML workbook

The workbook may be valid but located under a path that is too deep for an older Excel configuration. Copy it to `C:\Spiky_Output\` or choose a shorter output parent. Validate XML structure before treating the message as corruption.

## CSV columns look wrong in Excel

Use Excel's text import controls and select the delimiter/decimal convention recorded in `Analysis_Settings.txt`.

## A Full Batch run has failed samples

That alone is not a software failure. Confirm each sample appears in the run log and QC summary, later samples continued, aggregate counts are consistent, and expected run-level files exist.

## Reporting a bug

Use a public-safe synthetic reproduction. Include Fiji/ImageJ version, operating system, macro SHA-256, settings, input dimensions, terminal status, and error text. Never post private or unpublished data publicly.
