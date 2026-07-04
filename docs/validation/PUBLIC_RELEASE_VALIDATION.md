# Public Release Validation

Validation date: 2026-07-04

## Identity

- Release: v0.1.17 final
- Batch macro SHA-256: `05A8363EBFC5F2988E2CD6E287179C09792B3F38577589C83422A81A803CFF6D`
- Prior scientific-release SHA-256: `2E698D4ACC3D7234089D57879CA7ECA51953781338A993768EBA0B5AFB642D0E`
- Difference: approved copyright and GPL identifier header only.
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

All five master CSVs matched the accepted reference after normalizing timestamps and paths. The lightweight workbook matched normalized accepted content. Failures remained traceable and later wells continued.

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
