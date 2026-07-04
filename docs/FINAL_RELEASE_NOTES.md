# Spiky Batch Macro v0.1.17 Final

Release date: 2026-07-02

This is the first public-ready packaged release of the Fiji/ImageJ Spiky Batch Macro.

## Highlights

- Full Batch calcium-flux trace analysis using the packaged Spiky dependency.
- Validated polynomial baseline correction and corrected-trace peak analysis.
- Conservative, traceable QC and recoverable per-sample failures.
- Source-aware aggregate filenames and organized run-root, `Data/`, `Plots/`, and `Tables/` outputs.
- Lightweight Excel XML workbook plus separate detailed masters.
- Publication-oriented `Method_Note.txt`, settings, runtime records, and macro provenance verification.
- Deterministic 96-well synthetic stress test and lightweight public example.

## Validation

The accepted scientific workflow completed the deterministic Full Batch stress test with 96/96 wells processed, 59 successes, 37 traceable conservative failures, and 526 final peaks. Required source-aware outputs, aggregate structure, normalized scientific CSV/workbook content, provenance, XML validation, and Excel 16.0 short-path opening passed.

Final pre-public UI polish changed only interactive menu wording/control mapping and the source license header. The non-interactive argument path, scientific calculations, validation logic, and output formats were preserved. Static dialog/getter checks and a non-interactive packaged Dry Run passed with verified provenance and no Fiji stdout/stderr error matches.

Batch macro SHA-256:

`E591A8780EBF9E3FBC42FF80B091281119F1A6E51205A7E680C4705416CA62E2`

Spiky dependency SHA-256:

`79E1F96DA597A1AA91D462DB7B662459FF68B388BD93BF204FD8ABF401CDD81D`

## Compatibility and limitations

Validated with ImageJ 2.16.0 / 1.54p on Windows. Cross-platform use is expected but not fully validated. Older Excel configurations may require the XML workbook to be copied to a short path such as `C:\Spiky_Output\`.

Scientific calculations, peak detection, baseline fitting, thresholds, and pass/fail criteria did not change during public hardening.
