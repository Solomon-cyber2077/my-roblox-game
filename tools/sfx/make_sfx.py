"""Synthesised replacements for the footstep and breath cues in Config/Audio.

Everything is built from noise and tones, nothing is sampled, so the files are our own work.
  python3 tools/sfx/make_sfx.py [out_dir]     (default tools/sfx/out)
Writes <name>.wav (48 kHz, 16-bit) and <name>.ogg for upload. Seeds are fixed, so a rerun gives the same files.
"""

import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter, sosfilt

SR = 48000


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def band(x, lo, hi, order=2):
    nyq = SR / 2
    if lo <= 0:
        sos = butter(order, hi / nyq, "low", output="sos")
    elif hi >= nyq:
        sos = butter(order, lo / nyq, "high", output="sos")
    else:
        sos = butter(order, [lo / nyq, hi / nyq], "band", output="sos")
    return sosfilt(sos, x)


def env(n, attack, tau):
    """Linear attack (s), then exponential decay with time constant tau (s)."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / tau)


def place(out, sig, at):
    i = int(at * SR)
    if i >= len(out):
        return
    j = min(len(out), i + len(sig))
    out[i:j] += sig[: j - i]


def mode(freq, tau, amp, seconds, drop=1.0, rng=None):
    """A damped sine; drop < 1 glides the pitch down over its decay (a body settling)."""
    t = t_axis(seconds)
    f = freq * (drop + (1 - drop) * np.exp(-t / (tau * 0.6)))
    phase = 2 * np.pi * np.cumsum(f) / SR + (rng.uniform(0, 6.28) if rng is not None else 0)
    return amp * np.sin(phase) * env(len(t), 0.0015, tau)


def noise_burst(rng, seconds, lo, hi, attack, tau, amp):
    n = int(seconds * SR)
    return amp * band(rng.standard_normal(n), lo, hi) * env(n, attack, tau)


def grains(rng, out, start, count, spread, lo, hi, size=(0.0003, 0.0012), amp=1.0):
    """Many tiny bandpassed clicks: stones shifting, crystals breaking."""
    for _ in range(count):
        at = start + rng.exponential(spread)
        length = rng.uniform(*size)
        c = rng.uniform(lo, hi)
        g = noise_burst(rng, length * 4, c * 0.7, min(c * 1.4, SR / 2 - 100), length * 0.2, length, 1)
        place(out, g * amp * rng.lognormal(0, 0.6) * np.exp(-(at - start) / (spread * 3)), at)


def finish(x, peak_db=-3.0, fade=0.03):
    x = x - np.mean(x)
    n = int(fade * SR)
    if n and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    x[: int(0.0005 * SR)] *= np.linspace(0, 1, int(0.0005 * SR))
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


# Footsteps -----------------------------------------------------------------


def plank(seed, creak):
    rng = np.random.default_rng(seed)
    out = np.zeros(int(0.5 * SR))
    boards = [330, 560, 870, 1320, 1950, 2900]
    for at, weight in ((0.0, 1.0), (rng.uniform(0.07, 0.095), 0.55)):  # heel, then toe
        place(out, mode(rng.uniform(110, 140), 0.035, 0.55 * weight, 0.4, drop=0.72, rng=rng), at)
        for k, f in enumerate(boards):
            # wood rings as narrow noisy bands that die fast, not as clean tones
            fk = f * rng.uniform(0.94, 1.06)
            g = weight * 1.6 / (k + 1) ** 0.6
            place(out, noise_burst(rng, 0.15, fk * 0.92, fk * 1.08, 0.001, rng.uniform(0.012, 0.03), g), at)
            place(out, mode(fk, rng.uniform(0.008, 0.018), g * 0.25, 0.1, rng=rng), at)
        place(out, noise_burst(rng, 0.05, 1500, 6500, 0.0008, 0.006, 0.75 * weight), at)  # the shoe's hard edge
        place(out, noise_burst(rng, 0.12, 0, 3000, 0.004, 0.025, 0.12 * weight), at)  # sole scuff
    if creak:  # the board flexing back: stick-slip pulses through the wood's band
        t0, length = rng.uniform(0.13, 0.16), 0.16
        n = int(length * SR)
        pulses = np.zeros(n)
        pos = 0.0
        while pos < length:
            pulses[int(pos * SR)] = rng.uniform(0.5, 1)
            pos += 1 / (rng.uniform(150, 200) * (1 + 0.6 * pos / length))
        c = band(pulses, 420, 1600) * np.hanning(n) * 3.0
        place(out, c, t0)
    for d, g in ((0.011, 0.18), (0.023, 0.1)):  # close floor reflections
        out[int(d * SR):] += g * out[: len(out) - int(d * SR)]
    out = np.tanh(out / np.max(np.abs(out)) * 2.5)  # tame the strike so both takes sit at one loudness
    return finish(out)


def gravel(seed):
    rng = np.random.default_rng(seed)
    out = np.zeros(int(0.5 * SR))
    toe = rng.uniform(0.075, 0.1)
    place(out, mode(70, 0.03, 0.6, 0.3, drop=0.8, rng=rng), 0)
    place(out, noise_burst(rng, 0.15, 0, 450, 0.003, 0.03, 0.5), 0)
    grains(rng, out, 0.0, 150, 0.035, 700, 5500, amp=0.35)
    grains(rng, out, 0.004, 60, 0.05, 350, 1400, size=(0.001, 0.003), amp=0.7)  # bigger stones
    place(out, noise_burst(rng, 0.1, 0, 400, 0.003, 0.02, 0.25), toe)
    grains(rng, out, toe, 70, 0.03, 700, 5500, amp=0.25)
    return finish(out)


def snow(seed, length):
    rng = np.random.default_rng(seed)
    out = np.zeros(int(0.5 * SR))
    n = int(length * SR)
    # compression: the heel breaks the crust at once, then the crystals keep giving under a short swell and fade
    t = np.arange(n) / SR
    swell = np.clip(t / 0.004, 0, 1) * (0.85 + 0.15 * np.clip(t / 0.03, 0, 1)) * np.exp(-np.maximum(t - 0.03, 0) / (length * 0.22))
    swell[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR)) ** 2
    sparse = (rng.random(n) < 0.06) * rng.standard_normal(n)
    crunch = band(sparse, 250, 1900) * swell
    out[:n] += crunch * 1.2
    grains(rng, out, 0.01, 90, length * 0.25, 350, 2000, size=(0.0008, 0.0025), amp=0.5)
    for _ in range(rng.integers(2, 4)):  # cold-snow squeak
        at, sl = rng.uniform(0.03, length * 0.6), rng.uniform(0.02, 0.045)
        tt = t_axis(sl)
        f = rng.uniform(600, 1100) * (1 + 0.25 * tt / sl)
        sq = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(len(tt)) * rng.uniform(0.04, 0.09)
        place(out, sq, at)
    place(out, noise_burst(rng, 0.12, 0, 300, 0.001, 0.04, 0.7), 0)  # muffled weight
    place(out, noise_burst(rng, 0.04, 500, 3000, 0.0005, 0.008, 0.7), 0)  # crust break at heel strike
    return finish(band(out, 0, 5000))


# Breath --------------------------------------------------------------------


def shaped(rng, n, peaks, tilt=0.0):
    """Noise through a smooth spectrum: wide resonances (Hz, width Hz, gain) on a gentle tilt.
    Shaping in the frequency domain keeps it airy; narrow filters ring and read as a knock."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    curve = np.full_like(f, 0.05)
    for fc, width, g in peaks:
        curve += g * np.exp(-0.5 * ((f - fc) / width) ** 2)
    curve *= (np.maximum(f, 100) / 1000) ** tilt
    curve[f < 90] = 0
    return np.fft.irfft(spec * curve, n)


