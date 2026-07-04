#!/usr/bin/env python3
"""Collect a conservative Phase 17 tolerance-sweep summary.

The current Fiji macro output schema can evolve, so this collector favors robust
file discovery and best-effort parsing over strict assumptions.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path
from typing import Iterable


TOLERANCE_RE = re.compile(r"tolerance[_-](\d+(?:[_.]\d+)?)", re.IGNORECASE)
POLY_RE = re.compile(r"(H10|H11).*?(?:final_?)?polynomial.*?degree[^0-9]*(\d+)", re.IGNORECASE)
WARNING_RE = re.compile(r"(H10|H11).*?(anchor|support|spread|fallback|warning|shoulder).*", re.IGNORECASE)


def find_files(root: Path, patterns: Iterable[str]) -> list[Path]:
    results: list[Path] = []
    for pattern in patterns:
        results.extend(root.rglob(pattern))
    return sorted({path for path in results if path.is_file()})


def infer_tolerance(run_dir: Path) -> str:
    match = TOLERANCE_RE.search(run_dir.name)
    if not match:
        return ""
    return match.group(1).replace("_", ".")


def extract_setting_value(text: str, key: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}:\s*(.*?)\s*$", re.IGNORECASE | re.MULTILINE)
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def count_csv_rows(path: Path) -> int | None:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            return max(sum(1 for _ in csv.reader(handle)) - 1, 0)
    except UnicodeDecodeError:
        try:
            with path.open("r", encoding="latin-1", newline="") as handle:
                return max(sum(1 for _ in csv.reader(handle)) - 1, 0)
        except Exception:
            return None
    except Exception:
        return None


def read_text(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return path.read_text(encoding=encoding, errors="replace")
        except Exception:
            continue
    return ""


def summarize_run(run_dir: Path) -> dict[str, str]:
    text_files = find_files(run_dir, ["*.txt", "*.csv", "*.tsv", "*.log"])
    combined_text_parts: list[str] = []
    for path in text_files:
        if path.stat().st_size <= 5_000_000:
            combined_text_parts.append(read_text(path))
    combined_text = "\n".join(combined_text_parts)

    degrees = {"H10": "", "H11": ""}
    for sample, degree in POLY_RE.findall(combined_text):
        degrees[sample.upper()] = degree

    warnings = {"H10": [], "H11": []}
    for line in combined_text.splitlines():
        match = WARNING_RE.search(line)
        if match:
            sample = match.group(1).upper()
            if len(warnings[sample]) < 5:
                warnings[sample].append(line.strip()[:240])

    analysis_settings_files = find_files(run_dir, ["Analysis_Settings.txt", "*Analysis*Settings*.txt"])
    method_note_files = find_files(run_dir, ["Method_Note.txt", "*Method*Note*.txt"])
    final_peak_files = find_files(run_dir, ["*Final_Peak_Master*", "*Final*Peak*Master*"])
    batch_master_files = find_files(run_dir, ["*Batch_Master_Results*", "*Batch*Master*Results*"])
    h10_h11_candidate_files = [
        path
        for path in find_files(run_dir, ["*H10*", "*H11*"])
        if path.suffix.lower() in {".txt", ".csv", ".tsv", ".png", ".jpg", ".jpeg", ".tif", ".tiff", ".xml"}
    ]
    baseline_plots = [
        path
        for path in find_files(run_dir, ["*.png", "*.jpg", "*.jpeg", "*.tif", "*.tiff"])
        if re.search(r"H10|H11", path.name, re.IGNORECASE)
        and re.search(r"baseline|reconstruction", path.name, re.IGNORECASE)
    ]
    corrected_plots = [
        path
        for path in find_files(run_dir, ["*.png", "*.jpg", "*.jpeg", "*.tif", "*.tiff"])
        if re.search(r"H10|H11", path.name, re.IGNORECASE)
        and re.search(r"corrected|peak|detected", path.name, re.IGNORECASE)
    ]

    return {
        "run_folder": str(run_dir),
        "first_spiky_tolerance": extract_setting_value(combined_text, "First_Spiky_Tolerance_Percent_Selected")
        or infer_tolerance(run_dir),
        "analysis_settings_files": " | ".join(str(path) for path in analysis_settings_files[:10]),
        "method_note_files": " | ".join(str(path) for path in method_note_files[:10]),
        "h10_final_polynomial_degree": degrees["H10"],
        "h11_final_polynomial_degree": degrees["H11"],
        "h10_anchor_spread_support_warnings": " | ".join(warnings["H10"]),
        "h11_anchor_spread_support_warnings": " | ".join(warnings["H11"]),
        "h10_h11_fallback_reasons": " | ".join(
            line.strip()[:240]
            for line in combined_text.splitlines()
            if re.search(r"H10|H11", line, re.IGNORECASE)
            and re.search(r"fallback|reason", line, re.IGNORECASE)
        )[:1000],
        "final_peak_master_signal": describe_files(final_peak_files),
        "batch_master_results_signal": describe_files(batch_master_files),
        "h10_h11_baseline_reconstruction_plots": " | ".join(str(path) for path in baseline_plots[:10]),
        "h10_h11_final_corrected_peak_plots": " | ".join(str(path) for path in corrected_plots[:10]),
        "h10_h11_candidate_files": " | ".join(str(path) for path in h10_h11_candidate_files[:20]),
    }


def describe_files(paths: list[Path]) -> str:
    if not paths:
        return "missing"
    parts: list[str] = []
    for path in paths[:5]:
        rows = count_csv_rows(path) if path.suffix.lower() in {".csv", ".tsv"} else None
        row_text = f", rows={rows}" if rows is not None else ""
        parts.append(f"{path} (bytes={path.stat().st_size}{row_text})")
    return " | ".join(parts)


def discover_run_dirs(outputs_root: Path) -> list[Path]:
    if not outputs_root.exists():
        return []
    candidates = [path for path in outputs_root.iterdir() if path.is_dir()]
    tolerance_dirs = [path for path in candidates if TOLERANCE_RE.search(path.name)]
    if tolerance_dirs:
        return sorted(tolerance_dirs)
    return sorted(path for path in candidates if not path.name.startswith("_"))


def write_csv(rows: list[dict[str, str]], output_path: Path) -> None:
    if not rows:
        return
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect Phase 17 tolerance-sweep output signals.")
    parser.add_argument(
        "--outputs-root",
        default=str(Path("validation") / "phase17" / "outputs"),
        help="Folder containing tolerance_* run folders.",
    )
    parser.add_argument("--write-csv", help="Optional CSV summary path.")
    args = parser.parse_args()

    outputs_root = Path(args.outputs_root).resolve()
    run_dirs = discover_run_dirs(outputs_root)
    rows = [summarize_run(run_dir) for run_dir in run_dirs]

    if not rows:
        print(f"No run folders found under {outputs_root}")
        return 0

    for row in rows:
        print(f"## {row['run_folder']}")
        for key, value in row.items():
            if key != "run_folder":
                print(f"- {key}: {value or 'TODO/not found'}")
        print()

    if args.write_csv:
        write_csv(rows, Path(args.write_csv).resolve())
        print(f"Wrote CSV summary: {Path(args.write_csv).resolve()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
