"""Render gnossienne3.py on single-note piano recordings (a played performance, not a MIDI dump).

Samples: University of Iowa MIS, Steinway model B, pp and mf takes, one file per note
(theremin.music.uiowa.edu/MISpiano.html, "may be downloaded and used for any projects, without restrictions").
They live outside the synced tree: SAMPLES (default ~/piano-samples/iowa).

  python3 tools/piano/render.py            -> tools/piano/out/lto_lobby_piano.wav/.ogg and a stereo listen mp3
"""
import os, re, subprocess, sys
import numpy as np
from scipy.signal import butter, fftconvolve, sosfiltfilt

sys.path.insert(0, os.path.dirname(__file__))
import gnossienne3 as G

SR = 44100
SAMPLES = os.environ.get("SAMPLES", os.path.expanduser("~/piano-samples/iowa"))
OUT = os.path.join(os.path.dirname(__file__), "out")
rng = np.random.default_rng(1890)

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
FLAT = {1: "Db", 3: "Eb", 6: "Gb", 8: "Ab", 10: "Bb"}
SHARP_NAME = {0: "C", 2: "D", 4: "E", 5: "F", 7: "G", 9: "A", 11: "B"}


def midi(p):
    m = re.fullmatch(r"([A-G])(#?)(-?\d)", p)
    return 12 * (int(m[3]) + 1) + NAMES[m[1]] + (1 if m[2] else 0)


def iowa_name(n):
    pc, octave = n % 12, n // 12 - 1
    return (FLAT.get(pc) or SHARP_NAME[pc]) + str(octave)


_cache = {}


def cents_off(x, n):
    """How far a take sits from equal temperament, from its fundamental (2nd/3rd partial for low notes)."""
    f0 = 440 * 2 ** ((n - 69) / 12)
    seg = x.mean(1)[int(0.15 * SR):int(1.65 * SR)]
    N = 16 * len(seg)
    X = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), N))
    k = 1 if f0 > 110 else (2 if f0 > 55 else 3)
    c = f0 * 2 ** (np.linspace(-0.6, 0.6, 481) / 12)
    return 1200 * np.log2(c[int(np.argmax([X[int(round(k * cc * N / SR))] for cc in c]))] / f0)


def retune(x, n):
    """The takes were recorded on two days and drift up to 15 cents apart; resample each to exact pitch."""
    r = 2 ** (-cents_off(x, n) / 1200)               # < 1 lowers the pitch
    src = np.arange(0, len(x) - 1, r)
    return np.stack([np.interp(src, np.arange(len(x)), x[:, c]) for c in range(2)], 1)


def sample(n, layer):
    key = (n, layer)
    if key not in _cache:
        path = os.path.join(SAMPLES, f"Piano.{layer}.{iowa_name(n)}.aiff")
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                             capture_output=True, check=True).stdout
        x = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
        # the 2001 DAT takes carry a DC offset and sub-bass rumble; the lowest note used is 46 Hz
        x = sosfiltfilt(butter(2, 28, "hp", fs=SR, output="sos"), x - x.mean(0), axis=0)
        env = np.abs(x).max(1)
        start = int(np.argmax(env > env.max() * 0.03))
        x = x[max(0, start - int(0.004 * SR)):]
        x = retune(x, n)
        # each take is normalised to its own peak; restore the pp/mf difference
        x /= np.abs(x).max()
        x *= 0.35 if layer == "pp" else 1.0
        _cache[key] = x
    return _cache[key]


def note(n, vel, length):
    """vel 0..1 blends the pp and mf takes; length in seconds before the damper falls."""
    a, b = sample(n, "pp"), sample(n, "mf")
    w = np.clip(vel, 0, 1)
    damp = 0.045 + 0.06 * np.clip((60 - n) / 30, 0, 1)      # damper time constant: ~0.25 s to -40 dB mid, ~0.5 s low
    total = int((length + damp * 5) * SR)
    y = np.zeros((total, 2))
    la, lb = min(total, len(a)), min(total, len(b))
    y[:la] += a[:la] * (1 - w)
    y[:lb] += b[:lb] * w
    t = np.arange(total) / SR
    y *= np.where(t < length, 1.0, np.exp(-(t - length) / damp))[:, None]
    return y


def peak(f, gain_db, q):
    """RBJ peaking EQ as one second-order section."""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * a, -2 * np.cos(w), 1 - al * a]
    d = [1 + al / a, -2 * np.cos(w), 1 - al / a]
    return np.array([[*(np.array(b) / d[0]), 1, d[1] / d[0], d[2] / d[0]]])


