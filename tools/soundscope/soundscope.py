"""soundscope: measure every number in a sound and compare it with target profiles.

  python tools/soundscope/soundscope.py analyze <files or folders> [--json out.json] [--html out.html]
  python tools/soundscope/soundscope.py compare <file> --to <profile | reference file> [--html out.html]
  python tools/soundscope/soundscope.py profile list | show <name> | make <name> <reference files or folders>
  python tools/soundscope/soundscope.py play <file>

Reads WAV, FLAC, OGG and MP3 (soundfile). Needs numpy, scipy, soundfile.
Loudness follows ITU-R BS.1770-4 / EBU R128 (K-weighting, 400 ms gated blocks, LRA per EBU Tech 3342).
"""

from __future__ import annotations

import argparse
import html
import json
import math
import os
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

HERE = Path(__file__).resolve().parent
PROFILES_FILE = HERE / "profiles.json"
USER_PROFILES = HERE / "profiles"
AUDIO_EXT = {".wav", ".flac", ".ogg", ".mp3", ".aiff", ".aif"}

BANDS = [
    ("sub", 20, 60),
    ("bass", 60, 250),
    ("lowmid", 250, 500),
    ("mid", 500, 2000),
    ("highmid", 2000, 4000),
    ("presence", 4000, 6000),
    ("air", 6000, 20000),
]

# name: (label, unit, group, tolerance used when a reference becomes a target, fix when too high, fix when too low)
METRICS: dict[str, tuple[str, str, str, float, str, str]] = {
    "duration_s": ("Duration", "s", "File", 0.1, "trim it shorter", "it is too short; extend the tail or loop"),
    "sample_rate": ("Sample rate", "Hz", "File", 0, "resample down", "resample to 44100 or 48000"),
    "channels": ("Channels", "", "File", 0, "fold to mono", "use stereo"),
    "integrated_lufs": ("Integrated loudness", "LUFS", "Loudness", 1.0, "lower gain by {d} dB", "raise gain by {d} dB"),
    "momentary_max_lufs": ("Momentary max", "LUFS", "Loudness", 1.5, "lower gain by {d} dB", "raise gain by {d} dB"),
    "short_term_max_lufs": ("Short-term max", "LUFS", "Loudness", 1.5, "lower gain by {d} dB", "raise gain by {d} dB"),
    "lra_lu": ("Loudness range (LRA)", "LU", "Loudness", 2.0, "compress more", "compress less / add quiet moments"),
    "true_peak_dbtp": ("True peak", "dBTP", "Levels", 0.5, "limit peaks {d} dB lower", "peaks have room; fine unless also quiet"),
    "sample_peak_dbfs": ("Sample peak", "dBFS", "Levels", 0.5, "lower gain or limit", "raise gain"),
    "rms_dbfs": ("RMS", "dBFS", "Levels", 1.0, "lower gain by {d} dB", "raise gain by {d} dB"),
    "crest_db": ("Crest factor", "dB", "Dynamics", 1.5, "compress / limit transients", "less compression; let transients through"),
    "plr_db": ("Peak to loudness (PLR)", "dB", "Dynamics", 1.5, "compress / limit transients", "less limiting"),
    "dynamic_range_db": ("Dynamic range (p95-p10)", "dB", "Dynamics", 2.0, "compress", "expand / add contrast"),
    "noise_floor_dbfs": ("Noise floor", "dBFS", "Dynamics", 3.0, "denoise / gate the quiet parts", "fine"),
    "clipped_runs": ("Clipped runs", "", "Levels", 0, "re-render with headroom; clips found", "fine"),
    "dc_offset": ("DC offset", "%", "Levels", 0.1, "high-pass at 20 Hz", "fine"),
    "attack_ms": ("Attack (10-90%)", "ms", "Envelope", 5.0, "sharpen the transient", "soften the transient (fade in)"),
    "tail_ms": ("Tail (peak to -40 dB)", "ms", "Envelope", 50.0, "shorten the decay / reverb", "longer decay / more reverb"),
    "leading_silence_ms": ("Leading silence", "ms", "Envelope", 5.0, "trim the start {d} ms", "fine"),
    "trailing_silence_ms": ("Trailing silence", "ms", "Envelope", 20.0, "trim the end {d} ms", "fine"),
    "loop_seam_db": ("Loop seam level jump", "dB", "Envelope", 1.0, "crossfade the loop ends", "fine"),
    "centroid_hz": ("Spectral centroid (brightness)", "Hz", "Spectrum", 200.0, "darker: cut highs / low-pass", "brighter: boost highs"),
    "rolloff85_hz": ("Rolloff 85%", "Hz", "Spectrum", 500.0, "low-pass / cut highs", "boost highs"),
    "flatness": ("Spectral flatness (0 tone, 1 noise)", "", "Spectrum", 0.05, "more tonal", "more noisy / textured"),
    "band_sub_pct": ("Band sub 20-60 Hz", "%", "Bands", 3.0, "cut sub", "boost sub"),
    "band_bass_pct": ("Band bass 60-250 Hz", "%", "Bands", 3.0, "cut bass", "boost bass"),
    "band_lowmid_pct": ("Band low-mid 250-500 Hz", "%", "Bands", 3.0, "cut low-mids (mud)", "boost low-mids (body)"),
    "band_mid_pct": ("Band mid 500-2k Hz", "%", "Bands", 3.0, "cut mids", "boost mids"),
    "band_highmid_pct": ("Band high-mid 2-4k Hz", "%", "Bands", 3.0, "cut high-mids (harsh)", "boost high-mids (bite)"),
    "band_presence_pct": ("Band presence 4-6k Hz", "%", "Bands", 2.0, "cut presence (sibilance)", "boost presence"),
    "band_air_pct": ("Band air 6-20k Hz", "%", "Bands", 2.0, "cut air (hiss)", "boost air (sparkle)"),
    "stereo_correlation": ("Stereo correlation", "", "Stereo", 0.1, "widen", "narrow; phase problems near or below 0"),
    "stereo_width": ("Stereo width (side/mid)", "", "Stereo", 0.1, "narrow the image", "widen the image"),
    "balance_db": ("L/R balance", "dB", "Stereo", 0.5, "pan toward right", "pan toward left"),
    "mono_drop_db": ("Mono fold-down drop", "dB", "Stereo", 1.0, "fix phase; it loses level in mono", "fine"),
    "tempo_bpm": ("Tempo", "BPM", "Rhythm", 4.0, "slower", "faster"),
    "onset_rate": ("Onsets per second", "/s", "Rhythm", 0.5, "fewer hits / events", "more hits / events"),
    "pitch_hz": ("Fundamental pitch", "Hz", "Pitch", 10.0, "pitch down", "pitch up"),
}