class Voice:
    """A small source-filter voice: the vocal folds (pulses with jitter) and the air through them,
    shaped by a moving mouth (four resonances that glide), plus hiss at the teeth.
    Events paint the controls over time; render() turns them into sound. Breath made this way
    keeps the slowly moving mouth shape and the voiced edge that real breathing has."""

    def __init__(self, rng, seconds):
        self.rng = rng
        self.n = int(seconds * SR)
        n = self.n
        self.air = np.zeros(n)  # turbulence through the throat
        self.voice = np.zeros(n)  # how much the folds vibrate
        self.hiss = np.zeros(n)  # air past the teeth and lips
        self.f0 = np.full(n, 160.0)
        self.jitter = np.full(n, 0.01)
        self.chest = 0.0  # low push of the chest under the air
        self.form = np.tile(np.array([600.0, 1300.0, 2500.0, 3600.0]), (n, 1))
        self.width = np.tile(np.array([160.0, 200.0, 300.0, 400.0]), (n, 1))

    def span(self, at, length, ramp=0.015):
        """Sample range and a weight that is 1 inside and eases in and out at the edges."""
        i, j = int(at * SR), min(self.n, int((at + length) * SR))
        t = np.arange(j - i) / SR
        w = np.clip(np.minimum(t, length - t) / ramp, 0, 1)
        return i, j, np.sin(0.5 * np.pi * w) ** 2

    def glide(self, at, length, start, end):
        """A curve from start to end over the span, eased (the mouth and pitch move smoothly)."""
        i, j, _ = self.span(at, length)
        u = np.linspace(0, 1, j - i)
        u = u * u * (3 - 2 * u)
        return i, j, start + (end - start) * u

    def mouth(self, at, length, start, end, widths=None):
        i, j, w = self.span(at, length, 0.03)
        u = np.linspace(0, 1, j - i)[:, None]
        u = u * u * (3 - 2 * u)
        f = np.array(start) + (np.array(end) - np.array(start)) * u
        self.form[i:j] = self.form[i:j] * (1 - w[:, None]) + f * w[:, None]
        if widths is not None:
            self.width[i:j] = self.width[i:j] * (1 - w[:, None]) + np.array(widths) * w[:, None]

    def pitch(self, at, length, start, end, jitter=0.01):
        i, j, f = self.glide(at, length, start, end)
        _, _, w = self.span(at, length, 0.02)
        self.f0[i:j] = self.f0[i:j] * (1 - w) + f * w
        self.jitter[i:j] = self.jitter[i:j] * (1 - w) + jitter * w

    def swell(self, track, at, length, peak, rise, fall=None, tremor=0.0, catch=False):
        """Adds an envelope to a control track: eased rise, then a fall to nothing. `tremor` shakes it
        unevenly (5-9 Hz, never a clean beat); `catch` stops it short, the throat closing."""
        i, j = int(at * SR), min(self.n, int((at + length) * SR))
        t = np.arange(j - i) / SR
        fall = fall if fall is not None else length - rise
        e = np.sin(0.5 * np.pi * np.clip(t / rise, 0, 1)) ** 2
        k = np.clip((t - rise) / max(fall, 1e-3), 0, 1)
        e *= np.where(t > rise, (1 - k) ** (0.6 if catch else 1.6), 1)
        if catch:
            e *= np.clip((length - t) / 0.028, 0, 1)
        if tremor:
            tr = band(self.rng.standard_normal(len(t) + 4800), 5, 9)[4800:]
            tr /= np.std(tr) + 1e-9
            e *= np.clip(1 + tremor * tr, 0.15, 2)
        track[i:j] += peak * e

    def render(self):
        rng, n = self.rng, self.n
        # the folds: an open-close pulse each cycle (Rosenberg), wobbling in pitch and strength
        wob = band(rng.standard_normal(n), 0, 30)
        wob /= np.std(wob) + 1e-9
        f0 = self.f0 * (1 + self.jitter * wob)
        phase = np.cumsum(f0 / SR) % 1
        open_q = 0.75
        tp = 0.6 * open_q
        g = np.where(
            phase < tp,
            0.5 * (1 - np.cos(np.pi * phase / tp)),
            np.where(phase < open_q, np.cos(0.5 * np.pi * (phase - tp) / (open_q - tp)), 0),
        )
        dg = np.diff(g, prepend=0) * SR / (np.pi * np.maximum(f0, 50)) * 0.5
        shimmer = 1 + 0.08 * band(rng.standard_normal(n), 0, 40) / 0.1
        flutter = band(rng.standard_normal(n), 0, 45)
        flutter = 1 + 0.3 * flutter / (np.std(flutter) + 1e-9)
        noise = lfilter([1], [1, -0.7], rng.standard_normal(n)) * 0.55 * np.clip(flutter, 0.2, 2)  # air is darker than hiss
        # breath through vibrating folds comes in puffs at the pitch; plain breath does not
        voiced = np.clip(self.voice / (self.voice + self.air + 1e-6), 0, 1)
        src = dg * self.voice * shimmer + noise * self.air * (1 - voiced + voiced * (0.3 + 1.2 * g))
        out = np.zeros(n)
        y = src
        block = 120
        for k in range(4):  # the mouth: four resonances in a row, retuned every 2.5 ms
            res = np.zeros(n)
            z = np.zeros(2)
            for i in range(0, n, block):
                f, bw = self.form[i, k], self.width[i, k]
                c = -np.exp(-2 * np.pi * bw / SR)
                bb = 2 * np.exp(-np.pi * bw / SR) * np.cos(2 * np.pi * f / SR)
                aa = 1 - bb - c
                res[i : i + block], z = lfilter([aa], [1, -bb, -c], y[i : i + block], zi=z)
            y = res
        out += y
        out += band(rng.standard_normal(n), 2600, 7500) * self.hiss * 1.6  # teeth and lips
        out = lfilter([1, -0.9], [1], out) * 3  # sound leaving the lips tilts up (the chest keeps some low end)
        out = band(out, 90, 7000, order=1)
        if self.chest:  # the chest pushing the air
            out += band(rng.standard_normal(n), 80, 320) * self.air * self.chest
        tail = int(0.18 * SR)  # a small room around the voice, so breaths never stop dead
        room = rng.standard_normal(tail) * np.exp(-np.arange(tail) / SR / 0.05)
        return out + np.convolve(out, band(room, 200, 5000))[: len(out)] * 0.02