def parse(bar):
    out, pos, grace = [], 0, None
    for tok in bar.split():
        p, _, d = tok.partition(":")
        if p == "g":
            grace = d
            continue
        d = int(d) if d else 1
        if p == "_":
            out.append(("_", pos, d, None))
        elif p != "r":
            out.append((p, pos, d, grace))
            grace = None
        pos += d
    assert pos == 8, bar
    return out


def performance():
    """Onset times with rubato: lingering at phrase ends, a slower last phrase, small human drift."""
    q = 60 / 54                                      # Lent, quarter = 54
    t, starts = 0.0, []
    for b in range(1, 56):
        starts.append(t)
        stretch = 1.0 + 0.02 * np.sin(b * 0.9) + 0.008 * rng.standard_normal()
        if b in G.PHRASE_ENDS:
            stretch += 0.05
        if b >= 50:
            stretch += 0.05 * (b - 49)
        t += 4 * q * stretch
    return starts


def render():
    starts = performance()
    end = starts[54] + 7.0
    mix = np.zeros((int(end * SR) + SR, 2))

    events = []                                      # [key, onset, velocity, damper time]

    def place(n, at, vel, length, mel=False):
        events.append([n, at, vel, at + length, mel])

    for b in range(54):
        t0, t1 = starts[b], starts[b + 1]
        e = (t1 - t0) / 8
        pedal = t1 + 0.06                            # pedal changes just after the next downbeat
        swell = G.SWELLS.get(b + 1, 0.0)
        bass, chord = G.LEFT[b]
        place(midi(bass), t0 + 0.012, 0.30 + 0.04 * rng.random(), pedal - t0)
        for beat, frac in ((1, 1.0), (3, 0.85)):
            spread = 0.0
            for p in chord.split():
                place(midi(p), t0 + 2 * beat * e + 0.015 + spread, (0.22 + 0.04 * rng.random()) * frac + swell * 0.3,
                      pedal - t0 - 2 * beat * e)
                spread += 0.003 + 0.002 * rng.random()
        tied = b + 1 < 54 and G.MELODY[b + 1].startswith("_")
        for p, pos, d, grace in parse(G.MELODY[b]):
            at = t0 + pos * e + 0.003 * rng.standard_normal()
            if p == "_":
                continue
            if tied and pos + d == 8:
                pedal = starts[b + 2] + 0.06            # held into the next bar
            v = 0.55 + 0.06 * rng.standard_normal() + swell
            if pos in (0, 4):
                v += 0.05
            if grace:
                place(midi(grace), at - 0.075, v * 0.6, pedal - at + 0.075)
            place(midi(p), at, v, pedal - at, True)
    # a key struck again cuts its earlier sounding note
    events.sort(key=lambda ev: ev[1])
    # the melody is played legato rather than left under the pedal: each note lets go just after the next
    # one sounds, so neighbouring steps (E against D#) don't pile up into a smear
    mel = [ev for ev in events if ev[4]]
    for a, b in zip(mel, mel[1:]):
        a[3] = min(a[3], b[1] + 0.09)
    last = {}
    for ev in events:
        if ev[0] in last:
            last[ev[0]][3] = min(last[ev[0]][3], ev[1] + 0.02)
        last[ev[0]] = ev
    for n, at, vel, stop, _ in events:
        y = note(n, vel, max(0.05, stop - at))
        i = int(max(0, at) * SR)
        mix[i:i + len(y)] += y[:len(mix) - i]
    # room: short, dark, decorrelated tail
    n = int(1.6 * SR)
    tt = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-tt / 0.32)[:, None]
    ir[:, 0] = np.convolve(ir[:, 0], np.ones(6) / 6, "same")
    ir[:, 1] = np.convolve(ir[:, 1], np.ones(6) / 6, "same")
    ir /= np.sqrt((ir ** 2).sum(0))
    wet = np.stack([fftconvolve(mix[:, c], ir[:, c])[:len(mix)] for c in range(2)], 1)
    out = mix + 0.22 * wet
    # the takes were close-miked 8" over the bass strings: take the boom out of the low-mids
    out = sosfiltfilt(peak(200, -4.5, 0.8), out, axis=0)
    cut = int((starts[54] + 6.5) * SR)
    out = out[:cut]
    fade = int(2.0 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    out /= np.abs(out).max() / 0.89
    return out


def write(x, path, args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-",
                    *args, path], input=x.astype(np.float32).tobytes(), check=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    st = render()
    mono = st.mean(1, keepdims=True)
    mono /= np.abs(mono).max() / 0.89
    write(mono, os.path.join(OUT, "lto_lobby_piano.ogg"), ["-c:a", "libvorbis", "-q:a", "6"])
    write(st, os.path.join(OUT, "lto_lobby_piano-listen.mp3"), ["-c:a", "libmp3lame", "-b:a", "192k"])
    print(f"{len(st) / SR:.1f} s")