GROUPS = ["File", "Loudness", "Levels", "Dynamics", "Envelope", "Spectrum", "Bands", "Stereo", "Rhythm", "Pitch"]
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def db(x: float, floor: float = -150.0) -> float:
    return 20 * math.log10(x) if x > 0 else floor


def note_of(hz: float) -> str:
    n = round(12 * math.log2(hz / 440.0)) + 57
    return f"{NOTE_NAMES[n % 12]}{n // 12}"


# ---------------------------------------------------------------- loudness

def k_weight(y: np.ndarray, fs: int) -> np.ndarray:
    # BS.1770 pre-filter (high shelf) and RLB high-pass, re-derived for any sample rate
    # (the libebur128 parametrization; matches the spec's 48 kHz coefficients).
    k, q = math.tan(math.pi * 1681.974450955533 / fs), 0.7071752369554196
    vh = 10 ** (3.999843853973347 / 20)
    vb = vh**0.4996667741545416
    b1 = [vh + vb * k / q + k * k, 2 * (k * k - vh), vh - vb * k / q + k * k]
    a1 = [1 + k / q + k * k, 2 * (k * k - 1), 1 - k / q + k * k]
    k, q = math.tan(math.pi * 38.13547087602444 / fs), 0.5003270373238773
    b2 = [1.0, -2.0, 1.0]
    a2 = [1 + k / q + k * k, 2 * (k * k - 1), 1 - k / q + k * k]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, y, axis=0), axis=0)


def block_energy(yk: np.ndarray, fs: int, win_s: float, hop_s: float) -> np.ndarray:
    n, ch = yk.shape
    win, hop = int(round(win_s * fs)), int(round(hop_s * fs))
    if n < win:
        return np.zeros(0)
    weights = np.array([1.41 if i in (3, 4) else 1.0 for i in range(ch)])
    csum = np.vstack([np.zeros((1, ch)), np.cumsum(yk**2, axis=0)])
    starts = np.arange(0, n - win + 1, hop)
    ms = (csum[starts + win] - csum[starts]) / win
    return ms @ weights


