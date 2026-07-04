# Known Limitations

- Windows is validated; cross-platform behavior is expected but not fully validated.
- Deep Windows paths can prevent older Excel configurations from opening valid XML workbooks.
- Polynomial fitting depends on validated Spiky baseline anchors; insufficient support fails conservatively.
- Endpoint extrapolation is warning-only; no endpoint capping or flattening is applied.
- QC labels are technical indicators, not biological inclusion/exclusion decisions.
- The workbook is Excel 2003 XML Spreadsheet format, not `.xlsx`; heavy peak and time-series masters remain separate files.
- The software does not perform treatment/group interpretation, biological statistics, or clinical/diagnostic analysis.
