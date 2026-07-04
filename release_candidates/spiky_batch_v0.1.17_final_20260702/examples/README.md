# Public Example

All public example material is generated from the deterministic synthetic 96-well dataset in `../validation/`. It contains no real, lab-derived, unpublished, or identifiable experimental data.

`Dummy_96well_Lightweight_Output/` is a curated output subset from the validated Full Batch run. It demonstrates the run-root, `Data/`, `Plots/`, and `Tables/` organization without committing the full bulky time-series output. Recorded filesystem paths in text/XML copies are replaced with `C:/Spiky_Output/Public_Dummy_Example`.

Regenerate the dataset with:

```powershell
python .\docs\validation\generate_spiky_dummy_dataset.py
```

To regenerate full output, open the dummy CSV in Fiji and run Full Batch with release defaults. Repository contributors can also use the non-interactive command documented in `validation/README.md`.