def breath(seed):
    """Hurt and out of breath, 2.7 s: three breaths at a strained middle pace. Each breath in is quick
    and stops at the top; each breath out is pushed through a tight mouth, front-loaded and gone fast,
    with a low grunt of effort at its start. A long, even, open "haaah" sounds like fogging a window;
    quick panting sounds like cartoon panic; teeth hiss or shaking sounds cold."""
    rng = np.random.default_rng(seed)
    v = Voice(rng, 2.7)
    v.chest = 0.8
    v.air += 0.03  # air is always moving a little
    j = lambda x: x * rng.uniform(0.95, 1.05)  # noqa: E731  no two breaths alike
    push = [520, 1450, 2500, 3500]  # breath out through a tight, half-closed mouth ("hhuh"), not "haaah"
    draw = [600, 1500, 2550, 3600]
    widths = [150, 190, 300, 420]
    # (in at, in length, in level, out length, out level, grunt level, grunt pitch start, end)
    plan = [
        (0.00, 0.30, 0.7, 0.42, 0.95, 0.6, 125, 105),
        (0.80, 0.26, 0.55, 0.40, 0.9, 0.3, 120, 105),
        (1.52, 0.28, 0.6, 0.50, 0.85, 0.75, 120, 95),  # the last one groans "uhh"
        (2.38, 0.30, 0.55, 0.0, 0.0, 0.0, 0, 0),  # the next breath in, cut by the fade
    ]
    for at, il, ia, ol, oa, ga, p0, p1 in plan:
        at += rng.uniform(-0.02, 0.02)
        il = j(il)
        level = j(ia)
        v.mouth(at, il, [f * rng.uniform(0.96, 1.04) for f in draw], draw, widths)
        v.swell(v.air, at, il, level, il * 0.75, catch=True)  # the chest stops at the top
        v.swell(v.hiss, at, il, level * 0.08, il * 0.75, catch=True)
        if ol <= 0:
            continue
        o = at + il + rng.uniform(0.03, 0.05)
        ol = j(ol)
        level = j(oa)
        v.mouth(o, ol, push, [480, 1350, 2450, 3450], widths)
        v.swell(v.air, o, ol, level, 0.03, fall=ol * 0.55)  # pushed out, most of it in the first moment
        v.swell(v.hiss, o, ol, level * 0.1, 0.03, fall=ol * 0.55)
        grunt = 0.14 if ga < 0.7 else 0.3
        v.pitch(o, grunt + 0.05, p0, p1, jitter=0.03)
        v.swell(v.voice, o + 0.01, grunt, ga, 0.03)
    return finish(v.render(), peak_db=-2.5, fade=0.25)


