#!/usr/bin/env python3
"""
Generate a deterministic 96-well dummy calcium-flux CSV for Spiky Batch Macro maintenance testing.

Output:
- Spiky_Maintenance_Dummy_96well_CalciumFlux_1000tp.csv
- Spiky_Maintenance_Dummy_96well_manifest.csv

Design:
- 1000 timepoints, Time(s) from 0.010 to 10.000 in 0.010 s steps.
- 96 sample columns in plate format A01-H12.
- Mixture of plausible cardiac organoid calcium transients and deliberately pathological traces.
- All values are numeric. No blank cells, NaN, Inf, or non-numeric sentinels are used.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path
from typing import Callable, Dict, List, Tuple

import numpy as np

SEED = 20260630
rng = np.random.default_rng(SEED)

OUTDIR = Path(__file__).resolve().parent
DATA_CSV = OUTDIR / 'Spiky_Maintenance_Dummy_96well_CalciumFlux_1000tp.csv'
MANIFEST_CSV = OUTDIR / 'Spiky_Maintenance_Dummy_96well_manifest.csv'

# 1000 timepoints: 0.010, 0.020, ..., 10.000 s
T = np.round(np.arange(1, 1001, dtype=float) * 0.010, 3)


def wells_96() -> List[str]:
    return [f'{row}{col:02d}' for row in 'ABCDEFGH' for col in range(1, 13)]


def transient_shape(x: np.ndarray, rise: float, decay: float) -> np.ndarray:
    """Difference-of-exponentials transient, normalized to max 1."""
    y = np.zeros_like(x, dtype=float)
    mask = x >= 0
    if not np.any(mask):
        return y
    xm = x[mask]
    raw = np.exp(-xm / decay) - np.exp(-xm / rise)
    raw[raw < 0] = 0
    max_raw = raw.max() if raw.size else 0
    if max_raw > 0:
        raw = raw / max_raw
    y[mask] = raw
    return y


def make_baseline(
    t: np.ndarray,
    base: float = 1000.0,
    kind: str = 'mild_bleach',
    strength: float = 0.08,
    noise: float = 4.0,
) -> np.ndarray:
    tn = (t - t.min()) / (t.max() - t.min())
    if kind == 'flat':
        b = np.full_like(t, base)
    elif kind == 'mild_bleach':
        b = base * (1.0 - strength * (1.0 - np.exp(-t / 4.0)))
    elif kind == 'severe_bleach':
        b = base * (1.0 - strength * (1.0 - np.exp(-t / 2.2)))
    elif kind == 'linear_down':
        b = base * (1.0 - strength * tn)
    elif kind == 'linear_up':
        b = base * (1.0 + strength * tn)
    elif kind == 'quadratic_down':
        b = base * (1.0 - strength * tn**2)
    elif kind == 'hump':
        b = base * (1.0 + strength * np.exp(-((tn - 0.45) / 0.22) ** 2))
    elif kind == 'bowl':
        b = base * (1.0 - strength * np.exp(-((tn - 0.50) / 0.25) ** 2))
    elif kind == 'sinusoidal':
        b = base * (1.0 + strength * np.sin(2 * np.pi * 1.15 * tn))
    elif kind == 'step_up':
        b = np.full_like(t, base)
        b[t >= 4.8] += base * strength
    elif kind == 'step_down':
        b = np.full_like(t, base)
        b[t >= 5.1] -= base * strength
    elif kind == 'w_shape':
        b = base * (1.0 + strength * (0.6 * np.cos(4 * np.pi * tn) - 0.4 * tn))
    elif kind == 'sawtooth':
        phase = (tn * 5.0) % 1.0
        b = base * (1.0 + strength * (phase - 0.5))
    elif kind == 'staircase':
        steps = np.floor(tn * 5.0) / 5.0
        b = base * (1.0 + strength * steps)
    else:
        raise ValueError(f'unknown baseline kind: {kind}')
    if noise > 0:
        b = b + rng.normal(0.0, noise, size=t.shape)
    return b


def regular_beats(
    bpm: float,
    start: float = 0.45,
    end: float = 9.80,
    jitter: float = 0.0,
    missed_prob: float = 0.0,
) -> List[float]:
    period = 60.0 / bpm
    beats: List[float] = []
    bt = start
    while bt < end:
        candidate = bt + (rng.normal(0, jitter) if jitter > 0 else 0.0)
        if 0.05 < candidate < 10.0 and rng.random() >= missed_prob:
            beats.append(float(candidate))
        bt += period
    return beats


def add_beats(
    y: np.ndarray,
    t: np.ndarray,
    beats: List[float],
    amp: float = 120.0,
    rise: float = 0.035,
    decay: float = 0.28,
    amp_jitter: float = 0.06,
    alternans: bool = False,
    invert: bool = False,
) -> np.ndarray:
    out = y.copy()
    sign = -1.0 if invert else 1.0
    for i, bt in enumerate(beats):
        local_amp = amp * (1.0 + rng.normal(0, amp_jitter))
        if alternans:
            local_amp *= 1.35 if i % 2 == 0 else 0.55
        shape = transient_shape(t - bt, rise, decay)
        out += sign * local_amp * shape
    return out


def calcium_trace(
    bpm: float = 60,
    amp: float = 140,
    base: float = 1000,
    baseline_kind: str = 'mild_bleach',
    baseline_strength: float = 0.06,
    noise: float = 5,
    start: float = 0.45,
    rise: float = 0.035,
    decay: float = 0.28,
    jitter: float = 0.015,
    missed_prob: float = 0.0,
    amp_jitter: float = 0.07,
    alternans: bool = False,
    invert: bool = False,
) -> Tuple[np.ndarray, List[float]]:
    b = make_baseline(T, base=base, kind=baseline_kind, strength=baseline_strength, noise=noise)
    beats = regular_beats(bpm=bpm, start=start, jitter=jitter, missed_prob=missed_prob)
    y = add_beats(b, T, beats, amp=amp, rise=rise, decay=decay, amp_jitter=amp_jitter, alternans=alternans, invert=invert)
    return y, beats


def manual_trace(
    beats: List[float],
    amp: float = 140,
    base: float = 1000,
    baseline_kind: str = 'flat',
    baseline_strength: float = 0.03,
    noise: float = 5,
    rise: float = 0.035,
    decay: float = 0.28,
    amp_jitter: float = 0.08,
    alternans: bool = False,
    invert: bool = False,
) -> np.ndarray:
    b = make_baseline(T, base=base, kind=baseline_kind, strength=baseline_strength, noise=noise)
    return add_beats(b, T, beats, amp=amp, rise=rise, decay=decay, amp_jitter=amp_jitter, alternans=alternans, invert=invert)


def add_artifact_spikes(y: np.ndarray, times: List[float], heights: List[float], widths: List[float] | None = None) -> np.ndarray:
    out = y.copy()
    if widths is None:
        widths = [0.012] * len(times)
    for tt, h, w in zip(times, heights, widths):
        out += h * np.exp(-0.5 * ((T - tt) / w) ** 2)
    return out


def add_square_pulses(y: np.ndarray, windows: List[Tuple[float, float, float]]) -> np.ndarray:
    out = y.copy()
    for start, stop, height in windows:
        out[(T >= start) & (T <= stop)] += height
    return out


def clip_signal(y: np.ndarray, lower: float | None = None, upper: float | None = None) -> np.ndarray:
    out = y.copy()
    if lower is not None:
        out = np.maximum(out, lower)
    if upper is not None:
        out = np.minimum(out, upper)
    return out


PatternFunc = Callable[[], Tuple[np.ndarray, str, str, str, str]]
patterns: Dict[str, PatternFunc] = {}


def register(well: str, category: str, description: str, challenge: str, plausible: str):
    def decorator(fn: Callable[[], np.ndarray]):
        def wrapped() -> Tuple[np.ndarray, str, str, str, str]:
            return fn(), category, description, challenge, plausible
        patterns[well] = wrapped
        return fn
    return decorator


# Row A: clean/mostly plausible cardiac organoid beating
for i, bpm in enumerate([36, 42, 48, 54, 60, 66, 72, 78, 84, 90, 58, 70], start=1):
    well = f'A{i:02d}'
    amp = [180, 160, 145, 170, 150, 130, 135, 120, 110, 100, 220, 190][i-1]
    decay = [0.42, 0.38, 0.34, 0.32, 0.30, 0.28, 0.25, 0.23, 0.21, 0.19, 0.45, 0.36][i-1]
    register(well, 'Plausible clean beating', f'Regular beating, {bpm} BPM, stable amplitude', 'Positive-control style trace', 'Yes')(
        lambda bpm=bpm, amp=amp, decay=decay: calcium_trace(bpm=bpm, amp=amp, decay=decay, baseline_strength=0.035, noise=3.5)[0]
    )

# Row B: plausible biological variation
b_configs = [
    ('B01', 30, 260, 0.52, 'Slow strong mature-like transients'),
    ('B02', 105, 75, 0.16, 'Fast low-amplitude beating'),
    ('B03', 52, 95, 0.28, 'Low amplitude but clear beating'),
    ('B04', 62, 280, 0.55, 'Large amplitude broad calcium decay'),
    ('B05', 68, 115, 0.12, 'Narrow rapid calcium transients'),
    ('B06', 55, 150, 0.33, 'Mild beat-to-beat amplitude variation'),
    ('B07', 64, 160, 0.30, 'Alternans-like amplitude pattern'),
    ('B08', 45, 140, 0.44, 'Mild baseline bleaching and slow beats'),
    ('B09', 75, 125, 0.25, 'Moderate noise but clear beats'),
    ('B10', 88, 105, 0.19, 'Faster rhythm close to peak overlap'),
    ('B11', 40, 80, 0.40, 'Weak slow rhythm'),
    ('B12', 72, 210, 0.28, 'High SNR regular beating'),
]
for well, bpm, amp, decay, desc in b_configs:
    register(well, 'Plausible biological variation', desc, 'Checks tolerance across normal biological variability', 'Yes')(
        lambda bpm=bpm, amp=amp, decay=decay, well=well: calcium_trace(
            bpm=bpm, amp=amp, decay=decay,
            baseline_kind='mild_bleach', baseline_strength=0.055,
            noise=7 if well == 'B09' else 4.5,
            amp_jitter=0.18 if well in {'B06'} else 0.07,
            alternans=well == 'B07',
        )[0]
    )

# Row C: arrhythmic or uneven but still biologically possible
c_manual = {
    'C01': ([0.55, 1.55, 2.45, 3.65, 4.55, 5.95, 6.85, 8.05, 8.95], 'Irregular IBI with visible beats'),
    'C02': ([0.50, 1.00, 1.50, 3.50, 4.00, 4.50, 7.20, 7.70, 8.20], 'Burst-pause-burst rhythm'),
    'C03': ([0.60, 1.40, 2.20, 3.00, 3.18, 3.98, 4.76, 5.56, 5.74, 6.55, 7.35, 8.15, 8.33, 9.15], 'Regular rhythm with doublets'),
    'C04': ([0.45, 0.78, 1.10, 1.43, 1.75, 2.08, 2.40, 5.20, 6.30, 7.40, 8.50, 9.60], 'Early tachy burst then slow recovery'),
    'C05': ([0.70, 2.20, 3.70, 5.20, 6.70, 8.20, 9.70], 'Bradycardic sparse but rhythmic'),
    'C06': ([0.50, 0.95, 1.80, 2.25, 3.10, 3.55, 4.40, 4.85, 5.70, 6.15, 7.00, 7.45, 8.30, 8.75, 9.60], 'Alternating short and long IBI'),
    'C07': ([1.00, 2.00, 3.00, 7.00, 8.00, 9.00], 'Long silent middle gap'),
    'C08': ([0.50, 1.22, 1.95, 2.65, 3.40, 4.15, 4.88, 5.62, 6.35, 7.08, 7.82, 8.55, 9.28], 'Jittery rhythm with moderate noise'),
    'C09': ([0.42, 1.15, 2.95, 3.55, 3.92, 5.70, 6.95, 8.90], 'Missed beats and irregular amplitude'),
    'C10': ([0.35, 0.70, 1.05, 1.40, 1.75, 2.10, 2.45, 2.80, 3.15, 3.50, 3.85, 4.20, 4.55, 4.90, 5.25, 5.60, 5.95, 6.30, 6.65, 7.00, 7.35, 7.70, 8.05, 8.40, 8.75, 9.10, 9.45, 9.80], 'Very fast near-overlapping transients'),
    'C11': ([0.80, 1.65, 2.50, 3.35, 4.20, 5.05, 5.90, 6.75, 7.60, 8.45, 9.30], 'Regular rhythm with strong alternans'),
    'C12': ([0.50, 1.20, 2.10, 3.30, 4.90, 6.20, 6.45, 7.80, 9.40], 'Highly irregular rhythm with one couplet'),
}
for well, (beats, desc) in c_manual.items():
    register(well, 'Arrhythmic / uneven beating', desc, 'Peak detection, IBI, and anchor extraction under arrhythmia', 'Mostly')(
        lambda beats=beats, well=well: manual_trace(
            beats=beats,
            amp=150 if well not in {'C05', 'C10'} else (115 if well == 'C05' else 80),
            decay=0.30 if well != 'C10' else 0.18,
            baseline_kind='mild_bleach', baseline_strength=0.05,
            noise=8 if well in {'C08', 'C09', 'C12'} else 5,
            alternans=well in {'C11', 'C09'},
        )
    )

# Row D: weak beating / failures / low SNR
for well, desc, fn in [
    ('D01', 'Very weak regular beats barely above noise', lambda: calcium_trace(60, amp=28, noise=8, baseline_strength=0.04)[0]),
    ('D02', 'Almost flat, tiny residual rhythm', lambda: calcium_trace(48, amp=18, noise=4, baseline_kind='flat')[0]),
    ('D03', 'No beating, flat baseline with noise', lambda: make_baseline(T, base=1000, kind='flat', strength=0, noise=6)),
    ('D04', 'No beating, mild photobleaching only', lambda: make_baseline(T, base=1050, kind='mild_bleach', strength=0.10, noise=5)),
    ('D05', 'Single clear beat only', lambda: manual_trace([4.8], amp=180, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('D06', 'Two beats only', lambda: manual_trace([2.7, 7.3], amp=160, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('D07', 'High noise with moderate real beats', lambda: calcium_trace(58, amp=85, noise=24, baseline_strength=0.04)[0]),
    ('D08', 'Low baseline, low amplitude, noisy', lambda: calcium_trace(50, amp=35, base=300, noise=9, baseline_strength=0.05)[0]),
    ('D09', 'Beating stops after early period', lambda: manual_trace([0.55, 1.25, 1.95, 2.65, 3.35], amp=120, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('D10', 'Beating starts only late', lambda: manual_trace([6.10, 6.85, 7.60, 8.35, 9.10, 9.85], amp=125, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('D11', 'Low SNR plus curved baseline', lambda: calcium_trace(55, amp=35, noise=13, baseline_kind='hump', baseline_strength=0.08)[0]),
    ('D12', 'Sparse weak arrhythmic beats', lambda: manual_trace([1.1, 3.8, 4.3, 8.7], amp=55, noise=10, baseline_kind='flat')),
]:
    register(well, 'Weak / failed beating', desc, 'Should classify weak/failing traces without crashing', 'Mixed')(fn)

# Row E: baseline fitting stress with plausible-looking peaks
for well, desc, kind, strength in [
    ('E01', 'Severe exponential photobleaching with regular beats', 'severe_bleach', 0.34),
    ('E02', 'Strong upward drift with regular beats', 'linear_up', 0.30),
    ('E03', 'Strong linear downward drift with regular beats', 'linear_down', 0.30),
    ('E04', 'Quadratic downward drift with regular beats', 'quadratic_down', 0.28),
    ('E05', 'Broad baseline hump under beats', 'hump', 0.22),
    ('E06', 'Broad baseline bowl under beats', 'bowl', 0.18),
    ('E07', 'Sinusoidal baseline wander under beats', 'sinusoidal', 0.13),
    ('E08', 'Step up in baseline mid-recording', 'step_up', 0.20),
    ('E09', 'Step down in baseline mid-recording', 'step_down', 0.20),
    ('E10', 'W-shaped non-polynomial baseline', 'w_shape', 0.17),
    ('E11', 'Sawtooth baseline drift under beats', 'sawtooth', 0.14),
    ('E12', 'Staircase baseline drift under beats', 'staircase', 0.25),
]:
    register(well, 'Baseline stress', desc, 'Challenges polynomial baseline anchors and fit stability', 'Unlikely-to-plausible')(
        lambda kind=kind, strength=strength: calcium_trace(
            bpm=60, amp=115, baseline_kind=kind, baseline_strength=strength, noise=5, decay=0.30
        )[0]
    )

# Row F: unusual/non-biological patterns that are still numeric
for well, desc, fn in [
    ('F01', 'Saturated/clipped high peaks', lambda: clip_signal(calcium_trace(62, amp=280, baseline_strength=0.04, noise=4)[0], upper=1160)),
    ('F02', 'Single huge positive artifact spike on normal beats', lambda: add_artifact_spikes(calcium_trace(58, amp=110, noise=5)[0], [4.40], [900], [0.018])),
    ('F03', 'Multiple narrow positive artifact spikes', lambda: add_artifact_spikes(calcium_trace(60, amp=80, noise=5)[0], [1.7, 3.3, 6.6, 9.2], [500, 450, 550, 400], [0.012, 0.010, 0.014, 0.012])),
    ('F04', 'Negative-going inverted calcium-like events', lambda: manual_trace([0.7, 1.6, 2.5, 3.4, 4.3, 5.2, 6.1, 7.0, 7.9, 8.8, 9.7], amp=120, noise=5, baseline_kind='flat', invert=True)),
    ('F05', 'Square pulse plateaus instead of transients', lambda: add_square_pulses(make_baseline(T, 1000, 'mild_bleach', 0.05, 4), [(1.0, 1.35, 160), (3.0, 3.45, 180), (5.4, 5.90, 140), (8.0, 8.50, 170)])),
    ('F06', 'Broad fused plateau from overlapping slow peaks', lambda: calcium_trace(120, amp=130, decay=0.80, rise=0.04, baseline_strength=0.04, noise=4)[0]),
    ('F07', 'Very high frequency oscillation/noise on baseline', lambda: make_baseline(T, 1000, 'flat', 0, 8) + 45*np.sin(2*np.pi*18*T)),
    ('F08', 'Large negative dip artifact plus normal beats', lambda: add_artifact_spikes(calcium_trace(60, amp=110, noise=5)[0], [5.2], [-650], [0.035])),
    ('F09', 'Alternating positive and negative artifacts', lambda: add_artifact_spikes(make_baseline(T, 1000, 'mild_bleach', 0.04, 5), [1.1,2.2,3.3,4.4,5.5,6.6,7.7,8.8], [300,-260,340,-280,300,-260,340,-280], [0.015]*8)),
    ('F10', 'Long saturation plateau followed by recovery', lambda: add_square_pulses(make_baseline(T, 950, 'mild_bleach', 0.04, 4), [(2.0, 5.5, 520)])),
    ('F11', 'Stair-step acquisition artifact without true beats', lambda: make_baseline(T, 900, 'staircase', 0.45, 4)),
    ('F12', 'Extremely jagged noisy trace with weak beats', lambda: calcium_trace(65, amp=45, noise=45, baseline_strength=0.04)[0]),
]:
    register(well, 'Non-biological / artifact', desc, 'Stress-test false peak detection and baseline robustness', 'No')(fn)

# Row G: anchor/edge cases for baseline fitting
for well, desc, fn in [
    ('G01', 'Beat exactly near the beginning plus regular later beats', lambda: manual_trace([0.08, 0.95, 1.82, 2.69, 3.56, 4.43, 5.30, 6.17, 7.04, 7.91, 8.78, 9.65], amp=130, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('G02', 'Beat very close to the end of recording', lambda: manual_trace([0.8, 1.7, 2.6, 3.5, 4.4, 5.3, 6.2, 7.1, 8.0, 8.9, 9.96], amp=130, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('G03', 'Only edge beats, little middle information', lambda: manual_trace([0.12, 0.85, 9.15, 9.88], amp=150, noise=5, baseline_kind='mild_bleach', baseline_strength=0.08)),
    ('G04', 'Very broad slow transients leave few clean anchor valleys', lambda: calcium_trace(48, amp=150, decay=1.10, rise=0.05, baseline_strength=0.04, noise=4)[0]),
    ('G05', 'Peaks on top of strong baseline hump', lambda: calcium_trace(55, amp=90, baseline_kind='hump', baseline_strength=0.30, noise=4)[0]),
    ('G06', 'Peaks on top of strong baseline bowl', lambda: calcium_trace(55, amp=90, baseline_kind='bowl', baseline_strength=0.28, noise=4)[0]),
    ('G07', 'Regular beats with sudden local baseline dip', lambda: add_square_pulses(calcium_trace(60, amp=110, baseline_strength=0.05, noise=4)[0], [(4.2, 5.1, -220)])),
    ('G08', 'Mostly quiescent with late tachy burst', lambda: manual_trace([7.00, 7.28, 7.56, 7.84, 8.12, 8.40, 8.68, 8.96, 9.24, 9.52], amp=95, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('G09', 'Early tachy burst then quiescent', lambda: manual_trace([0.50, 0.78, 1.06, 1.34, 1.62, 1.90, 2.18, 2.46, 2.74, 3.02], amp=95, noise=5, baseline_kind='mild_bleach', baseline_strength=0.05)),
    ('G10', 'Undulating baseline with small peaks', lambda: calcium_trace(60, amp=55, baseline_kind='sinusoidal', baseline_strength=0.18, noise=5)[0]),
    ('G11', 'Low-amplitude beats on severe bleaching', lambda: calcium_trace(60, amp=55, baseline_kind='severe_bleach', baseline_strength=0.35, noise=5)[0]),
    ('G12', 'Irregular sparse peaks on step baseline', lambda: manual_trace([1.4, 3.2, 4.9, 7.7], amp=110, noise=5, baseline_kind='step_down', baseline_strength=0.22)),
]:
    register(well, 'Anchor / edge-case stress', desc, 'Targets baseline anchor timing and insufficient-anchor behavior', 'Mixed')(fn)

# Row H: deliberately extreme numeric QC cases
for well, desc, fn in [
    ('H01', 'Perfect flatline, no noise', lambda: np.full_like(T, 1000.0)),
    ('H02', 'Constant line with tiny noise only', lambda: make_baseline(T, 1000, 'flat', 0, 1.2)),
    ('H03', 'Zero-valued acquisition dropout segment', lambda: np.where((T >= 3.0) & (T <= 4.2), 0.0, calcium_trace(60, amp=100, noise=4)[0])),
    ('H04', 'Sudden baseline offset without real peaks', lambda: make_baseline(T, 950, 'step_up', 0.45, 3)),
    ('H05', 'Monotonic rise with no beating', lambda: make_baseline(T, 800, 'linear_up', 0.75, 3)),
    ('H06', 'Monotonic fall with no beating', lambda: make_baseline(T, 1200, 'linear_down', 0.65, 3)),
    ('H07', 'One enormous spike, otherwise flat', lambda: add_artifact_spikes(make_baseline(T, 1000, 'flat', 0, 2), [5.0], [2500], [0.010])),
    ('H08', 'Long negative valley artifact', lambda: add_square_pulses(make_baseline(T, 1000, 'flat', 0, 3), [(2.2, 7.5, -430)])),
    ('H09', 'Periodic sawtooth with no true beats', lambda: make_baseline(T, 1000, 'sawtooth', 0.38, 4)),
    ('H10', 'Random artifact spikes without biological rhythm', lambda: add_artifact_spikes(make_baseline(T, 1000, 'mild_bleach', 0.05, 7), list(rng.uniform(0.4, 9.6, 18)), list(rng.uniform(120, 500, 18)), list(rng.uniform(0.008, 0.025, 18)))),
    ('H11', 'Highly clipped signal with ceiling and floor effects', lambda: clip_signal(add_square_pulses(calcium_trace(70, amp=240, noise=6)[0], [(3.5, 4.4, -360), (7.0, 8.2, 420)]), lower=700, upper=1150)),
    ('H12', 'Combination: severe bleaching, weak beats, giant artifact', lambda: add_artifact_spikes(calcium_trace(52, amp=45, baseline_kind='severe_bleach', baseline_strength=0.42, noise=12)[0], [6.25], [1000], [0.025])),
]:
    register(well, 'Extreme numeric QC case', desc, 'Release-blocking if parser crashes; QC warning/high-risk expected', 'No')(fn)


def generate() -> Tuple[Dict[str, np.ndarray], List[Dict[str, str]]]:
    data: Dict[str, np.ndarray] = {}
    manifest: List[Dict[str, str]] = []
    for well in wells_96():
        if well not in patterns:
            raise RuntimeError(f'Missing pattern for {well}')
        y, category, description, challenge, plausible = patterns[well]()
        y = np.asarray(y, dtype=float)
        # Keep all values finite; permit zero/negative values for artifact stress cases only if produced.
        if not np.all(np.isfinite(y)):
            raise RuntimeError(f'Non-finite values in {well}')
        # Round to 4 decimals for manageable CSV size while retaining signal shape.
        data[well] = np.round(y, 4)
        manifest.append({
            'Well': well,
            'Category': category,
            'Description': description,
            'Expected_Macro_Challenge': challenge,
            'Biologically_Plausible': plausible,
        })
    return data, manifest


def write_outputs() -> None:
    data, manifest = generate()
    headers = ['Time(s)'] + wells_96()
    with DATA_CSV.open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        for i, t in enumerate(T):
            writer.writerow([f'{t:.3f}'] + [f'{data[well][i]:.4f}' for well in wells_96()])

    with MANIFEST_CSV.open('w', newline='', encoding='utf-8') as f:
        fieldnames = ['Well', 'Category', 'Description', 'Expected_Macro_Challenge', 'Biologically_Plausible']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(manifest)

    print(f'Wrote {DATA_CSV}')
    print(f'Wrote {MANIFEST_CSV}')
    print(f'Rows including header: {len(T)+1}; data columns: {len(headers)}')
    print(f'Time range: {T[0]:.3f} to {T[-1]:.3f} s; dt={T[1]-T[0]:.3f} s')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate the deterministic public Spiky 96-well stress-test dataset.')
    parser.add_argument('--output-dir', type=Path, default=OUTDIR, help='Output directory (default: this script directory)')
    args = parser.parse_args()
    OUTDIR = args.output_dir.resolve()
    OUTDIR.mkdir(parents=True, exist_ok=True)
    DATA_CSV = OUTDIR / DATA_CSV.name
    MANIFEST_CSV = OUTDIR / MANIFEST_CSV.name
    write_outputs()