def lufs(e: np.ndarray | float) -> np.ndarray | float:
    return -0.691 + 10 * np.log10(np.maximum(e, 1e-20))


def gated(e: np.ndarray, rel_lu: float) -> np.ndarray:
    e = e[lufs(e) > -70]
    if len(e) == 0:
        return e
    return e[lufs(e) > lufs(e.mean()) - rel_lu]


def loudness(y: np.ndarray, fs: int) -> dict:
    yk = k_weight(y, fs)
    out: dict = {}
    mom = block_energy(yk, fs, 0.4, 0.1)
    if len(mom) == 0:
        # Shorter than one 400 ms block: measure the whole clip as one block.
        whole = float(np.mean(yk**2, axis=0).sum())
        out["integrated_lufs"] = out["momentary_max_lufs"] = round(float(lufs(whole)), 2)
        out["_short_clip"] = True
        return out
    g = gated(mom, 10)
    out["integrated_lufs"] = round(float(lufs(g.mean())), 2) if len(g) else -70.0
    out["momentary_max_lufs"] = round(float(lufs(mom.max())), 2)
    st = block_energy(yk, fs, 3.0, 0.1)
    if len(st):
        out["short_term_max_lufs"] = round(float(lufs(st.max())), 2)
        g = gated(st, 20)
        if len(g) > 1:
            lv = lufs(g)
            out["lra_lu"] = round(float(np.percentile(lv, 95) - np.percentile(lv, 10)), 2)
    out["_momentary"] = lufs(mom).tolist()
    return out


# ---------------------------------------------------------------- analysis

def load(path: Path) -> tuple[np.ndarray, int, dict]:
    info = sf.info(str(path))
    y, fs = sf.read(str(path), always_2d=True, dtype="float64")
    return y, fs, {"format": info.format, "subtype": info.subtype}


def envelope_db(mono: np.ndarray, fs: int, win_ms: float = 5.0, hop_ms: float = 1.0) -> tuple[np.ndarray, float]:
    win, hop = max(1, int(fs * win_ms / 1000)), max(1, int(fs * hop_ms / 1000))
    if len(mono) < win:
        return np.array([db(float(np.sqrt(np.mean(mono**2))))]), hop_ms
    csum = np.concatenate([[0.0], np.cumsum(mono**2)])
    starts = np.arange(0, len(mono) - win + 1, hop)
    rms = np.sqrt((csum[starts + win] - csum[starts]) / win)
    return 20 * np.log10(np.maximum(rms, 1e-8)), hop_ms


def tempo_and_onsets(mono: np.ndarray, fs: int) -> dict:
    out: dict = {}
    hop, nfft = 512, 2048
    if len(mono) < nfft * 4:
        return out
    _, _, z = signal.stft(mono, fs, nperseg=nfft, noverlap=nfft - hop, boundary=None)
    mag = np.log1p(np.abs(z) * 100)
    flux = np.maximum(0, np.diff(mag, axis=1)).sum(axis=0)
    flux = flux - signal.medfilt(flux, 15) if len(flux) > 15 else flux
    flux = np.maximum(flux, 0)
    frame_rate = fs / hop
    dur = len(mono) / fs
    peaks, _ = signal.find_peaks(flux, height=flux.mean() + 1.5 * flux.std(), distance=max(1, int(frame_rate * 0.05)))
    out["onset_rate"] = round(len(peaks) / dur, 2)
    if dur >= 6 and flux.std() > 0:
        f = flux - flux.mean()
        ac = np.correlate(f, f, mode="full")[len(f) - 1:]
        lo, hi = int(frame_rate * 60 / 200), int(frame_rate * 60 / 60)
        if hi < len(ac):
            seg = ac[lo:hi]
            # Gentle preference for 80-160 BPM, where most music sits.
            lags = np.arange(lo, hi)
            bpm = 60 * frame_rate / lags
            seg = seg * np.exp(-0.5 * (np.log2(bpm / 120) / 1.0) ** 2)
            lag = lo + int(np.argmax(seg))
            if ac[lag] > 0.1 * ac[0]:
                out["tempo_bpm"] = round(60 * frame_rate / lag, 1)
    return out