def breath_shiver(seed):
    """Tier 2 (temperature): the owner's third breath take, kept because it sounds cold, not hurt:
    a gasp that catches, a shaking breath out turning into a whimper through the nose, three sobbing
    catches in, a trembling moan out, the next gasp starting. Teeth hiss and uneven 5-9 Hz shaking
    are what make it read as shivering."""
    rng = np.random.default_rng(seed)
    v = Voice(rng, 2.7)
    v.air += 0.03
    v.mouth(0.0, 0.4, [800, 1300, 2600, 3700], [420, 1950, 2800, 3900], [220, 260, 380, 500])
    v.swell(v.air, 0.0, 0.38, 0.9, 0.05, catch=True)
    v.swell(v.hiss, 0.0, 0.38, 0.25, 0.06, catch=True)
    v.pitch(0.2, 0.18, 620, 860, jitter=0.06)
    v.swell(v.voice, 0.22, 0.16, 1.1, 0.08, catch=True)
    v.mouth(0.44, 0.62, [650, 1250, 2500, 3600], [320, 1650, 2550, 3500], [180, 220, 400, 600])
    v.swell(v.air, 0.44, 0.62, 0.75, 0.07, tremor=0.45)
    v.pitch(0.5, 0.56, 360, 285, jitter=0.02)
    v.swell(v.voice, 0.52, 0.52, 2.9, 0.12, tremor=0.35)
    for c, (at, ln) in enumerate(((1.1, 0.09), (1.235, 0.085), (1.365, 0.11))):
        v.mouth(at, ln, [480, 1900, 2700, 3800], [420, 2050, 2800, 3900], [200, 250, 350, 500])
        v.swell(v.air, at, ln, 0.55 + 0.1 * c, 0.02, catch=True)
        v.swell(v.hiss, at, ln, 0.12, 0.02, catch=True)
        v.pitch(at, ln, 430 + 90 * c, 520 + 110 * c, jitter=0.05)
        v.swell(v.voice, at + 0.01, ln - 0.01, 1.0 + 0.25 * c, 0.02, catch=True)
    v.mouth(1.52, 0.85, [780, 1200, 2500, 3500], [520, 1100, 2400, 3400], [140, 180, 300, 450])
    v.swell(v.air, 1.52, 0.85, 0.8, 0.08, tremor=0.55)
    v.pitch(1.55, 0.8, 250, 195, jitter=0.025)
    v.swell(v.voice, 1.58, 0.74, 3.3, 0.15, tremor=0.5)
    v.mouth(2.42, 0.28, [750, 1350, 2600, 3700], [500, 1800, 2700, 3800])
    v.swell(v.air, 2.42, 0.28, 0.6, 0.2)
    v.swell(v.hiss, 2.42, 0.28, 0.15, 0.2)
    return finish(v.render(), peak_db=-2.5, fade=0.25)


