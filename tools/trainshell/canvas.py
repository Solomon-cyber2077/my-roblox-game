"""
Paints a car's two side canvases for bake2.py (system Python with NumPy + Pillow):

  python tools/trainshell/canvas.py <car.json> <out.npz> [debug_dir]

A canvas is the car's side seen square on (80 px per stud, x by y), one layer per kind of mark,
each drawn at its cause from spec["feat"] (carriage2.py): rain streaks under every ledge and sill,
rust weeping from each rivet and strap, soot under the cornice and over the lamp, spray along the
skirt and round the step, scuffs and chips where hands and boots go, paint crazing on the upper
panels, a dark pinstripe inside every bead, gilt corner ornaments, tongue-and-groove boards (height).
Per car (identity.py's feat): the LastTrainOut's crest and double gilt lining, the Stores' stencils,
the Workshop's scorch round the stovepipe and doors.
"""

import glob
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

META = json.load(open(sys.argv[1]))
SPEC = META["spec"]
FEAT = SPEC.get("feat", {})
x0, x1 = SPEC["x0"], SPEC["x1"]
rng = np.random.default_rng(sum(map(ord, SPEC["name"])))
DEBUG = sys.argv[3] if len(sys.argv) > 3 else None

# -- the side canvases ------------------------------------------------------------------------
PPU = 80
CX0, CX1 = x0 - 0.6, x1 + 3.6
CY0, CY1 = -2.6, 10.4
CW, CH = int((CX1 - CX0) * PPU), int((CY1 - CY0) * PPU)


FONTS = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")))


def font(name, size):
    """Roblox's own fonts (as make_sign2.py); None if Roblox is not installed."""
    path = os.path.join(FONTS[-1], name) if FONTS else ""
    return ImageFont.truetype(path, size) if os.path.exists(path) else None


def cpx(x):
    return (x - CX0) * PPU


def cpy(y):
    return (CY1 - y) * PPU


class Canvas:
    LAYERS = ("height", "dirt", "rain", "rust", "soot", "scuff", "chip", "gild", "pin", "craze", "polish", "spray", "stencil")

    def __init__(self):
        for k in self.LAYERS:
            setattr(self, k, np.zeros((CH, CW), np.float32))

    def add(self, layer, x, y, arr, mode="max"):
        """Put a small array with its top-left at canvas pixel (x, y)."""
        L = getattr(self, layer)
        h, w = arr.shape
        xa, ya = int(round(x)), int(round(y))
        sx0, sy0 = max(0, -xa), max(0, -ya)
        xa, ya = max(0, xa), max(0, ya)
        xb, yb = min(CW, xa + w - sx0), min(CH, ya + h - sy0)
        if xb <= xa or yb <= ya:
            return
        src = arr[sy0 : sy0 + (yb - ya), sx0 : sx0 + (xb - xa)]
        if mode == "max":
            np.maximum(L[ya:yb, xa:xb], src, out=L[ya:yb, xa:xb])
        else:
            L[ya:yb, xa:xb] += src


def streak(length_px, width_px, wobble=0.0):
    """A vertical streak (top bright, fading down) as a small array."""
    w = max(3, int(width_px * 4))
    h = max(2, int(length_px))
    yy = np.linspace(0, 1, h)[:, None]
    xx = np.linspace(-1, 1, w)[None, :] * (w / 2) / max(width_px, 0.5)
    off = wobble * np.sin(yy * rng.uniform(3, 9) + rng.uniform(0, 6)) * 1.5
    core = np.exp(-((xx - off) ** 2))
    fade = (1 - yy) ** rng.uniform(0.8, 1.8) * (0.6 + 0.4 * np.clip(yy * 8, 0, 1))
    return (core * fade).astype(np.float32)


def blob(r_px, rough=0.5):
    """An irregular chip / spot."""
    n = int(r_px * 2 + 3)
    yy, xx = np.mgrid[-1 : 1 : n * 1j, -1 : 1 : n * 1j]
    ang = np.arctan2(yy, xx)
    k = rng.integers(3, 7)
    rad = 0.75 + rough * 0.25 * np.sin(ang * k + rng.uniform(0, 6)) + rough * 0.12 * np.sin(ang * (k * 2 + 1))
    d = np.sqrt(xx * xx + yy * yy)
    return np.clip((rad - d) * 6, 0, 1).astype(np.float32)