def pitch(mono: np.ndarray, fs: int) -> dict:
    n = min(len(mono), 4096)
    if n < 1024:
        return {}
    hop = n // 2
    best, start = -1.0, 0
    for i in range(0, len(mono) - n + 1, hop):
        e = float(np.sum(mono[i:i + n] ** 2))
        if e > best:
            best, start = e, i
    x = mono[start:start + n] * np.hanning(n)
    spec = np.fft.rfft(x, 2 * n)
    ac = np.fft.irfft(np.abs(spec) ** 2)[:n]
    if ac[0] <= 0:
        return {}
    ac /= ac[0]
    lo, hi = int(fs / 2000), int(fs / 40)
    if hi >= n:
        return {}
    lag = lo + int(np.argmax(ac[lo:hi]))
    clarity = float(ac[lag])
    if clarity < 0.6:
        return {}
    if 0 < lag < n - 1:
        a, b, c = ac[lag - 1], ac[lag], ac[lag + 1]
        denom = a - 2 * b + c
        lag = lag + (0.5 * (a - c) / denom if denom != 0 else 0)
    hz = fs / lag
    return {"pitch_hz": round(hz, 1), "pitch_note": note_of(hz), "pitch_clarity": round(clarity, 2)}


def analyze(path: Path) -> dict:
    y, fs, fmt = load(path)
    n, ch = y.shape
    m: dict = {"file": str(path), "format": f"{fmt['format']} {fmt['subtype']}"}
    m["duration_s"] = round(n / fs, 3)
    m["sample_rate"] = fs
    m["channels"] = ch
    mono = y.mean(axis=1)

    peak = float(np.max(np.abs(y))) if n else 0.0
    m["sample_peak_dbfs"] = round(db(peak), 2)
    up = signal.resample_poly(y, 4, 1, axis=0) if fs < 176400 else y
    m["true_peak_dbtp"] = round(db(float(np.max(np.abs(up)))), 2)
    rms = math.sqrt(float(np.mean(y**2))) if n else 0.0
    m["rms_dbfs"] = round(db(rms), 2)
    m["crest_db"] = round(m["sample_peak_dbfs"] - m["rms_dbfs"], 2)
    m["dc_offset"] = round(float(np.max(np.abs(y.mean(axis=0)))) * 100, 3)
    hot = np.abs(y).max(axis=1) >= 0.999
    edges = np.diff(np.concatenate([[0], hot.astype(int), [0]]))
    runs = np.flatnonzero(edges == -1) - np.flatnonzero(edges == 1)
    m["clipped_runs"] = int(np.sum(runs >= 3))

    m.update(loudness(y, fs))
    m["plr_db"] = round(m["true_peak_dbtp"] - m["integrated_lufs"], 2)

    # 50 ms frames for dynamic range and noise floor; digital silence is ignored.
    fr, _ = envelope_db(mono, fs, 50, 25)
    live = fr[fr > -120]
    if len(live):
        m["dynamic_range_db"] = round(float(np.percentile(live, 95) - np.percentile(live, 10)), 2)
        m["noise_floor_dbfs"] = round(float(np.percentile(live, 10)), 2)

    env, hop_ms = envelope_db(mono, fs)
    top = float(env.max())
    thr = max(top - 50, -75)
    above = np.flatnonzero(env > thr)
    if len(above):
        m["leading_silence_ms"] = round(above[0] * hop_ms, 1)
        m["trailing_silence_ms"] = round((len(env) - 1 - above[-1]) * hop_ms, 1)
        ip = int(np.argmax(env))
        lin = 10 ** (env / 20)
        mx = lin[ip]
        a10 = int(np.argmax(lin[: ip + 1] >= 0.1 * mx))
        a90 = int(np.argmax(lin[: ip + 1] >= 0.9 * mx))
        m["attack_ms"] = round((a90 - a10) * hop_ms, 1)
        loud = np.flatnonzero(lin >= 0.01 * mx)
        m["tail_ms"] = round((loud[-1] - ip) * hop_ms, 1)
    seg = min(n // 4, int(0.05 * fs))
    if seg > 0:
        m["loop_seam_db"] = round(abs(db(float(np.sqrt(np.mean(mono[:seg] ** 2)))) - db(float(np.sqrt(np.mean(mono[-seg:] ** 2))))), 2)

    nper = min(8192, 1 << max(8, int(math.log2(max(n, 256)))))
    f, p = signal.welch(mono, fs, nperseg=min(nper, n) if n >= 256 else n, scaling="spectrum")
    band = (f >= 20) & (f <= min(20000, fs / 2))
    fb, pb = f[band], p[band]
    tot = float(pb.sum())
    if tot > 0:
        m["centroid_hz"] = round(float((fb * pb).sum() / tot), 1)
        m["rolloff85_hz"] = round(float(fb[np.searchsorted(np.cumsum(pb), 0.85 * tot)]), 1)
        flat = (fb <= 16000)
        pf = np.maximum(pb[flat], 1e-20)
        m["flatness"] = round(float(np.exp(np.mean(np.log(pf))) / np.mean(pf)), 4)
        for name, lo, hi in BANDS:
            sel = (fb >= lo) & (fb < hi)
            m[f"band_{name}_pct"] = round(100 * float(pb[sel].sum()) / tot, 2)
    m["_spectrum"] = spectrum_curve(f, p)

    if ch >= 2:
        l, r = y[:, 0], y[:, 1]
        sl, sr = float(np.std(l)), float(np.std(r))
        m["stereo_correlation"] = round(float(np.corrcoef(l, r)[0, 1]), 3) if sl > 0 and sr > 0 else 1.0
        mid, side = (l + r) / 2, (l - r) / 2
        mr = float(np.sqrt(np.mean(mid**2)))
        m["stereo_width"] = round(float(np.sqrt(np.mean(side**2))) / mr, 3) if mr > 0 else 0.0
        m["balance_db"] = round(db(math.sqrt(float(np.mean(l**2)))) - db(math.sqrt(float(np.mean(r**2)))), 2)
        stereo_rms = math.sqrt(float(np.mean(y[:, :2] ** 2)))
        m["mono_drop_db"] = round(db(stereo_rms) - db(mr), 2) if mr > 0 else 99.0

    m.update(tempo_and_onsets(mono, fs))
    m.update(pitch(mono, fs))
    m["_envelope"] = env[:: max(1, len(env) // 600)].round(1).tolist()
    return m


def spectrum_curve(f: np.ndarray, p: np.ndarray, points: int = 120) -> list[list[float]]:
    # Average power into log-spaced bins (third-octave-ish), as dB, for plotting.
    edges = np.geomspace(20, min(20000, f[-1] if len(f) else 20000), points + 1)
    out = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        sel = (f >= lo) & (f < hi)
        if sel.any():
            out.append([round(float(math.sqrt(lo * hi)), 1), round(10 * math.log10(max(float(p[sel].mean()), 1e-20)), 2)])
    return out


# ---------------------------------------------------------------- profiles

def all_profiles() -> dict:
    profs = json.loads(PROFILES_FILE.read_text(encoding="utf-8"))
    if USER_PROFILES.is_dir():
        for fp in sorted(USER_PROFILES.glob("*.json")):
            profs[fp.stem] = json.loads(fp.read_text(encoding="utf-8"))
    return profs


def profile_from_measures(name: str, measures: list[dict], source: str) -> dict:
    targets = {}
    for key, (_, _, _, tol, _, _) in METRICS.items():
        vals = [mm[key] for mm in measures if isinstance(mm.get(key), (int, float))]
        if not vals:
            continue
        lo, hi, med = min(vals), max(vals), float(np.median(vals))
        pad = max(tol, 0.25 * (hi - lo))
        if METRICS[key][1] in ("Hz", "ms", "s", "BPM"):
            pad = max(pad, 0.1 * abs(med))
        targets[key] = {"min": round(lo - pad, 3), "ideal": round(med, 3), "max": round(hi + pad, 3)}
    return {"name": name, "kind": "measured", "source": source, "targets": targets,
            "_spectrum": measures[0].get("_spectrum") if len(measures) == 1 else average_spectrum(measures)}


def average_spectrum(measures: list[dict]) -> list[list[float]]:
    curves = [dict((round(f), v) for f, v in mm.get("_spectrum", [])) for mm in measures]
    keys = sorted(set().union(*curves)) if curves else []
    return [[k, round(float(np.mean([c[k] for c in curves if k in c])), 2)] for k in keys if sum(k in c for c in curves) == len(curves)]


def judge(m: dict, prof: dict) -> list[dict]:
    rows = []
    for key, t in prof["targets"].items():
        if key not in METRICS or not isinstance(m.get(key), (int, float)):
            continue
        label, unit, group, _, fix_hi, fix_lo = METRICS[key]
        v = m[key]
        lo, hi = t.get("min", -math.inf), t.get("max", math.inf)
        if v > hi:
            status, d, fix = "HIGH", v - (t.get("ideal", hi) if "ideal" in t else hi), fix_hi
        elif v < lo:
            status, d, fix = "LOW", (t.get("ideal", lo) if "ideal" in t else lo) - v, fix_lo
        else:
            status, d, fix = "OK", 0.0, ""
        rows.append({"key": key, "label": label, "unit": unit, "group": group, "value": v, "min": t.get("min"),
                     "ideal": t.get("ideal"), "max": t.get("max"), "status": status,
                     "fix": fix.replace("{d}", f"{abs(d):.1f}") if fix else "", "why": t.get("why", "")})
    rows.sort(key=lambda r: GROUPS.index(r["group"]))
    return rows


# ---------------------------------------------------------------- output

def fmt(v) -> str:
    if v is None:
        return "-"
    if isinstance(v, float):
        if v in (math.inf, -math.inf):
            return "-"
        if abs(v) >= 1000:
            return f"{v:.0f}"
        return f"{v:.3f}".rstrip("0").rstrip(".") if abs(v) < 10 else f"{v:.1f}"
    return str(v)


def print_measures(m: dict) -> None:
    print(f"\n== {m['file']}  ({m['format']})")
    if m.get("_short_clip"):
        print("   (shorter than 400 ms: loudness is measured over the whole clip as one block)")
    for g in GROUPS:
        keys = [k for k, meta in METRICS.items() if meta[2] == g and k in m]
        if not keys:
            continue
        print(f"  [{g}]")
        for k in keys:
            label, unit = METRICS[k][0], METRICS[k][1]
            extra = f"  ({m['pitch_note']}, clarity {m['pitch_clarity']})" if k == "pitch_hz" else ""
            print(f"    {label:<38}{fmt(m[k]):>10} {unit}{extra}")


def print_judgement(m: dict, prof: dict, rows: list[dict]) -> None:
    ok = sum(r["status"] == "OK" for r in rows)
    print(f"\n== {Path(m['file']).name}  vs  {prof['name']}  ({prof.get('source', '')})")
    print(f"   {ok}/{len(rows)} in range\n")
    print(f"  {'metric':<36}{'value':>10}  {'target (ideal)':<26}status  fix")
    for r in rows:
        tgt = f"{fmt(r['min'])} .. {fmt(r['max'])}"
        if r["ideal"] is not None:
            tgt += f" ({fmt(r['ideal'])})"
        print(f"  {r['label']:<36}{fmt(r['value']):>10}  {tgt:<26}{r['status']:<6}  {r['fix']}")
    notes = prof.get("notes")
    if notes:
        print(f"\n  note: {notes}")


def svg_lines(series: list[tuple[str, list[list[float]], str]], w: int, h: int, logx: bool, ylab: str) -> str:
    pts = [p for _, s, _ in series for p in s]
    if not pts:
        return ""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1 = (min(xs), max(xs))
    y1 = max(ys)
    y0 = max(min(ys), y1 - 90)
    pad = 36

    def X(x):
        if logx:
            return pad + (math.log10(x) - math.log10(x0)) / max(1e-9, math.log10(x1) - math.log10(x0)) * (w - pad - 8)
        return pad + (x - x0) / max(1e-9, x1 - x0) * (w - pad - 8)

    def Y(y):
        return 8 + (y1 - max(y, y0)) / max(1e-9, y1 - y0) * (h - 30)

    parts = [f'<svg viewBox="0 0 {w} {h}" class="plot" role="img">']
    for gx in ([50, 100, 250, 500, 1000, 2000, 4000, 8000, 16000] if logx else []):
        if x0 <= gx <= x1:
            parts.append(f'<line x1="{X(gx):.1f}" x2="{X(gx):.1f}" y1="8" y2="{h-22}" class="grid"/>'
                         f'<text x="{X(gx):.1f}" y="{h-8}" class="tick" text-anchor="middle">{gx if gx < 1000 else str(gx//1000)+"k"}</text>')
    parts.append(f'<text x="4" y="14" class="tick">{ylab}</text>')
    for name, s, cls in series:
        d = " ".join(f"{'M' if i == 0 else 'L'}{X(x):.1f},{Y(y):.1f}" for i, (x, y) in enumerate(s))
        parts.append(f'<path d="{d}" class="{cls}"><title>{html.escape(name)}</title></path>')
    parts.append("</svg>")
    return "".join(parts)


CSS = """
:root{--bg:#f6f5f2;--card:#fff;--ink:#1d1d1f;--mut:#6b6b70;--line:#e3e1dc;--a:#2f6fdb;--b:#d9822b;--ok:#2e8b57;--bad:#c0392b}
@media (prefers-color-scheme:dark){:root{--bg:#141416;--card:#1d1d20;--ink:#ececef;--mut:#9a9aa2;--line:#2c2c31;--a:#6ea0ff;--b:#f0a35a;--ok:#5cc28a;--bad:#ff7a6b}}
body{background:var(--bg);color:var(--ink);font:14px/1.45 system-ui,Segoe UI,sans-serif;margin:0;padding:24px 16px}
main{max-width:980px;margin:auto}h1{font-size:20px;margin:0 0 4px}h2{font-size:15px;margin:22px 0 8px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin:12px 0}
.mut{color:var(--mut)}table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums}
td,th{padding:5px 8px;border-bottom:1px solid var(--line);text-align:left}th{color:var(--mut);font-weight:500}
td.n{text-align:right}.OK{color:var(--ok);font-weight:600}.HIGH,.LOW{color:var(--bad);font-weight:600}
.plot{width:100%;height:auto}.grid{stroke:var(--line)}.tick{fill:var(--mut);font-size:10px}
.sa{fill:none;stroke:var(--a);stroke-width:1.6}.sb{fill:none;stroke:var(--b);stroke-width:1.6;stroke-dasharray:4 3}
.key span{display:inline-block;width:14px;height:3px;margin:0 6px 3px 12px;vertical-align:middle}
"""


def write_html(path: Path, measures: list[dict], judged: list[tuple[dict, dict, list[dict]]]) -> None:
    body = ["<main><h1>Sound report</h1>"]
    for m in measures:
        name = html.escape(Path(m["file"]).name)
        body.append(f'<div class="card"><h2>{name}</h2><div class="mut">{html.escape(m["format"])} &middot; '
                    f'{fmt(m["duration_s"])} s &middot; {m["sample_rate"]} Hz &middot; {m["channels"]} ch</div>')
        jud = [j for j in judged if j[0] is m]
        series = [(name, m["_spectrum"], "sa")]
        if jud and jud[0][1].get("_spectrum"):
            ref = jud[0][1]["_spectrum"]
            # Line the reference up on the same level so the shapes compare, not the gain.
            off = np.median([v for _, v in m["_spectrum"]]) - np.median([v for _, v in ref])
            series.append((jud[0][1]["name"], [[f, round(v + off, 2)] for f, v in ref], "sb"))
        body.append('<h2>Spectrum</h2><div class="key mut"><span style="background:var(--a)"></span>' + name)
        if len(series) > 1:
            body.append(f'<span style="background:var(--b)"></span>{html.escape(series[1][0])} (level-matched)')
        body.append("</div>" + svg_lines(series, 900, 260, True, "dB"))
        env = m.get("_envelope", [])
        step = m["duration_s"] / max(1, len(env) - 1)
        body.append("<h2>Level over time</h2>" + svg_lines([("level", [[i * step, v] for i, v in enumerate(env)], "sa")], 900, 160, False, "dBFS"))
        for _, prof, rows in jud:
            ok = sum(r["status"] == "OK" for r in rows)
            body.append(f'<h2>vs {html.escape(prof["name"])} &mdash; {ok}/{len(rows)} in range</h2>'
                        f'<div class="mut">{html.escape(prof.get("source", ""))}</div><table><tr><th>Metric</th>'
                        '<th class="n">Value</th><th class="n">Target</th><th>Status</th><th>Fix</th></tr>')
            for r in rows:
                tgt = f"{fmt(r['min'])} .. {fmt(r['max'])}" + (f" (ideal {fmt(r['ideal'])})" if r["ideal"] is not None else "")
                body.append(f'<tr><td title="{html.escape(r["why"])}">{r["label"]}</td><td class="n">{fmt(r["value"])} {r["unit"]}</td>'
                            f'<td class="n">{tgt}</td><td class="{r["status"]}">{r["status"]}</td><td>{html.escape(r["fix"])}</td></tr>')
            body.append("</table>")
        body.append("<h2>All measurements</h2><table>")
        for g in GROUPS:
            for k, meta in METRICS.items():
                if meta[2] == g and k in m:
                    body.append(f"<tr><td class='mut'>{g}</td><td>{meta[0]}</td><td class='n'>{fmt(m[k])} {meta[1]}</td></tr>")
        body.append("</table></div>")
    body.append("</main>")
    path.write_text(f"<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
                    f"<title>Sound report</title><style>{CSS}</style></head><body>{''.join(body)}</body></html>", encoding="utf-8")
    print(f"\nreport: {path}")


# ---------------------------------------------------------------- cli

def expand(paths: list[str]) -> list[Path]:
    out = []
    for p in map(Path, paths):
        if p.is_dir():
            out += sorted(q for q in p.rglob("*") if q.suffix.lower() in AUDIO_EXT)
        elif p.exists():
            out.append(p)
        else:
            sys.exit(f"not found: {p}")
    if not out:
        sys.exit("no audio files found")
    return out


def public(m: dict) -> dict:
    return {k: v for k, v in m.items() if not k.startswith("_")}


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="soundscope", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("analyze", help="measure every number in one or more sounds")
    a.add_argument("files", nargs="+")
    a.add_argument("--json")
    a.add_argument("--html")
    c = sub.add_parser("compare", help="compare sounds with a profile or a reference sound")
    c.add_argument("files", nargs="+")
    c.add_argument("--to", required=True, action="append", help="profile name or reference audio file (repeatable)")
    c.add_argument("--html")
    c.add_argument("--json")
    p = sub.add_parser("profile", help="list, show or make target profiles")
    p.add_argument("action", choices=["list", "show", "make"])
    p.add_argument("name", nargs="?")
    p.add_argument("refs", nargs="*")
    p.add_argument("--source", default="")
    pl = sub.add_parser("play", help="play a sound")
    pl.add_argument("file")
    args = ap.parse_args()

    if args.cmd == "play":
        if sys.platform == "win32" and args.file.lower().endswith(".wav"):
            import winsound
            winsound.PlaySound(args.file, winsound.SND_FILENAME)
        else:
            os.startfile(args.file) if sys.platform == "win32" else print("open it in a player")
        return

    if args.cmd == "profile":
        profs = all_profiles()
        if args.action == "list":
            for k, v in profs.items():
                print(f"  {k:<26}{v.get('kind', ''):<10}{v.get('source', '')}")
        elif args.action == "show":
            prof = profs.get(args.name) or sys.exit(f"no profile {args.name}")
            print(f"{args.name}: {prof.get('source', '')}")
            for k, t in prof["targets"].items():
                label = METRICS.get(k, (k,))[0]
                print(f"  {label:<38}{fmt(t.get('min')):>9} ..{fmt(t.get('max')):>9}  ideal {fmt(t.get('ideal'))}  {t.get('why', '')}")
            if prof.get("notes"):
                print(f"  note: {prof['notes']}")
        else:
            if not args.name or not args.refs:
                sys.exit("usage: profile make <name> <reference files or folders>")
            refs = expand(args.refs)
            measures = [analyze(r) for r in refs]
            prof = profile_from_measures(args.name, measures, args.source or f"measured from {len(refs)} reference(s): " + ", ".join(r.name for r in refs[:5]))
            USER_PROFILES.mkdir(exist_ok=True)
            out = USER_PROFILES / f"{args.name}.json"
            out.write_text(json.dumps(prof, indent=1), encoding="utf-8")
            print(f"saved {out} ({len(prof['targets'])} targets)")
        return

    files = expand(args.files)
    measures = [analyze(f) for f in files]
    judged: list[tuple[dict, dict, list[dict]]] = []
    if args.cmd == "analyze":
        for m in measures:
            print_measures(m)
    else:
        profs = all_profiles()
        targets = []
        for t in args.to:
            if t in profs:
                targets.append(profs[t])
            elif Path(t).exists():
                ref = analyze(Path(t))
                targets.append(profile_from_measures(Path(t).name, [ref], f"reference file {t}"))
            else:
                sys.exit(f"'{t}' is neither a profile (see: profile list) nor a file")
        for m in measures:
            for prof in targets:
                rows = judge(m, prof)
                judged.append((m, prof, rows))
                print_judgement(m, prof, rows)
    if args.json:
        data = [public(m) | {"judgements": [{"profile": p["name"], "rows": r} for mm, p, r in judged if mm is m]} for m in measures]
        Path(args.json).write_text(json.dumps(data, indent=1), encoding="utf-8")
        print(f"\njson: {args.json}")
    if args.html:
        write_html(Path(args.html), measures, judged)


if __name__ == "__main__":
    main()