def winded(seed, seconds=9.6):
    """Getting breath back after a sprint, as a loop: quick pants, now and then a deep breath that
    catches halfway and is dragged in the rest of the way, a long "hooo" after it. No two alike."""
    rng = np.random.default_rng(seed)
    v = Voice(rng, seconds + 1.0)
    v.air += 0.03
    plan = ["pant", "pant", "pant", "deep", "pant", "pant", "double", "pant", "deep", "pant", "pant"]
    at = 0.0
    for kind in plan * 2:
        if at > seconds - 0.3:
            break
        o = rng.uniform(0.9, 1.1)
        if kind == "pant":
            ln = rng.uniform(0.18, 0.26)
            v.mouth(at, ln, [700 * o, 1350, 2600, 3700], [550, 1700 * o, 2700, 3800], [220, 260, 380, 500])
            v.swell(v.air, at, ln, rng.uniform(0.45, 0.6), ln * 0.55)
            v.swell(v.hiss, at, ln, 0.12, ln * 0.6)
            at += ln + rng.uniform(0.01, 0.04)
            ex = rng.uniform(0.26, 0.38)
            v.mouth(at, ex, [720 * o, 1250, 2500, 3600], [560, 1300 * o, 2450, 3500])
            v.swell(v.air, at, ex, rng.uniform(0.7, 0.9), 0.05)
            if rng.random() < 0.6:  # a voiced "huh" on some
                v.pitch(at, ex, rng.uniform(150, 175), rng.uniform(120, 140), jitter=0.02)
                v.swell(v.voice, at + 0.02, ex * 0.6, rng.uniform(0.3, 0.6), 0.04)
            at += ex + rng.uniform(0.04, 0.12)
        elif kind == "deep":
            first = rng.uniform(0.3, 0.38)
            v.mouth(at, 0.75, [750, 1300, 2600, 3700], [400, 2000, 2800, 3900], [220, 260, 380, 500])
            v.swell(v.air, at, first, 0.6, first * 0.8, catch=True)
            v.swell(v.hiss, at, first, 0.18, first * 0.8, catch=True)
            rest = rng.uniform(0.32, 0.42)
            a2 = at + first + rng.uniform(0.04, 0.07)  # caught: the chest stops, then drags the rest in
            v.swell(v.air, a2, rest, 0.75, rest * 0.7, catch=True)
            v.swell(v.hiss, a2, rest, 0.25, rest * 0.7, catch=True)
            v.pitch(a2 + rest - 0.12, 0.12, 520, 700, jitter=0.05)
            v.swell(v.voice, a2 + rest - 0.11, 0.1, 0.5, 0.05, catch=True)
            at = a2 + rest + 0.06
            ex = rng.uniform(0.75, 0.95)
            v.mouth(at, ex, [520, 950, 2400, 3400], [450, 850, 2350, 3300], [150, 180, 300, 450])
            v.swell(v.air, at, ex, 0.85, 0.08, tremor=0.2)
            v.pitch(at, ex, 140, 110, jitter=0.02)
            v.swell(v.voice, at + 0.05, ex * 0.7, 0.6, 0.1)
            at += ex + rng.uniform(0.12, 0.2)
        else:  # two quick pulls in, one breath out
            for _ in range(2):
                ln = rng.uniform(0.11, 0.15)
                v.mouth(at, ln, [600, 1600, 2700, 3800], [480, 1900, 2800, 3900])
                v.swell(v.air, at, ln, 0.55, ln * 0.5, catch=True)
                v.swell(v.hiss, at, ln, 0.15, ln * 0.5, catch=True)
                at += ln + rng.uniform(0.03, 0.05)
            ex = rng.uniform(0.4, 0.5)
            v.mouth(at, ex, [700, 1250, 2500, 3600], [550, 1250, 2450, 3500])
            v.swell(v.air, at, ex, 0.85, 0.05)
            at += ex + rng.uniform(0.08, 0.14)
    x = v.render()
    n = int(seconds * SR)
    loop = x[:n].copy()
    tail = x[n:]
    loop[: len(tail)] += tail  # the last breath's tail wraps onto the start, so the loop has no seam
    loop -= np.mean(loop)
    return loop / np.max(np.abs(loop)) * 10 ** (-3 / 20)


