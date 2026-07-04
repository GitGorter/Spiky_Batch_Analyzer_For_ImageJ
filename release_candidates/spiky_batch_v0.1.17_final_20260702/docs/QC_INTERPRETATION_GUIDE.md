# QC Interpretation Guide

QC labels describe technical baseline confidence, not biological validity.

## Baseline_OK

The automated anchor and baseline checks passed. Perform routine review of the baseline reconstruction and final peak plot.

## Baseline_Warning

The sample completed with one or more cautions, such as limited endpoint support, uneven anchor coverage, fallback degree use, or correction-range concerns. A warning does not automatically mean failure or exclusion. Inspect the diagnostic table and plots.

## Baseline_HighRisk

The correction completed but severe or peak-aware timing concerns make downstream interpretation risky. Review the anchors, fitted baseline, corrected trace, final peak detection, and run-log reason before using the sample.

## Failed samples

Conservative failures can be appropriate when raw peaks, validated anchors, a safe fit, or corrected peaks cannot be verified. A Full Batch run may contain successful, warning, high-risk, and failed samples. The requirements are continued processing, explicit status, traceable reasons, and internally consistent aggregates.

Never use an automated label as the sole basis for a biological conclusion.
