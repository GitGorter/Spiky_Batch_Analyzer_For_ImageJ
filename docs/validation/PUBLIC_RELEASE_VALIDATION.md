# Public Release Validation

Validation date: 2026-07-04

## Identity

- Release: v0.1.17 final
- Active batch macro SHA-256: `E591A8780EBF9E3FBC42FF80B091281119F1A6E51205A7E680C4705416CA62E2`
- Full Batch regression-reference macro SHA-256: `05A8363EBFC5F2988E2CD6E287179C09792B3F38577589C83422A81A803CFF6D`
- Difference: final interactive-menu wording/control mapping and expanded source license header only; scientific and non-interactive analysis paths were unchanged.
- Spiky SHA-256: `79E1F96DA597A1AA91D462DB7B662459FF68B388BD93BF204FD8ABF401CDD81D`
- Fiji/ImageJ: ImageJ 2.16.0 / 1.54p on Windows.

## Full Batch stress test

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_phase17_tolerance_sweep.ps1 -InputCsv .\docs\validation\Spiky_Maintenance_Dummy_96well_CalciumFlux_1000tp.csv -Tolerance 15 -MaxSamples 0 -TimeoutSeconds 7200 -Force
```

| Check | Result |
|---|---:|
| Samples processed | 96/96 |
| Final-output successes | 59 |
| Traceable conservative failures | 37 |
| Final peaks | 526 |
| Missing required/source-aware outputs | 0 |
| Malformed rows in five master CSVs | 0 |
| Missing referenced paths | 0 |
| Fiji stdout/stderr errors | 0 |
| Runtime | 7:32.7 |

This Full Batch regression was completed before the final UI-only polish. All five master CSVs matched the accepted reference after normalizing timestamps and paths. The lightweight workbook matched normalized accepted content. Failures remained traceable and later wells continued.

## Final UI polish validation

- Macro delimiter/static syntax checks passed.
- Interactive dialog add/get ordering passed code review.
- `Full Batch (all samples)` maps to `maxSamples = 0`; `Set Sample Amount` maps to the entered numeric value.
- The non-interactive `maxSamples` argument parser remained unchanged.
- The displayed fallback baseline choice maps to the existing internal `Polynomial` token.
- PowerShell validation scripts parsed without errors.
- A non-interactive Dry Run passed with the active macro hash, verified copied-macro provenance, and no Fiji stdout/stderr error matches.

## Workbook gate

The source-aware workbook parsed as valid XML, contained no illegal control characters, used four safe worksheet names, and had safe inferred dimensions. A byte-identical copy at a 55-character temporary path opened read-only through Excel 16.0 COM with these used ranges:

- `Sample_QC`: 97 x 16
- `Peak_Analysis_Summary`: 97 x 26
- `Baseline_Correction_Master`: 97 x 39
- `Processing_Steps_Master`: 663 x 19

The original validation path was 257 characters, so the documented short-path workaround remains applicable.

## Public-safety audit

The release repository/package contain GPL licensing, Spiky attribution, citations, governance files, synthetic-only examples, and no private-path or credential matches. Obsolete release candidates, internal state/phase tracking, backups, real/ambiguous example data, and bulky generated validation outputs are excluded.

The staged package's Dry Run completed from a short temporary extraction path. Executed and copied macro hashes matched, provenance was verified, and Fiji stdout/stderr contained no error matches. A first attempt from the deeply nested staging directory reached macro completion but the PowerShell helper could not write its provenance file because the path exceeded legacy Windows limits; no generated smoke output is included in the package.

Intentional synthetic well failures are expected. A release blocker is a crash, silent corruption, inconsistent aggregation, missing required files, misleading success reporting, or an untraceable sample outcome.
