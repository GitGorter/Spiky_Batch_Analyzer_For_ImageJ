// =============================================================================
// Spiky Batch Macro for Fiji/ImageJ
// Copyright (C) 2026 Alan Gorter
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// See the LICENSE file included with this project for the full license text.
// =============================================================================
// Version: v0.1.16
// Status: Phase 15A role-based batch aggregation scaffold
// History:
// - Phase 3 validated: first Spiky raw peak-analysis wrapper,
//   output detection, plot export, and peak-table export.
// - Phase 4 validated: first Spiky Plot Values export,
//   Plot Values table capture, and Plot Values CSV export.
// - Phase 5 validated: baseline-anchor dataset prediction,
//   validation, and baseline-anchor CSV export.
// - Added user-editable Change Keyword for output folder naming
//   and run metadata.
// - Stage 1 output table format setting added for future staged
//   export migration; current export behavior unchanged.
// - Stage 2 applies selected output table format to Run_Log only.
//   Phase 3/4/5 table exports are unchanged.
// - Stage 3 applies selected output table format to Phase 5
//   BaselineAnchors export only.
// - Stage 4 applies selected output table format to Phase 3
//   FirstSpiky PeakAnalysis export only.
// - Stage 5 applies selected output table format to Phase 4
//   Plot Values export only; Phase 5 still reads the live table.
// - Phase 6 fits a polynomial baseline to validated Phase 5
//   anchors for Test First Sample Only mode and stores fitted
//   baseline values internally only.
// - Phase 7 calculates Baseline, DeltaF, DeltaF/F0, and
//   DeltaF/F0 percent after successful Phase 6 and exports one
//   first-sample corrected trace table for diagnostic revalidation only.
// - Phase 6 repair: Fit.doFit receives exact-length validated anchor
//   arrays only; fit-input, residual, support, and reasonableness
//   diagnostics block Phase 7 when hard checks fail.
// - Phase 8 creates a baseline reconstruction QC plot for Test First
//   Sample Only after successful Phase 6/7 completion. It plots raw
//   fluorescence, exact-length validated anchors, and the repaired
//   Phase 6 fitted baseline. No endpoint correction is performed.
// - Phase 9 creates a corrected DeltaF/F0 input plot from validated
//   Phase 7 arrays and runs a second Spiky analysis on that plot only.
//   Final peak-analysis export, final peak-analysis PNG export, Full
//   Batch, and final all-samples corrected trace export are not implemented.
// - Phase 10 exports final second-Spiky peak metrics and saves the
//   final second-Spiky detected-peaks plot for Test First Sample Only.
//   Full Batch and final all-samples corrected trace export are not implemented.
// - Phase 11 conservatively closes deterministic macro-created intermediate
//   windows after successful Test First Sample Only output verification.
//   Scientific outputs and Full Batch behavior are unchanged.
// - Phase 11 v0.1.6 adds a batch Spiky peak-orientation setting and maps
//   Auto/Negative/Positive to non-dialog Spiky commands for both Spiky runs.
// - Phase 11 v0.1.7 uses the already registered Spiky "Peaks analysis"
//   command with a batch-only orientation preference to avoid command
//   registration failures while preserving the manual dialog.
// - Phase 11 v0.1.8 fixes final-dialog string truncation so failure
//   reporting cannot crash in a numeric-return context.
// - Phase 11 v0.1.9 labels missing Spiky batch-orientation support as
//   Spiky orientation preflight in the final failure dialog.
// - Phase 11 v0.1.10 formalizes Option D: the batch macro sets a
//   one-shot SPIKY.Batch.PeakAnalysisOrientation preference and then calls
//   the original Spiky "Peaks analysis" command. The unregistered
//   Auto/Negative/Positive command strategy is not used.
// - Phase 11 v0.1.11 replaces Option D with direct execution of a selected
//   modified Spiky.ijm file using runMacro(path, argument). This avoids
//   command-registration ambiguity and verifies the exact file before use.
// - Phase 11 v0.1.12 moves the direct Spiky dispatcher to the early
//   top-level path, passes the exact source plot title, and stops the
//   direct macro run after launchAnalysis.
// - Phase 11 v0.1.14 replaces batch-only Y-axis label arguments with a
//   safer direct-batch Spiky prompt bypass that accepts the active source
//   plot's existing non-empty Y-axis label.
// - Phase 13 v0.1.15 adds a Full Batch loop skeleton with maximum-sample
//   validation limit, per-sample reset, per-sample outputs, and
//   stop-on-first-sample-failure behavior. Aggregation is not implemented.
// - Phase 14 v0.1.16 keeps the per-sample Full Batch loop but continues
//   after recoverable sample failures when exact-name cleanup verifies that
//   the next sample cannot be contaminated. Aggregation is not implemented.
// - Phase 15A v0.1.17 adds additive, role-based master aggregation files
//   in the main output folder. Analysis math, Spiky behavior, endpoint
//   policy, Run_Log schema, and existing per-sample exports are unchanged.
// =======================================================
//
// DEVELOPMENT CHECKLIST - UPDATE WHEN CHANGING THE MACRO
//
// [ ] Does this add/change a user setting?
//     -> Update settings dialog
//     -> Update Analysis_Settings.txt
//     -> Consider Run_Log.csv
//
// [ ] Does this add/change a per-timepoint metric?
//     -> Update Corrected_Traces_All_Samples.csv
//     -> Consider plots
//
// [ ] Does this add/change a per-peak metric?
//     -> Update Peak_Analysis_After_Baseline_Correction.csv
//     -> Consider Run_Log.csv summary metrics
//
// [ ] Does this add/change a QC metric?
//     -> Update Run_Log.csv
//     -> Consider Analysis_Settings.txt
//
// [ ] Does this add/change baseline fitting?
//     -> Update Baseline_Reconstruction plot
//     -> Update baseline diagnostics in Run_Log.csv
//
// [ ] Does this add/change peak analysis?
//     -> Update final peak CSV
//     -> Update peak count/summary metrics in Run_Log.csv
//
// [ ] Does this affect reproducibility?
//     -> Add to Analysis_Settings.txt
//     -> Add to Run_Log.csv if sample-specific
//
// [ ] Does this affect file/window names?
//     -> Check filename sanitization
//     -> Check duplicate sample names
//
// [ ] Could this break large or small datasets?
//     -> Check no hardcoded row counts
//     -> Check no hardcoded sample names
//     -> Check missing values
//     -> Check flat traces
//
// [ ] Could one bad sample crash the batch?
//     -> Add warning/error handling
//     -> Continue to next sample if possible
//
// CORE SCIENTIFIC RULE:
// Never substitute, infer, estimate, reconstruct, or guess scientific data
// when the expected source data cannot be verified.
//
// =======================================================
//
// IMPLEMENTATION PHASES
//
// Phase 1:
// - Settings dialog
// - Dry Run
// - Active table detection
// - Sample detection
// - Output folder/files
//
// Phase 2:
// - First-sample clean raw plot creation
//
// Phase 3:
// - First Spiky raw peak analysis on first-sample clean plot only
//
// Phase 4:
// - Export full Plot Values table from first Spiky detected-peaks plot
// - Do not interpret X/Y datasets or baseline anchors
//
// Phase 5:
// - Identify and validate first-sample baseline anchors only
//
// Phase 6:
// - Polynomial baseline fitting on validated first-sample anchors only
//
// Phase 7:
// - Internal corrected trace calculations on first sample only
//
// Phase 8:
// - Full-trace baseline reconstruction
//
// Phase 9:
// - Second Spiky peak analysis on corrected DeltaF/F0 input plot
//
// Phase 10:
// - Final peak analysis/export
//
// Phase 11+:
// - Full Batch / cleanup / polish
//
// =======================================================

var phaseWarning, phaseError, runCompletionStatus;
var phase2SourceSample, phase2PlotName;
var phase2RawPlotSavePath, phase2RawValuesTableSavePath;
var phase3RawPlotName, phase3SpikyDetectedPeaksPlotName;
var phase3SpikyPeakAnalysisTableName, phase3ExistingResultsBackupName;
var phase3SpikyStatus, phase3SpikyWasCalled, phase3OpenWindowsAfterSpiky;
var phase3DetectedPeaksPlotSavePath, phase3PeakAnalysisTableSavePath;
var phase3OutputSaveStatus, phase3PrefShowDetectedPeakPlot;
var phase3PrefShowPeakResultsTable, phase3PrefShowBaseline;
var phase3PrefShowThreshold, phase3PrefSynchroDetection;
var phase3PrefDerivativeOutput, phase3PrefSlopeOutput, phase3PrefSlopeDisplay;
var phase3PrefPeakAreaOutput, phase3PrefDecayFitting, phase3PrefSummaryOutput;
var phase3PrefAutoDetectMode, phase3PeakDirectionSource, phase3PeakDirectionFinal;
var phase3PrefTolerancePercent, phase3PrefSmoothing;
var phase3PrefThresholdStartPercent, phase3PrefFullWidthOutput;
var phase3PrefHalfWidthOutput, phase3PrefFullWidthPercent1;
var phase3PrefFullWidthPercent2;
var phase3FirstSpikyFallbackUsed, phase3FirstSpikyFallbackInitialTolerance;
var phase3FirstSpikyFallbackFinalTolerance, phase3FirstSpikyFallbackFailedAttempts;
var phase3FirstSpikyFallbackReason, phase3FirstSpikyFallbackPassedAfterFallback;
var phase4PlotValuesStatus, phase4PlotValuesTableName, phase4PlotValuesSavePath;
var phase4PlotValuesColumnCount, phase4PlotValuesColumnHeadings;
var phase4PlotValuesOpenWindowsBefore, phase4PlotValuesOpenWindowsAfter;
var phase4PlotValuesWarning, phase4PlotValuesError;
var phase4ExistingResultsBackupName, phase4ExistingPlotValuesBackupName;
var phase5ValidationStatus, phase5PlotValuesSourceTableName;
var phase5PredictedXColumn, phase5PredictedYColumn, phase5PredictionReason;
var phase5AnchorCount, phase5BaselineAnchorsSavePath;
var phase5ValidationError, phase5ValidationWarning, phase5ValidationWindowMode;
var phase5LocalBaselineWindowPoints, phase5PeakExclusionWindowPoints;
var phase5LocalBaselineTolerancePercent, phase5PeakSeparationPercent;
var phase5MedianTimeStep, phase5LocalBaselineWindowTimeUnits;
var phase5PeakExclusionWindowTimeUnits, phase5RawXMin, phase5RawXMax;
var phase5RawYMin, phase5RawYMax, phase5AnchorYMin, phase5AnchorYMax;
var phase5RawYRange, phase5PeakMarkerColumnX, phase5PeakMarkerColumnY;
var phase5CandidateDiagnostics, phase5RawTimes, phase5RawValues;
var phase5TimeSteps, phase5AnchorTimes, phase5AnchorValues;
var phase5PeakTimes, phase5PeakValues, phase5PeakCount;
var phase6FitStatus, phase6FitFunction, phase6PolynomialDegreeUsed;
var phase6SupportedDegrees, phase6AnchorCount, phase6CoefficientCount;
var phase6CoefficientsText, phase6CoefficientOrder, phase6FitRMSE;
var phase6FitRSquared, phase6FittedBaselineMin, phase6FittedBaselineMean;
var phase6FittedBaselineMax, phase6BaselineValueCount, phase6FitWarning;
var phase6FitError, phase6CoefficientStabilityAbsLimit, phase6BaselineValues;
var phase6SourceAnchorArrayLength, phase6FitInputAnchorCount;
var phase6UnusedSourceAnchorEntries, phase6FitInputArrayStatus;
var phase6FitInputFirstTime, phase6FitInputLastTime;
var phase6FitInputFirstValue, phase6FitInputLastValue;
var phase6FitAnchorTimes, phase6FitAnchorValues, phase6AnchorFittedValues;
var phase6AnchorResidualValues, phase6AnchorPercentResidualValues;
var phase6AnchorDiagnosticCount, phase6AnchorResidualRMSE;
var phase6AnchorResidualMaxAbs, phase6AnchorResidualMaxPercentAbs;
var phase6AnchorResidualWarnPercent, phase6AnchorResidualFailPercent;
var phase6RawTimeMin, phase6RawTimeMax, phase6AnchorTimeMin, phase6AnchorTimeMax;
var phase6RawRowsBeforeFirstAnchor, phase6RawRowsAfterLastAnchor;
var phase6RawPercentOutsideAnchorSupport, phase6FirstFittedBaseline;
var phase6LastFittedBaseline, phase6FitReasonablenessStatus;
var phase6FitReasonablenessError, phase6FitReasonablenessWarning;
var phase6AnchorTimeCoveragePercent, phase6AnchorSpreadStatus;
var phase6PolynomialDegreeFirstAttempted, phase6PolynomialFallbackUsed;
var phase6PolynomialFallbackReason, phase6BaselineRangeWarning;
var phase6BaselineEndpointWarning, phase6BaselineNegativeCorrectionWarning;
var phase6BaselineCurvatureWarning, phase6PeakAwareAnchorTimingWarning;
var phase6BaselineReliabilityClass, phase6BaselineReliabilityReason;
var phase6DiagnosticTableSaveStatus, phase6DiagnosticTableSavePath;
var phase7CalculationStatus, phase7RawValueCount, phase7BaselineValueCount;
var phase7DeltaFValueCount, phase7DeltaFOverF0ValueCount;
var phase7DeltaFOverF0PercentValueCount, phase7RawBaselineAlignmentStatus;
var phase7MinDeltaF, phase7MeanDeltaF, phase7MaxDeltaF;
var phase7MinDeltaFOverF0, phase7MeanDeltaFOverF0, phase7MaxDeltaFOverF0;
var phase7MinDeltaFOverF0Percent, phase7MeanDeltaFOverF0Percent;
var phase7MaxDeltaFOverF0Percent, phase7InvalidBaselineValueCount;
var phase7InvalidCorrectedValueCount, phase7FirstInvalidRow;
var phase7FirstInvalidReason, phase7MinimumSafeBaselineAbs;
var phase7Warning, phase7Error, phase7BaselineTimes, phase7BaselineValues;
var phase7DeltaFValues, phase7DeltaFOverF0Values;
var phase7DeltaFOverF0PercentValues;
var phase7CorrectedTraceTableSaveStatus, phase7CorrectedTraceTableSavePath;
var phase8PlotStatus, phase8PlotWindowName, phase8PlotSavePath;
var phase8PlotWarning, phase8PlotError, phase8InPlotWarningStatus;
var phase8InPlotWarningText, phase8EndpointAnnotationThresholdPercent;
var phase8FirstRawTime, phase8FirstAnchorTime;
var phase9SecondSpikyStatus, phase9CorrectedInputPlotName;
var phase9CorrectedInputValueCount, phase9CorrectedInputYMin;
var phase9CorrectedInputYMax, phase9CorrectedInputWarning;
var phase9CorrectedInputError, phase9SecondSpikyWasCalled;
var phase9ExistingResultsBackupName, phase9SecondSpikyDetectedPeaksPlotName;
var phase9SecondSpikyPeakAnalysisTableName, phase9OpenWindowsAfterSpiky;
var phase9SecondSpikyWarning, phase9SecondSpikyError;
var phase10FinalOutputStatus, phase10FinalPeakTableSourceName;
var phase10FinalPeakTableSavePath, phase10FinalPeakTableRowCount;
var phase10FinalPeakTableColumnCount, phase10FinalPeakPlotSourceName;
var phase10FinalPeakPlotSavePath, phase10FinalOutputWarning;
var phase10FinalOutputError;
var phase11WindowCleanupStatus, phase11WindowCleanupClosedWindows;
var phase11WindowCleanupWarning, phase11WindowCleanupKeptOpen;
var quotedExistingRunLogPathResult;
var logWindowWasOpenAtStart;
var finalDialogSampleName, firstSampleSafeName;
var spikyPeakOrientation, spikyPeakOrientationValidationError, spikyMacroPath;
var spikyBatchOrientationSupportError;
var firstSpikyTolerancePercent, firstSpikySmoothing;
var secondSpikyTolerancePercent, secondSpikySmoothing;
var fullBatchMaxSamplesToProcess, fullBatchPlannedSampleCount;
var fullBatchProcessedSampleCount, phase13CurrentSampleIndex;
var phase13SampleRunLogRows, phase13FullBatchStoppedAfterFailure;
var phase13FullBatchStopReason;
var returnToMainMenuAfterRun;
var phase2RawPlotCreateError;
var phase15SampleSummaryPath, phase15FinalPeakMasterPath;
var phase15TimeSeriesMasterPath, phase15BaselineCorrectionMasterPath;
var phase15ProcessingStepsMasterPath, phase15MasterTablesInitialized;
var phase15MasterTablesStatus, phase15ExportWarning, phase15ExportError;
var phase15SummaryRowWritten, phase15FinalPeakMasterRowsWrittenForSample;
var phase15LastAppendStatus;
var phase16OverviewPlotPath, phase16MasterWorkbookPath;
var phase16ExportStatus, phase16ExportWarning, phase16ExportError;
var phase16DelimitedFieldResult, phase16TextResult;
var validationModeUsed, validationArgText, validationInputCsvPath;
var validationOutputDir, validationArgumentSummary, nonInteractiveProgressLogPath;
var batchMacroSourcePath, batchMacroExpectedSha256;
var runStartTimeMs, fullBatchSampleLoopStartTimeMs, fullBatchSampleLoopElapsedMs;
var fullBatchAggregationStartTimeMs, fullBatchAggregationElapsedMs;
var phase16OverviewElapsedMs, phase16WorkbookElapsedMs, maxObservedOpenWindowCount;
var phase16DurationSafeNames, phase16DurationValues, phase16DurationCacheCount;
var phase16BaselineMasterLines;
var inputSourceFileStem;

requires("1.53");

runStartTimeMs = getTime();
fullBatchSampleLoopStartTimeMs = 0;
fullBatchSampleLoopElapsedMs = 0;
fullBatchAggregationStartTimeMs = 0;
fullBatchAggregationElapsedMs = 0;
phase16OverviewElapsedMs = 0;
phase16WorkbookElapsedMs = 0;
maxObservedOpenWindowCount = 0;
macroVersion = "v0.1.17";
macroName = "Batch_Spiky_Baseline_Correction";
phaseDescription = "Phase 16A Full Batch output polishing adds a combined final peak overview image and one Excel-compatible master results workbook without changing analysis math, Spiky behavior, baseline fitting logic, endpoint policy, Run_Log schema, or per-sample outputs";
currentPhaseTag = "Phase16A";
timestamp = makeTimestamp();
imageJVersion = getVersion();
lastOutputLocationPrefsKey = "spiky.batch.v0.1.dataOutputLocation";
phase2XAxisLabel = "Time (s)";
phase2YAxisLabel = "Fluorescence (RFU)";
fullBatchPhase6StopReason = "Phase 15A Full Batch continues after recoverable per-sample failures when cleanup verifies next-sample isolation and adds role-based master aggregation files without changing analysis math or per-sample outputs.";
spikyPeakOrientation = "Auto";
phase3SpikyCommand = makeSpikyPeakAnalysisCommand(spikyPeakOrientation);
defaultSpikyMacroPath = makeDefaultSpikyMacroPath();
batchMacroSourcePath = cleanDialogPath(getInfo("macro.filepath"));
batchMacroExpectedSha256 = "";
validationArgText = getArgument();
validationModeUsed = "No";
validationInputCsvPath = "";
validationOutputDir = "";
validationArgumentSummary = "";
nonInteractiveProgressLogPath = "";

if (validationArgText != "" && validationArgText != "NaN") {
	validationModeUsed = "Yes";
	validationInputCsvPath = getValidationArgumentValue(validationArgText, "inputCsv");
	if (validationInputCsvPath == "")
		exit("Non-interactive validation mode requires inputCsv=<path>.");
	if (!File.exists(validationInputCsvPath))
		exit("Non-interactive validation input CSV was not found:\n\n" + validationInputCsvPath);
	open(validationInputCsvPath);
	wait(500);
}
inputTableSelectionStatus = selectInputTableWindow();

activeWindowTitle = getInfo("window.title");
activeWindowType = getInfo("window.type");
activeTableTitle = Table.title;
headingsText = Table.headings;
logWindowWasOpenAtStart = isOpen("Log");

if (headingsText == "") {
	exit("The selected table does not have readable column headings.\n\nExpected format:\nColumn 1 = Time\nColumns 2+ = sample traces\n\nNo output was created.");
}

headings = split(headingsText, "\t");
columnCount = lengthOf(headings);
rowCount = Table.size;

if (rowCount <= 0) {
	exit("The selected table has no data rows.\n\nExpected format:\nColumn 1 = Time\nColumns 2+ = sample traces\n\nNo output was created.");
}

if (columnCount < 2) {
	exit("The selected table must contain at least two columns.\n\nExpected format:\nColumn 1 = Time\nColumns 2+ = sample traces\n\nNo output was created.");
}

timeColumnName = headings[0];
trimmedTimeColumnName = trimString(timeColumnName);
if (trimmedTimeColumnName == "") {
	exit("Column 1 is required to be the Time column, but its heading is blank.\n\nExpected format:\nColumn 1 = Time\nColumns 2+ = sample traces\n\nNo output was created.");
}

sampleCount = columnCount - 1;

homeDirectory = getDirectory("home");
defaultOutputParent = call("ij.Prefs.get", lastOutputLocationPrefsKey, homeDirectory);
defaultFirstSpikyTolerancePercent = call("ij.Prefs.get", "SPIKY.PeakAna.tolerance", 15);
defaultFirstSpikySmoothing = call("ij.Prefs.get", "SPIKY.PeakAna.smooth", -1);
defaultSecondSpikyTolerancePercent = defaultFirstSpikyTolerancePercent;
defaultSecondSpikySmoothing = defaultFirstSpikySmoothing;
if (isNaN(defaultFirstSpikyTolerancePercent) || defaultFirstSpikyTolerancePercent < 0)
	defaultFirstSpikyTolerancePercent = 15;
if (isNaN(defaultFirstSpikySmoothing) || defaultFirstSpikySmoothing < -1)
	defaultFirstSpikySmoothing = -1;
if (isNaN(defaultSecondSpikyTolerancePercent) || defaultSecondSpikyTolerancePercent < 0)
	defaultSecondSpikyTolerancePercent = 15;
if (isNaN(defaultSecondSpikySmoothing) || defaultSecondSpikySmoothing < -1)
	defaultSecondSpikySmoothing = -1;
if (validationModeUsed == "Yes") {
	validationOutputDir = getValidationArgumentValue(validationArgText, "outputDir");
	if (validationOutputDir == "")
		exit("Non-interactive validation mode requires outputDir=<folder>.");
	runMode = getValidationArgumentValue(validationArgText, "runMode");
	if (runMode == "")
		runMode = "Full Batch";
	if (runMode != "Full Batch" && runMode != "Test First Sample Only" && runMode != "Dry Run")
		exit("Invalid non-interactive runMode: " + runMode + ". Expected Full Batch, Test First Sample Only, or Dry Run.");
	outputParent = validationOutputDir;
	changeKeywordRaw = getValidationArgumentValue(validationArgText, "changeKeyword");
	if (changeKeywordRaw == "")
		changeKeywordRaw = "Phase17Validation";
	changeKeyword = normalizeChangeKeyword(changeKeywordRaw);
	outputTableFormat = "International CSV";
	baselineCurveMethod = "Polynomial";
	polynomialDegreeChoice = getValidationArgumentValue(validationArgText, "polynomialDegree");
	if (polynomialDegreeChoice == "")
		polynomialDegreeChoice = "4";
	spikyPeakOrientation = getValidationArgumentValue(validationArgText, "spikyOrientation");
	if (spikyPeakOrientation == "")
		spikyPeakOrientation = "Auto";
	spikyMacroPath = cleanDialogPath(getValidationArgumentValue(validationArgText, "spikyMacro"));
	if (spikyMacroPath == "")
		spikyMacroPath = defaultSpikyMacroPath;
	validationBatchMacroPath = cleanDialogPath(getValidationArgumentValue(validationArgText, "batchMacro"));
	if (validationBatchMacroPath != "")
		batchMacroSourcePath = validationBatchMacroPath;
	batchMacroExpectedSha256 = trimString(getValidationArgumentValue(validationArgText, "batchMacroSha256"));
	if (batchMacroSourcePath == "")
		exit("Non-interactive validation mode requires a verifiable batchMacro=<path> provenance source.");
	if (!File.exists(batchMacroSourcePath))
		exit("Non-interactive validation batch macro was not found:\n\n" + batchMacroSourcePath);
	firstSpikyTolerancePercent = normalizeSpikyTolerancePercent(parseRequiredValidationNumber(validationArgText, "firstTol"), defaultFirstSpikyTolerancePercent);
	firstSpikySmoothing = normalizeSpikySmoothing(parseRequiredValidationNumber(validationArgText, "firstSmooth"), defaultFirstSpikySmoothing);
	secondSpikyTolerancePercent = normalizeSpikyTolerancePercent(parseRequiredValidationNumber(validationArgText, "secondTol"), defaultSecondSpikyTolerancePercent);
	secondSpikySmoothing = normalizeSpikySmoothing(parseRequiredValidationNumber(validationArgText, "secondSmooth"), defaultSecondSpikySmoothing);
	fullBatchMaxSamplesToProcess = parseOptionalValidationNumber(validationArgText, "maxSamples", 2);
	returnToMainMenuAfterRun = false;
	copyMacroRequested = true;
	validationArgumentSummary = makeValidationArgumentSummary();
} else {
	Dialog.create("Spiky Batch Baseline Correction " + macroVersion);
	Dialog.addMessage("Input table should have Time in the first column and sample traces starting from the second column.");
	Dialog.addMessage("Run");
	Dialog.addChoice("Run mode", newArray("Dry Run", "Full Batch", "Test First Sample Only"), "Full Batch");
	Dialog.addChoice("Samples to process", newArray("Full Batch (all samples)", "Set Sample Amount"), "Full Batch (all samples)");
	Dialog.addNumber("Number of samples", 2);
	Dialog.addMessage("Used only when 'Set Sample Amount' is selected.");
	Dialog.addMessage("Input and output");
	Dialog.addDirectory("Data output location", defaultOutputParent);
	Dialog.addString("Change keyword for output folder", "NoKeyword", 30);
	Dialog.addChoice("Output table format", newArray("International CSV", "Excel EU/NL CSV", "TSV"), "International CSV");
	Dialog.addCheckbox("Copy macro into output folder if possible", true);
	Dialog.addCheckbox("Return to main menu after run", false);
	Dialog.addMessage("Baseline");
	Dialog.addChoice("Baseline curve method", newArray("Polynomial (with automatic fallback)"), "Polynomial (with automatic fallback)");
	Dialog.addChoice("Maximum polynomial degree", newArray("1", "2", "3", "4"), "4");
	Dialog.addMessage("The macro tries the selected degree first. If insufficient anchors or poor fit are detected, it automatically falls back to lower degrees.");
	Dialog.addMessage("Spiky");
	Dialog.addChoice("Spiky peak orientation", newArray("Auto", "Negative", "Positive"), "Auto");
	Dialog.addString("Spiky macro path", defaultSpikyMacroPath, 60);
	Dialog.addMessage("Path to the compatible Spiky.ijm used internally for anchor and peak detection.");
	Dialog.addMessage("Optional Spiky settings. Defaults use the current Fiji/Spiky preferences; change only for weak or poorly anchored traces.");
	Dialog.addNumber("First Spiky min peak amplitude from baseline (%)", defaultFirstSpikyTolerancePercent);
	Dialog.addNumber("First Spiky smoothing (-1 auto, 0 none, n points)", defaultFirstSpikySmoothing);
	Dialog.addNumber("Second Spiky min peak amplitude from baseline (%)", defaultSecondSpikyTolerancePercent);
	Dialog.addNumber("Second Spiky smoothing (-1 auto, 0 none, n points)", defaultSecondSpikySmoothing);
	Dialog.addMessage("Spiky Batch Baseline Correction\nCopyright (C) 2026 Alan Gorter\nFree software: redistribute and/or modify under GNU GPL v3.0 or later.\nSee the LICENSE file in this package for details.");
	Dialog.show();

	runMode = Dialog.getChoice();
	samplesToProcessChoice = Dialog.getChoice();
	requestedSampleAmount = Dialog.getNumber();
	fullBatchMaxSamplesToProcess = 0;
	if (samplesToProcessChoice == "Set Sample Amount")
		fullBatchMaxSamplesToProcess = requestedSampleAmount;
	outputParent = Dialog.getString();
	changeKeywordRaw = Dialog.getString();
	changeKeyword = normalizeChangeKeyword(changeKeywordRaw);
	outputTableFormat = Dialog.getChoice();
	copyMacroRequested = Dialog.getCheckbox();
	returnToMainMenuAfterRun = Dialog.getCheckbox();
	baselineCurveMethodChoice = Dialog.getChoice();
	baselineCurveMethod = "Polynomial";
	polynomialDegreeChoice = Dialog.getChoice();
	spikyPeakOrientation = Dialog.getChoice();
	spikyMacroPath = cleanDialogPath(Dialog.getString());
	firstSpikyTolerancePercent = normalizeSpikyTolerancePercent(Dialog.getNumber(), defaultFirstSpikyTolerancePercent);
	firstSpikySmoothing = normalizeSpikySmoothing(Dialog.getNumber(), defaultFirstSpikySmoothing);
	secondSpikyTolerancePercent = normalizeSpikyTolerancePercent(Dialog.getNumber(), defaultSecondSpikyTolerancePercent);
	secondSpikySmoothing = normalizeSpikySmoothing(Dialog.getNumber(), defaultSecondSpikySmoothing);
}
if (isNaN(fullBatchMaxSamplesToProcess) || fullBatchMaxSamplesToProcess < 0)
	fullBatchMaxSamplesToProcess = 0;
fullBatchMaxSamplesToProcess = floor(fullBatchMaxSamplesToProcess);
phase3SpikyCommand = makeSpikyPeakAnalysisCommand(spikyPeakOrientation);
selectedPolynomialDegree = 4;
if (polynomialDegreeChoice == "1")
	selectedPolynomialDegree = 1;
if (polynomialDegreeChoice == "2")
	selectedPolynomialDegree = 2;
if (polynomialDegreeChoice == "3")
	selectedPolynomialDegree = 3;
fullBatchPlannedSampleCount = sampleCount;
if (fullBatchMaxSamplesToProcess > 0 && fullBatchMaxSamplesToProcess < sampleCount)
	fullBatchPlannedSampleCount = fullBatchMaxSamplesToProcess;
fullBatchProcessedSampleCount = 0;
phase13CurrentSampleIndex = 0;
phase13SampleRunLogRows = "";
phase13FullBatchStoppedAfterFailure = "No";
phase13FullBatchStopReason = "";

if (outputTableFormat == "Excel EU/NL CSV") {
	outputFieldDelimiter = ";";
	outputFieldDelimiterLabel = "semicolon";
	outputDecimalSeparator = ",";
	outputTableExtension = ".csv";
} else if (outputTableFormat == "TSV") {
	outputFieldDelimiter = "\t";
	outputFieldDelimiterLabel = "tab";
	outputDecimalSeparator = ".";
	outputTableExtension = ".tsv";
} else {
	outputTableFormat = "International CSV";
	outputFieldDelimiter = ",";
	outputFieldDelimiterLabel = "comma";
	outputDecimalSeparator = ".";
	outputTableExtension = ".csv";
}
outputThousandsSeparators = "Never";

outputParent = ensureTrailingSeparator(outputParent);
if (!File.exists(outputParent)) {
	exit("The selected data output location does not exist:\n\n" + outputParent + "\n\nNo output was created.");
}
call("ij.Prefs.set", lastOutputLocationPrefsKey, outputParent);

sampleOriginalNames = newArray(sampleCount);
sampleUniqueNames = newArray(sampleCount);
sampleFileNames = newArray(sampleCount);
sampleWarnings = newArray(sampleCount);
sampleStatuses = newArray(sampleCount);
phase15SummaryRowWritten = newArray(sampleCount);

for (sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
	columnIndex = sampleIndex + 1;
	originalName = headings[columnIndex];
	baseName = trimString(originalName);
	warningText = "";

	if (baseName == "") {
		baseName = "Sample_Column_" + (columnIndex + 1);
		warningText = appendWarning(warningText, "Blank sample heading replaced with deterministic name.");
	}

	uniqueName = makeUniqueName(baseName, sampleUniqueNames, sampleIndex);
	if (uniqueName != baseName) {
		warningText = appendWarning(warningText, "Duplicate or conflicting sample name renamed deterministically.");
	}

	sanitizedName = sanitizeFileName(uniqueName);
	if (sanitizedName != uniqueName) {
		warningText = appendWarning(warningText, "Sample name sanitized for filename use.");
	}

	fileName = makeUniqueFileName(sanitizedName, sampleFileNames, sampleIndex);
	if (fileName != sanitizedName) {
		warningText = appendWarning(warningText, "Sanitized filename conflicted and was made unique.");
	}

	sampleOriginalNames[sampleIndex] = originalName;
	sampleUniqueNames[sampleIndex] = uniqueName;
	sampleFileNames[sampleIndex] = fileName;
	sampleWarnings[sampleIndex] = warningText;
	phase15SummaryRowWritten[sampleIndex] = 0;

	if (runMode == "Dry Run")
		sampleStatuses[sampleIndex] = "Dry_Run_Checked";
	else if (runMode == "Full Batch") {
		if (sampleIndex < fullBatchPlannedSampleCount)
			sampleStatuses[sampleIndex] = "Phase14_FullBatch_Planned";
		else
			sampleStatuses[sampleIndex] = "Skipped_By_Phase14_Max_Sample_Limit";
		sampleWarnings[sampleIndex] = warningText;
	}
	else
		sampleStatuses[sampleIndex] = "Phase1_Checked_No_Analysis";
}

runKeyword = makeRunKeyword(runMode);
outputFolder = createUniqueOutputFolder(outputParent, timestamp, macroVersion, currentPhaseTag, runKeyword, changeKeyword);
dataFolder = outputFolder + "Data" + File.separator;
File.makeDirectory(dataFolder);
if (!File.exists(dataFolder)) {
	exit("Could not create Data folder:\n\n" + dataFolder);
}
plotsFolder = outputFolder + "Plots" + File.separator;
File.makeDirectory(plotsFolder);
if (!File.exists(plotsFolder)) {
	exit("Could not create Plots folder:\n\n" + plotsFolder);
}

runLogPath = outputFolder + "Run_Log" + outputTableExtension;
settingsPath = dataFolder + "Analysis_Settings.txt";
methodNotePath = dataFolder + "Method_Note.txt";
macroCopyPath = outputFolder + "Macro_Used_For_This_Run.ijm";
inputSourceFileStem = makeInputSourceFileStem(validationInputCsvPath, activeTableTitle);
phase15SampleSummaryPath = dataFolder + inputSourceFileStem + "_Sample_Summary_QC" + outputTableExtension;
phase15FinalPeakMasterPath = dataFolder + inputSourceFileStem + "_Final_Peak_Master" + outputTableExtension;
phase15TimeSeriesMasterPath = dataFolder + inputSourceFileStem + "_TimeSeries_Master" + outputTableExtension;
phase15BaselineCorrectionMasterPath = dataFolder + inputSourceFileStem + "_Baseline_Correction_Master" + outputTableExtension;
phase15ProcessingStepsMasterPath = dataFolder + inputSourceFileStem + "_Processing_Steps_Master" + outputTableExtension;
phase16OverviewPlotPath = plotsFolder + inputSourceFileStem + "_Batch_Final_Peak_Analysis_Overview.png";
phase16MasterWorkbookPath = outputFolder + inputSourceFileStem + "_Batch_Master_Results.xml";
if (validationModeUsed == "Yes") {
	nonInteractiveProgressLogPath = dataFolder + "NonInteractive_Progress_Log.txt";
	File.saveString("Elapsed_ms\tEvent\tSample_Index\tSample_Name\tActive_Window\tOpen_Window_Count\tOpen_Windows\n", nonInteractiveProgressLogPath);
	writeNonInteractiveProgress("Output_Folder_Created");
}

phaseWarning = "";
phaseError = "";
phase15MasterTablesInitialized = "No";
phase15MasterTablesStatus = "";
phase15ExportWarning = "";
phase15ExportError = "";
phase15LastAppendStatus = "";
phase16ExportStatus = "Not_Started";
phase16ExportWarning = "";
phase16ExportError = "";
phase16DelimitedFieldResult = "";
phase16TextResult = "";
initializePhase15MasterTables();
if (phase15ExportWarning != "")
	phaseWarning = appendWarning(phaseWarning, phase15ExportWarning);
if (phase15ExportError != "")
	phaseError = appendWarning(phaseError, phase15ExportError);
spikyPeakOrientationValidationError = validateSpikyPeakOrientationSetting(spikyPeakOrientation, phase3SpikyCommand);
if (spikyPeakOrientationValidationError != "") {
	phaseError = appendWarning(phaseError, spikyPeakOrientationValidationError);
	runCompletionStatus = "Failed";
	if (sampleCount > 0)
		sampleStatuses[0] = "Failed";
}
spikyBatchOrientationSupportError = "";
if ((runMode == "Test First Sample Only" || runMode == "Full Batch") && baselineCurveMethod == "Polynomial" && phaseError == "") {
	spikyBatchOrientationSupportError = validateSpikyBatchOrientationSupport(spikyMacroPath);
	if (spikyBatchOrientationSupportError != "") {
		phaseError = appendWarning(phaseError, spikyBatchOrientationSupportError);
		runCompletionStatus = "Failed";
		if (sampleCount > 0)
			sampleStatuses[0] = "Failed";
	}
}
phase2SourceSample = "";
phase2PlotName = "";
phase2RawPlotSavePath = "";
phase2RawValuesTableSavePath = "";
phase2RawPlotCreateError = "";
phase3RawPlotName = "";
phase3SpikyDetectedPeaksPlotName = "";
phase3SpikyPeakAnalysisTableName = "";
phase3ExistingResultsBackupName = "";
phase3SpikyStatus = "";
phase3SpikyWasCalled = "No";
phase3OpenWindowsAfterSpiky = "";
phase3DetectedPeaksPlotSavePath = "";
phase3PeakAnalysisTableSavePath = "";
phase3OutputSaveStatus = "";
phase3PrefShowDetectedPeakPlot = "";
phase3PrefShowPeakResultsTable = "";
phase3PrefShowBaseline = "";
phase3PrefShowThreshold = "";
phase3PrefSynchroDetection = "";
phase3PrefDerivativeOutput = "";
phase3PrefSlopeOutput = "";
phase3PrefSlopeDisplay = "";
phase3PrefPeakAreaOutput = "";
phase3PrefDecayFitting = "";
phase3PrefSummaryOutput = "";
phase3PrefAutoDetectMode = "";
phase3PeakDirectionSource = "Batch_Spiky_Peak_Orientation_Setting";
phase3PeakDirectionFinal = spikyPeakOrientation;
phase3PrefTolerancePercent = "";
phase3PrefSmoothing = "";
phase3PrefThresholdStartPercent = "";
phase3PrefFullWidthOutput = "";
phase3PrefHalfWidthOutput = "";
phase3PrefFullWidthPercent1 = "";
phase3PrefFullWidthPercent2 = "";
phase3FirstSpikyFallbackUsed = "No";
phase3FirstSpikyFallbackInitialTolerance = "";
phase3FirstSpikyFallbackFinalTolerance = "";
phase3FirstSpikyFallbackFailedAttempts = "";
phase3FirstSpikyFallbackReason = "";
phase3FirstSpikyFallbackPassedAfterFallback = "No";
phase4PlotValuesStatus = "";
phase4PlotValuesTableName = "";
phase4PlotValuesSavePath = "";
phase4PlotValuesColumnCount = "";
phase4PlotValuesColumnHeadings = "";
phase4PlotValuesOpenWindowsBefore = "";
phase4PlotValuesOpenWindowsAfter = "";
phase4PlotValuesWarning = "";
phase4PlotValuesError = "";
phase4ExistingResultsBackupName = "";
phase4ExistingPlotValuesBackupName = "";
phase5ValidationStatus = "";
phase5PlotValuesSourceTableName = "";
phase5PredictedXColumn = "";
phase5PredictedYColumn = "";
phase5PredictionReason = "";
phase5AnchorCount = "";
phase5BaselineAnchorsSavePath = "";
phase5ValidationError = "";
phase5ValidationWarning = "";
phase5ValidationWindowMode = "points-based";
phase5LocalBaselineWindowPoints = 25;
phase5PeakExclusionWindowPoints = 5;
// Phase 5 validation uses raw-trace point windows for pass/fail so it
// does not assume seconds, minutes, frames, or any specific time unit.
phase5LocalBaselineTolerancePercent = 5;
phase5PeakSeparationPercent = 10;
phase5MedianTimeStep = "";
phase5LocalBaselineWindowTimeUnits = "";
phase5PeakExclusionWindowTimeUnits = "";
phase5RawXMin = "";
phase5RawXMax = "";
phase5RawYMin = "";
phase5RawYMax = "";
phase5AnchorYMin = "";
phase5AnchorYMax = "";
phase5RawYRange = "";
phase5PeakMarkerColumnX = "";
phase5PeakMarkerColumnY = "";
phase5CandidateDiagnostics = "";
phase5PeakCount = 0;
phase6FitStatus = "";
phase6FitFunction = "";
phase6PolynomialDegreeUsed = "";
phase6SupportedDegrees = "1,2,3,4";
phase6AnchorCount = "";
phase6CoefficientCount = "";
phase6CoefficientsText = "";
phase6CoefficientOrder = "Fit.p(0)=constant a; Fit.p(1)=linear b; Fit.p(2)=quadratic c; Fit.p(3)=cubic d; Fit.p(4)=quartic e";
phase6FitRMSE = "";
phase6FitRSquared = "";
phase6FittedBaselineMin = "";
phase6FittedBaselineMean = "";
phase6FittedBaselineMax = "";
phase6BaselineValueCount = "";
phase6FitWarning = "";
phase6FitError = "";
phase6CoefficientStabilityAbsLimit = 1e80;
phase6SourceAnchorArrayLength = "";
phase6FitInputAnchorCount = "";
phase6UnusedSourceAnchorEntries = "";
phase6FitInputArrayStatus = "";
phase6FitInputFirstTime = "";
phase6FitInputLastTime = "";
phase6FitInputFirstValue = "";
phase6FitInputLastValue = "";
phase6FitAnchorTimes = newArray(0);
phase6FitAnchorValues = newArray(0);
phase6AnchorFittedValues = newArray(0);
phase6AnchorResidualValues = newArray(0);
phase6AnchorPercentResidualValues = newArray(0);
phase6AnchorDiagnosticCount = "";
phase6AnchorResidualRMSE = "";
phase6AnchorResidualMaxAbs = "";
phase6AnchorResidualMaxPercentAbs = "";
phase6AnchorResidualWarnPercent = 5;
phase6AnchorResidualFailPercent = 10;
phase6RawTimeMin = "";
phase6RawTimeMax = "";
phase6AnchorTimeMin = "";
phase6AnchorTimeMax = "";
phase6RawRowsBeforeFirstAnchor = "";
phase6RawRowsAfterLastAnchor = "";
phase6RawPercentOutsideAnchorSupport = "";
phase6FirstFittedBaseline = "";
phase6LastFittedBaseline = "";
phase6FitReasonablenessStatus = "";
phase6FitReasonablenessError = "";
phase6FitReasonablenessWarning = "";
phase6AnchorTimeCoveragePercent = "";
phase6AnchorSpreadStatus = "";
phase6PolynomialDegreeFirstAttempted = "";
phase6PolynomialFallbackUsed = "";
phase6PolynomialFallbackReason = "";
phase6BaselineRangeWarning = "";
phase6BaselineEndpointWarning = "";
phase6BaselineNegativeCorrectionWarning = "";
phase6BaselineCurvatureWarning = "";
phase6PeakAwareAnchorTimingWarning = "";
phase6BaselineReliabilityClass = "Baseline_OK";
phase6BaselineReliabilityReason = "";
phase6DiagnosticTableSaveStatus = "";
phase6DiagnosticTableSavePath = "";
phase7CalculationStatus = "";
phase7RawValueCount = "";
phase7BaselineValueCount = "";
phase7DeltaFValueCount = "";
phase7DeltaFOverF0ValueCount = "";
phase7DeltaFOverF0PercentValueCount = "";
phase7RawBaselineAlignmentStatus = "";
phase7MinDeltaF = "";
phase7MeanDeltaF = "";
phase7MaxDeltaF = "";
phase7MinDeltaFOverF0 = "";
phase7MeanDeltaFOverF0 = "";
phase7MaxDeltaFOverF0 = "";
phase7MinDeltaFOverF0Percent = "";
phase7MeanDeltaFOverF0Percent = "";
phase7MaxDeltaFOverF0Percent = "";
phase7InvalidBaselineValueCount = "";
phase7InvalidCorrectedValueCount = "";
phase7FirstInvalidRow = "";
phase7FirstInvalidReason = "";
phase7MinimumSafeBaselineAbs = 1e-12;
phase7Warning = "";
phase7Error = "";
phase7BaselineTimes = newArray(0);
phase7BaselineValues = newArray(0);
phase7DeltaFValues = newArray(0);
phase7DeltaFOverF0Values = newArray(0);
phase7DeltaFOverF0PercentValues = newArray(0);
phase7CorrectedTraceTableSaveStatus = "";
phase7CorrectedTraceTableSavePath = "";
phase8PlotStatus = "";
phase8PlotWindowName = "";
phase8PlotSavePath = "";
phase8PlotWarning = "";
phase8PlotError = "";
phase8InPlotWarningStatus = "";
phase8InPlotWarningText = "";
phase8EndpointAnnotationThresholdPercent = 10;
phase8FirstRawTime = "";
phase8FirstAnchorTime = "";
phase9SecondSpikyStatus = "";
phase9CorrectedInputPlotName = "";
phase9CorrectedInputValueCount = "";
phase9CorrectedInputYMin = "";
phase9CorrectedInputYMax = "";
phase9CorrectedInputWarning = "";
phase9CorrectedInputError = "";
phase9SecondSpikyWasCalled = "No";
phase9ExistingResultsBackupName = "";
phase9SecondSpikyDetectedPeaksPlotName = "";
phase9SecondSpikyPeakAnalysisTableName = "";
phase9OpenWindowsAfterSpiky = "";
phase9SecondSpikyWarning = "";
phase9SecondSpikyError = "";
phase10FinalOutputStatus = "";
phase10FinalPeakTableSourceName = "";
phase10FinalPeakTableSavePath = "";
phase10FinalPeakTableRowCount = "";
phase10FinalPeakTableColumnCount = "";
phase10FinalPeakPlotSourceName = "";
phase10FinalPeakPlotSavePath = "";
phase10FinalOutputWarning = "";
phase10FinalOutputError = "";
phase11WindowCleanupStatus = "";
phase11WindowCleanupClosedWindows = "";
phase11WindowCleanupWarning = "";
phase11WindowCleanupKeptOpen = "";
finalDialogSampleName = "";
firstSampleSafeName = "";
runCompletionStatus = "Run_Metadata_Completed";

if ((runMode == "Test First Sample Only" || runMode == "Full Batch") && baselineCurveMethod != "Polynomial") {
	phase6FitStatus = "Phase6_Baseline_Method_Not_Supported";
	phase6FitError = "Unsupported baseline curve method selected for Phase 6: " + baselineCurveMethod + ". Only Polynomial is implemented in Phase 6.";
	phaseError = appendWarning(phaseError, phase6FitError);
	sampleStatuses[0] = phase6FitStatus;
	runCompletionStatus = phase6FitStatus;
}

if ((runMode == "Test First Sample Only" || runMode == "Full Batch") && baselineCurveMethod == "Polynomial" && phaseError == "") {
	phase13LoopSampleLimit = 1;
	if (runMode == "Full Batch")
		phase13LoopSampleLimit = fullBatchPlannedSampleCount;
	fullBatchSampleLoopStartTimeMs = getTime();
	if (runMode == "Full Batch") {
		showStatus("Starting Full Batch sample processing...");
		showProgress(0, phase13LoopSampleLimit);
	}

	for (phase13LoopSampleIndex = 0; phase13LoopSampleIndex < phase13LoopSampleLimit; phase13LoopSampleIndex++) {
	writeNonInteractiveProgress("Sample_Loop_Entered");
	resetPhase13PerSampleState();
	writeNonInteractiveProgress("Per_Sample_State_Reset");
	phase13CurrentSampleIndex = phase13LoopSampleIndex;
	firstSampleColumnName = headings[phase13CurrentSampleIndex + 1];
	phase2SourceSample = sampleUniqueNames[phase13CurrentSampleIndex];
	firstSampleSafeName = sampleFileNames[phase13CurrentSampleIndex];
	if (runMode == "Full Batch") {
		showStatus("Processing sample " + phase2SourceSample + " (" + (phase13CurrentSampleIndex + 1) + "/" + phase13LoopSampleLimit + ")...");
		showProgress(phase13CurrentSampleIndex, phase13LoopSampleLimit);
	}
	phase2PlotName = makeRawBaselineDetectionPlotName(firstSampleSafeName);
	phase2RawPlotCreateError = "";
	writeNonInteractiveProgress("Sample_Start");
	writeNonInteractiveProgress("Phase2_Raw_Plot_Create_Before");
	createFirstSampleRawPlot(timeColumnName, firstSampleColumnName, rowCount, phase2PlotName);
	writeNonInteractiveProgress("Phase2_Raw_Plot_Create_After");
	if (phase2RawPlotCreateError != "") {
		phaseError = phase2RawPlotCreateError;
		runCompletionStatus = "Phase2_Raw_Plot_Creation_Failed";
		sampleStatuses[phase13CurrentSampleIndex] = "Failed";
	} else {
	sampleStatuses[phase13CurrentSampleIndex] = "Phase2_Raw_Plot_Created";
	phase3RawPlotName = phase2PlotName;
	phase3SpikyDetectedPeaksPlotName = phase3RawPlotName + "-detected_peaks";
	phase3SpikyPeakAnalysisTableName = phase3RawPlotName + "-Peak analysis";
	phase3PeakDirectionSource = "Batch_Spiky_Peak_Orientation_Setting";
	phase3PeakDirectionFinal = spikyPeakOrientation;
	phase3SpikyStatus = "Phase3_Spiky_Started";

	if (!isOpen(phase3RawPlotName)) {
		phase3SpikyStatus = "Phase3_Raw_Plot_Not_Found";
		phaseError = "Phase 3 could not find the exact Phase 2 raw plot before calling Spiky.";
		runCompletionStatus = phase3SpikyStatus;
	} else {
		selectWindow(phase3RawPlotName);
		selectedPlotType = getInfo("window.type");
		if (!startsWith(selectedPlotType, "Plot")) {
			phase3SpikyStatus = "Phase3_Selected_Window_Not_Plot";
			phaseError = "The exact Phase 2 raw plot name was found, but the selected window was not a Plot.";
			runCompletionStatus = phase3SpikyStatus;
		} else {
			phase3TablesFolder = outputFolder + "Tables" + File.separator;
			phase3OutputSaveStatus = ensureDirectoryExists(plotsFolder, "Plots folder");
			tableRootStatus = ensureDirectoryExists(phase3TablesFolder, "Tables folder");
			phase3OutputSaveStatus = appendWarning(phase3OutputSaveStatus, tableRootStatus);
			phase2RawPlotSavePath = plotsFolder + firstSampleSafeName + "_raw_trace.png";
			phase2RawValuesTableSavePath = phase3TablesFolder + firstSampleSafeName + "_raw_values" + outputTableExtension;
			if (File.exists(plotsFolder))
				phase2RawPlotSaveStatus = savePhase2RawPlotAsPngPreserveWindow(phase3RawPlotName, phase2RawPlotSavePath);
			else
				phase2RawPlotSaveStatus = "Skipped raw trace plot save because output folder was not available.";
			if (File.exists(phase3TablesFolder))
				phase2RawValuesSaveStatus = savePhase2RawValuesTable(phase2RawValuesTableSavePath, phase2SourceSample, timeColumnName, firstSampleColumnName, rowCount);
			else
				phase2RawValuesSaveStatus = "Skipped raw values table save because output folder was not available.";
			phase3OutputSaveStatus = appendWarning(phase3OutputSaveStatus, phase2RawPlotSaveStatus);
			phase3OutputSaveStatus = appendWarning(phase3OutputSaveStatus, phase2RawValuesSaveStatus);
			phase3ExistingResultsBackupName = protectExistingResultsTable();
			phase3FirstSpikyFallbackInitialTolerance = firstSpikyTolerancePercent;
			phase3FirstSpikyFallbackFinalTolerance = firstSpikyTolerancePercent;
			phase3FirstSpikyFallbackFailedAttempts = "";
			phase3FirstSpikyFallbackReason = "";
			phase3FirstSpikyFallbackPassedAfterFallback = "No";
			phase3FirstSpikyFallbackUsed = "No";
			phase3FallbackTolerances = newArray(firstSpikyTolerancePercent, 15, 10, 7.5, 5);
			phase3TriedFallbackTolerances = "";
			detectedPeaksFound = false;
			peakAnalysisTableFound = false;
			phase3FallbackAttemptNumber = 0;
			for (phase3FallbackIndex = 0; phase3FallbackIndex < lengthOf(phase3FallbackTolerances); phase3FallbackIndex++) {
				phase3AttemptTolerance = phase3FallbackTolerances[phase3FallbackIndex];
				if (phase3AttemptTolerance > firstSpikyTolerancePercent)
					continue;
				if (phase3FallbackToleranceAlreadyTried(phase3TriedFallbackTolerances, phase3AttemptTolerance))
					continue;
				phase3TriedFallbackTolerances = appendWarning(phase3TriedFallbackTolerances, formatPhase6DiagnosticNumber(phase3AttemptTolerance));
				phase3FallbackAttemptNumber++;
				if (phase3FallbackAttemptNumber > 1) {
					phase3FirstSpikyFallbackUsed = "Yes";
					closePhase3FallbackAttemptWindows();
				}

				setConservativeSpikyPreferences(phase3AttemptTolerance, firstSpikySmoothing);
				phase3PrefShowDetectedPeakPlot = call("ij.Prefs.get", "SPIKY.PeakAna.SPWHDP", "");
				phase3PrefShowPeakResultsTable = call("ij.Prefs.get", "SPIKY.PeakAna.ShowSumTable", "");
				phase3PrefShowBaseline = call("ij.Prefs.get", "SPIKY.PeakAna.Dbaseline", "");
				phase3PrefShowThreshold = call("ij.Prefs.get", "SPIKY.PeakAna.Dthreshold", "");
				phase3PrefSynchroDetection = call("ij.Prefs.get", "SPIKY.PeakAna.ASfS", "");
				phase3PrefDerivativeOutput = call("ij.Prefs.get", "SPIKY.PeakAna.DerivativeSig", "");
				phase3PrefSlopeOutput = call("ij.Prefs.get", "SPIKY.PeakAna.Vmax", "");
				phase3PrefSlopeDisplay = call("ij.Prefs.get", "SPIKY.PeakAna.DVmax", "");
				phase3PrefPeakAreaOutput = call("ij.Prefs.get", "SPIKY.PeakAna.AUP", "");
				phase3PrefDecayFitting = call("ij.Prefs.get", "SPIKY.PeakAna.decay", "");
				phase3PrefSummaryOutput = call("ij.Prefs.get", "SPIKY.PeakAna.summarize", "");
				phase3PrefAutoDetectMode = call("ij.Prefs.get", "SPIKY.PeakAna.autoDetect", "");
				phase3PrefTolerancePercent = call("ij.Prefs.get", "SPIKY.PeakAna.tolerance", "");
				phase3PrefSmoothing = call("ij.Prefs.get", "SPIKY.PeakAna.smooth", "");
				phase3PrefThresholdStartPercent = call("ij.Prefs.get", "SPIKY.PeakAna.TTP.thresholdDetectionDEbPeak", "");
				phase3PrefFullWidthOutput = call("ij.Prefs.get", "SPIKY.PeakAna.FW", "");
				phase3PrefHalfWidthOutput = call("ij.Prefs.get", "SPIKY.PeakAna.HW", "");
				phase3PrefFullWidthPercent1 = call("ij.Prefs.get", "SPIKY.PeakAna.x1P", "");
				phase3PrefFullWidthPercent2 = call("ij.Prefs.get", "SPIKY.PeakAna.x2P", "");

				selectWindow(phase3RawPlotName);
				phase3SpikyWasCalled = "Yes";
				writeNonInteractiveProgress("Phase3_FirstSpiky_Attempt_Tolerance_" + formatPhase6DiagnosticNumber(phase3AttemptTolerance));
				runSpikyBatchPeakAnalysis(spikyMacroPath, spikyPeakOrientation, phase3RawPlotName);
				wait(500);

				phase3OpenWindowsAfterSpiky = getOpenWindowTitlesText();
				detectedPeaksFound = isOpen(phase3SpikyDetectedPeaksPlotName);
				peakAnalysisTableFound = isOpen(phase3SpikyPeakAnalysisTableName);
				phase3FirstSpikyFallbackFinalTolerance = phase3AttemptTolerance;
				if (detectedPeaksFound && peakAnalysisTableFound)
					break;
				if (!detectedPeaksFound && !peakAnalysisTableFound)
					phase3FirstSpikyFallbackReason = "No_Raw_Peaks";
				else
					phase3FirstSpikyFallbackReason = "Partial_FirstSpiky_Output";
				phase3FirstSpikyFallbackFailedAttempts = appendWarning(phase3FirstSpikyFallbackFailedAttempts, formatPhase6DiagnosticNumber(phase3AttemptTolerance));
			}
			if (phase3FirstSpikyFallbackUsed == "Yes" && detectedPeaksFound && peakAnalysisTableFound)
				phase3FirstSpikyFallbackPassedAfterFallback = "Yes";

			if (detectedPeaksFound && peakAnalysisTableFound) {
				phase3SpikyStatus = "Phase3_Spiky_Raw_Peak_Analysis_Captured";
				runCompletionStatus = phase3SpikyStatus;

				phase4PlotValuesStatus = "Phase4_PlotValues_Started";
				phase4PlotValuesOpenWindowsBefore = getOpenWindowTitlesText();
				phase4ExistingResultsBackupName = protectOpenTableWindow("Results", "PreExisting_Results_Before_Phase4_PlotValues_" + timestamp);
				phase4ExistingPlotValuesBackupName = protectOpenTableWindow("Plot Values", "PreExisting_Plot_Values_Before_Phase4_" + timestamp);

				if (!isOpen(phase3SpikyDetectedPeaksPlotName)) {
					phase4PlotValuesStatus = "Phase4_Detected_Peaks_Plot_Not_Found";
					phase4PlotValuesError = "Phase 4 could not find the exact detected-peaks plot: " + phase3SpikyDetectedPeaksPlotName;
					runCompletionStatus = phase4PlotValuesStatus;
				} else {
					selectWindow(phase3SpikyDetectedPeaksPlotName);
					phase4DetectedPeaksWindowType = getInfo("window.type");
					if (!startsWith(phase4DetectedPeaksWindowType, "Plot")) {
						phase4PlotValuesStatus = "Phase4_Detected_Peaks_Window_Not_Plot";
						phase4PlotValuesError = "Phase 4 selected the detected-peaks window, but it was not a Plot.";
						runCompletionStatus = phase4PlotValuesStatus;
					} else {
						Plot.showValues();
						wait(500);
						phase4PlotValuesOpenWindowsAfter = getOpenWindowTitlesText();

						phase4PlotValuesTableName = findReadablePlotValuesTable(phase4PlotValuesOpenWindowsBefore);
						if (phase4PlotValuesTableName == "") {
							phase4PlotValuesStatus = "Phase4_PlotValues_Table_Not_Found";
							phase4PlotValuesError = "Plot.showValues did not create or expose a readable Plot Values table.";
							phase4PlotValuesError = appendWarning(phase4PlotValuesError, "Expected source plot: " + phase3SpikyDetectedPeaksPlotName);
							phase4PlotValuesError = appendWarning(phase4PlotValuesError, "Open windows before Plot.showValues: " + phase4PlotValuesOpenWindowsBefore);
							phase4PlotValuesError = appendWarning(phase4PlotValuesError, "Open windows after Plot.showValues: " + phase4PlotValuesOpenWindowsAfter);
							runCompletionStatus = phase4PlotValuesStatus;
						} else {
							selectWindow(phase4PlotValuesTableName);
							phase4PlotValuesColumnHeadings = Table.headings;
							phase4PlotValuesColumnCount = countDelimitedFields(phase4PlotValuesColumnHeadings, "\t");
							phase4PlotValuesSavePath = phase3TablesFolder + firstSampleSafeName + "_Phase4_FirstSpiky_PlotValues" + outputTableExtension;
							phase4SaveStatus = savePhase4PlotValuesTable(phase4PlotValuesTableName, phase4PlotValuesSavePath);
							if (phase4SaveStatus == "") {
								phase4PlotValuesStatus = "Phase4_PlotValues_Exported";
								runCompletionStatus = phase4PlotValuesStatus;

								phase5ValidationStatus = "Phase5_Validation_Started";
								phase5BaselineAnchorsSavePath = phase3TablesFolder + firstSampleSafeName + "_Phase5_BaselineAnchors" + outputTableExtension;
								phase5PeakMarkerColumnX = "X1";
								phase5PeakMarkerColumnY = "Y1";
								phase5PredictedSeriesIndex = predictBaselineSeriesIndex(phase3PrefShowThreshold, phase3PrefSlopeOutput, phase3PrefSlopeDisplay, phase3PrefShowBaseline);
								if (phase5PredictedSeriesIndex < 0) {
									phase5ValidationStatus = "Phase5_Baseline_Prediction_Failed";
									phase5ValidationError = "Baseline display was not enabled, so no baseline-marker Plot Values dataset can be predicted.";
									runCompletionStatus = phase5ValidationStatus;
								} else {
									phase5PredictedXColumn = "X" + phase5PredictedSeriesIndex;
									phase5PredictedYColumn = "Y" + phase5PredictedSeriesIndex;
									phase5PredictionReason = "Predicted from Spiky detected-peaks plot order and applied display settings.";
									phase5CandidateDiagnostics = buildXYPairDiagnostics(phase4PlotValuesColumnHeadings);

									phase5PlotValuesSourceTableName = resolveLivePlotValuesSourceTable(phase4PlotValuesTableName);
									if (phase5PlotValuesSourceTableName == "") {
										phase5ValidationStatus = "Phase5_PlotValues_Source_Table_Not_Readable";
										phase5ValidationError = "Could not find the live Phase 4 Plot Values table for Phase 5 validation. The saved Phase 4 export is formatted for traceability only and is not used as a Phase 5 source.";
										runCompletionStatus = phase5ValidationStatus;
									} else {
										selectWindow(activeTableTitle);
										phase5RawTimes = newArray(rowCount);
										phase5RawValues = newArray(rowCount);
										phase5TimeSteps = newArray(rowCount - 1);
										phase5TimeStepCount = 0;
										phase5RawReadError = "";

										for (phase5RawRow = 0; phase5RawRow < rowCount; phase5RawRow++) {
											phase5RawTime = Table.get(timeColumnName, phase5RawRow);
											phase5RawValue = Table.get(firstSampleColumnName, phase5RawRow);
											if (isNaN(phase5RawTime) || isNaN(phase5RawValue)) {
												phase5RawReadError = "Raw trace contained nonnumeric Time or sample value at row " + (phase5RawRow + 1) + ".";
												break;
											}
											phase5RawTimes[phase5RawRow] = phase5RawTime;
											phase5RawValues[phase5RawRow] = phase5RawValue;
											if (phase5RawRow == 0) {
												phase5RawXMin = phase5RawTime;
												phase5RawXMax = phase5RawTime;
												phase5RawYMin = phase5RawValue;
												phase5RawYMax = phase5RawValue;
											} else {
												if (phase5RawTime < phase5RawXMin)
													phase5RawXMin = phase5RawTime;
												if (phase5RawTime > phase5RawXMax)
													phase5RawXMax = phase5RawTime;
												if (phase5RawValue < phase5RawYMin)
													phase5RawYMin = phase5RawValue;
												if (phase5RawValue > phase5RawYMax)
													phase5RawYMax = phase5RawValue;
												phase5Step = abs(phase5RawTime - phase5RawTimes[phase5RawRow - 1]);
												if (phase5Step > 0) {
													phase5TimeSteps[phase5TimeStepCount] = phase5Step;
													phase5TimeStepCount++;
												}
											}
										}

										if (phase5RawReadError != "") {
											phase5ValidationStatus = "Phase5_Raw_Trace_Not_Readable";
											phase5ValidationError = phase5RawReadError;
											runCompletionStatus = phase5ValidationStatus;
										} else {
											phase5RawYRange = phase5RawYMax - phase5RawYMin;
											if (phase5TimeStepCount > 0) {
												phase5MedianTimeStep = calculateMedianFromPrefix(phase5TimeSteps, phase5TimeStepCount);
												phase5LocalBaselineWindowTimeUnits = phase5MedianTimeStep * phase5LocalBaselineWindowPoints;
												phase5PeakExclusionWindowTimeUnits = phase5MedianTimeStep * phase5PeakExclusionWindowPoints;
											}

											selectWindow(phase5PlotValuesSourceTableName);
											phase5PlotValuesHeadings = Table.headings;
											if (!columnExistsInHeadings(phase5PlotValuesHeadings, phase5PredictedXColumn) || !columnExistsInHeadings(phase5PlotValuesHeadings, phase5PredictedYColumn)) {
												phase5ValidationStatus = "Phase5_Predicted_Columns_Missing";
												phase5ValidationError = "Predicted baseline columns were not found in Plot Values: " + phase5PredictedXColumn + "/" + phase5PredictedYColumn;
												runCompletionStatus = phase5ValidationStatus;
											} else if (!columnExistsInHeadings(phase5PlotValuesHeadings, phase5PeakMarkerColumnX) || !columnExistsInHeadings(phase5PlotValuesHeadings, phase5PeakMarkerColumnY)) {
												phase5ValidationStatus = "Phase5_Peak_Marker_Columns_Missing";
												phase5ValidationError = "Peak marker columns were not found in Plot Values: " + phase5PeakMarkerColumnX + "/" + phase5PeakMarkerColumnY;
												runCompletionStatus = phase5ValidationStatus;
											} else if (phase5RawYRange <= 0) {
												phase5ValidationStatus = "Phase5_Raw_Range_Invalid";
												phase5ValidationError = "Raw fluorescence range was zero or invalid.";
												runCompletionStatus = phase5ValidationStatus;
											} else {
												phase5PlotValuesRowCount = Table.size;
												phase5AnchorTimes = newArray(phase5PlotValuesRowCount);
												phase5AnchorValues = newArray(phase5PlotValuesRowCount);
												phase5PeakTimes = newArray(phase5PlotValuesRowCount);
												phase5PeakValues = newArray(phase5PlotValuesRowCount);
												phase5AnchorCountNumeric = 0;
												phase5PeakCountNumeric = 0;
												phase5PairingError = "";

												for (phase5PlotValuesRow = 0; phase5PlotValuesRow < phase5PlotValuesRowCount; phase5PlotValuesRow++) {
													phase5AnchorTime = Table.get(phase5PredictedXColumn, phase5PlotValuesRow);
													phase5AnchorValue = Table.get(phase5PredictedYColumn, phase5PlotValuesRow);
													if (isNaN(phase5AnchorTime) && isNaN(phase5AnchorValue)) {
													} else if (isNaN(phase5AnchorTime) || isNaN(phase5AnchorValue)) {
														phase5PairingError = "Predicted anchor row " + (phase5PlotValuesRow + 1) + " had only one numeric X/Y value.";
														break;
													} else {
														phase5AnchorTimes[phase5AnchorCountNumeric] = phase5AnchorTime;
														phase5AnchorValues[phase5AnchorCountNumeric] = phase5AnchorValue;
														if (phase5AnchorCountNumeric == 0) {
															phase5AnchorYMin = phase5AnchorValue;
															phase5AnchorYMax = phase5AnchorValue;
														} else {
															if (phase5AnchorValue < phase5AnchorYMin)
																phase5AnchorYMin = phase5AnchorValue;
															if (phase5AnchorValue > phase5AnchorYMax)
																phase5AnchorYMax = phase5AnchorValue;
														}
														phase5AnchorCountNumeric++;
													}

													phase5PeakTime = Table.get(phase5PeakMarkerColumnX, phase5PlotValuesRow);
													phase5PeakValue = Table.get(phase5PeakMarkerColumnY, phase5PlotValuesRow);
													if (!isNaN(phase5PeakTime) && !isNaN(phase5PeakValue)) {
														phase5PeakTimes[phase5PeakCountNumeric] = phase5PeakTime;
														phase5PeakValues[phase5PeakCountNumeric] = phase5PeakValue;
														phase5PeakCountNumeric++;
													}
												}

												phase5AnchorCount = phase5AnchorCountNumeric;
												phase5PeakCount = phase5PeakCountNumeric;
												if (phase5PairingError != "") {
													phase5ValidationStatus = "Phase5_Predicted_Anchor_Values_Not_Paired";
													phase5ValidationError = phase5PairingError;
													runCompletionStatus = phase5ValidationStatus;
												} else if (phase5AnchorCountNumeric <= 0) {
													phase5ValidationStatus = "Phase5_Anchor_Count_Too_Low";
													phase5ValidationError = "Predicted baseline dataset contained zero paired numeric anchors.";
													runCompletionStatus = phase5ValidationStatus;
												} else {
													phase5ValidationError = validateBaselineAnchors(phase5AnchorTimes, phase5AnchorValues, phase5AnchorCountNumeric, phase5RawTimes, phase5RawValues, rowCount, phase5PeakTimes, phase5PeakValues, phase5PeakCountNumeric, phase5RawXMin, phase5RawXMax, phase5RawYMin, phase5RawYMax, phase5RawYRange, phase5LocalBaselineWindowPoints, phase5PeakExclusionWindowPoints, phase5LocalBaselineTolerancePercent, phase5PeakSeparationPercent);
													if (phase5ValidationError == "") {
														phase5AnchorCountNumeric = phase5AnchorCount;
														phase5AnchorExportText = buildBaselineAnchorsTableText(phase5AnchorTimes, phase5AnchorValues, phase5AnchorCountNumeric, phase5PredictedXColumn, phase5PredictedYColumn);
														File.saveString(phase5AnchorExportText, phase5BaselineAnchorsSavePath);
														if (File.exists(phase5BaselineAnchorsSavePath)) {
															phase5ValidationStatus = "Phase5_Baseline_Anchors_Validated";
															runCompletionStatus = phase5ValidationStatus;
															phase6FitStatus = "Phase6_Baseline_Fit_Started";
															phase6DiagnosticTableSavePath = phase3TablesFolder + firstSampleSafeName + "_Phase6_Baseline_Fit_Diagnostics" + outputTableExtension;
															phase6FitError = runPhase6PolynomialBaselineFit(phase5AnchorTimes, phase5AnchorValues, phase5AnchorCountNumeric, phase5RawTimes, phase5RawValues, rowCount, selectedPolynomialDegree);
															if (phase6FitError != "") {
																phase6FitReasonablenessStatus = "Failed";
																phase6FitReasonablenessError = phase6FitError;
															}
															if (phase6AnchorDiagnosticCount == phase5AnchorCountNumeric) {
																phase6DiagnosticTableSaveError = savePhase6BaselineFitDiagnosticsTable(phase6DiagnosticTableSavePath, phase2SourceSample, phase6FitAnchorTimes, phase6FitAnchorValues, phase6AnchorFittedValues, phase6AnchorResidualValues, phase6AnchorPercentResidualValues, phase6AnchorDiagnosticCount, phase5PredictedXColumn, phase5PredictedYColumn, phase6PolynomialDegreeUsed);
																if (phase6DiagnosticTableSaveError == "") {
																	phase6DiagnosticTableSaveStatus = "Saved";
																} else {
																	phase6DiagnosticTableSaveStatus = "Failed";
																	phase6FitError = appendWarning(phase6FitError, phase6DiagnosticTableSaveError);
																}
															} else if (phase6FitError == "") {
																phase6DiagnosticTableSaveStatus = "Failed";
																phase6FitError = "Phase 6 anchor-fit diagnostics were incomplete after fitting; expected " + phase5AnchorCountNumeric + " rows but found " + phase6AnchorDiagnosticCount + ".";
															} else {
																phase6DiagnosticTableSaveStatus = "Not_Created_Fit_Failed_Before_Complete_Anchor_Diagnostics";
															}
															if (phase6FitError == "") {
																phase6FitStatus = "Phase6_Polynomial_Baseline_Fit_Completed";
																runCompletionStatus = phase6FitStatus;
																phase7CalculationStatus = "Phase7_Calculation_Started";
																phase7Error = runPhase7CorrectedTraceCalculation(phase5RawTimes, phase5RawValues, rowCount, phase6BaselineValues, phase6BaselineValueCount);
																if (phase7Error == "") {
																	phase7CalculationStatus = "Phase7_Corrected_Trace_Calculation_Completed";
																	runCompletionStatus = phase7CalculationStatus;
																	phase7CorrectedTraceTableSavePath = phase3TablesFolder + firstSampleSafeName + "_Phase7_Corrected_Trace" + outputTableExtension;
																	phase7CorrectedTraceExportError = savePhase7CorrectedTraceTable(phase7CorrectedTraceTableSavePath, phase2SourceSample, phase5RawTimes, phase5RawValues, phase7BaselineValues, phase7DeltaFValues, phase7DeltaFOverF0Values, phase7DeltaFOverF0PercentValues, rowCount);
																	if (phase7CorrectedTraceExportError == "") {
																		phase7CorrectedTraceTableSaveStatus = "Saved";
																		appendPhase15TimeSeriesRowsForCurrentSample();
																		phase8PlotStatus = "Started";
																		phase8PlotWindowName = firstSampleSafeName + " Baseline Reconstruction";
																		phase8PlotSavePath = plotsFolder + firstSampleSafeName + "_Baseline_Reconstruction.png";
																		phase8ValidationError = validatePhase8BaselineReconstructionInputs(phase5RawTimes, phase5RawValues, rowCount, phase6FitAnchorTimes, phase6FitAnchorValues, phase6FitInputAnchorCount, phase6BaselineValues, phase6BaselineValueCount);
																		if (phase8ValidationError == "") {
																			phase8PlotWarning = preparePhase8EndpointWarningAndAnnotation(phase5RawTimes, phase6FitAnchorTimes);
																			phase8PlotError = createPhase8BaselineReconstructionPlot(phase8PlotWindowName, phase2SourceSample, phase5RawTimes, phase5RawValues, rowCount, phase6FitAnchorTimes, phase6FitAnchorValues, phase6FitInputAnchorCount, phase6BaselineValues, phase6BaselineValueCount);
																			if (phase8PlotError == "") {
																				phase8PlotSaveError = savePhase8BaselineReconstructionPlotAsPng(phase8PlotWindowName, phase8PlotSavePath);
																				if (phase8PlotSaveError == "") {
																					phase8PlotStatus = "Saved";
																					runCompletionStatus = "Phase8_Baseline_Reconstruction_Plot_Saved";
																					phase9SecondSpikyStatus = "Phase9_SecondSpiky_Started";
																					phase9CorrectedInputPlotName = firstSampleSafeName + "_DeltaF_over_F0_SecondSpiky_Input";
																					phase9SecondSpikyDetectedPeaksPlotName = phase9CorrectedInputPlotName + "-detected_peaks";
																					phase9SecondSpikyPeakAnalysisTableName = phase9CorrectedInputPlotName + "-Peak analysis";
																					phase9ValidationError = validatePhase9SecondSpikyInputs(phase5RawTimes, phase7DeltaFOverF0Values, rowCount);
																					if (phase9ValidationError == "") {
																						phase9CorrectedInputError = createPhase9CorrectedDeltaFOverF0Plot(phase9CorrectedInputPlotName, phase5RawTimes, phase7DeltaFOverF0Values, rowCount);
																						if (phase9CorrectedInputError == "") {
																							selectWindow(phase9CorrectedInputPlotName);
																							phase9SelectedWindowType = getInfo("window.type");
																							if (!startsWith(phase9SelectedWindowType, "Plot")) {
																								phase9SecondSpikyStatus = "Failed";
																								phase9SecondSpikyError = "Phase 9 selected the corrected DeltaF/F0 input window, but it was not a Plot: " + phase9SelectedWindowType;
																								runCompletionStatus = "Failed";
																							} else {
																								phase9ExistingResultsBackupName = protectOpenTableWindow("Results", "PreExisting_Results_Before_Phase9_SecondSpiky_" + timestamp);
																								setConservativeSpikyPreferences(secondSpikyTolerancePercent, secondSpikySmoothing);
																								selectWindow(phase9CorrectedInputPlotName);
																								phase9SecondSpikyWasCalled = "Yes";
																								runSpikyBatchPeakAnalysis(spikyMacroPath, spikyPeakOrientation, phase9CorrectedInputPlotName);
																								wait(500);
																								phase9OpenWindowsAfterSpiky = getOpenWindowTitlesText();
																								phase9DetectedPeaksFound = isOpen(phase9SecondSpikyDetectedPeaksPlotName);
																								phase9PeakAnalysisTableFound = isOpen(phase9SecondSpikyPeakAnalysisTableName);
																								if (phase9DetectedPeaksFound && phase9PeakAnalysisTableFound) {
																									phase9SecondSpikyStatus = "Phase9_SecondSpiky_Output_Captured";
																									runCompletionStatus = phase9SecondSpikyStatus;
																									phase10FinalOutputStatus = "Phase10_Final_Output_Started";
																									phase10FinalPeakTableSourceName = phase9SecondSpikyPeakAnalysisTableName;
																									phase10FinalPeakPlotSourceName = phase9SecondSpikyDetectedPeaksPlotName;
																									if (runMode == "Full Batch")
																										phase10FinalPeakTableSavePath = phase3TablesFolder + firstSampleSafeName + "_Peak_Analysis_After_Baseline_Correction" + outputTableExtension;
																									else
																										phase10FinalPeakTableSavePath = outputFolder + "Peak_Analysis_After_Baseline_Correction" + outputTableExtension;
																									phase10FinalPeakPlotSavePath = plotsFolder + firstSampleSafeName + "_Final_Peak_Analysis.png";
																									phase10ValidationError = validatePhase10FinalOutputInputs();
																									if (phase10ValidationError == "") {
																										phase10TableSaveError = savePhase10FinalPeakAnalysisTable(phase10FinalPeakTableSourceName, phase10FinalPeakTableSavePath, phase2SourceSample, "DeltaF_over_F0_SecondSpiky");
																										if (phase10TableSaveError != "")
																											phase10FinalOutputError = appendWarning(phase10FinalOutputError, phase10TableSaveError);
																										phase10PlotSaveError = savePhase10FinalPeakAnalysisPlotAsPng(phase10FinalPeakPlotSourceName, phase10FinalPeakPlotSavePath);
																										if (phase10PlotSaveError != "")
																											phase10FinalOutputError = appendWarning(phase10FinalOutputError, phase10PlotSaveError);
																										if (phase10FinalOutputError == "") {
																											phase10FinalOutputStatus = "Phase10_Final_Output_Saved";
																											runCompletionStatus = phase10FinalOutputStatus;
																											appendPhase15FinalPeakRowsForCurrentSample();
																										} else {
																											phase10FinalOutputStatus = "Failed";
																											runCompletionStatus = "Failed";
																										}
																									} else {
																										phase10FinalOutputStatus = "Failed";
																										phase10FinalOutputError = phase10ValidationError;
																										runCompletionStatus = "Failed";
																									}
																								} else {
																									phase9SecondSpikyStatus = "Failed";
																									if (!phase9DetectedPeaksFound)
																										phase9SecondSpikyError = appendWarning(phase9SecondSpikyError, "Expected second-Spiky detected-peaks plot was not found: " + phase9SecondSpikyDetectedPeaksPlotName);
																									if (!phase9PeakAnalysisTableFound)
																										phase9SecondSpikyError = appendWarning(phase9SecondSpikyError, "Expected second-Spiky peak-analysis table was not found: " + phase9SecondSpikyPeakAnalysisTableName);
																									phase9SecondSpikyError = appendWarning(phase9SecondSpikyError, "Direct Spiky file execution attempted: " + phase3SpikyCommand + "; selected Spiky path: " + spikyMacroPath + "; selected batch orientation: " + spikyPeakOrientation);
																									phase9SecondSpikyError = appendWarning(phase9SecondSpikyError, "Open windows after Phase 9 Spiky: " + phase9OpenWindowsAfterSpiky);
																									runCompletionStatus = "Failed";
																								}
																							}
																						} else {
																							phase9SecondSpikyStatus = "Failed";
																							runCompletionStatus = "Failed";
																						}
																					} else {
																						phase9SecondSpikyStatus = "Failed";
																						phase9CorrectedInputError = phase9ValidationError;
																						runCompletionStatus = "Failed";
																					}
																				} else {
																					phase8PlotStatus = "Failed";
																					phase8PlotError = phase8PlotSaveError;
																					runCompletionStatus = "Failed";
																				}
																			} else {
																				phase8PlotStatus = "Failed";
																				runCompletionStatus = "Failed";
																			}
																		} else {
																			phase8PlotStatus = "Failed";
																			phase8PlotError = phase8ValidationError;
																			runCompletionStatus = "Failed";
																		}
																	} else {
																		phase7CorrectedTraceTableSaveStatus = "Failed";
																		phase7Error = phase7CorrectedTraceExportError;
																		phase7CalculationStatus = "Phase7_Corrected_Trace_Table_Export_Failed";
																		runCompletionStatus = "Failed";
																	}
																} else {
																	phase7CalculationStatus = "Phase7_Corrected_Trace_Calculation_Failed";
																	runCompletionStatus = "Failed";
																}
															} else {
																phase6FitStatus = "Phase6_Polynomial_Baseline_Fit_Failed";
																runCompletionStatus = phase6FitStatus;
															}
														} else {
															phase5ValidationStatus = "Phase5_Baseline_Anchor_Save_Failed";
															phase5ValidationError = "Baseline anchor table was not created: " + phase5BaselineAnchorsSavePath;
															runCompletionStatus = phase5ValidationStatus;
														}
													} else {
														phase5ValidationStatus = "Phase5_Baseline_Anchor_Validation_Failed";
														runCompletionStatus = phase5ValidationStatus;
													}
												}
											}
										}
									}
								}
							} else {
								phase4PlotValuesStatus = "Phase4_PlotValues_Save_Failed";
								phase4PlotValuesError = phase4SaveStatus;
								runCompletionStatus = phase4PlotValuesStatus;
							}
						}
					}
				}

				if (phase4PlotValuesError != "")
					phaseError = appendWarning(phaseError, phase4PlotValuesError);
				if (phase4PlotValuesWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase4PlotValuesWarning);
				if (phase5ValidationError != "")
					phaseError = appendWarning(phaseError, phase5ValidationError);
				if (phase5ValidationWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase5ValidationWarning);
				if (phase6FitError != "")
					phaseError = appendWarning(phaseError, phase6FitError);
				if (phase6FitWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase6FitWarning);
				if (phase7Error != "")
					phaseError = appendWarning(phaseError, phase7Error);
				if (phase7Warning != "")
					phaseWarning = appendWarning(phaseWarning, phase7Warning);
				if (phase8PlotError != "")
					phaseError = appendWarning(phaseError, phase8PlotError);
				if (phase8PlotWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase8PlotWarning);
				if (phase9CorrectedInputError != "")
					phaseError = appendWarning(phaseError, phase9CorrectedInputError);
				if (phase9CorrectedInputWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase9CorrectedInputWarning);
				if (phase9SecondSpikyError != "")
					phaseError = appendWarning(phaseError, phase9SecondSpikyError);
				if (phase9SecondSpikyWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase9SecondSpikyWarning);
				if (phase10FinalOutputError != "")
					phaseError = appendWarning(phaseError, phase10FinalOutputError);
				if (phase10FinalOutputWarning != "")
					phaseWarning = appendWarning(phaseWarning, phase10FinalOutputWarning);

				phase3DetectedPeaksPlotSavePath = plotsFolder + firstSampleSafeName + "_Phase3_FirstSpiky_DetectedPeaks.png";
				phase3PeakAnalysisTableSavePath = phase3TablesFolder + firstSampleSafeName + "_Phase3_FirstSpiky_PeakAnalysis" + outputTableExtension;
				if (File.exists(plotsFolder))
					plotSaveStatus = savePlotWindowAsPng(phase3SpikyDetectedPeaksPlotName, phase3DetectedPeaksPlotSavePath);
				else
					plotSaveStatus = "Skipped detected-peaks plot save because output folder was not available.";
				if (File.exists(phase3TablesFolder))
					tableSaveStatus = savePhase3PeakAnalysisTable(phase3SpikyPeakAnalysisTableName, phase3PeakAnalysisTableSavePath);
				else
					tableSaveStatus = "Skipped peak-analysis table save because output folder was not available.";
				phase3OutputSaveStatus = appendWarning(phase3OutputSaveStatus, plotSaveStatus);
				phase3OutputSaveStatus = appendWarning(phase3OutputSaveStatus, tableSaveStatus);
				if (phase3OutputSaveStatus == "")
					phase3OutputSaveStatus = "Saved";
				else
					phaseWarning = appendWarning(phaseWarning, phase3OutputSaveStatus);
				if (phase3FirstSpikyFallbackUsed == "Yes") {
					phase3FallbackSummaryText = buildPhase3FirstSpikyFallbackSummary();
					phase3OutputSaveStatus = appendWarning(phase3OutputSaveStatus, phase3FallbackSummaryText);
					phaseWarning = appendWarning(phaseWarning, phase3FallbackSummaryText);
				}
			} else {
				phase3SpikyStatus = "Phase3_Spiky_Output_Missing";
				phaseError = "";
				if (!detectedPeaksFound && !peakAnalysisTableFound) {
					phaseError = appendWarning(phaseError, "No raw peaks detected. Raw-only QC artifacts were exported when possible: " + phase2RawPlotSavePath + " | " + phase2RawValuesTableSavePath);
					phase5ValidationStatus = "Phase5_No_Raw_Peaks_Detected";
					phase5ValidationError = "No raw peaks detected";
				} else if (!detectedPeaksFound)
					phaseError = appendWarning(phaseError, "Expected detected-peaks plot was not found: " + phase3SpikyDetectedPeaksPlotName);
				if (!peakAnalysisTableFound)
					phaseError = appendWarning(phaseError, "Expected peak-analysis table was not found: " + phase3SpikyPeakAnalysisTableName);
				phaseError = appendWarning(phaseError, "Direct Spiky file execution attempted: " + phase3SpikyCommand + "; selected Spiky path: " + spikyMacroPath + "; selected batch orientation: " + spikyPeakOrientation);
				phaseError = appendWarning(phaseError, "Open windows after Spiky: " + phase3OpenWindowsAfterSpiky);
				phaseError = appendWarning(phaseError, buildPhase3FirstSpikyFallbackSummary());
				runCompletionStatus = phase3SpikyStatus;
			}
		}
	}
	}
	if (phase3SpikyStatus != "")
		sampleStatuses[phase13CurrentSampleIndex] = phase3SpikyStatus;
	if (phase4PlotValuesStatus != "")
		sampleStatuses[phase13CurrentSampleIndex] = phase4PlotValuesStatus;
	if (phase5ValidationStatus != "")
		sampleStatuses[phase13CurrentSampleIndex] = phase5ValidationStatus;
	if (phase6FitStatus != "")
		sampleStatuses[phase13CurrentSampleIndex] = phase6FitStatus;
	if (phase7CalculationStatus != "") {
		if (phase7CalculationStatus == "Phase7_Corrected_Trace_Calculation_Failed" || phase7CalculationStatus == "Phase7_Corrected_Trace_Table_Export_Failed")
			sampleStatuses[phase13CurrentSampleIndex] = "Failed";
		else
			sampleStatuses[phase13CurrentSampleIndex] = phase7CalculationStatus;
	}
	if (phase8PlotStatus != "") {
		if (phase8PlotStatus == "Failed")
			sampleStatuses[phase13CurrentSampleIndex] = "Failed";
		else if (phase8PlotStatus == "Saved")
			sampleStatuses[phase13CurrentSampleIndex] = "Phase8_Baseline_Reconstruction_Plot_Saved";
	}
	if (phase9SecondSpikyStatus != "") {
		if (phase9SecondSpikyStatus == "Failed")
			sampleStatuses[phase13CurrentSampleIndex] = "Failed";
		else if (phase9SecondSpikyStatus == "Phase9_SecondSpiky_Output_Captured")
			sampleStatuses[phase13CurrentSampleIndex] = phase9SecondSpikyStatus;
	}
	if (phase10FinalOutputStatus != "") {
		if (phase10FinalOutputStatus == "Failed")
			sampleStatuses[phase13CurrentSampleIndex] = "Failed";
		else if (phase10FinalOutputStatus == "Phase10_Final_Output_Saved")
			sampleStatuses[phase13CurrentSampleIndex] = phase10FinalOutputStatus;
	}
	if (runMode == "Full Batch") {
		showStatus("Cleaning temporary windows for " + phase2SourceSample + "...");
		writeNonInteractiveProgress("Phase11_Cleanup_Before");
		runPhase11ConservativeWindowCleanup();
		writeNonInteractiveProgress("Phase11_Cleanup_After");
		if (phase11WindowCleanupWarning != "")
			phaseWarning = appendWarning(phaseWarning, phase11WindowCleanupWarning);
		writeNonInteractiveProgress("Phase14_Cleanup_Verify_Before");
		phase14CleanupCriticalError = verifyPhase14FullBatchCleanupSafeForNextSample();
		writeNonInteractiveProgress("Phase14_Cleanup_Verify_After");
		if (phase14CleanupCriticalError != "") {
			phaseError = appendWarning(phaseError, phase14CleanupCriticalError);
			phase13FullBatchStoppedAfterFailure = "Yes";
			phase13FullBatchStopReason = "Phase 14 stopped Full Batch after critical cleanup failure at sample index " + (phase13CurrentSampleIndex + 1) + ".";
			runCompletionStatus = "Phase14_Stopped_Critical_Cleanup_Failure";
		}
		if (phase11WindowCleanupStatus != "") {
			if (phase14CleanupCriticalError == "")
				runCompletionStatus = phase11WindowCleanupStatus;
			if (phase14CleanupCriticalError == "")
				sampleStatuses[phase13CurrentSampleIndex] = phase11WindowCleanupStatus;
		}
	}
	if (phaseError != "")
		sampleStatuses[phase13CurrentSampleIndex] = "Failed";
	if (runMode == "Full Batch") {
		if (phase15ExportWarning != "")
			phaseWarning = appendWarning(phaseWarning, phase15ExportWarning);
		if (phase15ExportError != "")
			phaseError = appendWarning(phaseError, phase15ExportError);
		if (phaseError != "")
			sampleStatuses[phase13CurrentSampleIndex] = "Failed";
		phase15ExportWarning = "";
		phase15ExportError = "";
		appendPhase15MasterRowsForCurrentSample();
		if (phase15ExportWarning != "")
			phaseWarning = appendWarning(phaseWarning, phase15ExportWarning);
		if (phase15ExportError != "")
			phaseError = appendWarning(phaseError, phase15ExportError);
		if (phaseError != "")
			sampleStatuses[phase13CurrentSampleIndex] = "Failed";
	}
	if (phaseWarning != "")
		sampleWarnings[phase13CurrentSampleIndex] = appendWarning(sampleWarnings[phase13CurrentSampleIndex], phaseWarning);
	fullBatchProcessedSampleCount++;
	phase13SampleRunLogRows = addRunLogRow(phase13SampleRunLogRows, timestamp, macroVersion, runMode, activeTableTitle, rowCount, columnCount, sampleCount, phase13CurrentSampleIndex + 1, phase13CurrentSampleIndex + 2, sampleOriginalNames[phase13CurrentSampleIndex], sampleUniqueNames[phase13CurrentSampleIndex], sampleFileNames[phase13CurrentSampleIndex], phase2SourceSample, phase2PlotName, phase3SpikyStatus, sampleStatuses[phase13CurrentSampleIndex], sampleWarnings[phase13CurrentSampleIndex], phaseError);
	if (runMode == "Full Batch") {
		if (phase13FullBatchStoppedAfterFailure == "Yes") {
			for (phase13UnprocessedIndex = phase13CurrentSampleIndex + 1; phase13UnprocessedIndex < fullBatchPlannedSampleCount; phase13UnprocessedIndex++)
				sampleStatuses[phase13UnprocessedIndex] = "Not_Processed_Phase14_Critical_Cleanup_Stop";
			writeNonInteractiveProgress("Run_Log_Write_Before_Cleanup_Stop");
			writeRunLog(runLogPath);
			writeNonInteractiveProgress("Run_Log_Write_After_Cleanup_Stop");
			break;
		}
		writeNonInteractiveProgress("Run_Log_Write_Before");
		writeRunLog(runLogPath);
		writeNonInteractiveProgress("Run_Log_Write_After");
	}
	writeNonInteractiveProgress("Sample_Finish");
	if (runMode == "Full Batch") {
		if (sampleStatuses[phase13CurrentSampleIndex] == "Failed")
			showStatus("Sample " + phase2SourceSample + " failed safely; continuing Full Batch (" + (phase13CurrentSampleIndex + 1) + "/" + phase13LoopSampleLimit + ")...");
		else
			showStatus("Completed sample " + phase2SourceSample + " (" + (phase13CurrentSampleIndex + 1) + "/" + phase13LoopSampleLimit + ")...");
		showProgress(phase13CurrentSampleIndex + 1, phase13LoopSampleLimit);
	}
	}
	fullBatchSampleLoopElapsedMs = floor(getTime() - fullBatchSampleLoopStartTimeMs);
	if (runMode == "Full Batch" && phase13FullBatchStoppedAfterFailure != "Yes") {
		if (countPhase14FullBatchFailedSamples() > 0)
			runCompletionStatus = "Phase15A_FullBatch_Completed_With_Failed_Samples_And_Aggregation";
		else
			runCompletionStatus = "Phase15A_FullBatch_Completed_With_Aggregation";
	}
}

if (runMode == "Full Batch") {
	fullBatchAggregationStartTimeMs = getTime();
	showStatus("Compiling Full Batch aggregate outputs...");
	writeNonInteractiveProgress("Aggregation_Start");
	phase15ExportWarning = "";
	phase15ExportError = "";
	appendPhase15RemainingFullBatchRows();
	if (phase15ExportWarning != "")
		phaseWarning = appendWarning(phaseWarning, phase15ExportWarning);
	if (phase15ExportError != "")
		phaseError = appendWarning(phaseError, phase15ExportError);
	runPhase16FullBatchOutputPolish();
	if (phase16ExportWarning != "")
		phaseWarning = appendWarning(phaseWarning, phase16ExportWarning);
	if (phase16ExportError != "")
		phaseError = appendWarning(phaseError, phase16ExportError);
	fullBatchAggregationElapsedMs = floor(getTime() - fullBatchAggregationStartTimeMs);
	writeNonInteractiveProgress("Aggregation_Finish");
}

macroCopyStatus = copyMacroUsedIfPossible(batchMacroSourcePath, macroCopyPath, copyMacroRequested);
if (macroCopyStatus != "Copied_And_Content_Verified") {
	macroCopyWarning = "Macro copy status: " + macroCopyStatus;
	phaseWarning = appendWarning(phaseWarning, macroCopyWarning);
}

writeRunLog(runLogPath);
writeAnalysisSettings(settingsPath);
writeMethodNote(methodNotePath);
verifyRequiredOutputs();

if (runMode == "Full Batch") {
	showProgress(1.0);
	showStatus("Full Batch complete. Outputs: " + outputFolder);
}

if (runMode == "Test First Sample Only" && phase10FinalOutputStatus == "Phase10_Final_Output_Saved") {
	runPhase11ConservativeWindowCleanup();
	if (phase11WindowCleanupWarning != "")
		phaseWarning = appendWarning(phaseWarning, phase11WindowCleanupWarning);
	if (phase11WindowCleanupStatus != "") {
		runCompletionStatus = phase11WindowCleanupStatus;
		sampleStatuses[0] = phase11WindowCleanupStatus;
	}
	writeRunLog(runLogPath);
	writeAnalysisSettings(settingsPath);
	writeMethodNote(methodNotePath);
	verifyRequiredOutputs();
}

print("Spiky Batch Baseline Correction " + macroVersion);
print("Run mode: " + runMode);
print("Active table: " + activeTableTitle);
print("Rows: " + rowCount + ", columns: " + columnCount + ", samples: " + sampleCount);
print("Phase 14 planned Full Batch sample limit: " + fullBatchMaxSamplesToProcess + " (0 = all)");
print("Phase 14 planned Full Batch samples: " + fullBatchPlannedSampleCount);
print("Phase 14 processed Full Batch samples: " + fullBatchProcessedSampleCount);
print("Output folder: " + outputFolder);
if (phase2PlotName != "") {
	print("Phase 2 plot created: " + phase2PlotName);
	print("Phase 2 source sample: " + phase2SourceSample);
}
if (phase3SpikyStatus != "") {
	print("Phase 3 Spiky status: " + phase3SpikyStatus);
	print("Phase 3 raw plot analyzed: " + phase3RawPlotName);
	print("Phase 3 detected-peaks plot: " + phase3SpikyDetectedPeaksPlotName);
	print("Phase 3 peak-analysis table: " + phase3SpikyPeakAnalysisTableName);
	if (phase4PlotValuesStatus != "") {
		print("Phase 4 Plot Values status: " + phase4PlotValuesStatus);
		print("Phase 4 Plot Values table: " + phase4PlotValuesTableName);
		print("Phase 4 Plot Values column count: " + phase4PlotValuesColumnCount);
		print("Phase 4 Plot Values column headings: " + phase4PlotValuesColumnHeadings);
		if (phase4PlotValuesSavePath != "")
			print("Phase 4 Plot Values saved: " + phase4PlotValuesSavePath);
	}
	if (phase5ValidationStatus != "") {
		print("Phase 5 validation status: " + phase5ValidationStatus);
		print("Phase 5 predicted baseline columns: " + phase5PredictedXColumn + "/" + phase5PredictedYColumn);
		print("Phase 5 anchor count: " + phase5AnchorCount);
		print("Phase 5 validation windows: " + phase5ValidationWindowMode + ", local=" + phase5LocalBaselineWindowPoints + " points, peak exclusion=" + phase5PeakExclusionWindowPoints + " points");
		print("Phase 5 median time step: " + phase5MedianTimeStep);
		if (phase5BaselineAnchorsSavePath != "")
			print("Phase 5 baseline anchors saved: " + phase5BaselineAnchorsSavePath);
		if (phase5ValidationError != "")
			print("Phase 5 validation error: " + phase5ValidationError);
	}
	if (phase3DetectedPeaksPlotSavePath != "")
		print("Phase 3 detected-peaks plot saved: " + phase3DetectedPeaksPlotSavePath);
	if (phase3PeakAnalysisTableSavePath != "")
		print("Phase 3 peak-analysis table saved: " + phase3PeakAnalysisTableSavePath);
	if (phase3OutputSaveStatus != "")
		print("Phase 3 output save status: " + phase3OutputSaveStatus);
	if (phase3SpikyStatus == "Phase3_Spiky_Output_Missing")
		print("Open windows after Spiky: " + phase3OpenWindowsAfterSpiky);
	if (phase3ExistingResultsBackupName != "")
		print("Existing Results table renamed to: " + phase3ExistingResultsBackupName);
}
if (runMode == "Full Batch") {
	print("Phase 14 Full Batch scope: " + fullBatchPhase6StopReason);
	if (phase13FullBatchStoppedAfterFailure == "Yes")
		print("Phase 14 Full Batch stop reason: " + phase13FullBatchStopReason);
}
if (phase6FitStatus != "") {
	print("Phase 6 fit status: " + phase6FitStatus);
	print("Phase 6 fit function: " + phase6FitFunction);
	print("Phase 6 polynomial degree used: " + phase6PolynomialDegreeUsed);
	print("Phase 6 coefficient order: " + phase6CoefficientOrder);
	print("Phase 6 coefficients: " + phase6CoefficientsText);
	print("Phase 6 source anchor array length / exact fit input count / unused source entries: " + phase6SourceAnchorArrayLength + " / " + phase6FitInputAnchorCount + " / " + phase6UnusedSourceAnchorEntries);
	print("Phase 6 fit input array status: " + phase6FitInputArrayStatus);
	print("Phase 6 anchor residual RMSE / max abs / max percent abs: " + phase6AnchorResidualRMSE + " / " + phase6AnchorResidualMaxAbs + " / " + phase6AnchorResidualMaxPercentAbs);
	print("Phase 6 raw rows before/after anchor support: " + phase6RawRowsBeforeFirstAnchor + " / " + phase6RawRowsAfterLastAnchor);
	print("Phase 6 fit reasonableness status: " + phase6FitReasonablenessStatus);
	print("Phase 6 diagnostic table save status: " + phase6DiagnosticTableSaveStatus);
	if (phase6DiagnosticTableSavePath != "")
		print("Phase 6 diagnostic table save path: " + phase6DiagnosticTableSavePath);
	print("Phase 6 RMSE: " + phase6FitRMSE);
	print("Phase 6 R2: " + phase6FitRSquared);
	print("Phase 6 fitted baseline min/mean/max: " + phase6FittedBaselineMin + " / " + phase6FittedBaselineMean + " / " + phase6FittedBaselineMax);
	if (phase6FitWarning != "")
		print("Phase 6 warning: " + phase6FitWarning);
	if (phase6FitError != "")
		print("Phase 6 error: " + phase6FitError);
}
if (phase7CalculationStatus != "") {
	print("Phase 7 calculation status: " + phase7CalculationStatus);
	print("Phase 7 raw/baseline alignment: " + phase7RawBaselineAlignmentStatus);
	print("Phase 7 raw/baseline/DeltaF counts: " + phase7RawValueCount + " / " + phase7BaselineValueCount + " / " + phase7DeltaFValueCount);
	print("Phase 7 DeltaF min/mean/max: " + phase7MinDeltaF + " / " + phase7MeanDeltaF + " / " + phase7MaxDeltaF);
	print("Phase 7 DeltaF/F0 min/mean/max: " + phase7MinDeltaFOverF0 + " / " + phase7MeanDeltaFOverF0 + " / " + phase7MaxDeltaFOverF0);
	print("Phase 7 DeltaF/F0 percent min/mean/max: " + phase7MinDeltaFOverF0Percent + " / " + phase7MeanDeltaFOverF0Percent + " / " + phase7MaxDeltaFOverF0Percent);
	print("Phase 7 corrected trace table save status: " + phase7CorrectedTraceTableSaveStatus);
	if (phase7CorrectedTraceTableSavePath != "")
		print("Phase 7 corrected trace table save path: " + phase7CorrectedTraceTableSavePath);
	if (phase7Warning != "")
		print("Phase 7 warning: " + phase7Warning);
	if (phase7Error != "")
		print("Phase 7 error: " + phase7Error);
}
if (phase8PlotStatus != "") {
	print("Phase 8 baseline reconstruction plot status: " + phase8PlotStatus);
	if (phase8PlotSavePath != "")
		print("Phase 8 baseline reconstruction plot path: " + phase8PlotSavePath);
	print("Phase 8 in-plot warning status: " + phase8InPlotWarningStatus);
	if (phase8PlotWarning != "")
		print("Phase 8 warning: " + phase8PlotWarning);
	if (phase8PlotError != "")
		print("Phase 8 error: " + phase8PlotError);
}
if (phase9SecondSpikyStatus != "") {
	print("Phase 9 second Spiky status: " + phase9SecondSpikyStatus);
	print("Phase 9 corrected DeltaF/F0 input plot: " + phase9CorrectedInputPlotName);
	print("Phase 9 corrected input value count: " + phase9CorrectedInputValueCount);
	print("Phase 9 corrected input DeltaF/F0 min/max: " + phase9CorrectedInputYMin + " / " + phase9CorrectedInputYMax);
	print("Phase 9 second detected-peaks plot: " + phase9SecondSpikyDetectedPeaksPlotName);
	print("Phase 9 second peak-analysis table: " + phase9SecondSpikyPeakAnalysisTableName);
	if (phase9ExistingResultsBackupName != "")
		print("Existing Results table renamed before Phase 9 Spiky: " + phase9ExistingResultsBackupName);
	if (phase9CorrectedInputWarning != "")
		print("Phase 9 corrected input warning: " + phase9CorrectedInputWarning);
	if (phase9CorrectedInputError != "")
		print("Phase 9 corrected input error: " + phase9CorrectedInputError);
	if (phase9SecondSpikyWarning != "")
		print("Phase 9 second Spiky warning: " + phase9SecondSpikyWarning);
	if (phase9SecondSpikyError != "")
		print("Phase 9 second Spiky error: " + phase9SecondSpikyError);
}
if (phase10FinalOutputStatus != "") {
	print("Phase 10 final output status: " + phase10FinalOutputStatus);
	print("Phase 10 final peak table source: " + phase10FinalPeakTableSourceName);
	print("Phase 10 final peak table path: " + phase10FinalPeakTableSavePath);
	print("Phase 10 final peak table rows/columns: " + phase10FinalPeakTableRowCount + " / " + phase10FinalPeakTableColumnCount);
	print("Phase 10 final peak plot source: " + phase10FinalPeakPlotSourceName);
	print("Phase 10 final peak plot path: " + phase10FinalPeakPlotSavePath);
	if (phase10FinalOutputWarning != "")
		print("Phase 10 warning: " + phase10FinalOutputWarning);
	if (phase10FinalOutputError != "")
		print("Phase 10 error: " + phase10FinalOutputError);
}
if (phase11WindowCleanupStatus != "") {
	print("Phase 11 window cleanup status: " + phase11WindowCleanupStatus);
	print("Phase 11 windows closed: " + phase11WindowCleanupClosedWindows);
	print("Phase 11 windows intentionally kept open: " + phase11WindowCleanupKeptOpen);
	if (phase11WindowCleanupWarning != "")
		print("Phase 11 cleanup warning: " + phase11WindowCleanupWarning);
}
print("Phase 15A role-based master aggregation files were initialized in the Data folder; Corrected_Traces_All_Samples.csv remains not implemented.");

finalDialogSampleName = "Unknown";
if (phase2SourceSample != "" && phase2SourceSample != "NaN")
	finalDialogSampleName = phase2SourceSample;
else if (firstSampleSafeName != "" && firstSampleSafeName != "NaN")
	finalDialogSampleName = firstSampleSafeName;
else if (sampleCount > 0 && sampleFileNames[0] != "" && sampleFileNames[0] != "NaN")
	finalDialogSampleName = sampleFileNames[0];
if (finalDialogSampleName == "Unknown") {
	phaseWarning = appendWarning(phaseWarning, "Final dialog sample name could not be verified; displayed Unknown.");
	writeRunLog(runLogPath);
	writeAnalysisSettings(settingsPath);
	writeMethodNote(methodNotePath);
}
if (validationModeUsed == "Yes") {
	print("Non-interactive validation mode completed; final completion dialog and post-dialog cleanup were skipped.");
	eval("script", "System.exit(0);");
}
closeRemainingMacroWindowsAfterFinalDialog = showConciseFinalRunDialog();
if (closeRemainingMacroWindowsAfterFinalDialog) {
	runPhase11CloseRemainingMacroWindowsAfterFinalDialog();
	if (runMode == "Test First Sample Only" && phase10FinalOutputStatus == "Phase10_Final_Output_Saved" && phase11WindowCleanupStatus != "") {
		runCompletionStatus = phase11WindowCleanupStatus;
		sampleStatuses[0] = phase11WindowCleanupStatus;
	}
	writeRunLog(runLogPath);
	writeAnalysisSettings(settingsPath);
	writeMethodNote(methodNotePath);
}
returnToMainMenuAfterInteractiveRunIfRequested();

// Fiji macro compatibility rule:
// assign string-returning helper results to variables before using them in
// concatenations, comparisons, or other larger expressions.
// For small metadata files, build the complete text and save once instead
// of mixing File.saveString and File.append.
// Select exact table windows before reading table metadata; do not rely on
// whatever window happens to be active after dialogs or plot creation.
// Keep top-level array state updates in top-level code; helper functions
// should use passed-in values and local arrays for Fiji macro compatibility.
function resetPhase13PerSampleState() {
	phaseWarning = "";
	phaseError = "";
	phase2SourceSample = "";
	phase2PlotName = "";
	phase2RawPlotSavePath = "";
	phase2RawValuesTableSavePath = "";
	phase2RawPlotCreateError = "";
	phase3RawPlotName = "";
	phase3SpikyDetectedPeaksPlotName = "";
	phase3SpikyPeakAnalysisTableName = "";
	phase3ExistingResultsBackupName = "";
	phase3SpikyStatus = "";
	phase3SpikyWasCalled = "No";
	phase3OpenWindowsAfterSpiky = "";
	phase3DetectedPeaksPlotSavePath = "";
	phase3PeakAnalysisTableSavePath = "";
	phase3OutputSaveStatus = "";
	phase3PrefShowDetectedPeakPlot = "";
	phase3PrefShowPeakResultsTable = "";
	phase3PrefShowBaseline = "";
	phase3PrefShowThreshold = "";
	phase3PrefSynchroDetection = "";
	phase3PrefDerivativeOutput = "";
	phase3PrefSlopeOutput = "";
	phase3PrefSlopeDisplay = "";
	phase3PrefPeakAreaOutput = "";
	phase3PrefDecayFitting = "";
	phase3PrefSummaryOutput = "";
	phase3PrefAutoDetectMode = "";
	phase3PeakDirectionSource = "Batch_Spiky_Peak_Orientation_Setting";
	phase3PeakDirectionFinal = spikyPeakOrientation;
	phase3PrefTolerancePercent = "";
	phase3PrefSmoothing = "";
	phase3PrefThresholdStartPercent = "";
	phase3PrefFullWidthOutput = "";
	phase3PrefHalfWidthOutput = "";
	phase3PrefFullWidthPercent1 = "";
	phase3PrefFullWidthPercent2 = "";
	phase3FirstSpikyFallbackUsed = "No";
	phase3FirstSpikyFallbackInitialTolerance = "";
	phase3FirstSpikyFallbackFinalTolerance = "";
	phase3FirstSpikyFallbackFailedAttempts = "";
	phase3FirstSpikyFallbackReason = "";
	phase3FirstSpikyFallbackPassedAfterFallback = "No";
	phase4PlotValuesStatus = "";
	phase4PlotValuesTableName = "";
	phase4PlotValuesSavePath = "";
	phase4PlotValuesColumnCount = "";
	phase4PlotValuesColumnHeadings = "";
	phase4PlotValuesOpenWindowsBefore = "";
	phase4PlotValuesOpenWindowsAfter = "";
	phase4PlotValuesWarning = "";
	phase4PlotValuesError = "";
	phase4ExistingResultsBackupName = "";
	phase4ExistingPlotValuesBackupName = "";
	phase5ValidationStatus = "";
	phase5PlotValuesSourceTableName = "";
	phase5PredictedXColumn = "";
	phase5PredictedYColumn = "";
	phase5PredictionReason = "";
	phase5AnchorCount = "";
	phase5BaselineAnchorsSavePath = "";
	phase5ValidationError = "";
	phase5ValidationWarning = "";
	phase5ValidationWindowMode = "points-based";
	phase5LocalBaselineWindowPoints = 25;
	phase5PeakExclusionWindowPoints = 5;
	phase5LocalBaselineTolerancePercent = 5;
	phase5PeakSeparationPercent = 10;
	phase5MedianTimeStep = "";
	phase5LocalBaselineWindowTimeUnits = "";
	phase5PeakExclusionWindowTimeUnits = "";
	phase5RawXMin = "";
	phase5RawXMax = "";
	phase5RawYMin = "";
	phase5RawYMax = "";
	phase5AnchorYMin = "";
	phase5AnchorYMax = "";
	phase5RawYRange = "";
	phase5PeakMarkerColumnX = "";
	phase5PeakMarkerColumnY = "";
	phase5CandidateDiagnostics = "";
	phase5RawTimes = newArray(0);
	phase5RawValues = newArray(0);
	phase5TimeSteps = newArray(0);
	phase5AnchorTimes = newArray(0);
	phase5AnchorValues = newArray(0);
	phase5PeakTimes = newArray(0);
	phase5PeakValues = newArray(0);
	phase5PeakCount = 0;
	phase6FitStatus = "";
	phase6FitFunction = "";
	phase6PolynomialDegreeUsed = "";
	phase6SupportedDegrees = "1,2,3,4";
	phase6AnchorCount = "";
	phase6CoefficientCount = "";
	phase6CoefficientsText = "";
	phase6CoefficientOrder = "Fit.p(0)=constant a; Fit.p(1)=linear b; Fit.p(2)=quadratic c; Fit.p(3)=cubic d; Fit.p(4)=quartic e";
	phase6FitRMSE = "";
	phase6FitRSquared = "";
	phase6FittedBaselineMin = "";
	phase6FittedBaselineMean = "";
	phase6FittedBaselineMax = "";
	phase6BaselineValueCount = "";
	phase6FitWarning = "";
	phase6FitError = "";
	phase6CoefficientStabilityAbsLimit = 1e80;
	phase6SourceAnchorArrayLength = "";
	phase6FitInputAnchorCount = "";
	phase6UnusedSourceAnchorEntries = "";
	phase6FitInputArrayStatus = "";
	phase6FitInputFirstTime = "";
	phase6FitInputLastTime = "";
	phase6FitInputFirstValue = "";
	phase6FitInputLastValue = "";
	phase6FitAnchorTimes = newArray(0);
	phase6FitAnchorValues = newArray(0);
	phase6AnchorFittedValues = newArray(0);
	phase6AnchorResidualValues = newArray(0);
	phase6AnchorPercentResidualValues = newArray(0);
	phase6BaselineValues = newArray(0);
	phase6AnchorDiagnosticCount = "";
	phase6AnchorResidualRMSE = "";
	phase6AnchorResidualMaxAbs = "";
	phase6AnchorResidualMaxPercentAbs = "";
	phase6AnchorResidualWarnPercent = 5;
	phase6AnchorResidualFailPercent = 10;
	phase6RawTimeMin = "";
	phase6RawTimeMax = "";
	phase6AnchorTimeMin = "";
	phase6AnchorTimeMax = "";
	phase6RawRowsBeforeFirstAnchor = "";
	phase6RawRowsAfterLastAnchor = "";
	phase6RawPercentOutsideAnchorSupport = "";
	phase6FirstFittedBaseline = "";
	phase6LastFittedBaseline = "";
	phase6FitReasonablenessStatus = "";
	phase6FitReasonablenessError = "";
	phase6FitReasonablenessWarning = "";
	phase6AnchorTimeCoveragePercent = "";
	phase6AnchorSpreadStatus = "";
	phase6PolynomialDegreeFirstAttempted = "";
	phase6PolynomialFallbackUsed = "";
	phase6PolynomialFallbackReason = "";
	phase6BaselineRangeWarning = "";
	phase6BaselineEndpointWarning = "";
	phase6BaselineNegativeCorrectionWarning = "";
	phase6BaselineCurvatureWarning = "";
	phase6PeakAwareAnchorTimingWarning = "";
	phase6BaselineReliabilityClass = "Baseline_OK";
	phase6BaselineReliabilityReason = "";
	phase6DiagnosticTableSaveStatus = "";
	phase6DiagnosticTableSavePath = "";
	phase7CalculationStatus = "";
	phase7RawValueCount = "";
	phase7BaselineValueCount = "";
	phase7DeltaFValueCount = "";
	phase7DeltaFOverF0ValueCount = "";
	phase7DeltaFOverF0PercentValueCount = "";
	phase7RawBaselineAlignmentStatus = "";
	phase7MinDeltaF = "";
	phase7MeanDeltaF = "";
	phase7MaxDeltaF = "";
	phase7MinDeltaFOverF0 = "";
	phase7MeanDeltaFOverF0 = "";
	phase7MaxDeltaFOverF0 = "";
	phase7MinDeltaFOverF0Percent = "";
	phase7MeanDeltaFOverF0Percent = "";
	phase7MaxDeltaFOverF0Percent = "";
	phase7InvalidBaselineValueCount = "";
	phase7InvalidCorrectedValueCount = "";
	phase7FirstInvalidRow = "";
	phase7FirstInvalidReason = "";
	phase7MinimumSafeBaselineAbs = 1e-12;
	phase7Warning = "";
	phase7Error = "";
	phase7BaselineTimes = newArray(0);
	phase7BaselineValues = newArray(0);
	phase7DeltaFValues = newArray(0);
	phase7DeltaFOverF0Values = newArray(0);
	phase7DeltaFOverF0PercentValues = newArray(0);
	phase7CorrectedTraceTableSaveStatus = "";
	phase7CorrectedTraceTableSavePath = "";
	phase8PlotStatus = "";
	phase8PlotWindowName = "";
	phase8PlotSavePath = "";
	phase8PlotWarning = "";
	phase8PlotError = "";
	phase8InPlotWarningStatus = "";
	phase8InPlotWarningText = "";
	phase8EndpointAnnotationThresholdPercent = 10;
	phase8FirstRawTime = "";
	phase8FirstAnchorTime = "";
	phase9SecondSpikyStatus = "";
	phase9CorrectedInputPlotName = "";
	phase9CorrectedInputValueCount = "";
	phase9CorrectedInputYMin = "";
	phase9CorrectedInputYMax = "";
	phase9CorrectedInputWarning = "";
	phase9CorrectedInputError = "";
	phase9SecondSpikyWasCalled = "No";
	phase9ExistingResultsBackupName = "";
	phase9SecondSpikyDetectedPeaksPlotName = "";
	phase9SecondSpikyPeakAnalysisTableName = "";
	phase9OpenWindowsAfterSpiky = "";
	phase9SecondSpikyWarning = "";
	phase9SecondSpikyError = "";
	phase10FinalOutputStatus = "";
	phase10FinalPeakTableSourceName = "";
	phase10FinalPeakTableSavePath = "";
	phase10FinalPeakTableRowCount = "";
	phase10FinalPeakTableColumnCount = "";
	phase10FinalPeakPlotSourceName = "";
	phase10FinalPeakPlotSavePath = "";
	phase10FinalOutputWarning = "";
	phase10FinalOutputError = "";
	phase11WindowCleanupStatus = "";
	phase11WindowCleanupClosedWindows = "";
	phase11WindowCleanupWarning = "";
	phase11WindowCleanupKeptOpen = "";
	phase15ExportWarning = "";
	phase15ExportError = "";
	phase15LastAppendStatus = "";
	phase15FinalPeakMasterRowsWrittenForSample = 0;
	finalDialogSampleName = "";
	firstSampleSafeName = "";
	runCompletionStatus = "Run_Metadata_Completed";
}

function initializePhase15MasterTables() {
	phase15MasterTablesInitialized = "No";
	phase15MasterTablesStatus = "Started";
	phase15ExportWarning = "";
	phase15ExportError = "";

	phase15SampleSummaryHeader = newArray("Run_Timestamp", "Macro_Version", "Run_Mode", "Input_Table_Title", "Sample_Index", "Source_Column_Index", "Original_Sample_Name", "Unique_Sample_Name", "Sanitized_File_Name", "Sample_QC_Status", "Sample_Processing_Status", "Terminal_Analysis_Role", "Terminal_Phase_Status", "Failure_Reason", "Failure_Detail", "Warning_Message", "QC_Flags", "Raw_Timepoint_Count", "Processed_Timepoint_Count", "Baseline_Correction_Method", "Baseline_Correction_Status", "Final_Peak_Detection_Performed", "Final_Peak_Detection_Status", "Final_Peak_Count", "Final_Peak_Master_Row_Count", "Preliminary_Peak_Table_Path", "Baseline_Anchors_Table_Path", "Baseline_Diagnostics_Table_Path", "Processed_Trace_Table_Path", "Baseline_QC_Plot_Path", "Final_Peak_Table_Path", "Final_Peak_Plot_Path");
	phase15FinalPeakHeader = newArray("Run_Timestamp", "Macro_Version", "Sample_Index", "Source_Column_Index", "Original_Sample_Name", "Unique_Sample_Name", "Sanitized_File_Name", "Analysis_Role", "Detection_Method", "Analysis_Trace_Source", "Analysis_Trace_Unit", "Baseline_Correction_Method", "Peak_Row_Index", "Spiky_Index", "Spiky_Pos", "Tmax_s", "APeak", "Spiky_Baseline_Bl", "Amplitude", "Pk2Pk_s", "Time2Pk_s", "FWHM_s", "FW20_s", "FW80_s", "LW50_s", "LW20_s", "LW80_s", "RW50_s", "RW20_s", "RW80_s", "Peak_QC_Status", "Peak_QC_Flags", "Peak_QC_Message");
	phase15TimeSeriesHeader = newArray("Run_Timestamp", "Macro_Version", "Sample_Index", "Source_Column_Index", "Original_Sample_Name", "Unique_Sample_Name", "Sanitized_File_Name", "Trace_Role", "Row_Index", "Time", "Raw_Fluorescence", "Baseline_F0", "DeltaF", "DeltaF_over_F0", "DeltaF_over_F0_percent", "Final_Analysis_Trace_Value", "Final_Analysis_Trace_Unit", "Final_Analysis_Trace_Source", "Baseline_Correction_Method", "Baseline_Correction_Status", "QC_Status", "QC_Flags", "QC_Message");
	phase15BaselineHeader = newArray("Run_Timestamp", "Macro_Version", "Sample_Index", "Source_Column_Index", "Original_Sample_Name", "Unique_Sample_Name", "Sanitized_File_Name", "Baseline_Correction_Role", "Baseline_Correction_Method", "Baseline_Correction_Status", "Correction_Needed_Status", "Baseline_Output_Type", "Baseline_F0_Is_TimeVarying", "Anchor_Detection_Method", "Anchor_Source_Role", "Anchor_Count", "Fit_Function", "Polynomial_Degree_Selected", "Polynomial_Degree_Used", "Coefficient_Count", "Coefficients", "Fit_RMSE", "Fit_R2", "Fitted_Baseline_Min", "Fitted_Baseline_Mean", "Fitted_Baseline_Max", "Anchor_Residual_RMSE", "Anchor_Residual_MaxAbs", "Anchor_Residual_MaxPercentAbs", "Raw_Rows_Before_First_Anchor", "Raw_Rows_After_Last_Anchor", "Raw_Percent_Outside_Anchor_Support", "Reasonableness_Status", "QC_Status", "QC_Flags", "QC_Message", "Baseline_Anchors_Table_Path", "Baseline_Diagnostics_Table_Path", "Baseline_QC_Plot_Path");
	phase15StepsHeader = newArray("Run_Timestamp", "Macro_Version", "Sample_Index", "Source_Column_Index", "Original_Sample_Name", "Unique_Sample_Name", "Sanitized_File_Name", "Step_Index", "Step_Role", "Step_Method", "Input_Role", "Output_Role", "Step_Status", "Source_Window_Or_Table", "Output_Window_Or_Table", "Output_File_Path", "QC_Status", "QC_Flags", "QC_Message");

	savePhase15Header(phase15SampleSummaryPath, phase15SampleSummaryHeader, lengthOf(phase15SampleSummaryHeader), "Sample_Summary_QC");
	savePhase15Header(phase15FinalPeakMasterPath, phase15FinalPeakHeader, lengthOf(phase15FinalPeakHeader), "Final_Peak_Master");
	savePhase15Header(phase15TimeSeriesMasterPath, phase15TimeSeriesHeader, lengthOf(phase15TimeSeriesHeader), "TimeSeries_Master");
	savePhase15Header(phase15BaselineCorrectionMasterPath, phase15BaselineHeader, lengthOf(phase15BaselineHeader), "Baseline_Correction_Master");
	savePhase15Header(phase15ProcessingStepsMasterPath, phase15StepsHeader, lengthOf(phase15StepsHeader), "Processing_Steps_Master");

	if (phase15ExportError == "") {
		phase15MasterTablesInitialized = "Yes";
		phase15MasterTablesStatus = "Initialized";
	} else {
		phase15MasterTablesStatus = "Failed";
	}
}

function savePhase15Header(path, fields, expectedFieldCount, tableLabel) {
	headerLine = joinPhase15Fields(fields);
	appendError = validatePhase15LineFieldCount(headerLine, expectedFieldCount, tableLabel + " header");
	if (appendError != "") {
		phase15ExportError = appendWarning(phase15ExportError, appendError);
		return;
	}
	File.saveString(headerLine + "\n", path);
	if (!File.exists(path))
		phase15ExportError = appendWarning(phase15ExportError, "Phase 15A could not create master table header file: " + path);
}

function appendPhase15Line(path, line, expectedFieldCount, tableLabel) {
	phase15LastAppendStatus = "";
	if (phase15MasterTablesInitialized != "Yes") {
		phase15LastAppendStatus = "Skipped_Not_Initialized";
		return;
	}
	appendError = validatePhase15LineFieldCount(line, expectedFieldCount, tableLabel);
	if (appendError != "") {
		phase15ExportError = appendWarning(phase15ExportError, appendError);
		phase15LastAppendStatus = "Failed_Field_Count";
		return;
	}
	if (!File.exists(path)) {
		phase15ExportError = appendWarning(phase15ExportError, "Phase 15A could not append " + tableLabel + " because the master file was missing: " + path);
		phase15LastAppendStatus = "Failed_Missing_File";
		return;
	}
	File.append(line, path);
	phase15LastAppendStatus = "Appended";
}

function validatePhase15LineFieldCount(line, expectedFieldCount, tableLabel) {
	actualFieldCount = countDelimitedFields(line, outputFieldDelimiter);
	if (actualFieldCount != expectedFieldCount)
		return "Phase 15A " + tableLabel + " field-count check failed: expected " + expectedFieldCount + " fields, found " + actualFieldCount + ". Row was not written.";
	return "";
}

function joinPhase15Fields(fields) {
	if (lengthOf(fields) <= 0)
		return "";
	line = cleanPhase15Text(fields[0]);
	for (phase15JoinIndex = 1; phase15JoinIndex < lengthOf(fields); phase15JoinIndex++)
		line = line + outputFieldDelimiter + cleanPhase15Text(fields[phase15JoinIndex]);
	return line;
}

function cleanPhase15Text(value) {
	text = "" + value;
	if (text == "" || text == "NaN" || text == "null")
		return "NA";
	text = replace(text, outputFieldDelimiter, " ");
	text = replace(text, "\t", " ");
	text = replace(text, "\n", " ");
	text = replace(text, "\r", " ");
	while (indexOf(text, "  ") >= 0)
		text = replace(text, "  ", " ");
	return text;
}

function formatPhase15Number(value) {
	text = "" + value;
	if (text == "" || text == "NaN" || text == "null")
		return "NA";
	if (!isClearlyNumericText(text))
		return "NA";
	numericValue = parseFloat(text);
	formattedText = d2s(numericValue, 12);
	while (indexOf(formattedText, ".") >= 0 && endsWith(formattedText, "0"))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (endsWith(formattedText, "."))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (outputDecimalSeparator == ",")
		formattedText = replace(formattedText, ".", ",");
	return formattedText;
}

function formatPhase15SourceTableCell(value) {
	text = "" + value;
	if (text == "" || text == "NaN" || text == "null")
		return "NA";
	if (isClearlyNumericText(text)) {
		numericValue = parseFloat(text);
		formattedCellText = formatPhase15Number(numericValue);
		return formattedCellText;
	}
	cleanedCellText = cleanPhase15Text(text);
	return cleanedCellText;
}

function phase15ExistingPath(path) {
	if (path != "" && File.exists(path))
		return path;
	return "NA";
}

function appendPhase15TimeSeriesRowsForCurrentSample() {
	if (runMode != "Full Batch")
		return;
	if (phase15MasterTablesInitialized != "Yes")
		return;
	if (phase7CorrectedTraceTableSaveStatus != "Saved")
		return;
	if (phase7RawValueCount <= 0)
		return;

	for (phase15TimeSeriesIndex = 0; phase15TimeSeriesIndex < phase7RawValueCount; phase15TimeSeriesIndex++) {
		qPhase15SampleIndex = "" + (phase13CurrentSampleIndex + 1);
		qPhase15SourceColumnIndex = "" + (phase13CurrentSampleIndex + 2);
		qPhase15RowIndex = "" + (phase15TimeSeriesIndex + 1);
		qPhase15Time = formatPhase15Number(phase5RawTimes[phase15TimeSeriesIndex]);
		qPhase15RawFluorescence = formatPhase15Number(phase5RawValues[phase15TimeSeriesIndex]);
		qPhase15BaselineF0 = formatPhase15Number(phase7BaselineValues[phase15TimeSeriesIndex]);
		qPhase15DeltaF = formatPhase15Number(phase7DeltaFValues[phase15TimeSeriesIndex]);
		qPhase15DeltaFOverF0 = formatPhase15Number(phase7DeltaFOverF0Values[phase15TimeSeriesIndex]);
		qPhase15DeltaFOverF0Percent = formatPhase15Number(phase7DeltaFOverF0PercentValues[phase15TimeSeriesIndex]);
		qPhase15BaselineMethod = "" + getPhase15BaselineCorrectionMethod();
		qPhase15BaselineStatus = "" + getPhase15BaselineCorrectionStatus();
		qPhase15QCStatus = "" + getPhase15SampleQCStatus();
		qPhase15QCFlags = "" + getPhase15QCFlags();
		fields = newArray("" + timestamp, "" + macroVersion, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[phase13CurrentSampleIndex], "" + sampleUniqueNames[phase13CurrentSampleIndex], "" + sampleFileNames[phase13CurrentSampleIndex], "Processed_Trace", qPhase15RowIndex, qPhase15Time, qPhase15RawFluorescence, qPhase15BaselineF0, qPhase15DeltaF, qPhase15DeltaFOverF0, qPhase15DeltaFOverF0Percent, qPhase15DeltaFOverF0, "DeltaF/F0", "Processed_Trace", qPhase15BaselineMethod, qPhase15BaselineStatus, qPhase15QCStatus, qPhase15QCFlags, "" + phase7Warning);
		line = joinPhase15Fields(fields);
		appendPhase15Line(phase15TimeSeriesMasterPath, line, 23, "TimeSeries_Master row");
	}
}

function appendPhase15FinalPeakRowsForCurrentSample() {
	phase15FinalPeakMasterRowsWrittenForSample = 0;
	if (runMode != "Full Batch")
		return;
	if (phase15MasterTablesInitialized != "Yes")
		return;
	if (phase10FinalOutputStatus != "Phase10_Final_Output_Saved")
		return;
	if (!isOpen(phase10FinalPeakTableSourceName)) {
		phase15ExportWarning = appendWarning(phase15ExportWarning, "Phase 15A could not append final peak master rows because the final peak source table was not open: " + phase10FinalPeakTableSourceName);
		return;
	}

	selectWindow(phase10FinalPeakTableSourceName);
	phase15PeakTableRows = Table.size;
	phase15PeakTableHeadings = Table.headings;
	if (phase15PeakTableRows <= 0) {
		phase15FinalPeakMasterRowsWrittenForSample = 0;
		return;
	}

	for (phase15PeakRow = 0; phase15PeakRow < phase15PeakTableRows; phase15PeakRow++) {
		qPhase15SampleIndex = "" + (phase13CurrentSampleIndex + 1);
		qPhase15SourceColumnIndex = "" + (phase13CurrentSampleIndex + 2);
		qPhase15PeakRowIndex = "" + (phase15PeakRow + 1);
		qPhase15BaselineMethod = "" + getPhase15BaselineCorrectionMethod();
		qPhase15PeakIndex = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Index", phase15PeakRow);
		qPhase15PeakPos = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Pos", phase15PeakRow);
		qPhase15Tmax = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Tmax (s)", phase15PeakRow);
		qPhase15APeak = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "APeak", phase15PeakRow);
		qPhase15BaselineBl = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Baseline Bl", phase15PeakRow);
		qPhase15Amplitude = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Amplitude", phase15PeakRow);
		qPhase15Pk2Pk = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Pk2Pk (s)", phase15PeakRow);
		qPhase15Time2Pk = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "Time2Pk (s)", phase15PeakRow);
		qPhase15FWHM = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "FWHM (s)", phase15PeakRow);
		qPhase15FW20 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "FW20 (s)", phase15PeakRow);
		qPhase15FW80 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "FW80 (s)", phase15PeakRow);
		qPhase15LW50 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "LW50 (s)", phase15PeakRow);
		qPhase15LW20 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "LW20 (s)", phase15PeakRow);
		qPhase15LW80 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "LW80 (s)", phase15PeakRow);
		qPhase15RW50 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "RW50 (s)", phase15PeakRow);
		qPhase15RW20 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "RW20 (s)", phase15PeakRow);
		qPhase15RW80 = "" + phase15GetTableCellByHeading(phase15PeakTableHeadings, "RW80 (s)", phase15PeakRow);
		qPhase15QCFlags = "" + getPhase15QCFlags();
		fields = newArray("" + timestamp, "" + macroVersion, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[phase13CurrentSampleIndex], "" + sampleUniqueNames[phase13CurrentSampleIndex], "" + sampleFileNames[phase13CurrentSampleIndex], "Final_Peak_Detection", "Spiky", "Processed_Trace", "DeltaF/F0", qPhase15BaselineMethod, qPhase15PeakRowIndex, qPhase15PeakIndex, qPhase15PeakPos, qPhase15Tmax, qPhase15APeak, qPhase15BaselineBl, qPhase15Amplitude, qPhase15Pk2Pk, qPhase15Time2Pk, qPhase15FWHM, qPhase15FW20, qPhase15FW80, qPhase15LW50, qPhase15LW20, qPhase15LW80, qPhase15RW50, qPhase15RW20, qPhase15RW80, "Success", qPhase15QCFlags, "" + phase10FinalOutputWarning);
		line = joinPhase15Fields(fields);
		appendPhase15Line(phase15FinalPeakMasterPath, line, 33, "Final_Peak_Master row");
		if (phase15LastAppendStatus == "Appended")
			phase15FinalPeakMasterRowsWrittenForSample++;
	}
}

function phase15GetTableCellByHeading(headingsTextToSearch, heading, rowIndex) {
	resolvedHeading = phase15ResolveTableHeading(headingsTextToSearch, heading);
	if (resolvedHeading == "") {
		phase15RecordMissingFinalPeakSourceHeading(heading);
		return "NA";
	}
	cellText = Table.getString(resolvedHeading, rowIndex);
	formattedCellText = formatPhase15SourceTableCell(cellText);
	return formattedCellText;
}

function phase15ResolveTableHeading(headingsTextToSearch, heading) {
	searchHeadings = split(headingsTextToSearch, "\t");
	requestedHeading = trimString("" + heading);
	requestedNorm = phase15NormalizeHeadingForMatch(requestedHeading);
	for (phase15HeadingIndex = 0; phase15HeadingIndex < lengthOf(searchHeadings); phase15HeadingIndex++) {
		sourceHeading = searchHeadings[phase15HeadingIndex];
		trimmedSourceHeading = trimString(sourceHeading);
		if (trimmedSourceHeading == requestedHeading)
			return sourceHeading;
	}
	for (phase15HeadingIndex = 0; phase15HeadingIndex < lengthOf(searchHeadings); phase15HeadingIndex++) {
		sourceHeading = searchHeadings[phase15HeadingIndex];
		trimmedSourceHeading = trimString(sourceHeading);
		if (startsWith(trimmedSourceHeading, requestedHeading + " ") || startsWith(trimmedSourceHeading, requestedHeading + "("))
			return sourceHeading;
	}
	for (phase15HeadingIndex = 0; phase15HeadingIndex < lengthOf(searchHeadings); phase15HeadingIndex++) {
		sourceHeading = searchHeadings[phase15HeadingIndex];
		sourceNorm = phase15NormalizeHeadingForMatch(sourceHeading);
		if (sourceNorm == requestedNorm || startsWith(sourceNorm, requestedNorm) || indexOf(sourceNorm, requestedNorm) >= 0)
			return sourceHeading;
	}
	return "";
}

function phase15NormalizeHeadingForMatch(value) {
	text = trimString("" + value);
	text = replace(text, "\"", "");
	text = replace(text, " ", "");
	text = replace(text, "_", "");
	text = replace(text, "(", "");
	text = replace(text, ")", "");
	text = replace(text, "/", "");
	return text;
}

function phase15RecordMissingFinalPeakSourceHeading(heading) {
	warningText = "Phase 16B Final_Peak_Master source heading missing: " + heading + ".";
	if (indexOf(phase15ExportWarning, warningText) < 0)
		phase15ExportWarning = appendWarning(phase15ExportWarning, warningText);
}

function appendPhase15MasterRowsForCurrentSample() {
	if (runMode != "Full Batch")
		return;
	if (phase15MasterTablesInitialized != "Yes")
		return;
	appendPhase15BaselineCorrectionRowForCurrentSample();
	appendPhase15ProcessingStepsForCurrentSample();
	appendPhase15SampleSummaryRowForCurrentSample();
}

function appendPhase15SampleSummaryRowForCurrentSample() {
	if (phase15SummaryRowWritten[phase13CurrentSampleIndex] == 1)
		return;
	finalPeakCount = "";
	if (phase10FinalPeakTableRowCount != "")
		finalPeakCount = phase10FinalPeakTableRowCount;
	qPhase15SampleIndex = "" + (phase13CurrentSampleIndex + 1);
	qPhase15SourceColumnIndex = "" + (phase13CurrentSampleIndex + 2);
	qPhase15SampleQCStatus = "" + getPhase15SampleQCStatus();
	qPhase15TerminalRole = "" + getPhase15TerminalAnalysisRole();
	qPhase15TerminalPhaseStatus = "" + getPhase15TerminalPhaseStatus();
	qPhase15FailureReason = "" + getPhase15FailureReason();
	qPhase15QCFlags = "" + getPhase15QCFlags();
	qPhase15RowCount = "" + rowCount;
	qPhase15ProcessedTraceRows = "" + phase7DeltaFOverF0ValueCount;
	qPhase15BaselineMethod = "" + getPhase15BaselineCorrectionMethod();
	qPhase15BaselineStatus = "" + getPhase15BaselineCorrectionStatus();
	qPhase15FinalPeakPerformed = "" + getPhase15FinalPeakDetectionPerformed();
	qPhase15FinalPeakStatus = "" + getPhase15FinalPeakDetectionStatus();
	qPhase15FinalPeakCount = "" + finalPeakCount;
	qPhase15FinalPeakRowsWritten = "" + phase15FinalPeakMasterRowsWrittenForSample;
	qPhase15Phase3Path = "" + phase15ExistingPath(phase3PeakAnalysisTableSavePath);
	qPhase15Phase5Path = "" + phase15ExistingPath(phase5BaselineAnchorsSavePath);
	qPhase15Phase6Path = "" + phase15ExistingPath(phase6DiagnosticTableSavePath);
	qPhase15Phase7Path = "" + phase15ExistingPath(phase7CorrectedTraceTableSavePath);
	qPhase15Phase8Path = "" + phase15ExistingPath(phase8PlotSavePath);
	qPhase15Phase10TablePath = "" + phase15ExistingPath(phase10FinalPeakTableSavePath);
	qPhase15Phase10PlotPath = "" + phase15ExistingPath(phase10FinalPeakPlotSavePath);
	fields = newArray("" + timestamp, "" + macroVersion, "" + runMode, "" + activeTableTitle, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[phase13CurrentSampleIndex], "" + sampleUniqueNames[phase13CurrentSampleIndex], "" + sampleFileNames[phase13CurrentSampleIndex], qPhase15SampleQCStatus, "" + sampleStatuses[phase13CurrentSampleIndex], qPhase15TerminalRole, qPhase15TerminalPhaseStatus, qPhase15FailureReason, "" + phaseError, "" + sampleWarnings[phase13CurrentSampleIndex], qPhase15QCFlags, qPhase15RowCount, qPhase15ProcessedTraceRows, qPhase15BaselineMethod, qPhase15BaselineStatus, qPhase15FinalPeakPerformed, qPhase15FinalPeakStatus, qPhase15FinalPeakCount, qPhase15FinalPeakRowsWritten, qPhase15Phase3Path, qPhase15Phase5Path, qPhase15Phase6Path, qPhase15Phase7Path, qPhase15Phase8Path, qPhase15Phase10TablePath, qPhase15Phase10PlotPath);
	line = joinPhase15Fields(fields);
	appendPhase15Line(phase15SampleSummaryPath, line, 32, "Sample_Summary_QC row");
	if (phase15LastAppendStatus == "Appended")
		phase15SummaryRowWritten[phase13CurrentSampleIndex] = 1;
}

function appendPhase15BaselineCorrectionRowForCurrentSample() {
	qPhase15SampleIndex = "" + (phase13CurrentSampleIndex + 1);
	qPhase15SourceColumnIndex = "" + (phase13CurrentSampleIndex + 2);
	qPhase15BaselineMethod = "" + getPhase15BaselineCorrectionMethod();
	qPhase15BaselineStatus = "" + getPhase15BaselineCorrectionStatus();
	qPhase15AnchorCount = "" + phase5AnchorCount;
	qPhase15SelectedPolynomialDegree = "" + selectedPolynomialDegree;
	qPhase15PolynomialDegreeUsed = "" + phase6PolynomialDegreeUsed;
	qPhase15CoefficientCount = "" + phase6CoefficientCount;
	qPhase15FitRMSE = formatPhase15Number(phase6FitRMSE);
	qPhase15FitRSquared = formatPhase15Number(phase6FitRSquared);
	qPhase15FittedBaselineMin = formatPhase15Number(phase6FittedBaselineMin);
	qPhase15FittedBaselineMean = formatPhase15Number(phase6FittedBaselineMean);
	qPhase15FittedBaselineMax = formatPhase15Number(phase6FittedBaselineMax);
	qPhase15AnchorResidualRMSE = formatPhase15Number(phase6AnchorResidualRMSE);
	qPhase15AnchorResidualMaxAbs = formatPhase15Number(phase6AnchorResidualMaxAbs);
	qPhase15AnchorResidualMaxPercentAbs = formatPhase15Number(phase6AnchorResidualMaxPercentAbs);
	qPhase15RawRowsBeforeFirstAnchor = "" + phase6RawRowsBeforeFirstAnchor;
	qPhase15RawRowsAfterLastAnchor = "" + phase6RawRowsAfterLastAnchor;
	qPhase15RawPercentOutsideAnchorSupport = formatPhase15Number(phase6RawPercentOutsideAnchorSupport);
	qPhase15SampleQCStatus = "" + getPhase15SampleQCStatus();
	qPhase15QCFlags = "" + getPhase15QCFlags();
	qPhase15QCMessage = "" + appendWarning(phase6FitWarning, phase6FitError);
	qPhase15AnchorPath = "" + phase15ExistingPath(phase5BaselineAnchorsSavePath);
	qPhase15DiagnosticPath = "" + phase15ExistingPath(phase6DiagnosticTableSavePath);
	qPhase15PlotPath = "" + phase15ExistingPath(phase8PlotSavePath);
	fields = newArray("" + timestamp, "" + macroVersion, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[phase13CurrentSampleIndex], "" + sampleUniqueNames[phase13CurrentSampleIndex], "" + sampleFileNames[phase13CurrentSampleIndex], "Baseline_Correction", qPhase15BaselineMethod, qPhase15BaselineStatus, "Performed_When_Validated", "TimeVarying_F0", "TRUE", "Spiky", "Baseline_Anchor_Detection", qPhase15AnchorCount, "" + phase6FitFunction, qPhase15SelectedPolynomialDegree, qPhase15PolynomialDegreeUsed, qPhase15CoefficientCount, "" + phase6CoefficientsText, qPhase15FitRMSE, qPhase15FitRSquared, qPhase15FittedBaselineMin, qPhase15FittedBaselineMean, qPhase15FittedBaselineMax, qPhase15AnchorResidualRMSE, qPhase15AnchorResidualMaxAbs, qPhase15AnchorResidualMaxPercentAbs, qPhase15RawRowsBeforeFirstAnchor, qPhase15RawRowsAfterLastAnchor, qPhase15RawPercentOutsideAnchorSupport, "" + phase6FitReasonablenessStatus, qPhase15SampleQCStatus, qPhase15QCFlags, qPhase15QCMessage, qPhase15AnchorPath, qPhase15DiagnosticPath, qPhase15PlotPath);
	line = joinPhase15Fields(fields);
	appendPhase15Line(phase15BaselineCorrectionMasterPath, line, 39, "Baseline_Correction_Master row");
}

function appendPhase15ProcessingStepsForCurrentSample() {
	qPhase15InputStepStatus = "" + getPhase15InputStepStatus();
	qPhase15SampleQCStatus = "" + getPhase15SampleQCStatus();
	qPhase15QCFlags = "" + getPhase15QCFlags();
	appendPhase15ProcessingStepRow(1, "Input_Raw_Trace", "Input_Table_Column", "Input_Table", "Raw_Sample_Trace", qPhase15InputStepStatus, activeTableTitle, phase2PlotName, "", qPhase15SampleQCStatus, qPhase15QCFlags, phase2RawPlotCreateError);
	if (phase3SpikyStatus != "" || phase3SpikyWasCalled == "Yes") {
		qPhase15StepQCStatus = "" + getPhase15StepQCStatus(phase3SpikyStatus);
		qPhase15Phase3Path = "" + phase15ExistingPath(phase3PeakAnalysisTableSavePath);
		appendPhase15ProcessingStepRow(2, "Preliminary_Peak_Detection", "Spiky", "Input_Raw_Trace", "Preliminary_Peak_Table", phase3SpikyStatus, phase3RawPlotName, phase3SpikyPeakAnalysisTableName, qPhase15Phase3Path, qPhase15StepQCStatus, qPhase15QCFlags, phaseError);
	}
	if (phase4PlotValuesStatus != "" || phase5ValidationStatus != "") {
		qPhase15StepQCStatus = "" + getPhase15StepQCStatus(phase5ValidationStatus);
		qPhase15Phase5Path = "" + phase15ExistingPath(phase5BaselineAnchorsSavePath);
		qPhase15Phase5OutputText = "" + phase5PredictedXColumn + "/" + phase5PredictedYColumn;
		qPhase15Phase5Message = "" + appendWarning(phase5ValidationWarning, phase5ValidationError);
		appendPhase15ProcessingStepRow(3, "Baseline_Anchor_Detection", "Spiky_Plot_Values", "Preliminary_Peak_Detection", "Baseline_Anchors", phase5ValidationStatus, phase4PlotValuesTableName, qPhase15Phase5OutputText, qPhase15Phase5Path, qPhase15StepQCStatus, qPhase15QCFlags, qPhase15Phase5Message);
	}
	if (phase6FitStatus != "" || phase5ValidationStatus == "Phase5_Baseline_Anchors_Validated") {
		qPhase15BaselineMethod = "" + getPhase15BaselineCorrectionMethod();
		qPhase15StepQCStatus = "" + getPhase15StepQCStatus(phase6FitStatus);
		qPhase15Phase6Path = "" + phase15ExistingPath(phase6DiagnosticTableSavePath);
		qPhase15Phase6Message = "" + appendWarning(phase6FitWarning, phase6FitError);
		appendPhase15ProcessingStepRow(4, "Baseline_Correction", qPhase15BaselineMethod, "Baseline_Anchors", "Baseline_F0", phase6FitStatus, phase5BaselineAnchorsSavePath, phase6FitFunction, qPhase15Phase6Path, qPhase15StepQCStatus, qPhase15QCFlags, qPhase15Phase6Message);
	}
	if (phase7CalculationStatus != "") {
		qPhase15StepQCStatus = "" + getPhase15StepQCStatus(phase7CalculationStatus);
		qPhase15Phase7Path = "" + phase15ExistingPath(phase7CorrectedTraceTableSavePath);
		qPhase15Phase7Message = "" + appendWarning(phase7Warning, phase7Error);
		appendPhase15ProcessingStepRow(5, "Processed_Trace", "DeltaF_over_F0", "Input_Raw_Trace_and_Baseline_F0", "Processed_Trace", phase7CalculationStatus, phase7CorrectedTraceTableSavePath, "DeltaF/F0", qPhase15Phase7Path, qPhase15StepQCStatus, qPhase15QCFlags, qPhase15Phase7Message);
	}
	if (phase9SecondSpikyStatus != "" || phase10FinalOutputStatus != "") {
		qPhase15FinalPeakStatus = "" + getPhase15FinalPeakDetectionStatus();
		qPhase15StepQCStatus = "" + getPhase15StepQCStatus(qPhase15FinalPeakStatus);
		qPhase15Phase10Path = "" + phase15ExistingPath(phase10FinalPeakTableSavePath);
		qPhase15Phase10Message = "" + appendWarning(phase9SecondSpikyError, phase10FinalOutputError);
		appendPhase15ProcessingStepRow(6, "Final_Peak_Detection", "Spiky", "Processed_Trace", "Final_Peak_Table", qPhase15FinalPeakStatus, phase9CorrectedInputPlotName, phase10FinalPeakTableSourceName, qPhase15Phase10Path, qPhase15StepQCStatus, qPhase15QCFlags, qPhase15Phase10Message);
	}
	if (phase10FinalOutputStatus != "" || phase3OutputSaveStatus != "") {
		qPhase15ExportStatus = "" + getPhase15ExportStepStatus();
		qPhase15Phase10Path = "" + phase15ExistingPath(phase10FinalPeakTableSavePath);
		qPhase15ExportMessage = "" + appendWarning(phase3OutputSaveStatus, phase10FinalOutputWarning);
		appendPhase15ProcessingStepRow(7, "Export", "File_Export", "Analysis_Outputs", "Per_Sample_Files", qPhase15ExportStatus, outputFolder, "Tables_and_Plots", qPhase15Phase10Path, qPhase15SampleQCStatus, qPhase15QCFlags, qPhase15ExportMessage);
	}
	if (phase11WindowCleanupStatus != "") {
		qPhase15StepQCStatus = "" + getPhase15StepQCStatus(phase11WindowCleanupStatus);
		appendPhase15ProcessingStepRow(8, "Cleanup", "Exact_Window_Name_Cleanup", "Macro_Created_Windows", "Next_Sample_Ready_State", phase11WindowCleanupStatus, phase11WindowCleanupClosedWindows, phase11WindowCleanupKeptOpen, "", qPhase15StepQCStatus, qPhase15QCFlags, phase11WindowCleanupWarning);
	}
}

function appendPhase15ProcessingStepRow(stepIndex, stepRole, stepMethod, inputRole, outputRole, stepStatus, sourceText, outputText, outputPath, qcStatus, qcFlags, qcMessage) {
	qPhase15SampleIndex = "" + (phase13CurrentSampleIndex + 1);
	qPhase15SourceColumnIndex = "" + (phase13CurrentSampleIndex + 2);
	qPhase15StepIndex = "" + stepIndex;
	fields = newArray("" + timestamp, "" + macroVersion, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[phase13CurrentSampleIndex], "" + sampleUniqueNames[phase13CurrentSampleIndex], "" + sampleFileNames[phase13CurrentSampleIndex], qPhase15StepIndex, "" + stepRole, "" + stepMethod, "" + inputRole, "" + outputRole, "" + stepStatus, "" + sourceText, "" + outputText, "" + outputPath, "" + qcStatus, "" + qcFlags, "" + qcMessage);
	line = joinPhase15Fields(fields);
	appendPhase15Line(phase15ProcessingStepsMasterPath, line, 19, "Processing_Steps_Master row");
}

function appendPhase15RemainingFullBatchRows() {
	if (runMode != "Full Batch")
		return;
	if (phase15MasterTablesInitialized != "Yes")
		return;
	for (phase15RemainingIndex = 0; phase15RemainingIndex < sampleCount; phase15RemainingIndex++) {
		if (phase15SummaryRowWritten[phase15RemainingIndex] != 1) {
			if (baselineCurveMethod != "Polynomial")
				appendPhase15SkippedSampleRows(phase15RemainingIndex, "Skipped_UnsupportedMethod", "Unsupported baseline curve method selected for this phase: " + baselineCurveMethod);
			else if (phase13FullBatchStoppedAfterFailure == "Yes" && phase15RemainingIndex < fullBatchPlannedSampleCount)
				appendPhase15SkippedSampleRows(phase15RemainingIndex, "Stopped_CleanupCritical", phase13FullBatchStopReason);
			else if (phase15RemainingIndex >= fullBatchPlannedSampleCount)
				appendPhase15SkippedSampleRows(phase15RemainingIndex, "Skipped_MaxSampleLimit", "Sample was outside the selected Full Batch maximum sample limit.");
			else
				appendPhase15SkippedSampleRows(phase15RemainingIndex, "Skipped", "Sample was not processed by the Phase 15A Full Batch loop.");
		}
	}
}

function appendPhase15SkippedSampleRows(sampleIndex, statusText, reasonText) {
	if (phase15SummaryRowWritten[sampleIndex] == 1)
		return;
	qPhase15SampleIndex = "" + (sampleIndex + 1);
	qPhase15SourceColumnIndex = "" + (sampleIndex + 2);
	qPhase15BaselineMethod = "" + getPhase15BaselineCorrectionMethod();
	qPhase15SelectedPolynomialDegree = "" + selectedPolynomialDegree;
	fields = newArray("" + timestamp, "" + macroVersion, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[sampleIndex], "" + sampleUniqueNames[sampleIndex], "" + sampleFileNames[sampleIndex], "Baseline_Correction", qPhase15BaselineMethod, "Not_Started", "Not_Started", "", "", "", "", "", "", qPhase15SelectedPolynomialDegree, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "" + statusText, "" + statusText, "" + reasonText, "", "", "");
	line = joinPhase15Fields(fields);
	appendPhase15Line(phase15BaselineCorrectionMasterPath, line, 39, "Baseline_Correction_Master skipped row");

	qPhase15StepIndex = "" + 1;
	fields = newArray("" + timestamp, "" + macroVersion, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[sampleIndex], "" + sampleUniqueNames[sampleIndex], "" + sampleFileNames[sampleIndex], qPhase15StepIndex, "Input_Raw_Trace", "Input_Table_Column", "Input_Table", "Raw_Sample_Trace", "" + statusText, "" + activeTableTitle, "", "", "" + statusText, "" + statusText, "" + reasonText);
	line = joinPhase15Fields(fields);
	appendPhase15Line(phase15ProcessingStepsMasterPath, line, 19, "Processing_Steps_Master skipped row");

	qPhase15RowCount = "" + rowCount;
	qPhase15FinalPeakRowsWritten = "" + 0;
	fields = newArray("" + timestamp, "" + macroVersion, "" + runMode, "" + activeTableTitle, qPhase15SampleIndex, qPhase15SourceColumnIndex, "" + sampleOriginalNames[sampleIndex], "" + sampleUniqueNames[sampleIndex], "" + sampleFileNames[sampleIndex], "" + statusText, "" + statusText, "Sample_Summary_QC", "" + statusText, "" + reasonText, "" + reasonText, "" + sampleWarnings[sampleIndex], "" + statusText, qPhase15RowCount, "", qPhase15BaselineMethod, "Not_Started", "Not_Started", "" + statusText, "", qPhase15FinalPeakRowsWritten, "", "", "", "", "", "", "");
	line = joinPhase15Fields(fields);
	appendPhase15Line(phase15SampleSummaryPath, line, 32, "Sample_Summary_QC skipped row");
	if (phase15LastAppendStatus == "Appended")
		phase15SummaryRowWritten[sampleIndex] = 1;
}

function runPhase16FullBatchOutputPolish() {
	phase16ExportStatus = "Started";
	phase16ExportWarning = "";
	phase16ExportError = "";

	if (runMode != "Full Batch") {
		phase16ExportStatus = "Skipped_Not_Full_Batch";
		return;
	}
	if (phase15MasterTablesInitialized != "Yes") {
		phase16ExportStatus = "Skipped_Phase15_Not_Initialized";
		phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A skipped polished outputs because Phase 15A master tables were not initialized.");
		return;
	}

	showStatus("Building Full Batch final-peak overview...");
	writeNonInteractiveProgress("Overview_Start");
	phase16OverviewStartTimeMs = getTime();
	createPhase16FinalPeakOverviewImage();
	phase16OverviewElapsedMs = floor(getTime() - phase16OverviewStartTimeMs);
	writeNonInteractiveProgress("Overview_Finish");

	showStatus("Building Full Batch results workbook...");
	writeNonInteractiveProgress("Workbook_Start");
	phase16WorkbookStartTimeMs = getTime();
	createPhase16MasterResultsWorkbook();
	phase16WorkbookElapsedMs = floor(getTime() - phase16WorkbookStartTimeMs);
	writeNonInteractiveProgress("Workbook_Finish");

	if (phase16ExportError != "")
		phase16ExportStatus = "Completed_With_Errors";
	else if (phase16ExportWarning != "")
		phase16ExportStatus = "Completed_With_Warnings";
	else
		phase16ExportStatus = "Completed";
}

function createPhase16FinalPeakOverviewImage() {
	if (!File.exists(phase15SampleSummaryPath)) {
		phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A overview skipped because Sample_Summary_QC was missing.");
		return;
	}

	summaryText = File.openAsString(phase15SampleSummaryPath);
	summaryLines = split(summaryText, "\n");
	if (lengthOf(summaryLines) <= 1) {
		phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A overview skipped because Sample_Summary_QC had no sample rows.");
		return;
	}

	plotCount = 0;
	firstPlotPath = "";
	plotPath = "";
	for (phase16OverviewIndex = 1; phase16OverviewIndex < lengthOf(summaryLines); phase16OverviewIndex++) {
		line = trimString(summaryLines[phase16OverviewIndex]);
		if (line == "")
			continue;
		phase16SetDelimitedFieldResult(line, 31);
		plotPath = phase16DelimitedFieldResult;
		if (plotPath != "" && plotPath != "NA" && plotPath != "0" && File.exists(plotPath)) {
			plotCount++;
			if (firstPlotPath == "")
				firstPlotPath = plotPath;
		} else {
			phase16SetSampleNameFromSummaryLineResult(line);
			sampleName = phase16TextResult;
			phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A overview skipped missing final peak plot for sample " + sampleName + ".");
		}
	}

	if (plotCount <= 0) {
		phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A overview image was not created because no final peak analysis plots were available.");
		return;
	}

	open(firstPlotPath);
	firstPlotTitle = getTitle();
	cellWidth = getWidth();
	cellHeight = getHeight();
	close();
	labelHeight = 30;

	gridColumns = 1;
	while (gridColumns * gridColumns < plotCount)
		gridColumns++;
	gridRows = 1;
	while (gridRows * gridColumns < plotCount)
		gridRows++;

	overviewWidth = gridColumns * cellWidth;
	overviewHeight = gridRows * (cellHeight + labelHeight);
	newImage("Batch_Final_Peak_Analysis_Overview", "RGB white", overviewWidth, overviewHeight, 1);
	overviewTitle = getTitle();
	setFont("SansSerif", 16, "bold");
	setColor("black");

	plotPosition = 0;
	plotPath = "";
	for (phase16OverviewIndex = 1; phase16OverviewIndex < lengthOf(summaryLines); phase16OverviewIndex++) {
		line = trimString(summaryLines[phase16OverviewIndex]);
		if (line == "")
			continue;
		phase16SetDelimitedFieldResult(line, 31);
		plotPath = phase16DelimitedFieldResult;
		if (plotPath == "" || plotPath == "NA" || plotPath == "0" || !File.exists(plotPath))
			continue;

		phase16SetSampleNameFromSummaryLineResult(line);
		sampleName = phase16TextResult;
		showStatus("Building batch overview: " + sampleName + " (" + (plotPosition + 1) + "/" + plotCount + ")...");
		showProgress(plotPosition, plotCount);
		panelRow = floor(plotPosition / gridColumns);
		panelColumn = plotPosition - panelRow * gridColumns;
		panelX = panelColumn * cellWidth;
		panelY = panelRow * (cellHeight + labelHeight);

		open(plotPath);
		sourceTitle = getTitle();
		run("Select All");
		run("Copy");
		selectWindow(overviewTitle);
		setColor("black");
		drawString(sampleName, panelX + 8, panelY + 21);
		makeRectangle(panelX, panelY + labelHeight, cellWidth, cellHeight);
		run("Paste");
		selectWindow(sourceTitle);
		close();
		plotPosition++;
	}

	showStatus("Saving Full Batch final-peak overview...");
	showProgress(plotCount, plotCount);
	selectWindow(overviewTitle);
	saveAs("PNG", phase16OverviewPlotPath);
	close();
	if (!File.exists(phase16OverviewPlotPath))
		phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A overview save command completed but file was not found: " + phase16OverviewPlotPath);
}

function createPhase16MasterResultsWorkbook() {
	showStatus("Preparing Batch_Master_Results source data...");
	showProgress(0, 4);
	preparePhase16WorkbookCaches();
	showStatus("Generating Batch_Master_Results workbook...");
	sampleQCText = buildPhase16SampleQCTableText();
	showStatus("Writing Batch_Master_Results: Sample_QC");
	showProgress(1, 4);
	peakSummaryText = buildPhase16PeakAnalysisSummaryTableText();
	showStatus("Writing Batch_Master_Results: Peak_Analysis_Summary");
	showProgress(2, 4);

	workbookText = "<?xml version=\"1.0\"?>\n";
	workbookText = workbookText + "<?mso-application progid=\"Excel.Sheet\"?>\n";
	workbookText = workbookText + "<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\" xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\" xmlns:html=\"http://www.w3.org/TR/REC-html40\">\n";
	workbookText = workbookText + "<Styles><Style ss:ID=\"Header\"><Font ss:Bold=\"1\"/></Style><Style ss:ID=\"Cell\"><Alignment ss:Vertical=\"Top\"/></Style></Styles>\n";
	workbookText = appendPhase16XmlSheetFromDelimitedText(workbookText, "Sample_QC", sampleQCText);
	workbookText = appendPhase16XmlSheetFromDelimitedText(workbookText, "Peak_Analysis_Summary", peakSummaryText);
	showStatus("Writing Batch_Master_Results: Baseline_Correction_Master");
	showProgress(3, 4);
	workbookText = appendPhase16XmlSheetFromFile(workbookText, "Baseline_Correction_Master", phase15BaselineCorrectionMasterPath);
	showStatus("Writing Batch_Master_Results: Processing_Steps_Master");
	workbookText = appendPhase16XmlSheetFromFile(workbookText, "Processing_Steps_Master", phase15ProcessingStepsMasterPath);
	workbookText = workbookText + "</Workbook>\n";

	showStatus("Saving Batch_Master_Results workbook...");
	File.saveString(workbookText, phase16MasterWorkbookPath);
	if (!File.exists(phase16MasterWorkbookPath)) {
		phase16ExportError = appendWarning(phase16ExportError, "Phase 16A master results workbook was not created: " + phase16MasterWorkbookPath);
		showStatus("Batch_Master_Results generation failed");
	} else {
		showStatus("Batch_Master_Results generation complete");
		showProgress(4, 4);
	}
}

function preparePhase16WorkbookCaches() {
	phase16DurationSafeNames = newArray(sampleCount);
	phase16DurationValues = newArray(sampleCount);
	phase16DurationCacheCount = 0;
	phase16BaselineMasterLines = newArray(0);

	if (File.exists(phase15BaselineCorrectionMasterPath)) {
		phase16BaselineText = File.openAsString(phase15BaselineCorrectionMasterPath);
		phase16BaselineMasterLines = split(phase16BaselineText, "\n");
	}

	if (!File.exists(phase15TimeSeriesMasterPath))
		return;
	phase16TimeSeriesText = File.openAsString(phase15TimeSeriesMasterPath);
	phase16TimeSeriesLines = split(phase16TimeSeriesText, "\n");
	phase16CurrentSafeName = "";
	phase16CurrentFoundTime = false;
	phase16CurrentMinTime = 0;
	phase16CurrentMaxTime = 0;
	for (phase16CacheTimeIndex = 1; phase16CacheTimeIndex < lengthOf(phase16TimeSeriesLines); phase16CacheTimeIndex++) {
		phase16CacheLine = trimString(phase16TimeSeriesLines[phase16CacheTimeIndex]);
		if (phase16CacheLine == "")
			continue;
		phase16SetDelimitedFieldResult(phase16CacheLine, 6);
		phase16CacheSafeName = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(phase16CacheLine, 9);
		phase16CacheTimeValue = phase16ParseNumber(phase16DelimitedFieldResult);
		if (phase16CacheSafeName != phase16CurrentSafeName) {
			if (phase16CurrentSafeName != "" && phase16CurrentFoundTime && phase16DurationCacheCount < sampleCount) {
				phase16DurationSafeNames[phase16DurationCacheCount] = phase16CurrentSafeName;
				phase16DurationValues[phase16DurationCacheCount] = phase16FormatSummaryNumber(phase16CurrentMaxTime - phase16CurrentMinTime);
				phase16DurationCacheCount++;
			}
			phase16CurrentSafeName = phase16CacheSafeName;
			phase16CurrentFoundTime = false;
		}
		if (isNaN(phase16CacheTimeValue))
			continue;
		if (!phase16CurrentFoundTime) {
			phase16CurrentMinTime = phase16CacheTimeValue;
			phase16CurrentMaxTime = phase16CacheTimeValue;
			phase16CurrentFoundTime = true;
		} else {
			if (phase16CacheTimeValue < phase16CurrentMinTime)
				phase16CurrentMinTime = phase16CacheTimeValue;
			if (phase16CacheTimeValue > phase16CurrentMaxTime)
				phase16CurrentMaxTime = phase16CacheTimeValue;
		}
	}
	if (phase16CurrentSafeName != "" && phase16CurrentFoundTime && phase16DurationCacheCount < sampleCount) {
		phase16DurationSafeNames[phase16DurationCacheCount] = phase16CurrentSafeName;
		phase16DurationValues[phase16DurationCacheCount] = phase16FormatSummaryNumber(phase16CurrentMaxTime - phase16CurrentMinTime);
		phase16DurationCacheCount++;
	}
}

function buildPhase16SampleQCTableText() {
	header = "Sample" + outputFieldDelimiter + "Final_Status" + outputFieldDelimiter + "Include_For_Analysis_Suggested" + outputFieldDelimiter + "Exclusion_or_Warning_Reason" + outputFieldDelimiter + "Raw_Peak_Count" + outputFieldDelimiter + "Final_Peak_Count" + outputFieldDelimiter + "Recording_Duration_s" + outputFieldDelimiter + "Baseline_Anchor_Count" + outputFieldDelimiter + "Requested_Polynomial_Degree" + outputFieldDelimiter + "Actual_Polynomial_Degree" + outputFieldDelimiter + "Baseline_Fallback_Used" + outputFieldDelimiter + "Raw_Only_Export" + outputFieldDelimiter + "No_Raw_Peaks" + outputFieldDelimiter + "Baseline_Correction_Status" + outputFieldDelimiter + "Second_Spiky_Status" + outputFieldDelimiter + "Notes_or_Warnings";
	tableText = header + "\n";
	if (!File.exists(phase15SampleSummaryPath))
		return tableText;

	summaryText = File.openAsString(phase15SampleSummaryPath);
	summaryLines = split(summaryText, "\n");
	for (phase16QCIndex = 1; phase16QCIndex < lengthOf(summaryLines); phase16QCIndex++) {
		line = trimString(summaryLines[phase16QCIndex]);
		if (line == "")
			continue;
		phase16SetSampleNameFromSummaryLineResult(line);
		sampleName = phase16TextResult;
		phase16SetDelimitedFieldResult(line, 8);
		safeName = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 10);
		finalStatus = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 9);
		qcStatus = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 14);
		failureDetail = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 15);
		warningText = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 25);
		preliminaryPeakPath = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 23);
		finalPeakCount = phase16CleanMissingText(phase16DelimitedFieldResult);
		recordingDuration = phase16GetRecordingDurationForSample(safeName);
		rawPeakCount = phase16CountDataRowsInDelimitedFile(preliminaryPeakPath);
		baselineAnchorCount = phase16GetBaselineFieldForSample(safeName, 15);
		requestedDegree = phase16GetBaselineFieldForSample(safeName, 17);
		actualDegree = phase16GetBaselineFieldForSample(safeName, 18);
		baselineStatus = phase16GetBaselineFieldForSample(safeName, 9);
		phase16SetDelimitedFieldResult(line, 22);
		secondSpikyStatus = phase16DelimitedFieldResult;
		noRawPeaks = "No";
		if (indexOf(failureDetail, "No raw peaks detected") >= 0 || indexOf(warningText, "No raw peaks detected") >= 0)
			noRawPeaks = "Yes";
		baselineFallbackUsed = "No";
		if (requestedDegree != "" && requestedDegree != "NA" && actualDegree != "" && actualDegree != "NA" && requestedDegree != actualDegree)
			baselineFallbackUsed = "Yes";
		rawOnlyExport = "No";
		if (noRawPeaks == "Yes" || finalPeakCount == "" || finalPeakCount == "NA")
			rawOnlyExport = "Yes";
		includeSuggested = "Yes";
		if (qcStatus == "Failed" || qcStatus == "Skipped" || startsWith(finalStatus, "Failed") || startsWith(finalStatus, "Skipped") || noRawPeaks == "Yes")
			includeSuggested = "No";
		else if (qcStatus == "Warning")
			includeSuggested = "Review";
		reasonText = failureDetail;
		if (reasonText == "" || reasonText == "NA")
			reasonText = warningText;
		if (reasonText == "")
			reasonText = "NA";
		notesText = warningText;
		if (notesText == "")
			notesText = "NA";

		rowText = phase16WorkbookCellText(sampleName);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(finalStatus);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(includeSuggested);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(reasonText);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(rawPeakCount);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(finalPeakCount);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(recordingDuration);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(baselineAnchorCount);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(requestedDegree);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(actualDegree);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(baselineFallbackUsed);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(rawOnlyExport);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(noRawPeaks);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(baselineStatus);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(secondSpikyStatus);
		rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(notesText);
		tableText = tableText + rowText + "\n";
	}
	return tableText;
}

function buildPhase16PeakAnalysisSummaryTableText() {
	header = "Sample" + outputFieldDelimiter + "Analysis_Source" + outputFieldDelimiter + "N_peaks" + outputFieldDelimiter + "Recording_Duration_s" + outputFieldDelimiter + "BPM_count" + outputFieldDelimiter + "Mean_IBI_s" + outputFieldDelimiter + "BPM_from_IBI" + outputFieldDelimiter + "IBI_SD_s" + outputFieldDelimiter + "IBI_CV_pct" + outputFieldDelimiter + "Mean_Amplitude_dF_F0" + outputFieldDelimiter + "Median_Amplitude_dF_F0" + outputFieldDelimiter + "Amplitude_SD" + outputFieldDelimiter + "Amplitude_CV_pct" + outputFieldDelimiter + "Mean_APeak" + outputFieldDelimiter + "Mean_Baseline_Bl" + outputFieldDelimiter + "Mean_Time2Pk_s" + outputFieldDelimiter + "Mean_FWHM_s" + outputFieldDelimiter + "Mean_FW20_s" + outputFieldDelimiter + "Mean_FW80_s" + outputFieldDelimiter + "Mean_LW50_s" + outputFieldDelimiter + "Mean_LW20_s" + outputFieldDelimiter + "Mean_LW80_s" + outputFieldDelimiter + "Mean_RW50_s" + outputFieldDelimiter + "Mean_RW20_s" + outputFieldDelimiter + "Mean_RW80_s" + outputFieldDelimiter + "Mean_Approx_Area_Amp_x_FWHM";
	tableText = header + "\n";
	if (!File.exists(phase15SampleSummaryPath))
		return tableText;

	summaryText = File.openAsString(phase15SampleSummaryPath);
	summaryLines = split(summaryText, "\n");
	for (phase16SummaryIndex = 1; phase16SummaryIndex < lengthOf(summaryLines); phase16SummaryIndex++) {
		line = trimString(summaryLines[phase16SummaryIndex]);
		if (line == "")
			continue;
		phase16SetSampleNameFromSummaryLineResult(line);
		sampleName = phase16TextResult;
		phase16SetDelimitedFieldResult(line, 8);
		safeName = phase16DelimitedFieldResult;
		duration = phase16GetRecordingDurationForSample(safeName);
		phase16SetDelimitedFieldResult(line, 23);
		finalPeakCount = phase16ParseNumber(phase16DelimitedFieldResult);
		phase16SetDelimitedFieldResult(line, 25);
		rawPeakPath = phase16DelimitedFieldResult;
		noRawPeaks = false;
		phase16SetDelimitedFieldResult(line, 14);
		failureDetail = phase16DelimitedFieldResult;
		phase16SetDelimitedFieldResult(line, 15);
		warningText = phase16DelimitedFieldResult;
		if (indexOf(failureDetail, "No raw peaks detected") >= 0 || indexOf(warningText, "No raw peaks detected") >= 0)
			noRawPeaks = true;

		if (!isNaN(finalPeakCount) && finalPeakCount > 0)
			rowText = buildPhase16PeakSummaryRowFromFile(sampleName, safeName, "Corrected_dF_F0_Final_Spiky", duration, phase15FinalPeakMasterPath, true);
		else if (rawPeakPath != "" && rawPeakPath != "NA" && File.exists(rawPeakPath))
			rowText = buildPhase16PeakSummaryRowFromFile(sampleName, safeName, "Raw_Trace_First_Spiky", duration, rawPeakPath, false);
		else if (noRawPeaks)
			rowText = buildPhase16EmptyPeakSummaryRow(sampleName, "Raw_Only_No_Final_Peaks", "0", duration);
		else
			rowText = buildPhase16EmptyPeakSummaryRow(sampleName, "No_Available_Peak_Table", "NA", duration);
		tableText = tableText + rowText + "\n";
	}
	return tableText;
}

function buildPhase16PeakSummaryRowFromFile(sampleName, safeName, analysisSource, durationText, sourcePath, sourceIsFinalMaster) {
	if (sourcePath == "" || sourcePath == "NA" || sourcePath == "0" || !File.exists(sourcePath)) {
		emptySummaryRow = buildPhase16EmptyPeakSummaryRow(sampleName, analysisSource, "NA", durationText);
		return emptySummaryRow;
	}
	sourceText = File.openAsString(sourcePath);
	sourceLines = split(sourceText, "\n");
	if (lengthOf(sourceLines) <= 1) {
		emptySummaryRow = buildPhase16EmptyPeakSummaryRow(sampleName, analysisSource, "0", durationText);
		return emptySummaryRow;
	}
	headerLine = trimString(sourceLines[0]);
	headerFields = split(headerLine, outputFieldDelimiter);
	idxSafeName = phase16FindHeadingIndex(headerFields, "Sanitized_File_Name");
	idxIBI = phase16FindMetricIndex(headerFields, "Pk2Pk_s", "Pk2Pk (s)");
	idxAmplitude = phase16FindHeadingIndex(headerFields, "Amplitude");
	idxAPeak = phase16FindHeadingIndex(headerFields, "APeak");
	idxBaseline = phase16FindMetricIndex(headerFields, "Spiky_Baseline_Bl", "Baseline Bl");
	idxTime2Pk = phase16FindMetricIndex(headerFields, "Time2Pk_s", "Time2Pk (s)");
	idxFWHM = phase16FindMetricIndex(headerFields, "FWHM_s", "FWHM (s)");
	idxFW20 = phase16FindMetricIndex(headerFields, "FW20_s", "FW20 (s)");
	idxFW80 = phase16FindMetricIndex(headerFields, "FW80_s", "FW80 (s)");
	idxLW50 = phase16FindMetricIndex(headerFields, "LW50_s", "LW50 (s)");
	idxLW20 = phase16FindMetricIndex(headerFields, "LW20_s", "LW20 (s)");
	idxLW80 = phase16FindMetricIndex(headerFields, "LW80_s", "LW80 (s)");
	idxRW50 = phase16FindMetricIndex(headerFields, "RW50_s", "RW50 (s)");
	idxRW20 = phase16FindMetricIndex(headerFields, "RW20_s", "RW20 (s)");
	idxRW80 = phase16FindMetricIndex(headerFields, "RW80_s", "RW80 (s)");

	peakCount = 0;
	for (phase16PeakRow = 1; phase16PeakRow < lengthOf(sourceLines); phase16PeakRow++) {
		line = trimString(sourceLines[phase16PeakRow]);
		if (line == "")
			continue;
		if (sourceIsFinalMaster && idxSafeName >= 0) {
			phase16SetDelimitedFieldResult(line, idxSafeName);
			if (phase16DelimitedFieldResult != safeName)
				continue;
		}
		peakCount++;
	}
	if (peakCount <= 0) {
		emptySummaryRow = buildPhase16EmptyPeakSummaryRow(sampleName, analysisSource, "0", durationText);
		return emptySummaryRow;
	}

	ampValues = newArray(peakCount);
	ampCount = 0;
	sumIBI = 0; sumsqIBI = 0; countIBI = 0;
	sumAmp = 0; sumsqAmp = 0;
	sumAPeak = 0; countAPeak = 0;
	sumBaseline = 0; countBaseline = 0;
	sumTime2Pk = 0; countTime2Pk = 0;
	sumFWHM = 0; countFWHM = 0;
	sumFW20 = 0; countFW20 = 0;
	sumFW80 = 0; countFW80 = 0;
	sumLW50 = 0; countLW50 = 0;
	sumLW20 = 0; countLW20 = 0;
	sumLW80 = 0; countLW80 = 0;
	sumRW50 = 0; countRW50 = 0;
	sumRW20 = 0; countRW20 = 0;
	sumRW80 = 0; countRW80 = 0;
	sumArea = 0; countArea = 0;

	for (phase16PeakRow = 1; phase16PeakRow < lengthOf(sourceLines); phase16PeakRow++) {
		line = trimString(sourceLines[phase16PeakRow]);
		if (line == "")
			continue;
		if (sourceIsFinalMaster && idxSafeName >= 0) {
			phase16SetDelimitedFieldResult(line, idxSafeName);
			if (phase16DelimitedFieldResult != safeName)
				continue;
		}

		ibi = phase16GetNumericField(line, idxIBI);
		amp = phase16GetNumericField(line, idxAmplitude);
		fwhm = phase16GetNumericField(line, idxFWHM);
		if (!isNaN(ibi)) {
			sumIBI = sumIBI + ibi;
			sumsqIBI = sumsqIBI + ibi * ibi;
			countIBI = countIBI + 1;
		}
		if (!isNaN(amp)) {
			sumAmp = sumAmp + amp;
			sumsqAmp = sumsqAmp + amp * amp;
			ampValues[ampCount] = amp;
			ampCount = ampCount + 1;
		}
		value = phase16GetNumericField(line, idxAPeak); if (!isNaN(value)) { sumAPeak = sumAPeak + value; countAPeak = countAPeak + 1; }
		value = phase16GetNumericField(line, idxBaseline); if (!isNaN(value)) { sumBaseline = sumBaseline + value; countBaseline = countBaseline + 1; }
		value = phase16GetNumericField(line, idxTime2Pk); if (!isNaN(value)) { sumTime2Pk = sumTime2Pk + value; countTime2Pk = countTime2Pk + 1; }
		if (!isNaN(fwhm)) {
			sumFWHM = sumFWHM + fwhm;
			countFWHM = countFWHM + 1;
		}
		value = phase16GetNumericField(line, idxFW20); if (!isNaN(value)) { sumFW20 = sumFW20 + value; countFW20 = countFW20 + 1; }
		value = phase16GetNumericField(line, idxFW80); if (!isNaN(value)) { sumFW80 = sumFW80 + value; countFW80 = countFW80 + 1; }
		value = phase16GetNumericField(line, idxLW50); if (!isNaN(value)) { sumLW50 = sumLW50 + value; countLW50 = countLW50 + 1; }
		value = phase16GetNumericField(line, idxLW20); if (!isNaN(value)) { sumLW20 = sumLW20 + value; countLW20 = countLW20 + 1; }
		value = phase16GetNumericField(line, idxLW80); if (!isNaN(value)) { sumLW80 = sumLW80 + value; countLW80 = countLW80 + 1; }
		value = phase16GetNumericField(line, idxRW50); if (!isNaN(value)) { sumRW50 = sumRW50 + value; countRW50 = countRW50 + 1; }
		value = phase16GetNumericField(line, idxRW20); if (!isNaN(value)) { sumRW20 = sumRW20 + value; countRW20 = countRW20 + 1; }
		value = phase16GetNumericField(line, idxRW80); if (!isNaN(value)) { sumRW80 = sumRW80 + value; countRW80 = countRW80 + 1; }
		if (!isNaN(amp) && !isNaN(fwhm)) {
			sumArea = sumArea + amp * fwhm;
			countArea = countArea + 1;
		}
	}

	meanIBI = phase16Mean(sumIBI, countIBI);
	sdIBI = phase16SD(sumIBI, sumsqIBI, countIBI);
	meanAmp = phase16Mean(sumAmp, ampCount);
	sdAmp = phase16SD(sumAmp, sumsqAmp, ampCount);
	medianAmp = phase16MedianFromPrefix(ampValues, ampCount);
	duration = phase16ParseNumber(durationText);
	bpmCount = "NA";
	if (!isNaN(duration) && duration > 0)
		bpmCount = phase16FormatSummaryNumber(60 * peakCount / duration);
	bpmFromIBI = "NA";
	if (!isNaN(meanIBI) && meanIBI > 0)
		bpmFromIBI = phase16FormatSummaryNumber(60 / meanIBI);
	ibiCV = "NA";
	if (!isNaN(meanIBI) && meanIBI != 0 && !isNaN(sdIBI))
		ibiCV = phase16FormatSummaryNumber(100 * sdIBI / meanIBI);
	ampCV = "NA";
	if (!isNaN(meanAmp) && meanAmp != 0 && !isNaN(sdAmp))
		ampCV = phase16FormatSummaryNumber(100 * sdAmp / meanAmp);

	rowText = phase16WorkbookCellText(sampleName);
	rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(analysisSource);
	rowText = rowText + outputFieldDelimiter + peakCount;
	rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(durationText);
	rowText = rowText + outputFieldDelimiter + bpmCount;
	rowText = rowText + outputFieldDelimiter + phase16FormatSummaryNumber(meanIBI);
	rowText = rowText + outputFieldDelimiter + bpmFromIBI;
	rowText = rowText + outputFieldDelimiter + phase16FormatSummaryNumber(sdIBI);
	rowText = rowText + outputFieldDelimiter + ibiCV;
	rowText = rowText + outputFieldDelimiter + phase16FormatSummaryNumber(meanAmp);
	rowText = rowText + outputFieldDelimiter + phase16FormatSummaryNumber(medianAmp);
	rowText = rowText + outputFieldDelimiter + phase16FormatSummaryNumber(sdAmp);
	rowText = rowText + outputFieldDelimiter + ampCV;
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumAPeak, countAPeak);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumBaseline, countBaseline);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumTime2Pk, countTime2Pk);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumFWHM, countFWHM);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumFW20, countFW20);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumFW80, countFW80);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumLW50, countLW50);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumLW20, countLW20);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumLW80, countLW80);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumRW50, countRW50);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumRW20, countRW20);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumRW80, countRW80);
	rowText = rowText + outputFieldDelimiter + phase16FormatMean(sumArea, countArea);
	return rowText;
}

function buildPhase16EmptyPeakSummaryRow(sampleName, analysisSource, peakCountText, durationText) {
	rowText = phase16WorkbookCellText(sampleName);
	rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(analysisSource);
	rowText = rowText + outputFieldDelimiter + peakCountText;
	rowText = rowText + outputFieldDelimiter + phase16WorkbookCellText(durationText);
	for (phase16EmptyMetricIndex = 0; phase16EmptyMetricIndex < 22; phase16EmptyMetricIndex++)
		rowText = rowText + outputFieldDelimiter + "NA";
	return rowText;
}

function appendPhase16XmlSheetFromFile(workbookText, sheetName, sourcePath) {
	if (!File.exists(sourcePath)) {
		missingText = "Status" + outputFieldDelimiter + "Message\nMissing" + outputFieldDelimiter + sourcePath + "\n";
		workbookText = appendPhase16XmlSheetFromDelimitedText(workbookText, sheetName, missingText);
		return workbookText;
	}
	sourceText = File.openAsString(sourcePath);
	workbookText = appendPhase16XmlSheetFromDelimitedText(workbookText, sheetName, sourceText);
	return workbookText;
}

function appendPhase16XmlSheetFromDelimitedText(workbookText, sheetName, delimitedText) {
	workbookText = workbookText + "<Worksheet ss:Name=\"" + phase16XmlEscape(sheetName) + "\"><Table>\n";
	lines = split(delimitedText, "\n");
	wroteHeader = false;
	for (phase16XmlRowIndex = 0; phase16XmlRowIndex < lengthOf(lines); phase16XmlRowIndex++) {
		line = trimString(lines[phase16XmlRowIndex]);
		if (line == "")
			continue;
		fields = split(line, outputFieldDelimiter);
		if (!wroteHeader)
			workbookText = workbookText + "<Row ss:StyleID=\"Header\">";
		else
			workbookText = workbookText + "<Row>";
		for (phase16XmlCellIndex = 0; phase16XmlCellIndex < lengthOf(fields); phase16XmlCellIndex++) {
			phase16SetCleanTextResult(fields[phase16XmlCellIndex]);
			cellText = phase16TextResult;
			workbookText = workbookText + "<Cell><Data ss:Type=\"String\">" + phase16XmlEscape(cellText) + "</Data></Cell>";
		}
		workbookText = workbookText + "</Row>\n";
		wroteHeader = true;
	}
	workbookText = workbookText + "</Table><WorksheetOptions xmlns=\"urn:schemas-microsoft-com:office:excel\"><FreezePanes/><FrozenNoSplit/><SplitHorizontal>1</SplitHorizontal><TopRowBottomPane>1</TopRowBottomPane><ActivePane>2</ActivePane></WorksheetOptions></Worksheet>\n";
	return workbookText;
}

function phase16SetSampleNameFromSummaryLineResult(line) {
	phase16TextResult = "";
	phase16SetDelimitedFieldResult(line, 7);
	sampleName = phase16DelimitedFieldResult;
	if (sampleName == "" || sampleName == "NA") {
		phase16SetDelimitedFieldResult(line, 8);
		sampleName = phase16DelimitedFieldResult;
	}
	phase16TextResult = sampleName;
}

function phase16GetRecordingDurationForSample(safeName) {
	for (phase16DurationIndex = 0; phase16DurationIndex < phase16DurationCacheCount; phase16DurationIndex++) {
		if (phase16DurationSafeNames[phase16DurationIndex] == safeName)
			return phase16DurationValues[phase16DurationIndex];
	}
	return "NA";
}

function phase16GetBaselineFieldForSample(safeName, fieldIndex) {
	if (lengthOf(phase16BaselineMasterLines) == 0)
		return "NA";
	for (phase16BaselineIndex = 1; phase16BaselineIndex < lengthOf(phase16BaselineMasterLines); phase16BaselineIndex++) {
		line = trimString(phase16BaselineMasterLines[phase16BaselineIndex]);
		if (line == "")
			continue;
		phase16SetDelimitedFieldResult(line, 6);
		baselineSafeName = phase16DelimitedFieldResult;
		if (baselineSafeName == safeName) {
			phase16SetDelimitedFieldResult(line, fieldIndex);
			baselineFieldText = phase16DelimitedFieldResult;
			baselineFieldText = phase16CleanMissingText(baselineFieldText);
			return baselineFieldText;
		}
	}
	return "NA";
}

function phase16CountDataRowsInDelimitedFile(path) {
	if (path == "" || path == "NA" || path == "0" || !File.exists(path))
		return "NA";
	text = File.openAsString(path);
	lines = split(text, "\n");
	rowCountText = 0;
	for (phase16CountIndex = 1; phase16CountIndex < lengthOf(lines); phase16CountIndex++) {
		line = trimString(lines[phase16CountIndex]);
		if (line != "")
			rowCountText++;
	}
	return "" + rowCountText;
}

function phase16FindHeadingIndex(headerFields, headingName) {
	for (phase16HeadingIndex = 0; phase16HeadingIndex < lengthOf(headerFields); phase16HeadingIndex++) {
		phase16SetCleanTextResult(headerFields[phase16HeadingIndex]);
		headingText = phase16TextResult;
		if (headingText == headingName)
			return phase16HeadingIndex;
	}
	return -1;
}

function phase16FindMetricIndex(headerFields, headingOne, headingTwo) {
	indexOne = phase16FindHeadingIndex(headerFields, headingOne);
	if (indexOne >= 0)
		return indexOne;
	return phase16FindHeadingIndex(headerFields, headingTwo);
}

function phase16GetNumericField(line, fieldIndex) {
	if (fieldIndex < 0)
		return NaN;
	phase16SetDelimitedFieldResult(line, fieldIndex);
	fieldText = phase16DelimitedFieldResult;
	return phase16ParseNumber(fieldText);
}

function phase16SetDelimitedFieldResult(line, fieldIndex) {
	phase16DelimitedFieldResult = "";
	fields = split(line, outputFieldDelimiter);
	fieldText = "";
	if (fieldIndex < 0 || fieldIndex >= lengthOf(fields)) {
		phase16ExportWarning = appendWarning(phase16ExportWarning, "Phase 16A field extraction skipped out-of-range field index " + fieldIndex + " for row with " + lengthOf(fields) + " fields.");
		return;
	}
	fieldText = trimString(fields[fieldIndex]);
	phase16SetCleanTextResult(fieldText);
	phase16DelimitedFieldResult = phase16TextResult;
}

function phase16SetCleanTextResult(value) {
	text = trimString("" + value);
	if (lengthOf(text) >= 2 && startsWith(text, "\"") && endsWith(text, "\"")) {
		text = substring(text, 1, lengthOf(text) - 1);
		text = replace(text, "\"\"", "\"");
	}
	phase16TextResult = text;
}

function phase16ParseNumber(value) {
	phase16SetCleanTextResult(value);
	text = phase16TextResult;
	if (text == "" || text == "NA" || text == "NaN" || text == "null")
		return NaN;
	text = replace(text, ",", ".");
	if (!isClearlyNumericText(text))
		return NaN;
	return parseFloat(text);
}

function phase16Mean(sumValue, valueCount) {
	if (valueCount <= 0)
		return NaN;
	return sumValue / valueCount;
}

function phase16SD(sumValue, sumSqValue, valueCount) {
	if (valueCount <= 1)
		return NaN;
	variance = (sumSqValue - (sumValue * sumValue / valueCount)) / (valueCount - 1);
	if (variance < 0 && variance > -0.000000001)
		variance = 0;
	if (variance < 0)
		return NaN;
	return sqrt(variance);
}

function phase16MedianFromPrefix(values, valueCount) {
	if (valueCount <= 0)
		return NaN;
	trimmedValues = newArray(valueCount);
	for (phase16MedianCopyIndex = 0; phase16MedianCopyIndex < valueCount; phase16MedianCopyIndex++)
		trimmedValues[phase16MedianCopyIndex] = values[phase16MedianCopyIndex];
	Array.sort(trimmedValues);
	upperIndex = valueCount / 2;
	lowerIndex = floor(valueCount / 2);
	if (upperIndex != lowerIndex)
		return trimmedValues[lowerIndex];
	upperIndex = lowerIndex;
	lowerIndex = upperIndex - 1;
	return (trimmedValues[lowerIndex] + trimmedValues[upperIndex]) / 2;
}

function phase16FormatMean(sumValue, valueCount) {
	if (valueCount <= 0)
		return "NA";
	meanText = phase16FormatSummaryNumber(sumValue / valueCount);
	return meanText;
}

function phase16FormatSummaryNumber(value) {
	text = "" + value;
	if (text == "" || text == "NA" || isNaN(value))
		return "NA";
	formattedText = d2s(value, 3);
	while (indexOf(formattedText, ".") >= 0 && endsWith(formattedText, "0"))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (endsWith(formattedText, "."))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (outputDecimalSeparator == ",")
		formattedText = replace(formattedText, ".", ",");
	return formattedText;
}

function phase16WorkbookCellText(value) {
	text = "" + value;
	if (text == "")
		return "NA";
	text = replace(text, outputFieldDelimiter, " ");
	text = replace(text, "\t", " ");
	text = replace(text, "\n", " ");
	text = replace(text, "\r", " ");
	return text;
}

function phase16CleanMissingText(value) {
	text = "" + value;
	if (text == "")
		return "NA";
	return text;
}

function phase16XmlEscape(value) {
	text = "" + value;
	text = replace(text, "&", "&amp;");
	text = replace(text, "<", "&lt;");
	text = replace(text, ">", "&gt;");
	text = replace(text, "\"", "&quot;");
	return text;
}

function getPhase15BaselineCorrectionMethod() {
	phase15MethodText = "";
	if (baselineCurveMethod == "Polynomial")
		phase15MethodText = "Polynomial_Anchor_Based";
	else if (baselineCurveMethod != "")
		phase15MethodText = baselineCurveMethod;
	phase15MethodText = cleanPhase15Text(phase15MethodText);
	return phase15MethodText;
}

function getPhase15BaselineCorrectionStatus() {
	phase15StatusText = "Not_Started";
	if (phase6FitStatus == "Phase6_Polynomial_Baseline_Fit_Completed")
		phase15StatusText = "Success";
	else if (phase6FitStatus == "Phase6_Polynomial_Baseline_Fit_Failed")
		phase15StatusText = "Failed";
	else if (phase6FitStatus == "Phase6_Baseline_Method_Not_Supported")
		phase15StatusText = "Skipped_UnsupportedMethod";
	else if (phase5ValidationStatus != "" || phase4PlotValuesStatus != "")
		phase15StatusText = "Failed";
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15SampleQCStatus() {
	phase15StatusText = "Success";
	if (sampleStatuses[phase13CurrentSampleIndex] == "Failed")
		phase15StatusText = "Failed";
	else if (phase6BaselineReliabilityClass == "Baseline_HighRisk")
		phase15StatusText = "Warning";
	else if (phaseWarning != "" || sampleWarnings[phase13CurrentSampleIndex] != "")
		phase15StatusText = "Warning";
	else if (startsWith(sampleStatuses[phase13CurrentSampleIndex], "Skipped") || startsWith(sampleStatuses[phase13CurrentSampleIndex], "Not_Processed"))
		phase15StatusText = "Skipped";
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15StepQCStatus(stepStatus) {
	phase15StatusText = "Success";
	if (stepStatus == "")
		phase15StatusText = "Not_Started";
	else if (stepStatus == "Failed" || indexOf(stepStatus, "Failed") >= 0 || indexOf(stepStatus, "Missing") >= 0 || indexOf(stepStatus, "Not_Found") >= 0)
		phase15StatusText = "Failed";
	else if (indexOf(stepStatus, "Warning") >= 0 || indexOf(stepStatus, "With_Warnings") >= 0)
		phase15StatusText = "Warning";
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15TerminalAnalysisRole() {
	phase15RoleText = "Input_Raw_Trace";
	if (phase13FullBatchStoppedAfterFailure == "Yes" && runCompletionStatus == "Phase14_Stopped_Critical_Cleanup_Failure")
		phase15RoleText = "Cleanup";
	else if (phase10FinalOutputStatus != "")
		phase15RoleText = "Final_Peak_Detection";
	else if (phase9SecondSpikyStatus != "")
		phase15RoleText = "Final_Peak_Detection";
	else if (phase8PlotStatus != "")
		phase15RoleText = "Processed_Trace";
	else if (phase7CalculationStatus != "")
		phase15RoleText = "Processed_Trace";
	else if (phase6FitStatus != "")
		phase15RoleText = "Baseline_Correction";
	else if (phase5ValidationStatus != "")
		phase15RoleText = "Baseline_Anchor_Detection";
	else if (phase4PlotValuesStatus != "")
		phase15RoleText = "Baseline_Anchor_Detection";
	else if (phase3SpikyStatus != "")
		phase15RoleText = "Preliminary_Peak_Detection";
	phase15RoleText = cleanPhase15Text(phase15RoleText);
	return phase15RoleText;
}

function getPhase15TerminalPhaseStatus() {
	phase15StatusText = runCompletionStatus;
	if (phaseError != "" || sampleStatuses[phase13CurrentSampleIndex] == "Failed") {
		if (phase10FinalOutputStatus != "")
			phase15StatusText = phase10FinalOutputStatus;
		else if (phase9SecondSpikyStatus != "")
			phase15StatusText = phase9SecondSpikyStatus;
		else if (phase8PlotStatus != "")
			phase15StatusText = phase8PlotStatus;
		else if (phase7CalculationStatus != "")
			phase15StatusText = phase7CalculationStatus;
		else if (phase6FitStatus != "")
			phase15StatusText = phase6FitStatus;
		else if (phase5ValidationStatus != "")
			phase15StatusText = phase5ValidationStatus;
		else if (phase4PlotValuesStatus != "")
			phase15StatusText = phase4PlotValuesStatus;
		else if (phase3SpikyStatus != "")
			phase15StatusText = phase3SpikyStatus;
		else
			phase15StatusText = "Failed";
	}
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15FailureReason() {
	phase15ReasonText = "";
	if (phaseError != "") {
		phase15ReasonText = getPhase15TerminalAnalysisRole();
		phase15ReasonText = cleanPhase15Text(phase15ReasonText);
	}
	return phase15ReasonText;
}

function getPhase15FinalPeakDetectionPerformed() {
	phase15StatusText = "Not_Started";
	if (phase9SecondSpikyWasCalled == "Yes")
		phase15StatusText = "Performed";
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15FinalPeakDetectionStatus() {
	phase15StatusText = "Not_Started";
	if (phase10FinalOutputStatus == "Phase10_Final_Output_Saved") {
		if (phase10FinalPeakTableRowCount == 0)
			phase15StatusText = "Success_No_Peaks";
		else
			phase15StatusText = "Success";
	} else if (phase10FinalOutputStatus == "Failed" || phase9SecondSpikyStatus == "Failed") {
		phase15StatusText = "Failed";
	} else if (phase9SecondSpikyWasCalled == "Yes") {
		phase15StatusText = "Failed";
	}
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15InputStepStatus() {
	phase15StatusText = "Not_Started";
	if (phase2RawPlotCreateError != "")
		phase15StatusText = "Failed";
	else if (phase2PlotName != "")
		phase15StatusText = "Success";
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15ExportStepStatus() {
	phase15StatusText = "Not_Started";
	if (phase10FinalOutputStatus == "Phase10_Final_Output_Saved")
		phase15StatusText = "Success";
	else if (phase10FinalOutputStatus == "Failed" || phase3OutputSaveStatus != "Saved")
		phase15StatusText = getPhase15StepQCStatus(phase10FinalOutputStatus);
	phase15StatusText = cleanPhase15Text(phase15StatusText);
	return phase15StatusText;
}

function getPhase15QCFlags() {
	flags = "";
	if (phase6BaselineReliabilityClass != "" && phase6BaselineReliabilityClass != "Baseline_OK")
		flags = appendWarning(flags, phase6BaselineReliabilityClass);
	if (phase6FitReasonablenessWarning != "")
		flags = appendWarning(flags, "Baseline_Correction_Warning");
	if (phase8PlotWarning != "")
		flags = appendWarning(flags, "Endpoint_Warning");
	if (phase10FinalOutputWarning != "")
		flags = appendWarning(flags, "Final_Peak_Export_Warning");
	if (phase11WindowCleanupWarning != "")
		flags = appendWarning(flags, "Cleanup_Warning");
	flags = cleanPhase15Text(flags);
	return flags;
}

function verifyPhase15MasterTables() {
	missingMasterOutputs = "";
	if (phase15MasterTablesInitialized != "Yes")
		missingMasterOutputs = appendMissingOutput(missingMasterOutputs, "Phase 15A master table initialization");
	if (!File.exists(phase15SampleSummaryPath))
		missingMasterOutputs = appendMissingOutput(missingMasterOutputs, inputSourceFileStem + "_Sample_Summary_QC" + outputTableExtension);
	if (!File.exists(phase15FinalPeakMasterPath))
		missingMasterOutputs = appendMissingOutput(missingMasterOutputs, inputSourceFileStem + "_Final_Peak_Master" + outputTableExtension);
	if (!File.exists(phase15TimeSeriesMasterPath))
		missingMasterOutputs = appendMissingOutput(missingMasterOutputs, inputSourceFileStem + "_TimeSeries_Master" + outputTableExtension);
	if (!File.exists(phase15BaselineCorrectionMasterPath))
		missingMasterOutputs = appendMissingOutput(missingMasterOutputs, inputSourceFileStem + "_Baseline_Correction_Master" + outputTableExtension);
	if (!File.exists(phase15ProcessingStepsMasterPath))
		missingMasterOutputs = appendMissingOutput(missingMasterOutputs, inputSourceFileStem + "_Processing_Steps_Master" + outputTableExtension);
	return missingMasterOutputs;
}

function showConciseFinalRunDialog() {
	finalDialogTitle = buildConciseFinalDialogTitle();
	finalDialogText = buildConciseFinalDialogText();
	Dialog.create(finalDialogTitle);
	Dialog.addMessage(finalDialogText);
	Dialog.addCheckbox("Close remaining macro windows after this dialog", true);
	Dialog.show();
	return Dialog.getCheckbox();
}

function returnToMainMenuAfterInteractiveRunIfRequested() {
	if (validationModeUsed == "Yes")
		return;
	if (!returnToMainMenuAfterRun)
		return;

	sourcePath = batchMacroSourcePath;
	if (sourcePath == "" || sourcePath == "NaN") {
		showMessage("Return to main menu", "The run completed, but the macro file path was not available for automatic return to the main menu.\n\nStart the macro again manually to run another analysis.");
		return;
	}
	if (!File.exists(sourcePath)) {
		showMessage("Return to main menu", "The run completed, but the macro file could not be found for automatic return to the main menu:\n\n" + sourcePath + "\n\nStart the macro again manually to run another analysis.");
		return;
	}

	print("Return to main menu after run requested; relaunching macro menu from: " + sourcePath);
	runMacro(sourcePath);
}

function buildConciseFinalDialogTitle() {
	if (isFinalDialogFailedRun())
		return "Spiky Batch Analysis Failed";
	return "Spiky Batch Analysis Completed";
}

function buildConciseFinalDialogText() {
	finalTitleText = buildConciseFinalDialogTitle();
	finalSampleText = getFinalDialogSampleName();

	if (isFinalDialogFailedRun()) {
		finalFailedPhaseText = getFinalDialogFailedPhase();
		finalShortFailureReasonText = getFinalDialogShortFailureReason();
		text = "Run failed\n\n";
		text = text + "Sample: " + finalSampleText + "\n";
		text = text + "Failed phase: " + finalFailedPhaseText + "\n";
		text = text + "Reason: " + finalShortFailureReasonText + "\n\n";
		text = text + "Details are recorded in Run_Log.csv.\n";
	} else if (runMode == "Full Batch") {
		finalPhaseStatusText = buildFinalPhaseStatusSummary();
		finalWarningsText = buildFinalWarningsSummary();
		text = finalTitleText + "\n\n";
		text = text + "Mode: " + runMode + "\n\n";
		text = text + "Status:\n" + finalPhaseStatusText + "\n";
		text = text + finalWarningsText;
		text = text + "Details:\nRun_Log.csv";
	} else {
		finalPhaseStatusText = buildFinalPhaseStatusSummary();
		finalWarningsText = buildFinalWarningsSummary();
		text = finalTitleText + "\n\n";
		text = text + "Sample: " + finalSampleText + "\n";
		text = text + "Mode: " + runMode + "\n\n";
		text = text + "Status:\n" + finalPhaseStatusText + "\n";
		text = text + finalWarningsText;
		text = text + "Details:\nRun_Log.csv";
	}
	return text;
}

function getFinalDialogSampleName() {
	if (finalDialogSampleName != "" && finalDialogSampleName != "NaN")
		return finalDialogSampleName;
	return "Unknown";
}

function isFinalDialogFailedRun() {
	if (runMode == "Test First Sample Only" && phase10FinalOutputStatus != "Phase10_Final_Output_Saved")
		return true;
	if (runMode == "Full Batch" && phase13FullBatchStoppedAfterFailure == "Yes")
		return true;
	return false;
}

function buildFinalPhaseStatusSummary() {
	if (runMode == "Dry Run") {
		text = "PASS Dry Run: metadata complete\n";
		text = text + "SKIP Analysis phases\n";
		return text;
	}
	if (runMode == "Full Batch") {
		if (phase13FullBatchStoppedAfterFailure == "Yes")
			text = "STOP Phase 14 Full Batch: critical cleanup failure logged\n";
		else if (countPhase14FullBatchFailedSamples() > 0)
			text = "WARN Phase 14 Full Batch: completed with failed sample(s)\n";
		else
			text = "PASS Phase 14 Full Batch: all processed sample(s) passed\n";
		text = text + "Planned samples: " + fullBatchPlannedSampleCount + "\n";
		text = text + "Processed samples: " + fullBatchProcessedSampleCount + "\n";
		text = text + "Passed samples: " + countPhase14FullBatchPassedSamples() + "\n";
		text = text + "Failed samples: " + countPhase14FullBatchFailedSamples() + "\n";
		text = text + "Stopped early: " + phase13FullBatchStoppedAfterFailure + "\n";
		text = text + "Phase 15A master aggregation files created\n";
		return text;
	}

	text = "PASS Phase 1-10: analysis complete\n";
	if (phase11WindowCleanupWarning != "")
		text = text + "WARN Phase 11: cleanup complete\n";
	else
		text = text + "PASS Phase 11: cleanup complete\n";
	return text;
}

function countPhase14FullBatchFailedSamples() {
	failedCount = 0;
	for (phase14CountIndex = 0; phase14CountIndex < fullBatchProcessedSampleCount; phase14CountIndex++) {
		if (sampleStatuses[phase14CountIndex] == "Failed")
			failedCount++;
	}
	return failedCount;
}

function countPhase14FullBatchPassedSamples() {
	passedCount = 0;
	for (phase14CountIndex = 0; phase14CountIndex < fullBatchProcessedSampleCount; phase14CountIndex++) {
		if (sampleStatuses[phase14CountIndex] != "Failed")
			passedCount++;
	}
	return passedCount;
}

function getFinalDialogFailedPhase() {
	if (spikyBatchOrientationSupportError != "")
		return "Spiky orientation preflight";
	if (phase10FinalOutputStatus == "Failed" || phase10FinalOutputError != "")
		return "Phase 10";
	if (phase9SecondSpikyStatus == "Failed" || phase9CorrectedInputError != "" || phase9SecondSpikyError != "")
		return "Phase 9";
	if (phase8PlotError != "")
		return "Phase 8";
	if (phase7Error != "")
		return "Phase 7";
	if (phase6FitError != "" || phase6FitReasonablenessError != "")
		return "Phase 6";
	if (phase5ValidationError != "")
		return "Phase 5";
	if (phase4PlotValuesError != "")
		return "Phase 4";
	if (phase3SpikyStatus == "Phase3_Raw_Plot_Not_Found" || phase3SpikyStatus == "Phase3_Selected_Window_Not_Plot" || phase3SpikyStatus == "Phase3_Spiky_Output_Missing")
		return "Phase 3";
	return runCompletionStatus;
}

function getFinalDialogShortFailureReason() {
	finalFailureReasonText = "";
	if (phaseError != "")
		finalFailureReasonText = "" + phaseError;
	else if (phase10FinalOutputError != "")
		finalFailureReasonText = "" + phase10FinalOutputError;
	else if (phase9SecondSpikyError != "")
		finalFailureReasonText = "" + phase9SecondSpikyError;
	else if (phase9CorrectedInputError != "")
		finalFailureReasonText = "" + phase9CorrectedInputError;
	else
		finalFailureReasonText = "" + runCompletionStatus;

	if (finalFailureReasonText == "" || finalFailureReasonText == "NaN")
		finalFailureReasonText = "No concise failure reason was available.";

	finalTruncatedFailureReasonText = truncateFinalDialogText(finalFailureReasonText, 300);
	return finalTruncatedFailureReasonText;
}

function buildFinalWarningsSummary() {
	if (phaseWarning == "" && phase10FinalOutputWarning == "" && phase11WindowCleanupWarning == "")
		return "Warnings:\nNone\n\n";

	text = "Warnings:\n";
	if (indexOf(phaseWarning, "Endpoint handling") >= 0 || indexOf(phaseWarning, "extrapolated") >= 0)
		text = text + "- Endpoint extrapolation logged.\n";
	if (indexOf(phase10FinalOutputWarning, "Phase 10 export headings adjusted") >= 0)
		text = text + "- Phase 10 export headings adjusted.\n";
	else if (phase10FinalOutputWarning != "")
		text = text + "- Phase 10 export warning logged.\n";
	if (phase11WindowCleanupWarning != "")
		text = text + "- Phase 11 cleanup warning logged.\n";
	if (indexOf(phaseWarning, "Macro copy status") >= 0)
		text = text + "- Macro copy warning logged.\n";
	if (text == "Warnings:\n")
		text = text + "- Warnings were logged; see Run_Log.csv.\n";
	text = text + "\n";
	return text;
}

function truncateFinalDialogText(value, maxLength) {
	finalTextValue = "" + value;
	finalMaxLength = 300;
	if (maxLength > 0)
		finalMaxLength = maxLength;
	if (finalMaxLength < 10)
		finalMaxLength = 10;
	if (finalTextValue == "" || finalTextValue == "NaN")
		return "No concise text was available.";
	if (lengthOf(finalTextValue) <= finalMaxLength)
		return finalTextValue;
	finalTrimLength = finalMaxLength - 3;
	finalTruncatedText = substring(finalTextValue, 0, finalTrimLength);
	finalTruncatedText = finalTruncatedText + "...";
	return finalTruncatedText;
}

function runPhase11CloseRemainingMacroWindowsAfterFinalDialog() {
	phase11WindowCleanupStatus = "Phase11_PostDialog_Close_Remaining_Started";
	phase11WindowCleanupKeptOpen = appendWarning(phase11WindowCleanupKeptOpen, "Raw input table preserved after final dialog checkbox: " + activeTableTitle);

	closeRemainingMacroWindowAfterFinalDialog(phase2PlotName, "Phase 2 raw first-Spiky input plot closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase3SpikyDetectedPeaksPlotName, "First-Spiky detected-peaks plot closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(getSavedFileWindowTitle(phase3DetectedPeaksPlotSavePath), "Saved Phase 3 first-Spiky detected-peaks PNG image window closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase3SpikyPeakAnalysisTableName, "First-Spiky peak-analysis table closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase4PlotValuesTableName, "Plot Values table closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase8PlotWindowName, "Phase 8 baseline reconstruction QC plot closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(getSavedFileWindowTitle(phase8PlotSavePath), "Saved Phase 8 baseline reconstruction PNG image window closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase9CorrectedInputPlotName, "Corrected DeltaF/F0 second-Spiky input plot closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase9ExistingResultsBackupName, "Phase 9 macro-generated Results backup closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase9SecondSpikyDetectedPeaksPlotName, "Final second-Spiky detected-peaks plot closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase10FinalPeakPlotSourceName, "Final peak-analysis plot source closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(getSavedFileWindowTitle(phase10FinalPeakPlotSavePath), "Saved final peak-analysis PNG image window closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase9SecondSpikyPeakAnalysisTableName, "Second-Spiky peak-analysis table closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog(phase10FinalPeakTableSourceName, "Final peak-analysis table source closed after final dialog checkbox.");
	closeRemainingMacroWindowAfterFinalDialog("Log", "ImageJ Log window closed after final dialog checkbox because it was not open at macro start.");

	if (phase11WindowCleanupWarning == "")
		phase11WindowCleanupStatus = "Phase11_PostDialog_Close_Remaining_Completed";
	else
		phase11WindowCleanupStatus = "Phase11_PostDialog_Close_Remaining_Completed_With_Warnings";
}

function closeRemainingMacroWindowAfterFinalDialog(windowName, reason) {
	if (windowName == "")
		return;
	if (!isOpen(windowName))
		return;
	if (!isPhase11PostDialogOwnedRemainingWindow(windowName)) {
		phase11PostDialogWarning = "Phase 11 final-dialog cleanup preserved window because ownership was not confirmed: " + windowName;
		phase11WindowCleanupWarning = appendWarning(phase11WindowCleanupWarning, phase11PostDialogWarning);
		phaseWarning = appendWarning(phaseWarning, phase11PostDialogWarning);
		phase11WindowCleanupKeptOpen = appendWarning(phase11WindowCleanupKeptOpen, windowName);
		return;
	}

	selectWindow(windowName);
	run("Close");
	wait(100);
	if (isOpen(windowName)) {
		selectWindow(windowName);
		close();
		wait(100);
	}
	if (isOpen(windowName)) {
		phase11PostDialogWarning = "Phase 11 final-dialog cleanup could not close window: " + windowName;
		phase11WindowCleanupWarning = appendWarning(phase11WindowCleanupWarning, phase11PostDialogWarning);
		phaseWarning = appendWarning(phaseWarning, phase11PostDialogWarning);
	} else
		phase11WindowCleanupClosedWindows = appendWarning(phase11WindowCleanupClosedWindows, windowName + " [" + reason + "]");
}

function isPhase11PostDialogOwnedRemainingWindow(windowName) {
	if (windowName == activeTableTitle)
		return false;
	if (windowName == phase3ExistingResultsBackupName)
		return false;
	if (windowName == phase4ExistingResultsBackupName)
		return false;
	if (windowName == phase4ExistingPlotValuesBackupName)
		return false;
	if (windowName == "Log") {
		if (logWindowWasOpenAtStart)
			return false;
		return true;
	}
	if (windowName == phase8PlotWindowName)
		return true;
	if (windowName == getSavedFileWindowTitle(phase3DetectedPeaksPlotSavePath))
		return true;
	if (windowName == getSavedFileWindowTitle(phase8PlotSavePath))
		return true;
	if (windowName == phase9SecondSpikyDetectedPeaksPlotName)
		return true;
	if (windowName == phase10FinalPeakPlotSourceName)
		return true;
	if (windowName == getSavedFileWindowTitle(phase10FinalPeakPlotSavePath))
		return true;
	if (isPhase11OwnedCleanupTarget(windowName))
		return true;
	return false;
}

function selectInputTableWindow() {
	allWindowTitles = getList("window.titles");
	windowCount = lengthOf(allWindowTitles);
	readableTableTitles = newArray(windowCount);
	readableTableCount = 0;
	activeTitleAtStart = getInfo("window.title");

	for (windowIndex = 0; windowIndex < windowCount; windowIndex++) {
		candidateTitle = allWindowTitles[windowIndex];
		selectWindow(candidateTitle);
		candidateWindowType = getInfo("window.type");

		if (candidateWindowType == "ResultsTable") {
			candidateHeadings = Table.headings;
			candidateRowCount = Table.size;

			if (candidateHeadings != "" && candidateRowCount > 0) {
				readableTableTitles[readableTableCount] = candidateTitle;
				readableTableCount++;
			}
		}
	}

	if (readableTableCount == 0) {
		exit("No readable ImageJ table was found.\n\nExpected format:\nColumn 1 = Time\nColumns 2+ = sample traces\n\nOpen the CSV/table in Fiji and run the macro again.");
	}

	if (readableTableCount == 1) {
		selectedInputTableTitle = readableTableTitles[0];
		selectWindow(selectedInputTableTitle);
		selectionStatus = "Auto_Selected_Single_Readable_Table";
		return selectionStatus;
	}

	tableChoices = newArray(readableTableCount);
	defaultTableChoice = readableTableTitles[0];
	for (tableIndex = 0; tableIndex < readableTableCount; tableIndex++) {
		tableChoices[tableIndex] = readableTableTitles[tableIndex];
		if (readableTableTitles[tableIndex] == activeTitleAtStart)
			defaultTableChoice = readableTableTitles[tableIndex];
	}

	Dialog.create("Select Input Table");
	Dialog.addMessage("Multiple readable tables are open. Select the raw input table.\nExpected format: Time in column 1, sample traces from column 2.");
	Dialog.addChoice("Input table", tableChoices, defaultTableChoice);
	Dialog.show();

	selectedInputTableTitle = Dialog.getChoice();
	selectWindow(selectedInputTableTitle);
	selectionStatus = "User_Selected_From_Multiple_Readable_Tables";
	return selectionStatus;
}

function writeRunLog(path) {
	runLogText = "Timestamp,Macro_Version,Run_Mode,Change_Keyword,Output_Table_Format,Output_Field_Delimiter,Output_Decimal_Separator,Output_Table_Extension,Output_Thousands_Separators,Input_Table_Selection,Baseline_Curve_Method,Phase6_Polynomial_Degree_Selected,Table_Title,Row_Count,Column_Count,Sample_Count,Sample_Index,Source_Column_Index,Original_Sample_Name,Unique_Sample_Name,Sanitized_File_Name,Phase2_Source_Sample,Phase2_Plot_Name,Phase3_Raw_Plot_Name,Phase3_Spiky_Command,Phase3_Spiky_Was_Called,Phase3_Existing_Results_Backup,Phase3_Detected_Peaks_Plot,Phase3_Peak_Analysis_Table,Phase3_Open_Windows_After_Spiky,Phase3_Detected_Peaks_Save_Path,Phase3_Peak_Analysis_Save_Path,Phase3_Output_Save_Status,Phase4_PlotValues_Status,Phase4_PlotValues_Table_Name,Phase4_PlotValues_Save_Path,Phase4_PlotValues_Column_Count,Phase4_PlotValues_Column_Headings,Phase4_Open_Windows_Before,Phase4_Open_Windows_After,Phase4_Existing_Results_Backup,Phase4_Existing_PlotValues_Backup,Phase4_Warning,Phase4_Error,Phase5_Validation_Status,Phase5_Source_PlotValues_Table,Phase5_Predicted_X_Column,Phase5_Predicted_Y_Column,Phase5_Prediction_Reason,Phase5_Anchor_Count,Phase5_BaselineAnchors_Save_Path,Phase5_Validation_Window_Mode,Phase5_Local_Baseline_Window_Points,Phase5_Peak_Exclusion_Window_Points,Phase5_Median_Time_Step,Phase5_Local_Baseline_Window_TimeUnits,Phase5_Peak_Exclusion_Window_TimeUnits,Phase5_Local_Baseline_Tolerance_Percent,Phase5_Peak_Separation_Percent,Phase5_Raw_X_Min,Phase5_Raw_X_Max,Phase5_Raw_Y_Min,Phase5_Raw_Y_Max,Phase5_Raw_Y_Range,Phase5_Anchor_Y_Min,Phase5_Anchor_Y_Max,Phase5_Peak_Marker_X_Column,Phase5_Peak_Marker_Y_Column,Phase5_Candidate_Diagnostics,Phase5_Warning,Phase5_Error,Phase6_Fit_Status,Phase6_Baseline_Model,Phase6_Supported_Degrees,Phase6_Polynomial_Degree_Used,Phase6_Fit_Function,Phase6_Coefficient_Order,Phase6_Coefficient_Count,Phase6_Coefficients,Phase6_Anchor_Count,Phase6_Source_Anchor_Array_Length,Phase6_Fit_Input_Anchor_Count,Phase6_Unused_Source_Anchor_Entries,Phase6_Fit_Input_Array_Status,Phase6_Fit_Input_First_Time,Phase6_Fit_Input_Last_Time,Phase6_Fit_Input_First_Value,Phase6_Fit_Input_Last_Value,Phase6_Anchor_Residual_RMSE,Phase6_Anchor_Residual_MaxAbs,Phase6_Anchor_Residual_MaxPercentAbs,Phase6_Anchor_Residual_Warn_Percent,Phase6_Anchor_Residual_Fail_Percent,Phase6_Raw_Time_Min,Phase6_Raw_Time_Max,Phase6_Anchor_Time_Min,Phase6_Anchor_Time_Max,Phase6_Raw_Rows_Before_First_Anchor,Phase6_Raw_Rows_After_Last_Anchor,Phase6_Raw_Percent_Outside_Anchor_Support,Phase6_First_Fitted_Baseline,Phase6_Last_Fitted_Baseline,Phase6_Fit_Reasonableness_Status,Phase6_Fit_Reasonableness_Error,Phase6_Fit_Reasonableness_Warning,Phase6_Diagnostic_Table_Save_Status,Phase6_Diagnostic_Table_Save_Path,Phase6_Baseline_Value_Count,Phase6_Fit_RMSE,Phase6_Fit_R2,Phase6_Fitted_Baseline_Min,Phase6_Fitted_Baseline_Mean,Phase6_Fitted_Baseline_Max,Phase6_Warning,Phase6_Error,Phase7_Calculation_Status,Phase7_Raw_Value_Count,Phase7_Baseline_Value_Count,Phase7_DeltaF_Value_Count,Phase7_DeltaF_Over_F0_Value_Count,Phase7_DeltaF_Over_F0_Percent_Value_Count,Phase7_Raw_Baseline_Alignment_Status,Phase7_Min_DeltaF,Phase7_Mean_DeltaF,Phase7_Max_DeltaF,Phase7_Min_DeltaF_Over_F0,Phase7_Mean_DeltaF_Over_F0,Phase7_Max_DeltaF_Over_F0,Phase7_Min_DeltaF_Over_F0_Percent,Phase7_Mean_DeltaF_Over_F0_Percent,Phase7_Max_DeltaF_Over_F0_Percent,Phase7_Invalid_Baseline_Value_Count,Phase7_Invalid_Corrected_Value_Count,Phase7_First_Invalid_Row,Phase7_First_Invalid_Reason,Phase7_Minimum_Safe_Baseline_Abs,Phase7_Warning,Phase7_Error,Phase7_Corrected_Trace_Table_Save_Status,Phase7_Corrected_Trace_Table_Save_Path,Phase8_Baseline_Reconstruction_Plot_Status,Phase8_Baseline_Reconstruction_Plot_Save_Path,Phase8_Baseline_Reconstruction_Plot_Warning,Phase8_Baseline_Reconstruction_Plot_Error,Phase9_SecondSpiky_Status,Phase9_Corrected_Input_Plot_Name,Phase9_Corrected_Input_Value_Count,Phase9_Corrected_Input_Y_Min,Phase9_Corrected_Input_Y_Max,Phase9_Corrected_Input_Warning,Phase9_Corrected_Input_Error,Phase9_SecondSpiky_Was_Called,Phase9_Existing_Results_Backup,Phase9_SecondSpiky_DetectedPeaks_Plot_Name,Phase9_SecondSpiky_PeakAnalysis_Table_Name,Phase9_Open_Windows_After_Spiky,Phase9_SecondSpiky_Warning,Phase9_SecondSpiky_Error,Phase10_Final_Output_Status,Phase10_Final_Peak_Table_Source_Name,Phase10_Final_Peak_Table_Save_Path,Phase10_Final_Peak_Table_Row_Count,Phase10_Final_Peak_Table_Column_Count,Phase10_Final_Peak_Plot_Source_Name,Phase10_Final_Peak_Plot_Save_Path,Phase10_Final_Output_Warning,Phase10_Final_Output_Error,Phase3_Peak_Direction_Source,Phase3_Peak_Direction_Final,Spiky_Show_Detected_Peak_Plot,Spiky_Show_Peak_Results_Table,Spiky_Show_Baseline,Spiky_Show_Threshold,Spiky_Synchro_Detection,Spiky_Derivative_Output,Spiky_Slope_Output,Spiky_Slope_Display,Spiky_Peak_Area_Output,Spiky_Decay_Fitting,Spiky_Summary_Output,Spiky_AutoDetect_Mode,Spiky_Tolerance_Percent,Spiky_Smoothing,Spiky_Threshold_Start_Percent,Spiky_Full_Width_Output,Spiky_Half_Width_Output,Spiky_Full_Width_Percent_1,Spiky_Full_Width_Percent_2,Phase3_Spiky_Status,Status,Warning,Error";
	if (outputFieldDelimiter != ",")
		runLogText = replace(runLogText, ",", outputFieldDelimiter);
	runLogText = runLogText + "\n";

	if (runMode == "Full Batch") {
		runLogText = runLogText + phase13SampleRunLogRows;
		File.saveString(runLogText, path);
		return;
	}

	runLogText = addRunLogRow(runLogText, timestamp, macroVersion, runMode, activeTableTitle, rowCount, columnCount, sampleCount, 0, 0, "", "", "", "", "", "", "Run_Started", phaseWarning, phaseError);

	for (i = 0; i < sampleCount; i++) {
		currentSampleIndex = i + 1;
		currentSourceColumnIndex = i + 2;
		rowPhase2SourceSample = "";
		rowPhase2PlotName = "";
		rowPhase3SpikyStatus = "";
		if (i == 0 && phase2PlotName != "") {
			rowPhase2SourceSample = phase2SourceSample;
			rowPhase2PlotName = phase2PlotName;
			rowPhase3SpikyStatus = phase3SpikyStatus;
		}
		runLogText = addRunLogRow(runLogText, timestamp, macroVersion, runMode, activeTableTitle, rowCount, columnCount, sampleCount, currentSampleIndex, currentSourceColumnIndex, sampleOriginalNames[i], sampleUniqueNames[i], sampleFileNames[i], rowPhase2SourceSample, rowPhase2PlotName, rowPhase3SpikyStatus, sampleStatuses[i], sampleWarnings[i], "");
	}

	runLogText = addRunLogRow(runLogText, timestamp, macroVersion, runMode, activeTableTitle, rowCount, columnCount, sampleCount, 0, 0, "", "", "", phase2SourceSample, phase2PlotName, phase3SpikyStatus, runCompletionStatus, phaseWarning, phaseError);
	File.saveString(runLogText, path);
}

function addRunLogRow(existingText, rowTimestamp, rowMacroVersion, rowRunMode, rowTableTitle, rowRowCount, rowColumnCount, rowSampleCount, rowSampleIndex, rowSourceColumnIndex, rowOriginalName, rowUniqueName, rowFileName, rowPhase2SourceSample, rowPhase2PlotName, rowPhase3SpikyStatus, rowStatus, rowWarning, rowError) {
	qTimestamp = quoteRunLogText(rowTimestamp);
	qMacroVersion = quoteRunLogText(rowMacroVersion);
	qRunMode = quoteRunLogText(rowRunMode);
	qChangeKeyword = quoteRunLogText(changeKeyword);
	qOutputTableFormat = quoteRunLogText(outputTableFormat);
	qOutputFieldDelimiter = quoteRunLogText(outputFieldDelimiterLabel);
	qOutputDecimalSeparator = quoteRunLogText(outputDecimalSeparator);
	qOutputTableExtension = quoteRunLogText(outputTableExtension);
	qOutputThousandsSeparators = quoteRunLogText(outputThousandsSeparators);
	qInputTableSelection = quoteRunLogText(inputTableSelectionStatus);
	qBaselineCurveMethod = quoteRunLogText(baselineCurveMethod);
	qPhase6PolynomialDegreeSelected = formatRunLogNumber(selectedPolynomialDegree);
	qTableTitle = quoteRunLogText(rowTableTitle);
	qRowCount = formatRunLogNumber(rowRowCount);
	qColumnCount = formatRunLogNumber(rowColumnCount);
	qSampleCount = formatRunLogNumber(rowSampleCount);
	qSampleIndex = formatRunLogNumber(rowSampleIndex);
	qSourceColumnIndex = formatRunLogNumber(rowSourceColumnIndex);
	qOriginalName = quoteRunLogText(rowOriginalName);
	qUniqueName = quoteRunLogText(rowUniqueName);
	qFileName = quoteRunLogText(rowFileName);
	qPhase2SourceSample = quoteRunLogText(rowPhase2SourceSample);
	qPhase2PlotName = quoteRunLogText(rowPhase2PlotName);
	qPhase3RawPlotName = quoteRunLogText(phase3RawPlotName);
	qPhase3SpikyCommand = quoteRunLogText(phase3SpikyCommand);
	qPhase3SpikyWasCalled = quoteRunLogText(phase3SpikyWasCalled);
	qPhase3ExistingResultsBackupName = quoteRunLogText(phase3ExistingResultsBackupName);
	qPhase3SpikyDetectedPeaksPlotName = quoteRunLogText(phase3SpikyDetectedPeaksPlotName);
	qPhase3SpikyPeakAnalysisTableName = quoteRunLogText(phase3SpikyPeakAnalysisTableName);
	qPhase3OpenWindowsAfterSpiky = quoteRunLogText(phase3OpenWindowsAfterSpiky);
	setQuotedExistingRunLogPath(phase3DetectedPeaksPlotSavePath);
	qPhase3DetectedPeaksPlotSavePath = quotedExistingRunLogPathResult;
	setQuotedExistingRunLogPath(phase3PeakAnalysisTableSavePath);
	qPhase3PeakAnalysisTableSavePath = quotedExistingRunLogPathResult;
	qPhase3OutputSaveStatus = quoteRunLogText(phase3OutputSaveStatus);
	qPhase4PlotValuesStatus = quoteRunLogText(phase4PlotValuesStatus);
	qPhase4PlotValuesTableName = quoteRunLogText(phase4PlotValuesTableName);
	setQuotedExistingRunLogPath(phase4PlotValuesSavePath);
	qPhase4PlotValuesSavePath = quotedExistingRunLogPathResult;
	qPhase4PlotValuesColumnCount = formatRunLogNumber(phase4PlotValuesColumnCount);
	qPhase4PlotValuesColumnHeadings = quoteRunLogText(phase4PlotValuesColumnHeadings);
	qPhase4PlotValuesOpenWindowsBefore = quoteRunLogText(phase4PlotValuesOpenWindowsBefore);
	qPhase4PlotValuesOpenWindowsAfter = quoteRunLogText(phase4PlotValuesOpenWindowsAfter);
	qPhase4ExistingResultsBackupName = quoteRunLogText(phase4ExistingResultsBackupName);
	qPhase4ExistingPlotValuesBackupName = quoteRunLogText(phase4ExistingPlotValuesBackupName);
	qPhase4PlotValuesWarning = quoteRunLogText(phase4PlotValuesWarning);
	qPhase4PlotValuesError = quoteRunLogText(phase4PlotValuesError);
	qPhase5ValidationStatus = quoteRunLogText(phase5ValidationStatus);
	qPhase5PlotValuesSourceTableName = quoteRunLogText(phase5PlotValuesSourceTableName);
	qPhase5PredictedXColumn = quoteRunLogText(phase5PredictedXColumn);
	qPhase5PredictedYColumn = quoteRunLogText(phase5PredictedYColumn);
	qPhase5PredictionReason = quoteRunLogText(phase5PredictionReason);
	qPhase5AnchorCount = formatRunLogNumber(phase5AnchorCount);
	setQuotedExistingRunLogPath(phase5BaselineAnchorsSavePath);
	qPhase5BaselineAnchorsSavePath = quotedExistingRunLogPathResult;
	qPhase5ValidationWindowMode = quoteRunLogText(phase5ValidationWindowMode);
	qPhase5LocalBaselineWindowPoints = formatRunLogNumber(phase5LocalBaselineWindowPoints);
	qPhase5PeakExclusionWindowPoints = formatRunLogNumber(phase5PeakExclusionWindowPoints);
	qPhase5MedianTimeStep = formatRunLogNumber(phase5MedianTimeStep);
	qPhase5LocalBaselineWindowTimeUnits = formatRunLogNumber(phase5LocalBaselineWindowTimeUnits);
	qPhase5PeakExclusionWindowTimeUnits = formatRunLogNumber(phase5PeakExclusionWindowTimeUnits);
	qPhase5LocalBaselineTolerancePercent = formatRunLogNumber(phase5LocalBaselineTolerancePercent);
	qPhase5PeakSeparationPercent = formatRunLogNumber(phase5PeakSeparationPercent);
	qPhase5RawXMin = formatRunLogNumber(phase5RawXMin);
	qPhase5RawXMax = formatRunLogNumber(phase5RawXMax);
	qPhase5RawYMin = formatRunLogNumber(phase5RawYMin);
	qPhase5RawYMax = formatRunLogNumber(phase5RawYMax);
	qPhase5RawYRange = formatRunLogNumber(phase5RawYRange);
	qPhase5AnchorYMin = formatRunLogNumber(phase5AnchorYMin);
	qPhase5AnchorYMax = formatRunLogNumber(phase5AnchorYMax);
	qPhase5PeakMarkerColumnX = quoteRunLogText(phase5PeakMarkerColumnX);
	qPhase5PeakMarkerColumnY = quoteRunLogText(phase5PeakMarkerColumnY);
	qPhase5CandidateDiagnostics = quoteRunLogText(phase5CandidateDiagnostics);
	qPhase5ValidationWarning = quoteRunLogText(phase5ValidationWarning);
	qPhase5ValidationError = quoteRunLogText(phase5ValidationError);
	qPhase6FitStatus = quoteRunLogText(phase6FitStatus);
	qPhase6BaselineModel = quoteRunLogText(baselineCurveMethod);
	qPhase6SupportedDegrees = quoteRunLogText(phase6SupportedDegrees);
	qPhase6PolynomialDegreeUsed = formatPhase6DiagnosticNumber(phase6PolynomialDegreeUsed);
	qPhase6FitFunction = quoteRunLogText(phase6FitFunction);
	qPhase6CoefficientOrder = quoteRunLogText(phase6CoefficientOrder);
	qPhase6CoefficientCount = formatPhase6DiagnosticNumber(phase6CoefficientCount);
	qPhase6CoefficientsText = quoteRunLogText(phase6CoefficientsText);
	qPhase6AnchorCount = formatPhase6DiagnosticNumber(phase6AnchorCount);
	qPhase6SourceAnchorArrayLength = formatPhase6DiagnosticNumber(phase6SourceAnchorArrayLength);
	qPhase6FitInputAnchorCount = formatPhase6DiagnosticNumber(phase6FitInputAnchorCount);
	qPhase6UnusedSourceAnchorEntries = formatPhase6DiagnosticNumber(phase6UnusedSourceAnchorEntries);
	qPhase6FitInputArrayStatus = quoteRunLogText(phase6FitInputArrayStatus);
	qPhase6FitInputFirstTime = formatPhase6DiagnosticNumber(phase6FitInputFirstTime);
	qPhase6FitInputLastTime = formatPhase6DiagnosticNumber(phase6FitInputLastTime);
	qPhase6FitInputFirstValue = formatPhase6DiagnosticNumber(phase6FitInputFirstValue);
	qPhase6FitInputLastValue = formatPhase6DiagnosticNumber(phase6FitInputLastValue);
	qPhase6AnchorResidualRMSE = formatPhase6DiagnosticNumber(phase6AnchorResidualRMSE);
	qPhase6AnchorResidualMaxAbs = formatPhase6DiagnosticNumber(phase6AnchorResidualMaxAbs);
	qPhase6AnchorResidualMaxPercentAbs = formatPhase6DiagnosticNumber(phase6AnchorResidualMaxPercentAbs);
	qPhase6AnchorResidualWarnPercent = formatPhase6DiagnosticNumber(phase6AnchorResidualWarnPercent);
	qPhase6AnchorResidualFailPercent = formatPhase6DiagnosticNumber(phase6AnchorResidualFailPercent);
	qPhase6RawTimeMin = formatPhase6DiagnosticNumber(phase6RawTimeMin);
	qPhase6RawTimeMax = formatPhase6DiagnosticNumber(phase6RawTimeMax);
	qPhase6AnchorTimeMin = formatPhase6DiagnosticNumber(phase6AnchorTimeMin);
	qPhase6AnchorTimeMax = formatPhase6DiagnosticNumber(phase6AnchorTimeMax);
	qPhase6RawRowsBeforeFirstAnchor = formatPhase6DiagnosticNumber(phase6RawRowsBeforeFirstAnchor);
	qPhase6RawRowsAfterLastAnchor = formatPhase6DiagnosticNumber(phase6RawRowsAfterLastAnchor);
	qPhase6RawPercentOutsideAnchorSupport = formatPhase6DiagnosticNumber(phase6RawPercentOutsideAnchorSupport);
	qPhase6FirstFittedBaseline = formatPhase6DiagnosticNumber(phase6FirstFittedBaseline);
	qPhase6LastFittedBaseline = formatPhase6DiagnosticNumber(phase6LastFittedBaseline);
	qPhase6FitReasonablenessStatus = quoteRunLogText(phase6FitReasonablenessStatus);
	qPhase6FitReasonablenessError = quoteRunLogText(phase6FitReasonablenessError);
	qPhase6FitReasonablenessWarning = quoteRunLogText(phase6FitReasonablenessWarning);
	qPhase6DiagnosticTableSaveStatus = quoteRunLogText(phase6DiagnosticTableSaveStatus);
	setQuotedExistingRunLogPath(phase6DiagnosticTableSavePath);
	qPhase6DiagnosticTableSavePath = quotedExistingRunLogPathResult;
	qPhase6BaselineValueCount = formatPhase6DiagnosticNumber(phase6BaselineValueCount);
	qPhase6FitRMSE = formatPhase6DiagnosticNumber(phase6FitRMSE);
	qPhase6FitRSquared = formatPhase6DiagnosticNumber(phase6FitRSquared);
	qPhase6FittedBaselineMin = formatPhase6DiagnosticNumber(phase6FittedBaselineMin);
	qPhase6FittedBaselineMean = formatPhase6DiagnosticNumber(phase6FittedBaselineMean);
	qPhase6FittedBaselineMax = formatPhase6DiagnosticNumber(phase6FittedBaselineMax);
	qPhase6FitWarning = quoteRunLogText(phase6FitWarning);
	qPhase6FitError = quoteRunLogText(phase6FitError);
	qPhase7CalculationStatus = quoteRunLogText(phase7CalculationStatus);
	qPhase7RawValueCount = formatPhase7DiagnosticNumber(phase7RawValueCount);
	qPhase7BaselineValueCount = formatPhase7DiagnosticNumber(phase7BaselineValueCount);
	qPhase7DeltaFValueCount = formatPhase7DiagnosticNumber(phase7DeltaFValueCount);
	qPhase7DeltaFOverF0ValueCount = formatPhase7DiagnosticNumber(phase7DeltaFOverF0ValueCount);
	qPhase7DeltaFOverF0PercentValueCount = formatPhase7DiagnosticNumber(phase7DeltaFOverF0PercentValueCount);
	qPhase7RawBaselineAlignmentStatus = quoteRunLogText(phase7RawBaselineAlignmentStatus);
	qPhase7MinDeltaF = formatPhase7DiagnosticNumber(phase7MinDeltaF);
	qPhase7MeanDeltaF = formatPhase7DiagnosticNumber(phase7MeanDeltaF);
	qPhase7MaxDeltaF = formatPhase7DiagnosticNumber(phase7MaxDeltaF);
	qPhase7MinDeltaFOverF0 = formatPhase7DiagnosticNumber(phase7MinDeltaFOverF0);
	qPhase7MeanDeltaFOverF0 = formatPhase7DiagnosticNumber(phase7MeanDeltaFOverF0);
	qPhase7MaxDeltaFOverF0 = formatPhase7DiagnosticNumber(phase7MaxDeltaFOverF0);
	qPhase7MinDeltaFOverF0Percent = formatPhase7DiagnosticNumber(phase7MinDeltaFOverF0Percent);
	qPhase7MeanDeltaFOverF0Percent = formatPhase7DiagnosticNumber(phase7MeanDeltaFOverF0Percent);
	qPhase7MaxDeltaFOverF0Percent = formatPhase7DiagnosticNumber(phase7MaxDeltaFOverF0Percent);
	qPhase7InvalidBaselineValueCount = formatPhase7DiagnosticNumber(phase7InvalidBaselineValueCount);
	qPhase7InvalidCorrectedValueCount = formatPhase7DiagnosticNumber(phase7InvalidCorrectedValueCount);
	qPhase7FirstInvalidRow = formatPhase7DiagnosticNumber(phase7FirstInvalidRow);
	qPhase7FirstInvalidReason = quoteRunLogText(phase7FirstInvalidReason);
	qPhase7MinimumSafeBaselineAbs = formatPhase7DiagnosticNumber(phase7MinimumSafeBaselineAbs);
	qPhase7Warning = quoteRunLogText(phase7Warning);
	qPhase7Error = quoteRunLogText(phase7Error);
	qPhase7CorrectedTraceTableSaveStatus = quoteRunLogText(phase7CorrectedTraceTableSaveStatus);
	setQuotedExistingRunLogPath(phase7CorrectedTraceTableSavePath);
	qPhase7CorrectedTraceTableSavePath = quotedExistingRunLogPathResult;
	qPhase8PlotStatus = quoteRunLogText(phase8PlotStatus);
	setQuotedExistingRunLogPath(phase8PlotSavePath);
	qPhase8PlotSavePath = quotedExistingRunLogPathResult;
	qPhase8PlotWarning = quoteRunLogText(phase8PlotWarning);
	qPhase8PlotError = quoteRunLogText(phase8PlotError);
	qPhase9SecondSpikyStatus = quoteRunLogText(phase9SecondSpikyStatus);
	qPhase9CorrectedInputPlotName = quoteRunLogText(phase9CorrectedInputPlotName);
	qPhase9CorrectedInputValueCount = formatPhase7DiagnosticNumber(phase9CorrectedInputValueCount);
	qPhase9CorrectedInputYMin = formatPhase7DiagnosticNumber(phase9CorrectedInputYMin);
	qPhase9CorrectedInputYMax = formatPhase7DiagnosticNumber(phase9CorrectedInputYMax);
	qPhase9CorrectedInputWarning = quoteRunLogText(phase9CorrectedInputWarning);
	qPhase9CorrectedInputError = quoteRunLogText(phase9CorrectedInputError);
	qPhase9SecondSpikyWasCalled = quoteRunLogText(phase9SecondSpikyWasCalled);
	qPhase9ExistingResultsBackupName = quoteRunLogText(phase9ExistingResultsBackupName);
	qPhase9SecondSpikyDetectedPeaksPlotName = quoteRunLogText(phase9SecondSpikyDetectedPeaksPlotName);
	qPhase9SecondSpikyPeakAnalysisTableName = quoteRunLogText(phase9SecondSpikyPeakAnalysisTableName);
	qPhase9OpenWindowsAfterSpiky = quoteRunLogText(phase9OpenWindowsAfterSpiky);
	qPhase9SecondSpikyWarning = quoteRunLogText(phase9SecondSpikyWarning);
	qPhase9SecondSpikyError = quoteRunLogText(phase9SecondSpikyError);
	qPhase10FinalOutputStatus = quoteRunLogText(phase10FinalOutputStatus);
	qPhase10FinalPeakTableSourceName = quoteRunLogText(phase10FinalPeakTableSourceName);
	setQuotedExistingRunLogPath(phase10FinalPeakTableSavePath);
	qPhase10FinalPeakTableSavePath = quotedExistingRunLogPathResult;
	qPhase10FinalPeakTableRowCount = formatRunLogNumber(phase10FinalPeakTableRowCount);
	qPhase10FinalPeakTableColumnCount = formatRunLogNumber(phase10FinalPeakTableColumnCount);
	qPhase10FinalPeakPlotSourceName = quoteRunLogText(phase10FinalPeakPlotSourceName);
	setQuotedExistingRunLogPath(phase10FinalPeakPlotSavePath);
	qPhase10FinalPeakPlotSavePath = quotedExistingRunLogPathResult;
	qPhase10FinalOutputWarning = quoteRunLogText(phase10FinalOutputWarning);
	qPhase10FinalOutputError = quoteRunLogText(phase10FinalOutputError);
	qPhase3PeakDirectionSource = quoteRunLogText(phase3PeakDirectionSource);
	qPhase3PeakDirectionFinal = quoteRunLogText(phase3PeakDirectionFinal);
	qPhase3PrefShowDetectedPeakPlot = quoteRunLogText(phase3PrefShowDetectedPeakPlot);
	qPhase3PrefShowPeakResultsTable = quoteRunLogText(phase3PrefShowPeakResultsTable);
	qPhase3PrefShowBaseline = quoteRunLogText(phase3PrefShowBaseline);
	qPhase3PrefShowThreshold = quoteRunLogText(phase3PrefShowThreshold);
	qPhase3PrefSynchroDetection = quoteRunLogText(phase3PrefSynchroDetection);
	qPhase3PrefDerivativeOutput = quoteRunLogText(phase3PrefDerivativeOutput);
	qPhase3PrefSlopeOutput = quoteRunLogText(phase3PrefSlopeOutput);
	qPhase3PrefSlopeDisplay = quoteRunLogText(phase3PrefSlopeDisplay);
	qPhase3PrefPeakAreaOutput = quoteRunLogText(phase3PrefPeakAreaOutput);
	qPhase3PrefDecayFitting = quoteRunLogText(phase3PrefDecayFitting);
	qPhase3PrefSummaryOutput = quoteRunLogText(phase3PrefSummaryOutput);
	qPhase3PrefAutoDetectMode = quoteRunLogText(phase3PrefAutoDetectMode);
	qPhase3PrefTolerancePercent = formatRunLogNumber(phase3PrefTolerancePercent);
	qPhase3PrefSmoothing = formatRunLogNumber(phase3PrefSmoothing);
	qPhase3PrefThresholdStartPercent = formatRunLogNumber(phase3PrefThresholdStartPercent);
	qPhase3PrefFullWidthOutput = quoteRunLogText(phase3PrefFullWidthOutput);
	qPhase3PrefHalfWidthOutput = quoteRunLogText(phase3PrefHalfWidthOutput);
	qPhase3PrefFullWidthPercent1 = formatRunLogNumber(phase3PrefFullWidthPercent1);
	qPhase3PrefFullWidthPercent2 = formatRunLogNumber(phase3PrefFullWidthPercent2);
	qPhase3SpikyStatus = quoteRunLogText(rowPhase3SpikyStatus);
	qStatus = quoteRunLogText(rowStatus);
	qWarning = quoteRunLogText(rowWarning);
	qError = quoteRunLogText(rowError);

	line = qTimestamp;
	line = line + outputFieldDelimiter + qMacroVersion;
	line = line + outputFieldDelimiter + qRunMode;
	line = line + outputFieldDelimiter + qChangeKeyword;
	line = line + outputFieldDelimiter + qOutputTableFormat;
	line = line + outputFieldDelimiter + qOutputFieldDelimiter;
	line = line + outputFieldDelimiter + qOutputDecimalSeparator;
	line = line + outputFieldDelimiter + qOutputTableExtension;
	line = line + outputFieldDelimiter + qOutputThousandsSeparators;
	line = line + outputFieldDelimiter + qInputTableSelection;
	line = line + outputFieldDelimiter + qBaselineCurveMethod;
	line = line + outputFieldDelimiter + qPhase6PolynomialDegreeSelected;
	line = line + outputFieldDelimiter + qTableTitle;
	line = line + outputFieldDelimiter + qRowCount;
	line = line + outputFieldDelimiter + qColumnCount;
	line = line + outputFieldDelimiter + qSampleCount;
	line = line + outputFieldDelimiter + qSampleIndex;
	line = line + outputFieldDelimiter + qSourceColumnIndex;
	line = line + outputFieldDelimiter + qOriginalName;
	line = line + outputFieldDelimiter + qUniqueName;
	line = line + outputFieldDelimiter + qFileName;
	line = line + outputFieldDelimiter + qPhase2SourceSample;
	line = line + outputFieldDelimiter + qPhase2PlotName;
	line = line + outputFieldDelimiter + qPhase3RawPlotName;
	line = line + outputFieldDelimiter + qPhase3SpikyCommand;
	line = line + outputFieldDelimiter + qPhase3SpikyWasCalled;
	line = line + outputFieldDelimiter + qPhase3ExistingResultsBackupName;
	line = line + outputFieldDelimiter + qPhase3SpikyDetectedPeaksPlotName;
	line = line + outputFieldDelimiter + qPhase3SpikyPeakAnalysisTableName;
	line = line + outputFieldDelimiter + qPhase3OpenWindowsAfterSpiky;
	line = line + outputFieldDelimiter + qPhase3DetectedPeaksPlotSavePath;
	line = line + outputFieldDelimiter + qPhase3PeakAnalysisTableSavePath;
	line = line + outputFieldDelimiter + qPhase3OutputSaveStatus;
	line = line + outputFieldDelimiter + qPhase4PlotValuesStatus;
	line = line + outputFieldDelimiter + qPhase4PlotValuesTableName;
	line = line + outputFieldDelimiter + qPhase4PlotValuesSavePath;
	line = line + outputFieldDelimiter + qPhase4PlotValuesColumnCount;
	line = line + outputFieldDelimiter + qPhase4PlotValuesColumnHeadings;
	line = line + outputFieldDelimiter + qPhase4PlotValuesOpenWindowsBefore;
	line = line + outputFieldDelimiter + qPhase4PlotValuesOpenWindowsAfter;
	line = line + outputFieldDelimiter + qPhase4ExistingResultsBackupName;
	line = line + outputFieldDelimiter + qPhase4ExistingPlotValuesBackupName;
	line = line + outputFieldDelimiter + qPhase4PlotValuesWarning;
	line = line + outputFieldDelimiter + qPhase4PlotValuesError;
	line = line + outputFieldDelimiter + qPhase5ValidationStatus;
	line = line + outputFieldDelimiter + qPhase5PlotValuesSourceTableName;
	line = line + outputFieldDelimiter + qPhase5PredictedXColumn;
	line = line + outputFieldDelimiter + qPhase5PredictedYColumn;
	line = line + outputFieldDelimiter + qPhase5PredictionReason;
	line = line + outputFieldDelimiter + qPhase5AnchorCount;
	line = line + outputFieldDelimiter + qPhase5BaselineAnchorsSavePath;
	line = line + outputFieldDelimiter + qPhase5ValidationWindowMode;
	line = line + outputFieldDelimiter + qPhase5LocalBaselineWindowPoints;
	line = line + outputFieldDelimiter + qPhase5PeakExclusionWindowPoints;
	line = line + outputFieldDelimiter + qPhase5MedianTimeStep;
	line = line + outputFieldDelimiter + qPhase5LocalBaselineWindowTimeUnits;
	line = line + outputFieldDelimiter + qPhase5PeakExclusionWindowTimeUnits;
	line = line + outputFieldDelimiter + qPhase5LocalBaselineTolerancePercent;
	line = line + outputFieldDelimiter + qPhase5PeakSeparationPercent;
	line = line + outputFieldDelimiter + qPhase5RawXMin;
	line = line + outputFieldDelimiter + qPhase5RawXMax;
	line = line + outputFieldDelimiter + qPhase5RawYMin;
	line = line + outputFieldDelimiter + qPhase5RawYMax;
	line = line + outputFieldDelimiter + qPhase5RawYRange;
	line = line + outputFieldDelimiter + qPhase5AnchorYMin;
	line = line + outputFieldDelimiter + qPhase5AnchorYMax;
	line = line + outputFieldDelimiter + qPhase5PeakMarkerColumnX;
	line = line + outputFieldDelimiter + qPhase5PeakMarkerColumnY;
	line = line + outputFieldDelimiter + qPhase5CandidateDiagnostics;
	line = line + outputFieldDelimiter + qPhase5ValidationWarning;
	line = line + outputFieldDelimiter + qPhase5ValidationError;
	line = line + outputFieldDelimiter + qPhase6FitStatus;
	line = line + outputFieldDelimiter + qPhase6BaselineModel;
	line = line + outputFieldDelimiter + qPhase6SupportedDegrees;
	line = line + outputFieldDelimiter + qPhase6PolynomialDegreeUsed;
	line = line + outputFieldDelimiter + qPhase6FitFunction;
	line = line + outputFieldDelimiter + qPhase6CoefficientOrder;
	line = line + outputFieldDelimiter + qPhase6CoefficientCount;
	line = line + outputFieldDelimiter + qPhase6CoefficientsText;
	line = line + outputFieldDelimiter + qPhase6AnchorCount;
	line = line + outputFieldDelimiter + qPhase6SourceAnchorArrayLength;
	line = line + outputFieldDelimiter + qPhase6FitInputAnchorCount;
	line = line + outputFieldDelimiter + qPhase6UnusedSourceAnchorEntries;
	line = line + outputFieldDelimiter + qPhase6FitInputArrayStatus;
	line = line + outputFieldDelimiter + qPhase6FitInputFirstTime;
	line = line + outputFieldDelimiter + qPhase6FitInputLastTime;
	line = line + outputFieldDelimiter + qPhase6FitInputFirstValue;
	line = line + outputFieldDelimiter + qPhase6FitInputLastValue;
	line = line + outputFieldDelimiter + qPhase6AnchorResidualRMSE;
	line = line + outputFieldDelimiter + qPhase6AnchorResidualMaxAbs;
	line = line + outputFieldDelimiter + qPhase6AnchorResidualMaxPercentAbs;
	line = line + outputFieldDelimiter + qPhase6AnchorResidualWarnPercent;
	line = line + outputFieldDelimiter + qPhase6AnchorResidualFailPercent;
	line = line + outputFieldDelimiter + qPhase6RawTimeMin;
	line = line + outputFieldDelimiter + qPhase6RawTimeMax;
	line = line + outputFieldDelimiter + qPhase6AnchorTimeMin;
	line = line + outputFieldDelimiter + qPhase6AnchorTimeMax;
	line = line + outputFieldDelimiter + qPhase6RawRowsBeforeFirstAnchor;
	line = line + outputFieldDelimiter + qPhase6RawRowsAfterLastAnchor;
	line = line + outputFieldDelimiter + qPhase6RawPercentOutsideAnchorSupport;
	line = line + outputFieldDelimiter + qPhase6FirstFittedBaseline;
	line = line + outputFieldDelimiter + qPhase6LastFittedBaseline;
	line = line + outputFieldDelimiter + qPhase6FitReasonablenessStatus;
	line = line + outputFieldDelimiter + qPhase6FitReasonablenessError;
	line = line + outputFieldDelimiter + qPhase6FitReasonablenessWarning;
	line = line + outputFieldDelimiter + qPhase6DiagnosticTableSaveStatus;
	line = line + outputFieldDelimiter + qPhase6DiagnosticTableSavePath;
	line = line + outputFieldDelimiter + qPhase6BaselineValueCount;
	line = line + outputFieldDelimiter + qPhase6FitRMSE;
	line = line + outputFieldDelimiter + qPhase6FitRSquared;
	line = line + outputFieldDelimiter + qPhase6FittedBaselineMin;
	line = line + outputFieldDelimiter + qPhase6FittedBaselineMean;
	line = line + outputFieldDelimiter + qPhase6FittedBaselineMax;
	line = line + outputFieldDelimiter + qPhase6FitWarning;
	line = line + outputFieldDelimiter + qPhase6FitError;
	line = line + outputFieldDelimiter + qPhase7CalculationStatus;
	line = line + outputFieldDelimiter + qPhase7RawValueCount;
	line = line + outputFieldDelimiter + qPhase7BaselineValueCount;
	line = line + outputFieldDelimiter + qPhase7DeltaFValueCount;
	line = line + outputFieldDelimiter + qPhase7DeltaFOverF0ValueCount;
	line = line + outputFieldDelimiter + qPhase7DeltaFOverF0PercentValueCount;
	line = line + outputFieldDelimiter + qPhase7RawBaselineAlignmentStatus;
	line = line + outputFieldDelimiter + qPhase7MinDeltaF;
	line = line + outputFieldDelimiter + qPhase7MeanDeltaF;
	line = line + outputFieldDelimiter + qPhase7MaxDeltaF;
	line = line + outputFieldDelimiter + qPhase7MinDeltaFOverF0;
	line = line + outputFieldDelimiter + qPhase7MeanDeltaFOverF0;
	line = line + outputFieldDelimiter + qPhase7MaxDeltaFOverF0;
	line = line + outputFieldDelimiter + qPhase7MinDeltaFOverF0Percent;
	line = line + outputFieldDelimiter + qPhase7MeanDeltaFOverF0Percent;
	line = line + outputFieldDelimiter + qPhase7MaxDeltaFOverF0Percent;
	line = line + outputFieldDelimiter + qPhase7InvalidBaselineValueCount;
	line = line + outputFieldDelimiter + qPhase7InvalidCorrectedValueCount;
	line = line + outputFieldDelimiter + qPhase7FirstInvalidRow;
	line = line + outputFieldDelimiter + qPhase7FirstInvalidReason;
	line = line + outputFieldDelimiter + qPhase7MinimumSafeBaselineAbs;
	line = line + outputFieldDelimiter + qPhase7Warning;
	line = line + outputFieldDelimiter + qPhase7Error;
	line = line + outputFieldDelimiter + qPhase7CorrectedTraceTableSaveStatus;
	line = line + outputFieldDelimiter + qPhase7CorrectedTraceTableSavePath;
	line = line + outputFieldDelimiter + qPhase8PlotStatus;
	line = line + outputFieldDelimiter + qPhase8PlotSavePath;
	line = line + outputFieldDelimiter + qPhase8PlotWarning;
	line = line + outputFieldDelimiter + qPhase8PlotError;
	line = line + outputFieldDelimiter + qPhase9SecondSpikyStatus;
	line = line + outputFieldDelimiter + qPhase9CorrectedInputPlotName;
	line = line + outputFieldDelimiter + qPhase9CorrectedInputValueCount;
	line = line + outputFieldDelimiter + qPhase9CorrectedInputYMin;
	line = line + outputFieldDelimiter + qPhase9CorrectedInputYMax;
	line = line + outputFieldDelimiter + qPhase9CorrectedInputWarning;
	line = line + outputFieldDelimiter + qPhase9CorrectedInputError;
	line = line + outputFieldDelimiter + qPhase9SecondSpikyWasCalled;
	line = line + outputFieldDelimiter + qPhase9ExistingResultsBackupName;
	line = line + outputFieldDelimiter + qPhase9SecondSpikyDetectedPeaksPlotName;
	line = line + outputFieldDelimiter + qPhase9SecondSpikyPeakAnalysisTableName;
	line = line + outputFieldDelimiter + qPhase9OpenWindowsAfterSpiky;
	line = line + outputFieldDelimiter + qPhase9SecondSpikyWarning;
	line = line + outputFieldDelimiter + qPhase9SecondSpikyError;
	line = line + outputFieldDelimiter + qPhase10FinalOutputStatus;
	line = line + outputFieldDelimiter + qPhase10FinalPeakTableSourceName;
	line = line + outputFieldDelimiter + qPhase10FinalPeakTableSavePath;
	line = line + outputFieldDelimiter + qPhase10FinalPeakTableRowCount;
	line = line + outputFieldDelimiter + qPhase10FinalPeakTableColumnCount;
	line = line + outputFieldDelimiter + qPhase10FinalPeakPlotSourceName;
	line = line + outputFieldDelimiter + qPhase10FinalPeakPlotSavePath;
	line = line + outputFieldDelimiter + qPhase10FinalOutputWarning;
	line = line + outputFieldDelimiter + qPhase10FinalOutputError;
	line = line + outputFieldDelimiter + qPhase3PeakDirectionSource;
	line = line + outputFieldDelimiter + qPhase3PeakDirectionFinal;
	line = line + outputFieldDelimiter + qPhase3PrefShowDetectedPeakPlot;
	line = line + outputFieldDelimiter + qPhase3PrefShowPeakResultsTable;
	line = line + outputFieldDelimiter + qPhase3PrefShowBaseline;
	line = line + outputFieldDelimiter + qPhase3PrefShowThreshold;
	line = line + outputFieldDelimiter + qPhase3PrefSynchroDetection;
	line = line + outputFieldDelimiter + qPhase3PrefDerivativeOutput;
	line = line + outputFieldDelimiter + qPhase3PrefSlopeOutput;
	line = line + outputFieldDelimiter + qPhase3PrefSlopeDisplay;
	line = line + outputFieldDelimiter + qPhase3PrefPeakAreaOutput;
	line = line + outputFieldDelimiter + qPhase3PrefDecayFitting;
	line = line + outputFieldDelimiter + qPhase3PrefSummaryOutput;
	line = line + outputFieldDelimiter + qPhase3PrefAutoDetectMode;
	line = line + outputFieldDelimiter + qPhase3PrefTolerancePercent;
	line = line + outputFieldDelimiter + qPhase3PrefSmoothing;
	line = line + outputFieldDelimiter + qPhase3PrefThresholdStartPercent;
	line = line + outputFieldDelimiter + qPhase3PrefFullWidthOutput;
	line = line + outputFieldDelimiter + qPhase3PrefHalfWidthOutput;
	line = line + outputFieldDelimiter + qPhase3PrefFullWidthPercent1;
	line = line + outputFieldDelimiter + qPhase3PrefFullWidthPercent2;
	line = line + outputFieldDelimiter + qPhase3SpikyStatus;
	line = line + outputFieldDelimiter + qStatus;
	line = line + outputFieldDelimiter + qWarning;
	line = line + outputFieldDelimiter + qError;
	line = line + "\n";

	updatedText = existingText + line;
	return updatedText;
}

function quoteRunLogText(value) {
	text = "" + value;
	if (text == "")
		return "";
	text = replace(text, "\"", "\"\"");
	quotedText = "\"" + text + "\"";
	return quotedText;
}

function setQuotedExistingRunLogPath(pathValue) {
	pathText = "" + pathValue;
	quotedExistingRunLogPathResult = "";
	if (pathText != "") {
		if (File.exists(pathText))
			quotedExistingRunLogPathResult = quoteRunLogText(pathText);
	}
}

function formatRunLogNumber(value) {
	text = "" + value;
	if (text == "")
		return "";

	text = d2s(value, 9);
	while (indexOf(text, ".") >= 0 && endsWith(text, "0"))
		text = substring(text, 0, lengthOf(text) - 1);
	if (endsWith(text, "."))
		text = substring(text, 0, lengthOf(text) - 1);
	if (outputDecimalSeparator == ",")
		text = replace(text, ".", ",");

	return text;
}

function createFirstSampleRawPlot(plotTimeColumnName, plotSampleColumnName, plotRowCount, rawPlotName) {
	phase2TimeValues = newArray(plotRowCount);
	phase2TraceValues = newArray(plotRowCount);

	if (!isOpen(activeTableTitle)) {
		phase2RawPlotCreateError = "Phase 2 clean plot creation failed. The raw input table was not open before reading sample data: " + activeTableTitle;
		if (runMode != "Full Batch")
			exit(phase2RawPlotCreateError);
		return;
	}
	selectWindow(activeTableTitle);
	phase2ActiveWindowType = getInfo("window.type");
	if (!startsWith(phase2ActiveWindowType, "ResultsTable")) {
		phase2RawPlotCreateError = "Phase 2 clean plot creation failed. The raw input table title was open but was not a readable ResultsTable: " + activeTableTitle + " type=" + phase2ActiveWindowType;
		if (runMode != "Full Batch")
			exit(phase2RawPlotCreateError);
		return;
	}

	for (plotRow = 0; plotRow < plotRowCount; plotRow++) {
		timeValue = Table.get(plotTimeColumnName, plotRow);
		traceValue = Table.get(plotSampleColumnName, plotRow);
		displayRowNumber = plotRow + 1;

		phase2TimeValueError = validateExtractedTraceValue(timeValue, plotTimeColumnName, displayRowNumber, "Time");
		if (phase2TimeValueError != "") {
			phase2RawPlotCreateError = phase2TimeValueError;
			return;
		}
		phase2TraceValueError = validateExtractedTraceValue(traceValue, plotSampleColumnName, displayRowNumber, "Sample trace");
		if (phase2TraceValueError != "") {
			phase2RawPlotCreateError = phase2TraceValueError;
			return;
		}

		phase2TimeValues[plotRow] = timeValue;
		phase2TraceValues[plotRow] = traceValue;
	}

	Plot.create(rawPlotName, phase2XAxisLabel, phase2YAxisLabel, phase2TimeValues, phase2TraceValues);
	Plot.show();
}

function validateExtractedTraceValue(value, columnName, rowNumber, valueRole) {
	valueIsInvalid = isNaN(value);
	if (valueIsInvalid) {
		phase2ValueError = "Phase 2 clean plot creation failed. Non-numeric or missing value detected. Value role: " + valueRole + "; column: " + columnName + "; row: " + rowNumber + ". No Spiky execution, baseline extraction, or peak analysis was performed for this sample.";
		if (runMode == "Full Batch")
			return phase2ValueError;
		exit("Phase 2 clean plot creation failed.\n\nNon-numeric or missing value detected.\n\nValue role: " + valueRole + "\nColumn: " + columnName + "\nRow: " + rowNumber + "\n\nNo Spiky execution, baseline extraction, or peak analysis was performed.");
	}
	return "";
}

function makeRawBaselineDetectionPlotName(safeSampleName) {
	plotName = safeSampleName + "_Raw_BaselineDetection_Input";
	return plotName;
}

function protectExistingResultsTable() {
	backupName = "";
	if (isOpen("Results")) {
		backupName = makeUniqueWindowName("PreExisting_Results_Before_Spiky_" + timestamp);
		selectWindow("Results");
		resultsWindowType = getInfo("window.type");
		if (startsWith(resultsWindowType, "ResultsTable"))
			IJ.renameResults(backupName);
		else
			rename(backupName);
	}
	return backupName;
}

function protectOpenTableWindow(windowTitle, backupBaseName) {
	backupName = "";
	if (isOpen(windowTitle)) {
		backupName = makeUniqueWindowName(backupBaseName);
		selectWindow(windowTitle);
		windowType = getInfo("window.type");
		if (startsWith(windowType, "ResultsTable")) {
			if (windowTitle == "Results")
				IJ.renameResults(backupName);
			else
				Table.rename(windowTitle, backupName);
		} else
			rename(backupName);
	}
	return backupName;
}

function makeUniqueWindowName(baseName) {
	candidate = baseName;
	suffix = 2;
	while (isOpen(candidate)) {
		candidate = baseName + "_" + suffix;
		suffix++;
	}
	return candidate;
}

function normalizeSpikyTolerancePercent(value, fallback) {
	if (isNaN(value) || value < 0)
		return fallback;
	return value;
}

function normalizeSpikySmoothing(value, fallback) {
	if (isNaN(value) || value < -1)
		return fallback;
	return value;
}

function setConservativeSpikyPreferences(tolerancePercent, smoothingPoints) {
	call("ij.Prefs.set", "SPIKY.PeakAna.SPWHDP", 1);
	call("ij.Prefs.set", "SPIKY.PeakAna.ShowSumTable", 1);
	call("ij.Prefs.set", "SPIKY.PeakAna.Dbaseline", 1);
	call("ij.Prefs.set", "SPIKY.PeakAna.Dthreshold", 1);
	call("ij.Prefs.set", "SPIKY.PeakAna.ASfS", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.DerivativeSig", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.DVmax", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.Vmax", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.AUP", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.decay", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.summarize", 0);
	call("ij.Prefs.set", "SPIKY.PeakAna.autoDetect", "Automatic");
	call("ij.Prefs.set", "SPIKY.PeakAna.tolerance", tolerancePercent);
	call("ij.Prefs.set", "SPIKY.PeakAna.smooth", smoothingPoints);
}

function makeSpikyPeakAnalysisCommand(orientation) {
	if (orientation == "Auto" || orientation == "Negative" || orientation == "Positive")
		return "runMacro(Spiky.ijm path, SPIKY.Batch.PeakAnalysisOrientation;SPIKY.Batch.SourceWindow)";
	return "";
}

function validateSpikyPeakOrientationSetting(orientation, commandName) {
	if (orientation != "Auto" && orientation != "Negative" && orientation != "Positive")
		return "Invalid Spiky peak orientation selected: " + orientation + ". Expected Auto, Negative, or Positive.";
	if (commandName == "")
		return "No Spiky peak-analysis command could be mapped for selected orientation: " + orientation + ".";
	if (commandName != "runMacro(Spiky.ijm path, SPIKY.Batch.PeakAnalysisOrientation;SPIKY.Batch.SourceWindow)")
		return "Mapped Spiky command is not the expected direct-file command: " + commandName + ".";
	return "";
}

function validateSpikyBatchOrientationSupport(path) {
	if (path == "" || path == "NaN")
		return "No modified Spiky.ijm path was provided. Select the Codex-modified Spiky.ijm file in the batch macro settings, then rerun.";
	if (!File.exists(path))
		return "Modified Spiky.ijm file was not found at the selected path: " + path;

	spikyText = File.openAsString(path);
	if (indexOf(spikyText, "SPIKY.Batch.DirectPeakAnalysisOrientationSupport=v0.1.14") < 0)
		return "Selected Spiky.ijm does not advertise direct batch orientation support v0.1.14. Expected marker: SPIKY.Batch.DirectPeakAnalysisOrientationSupport=v0.1.14. Selected path: " + path;
	if (indexOf(spikyText, "Spiky batch direct dispatcher reached") < 0)
		return "Selected Spiky.ijm is missing the early direct batch orientation argument dispatcher. Selected path: " + path;
	if (indexOf(spikyText, "SPIKY.Batch.SourceWindow") < 0)
		return "Selected Spiky.ijm is missing direct source-window selection support. Selected path: " + path;
	if (indexOf(spikyText, "Spiky batch direct source plot Y axis accepted") < 0)
		return "Selected Spiky.ijm is missing direct source-plot Y-axis label acceptance support. Selected path: " + path;
	if (indexOf(spikyText, "launchAnalysis(1)") < 0 || indexOf(spikyText, "launchAnalysis(0)") < 0 || indexOf(spikyText, "launchAnalysis(-1)") < 0)
		return "Selected Spiky.ijm does not contain the required direct launchAnalysis mappings for Positive, Negative, and Auto. Selected path: " + path;
	return "";
}

function runSpikyBatchPeakAnalysis(path, orientation, sourceWindowName) {
	if (orientation != "Auto" && orientation != "Negative" && orientation != "Positive")
		exit("Invalid Spiky peak orientation selected for direct execution: " + orientation);
	if (sourceWindowName == "" || sourceWindowName == "NaN")
		exit("Missing source window name for direct Spiky execution.");
	if (!isOpen(sourceWindowName))
		exit("Source window was not open before direct Spiky execution: " + sourceWindowName);
	selectWindow(sourceWindowName);
	if (!startsWith(getInfo("window.type"), "Plot"))
		exit("Source window was not a Plot before direct Spiky execution: " + sourceWindowName + " type=" + getInfo("window.type"));
	runMacro(path, "SPIKY.Batch.PeakAnalysisOrientation=" + orientation + ";SPIKY.Batch.SourceWindow=" + sourceWindowName);
}

function phase3FallbackToleranceAlreadyTried(triedText, toleranceValue) {
	toleranceText = formatPhase6DiagnosticNumber(toleranceValue);
	if (triedText == "")
		return false;
	triedParts = split(triedText, "; ");
	for (phase3TriedIndex = 0; phase3TriedIndex < lengthOf(triedParts); phase3TriedIndex++) {
		if (triedParts[phase3TriedIndex] == toleranceText)
			return true;
	}
	return false;
}

function closePhase3FallbackAttemptWindows() {
	closePhase3FallbackWindowIfOpen(phase3SpikyDetectedPeaksPlotName);
	closePhase3FallbackWindowIfOpen(phase3SpikyPeakAnalysisTableName);
}

function closePhase3FallbackWindowIfOpen(windowName) {
	if (windowName == "")
		return;
	if (!isOpen(windowName))
		return;
	selectWindow(windowName);
	run("Close");
	wait(100);
	if (isOpen(windowName)) {
		selectWindow(windowName);
		close();
		wait(100);
	}
}

function buildPhase3FirstSpikyFallbackSummary() {
	if (phase3FirstSpikyFallbackUsed != "Yes" && phase3FirstSpikyFallbackFailedAttempts == "")
		return "";
	summaryText = "First Spiky fallback ladder status: selected tolerance=" + phase3FirstSpikyFallbackInitialTolerance;
	summaryText = summaryText + "; final tolerance used=" + phase3FirstSpikyFallbackFinalTolerance;
	summaryText = summaryText + "; fallback used=" + phase3FirstSpikyFallbackUsed;
	summaryText = summaryText + "; failed attempts=" + phase3FirstSpikyFallbackFailedAttempts;
	summaryText = summaryText + "; reason=" + phase3FirstSpikyFallbackReason;
	summaryText = summaryText + "; passed only after fallback=" + phase3FirstSpikyFallbackPassedAfterFallback;
	return summaryText;
}

function makeDefaultSpikyMacroPath() {
	macroFilePath = getInfo("macro.filepath");
	if (macroFilePath != "" && macroFilePath != "NaN") {
		macroDirectory = File.getDirectory(macroFilePath);
		candidatePath = macroDirectory + "Spiky.ijm";
		if (File.exists(candidatePath))
			return candidatePath;
		return candidatePath;
	}
	return getDirectory("imagej") + "macros" + File.separator + "Spiky.ijm";
}

function cleanDialogPath(path) {
	cleanPath = trimString(path);
	if (startsWith(cleanPath, "\"") && endsWith(cleanPath, "\""))
		cleanPath = substring(cleanPath, 1, lengthOf(cleanPath) - 1);
	return cleanPath;
}

function getValidationArgumentValue(argumentText, keyName) {
	cleanKey = trimString(keyName);
	parts = split(argumentText, ";");
	for (argumentIndex = 0; argumentIndex < lengthOf(parts); argumentIndex++) {
		part = trimString(parts[argumentIndex]);
		equalsIndex = indexOf(part, "=");
		if (equalsIndex > 0) {
			partKey = trimString(substring(part, 0, equalsIndex));
			if (partKey == cleanKey) {
				partValue = trimString(substring(part, equalsIndex + 1, lengthOf(part)));
				if (lengthOf(partValue) >= 2 && startsWith(partValue, "\"") && endsWith(partValue, "\""))
					partValue = substring(partValue, 1, lengthOf(partValue) - 1);
				return partValue;
			}
		}
	}
	return "";
}

function parseRequiredValidationNumber(argumentText, keyName) {
	rawValue = getValidationArgumentValue(argumentText, keyName);
	if (rawValue == "")
		exit("Non-interactive validation mode requires " + keyName + "=<number>.");
	numberValue = phase16ParseNumber(rawValue);
	if (isNaN(numberValue))
		exit("Non-interactive validation argument was not numeric: " + keyName + "=" + rawValue);
	return numberValue;
}

function parseOptionalValidationNumber(argumentText, keyName, fallbackValue) {
	rawValue = getValidationArgumentValue(argumentText, keyName);
	if (rawValue == "")
		return fallbackValue;
	numberValue = phase16ParseNumber(rawValue);
	if (isNaN(numberValue))
		exit("Non-interactive validation argument was not numeric: " + keyName + "=" + rawValue);
	return numberValue;
}

function makeValidationArgumentSummary() {
	text = "inputCsv=" + validationInputCsvPath;
	text = text + "; outputDir=" + validationOutputDir;
	text = text + "; runMode=" + runMode;
	text = text + "; firstTol=" + firstSpikyTolerancePercent;
	text = text + "; firstSmooth=" + firstSpikySmoothing;
	text = text + "; secondTol=" + secondSpikyTolerancePercent;
	text = text + "; secondSmooth=" + secondSpikySmoothing;
	text = text + "; maxSamples=" + fullBatchMaxSamplesToProcess;
	text = text + "; batchMacro=" + batchMacroSourcePath;
	text = text + "; batchMacroSha256=" + batchMacroExpectedSha256;
	text = text + "; returnToMainMenu=" + returnToMainMenuAfterRun;
	return text;
}

function writeNonInteractiveProgress(eventText) {
	if (validationModeUsed != "Yes")
		return;
	if (nonInteractiveProgressLogPath == "")
		return;

	progressSampleIndex = "";
	progressSampleName = "";
	if (runMode == "Full Batch") {
		progressSampleIndex = "" + (phase13CurrentSampleIndex + 1);
		if (phase2SourceSample != "")
			progressSampleName = phase2SourceSample;
		else if (firstSampleSafeName != "")
			progressSampleName = firstSampleSafeName;
	}
	progressActiveWindow = getInfo("window.title");
	progressOpenWindowTitles = getList("window.titles");
	progressOpenWindowCount = lengthOf(progressOpenWindowTitles);
	if (progressOpenWindowCount > maxObservedOpenWindowCount)
		maxObservedOpenWindowCount = progressOpenWindowCount;
	progressOpenWindows = getOpenWindowTitlesText();
	progressElapsedMs = floor(getTime() - runStartTimeMs);
	progressLine = "" + progressElapsedMs + "\t" + sanitizeProgressLogField(eventText) + "\t" + sanitizeProgressLogField(progressSampleIndex) + "\t" + sanitizeProgressLogField(progressSampleName) + "\t" + sanitizeProgressLogField(progressActiveWindow) + "\t" + progressOpenWindowCount + "\t" + sanitizeProgressLogField(progressOpenWindows) + "\n";
	File.append(progressLine, nonInteractiveProgressLogPath);
}

function sanitizeProgressLogField(value) {
	text = "" + value;
	text = replace(text, "\t", " ");
	text = replace(text, "\n", " ");
	text = replace(text, "\r", " ");
	return text;
}

function getOpenWindowTitlesText() {
	openTitles = getList("window.titles");
	titleText = "";
	for (windowListIndex = 0; windowListIndex < lengthOf(openTitles); windowListIndex++) {
		if (titleText == "")
			titleText = openTitles[windowListIndex];
		else
			titleText = titleText + " | " + openTitles[windowListIndex];
	}
	return titleText;
}

function findReadablePlotValuesTable(beforeWindowText) {
	if (isReadableTableWindow("Plot Values"))
		return "Plot Values";
	if (isReadableTableWindow("Results"))
		return "Results";

	afterTitles = getList("window.titles");
	for (phase4WindowIndex = 0; phase4WindowIndex < lengthOf(afterTitles); phase4WindowIndex++) {
		candidateTitle = afterTitles[phase4WindowIndex];
		if (indexOf(beforeWindowText, candidateTitle) < 0) {
			if (isReadableTableWindow(candidateTitle))
				return candidateTitle;
		}
	}

	return "";
}

function isReadableTableWindow(tableWindowTitle) {
	if (!isOpen(tableWindowTitle))
		return false;
	selectWindow(tableWindowTitle);
	tableWindowType = getInfo("window.type");
	if (!startsWith(tableWindowType, "ResultsTable"))
		return false;
	tableHeadings = Table.headings;
	tableRows = Table.size;
	if (tableHeadings == "")
		return false;
	if (tableRows <= 0)
		return false;
	tableColumnCount = countDelimitedFields(tableHeadings, "\t");
	if (tableColumnCount < 2)
		return false;
	return true;
}

function countDelimitedFields(text, delimiter) {
	if (text == "")
		return 0;
	parts = split(text, delimiter);
	return lengthOf(parts);
}

function predictBaselineSeriesIndex(showThreshold, slopeOutput, slopeDisplay, showBaseline) {
	// Derive the baseline-marker series from enabled Spiky display outputs.
	// Do not treat a specific X/Y pair as universal; validate the prediction.
	if (!prefIsEnabled(showBaseline))
		return -1;

	nextSeriesIndex = 1;
	nextSeriesIndex++;

	if (prefIsEnabled(showThreshold))
		nextSeriesIndex++;

	if (prefIsEnabled(slopeOutput) && prefIsEnabled(slopeDisplay))
		nextSeriesIndex = nextSeriesIndex + 2;

	return nextSeriesIndex;
}

function prefIsEnabled(value) {
	text = "" + value;
	if (text == "1" || text == "true" || text == "True")
		return true;
	return false;
}

function resolvePlotValuesSourceTable(preferredTitle, savedPath) {
	if (isReadableTableWindow(preferredTitle))
		return preferredTitle;

	savedTitle = getPathLeaf(savedPath);
	if (isReadableTableWindow(savedTitle))
		return savedTitle;

	if (File.exists(savedPath)) {
		open(savedPath);
		wait(200);
		activeTitle = getInfo("window.title");
		if (isReadableTableWindow(activeTitle))
			return activeTitle;
		if (isReadableTableWindow(savedTitle))
			return savedTitle;
	}

	return "";
}

function resolveLivePlotValuesSourceTable(preferredTitle) {
	if (isReadableTableWindow(preferredTitle))
		return preferredTitle;
	return "";
}

function getPathLeaf(path) {
	leaf = path;
	lastSlash = lastIndexOf(leaf, "/");
	lastBackslash = lastIndexOf(leaf, "\\");
	cutIndex = lastSlash;
	if (lastBackslash > cutIndex)
		cutIndex = lastBackslash;
	if (cutIndex >= 0)
		leaf = substring(leaf, cutIndex + 1, lengthOf(leaf));
	return leaf;
}

function columnExistsInHeadings(headingsTextToSearch, columnName) {
	searchHeadings = split(headingsTextToSearch, "\t");
	for (headingIndex = 0; headingIndex < lengthOf(searchHeadings); headingIndex++) {
		trimmedHeading = trimString(searchHeadings[headingIndex]);
		if (trimmedHeading == columnName)
			return true;
	}
	return false;
}

function buildXYPairDiagnostics(headingsTextToSearch) {
	searchHeadings = split(headingsTextToSearch, "\t");
	diagnosticText = "";
	for (headingIndex = 0; headingIndex < lengthOf(searchHeadings); headingIndex++) {
		trimmedHeading = trimString(searchHeadings[headingIndex]);
		if (startsWith(trimmedHeading, "X")) {
			suffix = substring(trimmedHeading, 1, lengthOf(trimmedHeading));
			expectedY = "Y" + suffix;
			if (columnExistsInHeadings(headingsTextToSearch, expectedY)) {
				pairText = trimmedHeading + "/" + expectedY;
				if (diagnosticText == "")
					diagnosticText = pairText;
				else
					diagnosticText = diagnosticText + " | " + pairText;
			}
		}
	}
	return diagnosticText;
}

function validateBaselineAnchors(anchorTimes, anchorValues, anchorCount, rawTimes, rawValues, rawCount, peakTimes, peakValues, peakCount, rawXMin, rawXMax, rawYMin, rawYMax, rawYRange, localWindowPoints, peakWindowPoints, localTolerancePercent, peakSeparationPercent) {
	localToleranceValue = rawYRange * localTolerancePercent / 100;
	peakSeparationValue = rawYRange * peakSeparationPercent / 100;
	anchorRangeTolerance = phase5MedianTimeStep * 0.5;
	if (isNaN(anchorRangeTolerance) || anchorRangeTolerance < 0.000000001)
		anchorRangeTolerance = 0.000000001;
	validAnchorCount = 0;

	for (anchorIndex = 0; anchorIndex < anchorCount; anchorIndex++) {
		anchorTime = anchorTimes[anchorIndex];
		anchorValue = anchorValues[anchorIndex];

		if (anchorTime < rawXMin) {
			if (anchorTime >= rawXMin - anchorRangeTolerance) {
				phase5ValidationWarning = appendWarning(phase5ValidationWarning, "Anchor " + (anchorIndex + 1) + " time was within tolerance below raw trace minimum and was snapped from " + anchorTime + " to " + rawXMin + ".");
				anchorTime = rawXMin;
			} else {
				phase5ValidationWarning = appendWarning(phase5ValidationWarning, "Anchor " + (anchorIndex + 1) + " time was outside raw trace range beyond tolerance and was skipped: " + anchorTime + ".");
				continue;
			}
		}
		if (anchorTime > rawXMax) {
			if (anchorTime <= rawXMax + anchorRangeTolerance) {
				phase5ValidationWarning = appendWarning(phase5ValidationWarning, "Anchor " + (anchorIndex + 1) + " time was within tolerance above raw trace maximum and was snapped from " + anchorTime + " to " + rawXMax + ".");
				anchorTime = rawXMax;
			} else {
				phase5ValidationWarning = appendWarning(phase5ValidationWarning, "Anchor " + (anchorIndex + 1) + " time was outside raw trace range beyond tolerance and was skipped: " + anchorTime + ".");
				continue;
			}
		}
		if (anchorValue < rawYMin || anchorValue > rawYMax)
			return "Anchor value outside raw fluorescence range at anchor " + (anchorIndex + 1) + ".";

		rawIndex = findNearestRawIndex(rawTimes, rawCount, anchorTime);
		localStart = rawIndex - localWindowPoints;
		if (localStart < 0)
			localStart = 0;
		localEnd = rawIndex + localWindowPoints;
		if (localEnd >= rawCount)
			localEnd = rawCount - 1;

		localMin = rawValues[localStart];
		for (localIndex = localStart; localIndex <= localEnd; localIndex++) {
			if (rawValues[localIndex] < localMin)
				localMin = rawValues[localIndex];
		}

		if (anchorValue > localMin + localToleranceValue)
			return "Anchor " + (anchorIndex + 1) + " was not close enough to the local baseline/minimum region.";

		for (peakIndex = 0; peakIndex < peakCount; peakIndex++) {
			peakRawIndex = findNearestRawIndex(rawTimes, rawCount, peakTimes[peakIndex]);
			if (abs(rawIndex - peakRawIndex) <= peakWindowPoints) {
				if (anchorValue > peakValues[peakIndex] - peakSeparationValue)
					return "Anchor " + (anchorIndex + 1) + " resembled or overlapped a nearby peak maximum.";
			}
		}

		anchorTimes[validAnchorCount] = anchorTime;
		anchorValues[validAnchorCount] = anchorValue;
		validAnchorCount++;
	}

	phase5AnchorCount = validAnchorCount;
	if (validAnchorCount < 2)
		return "Validated baseline dataset contained fewer than 2 anchors after raw trace range tolerance filtering; constant degree 0 baseline is not supported safely by the current Phase 6 fit path.";
	return "";
}

function buildPhase6PeakAwareAnchorTimingWarning(anchorTimes, anchorCount, rawTimes, rawCount, peakTimes, peakCount) {
	if (anchorCount <= 0 || rawCount <= 1 || peakCount <= 0)
		return "";

	peakAwareRawMin = rawTimes[0];
	peakAwareRawMax = rawTimes[0];
	for (peakAwareRawIndex = 1; peakAwareRawIndex < rawCount; peakAwareRawIndex++) {
		peakAwareRawTime = rawTimes[peakAwareRawIndex];
		if (peakAwareRawTime < peakAwareRawMin)
			peakAwareRawMin = peakAwareRawTime;
		if (peakAwareRawTime > peakAwareRawMax)
			peakAwareRawMax = peakAwareRawTime;
	}
	peakAwareRawDuration = peakAwareRawMax - peakAwareRawMin;
	if (!isPhase6FiniteNumber(peakAwareRawDuration) || peakAwareRawDuration <= 0)
		return "";

	peakAwareWarning = "";
	peakAwareShortTimeThreshold = 0.25;
	if (isPhase6FiniteNumber(phase5MedianTimeStep)) {
		peakAwareTimeStepThreshold = phase5MedianTimeStep * 25;
		if (peakAwareTimeStepThreshold > peakAwareShortTimeThreshold)
			peakAwareShortTimeThreshold = peakAwareTimeStepThreshold;
	}
	if (peakAwareShortTimeThreshold > 0.30)
		peakAwareShortTimeThreshold = 0.30;
	peakAwareLatePositionThreshold = 85;
	peakAwareLargeGapFraction = 0.50;
	peakAwareAfterLastPeakFraction = 0.25;

	for (peakAwareAnchorIndex = 0; peakAwareAnchorIndex < anchorCount; peakAwareAnchorIndex++) {
		peakAwareAnchorTime = anchorTimes[peakAwareAnchorIndex];
		if (!isPhase6FiniteNumber(peakAwareAnchorTime))
			continue;

		peakAwarePreviousPeakTime = "";
		peakAwareNextPeakTime = "";
		for (peakAwarePeakIndex = 0; peakAwarePeakIndex < peakCount; peakAwarePeakIndex++) {
			peakAwarePeakTime = peakTimes[peakAwarePeakIndex];
			if (!isPhase6FiniteNumber(peakAwarePeakTime))
				continue;
			if (peakAwarePeakTime < peakAwareAnchorTime) {
				if (peakAwarePreviousPeakTime == "" || peakAwarePeakTime > peakAwarePreviousPeakTime)
					peakAwarePreviousPeakTime = peakAwarePeakTime;
			}
			if (peakAwarePeakTime > peakAwareAnchorTime) {
				if (peakAwareNextPeakTime == "" || peakAwarePeakTime < peakAwareNextPeakTime)
					peakAwareNextPeakTime = peakAwarePeakTime;
			}
		}

		peakAwareDistanceFromPreviousPeak = "";
		peakAwareDistanceToNextPeak = "";
		peakAwareInterval = "";
		peakAwareIntervalPositionPercent = "";
		peakAwareFlags = "";
		if (peakAwarePreviousPeakTime != "")
			peakAwareDistanceFromPreviousPeak = peakAwareAnchorTime - peakAwarePreviousPeakTime;
		if (peakAwareNextPeakTime != "")
			peakAwareDistanceToNextPeak = peakAwareNextPeakTime - peakAwareAnchorTime;
		if (peakAwarePreviousPeakTime != "" && peakAwareNextPeakTime != "") {
			peakAwareInterval = peakAwareNextPeakTime - peakAwarePreviousPeakTime;
			if (peakAwareInterval > 0)
				peakAwareIntervalPositionPercent = 100 * peakAwareDistanceFromPreviousPeak / peakAwareInterval;
		}

		peakAwarePreviousAnchorGap = "";
		peakAwareNextAnchorGap = "";
		peakAwareMaxAdjacentAnchorGap = 0;
		if (peakAwareAnchorIndex > 0) {
			peakAwarePreviousAnchorGap = peakAwareAnchorTime - anchorTimes[peakAwareAnchorIndex - 1];
			if (peakAwarePreviousAnchorGap > peakAwareMaxAdjacentAnchorGap)
				peakAwareMaxAdjacentAnchorGap = peakAwarePreviousAnchorGap;
		}
		if (peakAwareAnchorIndex < anchorCount - 1) {
			peakAwareNextAnchorGap = anchorTimes[peakAwareAnchorIndex + 1] - peakAwareAnchorTime;
			if (peakAwareNextAnchorGap > peakAwareMaxAdjacentAnchorGap)
				peakAwareMaxAdjacentAnchorGap = peakAwareNextAnchorGap;
		}
		peakAwareHasLargeAdjacentAnchorGap = false;
		if (peakAwareMaxAdjacentAnchorGap > peakAwareRawDuration * peakAwareLargeGapFraction)
			peakAwareHasLargeAdjacentAnchorGap = true;
		peakAwareHasLargePeakInterval = false;
		if (peakAwareInterval != "" && peakAwareInterval > peakAwareRawDuration * peakAwareLargeGapFraction)
			peakAwareHasLargePeakInterval = true;

		if (peakAwareHasLargeAdjacentAnchorGap)
			peakAwareFlags = appendPeakAwareFlag(peakAwareFlags, "Large_Internal_Anchor_Gap");
		if (peakAwareNextPeakTime == "" && peakAwarePreviousPeakTime != "") {
			if (peakAwareDistanceFromPreviousPeak > peakAwareRawDuration * peakAwareAfterLastPeakFraction)
				peakAwareFlags = appendPeakAwareFlag(peakAwareFlags, "Anchor_After_Last_Peak_With_Long_Gap");
		}
		if (peakAwareNextPeakTime != "" && peakAwareIntervalPositionPercent != "") {
			if (peakAwareDistanceToNextPeak <= peakAwareShortTimeThreshold && (peakAwareHasLargeAdjacentAnchorGap || peakAwareHasLargePeakInterval))
				peakAwareFlags = appendPeakAwareFlag(peakAwareFlags, "Anchor_Too_Close_To_Next_Peak");
			if (peakAwareIntervalPositionPercent >= peakAwareLatePositionThreshold && (peakAwareHasLargeAdjacentAnchorGap || peakAwareHasLargePeakInterval))
				peakAwareFlags = appendPeakAwareFlag(peakAwareFlags, "Anchor_Late_In_Peak_Interval");
		}

		if (peakAwareFlags != "") {
			peakAwareDetail = "Peak_Aware_Anchor_Timing_Warning: anchor=" + (peakAwareAnchorIndex + 1) + "; flags=" + peakAwareFlags + "; anchor_time=" + formatPhase6DiagnosticNumber(peakAwareAnchorTime) + "; previous_peak_time=" + formatPhase6DiagnosticNumber(peakAwarePreviousPeakTime) + "; next_peak_time=" + formatPhase6DiagnosticNumber(peakAwareNextPeakTime) + "; distance_from_previous_peak=" + formatPhase6DiagnosticNumber(peakAwareDistanceFromPreviousPeak) + "; distance_to_next_peak=" + formatPhase6DiagnosticNumber(peakAwareDistanceToNextPeak) + "; interval_position_percent=" + formatPhase6DiagnosticNumber(peakAwareIntervalPositionPercent) + "; max_adjacent_anchor_gap=" + formatPhase6DiagnosticNumber(peakAwareMaxAdjacentAnchorGap) + ".";
			peakAwareWarning = appendWarning(peakAwareWarning, peakAwareDetail);
		}
	}

	return peakAwareWarning;
}

function appendPeakAwareFlag(existingFlags, newFlag) {
	if (existingFlags == "")
		return newFlag;
	return existingFlags + "|" + newFlag;
}

function choosePhase6PolynomialDegreeForAnchorCount(anchorCount, requestedDegree) {
	actualDegree = requestedDegree;
	if (actualDegree > 4)
		actualDegree = 4;
	if (anchorCount >= 5)
		return actualDegree;
	if (anchorCount == 4) {
		if (actualDegree > 2)
			actualDegree = 2;
		return actualDegree;
	}
	if (anchorCount == 3 || anchorCount == 2)
		return 1;
	return 0;
}

function runPhase6PolynomialBaselineFit(anchorTimes, anchorValues, anchorCount, rawTimes, rawValues, rawCount, polynomialDegree) {
	phase6AnchorCount = anchorCount;
	phase6PolynomialDegreeUsed = "";
	phase6FitFunction = "";
	phase6FitRMSE = "";
	phase6FitRSquared = "";
	phase6FittedBaselineMin = "";
	phase6FittedBaselineMean = "";
	phase6FittedBaselineMax = "";
	phase6BaselineValueCount = "";
	phase6CoefficientCount = "";
	phase6CoefficientsText = "";
	phase6BaselineValues = newArray(0);
	phase6SourceAnchorArrayLength = lengthOf(anchorTimes);
	phase6FitInputAnchorCount = 0;
	phase6UnusedSourceAnchorEntries = phase6SourceAnchorArrayLength - anchorCount;
	phase6FitInputArrayStatus = "Not_Validated";
	phase6FitInputFirstTime = "";
	phase6FitInputLastTime = "";
	phase6FitInputFirstValue = "";
	phase6FitInputLastValue = "";
	phase6FitAnchorTimes = newArray(0);
	phase6FitAnchorValues = newArray(0);
	phase6AnchorFittedValues = newArray(0);
	phase6AnchorResidualValues = newArray(0);
	phase6AnchorPercentResidualValues = newArray(0);
	phase6AnchorDiagnosticCount = 0;
	phase6AnchorResidualRMSE = "";
	phase6AnchorResidualMaxAbs = "";
	phase6AnchorResidualMaxPercentAbs = "";
	phase6RawTimeMin = "";
	phase6RawTimeMax = "";
	phase6AnchorTimeMin = "";
	phase6AnchorTimeMax = "";
	phase6RawRowsBeforeFirstAnchor = "";
	phase6RawRowsAfterLastAnchor = "";
	phase6RawPercentOutsideAnchorSupport = "";
	phase6FirstFittedBaseline = "";
	phase6LastFittedBaseline = "";
	phase6FitReasonablenessStatus = "Not_Evaluated";
	phase6FitReasonablenessError = "";
	phase6FitReasonablenessWarning = "";
	phase6AnchorTimeCoveragePercent = "";
	phase6AnchorSpreadStatus = "";
	phase6PolynomialDegreeFirstAttempted = "";
	phase6PolynomialFallbackUsed = "No";
	phase6PolynomialFallbackReason = "";
	phase6BaselineRangeWarning = "";
	phase6BaselineEndpointWarning = "";
	phase6BaselineNegativeCorrectionWarning = "";
	phase6BaselineCurvatureWarning = "";
	phase6PeakAwareAnchorTimingWarning = "";
	phase6BaselineReliabilityClass = "Baseline_OK";
	phase6BaselineReliabilityReason = "";
	phase6FitWarning = "";

	if (baselineCurveMethod != "Polynomial")
		return "Phase 6 baseline fitting requires Baseline curve method = Polynomial.";
	if (anchorCount <= 0)
		return "Phase 6 could not fit baseline because Phase 5 validated zero usable baseline anchors.";
	if (anchorCount == 1)
		return "Phase 6 could not fit baseline because Phase 5 validated one usable anchor and degree 0 constant baseline is not supported safely by the current fit path.";
	if (polynomialDegree < 1 || polynomialDegree > 4)
		return "Unsupported requested Phase 6 polynomial degree: " + polynomialDegree + ". Supported requested degrees are 1, 2, 3, and 4.";
	phase6PolynomialDegreeUsed = choosePhase6PolynomialDegreeForAnchorCount(anchorCount, polynomialDegree);
	phase6PolynomialDegreeFirstAttempted = "" + phase6PolynomialDegreeUsed;
	if (phase6PolynomialDegreeUsed < 1)
		return "Phase 6 could not choose a safe polynomial fallback degree for " + anchorCount + " validated anchors and requested degree " + polynomialDegree + ".";
	if (phase6PolynomialDegreeUsed != polynomialDegree)
		phase6FitWarning = appendWarning(phase6FitWarning, "Phase 6 polynomial fallback used for sample " + phase2SourceSample + ": anchor count=" + anchorCount + "; requested degree=" + polynomialDegree + "; actual degree used=" + phase6PolynomialDegreeUsed + ".");
	phase6FitFunction = getPhase6PolynomialFitFunction(phase6PolynomialDegreeUsed);
	if (phase6FitFunction == "")
		return "No ImageJ polynomial fit function was mapped for actual degree: " + phase6PolynomialDegreeUsed + ".";
	if (anchorCount <= phase6PolynomialDegreeUsed)
		return "Actual polynomial degree " + phase6PolynomialDegreeUsed + " requires at least " + (phase6PolynomialDegreeUsed + 1) + " validated anchors, but Phase 5 validated " + anchorCount + ".";
	if (rawCount <= 0)
		return "Phase 6 could not find original time points for baseline generation.";
	if (lengthOf(rawValues) < rawCount)
		return "Phase 6 raw value array length was shorter than raw time count; baseline plausibility checks could not be run safely.";
	if (phase6SourceAnchorArrayLength < anchorCount) {
		phase6FitInputArrayStatus = "Failed_Source_Time_Array_Too_Short";
		return "Phase 6 source anchor time array length " + phase6SourceAnchorArrayLength + " was smaller than validated anchor count " + anchorCount + ".";
	}
	phase6SourceAnchorValueArrayLength = lengthOf(anchorValues);
	if (phase6SourceAnchorValueArrayLength < anchorCount) {
		phase6FitInputArrayStatus = "Failed_Source_Value_Array_Too_Short";
		return "Phase 6 source anchor value array length " + phase6SourceAnchorValueArrayLength + " was smaller than validated anchor count " + anchorCount + ".";
	}

	phase6FitAnchorTimes = newArray(anchorCount);
	phase6FitAnchorValues = newArray(anchorCount);
	if (lengthOf(phase6FitAnchorTimes) != anchorCount || lengthOf(phase6FitAnchorValues) != anchorCount) {
		phase6FitInputArrayStatus = "Failed_Exact_Length_Array_Creation";
		return "Phase 6 could not create exact-length fit input arrays for " + anchorCount + " validated anchors.";
	}

	for (phase6FitInputIndex = 0; phase6FitInputIndex < anchorCount; phase6FitInputIndex++) {
		phase6FitInputTime = anchorTimes[phase6FitInputIndex];
		phase6FitInputValue = anchorValues[phase6FitInputIndex];
		if (!isPhase6FiniteNumber(phase6FitInputTime)) {
			phase6FitInputArrayStatus = "Failed_Nonfinite_Anchor_Time";
			return "Phase 6 validated anchor time was not finite at anchor " + (phase6FitInputIndex + 1) + ".";
		}
		if (!isPhase6FiniteNumber(phase6FitInputValue)) {
			phase6FitInputArrayStatus = "Failed_Nonfinite_Anchor_Value";
			return "Phase 6 validated anchor value was not finite at anchor " + (phase6FitInputIndex + 1) + ".";
		}
		phase6FitAnchorTimes[phase6FitInputIndex] = phase6FitInputTime;
		phase6FitAnchorValues[phase6FitInputIndex] = phase6FitInputValue;
		if (phase6FitInputIndex == 0) {
			phase6AnchorTimeMin = phase6FitInputTime;
			phase6AnchorTimeMax = phase6FitInputTime;
			phase6AnchorValueMin = phase6FitInputValue;
			phase6AnchorValueMax = phase6FitInputValue;
		} else {
			if (phase6FitInputTime < phase6AnchorTimeMin)
				phase6AnchorTimeMin = phase6FitInputTime;
			if (phase6FitInputTime > phase6AnchorTimeMax)
				phase6AnchorTimeMax = phase6FitInputTime;
			if (phase6FitInputValue < phase6AnchorValueMin)
				phase6AnchorValueMin = phase6FitInputValue;
			if (phase6FitInputValue > phase6AnchorValueMax)
				phase6AnchorValueMax = phase6FitInputValue;
		}
	}

	phase6FitInputAnchorCount = lengthOf(phase6FitAnchorTimes);
	if (phase6FitInputAnchorCount != anchorCount || lengthOf(phase6FitAnchorValues) != anchorCount) {
		phase6FitInputArrayStatus = "Failed_Exact_Length_Count_Mismatch";
		return "Phase 6 exact-length fit input count did not equal validated anchor count " + anchorCount + ".";
	}
	phase6FitInputFirstTime = phase6FitAnchorTimes[0];
	phase6FitInputLastTime = phase6FitAnchorTimes[anchorCount - 1];
	phase6FitInputFirstValue = phase6FitAnchorValues[0];
	phase6FitInputLastValue = phase6FitAnchorValues[anchorCount - 1];
	phase6FitInputArrayStatus = "Exact_Length_Validated";

	Fit.doFit(phase6FitFunction, phase6FitAnchorTimes, phase6FitAnchorValues);
	expectedCoefficientCount = phase6PolynomialDegreeUsed + 1;
	phase6CoefficientCount = Fit.nParams;
	if (phase6CoefficientCount != expectedCoefficientCount)
		return "ImageJ Fit.doFit returned " + phase6CoefficientCount + " parameters for " + phase6FitFunction + "; expected " + expectedCoefficientCount + ".";

	phase6Coefficients = newArray(expectedCoefficientCount);
	for (phase6CoeffIndex = 0; phase6CoeffIndex < expectedCoefficientCount; phase6CoeffIndex++) {
		phase6Coeff = Fit.p(phase6CoeffIndex);
		if (!isPhase6FiniteNumber(phase6Coeff))
			return "ImageJ Fit.p(" + phase6CoeffIndex + ") was invalid after " + phase6FitFunction + ".";
		phase6Coefficients[phase6CoeffIndex] = phase6Coeff;
		if (abs(phase6Coeff) > phase6CoefficientStabilityAbsLimit)
			phase6FitWarning = appendWarning(phase6FitWarning, "Phase 6 coefficient p" + phase6CoeffIndex + " exceeded stability warning limit " + phase6CoefficientStabilityAbsLimit + ".");
	}
	phase6CoefficientsText = buildPhase6CoefficientText(phase6Coefficients, expectedCoefficientCount);

	phase6AnchorMean = 0;
	for (phase6AnchorIndex = 0; phase6AnchorIndex < anchorCount; phase6AnchorIndex++)
		phase6AnchorMean = phase6AnchorMean + phase6FitAnchorValues[phase6AnchorIndex];
	phase6AnchorMean = phase6AnchorMean / anchorCount;

	phase6SSE = 0;
	phase6SST = 0;
	phase6AnchorResidualMaxAbs = 0;
	phase6AnchorResidualMaxPercentAbs = 0;
	phase6AnchorFittedValues = newArray(anchorCount);
	phase6AnchorResidualValues = newArray(anchorCount);
	phase6AnchorPercentResidualValues = newArray(anchorCount);
	for (phase6AnchorIndex = 0; phase6AnchorIndex < anchorCount; phase6AnchorIndex++) {
		phase6AnchorFitValue = evaluatePhase6Polynomial(phase6Coefficients, phase6PolynomialDegreeUsed, phase6FitAnchorTimes[phase6AnchorIndex]);
		if (!isPhase6FiniteNumber(phase6AnchorFitValue))
			return "Phase 6 fitted anchor value was invalid at anchor " + (phase6AnchorIndex + 1) + ".";
		phase6Residual = phase6FitAnchorValues[phase6AnchorIndex] - phase6AnchorFitValue;
		if (!isPhase6FiniteNumber(phase6Residual))
			return "Phase 6 residual was invalid at anchor " + (phase6AnchorIndex + 1) + ".";
		if (phase6FitAnchorValues[phase6AnchorIndex] == 0)
			return "Phase 6 anchor percent residual could not be computed because anchor " + (phase6AnchorIndex + 1) + " had value zero.";
		phase6PercentResidual = 100 * phase6Residual / phase6FitAnchorValues[phase6AnchorIndex];
		if (!isPhase6FiniteNumber(phase6PercentResidual))
			return "Phase 6 percent residual was invalid at anchor " + (phase6AnchorIndex + 1) + ".";
		phase6AnchorFittedValues[phase6AnchorIndex] = phase6AnchorFitValue;
		phase6AnchorResidualValues[phase6AnchorIndex] = phase6Residual;
		phase6AnchorPercentResidualValues[phase6AnchorIndex] = phase6PercentResidual;
		if (abs(phase6Residual) > phase6AnchorResidualMaxAbs)
			phase6AnchorResidualMaxAbs = abs(phase6Residual);
		if (abs(phase6PercentResidual) > phase6AnchorResidualMaxPercentAbs)
			phase6AnchorResidualMaxPercentAbs = abs(phase6PercentResidual);
		phase6SSE = phase6SSE + phase6Residual * phase6Residual;
		phase6MeanDifference = phase6FitAnchorValues[phase6AnchorIndex] - phase6AnchorMean;
		phase6SST = phase6SST + phase6MeanDifference * phase6MeanDifference;
	}
	phase6AnchorDiagnosticCount = anchorCount;

	if (!isPhase6FiniteNumber(phase6SSE))
		return "Phase 6 fit residual sum of squares was invalid.";
	phase6FitRMSE = sqrt(phase6SSE / anchorCount);
	if (!isPhase6FiniteNumber(phase6FitRMSE))
		return "Phase 6 anchor residual RMSE was invalid.";
	phase6AnchorResidualRMSE = phase6FitRMSE;
	if (!isPhase6FiniteNumber(phase6AnchorResidualMaxAbs))
		return "Phase 6 maximum absolute anchor residual was invalid.";
	if (!isPhase6FiniteNumber(phase6AnchorResidualMaxPercentAbs))
		return "Phase 6 maximum absolute anchor percent residual was invalid.";
	if (phase6AnchorResidualMaxPercentAbs > phase6AnchorResidualWarnPercent)
		phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, "Phase 6 maximum absolute anchor percent residual exceeded warning threshold " + phase6AnchorResidualWarnPercent + "%.");
	if (phase6AnchorResidualMaxPercentAbs > phase6AnchorResidualFailPercent) {
		phase6AnchorResidualMaxPercentText = formatPhase6DiagnosticNumber(phase6AnchorResidualMaxPercentAbs);
		return "Phase 6 maximum absolute anchor percent residual " + phase6AnchorResidualMaxPercentText + "% exceeded failure threshold " + phase6AnchorResidualFailPercent + "%.";
	}
	if (anchorCount > 1 && phase6SST > 0 && isPhase6FiniteNumber(phase6SST)) {
		phase6FitRSquared = 1 - (phase6SSE / phase6SST);
		if (!isPhase6FiniteNumber(phase6FitRSquared)) {
			phase6FitRSquared = "NA";
			phase6FitWarning = appendWarning(phase6FitWarning, "Phase 6 R2 could not be computed safely and was recorded as NA.");
		} else if (phase6FitRSquared < 0)
			phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, "Phase 6 fitted-anchor R2 was negative.");
	} else {
		phase6FitRSquared = "NA";
		phase6FitWarning = appendWarning(phase6FitWarning, "Phase 6 R2 could not be computed safely because anchor variance was zero or anchor count was too low; recorded as NA.");
	}

	phase6RawRowsBeforeFirstAnchor = 0;
	phase6RawRowsAfterLastAnchor = 0;
	for (phase6RawValidationIndex = 0; phase6RawValidationIndex < rawCount; phase6RawValidationIndex++) {
		phase6RawTime = rawTimes[phase6RawValidationIndex];
		if (!isPhase6FiniteNumber(phase6RawTime))
			return "Phase 6 raw time was invalid at original time-point row " + (phase6RawValidationIndex + 1) + ".";
		if (phase6RawValidationIndex == 0) {
			phase6RawTimeMin = phase6RawTime;
			phase6RawTimeMax = phase6RawTime;
		} else {
			if (phase6RawTime < phase6RawTimeMin)
				phase6RawTimeMin = phase6RawTime;
			if (phase6RawTime > phase6RawTimeMax)
				phase6RawTimeMax = phase6RawTime;
		}
		if (phase6RawTime < phase6AnchorTimeMin)
			phase6RawRowsBeforeFirstAnchor++;
		if (phase6RawTime > phase6AnchorTimeMax)
			phase6RawRowsAfterLastAnchor++;
	}
	phase6RawPercentOutsideAnchorSupport = 100 * (phase6RawRowsBeforeFirstAnchor + phase6RawRowsAfterLastAnchor) / rawCount;
	phase6RawDuration = phase6RawTimeMax - phase6RawTimeMin;
	phase6AnchorTimeCoveragePercent = "NA";
	if (phase6RawDuration > 0)
		phase6AnchorTimeCoveragePercent = 100 * (phase6AnchorTimeMax - phase6AnchorTimeMin) / phase6RawDuration;
	if (phase6RawRowsBeforeFirstAnchor > 0 || phase6RawRowsAfterLastAnchor > 0) {
		phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Endpoint handling not yet implemented; fitted baseline includes extrapolated region outside validated anchor range.");
		if (phase6RawPercentOutsideAnchorSupport > 20)
			phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Strong endpoint support warning: more than 20% of the raw trace lies outside first/last anchor support.");
		else if (phase6RawPercentOutsideAnchorSupport > 10)
			phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Endpoint support warning: more than 10% of the raw trace lies outside first/last anchor support.");
	}
	phase6EarlyAnchorCount = 0;
	phase6MiddleAnchorCount = 0;
	phase6LateAnchorCount = 0;
	if (phase6RawDuration > 0) {
		phase6FirstThirdTime = phase6RawTimeMin + phase6RawDuration / 3;
		phase6SecondThirdTime = phase6RawTimeMin + 2 * phase6RawDuration / 3;
		for (phase6SpreadIndex = 0; phase6SpreadIndex < anchorCount; phase6SpreadIndex++) {
			phase6SpreadTime = phase6FitAnchorTimes[phase6SpreadIndex];
			if (phase6SpreadTime <= phase6FirstThirdTime)
				phase6EarlyAnchorCount++;
			else if (phase6SpreadTime <= phase6SecondThirdTime)
				phase6MiddleAnchorCount++;
			else
				phase6LateAnchorCount++;
		}
		if (phase6EarlyAnchorCount > 0 && phase6MiddleAnchorCount > 0 && phase6LateAnchorCount > 0)
			phase6AnchorSpreadStatus = "Distributed_Early_Middle_Late";
		else {
			phase6AnchorSpreadStatus = "Clustered_Or_Missing_Trace_Third";
			phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Anchor spread warning: validated anchors were not represented in all early/middle/late trace thirds.");
		}
		phase6MaxInternalAnchorGap = 0;
		for (phase6SpreadIndex = 1; phase6SpreadIndex < anchorCount; phase6SpreadIndex++) {
			phase6InternalAnchorGap = phase6FitAnchorTimes[phase6SpreadIndex] - phase6FitAnchorTimes[phase6SpreadIndex - 1];
			if (phase6InternalAnchorGap > phase6MaxInternalAnchorGap)
				phase6MaxInternalAnchorGap = phase6InternalAnchorGap;
		}
		phase6MaxInternalAnchorGapPercent = 100 * phase6MaxInternalAnchorGap / phase6RawDuration;
		if (phase6MaxInternalAnchorGapPercent > 50)
			phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Internal anchor support warning: largest gap between adjacent validated anchors exceeds 50% of raw trace duration.");
		if (isPhase6FiniteNumber(phase6AnchorTimeCoveragePercent) && phase6AnchorTimeCoveragePercent < 80)
			phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Anchor time coverage warning: anchors cover less than 80% of raw trace duration.");
		phase6PeakAwareAnchorTimingWarning = buildPhase6PeakAwareAnchorTimingWarning(phase6FitAnchorTimes, anchorCount, rawTimes, rawCount, phase5PeakTimes, phase5PeakCount);
		phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, phase6PeakAwareAnchorTimingWarning);
	} else {
		phase6AnchorSpreadStatus = "Not_Evaluated_Invalid_Raw_Duration";
	}
	phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, phase6BaselineEndpointWarning);

	phase6BaselineValues = newArray(rawCount);
	phase6BaselineSum = 0;
	for (phase6RawIndex = 0; phase6RawIndex < rawCount; phase6RawIndex++) {
		phase6BaselineValue = evaluatePhase6Polynomial(phase6Coefficients, phase6PolynomialDegreeUsed, rawTimes[phase6RawIndex]);
		if (!isPhase6FiniteNumber(phase6BaselineValue))
			return "Phase 6 fitted baseline value was invalid at original time-point row " + (phase6RawIndex + 1) + ".";
		if (phase6BaselineValue <= 0)
			return "Phase 6 fitted baseline value was zero or negative at original time-point row " + (phase6RawIndex + 1) + ".";
		phase6BaselineValues[phase6RawIndex] = phase6BaselineValue;
		if (phase6RawIndex == 0) {
			phase6FittedBaselineMin = phase6BaselineValue;
			phase6FittedBaselineMax = phase6BaselineValue;
			phase6FirstFittedBaseline = phase6BaselineValue;
		} else {
			if (phase6BaselineValue < phase6FittedBaselineMin)
				phase6FittedBaselineMin = phase6BaselineValue;
			if (phase6BaselineValue > phase6FittedBaselineMax)
				phase6FittedBaselineMax = phase6BaselineValue;
		}
		phase6BaselineSum = phase6BaselineSum + phase6BaselineValue;
	}
	phase6LastFittedBaseline = phase6BaselineValues[rawCount - 1];
	phase6FittedBaselineMean = phase6BaselineSum / rawCount;
	phase6BaselineValueCount = rawCount;
	if (phase6BaselineValueCount != rawCount)
		return "Phase 6 fitted baseline value count did not equal raw timepoint count.";

	if (phase6FittedBaselineMin < phase6AnchorValueMin || phase6FittedBaselineMax > phase6AnchorValueMax)
		phase6BaselineRangeWarning = appendWarning(phase6BaselineRangeWarning, "Phase 6 fitted baseline range extends outside the validated anchor value range.");
	phase6AnchorValueRange = phase6AnchorValueMax - phase6AnchorValueMin;
	phase6RangeTolerance = phase6AnchorValueRange * 0.25;
	if (isPhase6FiniteNumber(phase5RawYMin) && isPhase6FiniteNumber(phase5RawYMax)) {
		phase6RawValueRange = phase5RawYMax - phase5RawYMin;
		if (phase6RangeTolerance < phase6RawValueRange * 0.05)
			phase6RangeTolerance = phase6RawValueRange * 0.05;
		if (phase6FittedBaselineMin < phase5RawYMin || phase6FittedBaselineMax > phase5RawYMax)
			phase6BaselineRangeWarning = appendWarning(phase6BaselineRangeWarning, "Phase 6 fitted baseline range extends outside the raw fluorescence value range.");
	} else {
		phase6RawValueRange = phase6AnchorValueRange;
	}
	if (phase6FittedBaselineMin < phase6AnchorValueMin - phase6RangeTolerance || phase6FittedBaselineMax > phase6AnchorValueMax + phase6RangeTolerance)
		phase6BaselineRangeWarning = appendWarning(phase6BaselineRangeWarning, "Strong baseline range warning: fitted baseline extends beyond anchor range tolerance.");

	phase6BaselineAboveRawCount = 0;
	phase6StrongNegativeCorrectedCount = 0;
	phase6StrongNegativeThreshold = -0.2;
	for (phase6RawIndex = 0; phase6RawIndex < rawCount; phase6RawIndex++) {
		phase6DeltaFOverF0Candidate = (rawValues[phase6RawIndex] - phase6BaselineValues[phase6RawIndex]) / phase6BaselineValues[phase6RawIndex];
		if (phase6BaselineValues[phase6RawIndex] > rawValues[phase6RawIndex])
			phase6BaselineAboveRawCount++;
		if (phase6DeltaFOverF0Candidate < phase6StrongNegativeThreshold)
			phase6StrongNegativeCorrectedCount++;
	}
	phase6BaselineAboveRawPercent = 100 * phase6BaselineAboveRawCount / rawCount;
	phase6StrongNegativeCorrectedPercent = 100 * phase6StrongNegativeCorrectedCount / rawCount;
	if (phase6BaselineAboveRawPercent > 25)
		phase6BaselineNegativeCorrectionWarning = appendWarning(phase6BaselineNegativeCorrectionWarning, "Peak preservation warning: fitted baseline is above more than 25% of raw trace points.");
	if (phase6StrongNegativeCorrectedPercent > 5)
		phase6BaselineNegativeCorrectionWarning = appendWarning(phase6BaselineNegativeCorrectionWarning, "Negative correction warning: more than 5% of DeltaF/F0 values would be below -0.2.");

	phase6EndpointWindow = floor(rawCount * 0.05);
	if (phase6EndpointWindow < 2)
		phase6EndpointWindow = 2;
	if (phase6EndpointWindow >= rawCount)
		phase6EndpointWindow = rawCount - 1;
	phase6StartSlope = abs(phase6BaselineValues[phase6EndpointWindow] - phase6BaselineValues[0]) / (phase6EndpointWindow + 1);
	phase6EndSlope = abs(phase6BaselineValues[rawCount - 1] - phase6BaselineValues[rawCount - 1 - phase6EndpointWindow]) / (phase6EndpointWindow + 1);
	phase6OverallSlope = abs(phase6BaselineValues[rawCount - 1] - phase6BaselineValues[0]) / rawCount;
	phase6SlopeFloor = abs(phase6FittedBaselineMax - phase6FittedBaselineMin) / rawCount;
	if (phase6SlopeFloor < 0.000000001)
		phase6SlopeFloor = 0.000000001;
	if (phase6StartSlope > 5 * phase6SlopeFloor || phase6EndSlope > 5 * phase6SlopeFloor)
		phase6BaselineEndpointWarning = appendWarning(phase6BaselineEndpointWarning, "Endpoint slope warning: fitted baseline changes unusually quickly near the start or end of the trace.");
	if (phase6PolynomialDegreeUsed >= 3 && phase6RawValueRange > 0 && (phase6FittedBaselineMax - phase6FittedBaselineMin) > phase6RawValueRange * 0.75)
		phase6BaselineCurvatureWarning = appendWarning(phase6BaselineCurvatureWarning, "Curvature warning: high-degree fitted baseline spans more than 75% of raw fluorescence range.");

	phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, phase6BaselineRangeWarning);
	phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, phase6BaselineNegativeCorrectionWarning);
	phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, phase6BaselineEndpointWarning);
	phase6FitReasonablenessWarning = appendWarning(phase6FitReasonablenessWarning, phase6BaselineCurvatureWarning);

	if (phase6ShouldUseLowerPolynomialDegreeForQC() && phase6PolynomialDegreeUsed > 1) {
		phase6FirstAttemptDegree = phase6PolynomialDegreeUsed;
		phase6FallbackReasonText = appendWarning("", phase6BaselineRangeWarning);
		phase6FallbackReasonText = appendWarning(phase6FallbackReasonText, phase6BaselineNegativeCorrectionWarning);
		phase6FallbackReasonText = appendWarning(phase6FallbackReasonText, phase6BaselineEndpointWarning);
		phase6FallbackReasonText = appendWarning(phase6FallbackReasonText, phase6BaselineCurvatureWarning);
		phase6FallbackDegree = phase6PolynomialDegreeUsed - 1;
		phase6FallbackError = runPhase6PolynomialBaselineFit(anchorTimes, anchorValues, anchorCount, rawTimes, rawValues, rawCount, phase6FallbackDegree);
		phase6PolynomialDegreeFirstAttempted = "" + phase6FirstAttemptDegree;
		phase6PolynomialFallbackUsed = "Yes";
		phase6PolynomialFallbackReason = phase6FallbackReasonText;
		phase6FitWarning = appendWarning(phase6FitWarning, "Phase 17 QC-driven polynomial fallback used: first attempted degree=" + phase6FirstAttemptDegree + "; final degree=" + phase6PolynomialDegreeUsed + "; reason=" + phase6FallbackReasonText);
		return phase6FallbackError;
	}

	if (phase6FitReasonablenessWarning == "")
		phase6FitReasonablenessStatus = "Passed";
	else
		phase6FitReasonablenessStatus = "Passed_With_Warnings";
	classifyPhase6BaselineReliability();
	if (phase6BaselineReliabilityClass != "Baseline_OK")
		phase6FitWarning = appendWarning(phase6FitWarning, "Baseline reliability classification: " + phase6BaselineReliabilityClass + "; reason=" + phase6BaselineReliabilityReason + ".");
	phase6FitWarning = appendWarning(phase6FitWarning, phase6FitReasonablenessWarning);

	return "";
}

function phase6ShouldUseLowerPolynomialDegreeForQC() {
	if (phase6PolynomialDegreeUsed <= 1)
		return false;
	if (indexOf(phase6BaselineRangeWarning, "Strong baseline range warning") >= 0)
		return true;
	if (phase6PolynomialDegreeUsed > 2 && indexOf(phase6BaselineNegativeCorrectionWarning, "Peak preservation warning") >= 0)
		return true;
	if (indexOf(phase6BaselineNegativeCorrectionWarning, "Negative correction warning") >= 0)
		return true;
	if (phase6PolynomialDegreeUsed > 2 && indexOf(phase6BaselineEndpointWarning, "Internal anchor support warning") >= 0)
		return true;
	if (indexOf(phase6BaselineEndpointWarning, "Endpoint slope warning") >= 0)
		return true;
	if (indexOf(phase6BaselineCurvatureWarning, "Curvature warning") >= 0)
		return true;
	return false;
}

function classifyPhase6BaselineReliability() {
	phase6BaselineReliabilityClass = "Baseline_OK";
	phase6BaselineReliabilityReason = "";

	if (phase6PeakAwareAnchorTimingWarning != "")
		phase6BaselineReliabilityReason = appendWarning(phase6BaselineReliabilityReason, "Peak_Aware_Anchor_Timing_Warning");
	if (indexOf(phase6BaselineRangeWarning, "Strong baseline range warning") >= 0)
		phase6BaselineReliabilityReason = appendWarning(phase6BaselineReliabilityReason, "Strong_Baseline_Range_Warning");
	if (indexOf(phase6BaselineNegativeCorrectionWarning, "Negative correction warning") >= 0)
		phase6BaselineReliabilityReason = appendWarning(phase6BaselineReliabilityReason, "Strong_Negative_Correction_Warning");
	if (phase6PolynomialFallbackUsed == "Yes" && phase6PolynomialDegreeFirstAttempted != "" && phase6PolynomialDegreeUsed != "" && phase6PolynomialDegreeFirstAttempted != phase6PolynomialDegreeUsed)
		phase6BaselineReliabilityReason = appendWarning(phase6BaselineReliabilityReason, "Polynomial_Fallback_Used");

	if (phase6BaselineReliabilityReason != "") {
		phase6BaselineReliabilityClass = "Baseline_HighRisk";
		return;
	}

	if (phase6FitReasonablenessWarning != "") {
		phase6BaselineReliabilityClass = "Baseline_Warning";
		phase6BaselineReliabilityReason = "Non_HighRisk_Phase6_Warning";
		return;
	}

	phase6BaselineReliabilityReason = "No_Baseline_Warnings";
}

function savePhase6BaselineFitDiagnosticsTable(savePath, sampleName, anchorTimes, anchorValues, fittedValues, residualValues, percentResidualValues, anchorCount, sourceXColumn, sourceYColumn, polynomialDegree) {
	if (anchorCount <= 0)
		return "Phase 6 baseline-fit diagnostic table was not exported because anchor diagnostic count was zero.";
	if (lengthOf(anchorTimes) != anchorCount || lengthOf(anchorValues) != anchorCount)
		return "Phase 6 baseline-fit diagnostic table was not exported because exact-length fit input arrays did not match anchor count.";
	if (lengthOf(fittedValues) != anchorCount || lengthOf(residualValues) != anchorCount || lengthOf(percentResidualValues) != anchorCount)
		return "Phase 6 baseline-fit diagnostic table was not exported because residual diagnostic arrays did not match anchor count.";

	tableText = "Sample_Name" + outputFieldDelimiter + "Anchor_Index" + outputFieldDelimiter + "Anchor_Time" + outputFieldDelimiter + "Anchor_Value" + outputFieldDelimiter + "Fitted_Value_At_Anchor_Time" + outputFieldDelimiter + "Residual" + outputFieldDelimiter + "Percent_Residual" + outputFieldDelimiter + "Source_X_Column" + outputFieldDelimiter + "Source_Y_Column" + outputFieldDelimiter + "Polynomial_Degree\n";
	qSampleName = quoteBaselineAnchorText(sampleName);
	qSourceXColumn = quoteBaselineAnchorText(sourceXColumn);
	qSourceYColumn = quoteBaselineAnchorText(sourceYColumn);
	qPolynomialDegree = formatPhase6DiagnosticNumber(polynomialDegree);

	for (phase6DiagnosticExportIndex = 0; phase6DiagnosticExportIndex < anchorCount; phase6DiagnosticExportIndex++) {
		qAnchorIndex = "" + (phase6DiagnosticExportIndex + 1);
		qAnchorTime = formatPhase6DiagnosticNumber(anchorTimes[phase6DiagnosticExportIndex]);
		qAnchorValue = formatPhase6DiagnosticNumber(anchorValues[phase6DiagnosticExportIndex]);
		qFittedValue = formatPhase6DiagnosticNumber(fittedValues[phase6DiagnosticExportIndex]);
		qResidual = formatPhase6DiagnosticNumber(residualValues[phase6DiagnosticExportIndex]);
		qPercentResidual = formatPhase6DiagnosticNumber(percentResidualValues[phase6DiagnosticExportIndex]);
		rowText = qSampleName;
		rowText = rowText + outputFieldDelimiter + qAnchorIndex;
		rowText = rowText + outputFieldDelimiter + qAnchorTime;
		rowText = rowText + outputFieldDelimiter + qAnchorValue;
		rowText = rowText + outputFieldDelimiter + qFittedValue;
		rowText = rowText + outputFieldDelimiter + qResidual;
		rowText = rowText + outputFieldDelimiter + qPercentResidual;
		rowText = rowText + outputFieldDelimiter + qSourceXColumn;
		rowText = rowText + outputFieldDelimiter + qSourceYColumn;
		rowText = rowText + outputFieldDelimiter + qPolynomialDegree;
		tableText = tableText + rowText + "\n";
	}

	File.saveString(tableText, savePath);
	if (File.exists(savePath))
		return "";
	return "Phase 6 baseline-fit diagnostic table save command completed but file was not found: " + savePath;
}

function clearPhase7InternalArrays() {
	phase7BaselineTimes = newArray(0);
	phase7BaselineValues = newArray(0);
	phase7DeltaFValues = newArray(0);
	phase7DeltaFOverF0Values = newArray(0);
	phase7DeltaFOverF0PercentValues = newArray(0);
	phase7DeltaFValueCount = 0;
	phase7DeltaFOverF0ValueCount = 0;
	phase7DeltaFOverF0PercentValueCount = 0;
}

function clearPhase7CorrectedSummaries() {
	phase7MinDeltaF = "";
	phase7MeanDeltaF = "";
	phase7MaxDeltaF = "";
	phase7MinDeltaFOverF0 = "";
	phase7MeanDeltaFOverF0 = "";
	phase7MaxDeltaFOverF0 = "";
	phase7MinDeltaFOverF0Percent = "";
	phase7MeanDeltaFOverF0Percent = "";
	phase7MaxDeltaFOverF0Percent = "";
}

function runPhase7CorrectedTraceCalculation(rawTimes, rawValues, rawCount, baselineValues, baselineCount) {
	clearPhase7InternalArrays();
	phase7RawValueCount = rawCount;
	phase7BaselineValueCount = baselineCount;
	phase7RawBaselineAlignmentStatus = "";
	phase7MinDeltaF = "";
	phase7MeanDeltaF = "";
	phase7MaxDeltaF = "";
	phase7MinDeltaFOverF0 = "";
	phase7MeanDeltaFOverF0 = "";
	phase7MaxDeltaFOverF0 = "";
	phase7MinDeltaFOverF0Percent = "";
	phase7MeanDeltaFOverF0Percent = "";
	phase7MaxDeltaFOverF0Percent = "";
	phase7InvalidBaselineValueCount = 0;
	phase7InvalidCorrectedValueCount = 0;
	phase7FirstInvalidRow = "";
	phase7FirstInvalidReason = "";
	phase7Warning = "";

	if (phase6FitStatus != "Phase6_Polynomial_Baseline_Fit_Completed")
		return "Phase 7 requires completed Phase 6 fitted baseline values before corrected trace calculation.";
	if (phase6FitReasonablenessStatus != "Passed" && phase6FitReasonablenessStatus != "Passed_With_Warnings")
		return "Phase 7 requires a passed Phase 6 fit reasonableness status before corrected trace calculation; found: " + phase6FitReasonablenessStatus + ".";
	if (phase6FitReasonablenessWarning != "")
		phase7Warning = appendWarning(phase7Warning, "Phase 7 diagnostic export inherits Phase 6 warning: " + phase6FitReasonablenessWarning);
	if (rawCount <= 0)
		return "Phase 7 could not find original raw trace rows.";
	if (baselineCount <= 0)
		return "Phase 7 could not find Phase 6 fitted baseline values.";
	if (baselineCount != rawCount) {
		phase7RawBaselineAlignmentStatus = "Failed_Count_Mismatch";
		return "Phase 7 baseline/raw count mismatch: raw count " + rawCount + ", baseline count " + baselineCount + ".";
	}

	for (phase7ValidationIndex = 0; phase7ValidationIndex < rawCount; phase7ValidationIndex++) {
		if (!isPhase7FiniteNumber(rawTimes[phase7ValidationIndex])) {
			phase7FirstInvalidRow = phase7ValidationIndex + 1;
			phase7FirstInvalidReason = "Raw time was not finite.";
			return "Phase 7 raw time was invalid at original row " + phase7FirstInvalidRow + ".";
		}
		if (!isPhase7FiniteNumber(rawValues[phase7ValidationIndex])) {
			phase7FirstInvalidRow = phase7ValidationIndex + 1;
			phase7FirstInvalidReason = "Raw value was not finite.";
			return "Phase 7 raw value was invalid at original row " + phase7FirstInvalidRow + ".";
		}
		phase7BaselineValue = baselineValues[phase7ValidationIndex];
		if (!isPhase7SafeBaselineDenominator(phase7BaselineValue)) {
			phase7InvalidBaselineValueCount++;
			if (phase7FirstInvalidRow == "") {
				phase7FirstInvalidRow = phase7ValidationIndex + 1;
				if (!isPhase7FiniteNumber(phase7BaselineValue))
					phase7FirstInvalidReason = "Baseline denominator was not finite.";
				else if (phase7BaselineValue <= 0)
					phase7FirstInvalidReason = "Baseline denominator was zero or negative.";
				else
					phase7FirstInvalidReason = "Baseline denominator was too close to zero.";
			}
		}
	}

	if (phase7InvalidBaselineValueCount > 0)
		return "Phase 7 found " + phase7InvalidBaselineValueCount + " invalid baseline denominator value(s); first invalid row " + phase7FirstInvalidRow + ": " + phase7FirstInvalidReason;

	phase7RawBaselineAlignmentStatus = "Verified_By_Shared_RowOrder_And_Count";
	phase7BaselineTimes = newArray(rawCount);
	phase7BaselineValues = newArray(rawCount);
	phase7DeltaFValues = newArray(rawCount);
	phase7DeltaFOverF0Values = newArray(rawCount);
	phase7DeltaFOverF0PercentValues = newArray(rawCount);
	phase7DeltaFSum = 0;
	phase7DeltaFOverF0Sum = 0;
	phase7DeltaFOverF0PercentSum = 0;

	for (phase7CalcIndex = 0; phase7CalcIndex < rawCount; phase7CalcIndex++) {
		phase7BaselineValue = baselineValues[phase7CalcIndex];
		phase7DeltaFValue = rawValues[phase7CalcIndex] - phase7BaselineValue;
		phase7DeltaFOverF0Value = phase7DeltaFValue / phase7BaselineValue;
		phase7DeltaFOverF0PercentValue = 100 * phase7DeltaFOverF0Value;

		if (!isPhase7FiniteNumber(phase7DeltaFValue)) {
			phase7InvalidCorrectedValueCount++;
			phase7FirstInvalidRow = phase7CalcIndex + 1;
			phase7FirstInvalidReason = "DeltaF was not finite.";
			clearPhase7InternalArrays();
			clearPhase7CorrectedSummaries();
			return "Phase 7 DeltaF was invalid at original row " + phase7FirstInvalidRow + ".";
		}
		if (!isPhase7FiniteNumber(phase7DeltaFOverF0Value)) {
			phase7InvalidCorrectedValueCount++;
			phase7FirstInvalidRow = phase7CalcIndex + 1;
			phase7FirstInvalidReason = "DeltaF/F0 was not finite.";
			clearPhase7InternalArrays();
			clearPhase7CorrectedSummaries();
			return "Phase 7 DeltaF/F0 was invalid at original row " + phase7FirstInvalidRow + ".";
		}
		if (!isPhase7FiniteNumber(phase7DeltaFOverF0PercentValue)) {
			phase7InvalidCorrectedValueCount++;
			phase7FirstInvalidRow = phase7CalcIndex + 1;
			phase7FirstInvalidReason = "DeltaF/F0 percent was not finite.";
			clearPhase7InternalArrays();
			clearPhase7CorrectedSummaries();
			return "Phase 7 DeltaF/F0 percent was invalid at original row " + phase7FirstInvalidRow + ".";
		}

		phase7BaselineTimes[phase7CalcIndex] = rawTimes[phase7CalcIndex];
		phase7BaselineValues[phase7CalcIndex] = phase7BaselineValue;
		phase7DeltaFValues[phase7CalcIndex] = phase7DeltaFValue;
		phase7DeltaFOverF0Values[phase7CalcIndex] = phase7DeltaFOverF0Value;
		phase7DeltaFOverF0PercentValues[phase7CalcIndex] = phase7DeltaFOverF0PercentValue;

		if (phase7CalcIndex == 0) {
			phase7MinDeltaF = phase7DeltaFValue;
			phase7MaxDeltaF = phase7DeltaFValue;
			phase7MinDeltaFOverF0 = phase7DeltaFOverF0Value;
			phase7MaxDeltaFOverF0 = phase7DeltaFOverF0Value;
			phase7MinDeltaFOverF0Percent = phase7DeltaFOverF0PercentValue;
			phase7MaxDeltaFOverF0Percent = phase7DeltaFOverF0PercentValue;
		} else {
			if (phase7DeltaFValue < phase7MinDeltaF)
				phase7MinDeltaF = phase7DeltaFValue;
			if (phase7DeltaFValue > phase7MaxDeltaF)
				phase7MaxDeltaF = phase7DeltaFValue;
			if (phase7DeltaFOverF0Value < phase7MinDeltaFOverF0)
				phase7MinDeltaFOverF0 = phase7DeltaFOverF0Value;
			if (phase7DeltaFOverF0Value > phase7MaxDeltaFOverF0)
				phase7MaxDeltaFOverF0 = phase7DeltaFOverF0Value;
			if (phase7DeltaFOverF0PercentValue < phase7MinDeltaFOverF0Percent)
				phase7MinDeltaFOverF0Percent = phase7DeltaFOverF0PercentValue;
			if (phase7DeltaFOverF0PercentValue > phase7MaxDeltaFOverF0Percent)
				phase7MaxDeltaFOverF0Percent = phase7DeltaFOverF0PercentValue;
		}

		phase7DeltaFSum = phase7DeltaFSum + phase7DeltaFValue;
		phase7DeltaFOverF0Sum = phase7DeltaFOverF0Sum + phase7DeltaFOverF0Value;
		phase7DeltaFOverF0PercentSum = phase7DeltaFOverF0PercentSum + phase7DeltaFOverF0PercentValue;
	}

	phase7MeanDeltaF = phase7DeltaFSum / rawCount;
	phase7MeanDeltaFOverF0 = phase7DeltaFOverF0Sum / rawCount;
	phase7MeanDeltaFOverF0Percent = phase7DeltaFOverF0PercentSum / rawCount;
	phase7DeltaFValueCount = rawCount;
	phase7DeltaFOverF0ValueCount = rawCount;
	phase7DeltaFOverF0PercentValueCount = rawCount;

	return "";
}

function isPhase7FiniteNumber(value) {
	if (isNaN(value))
		return false;
	if (abs(value) > 1e300)
		return false;
	return true;
}

function isPhase7SafeBaselineDenominator(value) {
	if (!isPhase7FiniteNumber(value))
		return false;
	if (value <= 0)
		return false;
	if (abs(value) <= phase7MinimumSafeBaselineAbs)
		return false;
	return true;
}

function formatPhase7DiagnosticNumber(value) {
	text = "" + value;
	if (text == "")
		return "";
	formattedText = d2s(value, 12);
	while (indexOf(formattedText, ".") >= 0 && endsWith(formattedText, "0"))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (endsWith(formattedText, "."))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (outputDecimalSeparator == ",")
		formattedText = replace(formattedText, ".", ",");
	return formattedText;
}

function savePhase2RawValuesTable(savePath, sampleName, rawTimeColumnName, rawSampleColumnName, valueCount) {
	if (valueCount <= 0)
		return "Phase 2 raw values table was not exported because row count was zero.";
	if (!isOpen(activeTableTitle))
		return "Phase 2 raw values table was not exported because the raw input table was not open: " + activeTableTitle;

	selectWindow(activeTableTitle);
	tableText = "Sample_Name" + outputFieldDelimiter + "Row_Index" + outputFieldDelimiter + "Time" + outputFieldDelimiter + "Raw_Fluorescence\n";
	qSampleName = quotePhase7CorrectedTraceText(sampleName);

	for (phase2RawExportIndex = 0; phase2RawExportIndex < valueCount; phase2RawExportIndex++) {
		phase2RawExportTime = Table.get(rawTimeColumnName, phase2RawExportIndex);
		phase2RawExportValue = Table.get(rawSampleColumnName, phase2RawExportIndex);
		if (isNaN(phase2RawExportTime) || isNaN(phase2RawExportValue))
			return "Phase 2 raw values table export found nonnumeric Time or sample value at row " + (phase2RawExportIndex + 1) + ".";
		qRowIndex = "" + (phase2RawExportIndex + 1);
		qTime = formatPhase7DiagnosticNumber(phase2RawExportTime);
		qRawValue = formatPhase7DiagnosticNumber(phase2RawExportValue);
		rowText = qSampleName;
		rowText = rowText + outputFieldDelimiter + qRowIndex;
		rowText = rowText + outputFieldDelimiter + qTime;
		rowText = rowText + outputFieldDelimiter + qRawValue;
		tableText = tableText + rowText + "\n";
	}

	File.saveString(tableText, savePath);
	if (File.exists(savePath))
		return "";
	return "Phase 2 raw values table save command completed but file was not found: " + savePath;
}

function savePhase7CorrectedTraceTable(savePath, sampleName, rawTimes, rawValues, baselineValues, deltaFValues, deltaFOverF0Values, deltaFOverF0PercentValues, valueCount) {
	if (phase7CalculationStatus != "Phase7_Corrected_Trace_Calculation_Completed")
		return "Phase 7 corrected trace table was not exported because Phase 7 calculation status was not completed: " + phase7CalculationStatus;
	if (phase6FitReasonablenessStatus != "Passed" && phase6FitReasonablenessStatus != "Passed_With_Warnings")
		return "Phase 7 corrected trace table was not exported because Phase 6 fit reasonableness status did not pass: " + phase6FitReasonablenessStatus;
	if (valueCount <= 0)
		return "Phase 7 corrected trace table was not exported because raw value count was zero.";
	if (phase7RawValueCount != valueCount)
		return "Phase 7 corrected trace table was not exported because raw value count did not match expected row count.";
	if (phase7BaselineValueCount != valueCount)
		return "Phase 7 corrected trace table was not exported because baseline value count did not match raw value count.";
	if (phase7DeltaFValueCount != valueCount)
		return "Phase 7 corrected trace table was not exported because DeltaF value count did not match raw value count.";
	if (phase7DeltaFOverF0ValueCount != valueCount)
		return "Phase 7 corrected trace table was not exported because DeltaF/F0 value count did not match raw value count.";
	if (phase7DeltaFOverF0PercentValueCount != valueCount)
		return "Phase 7 corrected trace table was not exported because DeltaF/F0 percent value count did not match raw value count.";
	if (phase7InvalidBaselineValueCount != 0)
		return "Phase 7 corrected trace table was not exported because invalid baseline value count was " + phase7InvalidBaselineValueCount + ".";
	if (phase7InvalidCorrectedValueCount != 0)
		return "Phase 7 corrected trace table was not exported because invalid corrected value count was " + phase7InvalidCorrectedValueCount + ".";

	tableText = "Sample_Name" + outputFieldDelimiter + "Row_Index" + outputFieldDelimiter + "Time" + outputFieldDelimiter + "Raw_Fluorescence" + outputFieldDelimiter + "Fitted_Baseline" + outputFieldDelimiter + "DeltaF" + outputFieldDelimiter + "DeltaF_over_F0" + outputFieldDelimiter + "DeltaF_over_F0_percent\n";
	qSampleName = quotePhase7CorrectedTraceText(sampleName);

	for (phase7ExportIndex = 0; phase7ExportIndex < valueCount; phase7ExportIndex++) {
		qRowIndex = "" + (phase7ExportIndex + 1);
		qTime = formatPhase7DiagnosticNumber(rawTimes[phase7ExportIndex]);
		qRawValue = formatPhase7DiagnosticNumber(rawValues[phase7ExportIndex]);
		qBaseline = formatPhase7DiagnosticNumber(baselineValues[phase7ExportIndex]);
		qDeltaF = formatPhase7DiagnosticNumber(deltaFValues[phase7ExportIndex]);
		qDeltaFOverF0 = formatPhase7DiagnosticNumber(deltaFOverF0Values[phase7ExportIndex]);
		qDeltaFOverF0Percent = formatPhase7DiagnosticNumber(deltaFOverF0PercentValues[phase7ExportIndex]);

		rowText = qSampleName;
		rowText = rowText + outputFieldDelimiter + qRowIndex;
		rowText = rowText + outputFieldDelimiter + qTime;
		rowText = rowText + outputFieldDelimiter + qRawValue;
		rowText = rowText + outputFieldDelimiter + qBaseline;
		rowText = rowText + outputFieldDelimiter + qDeltaF;
		rowText = rowText + outputFieldDelimiter + qDeltaFOverF0;
		rowText = rowText + outputFieldDelimiter + qDeltaFOverF0Percent;
		tableText = tableText + rowText + "\n";
	}

	File.saveString(tableText, savePath);
	if (File.exists(savePath))
		return "";

	return "Phase 7 corrected trace table save command completed but file was not found: " + savePath;
}

function validatePhase8BaselineReconstructionInputs(rawTimes, rawValues, rawCount, anchorTimes, anchorValues, anchorCount, baselineValues, baselineCount) {
	if (runMode != "Test First Sample Only" && runMode != "Full Batch")
		return "Phase 8 baseline reconstruction plot is only implemented for Test First Sample Only and Phase 14 Full Batch modes.";
	if (sampleStatuses[phase13CurrentSampleIndex] == "Failed")
		return "Phase 8 baseline reconstruction plot was not created because the sample was already marked Failed.";
	if (phase6FitStatus != "Phase6_Polynomial_Baseline_Fit_Completed")
		return "Phase 8 requires completed Phase 6 fitted baseline values; found Phase 6 status: " + phase6FitStatus + ".";
	if (phase6FitReasonablenessStatus != "Passed" && phase6FitReasonablenessStatus != "Passed_With_Warnings")
		return "Phase 8 requires a passed Phase 6 fit reasonableness status; found: " + phase6FitReasonablenessStatus + ".";
	if (phase7CalculationStatus != "Phase7_Corrected_Trace_Calculation_Completed")
		return "Phase 8 requires completed Phase 7 calculation; found: " + phase7CalculationStatus + ".";
	if (phase7RawBaselineAlignmentStatus != "Verified_By_Shared_RowOrder_And_Count")
		return "Phase 8 requires verified Phase 7 raw/baseline alignment; found: " + phase7RawBaselineAlignmentStatus + ".";
	if (phase7CorrectedTraceTableSaveStatus != "Saved")
		return "Phase 8 requires the Phase 7 corrected trace diagnostic table to be saved before plotting; found: " + phase7CorrectedTraceTableSaveStatus + ".";
	if (rawCount <= 0)
		return "Phase 8 could not find original raw trace rows.";
	if (lengthOf(rawTimes) != rawCount)
		return "Phase 8 raw time array length " + lengthOf(rawTimes) + " did not match raw row count " + rawCount + ".";
	if (lengthOf(rawValues) != rawCount)
		return "Phase 8 raw value array length " + lengthOf(rawValues) + " did not match raw row count " + rawCount + ".";
	if (baselineCount <= 0)
		return "Phase 8 could not find Phase 6 fitted baseline values.";
	if (baselineCount != rawCount)
		return "Phase 8 baseline/raw count mismatch: raw count " + rawCount + ", baseline count " + baselineCount + ".";
	if (lengthOf(baselineValues) != rawCount)
		return "Phase 8 fitted baseline array length " + lengthOf(baselineValues) + " did not match raw row count " + rawCount + ".";
	if (anchorCount <= 0)
		return "Phase 8 could not find exact-length validated Phase 6 anchor arrays.";
	if (phase5AnchorCount != anchorCount)
		return "Phase 8 exact-length anchor count " + anchorCount + " did not match validated Phase 5 anchor count " + phase5AnchorCount + ".";
	if (phase6FitInputArrayStatus != "Exact_Length_Validated")
		return "Phase 8 requires exact-length validated Phase 6 fit input arrays; found: " + phase6FitInputArrayStatus + ".";
	if (lengthOf(anchorTimes) != anchorCount)
		return "Phase 8 exact-length anchor time array length " + lengthOf(anchorTimes) + " did not match anchor count " + anchorCount + ".";
	if (lengthOf(anchorValues) != anchorCount)
		return "Phase 8 exact-length anchor value array length " + lengthOf(anchorValues) + " did not match anchor count " + anchorCount + ".";

	for (phase8ValidationIndex = 0; phase8ValidationIndex < rawCount; phase8ValidationIndex++) {
		if (!isPhase6FiniteNumber(rawTimes[phase8ValidationIndex]))
			return "Phase 8 raw time was invalid at original row " + (phase8ValidationIndex + 1) + ".";
		if (!isPhase6FiniteNumber(rawValues[phase8ValidationIndex]))
			return "Phase 8 raw fluorescence value was invalid at original row " + (phase8ValidationIndex + 1) + ".";
		if (!isPhase6FiniteNumber(baselineValues[phase8ValidationIndex]))
			return "Phase 8 fitted baseline value was invalid at original row " + (phase8ValidationIndex + 1) + ".";
	}

	for (phase8AnchorValidationIndex = 0; phase8AnchorValidationIndex < anchorCount; phase8AnchorValidationIndex++) {
		if (!isPhase6FiniteNumber(anchorTimes[phase8AnchorValidationIndex]))
			return "Phase 8 exact-length anchor time was invalid at anchor " + (phase8AnchorValidationIndex + 1) + ".";
		if (!isPhase6FiniteNumber(anchorValues[phase8AnchorValidationIndex]))
			return "Phase 8 exact-length anchor value was invalid at anchor " + (phase8AnchorValidationIndex + 1) + ".";
	}

	return "";
}

function preparePhase8EndpointWarningAndAnnotation(rawTimes, anchorTimes) {
	phase8FirstRawTime = "";
	phase8FirstAnchorTime = "";
	phase8InPlotWarningStatus = "Not_Shown_No_Endpoint_Extrapolation";
	phase8InPlotWarningText = "";

	if (lengthOf(rawTimes) > 0)
		phase8FirstRawTime = formatPhase6DiagnosticNumber(rawTimes[0]);
	if (lengthOf(anchorTimes) > 0)
		phase8FirstAnchorTime = formatPhase6DiagnosticNumber(anchorTimes[0]);

	phase8RoutineEndpointWarning = "Endpoint handling not yet implemented; fitted baseline includes extrapolated region outside validated anchor range.";
	phase8EndpointExtrapolationPresent = false;
	if (phase6RawRowsBeforeFirstAnchor > 0 || phase6RawRowsAfterLastAnchor > 0)
		phase8EndpointExtrapolationPresent = true;

	phase8NonRoutinePhase6WarningPresent = false;
	if (phase6FitReasonablenessStatus == "Passed_With_Warnings" && phase6FitReasonablenessWarning != "" && phase6FitReasonablenessWarning != phase8RoutineEndpointWarning)
		phase8NonRoutinePhase6WarningPresent = true;

	if (phase8EndpointExtrapolationPresent && phase6RawPercentOutsideAnchorSupport > phase8EndpointAnnotationThresholdPercent) {
		phase8InPlotWarningStatus = "Shown_Endpoint_Extrapolation_Above_Threshold";
		phase8InPlotWarningText = "QC warning: endpoint extrapolation >10%; see Run_Log.";
	} else if (phase8NonRoutinePhase6WarningPresent) {
		phase8InPlotWarningStatus = "Shown_NonRoutine_Phase6_Warning";
		phase8InPlotWarningText = "QC warning: Phase 6 fit warning; see Run_Log.";
	} else if (phase8EndpointExtrapolationPresent) {
		phase8InPlotWarningStatus = "Not_Shown_Routine_Endpoint_At_Or_Below_Threshold";
	}

	phase8EndpointWarningText = "";
	if (phase8EndpointExtrapolationPresent) {
		phase8EndpointWarningText = "Endpoint extrapolation detected; first raw time=" + phase8FirstRawTime + "; first anchor time=" + phase8FirstAnchorTime + "; rows before first anchor=" + phase6RawRowsBeforeFirstAnchor + "; rows after last anchor=" + phase6RawRowsAfterLastAnchor + "; percent outside anchor support=" + formatPhase6DiagnosticNumber(phase6RawPercentOutsideAnchorSupport) + "%; endpoint policy status=warning-only; no capping/flattening; no boundary anchors; no endpoint correction applied; in-plot warning status=" + phase8InPlotWarningStatus + ".";
	}
	if (phase8NonRoutinePhase6WarningPresent)
		phase8EndpointWarningText = appendWarning(phase8EndpointWarningText, "Non-routine Phase 6 reasonableness warning present: " + phase6FitReasonablenessWarning);

	return phase8EndpointWarningText;
}

function createPhase8BaselineReconstructionPlot(plotWindowName, sampleName, rawTimes, rawValues, rawCount, anchorTimes, anchorValues, anchorCount, baselineValues, baselineCount) {
	if (plotWindowName == "")
		return "Phase 8 plot window name was blank.";
	if (isOpen(plotWindowName))
		return "Phase 8 baseline reconstruction plot window already existed before plotting: " + plotWindowName;

	Plot.create(plotWindowName, phase2XAxisLabel, phase2YAxisLabel);
	Plot.setLineWidth(1);
	Plot.setColor("black");
	Plot.add("line", rawTimes, rawValues);
	Plot.setLineWidth(2);
	Plot.setColor("red");
	Plot.add("line", rawTimes, baselineValues);
	Plot.setLineWidth(4);
	Plot.setColor("blue");
	Plot.add("circles", anchorTimes, anchorValues);
	Plot.setLineWidth(1);
	Plot.setColor("black");
	Plot.addText("black: raw trace", 0.62, 0.05);
	Plot.setColor("red");
	Plot.addText("red: fitted baseline", 0.62, 0.10);
	Plot.setColor("blue");
	Plot.addText("blue: validated anchors", 0.62, 0.15);
	if (phase6BaselineReliabilityClass == "Baseline_HighRisk") {
		Plot.setColor("magenta");
		Plot.addText("Baseline QC: HIGH RISK", 0.62, 0.23);
	} else if (phase6BaselineReliabilityClass == "Baseline_Warning") {
		Plot.setColor("magenta");
		Plot.addText("Baseline QC: warning", 0.62, 0.23);
	}
	if (phase8InPlotWarningText != "") {
		Plot.setColor("magenta");
		Plot.addText("QC warning: see Run_Log", 0.62, 0.31);
	}
	Plot.show();

	if (!isOpen(plotWindowName))
		return "Phase 8 plot creation completed but expected plot window was not open: " + plotWindowName;

	return "";
}

function savePhase8BaselineReconstructionPlotAsPng(plotWindowTitle, savePath) {
	if (savePath == "")
		return "Phase 8 baseline reconstruction plot save path was blank.";
	if (!File.exists(plotsFolder))
		return "Phase 8 could not save baseline reconstruction plot because Plots folder was missing: " + plotsFolder;
	if (File.exists(savePath))
		return "Phase 8 baseline reconstruction plot save path already existed before saving: " + savePath;
	if (!isOpen(plotWindowTitle))
		return "Phase 8 could not save baseline reconstruction plot because window was not open: " + plotWindowTitle;

	selectWindow(plotWindowTitle);
	phase8SelectedWindowType = getInfo("window.type");
	if (!startsWith(phase8SelectedWindowType, "Plot"))
		return "Phase 8 selected baseline reconstruction window was not a Plot: " + phase8SelectedWindowType;

	saveAs("PNG", savePath);
	if (File.exists(savePath))
		return "";

	return "Phase 8 baseline reconstruction plot save command completed but file was not found: " + savePath;
}

function validatePhase9SecondSpikyInputs(rawTimes, deltaFOverF0Values, rawCount) {
	phase9CorrectedInputValueCount = "";
	phase9CorrectedInputYMin = "";
	phase9CorrectedInputYMax = "";
	phase9CorrectedInputWarning = "";

	if (runMode != "Test First Sample Only" && runMode != "Full Batch")
		return "Phase 9 second Spiky analysis is only implemented for Test First Sample Only and Phase 14 Full Batch modes.";
	if (sampleStatuses[phase13CurrentSampleIndex] == "Failed")
		return "Phase 9 corrected input plot was not created because the sample was already marked Failed.";
	if (phase6FitStatus != "Phase6_Polynomial_Baseline_Fit_Completed")
		return "Phase 9 requires completed Phase 6 fitted baseline values; found Phase 6 status: " + phase6FitStatus + ".";
	if (phase6FitReasonablenessStatus != "Passed" && phase6FitReasonablenessStatus != "Passed_With_Warnings")
		return "Phase 9 requires a passed Phase 6 fit reasonableness status; found: " + phase6FitReasonablenessStatus + ".";
	if (phase7CalculationStatus != "Phase7_Corrected_Trace_Calculation_Completed")
		return "Phase 9 requires completed Phase 7 corrected trace calculation; found: " + phase7CalculationStatus + ".";
	if (phase7RawBaselineAlignmentStatus != "Verified_By_Shared_RowOrder_And_Count")
		return "Phase 9 requires verified Phase 7 raw/baseline alignment; found: " + phase7RawBaselineAlignmentStatus + ".";
	if (phase7CorrectedTraceTableSaveStatus != "Saved")
		return "Phase 9 requires the Phase 7 corrected trace diagnostic table to be saved; found: " + phase7CorrectedTraceTableSaveStatus + ".";
	if (phase8PlotStatus != "Saved")
		return "Phase 9 requires the Phase 8 baseline reconstruction QC plot to be saved before second Spiky analysis; found: " + phase8PlotStatus + ".";
	if (rawCount <= 0)
		return "Phase 9 could not find original raw trace rows.";
	if (lengthOf(rawTimes) != rawCount)
		return "Phase 9 raw time array length " + lengthOf(rawTimes) + " did not match raw row count " + rawCount + ".";
	if (lengthOf(deltaFOverF0Values) != rawCount)
		return "Phase 9 DeltaF/F0 array length " + lengthOf(deltaFOverF0Values) + " did not match raw row count " + rawCount + ".";
	if (phase7DeltaFOverF0ValueCount != rawCount)
		return "Phase 9 DeltaF/F0 value count " + phase7DeltaFOverF0ValueCount + " did not match raw row count " + rawCount + ".";
	if (phase7InvalidCorrectedValueCount != 0)
		return "Phase 9 requires zero invalid corrected values from Phase 7; found: " + phase7InvalidCorrectedValueCount + ".";
	if (phase9CorrectedInputPlotName == "")
		return "Phase 9 corrected DeltaF/F0 input plot name was blank.";
	if (isOpen(phase9CorrectedInputPlotName))
		return "Phase 9 corrected DeltaF/F0 input plot window already existed before plotting: " + phase9CorrectedInputPlotName;

	for (phase9ValidationIndex = 0; phase9ValidationIndex < rawCount; phase9ValidationIndex++) {
		if (!isPhase7FiniteNumber(rawTimes[phase9ValidationIndex]))
			return "Phase 9 raw time was invalid at original row " + (phase9ValidationIndex + 1) + ".";
		if (!isPhase7FiniteNumber(deltaFOverF0Values[phase9ValidationIndex]))
			return "Phase 9 DeltaF/F0 value was invalid at original row " + (phase9ValidationIndex + 1) + ".";

		phase9CurrentDeltaFOverF0 = deltaFOverF0Values[phase9ValidationIndex];
		if (phase9ValidationIndex == 0) {
			phase9CorrectedInputYMin = phase9CurrentDeltaFOverF0;
			phase9CorrectedInputYMax = phase9CurrentDeltaFOverF0;
		} else {
			if (phase9CurrentDeltaFOverF0 < phase9CorrectedInputYMin)
				phase9CorrectedInputYMin = phase9CurrentDeltaFOverF0;
			if (phase9CurrentDeltaFOverF0 > phase9CorrectedInputYMax)
				phase9CorrectedInputYMax = phase9CurrentDeltaFOverF0;
		}
	}

	phase9CorrectedInputValueCount = rawCount;
	if (phase8PlotWarning != "")
		phase9CorrectedInputWarning = appendWarning(phase9CorrectedInputWarning, "Phase 9 proceeded with prior warning-only endpoint status already logged in Phase 8; no endpoint correction applied.");

	return "";
}

function createPhase9CorrectedDeltaFOverF0Plot(plotWindowName, rawTimes, deltaFOverF0Values, valueCount) {
	if (plotWindowName == "")
		return "Phase 9 corrected DeltaF/F0 input plot window name was blank.";
	if (valueCount <= 0)
		return "Phase 9 corrected DeltaF/F0 input plot was not created because value count was zero.";
	if (isOpen(plotWindowName))
		return "Phase 9 corrected DeltaF/F0 input plot window already existed before plotting: " + plotWindowName;

	Plot.create(plotWindowName, phase2XAxisLabel, "DeltaF/F0");
	Plot.setLineWidth(1);
	Plot.setColor("black");
	Plot.add("line", rawTimes, deltaFOverF0Values);
	Plot.show();

	if (!isOpen(plotWindowName))
		return "Phase 9 corrected DeltaF/F0 input plot creation completed but expected plot window was not open: " + plotWindowName;

	return "";
}

function validatePhase10FinalOutputInputs() {
	if (runMode != "Test First Sample Only" && runMode != "Full Batch")
		return "Phase 10 final output export is only implemented for Test First Sample Only and Phase 14 Full Batch modes.";
	if (sampleStatuses[phase13CurrentSampleIndex] == "Failed")
		return "Phase 10 final output export was not created because the sample was already marked Failed.";
	if (phase9SecondSpikyStatus != "Phase9_SecondSpiky_Output_Captured")
		return "Phase 10 requires successful Phase 9 second-Spiky capture; found: " + phase9SecondSpikyStatus + ".";
	if (phase9SecondSpikyWasCalled != "Yes")
		return "Phase 10 requires Phase 9 second Spiky to have been called; found: " + phase9SecondSpikyWasCalled + ".";
	if (phase9CorrectedInputPlotName == "")
		return "Phase 10 could not verify the corrected input plot name.";
	if (phase10FinalPeakTableSourceName == "")
		return "Phase 10 second-Spiky peak-analysis table source name was blank.";
	if (phase10FinalPeakPlotSourceName == "")
		return "Phase 10 second-Spiky detected-peaks plot source name was blank.";

	expectedPhase10TableName = phase9CorrectedInputPlotName + "-Peak analysis";
	expectedPhase10PlotName = phase9CorrectedInputPlotName + "-detected_peaks";
	if (phase10FinalPeakTableSourceName != expectedPhase10TableName)
		return "Phase 10 peak table source did not match corrected second-Spiky source. Expected " + expectedPhase10TableName + " but found " + phase10FinalPeakTableSourceName + ".";
	if (phase10FinalPeakPlotSourceName != expectedPhase10PlotName)
		return "Phase 10 peak plot source did not match corrected second-Spiky source. Expected " + expectedPhase10PlotName + " but found " + phase10FinalPeakPlotSourceName + ".";
	if (phase10FinalPeakTableSourceName == phase3SpikyPeakAnalysisTableName)
		return "Phase 10 peak table source matched the first-Spiky raw-trace table and cannot be exported as final corrected output.";
	if (phase10FinalPeakPlotSourceName == phase3SpikyDetectedPeaksPlotName)
		return "Phase 10 peak plot source matched the first-Spiky raw-trace plot and cannot be saved as final corrected output.";

	if (phase10FinalPeakTableSavePath == "")
		return "Phase 10 final peak-analysis table save path was blank.";
	if (phase10FinalPeakPlotSavePath == "")
		return "Phase 10 final peak-analysis plot save path was blank.";
	if (File.exists(phase10FinalPeakTableSavePath))
		return "Phase 10 final peak-analysis table save path already existed before export: " + phase10FinalPeakTableSavePath;
	if (File.exists(phase10FinalPeakPlotSavePath))
		return "Phase 10 final peak-analysis plot save path already existed before saving: " + phase10FinalPeakPlotSavePath;
	if (!File.exists(outputFolder))
		return "Phase 10 output folder was missing: " + outputFolder;
	if (!File.exists(plotsFolder))
		return "Phase 10 plots folder was missing: " + plotsFolder;

	if (!isOpen(phase10FinalPeakTableSourceName))
		return "Phase 10 second-Spiky peak-analysis table was not open: " + phase10FinalPeakTableSourceName;
	selectWindow(phase10FinalPeakTableSourceName);
	phase10TableWindowType = getInfo("window.type");
	if (!startsWith(phase10TableWindowType, "ResultsTable"))
		return "Phase 10 second-Spiky peak-analysis table source was not a ResultsTable: " + phase10TableWindowType;
	phase10TableHeadings = Table.headings;
	if (phase10TableHeadings == "")
		return "Phase 10 second-Spiky peak-analysis table had no readable headings.";

	if (!isOpen(phase10FinalPeakPlotSourceName))
		return "Phase 10 second-Spiky detected-peaks plot was not open: " + phase10FinalPeakPlotSourceName;
	selectWindow(phase10FinalPeakPlotSourceName);
	phase10PlotWindowType = getInfo("window.type");
	if (!startsWith(phase10PlotWindowType, "Plot"))
		return "Phase 10 second-Spiky detected-peaks source window was not a Plot: " + phase10PlotWindowType;

	return "";
}

function savePhase10FinalPeakAnalysisTable(tableWindowTitle, savePath, sampleName, analysisType) {
	if (!isOpen(tableWindowTitle))
		return "Could not export Phase 10 final peak-analysis table because source window was not open: " + tableWindowTitle;
	if (savePath == "")
		return "Could not export Phase 10 final peak-analysis table because save path was blank.";
	if (File.exists(savePath))
		return "Could not export Phase 10 final peak-analysis table because save path already existed: " + savePath;

	selectWindow(tableWindowTitle);
	phase10TableWindowType = getInfo("window.type");
	if (!startsWith(phase10TableWindowType, "ResultsTable"))
		return "Could not export Phase 10 final peak-analysis table because source was not a ResultsTable: " + phase10TableWindowType;

	tableHeadings = Table.headings;
	tableRows = Table.size;
	if (tableHeadings == "")
		return "Could not export Phase 10 final peak-analysis table because source had no readable headings.";

	tableText = buildPhase10FinalPeakAnalysisTableText(tableHeadings, tableRows, sampleName, analysisType);
	if (startsWith(tableText, "PHASE10_TABLE_EXPORT_ERROR:"))
		return tableText;

	File.saveString(tableText, savePath);
	if (File.exists(savePath))
		return "";

	return "Phase 10 final peak-analysis table save command completed but file was not found: " + savePath;
}

function buildPhase10FinalPeakAnalysisTableText(tableHeadings, tableRows, sampleName, analysisType) {
	headings = split(tableHeadings, "\t");
	columnCountForExport = lengthOf(headings);
	if (columnCountForExport <= 0)
		return "PHASE10_TABLE_EXPORT_ERROR: no columns were found in the Phase 10 final peak-analysis table.";

	includeColumns = newArray(columnCountForExport);
	sourceReadHeadings = newArray(columnCountForExport);
	exportHeadings = newArray(columnCountForExport);
	includedColumnCount = 0;
	blankExportHeadingCount = 0;
	phase10SkippedBlankIndexColumn = false;
	phase10BlankHeadingRenamed = false;
	phase10DuplicateHeadingsMadeUnique = false;
	for (phase10ExportColumn = 0; phase10ExportColumn < columnCountForExport; phase10ExportColumn++) {
		sourceHeading = headings[phase10ExportColumn];
		trimmedHeading = trimString(sourceHeading);
		if (trimmedHeading == "") {
			blankColumnHasData = false;
			fallbackColumnHasData = false;
			fallbackHeading = "Column_" + (phase10ExportColumn + 1);
			for (phase10ExportRow = 0; phase10ExportRow < tableRows; phase10ExportRow++) {
				cellText = Table.getString(sourceHeading, phase10ExportRow);
				if (cellText != "null" && cellText != "")
					blankColumnHasData = true;

				fallbackCellText = Table.getString(fallbackHeading, phase10ExportRow);
				if (fallbackCellText != "null" && fallbackCellText != "")
					fallbackColumnHasData = true;
			}

			if (!blankColumnHasData && !fallbackColumnHasData) {
				includeColumns[phase10ExportColumn] = 0;
				phase10SkippedBlankIndexColumn = true;
			} else {
				includeColumns[phase10ExportColumn] = 1;
				if (blankColumnHasData)
					sourceReadHeadings[phase10ExportColumn] = sourceHeading;
				else
					sourceReadHeadings[phase10ExportColumn] = fallbackHeading;
				if (phase10SourceReadHeadingAlreadyUsed(sourceReadHeadings, includeColumns, phase10ExportColumn, sourceReadHeadings[phase10ExportColumn]))
					return "PHASE10_TABLE_EXPORT_ERROR: blank Phase 10 peak-analysis heading contained data but could not be read safely as a distinct source column at column " + (phase10ExportColumn + 1);

				blankExportHeadingCount++;
				proposedExportHeading = "Spiky_Unnamed_Column_" + blankExportHeadingCount;
				exportHeadings[phase10ExportColumn] = makePhase10UniqueExportHeading(proposedExportHeading, exportHeadings, phase10ExportColumn);
				if (exportHeadings[phase10ExportColumn] != proposedExportHeading)
					phase10DuplicateHeadingsMadeUnique = true;
				phase10BlankHeadingRenamed = true;
				includedColumnCount++;
			}
		} else {
			includeColumns[phase10ExportColumn] = 1;
			sourceReadHeadings[phase10ExportColumn] = sourceHeading;
			if (phase10SourceReadHeadingAlreadyUsed(sourceReadHeadings, includeColumns, phase10ExportColumn, sourceReadHeadings[phase10ExportColumn]))
				return "PHASE10_TABLE_EXPORT_ERROR: duplicate Phase 10 peak-analysis source heading cannot be read safely by ImageJ heading lookup: " + trimmedHeading;
			exportHeadings[phase10ExportColumn] = makePhase10UniqueExportHeading(trimmedHeading, exportHeadings, phase10ExportColumn);
			if (exportHeadings[phase10ExportColumn] != trimmedHeading)
				phase10DuplicateHeadingsMadeUnique = true;
			includedColumnCount++;
		}
	}
	if (phase10SkippedBlankIndexColumn || phase10BlankHeadingRenamed || phase10DuplicateHeadingsMadeUnique) {
		phase10HeadingWarningText = "Phase 10 export headings adjusted:";
		if (phase10SkippedBlankIndexColumn)
			phase10HeadingWarningText = phase10HeadingWarningText + " skipped blank index column;";
		if (phase10BlankHeadingRenamed)
			phase10HeadingWarningText = phase10HeadingWarningText + " blank headings renamed;";
		if (phase10DuplicateHeadingsMadeUnique)
			phase10HeadingWarningText = phase10HeadingWarningText + " duplicate headings made unique;";
		phase10FinalOutputWarning = appendWarning(phase10FinalOutputWarning, phase10HeadingWarningText);
	}
	if (includedColumnCount <= 0)
		return "PHASE10_TABLE_EXPORT_ERROR: no usable Spiky columns were found in the Phase 10 final peak-analysis table.";

	columnReadCounts = newArray(columnCountForExport);
	phase10FinalPeakTableRowCount = tableRows;
	phase10FinalPeakTableColumnCount = includedColumnCount + 2;
	if (tableRows == 0)
		phase10FinalOutputWarning = appendWarning(phase10FinalOutputWarning, "No peaks detected in second-Spiky peak-analysis table");

	qSampleHeading = quotePhase3PeakAnalysisText("Sample_Name");
	qAnalysisTypeHeading = quotePhase3PeakAnalysisText("Analysis_Type");
	headerText = qSampleHeading + outputFieldDelimiter + qAnalysisTypeHeading;
	for (phase10HeaderColumn = 0; phase10HeaderColumn < columnCountForExport; phase10HeaderColumn++) {
		if (includeColumns[phase10HeaderColumn] == 1) {
			qHeading = quotePhase3PeakAnalysisText(exportHeadings[phase10HeaderColumn]);
			headerText = headerText + outputFieldDelimiter + qHeading;
		}
	}

	tableText = headerText + "\n";
	qSampleName = quotePhase3PeakAnalysisText(sampleName);
	qAnalysisType = quotePhase3PeakAnalysisText(analysisType);
	for (phase10ExportRow = 0; phase10ExportRow < tableRows; phase10ExportRow++) {
		rowText = qSampleName + outputFieldDelimiter + qAnalysisType;
		for (phase10ExportColumn = 0; phase10ExportColumn < columnCountForExport; phase10ExportColumn++) {
			if (includeColumns[phase10ExportColumn] == 1) {
				sourceHeading = sourceReadHeadings[phase10ExportColumn];
				cellText = Table.getString(sourceHeading, phase10ExportRow);
				if (cellText != "null")
					columnReadCounts[phase10ExportColumn] = columnReadCounts[phase10ExportColumn] + 1;
				qCell = formatPhase3PeakAnalysisCell(cellText);
				rowText = rowText + outputFieldDelimiter + qCell;
			}
		}
		tableText = tableText + rowText + "\n";
	}

	for (phase10ExportColumn = 0; phase10ExportColumn < columnCountForExport; phase10ExportColumn++) {
		if (includeColumns[phase10ExportColumn] == 1 && tableRows > 0) {
			if (columnReadCounts[phase10ExportColumn] == 0)
				return "PHASE10_TABLE_EXPORT_ERROR: Phase 10 peak-analysis column could not be read safely for export: " + exportHeadings[phase10ExportColumn];
		}
	}

	return tableText;
}

function phase10SourceReadHeadingAlreadyUsed(sourceReadHeadings, includeColumns, currentColumn, readHeading) {
	for (phase10CompareColumn = 0; phase10CompareColumn < currentColumn; phase10CompareColumn++) {
		if (includeColumns[phase10CompareColumn] == 1) {
			compareReadHeading = sourceReadHeadings[phase10CompareColumn];
			if (compareReadHeading == readHeading)
				return true;
		}
	}
	return false;
}

function makePhase10UniqueExportHeading(candidateHeading, exportHeadings, currentColumn) {
	baseHeading = trimString(candidateHeading);
	if (baseHeading == "")
		baseHeading = "Spiky_Unnamed_Column";

	uniqueHeading = baseHeading;
	duplicateIndex = 2;
	while (phase10ExportHeadingAlreadyUsed(exportHeadings, currentColumn, uniqueHeading)) {
		uniqueHeading = baseHeading + "_" + duplicateIndex;
		duplicateIndex++;
	}
	return uniqueHeading;
}

function phase10ExportHeadingAlreadyUsed(exportHeadings, currentColumn, exportHeading) {
	for (phase10CompareColumn = 0; phase10CompareColumn < currentColumn; phase10CompareColumn++) {
		compareExportHeading = exportHeadings[phase10CompareColumn];
		if (compareExportHeading != "" && compareExportHeading == exportHeading)
			return true;
	}
	return false;
}

function savePhase10FinalPeakAnalysisPlotAsPng(plotWindowTitle, savePath) {
	if (plotWindowTitle == "")
		return "Could not save Phase 10 final peak-analysis plot because source window name was blank.";
	if (savePath == "")
		return "Could not save Phase 10 final peak-analysis plot because save path was blank.";
	if (File.exists(savePath))
		return "Could not save Phase 10 final peak-analysis plot because save path already existed: " + savePath;
	if (!isOpen(plotWindowTitle))
		return "Could not save Phase 10 final peak-analysis plot because source window was not open: " + plotWindowTitle;

	selectWindow(plotWindowTitle);
	phase10PlotWindowType = getInfo("window.type");
	if (!startsWith(phase10PlotWindowType, "Plot"))
		return "Could not save Phase 10 final peak-analysis plot because source window was not a Plot: " + phase10PlotWindowType;

	saveAs("PNG", savePath);
	if (File.exists(savePath))
		return "";

	return "Phase 10 final peak-analysis plot save command completed but file was not found: " + savePath;
}

function quotePhase7CorrectedTraceText(value) {
	text = "" + value;
	if (text == "")
		return "";
	text = replace(text, "\"", "\"\"");
	quotedText = "\"" + text + "\"";
	return quotedText;
}

function getPhase6PolynomialFitFunction(polynomialDegree) {
	if (polynomialDegree == 1)
		return "Straight Line";
	if (polynomialDegree == 2)
		return "2nd Degree Polynomial";
	if (polynomialDegree == 3)
		return "3rd Degree Polynomial";
	if (polynomialDegree == 4)
		return "4th Degree Polynomial";
	return "";
}

function evaluatePhase6Polynomial(coefficients, polynomialDegree, xValue) {
	fittedValue = coefficients[polynomialDegree];
	phase6EvalIndex = polynomialDegree - 1;
	while (phase6EvalIndex >= 0) {
		fittedValue = fittedValue * xValue + coefficients[phase6EvalIndex];
		phase6EvalIndex = phase6EvalIndex - 1;
	}
	return fittedValue;
}

function buildPhase6CoefficientText(coefficients, coefficientCount) {
	text = "";
	for (phase6CoeffTextIndex = 0; phase6CoeffTextIndex < coefficientCount; phase6CoeffTextIndex++) {
		coefficientText = "p" + phase6CoeffTextIndex + "=" + formatPhase6DiagnosticNumber(coefficients[phase6CoeffTextIndex]);
		if (text == "")
			text = coefficientText;
		else
			text = text + "; " + coefficientText;
	}
	return text;
}

function isPhase6FiniteNumber(value) {
	if (isNaN(value))
		return false;
	if (abs(value) > 1e300)
		return false;
	return true;
}

function formatPhase6DiagnosticNumber(value) {
	text = "" + value;
	if (text == "")
		return "";
	if (text == "NA")
		return "NA";
	formattedText = d2s(value, 9);
	while (indexOf(formattedText, ".") >= 0 && endsWith(formattedText, "0"))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (endsWith(formattedText, "."))
		formattedText = substring(formattedText, 0, lengthOf(formattedText) - 1);
	if (outputDecimalSeparator == ",")
		formattedText = replace(formattedText, ".", ",");
	return formattedText;
}

function calculateMedianFromPrefix(values, valueCount) {
	if (valueCount <= 0)
		return "";

	trimmedValues = newArray(valueCount);
	for (medianCopyIndex = 0; medianCopyIndex < valueCount; medianCopyIndex++)
		trimmedValues[medianCopyIndex] = values[medianCopyIndex];
	Array.sort(trimmedValues);
	medianIndex = round((valueCount - 1) / 2);
	return trimmedValues[medianIndex];
}

function findNearestRawIndex(rawTimes, rawCount, targetTime) {
	nearestIndex = 0;
	nearestDistance = abs(rawTimes[0] - targetTime);
	for (rawSearchIndex = 1; rawSearchIndex < rawCount; rawSearchIndex++) {
		currentDistance = abs(rawTimes[rawSearchIndex] - targetTime);
		if (currentDistance < nearestDistance) {
			nearestDistance = currentDistance;
			nearestIndex = rawSearchIndex;
		}
	}
	return nearestIndex;
}

function buildBaselineAnchorsTableText(anchorTimes, anchorValues, anchorCount, sourceXColumn, sourceYColumn) {
	tableText = "Anchor_Index" + outputFieldDelimiter + "Anchor_Time" + outputFieldDelimiter + "Anchor_Value" + outputFieldDelimiter + "Source_X_Column" + outputFieldDelimiter + "Source_Y_Column\n";
	for (anchorTableIndex = 0; anchorTableIndex < anchorCount; anchorTableIndex++) {
		qAnchorIndex = "" + (anchorTableIndex + 1);
		qAnchorTime = formatBaselineAnchorNumber(anchorTimes[anchorTableIndex]);
		qAnchorValue = formatBaselineAnchorNumber(anchorValues[anchorTableIndex]);
		qSourceXColumn = quoteBaselineAnchorText(sourceXColumn);
		qSourceYColumn = quoteBaselineAnchorText(sourceYColumn);

		rowText = "";
		rowText = qAnchorIndex;
		rowText = rowText + outputFieldDelimiter + qAnchorTime;
		rowText = rowText + outputFieldDelimiter + qAnchorValue;
		rowText = rowText + outputFieldDelimiter + qSourceXColumn;
		rowText = rowText + outputFieldDelimiter + qSourceYColumn;
		tableText = tableText + rowText + "\n";
	}
	return tableText;
}

function formatBaselineAnchorNumber(value) {
	text = d2s(value, 9);
	while (indexOf(text, ".") >= 0 && endsWith(text, "0"))
		text = substring(text, 0, lengthOf(text) - 1);
	if (endsWith(text, "."))
		text = substring(text, 0, lengthOf(text) - 1);
	if (outputDecimalSeparator == ",")
		text = replace(text, ".", ",");
	return text;
}

function quoteBaselineAnchorText(value) {
	text = "" + value;
	if (text == "")
		return "";
	text = replace(text, "\"", "\"\"");
	quotedText = "\"" + text + "\"";
	return quotedText;
}

function savePhase3PeakAnalysisTable(tableWindowTitle, savePath) {
	if (!isOpen(tableWindowTitle)) {
		warningText = "Could not save Phase 3 peak-analysis table because window was not open: " + tableWindowTitle;
		return warningText;
	}

	selectWindow(tableWindowTitle);
	tableWindowType = getInfo("window.type");
	if (!startsWith(tableWindowType, "ResultsTable")) {
		warningText = "Could not save Phase 3 peak-analysis table because window was not a ResultsTable: " + tableWindowTitle;
		return warningText;
	}

	tableHeadings = Table.headings;
	tableRows = Table.size;
	if (tableHeadings == "")
		return "Could not save Phase 3 peak-analysis table because it had no readable headings.";
	if (tableRows <= 0)
		return "Could not save Phase 3 peak-analysis table because it had no data rows.";

	phase3PeakAnalysisExportWarning = "";
	tableText = buildPhase3PeakAnalysisTableText(tableHeadings, tableRows);
	if (startsWith(tableText, "PHASE3_TABLE_EXPORT_ERROR:"))
		return tableText;

	File.saveString(tableText, savePath);
	if (File.exists(savePath))
		return phase3PeakAnalysisExportWarning;

	warningText = "Phase 3 peak-analysis table save command completed but file was not found: " + savePath;
	return warningText;
}

function buildPhase3PeakAnalysisTableText(tableHeadings, tableRows) {
	headings = split(tableHeadings, "\t");
	columnCountForExport = lengthOf(headings);
	if (columnCountForExport <= 0)
		return "PHASE3_TABLE_EXPORT_ERROR: no columns were found in the Phase 3 peak-analysis table.";

	includeColumns = newArray(columnCountForExport);
	includedColumnCount = 0;
	for (phase3ExportColumn = 0; phase3ExportColumn < columnCountForExport; phase3ExportColumn++) {
		sourceHeading = headings[phase3ExportColumn];
		trimmedHeading = trimString(sourceHeading);
		if (trimmedHeading == "") {
			blankColumnHasData = false;
			for (phase3ExportRow = 0; phase3ExportRow < tableRows; phase3ExportRow++) {
				cellText = Table.getString(sourceHeading, phase3ExportRow);
				if (cellText != "null" && cellText != "")
					blankColumnHasData = true;

				exportHeading = "Column_" + (phase3ExportColumn + 1);
				fallbackCellText = Table.getString(exportHeading, phase3ExportRow);
				if (fallbackCellText != "null" && fallbackCellText != "")
					blankColumnHasData = true;
			}
			if (blankColumnHasData)
				return "PHASE3_TABLE_EXPORT_ERROR: blank Phase 3 peak-analysis heading contained data and cannot be exported reliably at column " + (phase3ExportColumn + 1);
			includeColumns[phase3ExportColumn] = 0;
			phase3PeakAnalysisExportWarning = appendWarning(phase3PeakAnalysisExportWarning, "Phase3 export skipped blank non-data leading table column.");
		} else {
			includeColumns[phase3ExportColumn] = 1;
			includedColumnCount++;
			for (phase3CompareColumn = 0; phase3CompareColumn < phase3ExportColumn; phase3CompareColumn++) {
				compareHeading = trimString(headings[phase3CompareColumn]);
				if (compareHeading == trimmedHeading)
					return "PHASE3_TABLE_EXPORT_ERROR: duplicate Phase 3 peak-analysis heading cannot be read reliably: " + trimmedHeading;
			}
		}
	}
	if (includedColumnCount <= 0)
		return "PHASE3_TABLE_EXPORT_ERROR: no real Spiky columns were found in the Phase 3 peak-analysis table.";

	columnReadCounts = newArray(columnCountForExport);
	tableText = "";
	headerText = "";
	headerFieldCount = 0;
	for (phase3ExportColumn = 0; phase3ExportColumn < columnCountForExport; phase3ExportColumn++) {
		if (includeColumns[phase3ExportColumn] == 1) {
			sourceHeading = headings[phase3ExportColumn];
			trimmedHeading = trimString(sourceHeading);
			exportHeading = sourceHeading;

			qHeading = quotePhase3PeakAnalysisText(exportHeading);
			if (headerFieldCount == 0)
				headerText = qHeading;
			else
				headerText = headerText + outputFieldDelimiter + qHeading;
			columnReadCounts[phase3ExportColumn] = 0;
			headerFieldCount++;
		}
	}
	tableText = headerText + "\n";

	for (phase3ExportRow = 0; phase3ExportRow < tableRows; phase3ExportRow++) {
		rowText = "";
		rowFieldCount = 0;
		for (phase3ExportColumn = 0; phase3ExportColumn < columnCountForExport; phase3ExportColumn++) {
			if (includeColumns[phase3ExportColumn] == 1) {
				sourceHeading = headings[phase3ExportColumn];
				cellText = Table.getString(sourceHeading, phase3ExportRow);
				if (cellText != "null")
					columnReadCounts[phase3ExportColumn] = columnReadCounts[phase3ExportColumn] + 1;
				qCell = formatPhase3PeakAnalysisCell(cellText);

				if (rowFieldCount == 0)
					rowText = qCell;
				else
					rowText = rowText + outputFieldDelimiter + qCell;
				rowFieldCount++;
			}
		}
		tableText = tableText + rowText + "\n";
	}

	for (phase3ExportColumn = 0; phase3ExportColumn < columnCountForExport; phase3ExportColumn++) {
		if (includeColumns[phase3ExportColumn] == 1) {
			if (columnReadCounts[phase3ExportColumn] == 0) {
				sourceHeading = headings[phase3ExportColumn];
				exportHeading = sourceHeading;
				return "PHASE3_TABLE_EXPORT_ERROR: Phase 3 peak-analysis column could not be read reliably: " + exportHeading;
			}
		}
	}

	return tableText;
}

function formatPhase3PeakAnalysisCell(value) {
	text = "" + value;
	if (text == "")
		return "";
	if (text == "null")
		return "";
	if (isClearlyNumericText(text)) {
		formatted = formatPhase3PeakAnalysisNumericText(text);
		formatted = "" + formatted;
		return formatted;
	}
	quoted = quotePhase3PeakAnalysisText(text);
	quoted = "" + quoted;
	return quoted;
}

function formatPhase3PeakAnalysisNumericText(value) {
	text = trimString(value);
	if (outputDecimalSeparator == ",")
		text = replace(text, ".", ",");
	return text;
}

function quotePhase3PeakAnalysisText(value) {
	text = "" + value;
	if (text == "")
		return "";
	text = replace(text, "\"", "\"\"");
	quotedText = "\"" + text + "\"";
	return quotedText;
}

function isClearlyNumericText(value) {
	text = trimString(value);
	if (text == "")
		return false;

	seenDigit = false;
	seenDot = false;
	for (numericCheckIndex = 0; numericCheckIndex < lengthOf(text); numericCheckIndex++) {
		ch = substring(text, numericCheckIndex, numericCheckIndex + 1);
		if (indexOf("0123456789", ch) >= 0) {
			seenDigit = true;
		} else if (ch == "." && !seenDot) {
			seenDot = true;
		} else if ((ch == "-" || ch == "+") && numericCheckIndex == 0) {
		} else {
			return false;
		}
	}

	return seenDigit;
}

function savePhase4PlotValuesTable(tableWindowTitle, savePath) {
	if (!isOpen(tableWindowTitle)) {
		warningText = "Could not save Phase 4 Plot Values table because window was not open: " + tableWindowTitle;
		return warningText;
	}

	selectWindow(tableWindowTitle);
	tableWindowType = getInfo("window.type");
	if (!startsWith(tableWindowType, "ResultsTable")) {
		warningText = "Could not save Phase 4 Plot Values table because window was not a ResultsTable: " + tableWindowTitle;
		return warningText;
	}

	tableHeadings = Table.headings;
	tableRows = Table.size;
	if (tableHeadings == "")
		return "Could not save Phase 4 Plot Values table because it had no readable headings.";
	if (tableRows <= 0)
		return "Could not save Phase 4 Plot Values table because it had no data rows.";

	phase4PlotValuesExportWarning = "";
	tableText = buildPhase4PlotValuesTableText(tableHeadings, tableRows);
	if (startsWith(tableText, "PHASE4_TABLE_EXPORT_ERROR:"))
		return tableText;

	File.saveString(tableText, savePath);
	if (File.exists(savePath)) {
		if (phase4PlotValuesExportWarning != "")
			phase4PlotValuesWarning = appendWarning(phase4PlotValuesWarning, phase4PlotValuesExportWarning);
		return "";
	}

	warningText = "Phase 4 Plot Values table save command completed but file was not found: " + savePath;
	return warningText;
}

function buildPhase4PlotValuesTableText(tableHeadings, tableRows) {
	headings = split(tableHeadings, "\t");
	columnCountForExport = lengthOf(headings);
	if (columnCountForExport <= 0)
		return "PHASE4_TABLE_EXPORT_ERROR: no columns were found in the Phase 4 Plot Values table.";

	includeColumns = newArray(columnCountForExport);
	includedColumnCount = 0;
	for (phase4ExportColumn = 0; phase4ExportColumn < columnCountForExport; phase4ExportColumn++) {
		sourceHeading = headings[phase4ExportColumn];
		trimmedHeading = trimString(sourceHeading);
		if (trimmedHeading == "") {
			blankColumnHasData = false;
			for (phase4ExportRow = 0; phase4ExportRow < tableRows; phase4ExportRow++) {
				cellText = Table.getString(sourceHeading, phase4ExportRow);
				if (cellText != "null" && cellText != "")
					blankColumnHasData = true;

				exportHeading = "Column_" + (phase4ExportColumn + 1);
				fallbackCellText = Table.getString(exportHeading, phase4ExportRow);
				if (fallbackCellText != "null" && fallbackCellText != "")
					blankColumnHasData = true;
			}
			if (blankColumnHasData)
				return "PHASE4_TABLE_EXPORT_ERROR: blank Phase 4 Plot Values heading contained data and cannot be exported reliably at column " + (phase4ExportColumn + 1);
			includeColumns[phase4ExportColumn] = 0;
			phase4PlotValuesExportWarning = appendWarning(phase4PlotValuesExportWarning, "Phase4 export skipped blank non-data leading table column.");
		} else {
			includeColumns[phase4ExportColumn] = 1;
			includedColumnCount++;
			for (phase4CompareColumn = 0; phase4CompareColumn < phase4ExportColumn; phase4CompareColumn++) {
				compareHeading = trimString(headings[phase4CompareColumn]);
				if (compareHeading == trimmedHeading)
					return "PHASE4_TABLE_EXPORT_ERROR: duplicate Phase 4 Plot Values heading cannot be read reliably: " + trimmedHeading;
			}
		}
	}
	if (includedColumnCount <= 0)
		return "PHASE4_TABLE_EXPORT_ERROR: no real Plot Values columns were found.";

	columnReadCounts = newArray(columnCountForExport);
	tableText = "";
	headerText = "";
	headerFieldCount = 0;
	for (phase4ExportColumn = 0; phase4ExportColumn < columnCountForExport; phase4ExportColumn++) {
		if (includeColumns[phase4ExportColumn] == 1) {
			sourceHeading = headings[phase4ExportColumn];
			qHeading = quotePhase4PlotValuesText(sourceHeading);
			if (headerFieldCount == 0)
				headerText = qHeading;
			else
				headerText = headerText + outputFieldDelimiter + qHeading;
			columnReadCounts[phase4ExportColumn] = 0;
			headerFieldCount++;
		}
	}
	tableText = headerText + "\n";

	for (phase4ExportRow = 0; phase4ExportRow < tableRows; phase4ExportRow++) {
		rowText = "";
		rowFieldCount = 0;
		for (phase4ExportColumn = 0; phase4ExportColumn < columnCountForExport; phase4ExportColumn++) {
			if (includeColumns[phase4ExportColumn] == 1) {
				sourceHeading = headings[phase4ExportColumn];
				cellText = Table.getString(sourceHeading, phase4ExportRow);
				if (cellText != "null")
					columnReadCounts[phase4ExportColumn] = columnReadCounts[phase4ExportColumn] + 1;
				qCell = formatPhase4PlotValuesCell(cellText);

				if (rowFieldCount == 0)
					rowText = qCell;
				else
					rowText = rowText + outputFieldDelimiter + qCell;
				rowFieldCount++;
			}
		}
		tableText = tableText + rowText + "\n";
	}

	for (phase4ExportColumn = 0; phase4ExportColumn < columnCountForExport; phase4ExportColumn++) {
		if (includeColumns[phase4ExportColumn] == 1) {
			if (columnReadCounts[phase4ExportColumn] == 0) {
				sourceHeading = headings[phase4ExportColumn];
				return "PHASE4_TABLE_EXPORT_ERROR: Phase 4 Plot Values column could not be read reliably: " + sourceHeading;
			}
		}
	}

	return tableText;
}

function formatPhase4PlotValuesCell(value) {
	text = "" + value;
	if (text == "")
		return "";
	if (text == "null")
		return "";
	if (isClearlyNumericText(text)) {
		formatted = formatPhase4PlotValuesNumericText(text);
		formatted = "" + formatted;
		return formatted;
	}
	quoted = quotePhase4PlotValuesText(text);
	quoted = "" + quoted;
	return quoted;
}

function formatPhase4PlotValuesNumericText(value) {
	text = trimString(value);
	if (outputDecimalSeparator == ",")
		text = replace(text, ".", ",");
	return text;
}

function quotePhase4PlotValuesText(value) {
	text = "" + value;
	if (text == "")
		return "";
	text = replace(text, "\"", "\"\"");
	quotedText = "\"" + text + "\"";
	return quotedText;
}

function ensureDirectoryExists(folderPath, folderLabel) {
	if (!File.exists(folderPath))
		File.makeDirectory(folderPath);
	if (File.exists(folderPath))
		return "";
	warningText = "Could not create " + folderLabel + ": " + folderPath;
	return warningText;
}

function savePlotWindowAsPng(plotWindowTitle, savePath) {
	if (!isOpen(plotWindowTitle)) {
		warningText = "Could not save detected-peaks plot because window was not open: " + plotWindowTitle;
		return warningText;
	}

	selectWindow(plotWindowTitle);
	saveAs("PNG", savePath);
	if (File.exists(savePath))
		return "";

	warningText = "Detected-peaks plot save command completed but file was not found: " + savePath;
	return warningText;
}

function savePhase2RawPlotAsPngPreserveWindow(plotWindowTitle, savePath) {
	if (!isOpen(plotWindowTitle))
		return "Could not save raw trace plot because processing window was not open: " + plotWindowTitle;

	selectWindow(plotWindowTitle);
	saveAs("PNG", savePath);
	if (!isOpen(plotWindowTitle)) {
		currentTitle = getTitle();
		if (currentTitle != "" && startsWith(getInfo("window.type"), "Plot"))
			rename(plotWindowTitle);
	}
	if (!isOpen(plotWindowTitle))
		return "Raw trace plot was saved, but the processing window title was not preserved: " + plotWindowTitle;
	if (File.exists(savePath))
		return "";
	return "Raw trace plot save command completed but file was not found: " + savePath;
}

function saveResultsTableAsCsv(tableWindowTitle, savePath) {
	if (!isOpen(tableWindowTitle)) {
		warningText = "Could not save peak-analysis table because window was not open: " + tableWindowTitle;
		return warningText;
	}

	selectWindow(tableWindowTitle);
	saveAs("Results", savePath);
	if (File.exists(savePath))
		return "";

	warningText = "Peak-analysis table save command completed but file was not found: " + savePath;
	return warningText;
}

function writeAnalysisSettings(path) {
	text = "";
	text = text + "Spiky Batch Baseline Correction\n";
	text = text + "Macro_Version: " + macroVersion + "\n";
	text = text + "Phase: " + phaseDescription + "\n";
	text = text + "Run_Timestamp: " + timestamp + "\n";
	text = text + "Run_Mode: " + runMode + "\n";
	text = text + "Non_Interactive_Validation_Mode: " + validationModeUsed + "\n";
	text = text + "Non_Interactive_Validation_Input_CSV: " + validationInputCsvPath + "\n";
	text = text + "Non_Interactive_Validation_Argument_Summary: " + validationArgumentSummary + "\n";
	text = text + "Run_Keyword: " + runKeyword + "\n";
	text = text + "Change_Keyword: " + changeKeyword + "\n";
	text = text + "Output_Table_Format: " + outputTableFormat + "\n";
	text = text + "Output_Field_Delimiter: " + outputFieldDelimiterLabel + "\n";
	text = text + "Output_Decimal_Separator: " + outputDecimalSeparator + "\n";
	text = text + "Output_Table_Extension: " + outputTableExtension + "\n";
	text = text + "Output_Thousands_Separators: " + outputThousandsSeparators + "\n";
	text = text + "Current_Phase: " + currentPhaseTag + "\n";
	text = text + "Last_Output_Location_Prefs_Key: " + lastOutputLocationPrefsKey + "\n";
	text = text + "ImageJ_Version: " + imageJVersion + "\n";
	text = text + "Input_Table_Selection: " + inputTableSelectionStatus + "\n";
	text = text + "Active_Table_Title: " + activeTableTitle + "\n";
	text = text + "Input_Source_File_Stem: " + inputSourceFileStem + "\n";
	text = text + "Source_Aware_Aggregate_Filename_Pattern: <InputFileStem>_<OutputType>.<extension>\n";
	text = text + "Active_Window_Type: " + activeWindowType + "\n";
	text = text + "Time_Column_Name: " + timeColumnName + "\n";
	text = text + "Row_Count: " + rowCount + "\n";
	text = text + "Column_Count: " + columnCount + "\n";
	text = text + "Sample_Count: " + sampleCount + "\n";
	text = text + "Full_Batch_Maximum_Samples_To_Process: " + fullBatchMaxSamplesToProcess + "\n";
	text = text + "Full_Batch_Planned_Sample_Count_Phase14: " + fullBatchPlannedSampleCount + "\n";
	text = text + "Full_Batch_Processed_Sample_Count_Phase14: " + fullBatchProcessedSampleCount + "\n";
	text = text + "Full_Batch_Phase15A_Status: Continue-after-failure enabled for recoverable per-sample failures when cleanup verifies next-sample isolation; role-based aggregation scaffold created\n";
	text = text + "Timing_Run_Elapsed_ms_At_Settings_Write: " + floor(getTime() - runStartTimeMs) + "\n";
	text = text + "Timing_Full_Batch_Sample_Loop_Elapsed_ms: " + fullBatchSampleLoopElapsedMs + "\n";
	text = text + "Timing_Full_Batch_Aggregation_Elapsed_ms: " + fullBatchAggregationElapsedMs + "\n";
	text = text + "Timing_Phase16_Overview_Elapsed_ms: " + phase16OverviewElapsedMs + "\n";
	text = text + "Timing_Phase16_Workbook_Elapsed_ms: " + phase16WorkbookElapsedMs + "\n";
	text = text + "NonInteractive_Max_Observed_Open_Window_Count: " + maxObservedOpenWindowCount + "\n";
	text = text + "Full_Batch_Progress_Feedback: sample name/count, safe failure continuation, overview assembly, workbook generation, and completion output path\n";
	text = text + "Data_Output_Location: " + outputParent + "\n";
	text = text + "Output_Folder: " + outputFolder + "\n";
	text = text + "Data_Folder: " + dataFolder + "\n";
	text = text + "Plots_Folder: " + plotsFolder + "\n";
	text = text + "Phase15A_Aggregation_Status: " + phase15MasterTablesStatus + "\n";
	text = text + "Phase15A_Aggregation_Note: Role-based aggregation scaffold for current and future data outputs; this is not a change to analysis math and does not implement future baseline or photobleaching methods\n";
	text = text + "Phase15A_Output_Format: " + outputTableFormat + "\n";
	text = text + "Phase15A_Sample_Summary_QC_Path: " + phase15SampleSummaryPath + "\n";
	text = text + "Phase15A_Final_Peak_Master_Path: " + phase15FinalPeakMasterPath + "\n";
	text = text + "Phase15A_TimeSeries_Master_Path: " + phase15TimeSeriesMasterPath + "\n";
	text = text + "Phase15A_Baseline_Correction_Master_Path: " + phase15BaselineCorrectionMasterPath + "\n";
	text = text + "Phase15A_Processing_Steps_Master_Path: " + phase15ProcessingStepsMasterPath + "\n";
	text = text + "Phase16A_Output_Polish_Status: " + phase16ExportStatus + "\n";
	text = text + "Phase16A_Final_Peak_Overview_Path: " + phase16OverviewPlotPath + "\n";
	text = text + "Phase16A_Master_Results_Workbook_Path: " + phase16MasterWorkbookPath + "\n";
	text = text + "Phase16A_Master_Results_Workbook_Format: Excel 2003 XML Spreadsheet (.xml), Excel-compatible multi-sheet workbook\n";
	text = text + "Executed_Batch_Macro_Source_Path: " + batchMacroSourcePath + "\n";
	text = text + "Executed_Batch_Macro_SHA256_Expected: " + batchMacroExpectedSha256 + "\n";
	text = text + "Macro_Copy_Status: " + macroCopyStatus + "\n";
	text = text + "Phase2_Source_Sample: " + phase2SourceSample + "\n";
	text = text + "Phase2_Plot_Name: " + phase2PlotName + "\n";
	text = text + "Phase2_X_Axis_Label: " + phase2XAxisLabel + "\n";
	text = text + "Phase2_Y_Axis_Label: " + phase2YAxisLabel + "\n";
	text = text + "Spiky_Raw_Source_Plot_Y_Axis_Label: " + phase2YAxisLabel + "\n";
	text = text + "Spiky_Corrected_Source_Plot_Y_Axis_Label: DeltaF/F0\n";
	text = text + "Phase3_Raw_Plot_Name: " + phase3RawPlotName + "\n";
	text = text + "Spiky_Peak_Orientation_Selected: " + spikyPeakOrientation + "\n";
	text = text + "Spiky_Command_Strategy: Option C direct modified Spiky.ijm file execution\n";
	text = text + "Spiky_Direct_Macro_Path: " + spikyMacroPath + "\n";
	text = text + "Spiky_Direct_Argument_Template: SPIKY.Batch.PeakAnalysisOrientation=<Auto|Negative|Positive>;SPIKY.Batch.SourceWindow=<plot title>\n";
	text = text + "Spiky_Peak_Orientation_Application: Same selected orientation is applied to first/raw and second/DeltaF/F0 Spiky runs by executing the selected modified Spiky.ijm file directly after selecting the exact source plot. During direct batch execution, Spiky accepts the active source plot's non-empty Y-axis label without requiring a unit.\n";
	text = text + "First_Spiky_Tolerance_Percent_Selected: " + firstSpikyTolerancePercent + "\n";
	text = text + "First_Spiky_Smoothing_Selected: " + firstSpikySmoothing + "\n";
	text = text + "Second_Spiky_Tolerance_Percent_Selected: " + secondSpikyTolerancePercent + "\n";
	text = text + "Second_Spiky_Smoothing_Selected: " + secondSpikySmoothing + "\n";
	text = text + "Return_To_Main_Menu_After_Run: " + returnToMainMenuAfterRun + "\n";
	text = text + "Phase3_Spiky_Command: " + phase3SpikyCommand + "\n";
	text = text + "Phase3_Spiky_Was_Called: " + phase3SpikyWasCalled + "\n";
	text = text + "Phase3_Existing_Results_Backup: " + phase3ExistingResultsBackupName + "\n";
	text = text + "Phase3_Detected_Peaks_Plot: " + phase3SpikyDetectedPeaksPlotName + "\n";
	text = text + "Phase3_Peak_Analysis_Table: " + phase3SpikyPeakAnalysisTableName + "\n";
	text = text + "Phase3_Spiky_Status: " + phase3SpikyStatus + "\n";
	text = text + "Phase3_Open_Windows_After_Spiky: " + phase3OpenWindowsAfterSpiky + "\n";
	text = text + "Phase3_Detected_Peaks_Save_Path: " + phase3DetectedPeaksPlotSavePath + "\n";
	text = text + "Phase3_Peak_Analysis_Save_Path: " + phase3PeakAnalysisTableSavePath + "\n";
	text = text + "Phase3_Output_Save_Status: " + phase3OutputSaveStatus + "\n";
	text = text + "Phase3_FirstSpiky_Fallback_Used: " + phase3FirstSpikyFallbackUsed + "\n";
	text = text + "Phase3_FirstSpiky_Fallback_Initial_Tolerance: " + phase3FirstSpikyFallbackInitialTolerance + "\n";
	text = text + "Phase3_FirstSpiky_Fallback_Final_Tolerance: " + phase3FirstSpikyFallbackFinalTolerance + "\n";
	text = text + "Phase3_FirstSpiky_Fallback_Failed_Attempts: " + phase3FirstSpikyFallbackFailedAttempts + "\n";
	text = text + "Phase3_FirstSpiky_Fallback_Reason: " + phase3FirstSpikyFallbackReason + "\n";
	text = text + "Phase3_FirstSpiky_Passed_Only_After_Fallback: " + phase3FirstSpikyFallbackPassedAfterFallback + "\n";
	text = text + "Phase4_PlotValues_Status: " + phase4PlotValuesStatus + "\n";
	text = text + "Phase4_PlotValues_Table_Name: " + phase4PlotValuesTableName + "\n";
	text = text + "Phase4_PlotValues_Save_Path: " + phase4PlotValuesSavePath + "\n";
	text = text + "Phase4_PlotValues_Column_Count: " + phase4PlotValuesColumnCount + "\n";
	text = text + "Phase4_PlotValues_Column_Headings: " + phase4PlotValuesColumnHeadings + "\n";
	text = text + "Phase4_Open_Windows_Before_PlotValues: " + phase4PlotValuesOpenWindowsBefore + "\n";
	text = text + "Phase4_Open_Windows_After_PlotValues: " + phase4PlotValuesOpenWindowsAfter + "\n";
	text = text + "Phase4_Existing_Results_Backup: " + phase4ExistingResultsBackupName + "\n";
	text = text + "Phase4_Existing_PlotValues_Backup: " + phase4ExistingPlotValuesBackupName + "\n";
	text = text + "Phase4_Warning: " + phase4PlotValuesWarning + "\n";
	text = text + "Phase4_Error: " + phase4PlotValuesError + "\n";
	text = text + "Phase5_Validation_Status: " + phase5ValidationStatus + "\n";
	text = text + "Phase5_Source_PlotValues_Table: " + phase5PlotValuesSourceTableName + "\n";
	text = text + "Phase5_Predicted_X_Column: " + phase5PredictedXColumn + "\n";
	text = text + "Phase5_Predicted_Y_Column: " + phase5PredictedYColumn + "\n";
	text = text + "Phase5_Prediction_Reason: " + phase5PredictionReason + "\n";
	text = text + "Phase5_Anchor_Count: " + phase5AnchorCount + "\n";
	text = text + "Phase5_BaselineAnchors_Save_Path: " + phase5BaselineAnchorsSavePath + "\n";
	text = text + "Phase5_Validation_Window_Mode: " + phase5ValidationWindowMode + "\n";
	text = text + "Phase5_Local_Baseline_Window_Points: " + phase5LocalBaselineWindowPoints + "\n";
	text = text + "Phase5_Peak_Exclusion_Window_Points: " + phase5PeakExclusionWindowPoints + "\n";
	text = text + "Phase5_Median_Time_Step: " + phase5MedianTimeStep + "\n";
	text = text + "Phase5_Local_Baseline_Window_TimeUnits: " + phase5LocalBaselineWindowTimeUnits + "\n";
	text = text + "Phase5_Peak_Exclusion_Window_TimeUnits: " + phase5PeakExclusionWindowTimeUnits + "\n";
	text = text + "Phase5_Local_Baseline_Tolerance_Percent: " + phase5LocalBaselineTolerancePercent + "\n";
	text = text + "Phase5_Peak_Separation_Percent: " + phase5PeakSeparationPercent + "\n";
	text = text + "Phase5_Raw_X_Min: " + phase5RawXMin + "\n";
	text = text + "Phase5_Raw_X_Max: " + phase5RawXMax + "\n";
	text = text + "Phase5_Raw_Y_Min: " + phase5RawYMin + "\n";
	text = text + "Phase5_Raw_Y_Max: " + phase5RawYMax + "\n";
	text = text + "Phase5_Raw_Y_Range: " + phase5RawYRange + "\n";
	text = text + "Phase5_Anchor_Y_Min: " + phase5AnchorYMin + "\n";
	text = text + "Phase5_Anchor_Y_Max: " + phase5AnchorYMax + "\n";
	text = text + "Phase5_Peak_Marker_X_Column: " + phase5PeakMarkerColumnX + "\n";
	text = text + "Phase5_Peak_Marker_Y_Column: " + phase5PeakMarkerColumnY + "\n";
	text = text + "Phase5_Candidate_XY_Diagnostics: " + phase5CandidateDiagnostics + "\n";
	text = text + "Phase5_Warning: " + phase5ValidationWarning + "\n";
	text = text + "Phase5_Error: " + phase5ValidationError + "\n";
	text = text + "Phase6_Baseline_Model: " + baselineCurveMethod + "\n";
	text = text + "Phase6_Polynomial_Degree_Selected: " + selectedPolynomialDegree + "\n";
	text = text + "Phase6_Supported_Degrees: " + phase6SupportedDegrees + "\n";
	text = text + "Phase6_Fit_Status: " + phase6FitStatus + "\n";
	text = text + "Phase6_Polynomial_Degree_Used: " + phase6PolynomialDegreeUsed + "\n";
	text = text + "Phase6_Polynomial_Degree_First_Attempted: " + phase6PolynomialDegreeFirstAttempted + "\n";
	text = text + "Phase6_Polynomial_Fallback_Used: " + phase6PolynomialFallbackUsed + "\n";
	text = text + "Phase6_Polynomial_Fallback_Reason: " + phase6PolynomialFallbackReason + "\n";
	text = text + "Phase6_Fit_Function: " + phase6FitFunction + "\n";
	text = text + "Phase6_Fitting_Method: ImageJ macro Fit.doFit(fitFunction, fitAnchorTimes, fitAnchorValues) on exact-length validated Phase 5 anchor arrays only\n";
	text = text + "Phase6_Full_Length_Source_Arrays_Passed_To_Fit: No\n";
	text = text + "Phase6_Coefficient_Source: ImageJ macro Fit.p(n) after Fit.doFit\n";
	text = text + "Phase6_Coefficient_Order: " + phase6CoefficientOrder + "\n";
	text = text + "Phase6_Coefficient_Count: " + phase6CoefficientCount + "\n";
	text = text + "Phase6_Coefficients: " + phase6CoefficientsText + "\n";
	text = text + "Phase6_Anchor_Count: " + phase6AnchorCount + "\n";
	text = text + "Phase6_Source_Anchor_Array_Length: " + phase6SourceAnchorArrayLength + "\n";
	text = text + "Phase6_Fit_Input_Anchor_Count: " + phase6FitInputAnchorCount + "\n";
	text = text + "Phase6_Unused_Source_Anchor_Entries: " + phase6UnusedSourceAnchorEntries + "\n";
	text = text + "Phase6_Fit_Input_Array_Status: " + phase6FitInputArrayStatus + "\n";
	text = text + "Phase6_Fit_Input_First_Time: " + formatPhase6DiagnosticNumber(phase6FitInputFirstTime) + "\n";
	text = text + "Phase6_Fit_Input_Last_Time: " + formatPhase6DiagnosticNumber(phase6FitInputLastTime) + "\n";
	text = text + "Phase6_Fit_Input_First_Value: " + formatPhase6DiagnosticNumber(phase6FitInputFirstValue) + "\n";
	text = text + "Phase6_Fit_Input_Last_Value: " + formatPhase6DiagnosticNumber(phase6FitInputLastValue) + "\n";
	text = text + "Phase6_Anchor_Residual_RMSE: " + formatPhase6DiagnosticNumber(phase6AnchorResidualRMSE) + "\n";
	text = text + "Phase6_Anchor_Residual_MaxAbs: " + formatPhase6DiagnosticNumber(phase6AnchorResidualMaxAbs) + "\n";
	text = text + "Phase6_Anchor_Residual_MaxPercentAbs: " + formatPhase6DiagnosticNumber(phase6AnchorResidualMaxPercentAbs) + "\n";
	text = text + "Phase6_Anchor_Residual_Warn_Percent: " + phase6AnchorResidualWarnPercent + "\n";
	text = text + "Phase6_Anchor_Residual_Fail_Percent: " + phase6AnchorResidualFailPercent + "\n";
	text = text + "Phase6_Raw_Time_Min: " + formatPhase6DiagnosticNumber(phase6RawTimeMin) + "\n";
	text = text + "Phase6_Raw_Time_Max: " + formatPhase6DiagnosticNumber(phase6RawTimeMax) + "\n";
	text = text + "Phase6_Anchor_Time_Min: " + formatPhase6DiagnosticNumber(phase6AnchorTimeMin) + "\n";
	text = text + "Phase6_Anchor_Time_Max: " + formatPhase6DiagnosticNumber(phase6AnchorTimeMax) + "\n";
	text = text + "Phase6_Anchor_Time_Coverage_Percent: " + formatPhase6DiagnosticNumber(phase6AnchorTimeCoveragePercent) + "\n";
	text = text + "Phase6_Anchor_Spread_Status: " + phase6AnchorSpreadStatus + "\n";
	text = text + "Phase6_Raw_Rows_Before_First_Anchor: " + phase6RawRowsBeforeFirstAnchor + "\n";
	text = text + "Phase6_Raw_Rows_After_Last_Anchor: " + phase6RawRowsAfterLastAnchor + "\n";
	text = text + "Phase6_Raw_Percent_Outside_Anchor_Support: " + formatPhase6DiagnosticNumber(phase6RawPercentOutsideAnchorSupport) + "\n";
	text = text + "Phase6_First_Fitted_Baseline: " + formatPhase6DiagnosticNumber(phase6FirstFittedBaseline) + "\n";
	text = text + "Phase6_Last_Fitted_Baseline: " + formatPhase6DiagnosticNumber(phase6LastFittedBaseline) + "\n";
	text = text + "Phase6_Fit_Reasonableness_Status: " + phase6FitReasonablenessStatus + "\n";
	text = text + "Phase6_Fit_Reasonableness_Error: " + phase6FitReasonablenessError + "\n";
	text = text + "Phase6_Fit_Reasonableness_Warning: " + phase6FitReasonablenessWarning + "\n";
	text = text + "Phase6_Baseline_Range_Warning: " + phase6BaselineRangeWarning + "\n";
	text = text + "Phase6_Baseline_Endpoint_Warning: " + phase6BaselineEndpointWarning + "\n";
	text = text + "Phase6_Baseline_Negative_Correction_Warning: " + phase6BaselineNegativeCorrectionWarning + "\n";
	text = text + "Phase6_Baseline_Curvature_Warning: " + phase6BaselineCurvatureWarning + "\n";
	text = text + "Phase6_Peak_Aware_Anchor_Timing_Warning: " + phase6PeakAwareAnchorTimingWarning + "\n";
	text = text + "Phase6_Baseline_Reliability_Class: " + phase6BaselineReliabilityClass + "\n";
	text = text + "Phase6_Baseline_Reliability_Reason: " + phase6BaselineReliabilityReason + "\n";
	text = text + "Phase6_Endpoint_Handling: Not implemented; extrapolated regions are detected and logged without capping or flattening\n";
	text = text + "Phase6_Diagnostic_Table_Save_Status: " + phase6DiagnosticTableSaveStatus + "\n";
	text = text + "Phase6_Diagnostic_Table_Save_Path: " + phase6DiagnosticTableSavePath + "\n";
	text = text + "Phase6_Baseline_Value_Count_InternalOnly: " + phase6BaselineValueCount + "\n";
	text = text + "Phase6_Fit_RMSE: " + formatPhase6DiagnosticNumber(phase6FitRMSE) + "\n";
	text = text + "Phase6_Fit_R2: " + formatPhase6DiagnosticNumber(phase6FitRSquared) + "\n";
	text = text + "Phase6_Fitted_Baseline_Min: " + formatPhase6DiagnosticNumber(phase6FittedBaselineMin) + "\n";
	text = text + "Phase6_Fitted_Baseline_Mean: " + formatPhase6DiagnosticNumber(phase6FittedBaselineMean) + "\n";
	text = text + "Phase6_Fitted_Baseline_Max: " + formatPhase6DiagnosticNumber(phase6FittedBaselineMax) + "\n";
	text = text + "Phase6_Warning: " + phase6FitWarning + "\n";
	text = text + "Phase6_Error: " + phase6FitError + "\n";
	text = text + "Phase7_Calculation_Status: " + phase7CalculationStatus + "\n";
	text = text + "Phase7_Method: Row-wise internal calculation using rawValues[i] and Phase 6 fitted baseline values at the same original raw timepoint\n";
	text = text + "Phase7_F0_Definition: F0[i] = Baseline[i] = phase6BaselineValues[i]\n";
	text = text + "Phase7_Source_Baseline_Array: phase6BaselineValues generated by Phase 6\n";
	text = text + "Phase7_Raw_Value_Count: " + phase7RawValueCount + "\n";
	text = text + "Phase7_Baseline_Value_Count: " + phase7BaselineValueCount + "\n";
	text = text + "Phase7_DeltaF_Value_Count: " + phase7DeltaFValueCount + "\n";
	text = text + "Phase7_DeltaF_Over_F0_Value_Count: " + phase7DeltaFOverF0ValueCount + "\n";
	text = text + "Phase7_DeltaF_Over_F0_Percent_Value_Count: " + phase7DeltaFOverF0PercentValueCount + "\n";
	text = text + "Phase7_Raw_Baseline_Alignment_Status: " + phase7RawBaselineAlignmentStatus + "\n";
	text = text + "Phase7_Min_DeltaF: " + formatPhase7DiagnosticNumber(phase7MinDeltaF) + "\n";
	text = text + "Phase7_Mean_DeltaF: " + formatPhase7DiagnosticNumber(phase7MeanDeltaF) + "\n";
	text = text + "Phase7_Max_DeltaF: " + formatPhase7DiagnosticNumber(phase7MaxDeltaF) + "\n";
	text = text + "Phase7_Min_DeltaF_Over_F0: " + formatPhase7DiagnosticNumber(phase7MinDeltaFOverF0) + "\n";
	text = text + "Phase7_Mean_DeltaF_Over_F0: " + formatPhase7DiagnosticNumber(phase7MeanDeltaFOverF0) + "\n";
	text = text + "Phase7_Max_DeltaF_Over_F0: " + formatPhase7DiagnosticNumber(phase7MaxDeltaFOverF0) + "\n";
	text = text + "Phase7_Min_DeltaF_Over_F0_Percent: " + formatPhase7DiagnosticNumber(phase7MinDeltaFOverF0Percent) + "\n";
	text = text + "Phase7_Mean_DeltaF_Over_F0_Percent: " + formatPhase7DiagnosticNumber(phase7MeanDeltaFOverF0Percent) + "\n";
	text = text + "Phase7_Max_DeltaF_Over_F0_Percent: " + formatPhase7DiagnosticNumber(phase7MaxDeltaFOverF0Percent) + "\n";
	text = text + "Phase7_Invalid_Baseline_Value_Count: " + phase7InvalidBaselineValueCount + "\n";
	text = text + "Phase7_Invalid_Corrected_Value_Count: " + phase7InvalidCorrectedValueCount + "\n";
	text = text + "Phase7_First_Invalid_Row: " + phase7FirstInvalidRow + "\n";
	text = text + "Phase7_First_Invalid_Reason: " + phase7FirstInvalidReason + "\n";
	text = text + "Phase7_Minimum_Safe_Baseline_Abs: " + formatPhase7DiagnosticNumber(phase7MinimumSafeBaselineAbs) + "\n";
	text = text + "Phase7_Corrected_Trace_Table_Save_Status: " + phase7CorrectedTraceTableSaveStatus + "\n";
	text = text + "Phase7_Corrected_Trace_Table_Save_Path: " + phase7CorrectedTraceTableSavePath + "\n";
	text = text + "Phase7_Output_File_Status: Per-sample corrected trace diagnostic table only; Corrected_Traces_All_Samples.csv is not created in Phase 14\n";
	text = text + "Phase7_Warning: " + phase7Warning + "\n";
	text = text + "Phase7_Error: " + phase7Error + "\n";
	text = text + "Phase8_Baseline_Reconstruction_Plot_Status: " + phase8PlotStatus + "\n";
	text = text + "Phase8_Baseline_Reconstruction_Plot_Window: " + phase8PlotWindowName + "\n";
	text = text + "Phase8_Baseline_Reconstruction_Plot_Save_Path: " + phase8PlotSavePath + "\n";
	text = text + "Phase8_Baseline_Reconstruction_Plot_Method: QC plot using raw trace, exact-length validated Phase 6 fit anchors, and repaired Phase 6 fitted baseline values at original raw timepoints\n";
	text = text + "Phase8_Source_Raw_Arrays: phase5RawTimes / phase5RawValues\n";
	text = text + "Phase8_Source_Anchor_Arrays: phase6FitAnchorTimes / phase6FitAnchorValues exact-length validated fit input arrays only\n";
	text = text + "Phase8_Source_Baseline_Array: phase6BaselineValues generated by repaired Phase 6\n";
	text = text + "Phase8_Time_Axis_Policy: original raw timepoints only; no generated axis, resampling, or rounded plotting times\n";
	text = text + "Phase8_Endpoint_Annotation_Threshold_Percent: " + phase8EndpointAnnotationThresholdPercent + "\n";
	text = text + "Phase8_First_Raw_Time: " + phase8FirstRawTime + "\n";
	text = text + "Phase8_First_Anchor_Time: " + phase8FirstAnchorTime + "\n";
	text = text + "Phase8_Rows_Before_First_Anchor: " + phase6RawRowsBeforeFirstAnchor + "\n";
	text = text + "Phase8_Percent_Outside_Anchor_Support: " + formatPhase6DiagnosticNumber(phase6RawPercentOutsideAnchorSupport) + "\n";
	text = text + "Phase8_In_Plot_Warning_Status: " + phase8InPlotWarningStatus + "\n";
	text = text + "Phase8_In_Plot_Warning_Text: " + phase8InPlotWarningText + "\n";
	text = text + "Phase8_Endpoint_Handling: Warning-only; no capping, flattening, boundary anchors, time normalization, or endpoint correction applied\n";
	text = text + "Phase8_QC_Status: Plot is QC evidence only and visual inspection is not automated validation\n";
	text = text + "Phase8_Warning: " + phase8PlotWarning + "\n";
	text = text + "Phase8_Error: " + phase8PlotError + "\n";
	text = text + "Phase9_SecondSpiky_Status: " + phase9SecondSpikyStatus + "\n";
	text = text + "Phase9_Method: Second Spiky analysis on corrected DeltaF/F0 plot after successful Phase 8 QC plot save\n";
	text = text + "Phase9_Corrected_Input_Plot_Name: " + phase9CorrectedInputPlotName + "\n";
	text = text + "Phase9_Corrected_Input_X_Source: phase5RawTimes original raw timepoints, preserving original row order\n";
	text = text + "Phase9_Corrected_Input_Y_Source: phase7DeltaFOverF0Values validated Phase 7 DeltaF/F0 values\n";
	text = text + "Phase9_Corrected_Input_X_Axis_Label: " + phase2XAxisLabel + "\n";
	text = text + "Phase9_Corrected_Input_Y_Axis_Label: DeltaF/F0\n";
	text = text + "Phase9_Corrected_Input_Value_Count: " + phase9CorrectedInputValueCount + "\n";
	text = text + "Phase9_Corrected_Input_Y_Min: " + formatPhase7DiagnosticNumber(phase9CorrectedInputYMin) + "\n";
	text = text + "Phase9_Corrected_Input_Y_Max: " + formatPhase7DiagnosticNumber(phase9CorrectedInputYMax) + "\n";
	text = text + "Phase9_SecondSpiky_Was_Called: " + phase9SecondSpikyWasCalled + "\n";
	text = text + "Phase9_Existing_Results_Backup: " + phase9ExistingResultsBackupName + "\n";
	text = text + "Phase9_SecondSpiky_DetectedPeaks_Plot_Name: " + phase9SecondSpikyDetectedPeaksPlotName + "\n";
	text = text + "Phase9_SecondSpiky_PeakAnalysis_Table_Name: " + phase9SecondSpikyPeakAnalysisTableName + "\n";
	text = text + "Phase9_Open_Windows_After_Spiky: " + phase9OpenWindowsAfterSpiky + "\n";
	text = text + "Phase9_Output_File_Status: Live second-Spiky windows captured for Phase 10 export; Phase 15A master aggregation is role-based and Corrected_Traces_All_Samples.csv is not created\n";
	text = text + "Phase9_Full_Batch_Status: Phase 15A continues after recoverable per-sample failures when cleanup is safe\n";
	phase9SettingsWarning = appendWarning(phase9CorrectedInputWarning, phase9SecondSpikyWarning);
	phase9SettingsError = appendWarning(phase9CorrectedInputError, phase9SecondSpikyError);
	text = text + "Phase9_Warning: " + phase9SettingsWarning + "\n";
	text = text + "Phase9_Error: " + phase9SettingsError + "\n";
	text = text + "Phase10_Final_Output_Status: " + phase10FinalOutputStatus + "\n";
	text = text + "Phase10_Method: Export final second-Spiky peak metrics and save final second-Spiky detected-peaks plot per processed sample\n";
	text = text + "Phase10_Final_Peak_Metrics_Source: DeltaF/F0 second-Spiky analysis\n";
	text = text + "Phase10_Final_Peak_Table_Source_Name: " + phase10FinalPeakTableSourceName + "\n";
	text = text + "Phase10_Final_Peak_Table_Save_Path: " + phase10FinalPeakTableSavePath + "\n";
	text = text + "Phase10_Final_Peak_Table_Row_Count: " + phase10FinalPeakTableRowCount + "\n";
	text = text + "Phase10_Final_Peak_Table_Column_Count: " + phase10FinalPeakTableColumnCount + "\n";
	text = text + "Phase10_Final_Peak_Plot_Source_Name: " + phase10FinalPeakPlotSourceName + "\n";
	text = text + "Phase10_Final_Peak_Plot_Save_Path: " + phase10FinalPeakPlotSavePath + "\n";
	text = text + "Phase10_Final_All_Samples_Corrected_Trace_Export_Status: Not implemented in Phase 15A\n";
	text = text + "Phase10_Full_Batch_Status: Per-sample final peak CSVs are created in Full Batch; Phase 15A Final_Peak_Master is additive and role-based\n";
	text = text + "Phase10_Warning: " + phase10FinalOutputWarning + "\n";
	text = text + "Phase10_Error: " + phase10FinalOutputError + "\n";
	text = text + "Phase11_Window_Cleanup_Status: " + phase11WindowCleanupStatus + "\n";
	text = text + "Phase11_Method: Conservative cleanup of exact-name macro-created intermediate windows after successful per-sample output verification\n";
	text = text + "Phase11_Windows_Closed: " + phase11WindowCleanupClosedWindows + "\n";
	text = text + "Phase11_Windows_Kept_Open: " + phase11WindowCleanupKeptOpen + "\n";
	text = text + "Phase11_Window_Minimization_Status: No scientific output windows were added; larger direct-export refactors deferred until separately approved\n";
	text = text + "Phase11_Spiky_Peak_Orientation_Automation_Status: Direct modified Spiky.ijm execution with source-window argument and source-plot Y-axis label acceptance; manual Spiky dialog behavior unchanged\n";
	text = text + "Phase11_Full_Batch_Status: Phase 14 closes per-sample windows between Full Batch samples and stops only on critical cleanup contamination risk\n";
	text = text + "Phase11_Warning: " + phase11WindowCleanupWarning + "\n";
	text = text + "Phase3_Peak_Direction_Source: " + phase3PeakDirectionSource + "\n";
	text = text + "Phase3_Peak_Direction_Final: " + phase3PeakDirectionFinal + "\n";
	text = text + "\n";
	text = text + "Phase3_Spiky_Settings_Actually_Applied_Or_Read:\n";
	text = text + "Spiky_Show_Detected_Peak_Plot: " + phase3PrefShowDetectedPeakPlot + "\n";
	text = text + "Spiky_Show_Peak_Results_Table: " + phase3PrefShowPeakResultsTable + "\n";
	text = text + "Spiky_Show_Baseline: " + phase3PrefShowBaseline + "\n";
	text = text + "Spiky_Show_Threshold: " + phase3PrefShowThreshold + "\n";
	text = text + "Spiky_Synchro_Detection: " + phase3PrefSynchroDetection + "\n";
	text = text + "Spiky_Derivative_Output: " + phase3PrefDerivativeOutput + "\n";
	text = text + "Spiky_Slope_Output: " + phase3PrefSlopeOutput + "\n";
	text = text + "Spiky_Slope_Display: " + phase3PrefSlopeDisplay + "\n";
	text = text + "Spiky_Peak_Area_Output: " + phase3PrefPeakAreaOutput + "\n";
	text = text + "Spiky_Decay_Fitting: " + phase3PrefDecayFitting + "\n";
	text = text + "Spiky_Summary_Output: " + phase3PrefSummaryOutput + "\n";
	text = text + "Spiky_AutoDetect_Mode: " + phase3PrefAutoDetectMode + "\n";
	text = text + "Spiky_Tolerance_Percent: " + phase3PrefTolerancePercent + "\n";
	text = text + "Spiky_Smoothing: " + phase3PrefSmoothing + "\n";
	text = text + "Spiky_Threshold_Start_Percent: " + phase3PrefThresholdStartPercent + "\n";
	text = text + "Spiky_Full_Width_Output: " + phase3PrefFullWidthOutput + "\n";
	text = text + "Spiky_Half_Width_Output: " + phase3PrefHalfWidthOutput + "\n";
	text = text + "Spiky_Full_Width_Percent_1: " + phase3PrefFullWidthPercent1 + "\n";
	text = text + "Spiky_Full_Width_Percent_2: " + phase3PrefFullWidthPercent2 + "\n";
	text = text + "Run_Completion_Status: " + runCompletionStatus + "\n";
	text = text + "Run_Warning_Or_Stop_Reason: " + phaseWarning + "\n";
	text = text + "Run_Error_Reason: " + phaseError + "\n";
	text = text + "\n";
	text = text + "Phase_1_2_3_4_5_6_7_8_9_10_11_Limitations:\n";
	if (phase3SpikyWasCalled != "Yes")
		text = text + "- No Spiky execution was performed.\n";
	else
		text = text + "- First Spiky was run on the raw first-sample plot.\n";
	if (phase4PlotValuesStatus == "Phase4_PlotValues_Exported")
		text = text + "- Full Plot Values were exported for traceability only.\n";
	if (phase5ValidationStatus == "Phase5_Baseline_Anchors_Validated")
		text = text + "- Baseline anchors were identified, validated, and exported.\n";
	else
		text = text + "- Baseline anchors were not validated or exported.\n";
	text = text + "- Plot Values were interpreted only to validate the predicted baseline-anchor X/Y pair.\n";
	if (phase6FitStatus == "Phase6_Polynomial_Baseline_Fit_Completed") {
		text = text + "- A polynomial baseline model was fit using exact-length validated Phase 5 anchor arrays only.\n";
		text = text + "- Full-trace fitted baseline values were calculated and stored internally only.\n";
		text = text + "- Endpoint handling is not implemented; any fitted region outside validated anchor support is extrapolated and explicitly logged as a warning.\n";
	} else {
		text = text + "- No baseline model was fit.\n";
		text = text + "- No full-trace baseline values were calculated.\n";
	}
	if (phase7CalculationStatus == "Phase7_Corrected_Trace_Calculation_Completed") {
		text = text + "- Baseline, DeltaF, DeltaF/F0, and DeltaF/F0 percent were calculated row-wise for the first sample.\n";
		text = text + "- A single-sample Phase 7 corrected trace diagnostic table was exported when save validation passed; it remains pending manual Phase 6/7 revalidation.\n";
		text = text + "- Corrected_Traces_All_Samples.csv was not created.\n";
	} else {
		text = text + "- No Phase 7 corrected values were calculated.\n";
	}
	if (phase8PlotStatus == "Saved") {
		text = text + "- A Phase 8 baseline reconstruction QC plot was saved for the processed sample.\n";
		text = text + "- The plot used raw trace values, exact-length validated baseline anchors, and repaired Phase 6 fitted baseline values.\n";
		text = text + "- The plot is QC evidence only; visual inspection is not automated validation.\n";
	} else {
		text = text + "- No Phase 8 baseline reconstruction QC plot was saved.\n";
	}
	if (phase9SecondSpikyStatus == "Phase9_SecondSpiky_Output_Captured") {
		text = text + "- Phase 9 ran second Spiky on the corrected DeltaF/F0 input plot and captured the live output windows.\n";
	} else {
		text = text + "- No Phase 9 second Spiky output was captured.\n";
	}
	if (phase10FinalOutputStatus == "Phase10_Final_Output_Saved") {
		text = text + "- Phase 10 exported final second-Spiky peak metrics for the processed sample.\n";
		text = text + "- Phase 10 saved the final second-Spiky detected-peaks plot as PNG.\n";
	} else {
		text = text + "- No Phase 10 final peak output was saved.\n";
	}
	if (phase11WindowCleanupStatus != "") {
		text = text + "- Phase 11 conservatively closed macro-created intermediate windows after output verification.\n";
		text = text + "- Phase 11 kept the raw input table, Phase 8 QC plot, and final second-Spiky detected-peaks plot open for inspection.\n";
	} else {
		text = text + "- No Phase 11 window cleanup was run.\n";
	}
	text = text + "- Phase 15A Full Batch continue-after-failure handling is preserved and role-based master aggregation files are created; final all-samples corrected trace export is not implemented.\n";
	text = text + "- Phase 2 creates temporary raw plots for Test First Sample Only and each processed Full Batch sample.\n";
	text = text + "\n";
	text = text + "Phase_6_7_8_9_10_11_Settings:\n";
	text = text + "Baseline_Curve_Method: " + baselineCurveMethod + "\n";
	text = text + "Baseline_Curve_Method_Status: Polynomial used after Phase 5 anchor validation; Phase 7 uses the Phase 6 fitted baseline array\n";
	text = text + "Polynomial_Degree_Selected: " + selectedPolynomialDegree + "\n";
	text = text + "Baseline_Anchor_Source: validated Phase 5 Spiky Plot Values anchors\n";
	text = text + "Phase6_Fit_Input_Method: exact-length validated anchor arrays only; full-length Plot Values arrays are never passed to Fit.doFit\n";
	text = text + "Phase6_Endpoint_Handling: Not implemented; extrapolated regions are logged as warnings without capping or flattening\n";
	text = text + "Phase6_Anchor_Spread_Status: " + phase6AnchorSpreadStatus + "\n";
	text = text + "Phase6_Anchor_Time_Coverage_Percent: " + formatPhase6DiagnosticNumber(phase6AnchorTimeCoveragePercent) + "\n";
	text = text + "Phase6_Polynomial_Degree_First_Attempted: " + phase6PolynomialDegreeFirstAttempted + "\n";
	text = text + "Phase6_Polynomial_Degree_Used: " + phase6PolynomialDegreeUsed + "\n";
	text = text + "Phase6_Polynomial_Fallback_Used: " + phase6PolynomialFallbackUsed + "\n";
	text = text + "Phase6_Polynomial_Fallback_Reason: " + phase6PolynomialFallbackReason + "\n";
	text = text + "Phase6_Baseline_Range_Warning: " + phase6BaselineRangeWarning + "\n";
	text = text + "Phase6_Baseline_Endpoint_Warning: " + phase6BaselineEndpointWarning + "\n";
	text = text + "Phase6_Baseline_Negative_Correction_Warning: " + phase6BaselineNegativeCorrectionWarning + "\n";
	text = text + "Phase6_Baseline_Curvature_Warning: " + phase6BaselineCurvatureWarning + "\n";
	text = text + "Phase6_Peak_Aware_Anchor_Timing_Warning: " + phase6PeakAwareAnchorTimingWarning + "\n";
	text = text + "Phase6_Diagnostic_Table_Save_Status: " + phase6DiagnosticTableSaveStatus + "\n";
	text = text + "Phase6_Diagnostic_Table_Save_Path: " + phase6DiagnosticTableSavePath + "\n";
	text = text + "Phase7_Minimum_Safe_Baseline_Abs: " + formatPhase7DiagnosticNumber(phase7MinimumSafeBaselineAbs) + "\n";
	text = text + "Phase7_Corrected_Trace_Table_Save_Status: " + phase7CorrectedTraceTableSaveStatus + "\n";
	text = text + "Phase7_Corrected_Trace_Table_Save_Path: " + phase7CorrectedTraceTableSavePath + "\n";
	text = text + "Phase7_Output_File_Status: Per-sample corrected trace diagnostic table only; Corrected_Traces_All_Samples.csv is not created in Phase 14\n";
	text = text + "Phase8_Baseline_Reconstruction_Plot_Status: " + phase8PlotStatus + "\n";
	text = text + "Phase8_Baseline_Reconstruction_Plot_Save_Path: " + phase8PlotSavePath + "\n";
	text = text + "Phase8_Endpoint_Annotation_Threshold_Percent: " + phase8EndpointAnnotationThresholdPercent + "\n";
	text = text + "Phase8_In_Plot_Warning_Status: " + phase8InPlotWarningStatus + "\n";
	text = text + "Phase8_Endpoint_Handling: Warning-only; no endpoint correction applied\n";
	text = text + "Phase8_Output_File_Status: Per-sample baseline reconstruction QC plot; no final all-samples export is created in Phase 14\n";
	text = text + "Phase9_SecondSpiky_Status: " + phase9SecondSpikyStatus + "\n";
	text = text + "Phase9_Corrected_Input_Plot_Name: " + phase9CorrectedInputPlotName + "\n";
	text = text + "Phase9_Corrected_Input_Source: X=phase5RawTimes original raw timepoints; Y=phase7DeltaFOverF0Values\n";
	text = text + "Phase9_Corrected_Input_Value_Count: " + phase9CorrectedInputValueCount + "\n";
	text = text + "Phase9_SecondSpiky_DetectedPeaks_Plot_Name: " + phase9SecondSpikyDetectedPeaksPlotName + "\n";
	text = text + "Phase9_SecondSpiky_PeakAnalysis_Table_Name: " + phase9SecondSpikyPeakAnalysisTableName + "\n";
	text = text + "Phase9_Output_File_Status: Second Spiky live windows captured for per-sample Phase 10 export; Phase 15A master aggregation is additive and final all-samples corrected trace export is not created\n";
	text = text + "Phase10_Final_Output_Status: " + phase10FinalOutputStatus + "\n";
	text = text + "Phase10_Final_Peak_Table_Source_Name: " + phase10FinalPeakTableSourceName + "\n";
	text = text + "Phase10_Final_Peak_Table_Save_Path: " + phase10FinalPeakTableSavePath + "\n";
	text = text + "Phase10_Final_Peak_Table_Row_Count: " + phase10FinalPeakTableRowCount + "\n";
	text = text + "Phase10_Final_Peak_Table_Column_Count: " + phase10FinalPeakTableColumnCount + "\n";
	text = text + "Phase10_Final_Peak_Plot_Source_Name: " + phase10FinalPeakPlotSourceName + "\n";
	text = text + "Phase10_Final_Peak_Plot_Save_Path: " + phase10FinalPeakPlotSavePath + "\n";
	text = text + "Phase10_Output_File_Status: Final second-Spiky peak metrics CSV and final second-Spiky detected-peaks PNG only; no final all-samples corrected trace export created\n";
	text = text + "\n";
	text = text + "Detected_Samples:\n";
	text = text + "Source_Column_Index\tOriginal_Sample_Name\tUnique_Sample_Name\tSanitized_File_Name\tWarning\n";
	for (i = 0; i < sampleCount; i++) {
		text = text + (i + 2) + "\t" + sampleOriginalNames[i] + "\t" + sampleUniqueNames[i] + "\t" + sampleFileNames[i] + "\t" + sampleWarnings[i] + "\n";
	}
	File.saveString(text, path);
}

function verifyRequiredOutputs() {
	missingOutputs = "";

	if (!File.exists(runLogPath))
		missingOutputs = appendMissingOutput(missingOutputs, "Run_Log" + outputTableExtension);
	if (!File.exists(settingsPath))
		missingOutputs = appendMissingOutput(missingOutputs, "Analysis_Settings.txt");
	if (!File.exists(methodNotePath))
		missingOutputs = appendMissingOutput(missingOutputs, "Method_Note.txt");
	if (!File.exists(macroCopyPath))
		missingOutputs = appendMissingOutput(missingOutputs, "Macro_Used_For_This_Run.ijm");
	if (!File.exists(plotsFolder))
		missingOutputs = appendMissingOutput(missingOutputs, "Plots/");
	if (phase3DetectedPeaksPlotSavePath != "" && (runMode != "Full Batch" || phase3OutputSaveStatus == "Saved"))
		if (!File.exists(phase3DetectedPeaksPlotSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 3 detected-peaks plot export");
	if (phase3PeakAnalysisTableSavePath != "" && (runMode != "Full Batch" || phase3OutputSaveStatus == "Saved"))
		if (!File.exists(phase3PeakAnalysisTableSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 3 peak-analysis table export");
	if (phase4PlotValuesSavePath != "" && (runMode != "Full Batch" || phase4PlotValuesStatus == "Phase4_PlotValues_Exported"))
		if (!File.exists(phase4PlotValuesSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 4 Plot Values table export");
	if (phase5ValidationStatus == "Phase5_Baseline_Anchors_Validated")
		if (!File.exists(phase5BaselineAnchorsSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 5 baseline anchors export");
	if (phase6DiagnosticTableSaveStatus == "Saved")
		if (!File.exists(phase6DiagnosticTableSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 6 baseline-fit diagnostic table export");
	if (phase7CorrectedTraceTableSaveStatus == "Saved")
		if (!File.exists(phase7CorrectedTraceTableSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 7 corrected trace diagnostic table export");
	if (phase8PlotStatus == "Saved")
		if (!File.exists(phase8PlotSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 8 baseline reconstruction plot export");
	if (phase10FinalOutputStatus == "Phase10_Final_Output_Saved") {
		if (!File.exists(phase10FinalPeakTableSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 10 final peak-analysis table export");
		if (!File.exists(phase10FinalPeakPlotSavePath))
			missingOutputs = appendMissingOutput(missingOutputs, "Phase 10 final peak-analysis plot export");
	}
	phase15MissingOutputs = verifyPhase15MasterTables();
	if (phase15MissingOutputs != "")
		missingOutputs = appendMissingOutput(missingOutputs, phase15MissingOutputs);
	if (runMode == "Full Batch" && phase16ExportStatus != "Not_Started")
		if (!File.exists(phase16MasterWorkbookPath))
			missingOutputs = appendMissingOutput(missingOutputs, inputSourceFileStem + "_Batch_Master_Results.xml");

	if (missingOutputs != "") {
		exit("Phase 1/2/3/4/5/6/7/8/9/10/11/15A/16A output verification failed. Missing required output(s):\n\n" + missingOutputs + "\n\nOutput folder:\n" + outputFolder);
	}
}

function appendMissingOutput(existingText, outputName) {
	if (existingText == "")
		return outputName;
	updatedMissingText = existingText + "\n" + outputName;
	return updatedMissingText;
}

function getSavedFileWindowTitle(savePath) {
	if (savePath == "")
		return "";
	leafTitle = savePath;
	lastSlashIndex = lastIndexOf(leafTitle, "/");
	lastBackslashIndex = lastIndexOf(leafTitle, "\\");
	cutIndex = lastSlashIndex;
	if (lastBackslashIndex > cutIndex)
		cutIndex = lastBackslashIndex;
	if (cutIndex >= 0)
		leafTitle = substring(leafTitle, cutIndex + 1, lengthOf(leafTitle));
	return leafTitle;
}

function runPhase11ConservativeWindowCleanup() {
	phase11WindowCleanupStatus = "Phase11_Window_Cleanup_Started";
	phase11WindowCleanupClosedWindows = "";
	phase11WindowCleanupWarning = "";
	phase11WindowCleanupKeptOpen = "";

	phase11WindowCleanupKeptOpen = appendWarning(phase11WindowCleanupKeptOpen, "Raw input table: " + activeTableTitle);
	if (runMode != "Full Batch") {
		phase11WindowCleanupKeptOpen = appendWarning(phase11WindowCleanupKeptOpen, "Phase 8 baseline reconstruction QC plot: " + phase8PlotWindowName);
		phase11WindowCleanupKeptOpen = appendWarning(phase11WindowCleanupKeptOpen, "Final second-Spiky detected-peaks plot: " + phase9SecondSpikyDetectedPeaksPlotName);
	} else
		phase11WindowCleanupKeptOpen = appendWarning(phase11WindowCleanupKeptOpen, "Phase 14 Full Batch closes per-sample intermediate and QC windows after export or failed-sample cleanup.");

	closeWindowIfOpenAndOwned(phase2PlotName, "Phase 2 raw first-Spiky input plot no longer needed after Phase 10 output verification.");
	closeWindowIfOpenAndOwned(phase3SpikyDetectedPeaksPlotName, "First-Spiky detected-peaks plot already captured, used for Plot Values, and saved.");
	closeWindowIfOpenAndOwned(getSavedFileWindowTitle(phase3DetectedPeaksPlotSavePath), "Saved Phase 3 first-Spiky detected-peaks PNG image window is intermediate and no longer needed after Phase 10 output verification.");
	closeWindowIfOpenAndOwned(phase3SpikyPeakAnalysisTableName, "First-Spiky peak-analysis table already captured and exported.");
	closeWindowIfOpenAndOwned(phase4PlotValuesTableName, "Plot Values table already exported and used for Phase 5 validation.");
	closeWindowIfOpenAndOwned(phase9CorrectedInputPlotName, "Corrected DeltaF/F0 second-Spiky input plot no longer needed after second-Spiky capture and Phase 10 export.");
	closeWindowIfOpenAndOwned(phase9ExistingResultsBackupName, "Phase 9 protected Results backup was created after earlier user-Results protection and is treated as macro-generated intermediate Results content.");
	closeWindowIfOpenAndOwned(phase9SecondSpikyPeakAnalysisTableName, "Second-Spiky peak-analysis table already exported to the final Phase 10 CSV.");
	closeWindowIfOpenAndOwned(phase10FinalPeakTableSourceName, "Second-Spiky peak-analysis table already exported to the final Phase 10 CSV.");
	if (runMode == "Full Batch") {
		closeWindowIfOpenAndOwned(phase8PlotWindowName, "Phase 8 baseline reconstruction QC plot saved and closed between Full Batch samples.");
		closeWindowIfOpenAndOwned(getSavedFileWindowTitle(phase8PlotSavePath), "Saved Phase 8 PNG image window closed between Full Batch samples.");
		closeWindowIfOpenAndOwned(phase9SecondSpikyDetectedPeaksPlotName, "Second-Spiky detected-peaks plot saved and closed between Full Batch samples.");
		closeWindowIfOpenAndOwned(phase10FinalPeakPlotSourceName, "Final peak-analysis plot source saved and closed between Full Batch samples.");
		closeWindowIfOpenAndOwned(getSavedFileWindowTitle(phase10FinalPeakPlotSavePath), "Saved final peak-analysis PNG image window closed between Full Batch samples.");
	}

	if (phase11WindowCleanupWarning == "")
		phase11WindowCleanupStatus = "Phase11_Window_Cleanup_Completed";
	else
		phase11WindowCleanupStatus = "Phase11_Window_Cleanup_Completed_With_Warnings";
}

function verifyPhase14FullBatchCleanupSafeForNextSample() {
	criticalOpenWindows = "";
	phase14SavedPhase3Title = getSavedFileWindowTitle(phase3DetectedPeaksPlotSavePath);
	phase14SavedPhase8Title = getSavedFileWindowTitle(phase8PlotSavePath);
	phase14SavedPhase10Title = getSavedFileWindowTitle(phase10FinalPeakPlotSavePath);

	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase2PlotName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase3SpikyDetectedPeaksPlotName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase14SavedPhase3Title);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase3SpikyPeakAnalysisTableName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase4PlotValuesTableName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase8PlotWindowName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase14SavedPhase8Title);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase9CorrectedInputPlotName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase9ExistingResultsBackupName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase9SecondSpikyDetectedPeaksPlotName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase9SecondSpikyPeakAnalysisTableName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase10FinalPeakPlotSourceName);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase14SavedPhase10Title);
	criticalOpenWindows = appendPhase14CriticalOpenWindow(criticalOpenWindows, phase10FinalPeakTableSourceName);

	if (criticalOpenWindows != "")
		return "Phase 14 critical cleanup failure: macro-owned per-sample window(s) still open after cleanup and could contaminate the next sample: " + criticalOpenWindows;
	return "";
}

function appendPhase14CriticalOpenWindow(existingText, windowName) {
	if (windowName == "")
		return existingText;
	if (isOpen(windowName))
		return appendWarning(existingText, windowName);
	return existingText;
}

function closeWindowIfOpenAndOwned(windowName, reason) {
	if (windowName == "")
		return;
	if (!isOpen(windowName))
		return;
	if (!isPhase11OwnedCleanupTarget(windowName)) {
		phase11WindowCleanupWarning = appendWarning(phase11WindowCleanupWarning, "Phase 11 left window open because ownership was not confirmed: " + windowName);
		return;
	}

	selectWindow(windowName);
	run("Close");
	wait(100);
	if (isOpen(windowName)) {
		selectWindow(windowName);
		close();
		wait(100);
	}
	if (isOpen(windowName))
		phase11WindowCleanupWarning = appendWarning(phase11WindowCleanupWarning, "Phase 11 could not close window: " + windowName);
	else
		phase11WindowCleanupClosedWindows = appendWarning(phase11WindowCleanupClosedWindows, windowName + " [" + reason + "]");
}

function isPhase11OwnedCleanupTarget(windowName) {
	if (windowName == activeTableTitle)
		return false;
	if (runMode != "Full Batch" && windowName == phase8PlotWindowName)
		return false;
	if (runMode != "Full Batch" && windowName == phase9SecondSpikyDetectedPeaksPlotName)
		return false;
	if (runMode != "Full Batch" && windowName == phase10FinalPeakPlotSourceName)
		return false;
	if (windowName == phase3ExistingResultsBackupName)
		return false;
	if (windowName == phase4ExistingResultsBackupName)
		return false;
	if (windowName == phase4ExistingPlotValuesBackupName)
		return false;

	if (windowName == phase2PlotName)
		return true;
	if (windowName == phase3SpikyDetectedPeaksPlotName)
		return true;
	if (windowName == getSavedFileWindowTitle(phase3DetectedPeaksPlotSavePath))
		return true;
	if (windowName == phase3SpikyPeakAnalysisTableName)
		return true;
	if (windowName == phase4PlotValuesTableName)
		return true;
	if (windowName == getSavedFileWindowTitle(phase8PlotSavePath))
		return true;
	if (windowName == phase8PlotWindowName)
		return true;
	if (windowName == phase9CorrectedInputPlotName)
		return true;
	if (windowName == phase9ExistingResultsBackupName)
		return true;
	if (windowName == phase9SecondSpikyDetectedPeaksPlotName)
		return true;
	if (windowName == phase9SecondSpikyPeakAnalysisTableName)
		return true;
	if (windowName == phase10FinalPeakPlotSourceName)
		return true;
	if (windowName == getSavedFileWindowTitle(phase10FinalPeakPlotSavePath))
		return true;
	if (windowName == phase10FinalPeakTableSourceName)
		return true;

	return false;
}

function writeMethodNote(path) {
	text = "";
	text = text + "Methods Skeleton - Spiky Batch Baseline Correction " + macroVersion + "\n";
	text = text + "\n";
	text = text + "Purpose\n";
	text = text + "This note summarizes the stable analysis method and selected run-level scientific settings. It is intended as a concise starting point for a publication Methods section. Exact settings and run-specific audit details are retained separately in Analysis_Settings.txt, Run_Log, sample QC outputs, and provenance/validation logs.\n";
	text = text + "\n";
	text = text + "Software\n";
	text = text + "Calcium-flux traces were analyzed in Fiji/ImageJ " + imageJVersion + " using Spiky Batch Baseline Correction " + macroVersion + " and the release's modified Spiky peak-analysis dependency. Run mode: " + runMode + ".\n";
	text = text + "\n";
	text = text + "Input data\n";
	text = text + "Input was a delimited table with one numeric Time column followed by one numeric fluorescence trace per sample. Time values were used as supplied, in seconds, at their original sampling interval; no resampling or time-axis normalization was applied. Raw input values were not modified.\n";
	text = text + "\n";
	text = text + "Preliminary peak detection\n";
	text = text + "For scientific analysis, each raw fluorescence trace was analyzed with Spiky using peak orientation " + spikyPeakOrientation + ", minimum peak amplitude tolerance " + firstSpikyTolerancePercent + "%, and smoothing " + firstSpikySmoothing + " (-1 denotes Spiky automatic smoothing). If no raw peaks were detected, the predefined conservative tolerance ladder [15, 10, 7.5, 5]% could be attempted below the selected starting tolerance; successful first attempts were not retried.\n";
	text = text + "\n";
	text = text + "Baseline-anchor selection and validation\n";
	text = text + "Candidate baseline anchors were obtained from the baseline X/Y dataset in Spiky Plot Values rather than from the peak-analysis table's Baseline column. The predicted baseline dataset was validated before fitting. Candidate anchors were checked against the raw trace using a local baseline window of " + phase5LocalBaselineWindowPoints + " points and a peak-exclusion window of " + phase5PeakExclusionWindowPoints + " points. The local-baseline tolerance was " + phase5LocalBaselineTolerancePercent + "% of the raw fluorescence range and the peak-separation threshold was " + phase5PeakSeparationPercent + "% of that range. Samples with unverified anchors or insufficient validated anchors failed visibly and were excluded from downstream correction.\n";
	text = text + "\n";
	text = text + "Polynomial baseline fitting\n";
	text = text + "A polynomial baseline was fit only to exact-length arrays of validated anchor times and values using ImageJ Fit.doFit. The requested polynomial degree was " + selectedPolynomialDegree + ". Existing conservative degree handling was retained: five or more anchors allow the requested degree up to 4; four anchors allow up to degree 2; two or three anchors use degree 1; zero or one validated anchor fails. Existing QC-driven degree fallback may lower an unreasonable fit but does not add, move, or substitute anchors. Endpoint extrapolation is warning-only; no endpoint capping, flattening, boundary-anchor insertion, or correction was applied.\n";
	text = text + "\n";
	text = text + "Baseline correction\n";
	text = text + "The fitted baseline F0(t) was evaluated at each original timepoint. Corrected values were calculated row-wise as DeltaF(t) = F(t) - F0(t), DeltaF/F0(t) = [F(t) - F0(t)] / F0(t), and DeltaF/F0 percent(t) = 100 x DeltaF/F0(t). Rows with invalid or unsafe baseline denominators failed validation rather than receiving substituted values.\n";
	text = text + "\n";
	text = text + "Final peak analysis\n";
	text = text + "For samples passing baseline correction, a second Spiky analysis was performed on the DeltaF/F0 trace using peak orientation " + spikyPeakOrientation + ", minimum peak amplitude tolerance " + secondSpikyTolerancePercent + "%, and smoothing " + secondSpikySmoothing + ". Final peak timing, amplitude, interval, width, and area metrics were exported from this corrected-trace analysis.\n";
	text = text + "\n";
	text = text + "Quality control and failed samples\n";
	text = text + "Automated QC records anchor validation, fit residuals and reasonableness, endpoint support, peak preservation, corrected-value validity, and baseline reliability as Baseline_OK, Baseline_Warning, or Baseline_HighRisk. These reliability classes are warning metadata and do not change the scientific calculations. Recoverable sample failures are logged with their terminal phase and reason; Full Batch continues only when the batch state is safe for the next sample. QC plots support manual review but are not used as an automated acceptance rule.\n";
	text = text + "\n";
	text = text + "Outputs and traceability\n";
	text = text + "Major Full Batch aggregate files use the source-aware pattern <InputFileStem>_<OutputType>.<extension>, allowing related datasets to be opened side-by-side. Per-sample tables and plots retain sample-based names. Detailed settings, paths, warnings, failures, and validation evidence are intentionally kept outside this publication-oriented note in the dedicated audit outputs.\n";
	if (runMode == "Dry Run") {
		text = text + "\n";
		text = text + "Dry Run note\n";
		text = text + "This Dry Run validated input-table structure, naming, settings capture, and output creation only; it did not execute peak detection, baseline fitting, correction, or final peak analysis.\n";
	}
	File.saveString(text, path);
}

function copyMacroUsedIfPossible(sourcePath, destinationPath, copyRequested) {
	statusText = "";

	if (!copyRequested) {
		statusText = "Not requested";
		return statusText;
	}

	if (sourcePath == "" || sourcePath == "NaN") {
		statusText = "Failed; executed batch macro source path was not available";
		return statusText;
	}

	if (!File.exists(sourcePath)) {
		statusText = "Failed; executed batch macro source path did not exist: " + sourcePath;
		return statusText;
	}

	macroText = File.openAsString(sourcePath);
	if (macroText == "") {
		statusText = "Failed; executed batch macro source was empty or could not be read";
		return statusText;
	}

	File.saveString(macroText, destinationPath);
	if (!File.exists(destinationPath))
		return "Failed; copy destination was not created";

	copiedMacroText = File.openAsString(destinationPath);
	if (copiedMacroText != macroText)
		return "Failed; copied macro content did not match executed batch macro source";

	return "Copied_And_Content_Verified";
}

function createUniqueOutputFolder(parentFolder, runTimestamp, versionText, phaseText, keywordText, changeKeywordText) {
	versionSafe = sanitizeFileName(versionText);
	phaseSafe = sanitizeFileName(phaseText);
	keywordSafe = sanitizeFileName(keywordText);
	changeKeywordSafe = normalizeChangeKeyword(changeKeywordText);
	baseFolder = parentFolder + "Spiky_Batch_" + versionSafe + "_" + phaseSafe + "_" + keywordSafe + "_" + changeKeywordSafe + "_" + runTimestamp;
	candidate = baseFolder + File.separator;
	suffix = 2;
	while (File.exists(candidate)) {
		candidate = baseFolder + "_" + suffix + File.separator;
		suffix++;
	}

	File.makeDirectory(candidate);
	if (!File.exists(candidate)) {
		exit("Could not create output folder:\n\n" + candidate);
	}

	return candidate;
}

function makeRunKeyword(modeText) {
	keyword = "Run";
	if (modeText == "Dry Run")
		keyword = "DryRun";
	if (modeText == "Test First Sample Only")
		keyword = "TestFirstSample";
	if (modeText == "Full Batch")
		keyword = "FullBatch";
	return keyword;
}

function normalizeChangeKeyword(rawKeywordText) {
	keywordText = trimString("" + rawKeywordText);
	if (keywordText == "")
		keywordText = "NoKeyword";
	keywordText = sanitizeOptionalKeywordSegment(keywordText);
	if (keywordText == "")
		keywordText = "NoKeyword";
	return keywordText;
}

function sanitizeOptionalKeywordSegment(name) {
	clean = "";
	lastWasUnderscore = false;

	for (keywordCharIndex = 0; keywordCharIndex < lengthOf(name); keywordCharIndex++) {
		ch = substring(name, keywordCharIndex, keywordCharIndex + 1);
		if (matches(ch, "[A-Za-z0-9._-]")) {
			clean = clean + ch;
			lastWasUnderscore = false;
		} else {
			if (!lastWasUnderscore) {
				clean = clean + "_";
				lastWasUnderscore = true;
			}
		}
	}

	clean = trimFilenameEdges(clean);
	if (clean == "")
		return "";

	if (isReservedWindowsName(clean))
		clean = clean + "_keyword";

	if (lengthOf(clean) > 80)
		clean = substring(clean, 0, 80);

	clean = trimFilenameEdges(clean);
	return clean;
}

// Kept separate for Phase 1/2 stability, although both functions currently
// share the same uniqueness logic.
function makeUniqueName(baseName, existingNames, usedCount) {
	candidate = baseName;
	suffix = 2;
	while (nameAlreadyUsed(candidate, existingNames, usedCount)) {
		candidate = baseName + "_" + suffix;
		suffix++;
	}
	return candidate;
}

function makeUniqueFileName(baseName, existingFileNames, usedCount) {
	candidate = baseName;
	suffix = 2;
	while (nameAlreadyUsed(candidate, existingFileNames, usedCount)) {
		candidate = baseName + "_" + suffix;
		suffix++;
	}
	return candidate;
}

function nameAlreadyUsed(candidate, existingNames, usedCount) {
	lowerCandidate = toLowerCase(candidate);
	for (i = 0; i < usedCount; i++) {
		lowerExistingName = toLowerCase(existingNames[i]);
		if (lowerExistingName == lowerCandidate)
			return true;
	}
	return false;
}

function sanitizeFileName(name) {
	clean = "";
	lastWasUnderscore = false;

	for (i = 0; i < lengthOf(name); i++) {
		ch = substring(name, i, i + 1);
		if (matches(ch, "[A-Za-z0-9._-]")) {
			clean = clean + ch;
			lastWasUnderscore = false;
		} else {
			if (!lastWasUnderscore) {
				clean = clean + "_";
				lastWasUnderscore = true;
			}
		}
	}

	clean = trimFilenameEdges(clean);
	if (clean == "")
		clean = "Sample";

	if (isReservedWindowsName(clean))
		clean = clean + "_sample";

	if (lengthOf(clean) > 120)
		clean = substring(clean, 0, 120);

	clean = trimFilenameEdges(clean);
	if (clean == "")
		clean = "Sample";

	return clean;
}

function makeInputSourceFileStem(inputPath, tableTitle) {
	sourceName = inputPath;
	if (sourceName == "" || sourceName == "NaN")
		sourceName = tableTitle;
	sourceName = getPathLeaf(sourceName);
	lowerSourceName = toLowerCase(sourceName);
	if (endsWith(lowerSourceName, ".csv") || endsWith(lowerSourceName, ".tsv") || endsWith(lowerSourceName, ".txt"))
		sourceName = substring(sourceName, 0, lengthOf(sourceName) - 4);
	else if (endsWith(lowerSourceName, ".xlsx"))
		sourceName = substring(sourceName, 0, lengthOf(sourceName) - 5);
	else if (endsWith(lowerSourceName, ".xls"))
		sourceName = substring(sourceName, 0, lengthOf(sourceName) - 4);

	clean = "";
	lastWasUnderscore = false;
	for (sourceStemIndex = 0; sourceStemIndex < lengthOf(sourceName); sourceStemIndex++) {
		ch = substring(sourceName, sourceStemIndex, sourceStemIndex + 1);
		if (matches(ch, "[A-Za-z0-9._-]")) {
			clean = clean + ch;
			lastWasUnderscore = false;
		} else if (!lastWasUnderscore) {
			clean = clean + "_";
			lastWasUnderscore = true;
		}
	}
	clean = trimFilenameEdges(clean);
	if (clean == "")
		clean = "Input_Data";
	if (isReservedWindowsName(clean))
		clean = clean + "_dataset";
	if (lengthOf(clean) > 80)
		clean = substring(clean, 0, 80);
	clean = trimFilenameEdges(clean);
	if (clean == "")
		clean = "Input_Data";
	return clean;
}

function trimFilenameEdges(name) {
	clean = name;
	while (lengthOf(clean) > 0 && (substring(clean, 0, 1) == "." || substring(clean, 0, 1) == "_" || substring(clean, 0, 1) == "-")) {
		clean = substring(clean, 1, lengthOf(clean));
	}
	while (lengthOf(clean) > 0) {
		lastChar = substring(clean, lengthOf(clean) - 1, lengthOf(clean));
		if (lastChar == "." || lastChar == "_" || lastChar == "-")
			clean = substring(clean, 0, lengthOf(clean) - 1);
		else
			break;
	}
	return clean;
}

function isReservedWindowsName(name) {
	lowerName = toLowerCase(name);
	if (lowerName == "con" || lowerName == "prn" || lowerName == "aux" || lowerName == "nul")
		return true;
	if (lowerName == "com1" || lowerName == "com2" || lowerName == "com3" || lowerName == "com4" || lowerName == "com5" || lowerName == "com6" || lowerName == "com7" || lowerName == "com8" || lowerName == "com9")
		return true;
	if (lowerName == "lpt1" || lowerName == "lpt2" || lowerName == "lpt3" || lowerName == "lpt4" || lowerName == "lpt5" || lowerName == "lpt6" || lowerName == "lpt7" || lowerName == "lpt8" || lowerName == "lpt9")
		return true;
	return false;
}

function appendWarning(existingWarning, newWarning) {
	combinedWarning = "";
	if (newWarning == "")
		return existingWarning;
	if (existingWarning == "")
		return newWarning;
	combinedWarning = existingWarning + " " + newWarning;
	return combinedWarning;
}

function ensureTrailingSeparator(path) {
	clean = trimString(path);
	if (clean == "")
		exit("Data output location was blank. No output was created.");

	lastChar = substring(clean, lengthOf(clean) - 1, lengthOf(clean));
	if (lastChar == File.separator || lastChar == "/" || lastChar == "\\")
		return clean;

	cleanWithSeparator = clean + File.separator;
	return cleanWithSeparator;
}

function trimString(value) {
	text = "" + value;
	while (lengthOf(text) > 0) {
		firstChar = substring(text, 0, 1);
		if (firstChar == " " || firstChar == "\t" || firstChar == "\n" || firstChar == "\r")
			text = substring(text, 1, lengthOf(text));
		else
			break;
	}
	while (lengthOf(text) > 0) {
		lastChar = substring(text, lengthOf(text) - 1, lengthOf(text));
		if (lastChar == " " || lastChar == "\t" || lastChar == "\n" || lastChar == "\r")
			text = substring(text, 0, lengthOf(text) - 1);
		else
			break;
	}
	return text;
}

function makeTimestamp() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	monthValue = month + 1;

	yearText = "" + year;
	monthText = "" + monthValue;
	dayText = "" + dayOfMonth;
	hourText = "" + hour;
	minuteText = "" + minute;
	secondText = "" + second;

	if (monthValue < 10)
		monthText = "0" + monthText;
	if (dayOfMonth < 10)
		dayText = "0" + dayText;
	if (hour < 10)
		hourText = "0" + hourText;
	if (minute < 10)
		minuteText = "0" + minuteText;
	if (second < 10)
		secondText = "0" + secondText;

	timestampText = yearText + monthText + dayText + "_" + hourText + minuteText + secondText;
	return timestampText;
}

function csvQuote(value) {
	text = "" + value;
	text = replace(text, "\"", "\"\"");
	quotedText = "\"" + text + "\"";
	return quotedText;
}