def stone(seed):
    """A boot on cobbles or flagstones: a dull, dense "tock" (leather heel on stone), a little grit
    under the sole, the toe a beat later. Stone is heavy and hardly rings, so nothing here is tonal,
    and the open air around it is diffuse, not distinct echoes (those comb-filter into a metallic edge)."""
    rng = np.random.default_rng(seed)
    out = np.zeros(int(0.5 * SR))
    toe = rng.uniform(0.06, 0.085)
    for at, w in ((0.0, 1.0), (toe, 0.45)):
        place(out, noise_burst(rng, 0.08, 60, 500, 0.0015, 0.012, 1.0 * w), at)  # the weight landing
        place(out, noise_burst(rng, 0.04, 350, 2200, 0.0004, rng.uniform(0.0025, 0.0035), 0.9 * w), at)  # the tock
        place(out, noise_burst(rng, 0.02, 2200, 5000, 0.0002, 0.0012, 0.18 * w), at)  # the edge of the heel
        grains(rng, out, at + 0.003, 10, 0.015, 900, 3500, size=(0.0008, 0.002), amp=0.12 * w)  # grit
    place(out, noise_burst(rng, 0.09, 500, 3000, 0.008, 0.025, 0.05), toe + 0.008)  # the sole rolling off
    room = band(rng.standard_normal(int(0.06 * SR)), 200, 3500) * np.exp(-np.arange(int(0.06 * SR)) / SR / 0.012)
    out = out + np.convolve(out, room)[: len(out)] * 0.025  # walls and kerbs, diffuse
    out = np.tanh(out / np.max(np.abs(out)) * 2.6)
    return finish(band(out, 40, SR / 2 - 100))  # no offset left behind by the levelling


