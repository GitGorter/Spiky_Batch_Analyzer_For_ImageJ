# Validation Runner

The historical runner filename is retained for reproducibility. Configure the ignored `config/local_fiji_config.ps1`, then run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_phase17_tolerance_sweep.ps1 -InputCsv .\docs\validation\Spiky_Maintenance_Dummy_96well_CalciumFlux_1000tp.csv -Tolerance 15 -MaxSamples 0 -TimeoutSeconds 7200 -Force
```

Generated outputs are ignored. Release-reference totals are 96 processed wells, 59 final-output successes, 37 traceable failures, and 526 final peaks. Do not tune the macro to force all synthetic stress wells to pass.
