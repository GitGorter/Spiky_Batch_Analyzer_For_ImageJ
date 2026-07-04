# Changelog

All notable public changes are recorded here. The project follows semantic versioning where practical.

## [v0.1.17 final] - 2026-07-02

First public-ready packaged release.

### Added

- Full Batch calcium-flux workflow using Spiky peak detection.
- Polynomial baseline correction from validated Spiky baseline anchors.
- Traceable per-sample warnings and recoverable failures.
- Conservative `Baseline_OK`, `Baseline_Warning`, and `Baseline_HighRisk` labels.
- Source-aware aggregate filenames and lightweight Excel XML workbook.
- Organized run-root, `Data/`, `Plots/`, and `Tables/` outputs.
- Publication-oriented `Method_Note.txt` and complete settings/run provenance.
- Deterministic 96-well synthetic stress-test dataset and public-safe example.

### Improved

- Provenance verification confirms that the copied run macro matches the executed macro.
- Workbook generation and batch runtime reporting were optimized without changing scientific calculations.
- Public documentation, licensing, attribution, packaging, and repository hygiene were hardened.
- The interactive main menu now uses public-facing sample-limit controls, explains polynomial fallback behavior, clarifies the Spiky macro path, and displays a concise GPL notice.

### Validation

- 96/96 deterministic dummy wells processed.
- 59 final-output successes, 37 traceable conservative failures, and 526 final peaks.
- Source-aware outputs, aggregation, required files, XML structure, and short-path Excel opening passed.