SOUNDS = {
    "lto_step_plank_1": lambda: plank(11, creak=False),
    "lto_step_plank_2": lambda: plank(12, creak=True),
    "lto_step_gravel_1": lambda: gravel(21),
    "lto_step_gravel_2": lambda: gravel(22),
    "lto_step_snow_1": lambda: snow(31, 0.26),
    "lto_step_snow_2": lambda: snow(32, 0.3),
    "lto_step_snow_3": lambda: snow(33, 0.23),
    "lto_step_stone_1": lambda: stone(51),
    "lto_step_stone_2": lambda: stone(52),
    "lto_breath_torn": lambda: breath(41),
    "lto_breath_winded_loop": lambda: winded(61),
}

# Not for the current game: kept for the Tier 2 update, written to <out_dir>/tier2/
TIER2 = {
    "lto_breath_shiver": lambda: breath_shiver(41),
}


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(os.path.join(out_dir, "tier2"), exist_ok=True)
    jobs = [(out_dir, n, m) for n, m in SOUNDS.items()] + [(os.path.join(out_dir, "tier2"), n, m) for n, m in TIER2.items()]
    for out_dir, name, make in jobs:
        x = make()
        wav = os.path.join(out_dir, name + ".wav")
        wavfile.write(wav, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6",
                        os.path.join(out_dir, name + ".ogg")], check=True)
        print(name, f"{len(x) / SR:.2f}s", f"rms {20 * np.log10(np.sqrt(np.mean(x ** 2))):.1f} dBFS")


if __name__ == "__main__":
    main()