def value_noise(h, w, cell, seed_shift=0):
    g = rng.random((h // cell + 2, w // cell + 2)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize(((w // cell + 2) * cell, (h // cell + 2) * cell), Image.BICUBIC)
    return np.asarray(img, np.float32)[:h, :w] / 255


def voronoi_cracks(h, w, cell_px):
    """Thin crack lines on cell borders (F2 - F1 small)."""
    gh, gw = h // cell_px + 4, w // cell_px + 4
    px = (np.arange(gw)[None, :] - 1 + rng.random((gh, gw))) * cell_px
    py = (np.arange(gh)[:, None] - 1 + rng.random((gh, gw))) * cell_px
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ci, cj = (yy // cell_px).astype(int) + 1, (xx // cell_px).astype(int) + 1
    f1 = np.full((h, w), 1e9, np.float32)
    f2 = np.full((h, w), 1e9, np.float32)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ii, jj = ci + di, cj + dj
            d = np.hypot(xx - px[ii, jj], yy - py[ii, jj])
            f2 = np.where(d < f1, f1, np.minimum(f2, d))
            f1 = np.minimum(f1, d)
    return np.clip(1 - (f2 - f1) / 1.6, 0, 1)


def paint_canvas(side):
    cv = Canvas()
    P = [p for p in FEAT.get("panels", []) if p["side"] == side]
    # boards in the lower panels: a V-groove every 0.3 studs, the boards slightly uneven, a grain
    grain = value_noise(CH, CW, 6)
    grain_v = np.asarray(Image.fromarray((grain * 255).astype(np.uint8)).resize((CW, CH // 1)), np.float32) / 255
    for p in P:
        xa, ya, xb, yb = p["rect"]
        ia, ib, ja, jb = int(cpx(xa)), int(cpx(xb)), int(cpy(yb)), int(cpy(ya))
        if p["kind"] in ("boards", "leafboards", "plainboards"):
            xs = (np.arange(ia, ib) / PPU + CX0 - xa) / 0.3
            frac = xs - np.floor(xs)
            groove = np.clip(1 - np.minimum(frac, 1 - frac) / 0.09, 0, 1) ** 1.5
            board = np.floor(xs)
            lift = ((board * 7.31) % 1.0) * 0.006
            stretch = np.asarray(Image.fromarray((value_noise(64, ib - ia, 3) * 255).astype(np.uint8)).resize((ib - ia, jb - ja)), np.float32) / 255
            cv.height[ja:jb, ia:ib] += (-0.035 * groove + lift)[None, :] + 0.004 * stretch
            # dirt gathers in the grooves, more low down
            yfac = np.linspace(0.3, 1.0, jb - ja)[:, None]
            cv.dirt[ja:jb, ia:ib] = np.maximum(cv.dirt[ja:jb, ia:ib], 0.55 * groove[None, :] * yfac)
        # pinstripe inside the bead and a dark shadow under the bead's lower run (lined panels only)
        inset = 0.36
        lined = p["kind"] in ("boards", "upper", "eaves", "crest")
        for (qa, qb, qc, qd) in ((xa + inset, ya + inset, xb - inset, ya + inset + 0.035), (xa + inset, yb - inset - 0.035, xb - inset, yb - inset),
                                 (xa + inset, ya + inset, xa + inset + 0.035, yb - inset), (xb - inset - 0.035, ya + inset, xb - inset, yb - inset)):
            if lined:
                cv.pin[int(cpy(qd)) : int(cpy(qb)) + 1, int(cpx(qa)) : int(cpx(qc)) + 1] = 1
        # the namesake's double gilt lining: a fine gold line either side of the pinstripe
        if lined and SPEC["name"] == "LastTrainOut":
            for gi in (inset - 0.1, inset + 0.12):
                for (qa, qb, qc, qd) in ((xa + gi, ya + gi, xb - gi, ya + gi + 0.03), (xa + gi, yb - gi - 0.03, xb - gi, yb - gi),
                                         (xa + gi, ya + gi, xa + gi + 0.03, yb - gi), (xb - gi - 0.03, ya + gi, xb - gi, yb - gi)):
                    cv.gild[int(cpy(qd)) : int(cpy(qb)) + 1, int(cpx(qa)) : int(cpx(qc)) + 1] = 1
        # chips on the moulding's corners and lower edge (feet, buckets, luggage)
        for cxp, cyp in ((xa, ya), (xb, ya), (xa, yb), (xb, yb)):
            for _ in range(rng.integers(1, 4)):
                r = rng.uniform(1.5, 5)
                cv.add("chip", cpx(cxp + rng.uniform(-0.12, 0.12)) - r, cpy(cyp + rng.uniform(-0.12, 0.12)) - r, blob(r))
        if p["kind"] in ("boards", "leafboards", "plainboards"):
            for _ in range(int((xb - xa) * 2)):
                r = rng.uniform(1, 3.5)
                cv.add("chip", cpx(rng.uniform(xa, xb)) - r, cpy(ya + rng.uniform(-0.1, 0.25)) - r, blob(r))
        # gilt corner ornaments in the upper panels: a scroll and a dot
        if p["kind"] == "upper":
            img = Image.new("L", (ib - ia, jb - ja), 0)
            d = ImageDraw.Draw(img)
            m = int(0.48 * PPU)
            r = int(0.22 * PPU)
            W_, H_ = ib - ia, jb - ja
            for cxp, cyp, a0 in ((m, m, 0), (W_ - m, m, 90), (W_ - m, H_ - m, 180), (m, H_ - m, 270)):
                d.arc((cxp - r, cyp - r, cxp + r, cyp + r), a0, a0 + 90, fill=255, width=3)
                d.arc((cxp - r // 2, cyp - r // 2, cxp + r // 2, cyp + r // 2), a0 + 180, a0 + 330, fill=255, width=2)
                d.ellipse((cxp - 3, cyp - 3, cxp + 3, cyp + 3), fill=255)
            # a small lozenge at the centre top
            cxm, cym = W_ // 2, m
            d.polygon([(cxm, cym - 9), (cxm + 14, cym), (cxm, cym + 9), (cxm - 14, cym)], outline=255, width=2)
            g = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255
            cv.gild[ja:jb, ia:ib] = np.maximum(cv.gild[ja:jb, ia:ib], g)
        # paint crazing in the sunny upper and eaves panels
        if p["kind"] in ("upper", "eaves", "leaf", "leafboards", "plain") and ib - ia > 8 and jb - ja > 8:
            # fine and patchy: the old varnish has crazed only where the sun sits longest
            cr = voronoi_cracks(jb - ja, ib - ia, int(0.1 * PPU)) ** 2
            patch = value_noise(jb - ja, ib - ia, 36)
            mask = np.clip((patch - 0.55) * 5, 0, 1)
            cv.craze[ja:jb, ia:ib] = np.maximum(cv.craze[ja:jb, ia:ib], cr * mask * 0.7)
            cv.height[ja:jb, ia:ib] -= 0.0018 * cr * mask
    # rain streaks under every ledge, longer and darker under the window sills
    for L in FEAT.get("ledges", []):
        if L["side"] != side:
            continue
        a, b = L["x"]
        y = L["y"]
        dens = 7 if (b - a) < 5 else 5
        for _ in range(int((b - a) * dens)):
            x = rng.uniform(a, b)
            ln = rng.uniform(0.25, 1.4) * (1.6 if L.get("iron") else 1.0)
            s = streak(ln * PPU, rng.uniform(0.6, 2.2), 0.4) * rng.uniform(0.35, 0.9)
            cv.add("rust" if L.get("iron") else "rain", cpx(x) - s.shape[1] / 2, cpy(y), s)
    for w in FEAT.get("windows", []):
        if w["side"] != side:
            continue
        for _ in range(26):
            x = w["x"] + rng.uniform(-2.0, 2.0)
            s = streak(rng.uniform(0.8, 2.6) * PPU, rng.uniform(0.8, 2.6), 0.5) * rng.uniform(0.5, 1.0)
            cv.add("rain", cpx(x) - s.shape[1] / 2, cpy(3.2), s)
    # rust weeping from every rivet and bolt, and a halo round it
    for r in FEAT.get("rivets", []):
        if r["side"] != side:
            continue
        if rng.random() < 0.55:
            s = streak(rng.uniform(0.15, 0.9) * PPU, rng.uniform(0.6, 1.4), 0.2) * rng.uniform(0.4, 1.0)
            cv.add("rust", cpx(r["x"]) - s.shape[1] / 2, cpy(r["y"]) + 2, s)
        hb = blob(rng.uniform(4, 8), 0.8) * rng.uniform(0.3, 0.7)
        cv.add("rust", cpx(r["x"]) - hb.shape[1] / 2, cpy(r["y"]) - hb.shape[0] / 2, hb)
    for s_ in FEAT.get("straps", []):
        if s_["side"] != side:
            continue
        a, b = s_["x"]
        for _ in range(10):
            s = streak(rng.uniform(0.3, 1.2) * PPU, rng.uniform(1, 2.5), 0.3) * 0.7
            x = rng.choice([a - 0.02, b + 0.02])
            cv.add("rust", cpx(x) - s.shape[1] / 2, cpy(rng.uniform(0.6, 8.0)), s)
    # soot under the cornice (smoke rolls back off the roof), streaky
    yy = np.arange(CH)[:, None] / PPU
    yv = CY1 - yy
    t = np.clip((yv - 6.6) / (8.6 - 6.6), 0, 1) ** 1.6
    cols = value_noise(32, CW, 6)[0][None, :]
    soot = t * (0.45 + 0.55 * cols)
    cv.soot = np.maximum(cv.soot, soot.astype(np.float32) * np.ones((CH, 1), np.float32))
    # plume of soot over each lamp's chimney
    for L in FEAT.get("lamps", []):
        if L["side"] != side:
            continue
        h, w = int(1.2 * PPU), int(1.0 * PPU)
        py, px = np.mgrid[0:h, 0:w].astype(np.float32)
        u = (px - w / 2) / (w / 2)
        v = 1 - py / h  # 0 at the lamp top, 1 at the cornice
        plume = np.exp(-(u / (0.25 + 0.5 * v)) ** 2) * (1 - v * 0.4)
        cv.add("soot", cpx(L["x"]) - w / 2, cpy(L["y"] + 0.3) - h, plume.astype(np.float32) * 0.9)
    # spray off the wheels along the skirt, worst over the bogies and at the step
    t = np.clip((1.3 - yv) / 2.2, 0, 1)
    cv.spray = np.maximum(cv.spray, (t ** 1.3 * (0.5 + 0.5 * value_noise(CH, CW, 20))).astype(np.float32))
    for bx in SPEC.get("bogies", (x0 + 3.4, x1 - 3.4)):
        for _ in range(500):
            x = bx + rng.normal(0, 1.8)
            y = -1.5 + abs(rng.normal(0, 1.0))
            r = rng.uniform(0.6, 2.4)
            cv.add("spray", cpx(x) - r, cpy(y) - r, blob(r, 0.3) * rng.uniform(0.3, 0.8))
    # hands and boots: round the doors, the step and the grab rails
    for d in FEAT.get("doorEdges", []):
        if d["side"] != side:
            continue
        for ex in d["x"]:
            for _ in range(70):
                x = ex + rng.normal(0, 0.25)
                y = rng.uniform(2.4, 5.4)
                ln = rng.uniform(0.05, 0.35) * PPU
                ang = rng.uniform(-0.6, 0.6)
                img = Image.new("L", (int(ln) + 4, int(ln) + 4), 0)
                ImageDraw.Draw(img).line((2, 2 + ln * (0.5 - 0.5 * math.sin(ang)), 2 + ln * math.cos(ang), 2 + ln * (0.5 + 0.5 * math.sin(ang))), fill=255, width=1)
                g = np.asarray(img, np.float32) / 255 * rng.uniform(0.3, 0.8)
                cv.add("scuff", cpx(x), cpy(y), g)
            for _ in range(12):
                r = rng.uniform(1.5, 4.5)
                cv.add("chip", cpx(ex + rng.normal(0, 0.12)) - r, cpy(rng.uniform(0.4, 6.8)) - r, blob(r))
    for st in FEAT.get("steps", []):
        if st["side"] != side:
            continue
        a, b = st["x"]
        for _ in range(60):
            x = rng.uniform(a, b)
            y = rng.uniform(-0.1, 0.9)
            w = rng.uniform(0.1, 0.45) * PPU
            g = np.asarray(Image.new("L", (int(w), 6), 0), np.float32)
            g[2:4, :] = 1
            g = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1)), np.float32) / 255
            cv.add("scuff", cpx(x), cpy(y), g * rng.uniform(0.3, 0.7))
        span = (int(cpy(1.0)), int(cpy(-1.6)), int(cpx(a - 0.4)), int(cpx(b + 0.4)))
        cv.dirt[span[0] : span[1], span[2] : span[3]] = np.maximum(cv.dirt[span[0] : span[1], span[2] : span[3]], 0.35)
    for g_ in FEAT.get("grips", []):
        if g_["side"] != side:
            continue
        ya, yb = g_["y"]
        j0, j1 = int(cpy(4.6)), int(cpy(2.2))
        i0, i1 = int(cpx(g_["x"] - 0.12)), int(cpx(g_["x"] + 0.12))
        prof = np.sin(np.linspace(0, math.pi, j1 - j0))[:, None]
        cv.polish[j0:j1, i0:i1] = np.maximum(cv.polish[j0:j1, i0:i1], prof)
        # greasy hand marks on the paint either side of the rail
        for _ in range(30):
            r = rng.uniform(3, 7)
            cv.add("scuff", cpx(g_["x"] + rng.normal(0, 0.18)) - r, cpy(rng.uniform(2.4, 4.6)) - r, blob(r, 0.6) * 0.25)
    # name boards: a little soot over the top edge
    for b in FEAT.get("boards", []):
        if b["side"] != side:
            continue
    # the crest: a gilt garter round a dark field, a star and the monogram, a buckle at the foot
    for cr in FEAT.get("crests", []):
        if cr["side"] != side:
            continue
        R = int(cr["r"] * PPU)
        S = 2 * R + 8
        g, f = Image.new("L", (S, S), 0), Image.new("L", (S, S), 0)
        dg, df = ImageDraw.Draw(g), ImageDraw.Draw(f)
        c0 = S // 2
        ring = max(3, R // 5)
        dg.ellipse((c0 - R, c0 - R, c0 + R, c0 + R), outline=255, width=3)
        dg.ellipse((c0 - R + ring, c0 - R + ring, c0 + R - ring, c0 + R - ring), outline=255, width=2)
        df.ellipse((c0 - R + 2, c0 - R + 2, c0 + R - 2, c0 + R - 2), fill=150)
        df.ellipse((c0 - R + ring, c0 - R + ring, c0 + R - ring, c0 + R - ring), fill=255)
        for k in range(24):  # studs round the garter
            a = 2 * math.pi * k / 24
            rr = R - ring / 2
            dg.ellipse((c0 + rr * math.cos(a) - 1.5, c0 + rr * math.sin(a) - 1.5, c0 + rr * math.cos(a) + 1.5, c0 + rr * math.sin(a) + 1.5), fill=255)
        dg.rectangle((c0 - ring, c0 + R - ring - 2, c0 + ring, c0 + R + 2), outline=255, width=2)
        ri = R - ring - 4
        star = [(c0 + (ri * 0.42 if k % 2 == 0 else ri * 0.16) * math.sin(math.pi * k / 4), c0 - ri * 0.3 - (ri * 0.42 if k % 2 == 0 else ri * 0.16) * math.cos(math.pi * k / 4)) for k in range(8)]
        dg.polygon(star, fill=255)
        mono = font("Merriweather-Regular.ttf", max(8, int(ri * 0.5)))
        if mono:
            dg.text((c0, c0 + ri * 0.38), "LTO", fill=255, font=mono, anchor="mm")
        gg = np.asarray(g.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255
        ff = np.asarray(f.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
        if side < 0:
            gg, ff = gg[:, ::-1], ff[:, ::-1]
        cv.add("gild", cpx(cr["x"]) - S / 2, cpy(cr["y"]) - S / 2, gg)
        cv.add("pin", cpx(cr["x"]) - S / 2, cpy(cr["y"]) - S / 2, ff * 0.7)
    # stencilled lettering: worn off-white paint, rubbed through in patches (the far side reads mirrored in x)
    for st in FEAT.get("stencils", []):
        if st["side"] != side:
            continue
        hp = int(st["h"] * PPU)
        fnt = font("Oswald-Bold.ttf", int(hp * 1.3))
        if fnt is None:
            continue
        l, t, r, b = fnt.getbbox(st["text"])
        img = Image.new("L", (r - l + 8, b - t + 8), 0)
        ImageDraw.Draw(img).text((4 - l, 4 - t), st["text"], fill=255, font=fnt)
        img = img.resize((max(1, int(img.width * hp / img.height)), hp))
        a = np.asarray(img.filter(ImageFilter.GaussianBlur(0.5)), np.float32) / 255
        a = a * np.clip(0.55 + 0.9 * value_noise(*a.shape, 5), 0, 1)
        if side < 0:
            a = a[:, ::-1]
        cv.add("stencil", cpx(st["x"]) - a.shape[1] / 2, cpy(st["y"]) - a.shape[0] / 2, a)
    # sign-written lettering (the tender's name): gilt, shaded to the lower right, letter-spaced
    for lt in FEAT.get("letters", []):
        if lt["side"] != side:
            continue
        hp = int(lt["h"] * PPU)
        fnt = font("Merriweather-Bold.ttf", int(hp * 1.4)) or font("Merriweather-Regular.ttf", int(hp * 1.4))
        if fnt is None:
            continue
        text = "  ".join(" ".join(lt["text"]).split("   "))
        l, t, r, b = fnt.getbbox(text)
        sh = max(2, int(0.07 * PPU))
        W_, H_ = r - l + 8 + sh, b - t + 8 + sh
        g, d = Image.new("L", (W_, H_), 0), Image.new("L", (W_, H_), 0)
        ImageDraw.Draw(g).text((4 - l, 4 - t), text, fill=255, font=fnt)
        ImageDraw.Draw(d).text((4 - l + sh, 4 - t + sh), text, fill=255, font=fnt)
        scale = min(hp / (b - t), lt.get("w", 99) * PPU / W_)  # no wider than the panel allows
        size = (max(1, int(W_ * scale)), max(1, int(H_ * scale)))
        ga = np.asarray(g.resize(size, Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.5)), np.float32) / 255
        da = np.asarray(d.resize(size, Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
        da = np.clip(da - ga, 0, 1)
        if side < 0:
            ga, da = ga[:, ::-1], da[:, ::-1]
        cv.add("gild", cpx(lt["x"]) - ga.shape[1] / 2, cpy(lt["y"]) - ga.shape[0] / 2, ga)
        cv.add("pin", cpx(lt["x"]) - da.shape[1] / 2, cpy(lt["y"]) - da.shape[0] / 2, da * 0.9)
    # scorch: soot thrown round the forge's stovepipe and the doors, with spark burns in it
    for sc in FEAT.get("scorch", []):
        if sc["side"] != side:
            continue
        rp = int(sc["r"] * PPU)
        py, px = np.mgrid[-rp:rp, -rp:rp].astype(np.float32)
        d = np.sqrt(px * px + py * py) / rp
        haze = np.clip(1 - d, 0, 1) ** 1.4 * (0.5 + 0.5 * value_noise(2 * rp, 2 * rp, 10))
        cv.add("soot", cpx(sc["x"]) - rp, cpy(sc["y"]) - rp, haze.astype(np.float32) * 0.85)
        for _ in range(sc["n"]):
            r = rng.uniform(1.5, 4)
            cv.add("soot", cpx(sc["x"] + rng.normal(0, sc["r"] * 0.5)) - r, cpy(sc["y"] + rng.normal(0, sc["r"] * 0.5)) - r, blob(r, 0.4))
            cv.add("chip", cpx(sc["x"] + rng.normal(0, sc["r"] * 0.6)) - r / 2, cpy(sc["y"] + rng.normal(0, sc["r"] * 0.6)) - r / 2, blob(r / 2) * 0.6)
    # every chip dents the paint a hair
    cv.height -= 0.004 * np.clip(cv.chip, 0, 1)
    cv.height -= 0.002 * np.clip(cv.scuff, 0, 1)
    for k in Canvas.LAYERS:
        if k != "height":
            setattr(cv, k, np.clip(getattr(cv, k), 0, 1))
    return cv


canvases = {s: paint_canvas(s) for s in (1, -1)}
print("canvases painted", CW, CH)
out = {"geom": np.array([CX0, CX1, CY0, CY1, PPU], np.float64)}
for s, cv in canvases.items():
    for k in Canvas.LAYERS:
        out[f"{k}{s}"] = getattr(cv, k) if k == "height" else (getattr(cv, k) * 255).astype(np.uint8)
np.savez_compressed(sys.argv[2], **out)
if DEBUG:
    for s, cv in canvases.items():
        dbg = np.dstack([cv.rain + cv.soot, cv.rust + cv.gild, cv.pin + cv.chip + cv.scuff]).clip(0, 1)
        Image.fromarray((dbg * 255).astype(np.uint8)).save(os.path.join(DEBUG, f"canvas{s}.png"))
        h = cv.height
        Image.fromarray(((h - h.min()) / (np.ptp(h) + 1e-6) * 255).astype(np.uint8)).save(os.path.join(DEBUG, f"height{s}.png"))

