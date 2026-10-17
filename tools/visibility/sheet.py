"""
Contact sheet and numbers table for one harness run (system Python + Pillow):

    python tools/visibility/sheet.py <shots_dir> [--dim=45|25] [--only=<shot prefix>]

Writes <shots_dir>/sheet_<dim>.jpg (frames already at 0.5 scale) and <shots_dir>/gates.md:
per station, state, crew and view, the weakest must-see contrast at and inside the floor,
the weakest crew lantern, APL and lit share against the ceilings; then the slider range
the sweep supports (lowest floor passing must-see in the worst case at 45%, highest
passing the mood ceiling).
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thresholds as T  # noqa: E402

SHOTS = sys.argv[1]
DIM = next((a.split("=")[1] for a in sys.argv if a.startswith("--dim=")), "45")
ONLY = next((a.split("=")[1] for a in sys.argv if a.startswith("--only=")), None)
EXPORT = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--export=")), None)
TAG = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--tag=")), "")  # e.g. _fix1
with open(os.path.join(SHOTS, "results.json"), encoding="utf-8") as fh:
    run = json.load(fh)
APL, LIT = run["apl_ceiling"], run["lit_ceiling"]


def weakest(shot, dim, band=None):
    rows = [m for m in shot[dim]["must"] if band is None or m["band"] == band]
    return min(rows, key=lambda m: m["contrast"]) if rows else None


def crew_min(shot, dim):
    values = [c["lantern"] for c in shot[dim]["crew"] if c.get("lantern")]
    return min(values) if values else None


def verdict(shot, dim):
    w = weakest(shot, dim)
    must = w is None or w["contrast"] >= T.MUST_SEE_CONTRAST
    c = crew_min(shot, dim)
    crew = c is None or c >= T.CREW_CONTRAST
    mood = shot["apl"] <= APL and shot["lit"] <= LIT
    return must, crew, mood


def fmt(x, nd=2):
    return "-" if x is None else f"{x:.{nd}f}"


WHATIF = [s for s in run["shots"] if s.get("reach", 1) != 1]
CEIL = [s for s in run["shots"] if s["shot"].startswith("ceil_")]
SMOOTH = [s for s in run["shots"] if s.get("falloff") == "smooth"]
run["shots"] = [s for s in run["shots"] if s.get("reach", 1) == 1 and s not in CEIL and s not in SMOOTH]  # the game
shots = [s for s in run["shots"] if ONLY is None or s["shot"].startswith(ONLY)]
lines = [f"# Dim-screen gates ({DIM}% brightness, flare {T.FLARE:.0%}; office 5% in brackets)", "",
         f"Must-see >= {T.MUST_SEE_CONTRAST}:1, crew lantern >= {T.CREW_CONTRAST}:1, "
         f"APL <= {APL:.4f}, lit share <= {LIT:.3f} (horror upper quartile, refs.json).", "",
         "Must-see judges Tier A (hazards, near their lip) and Tier B (obstacles) from classify.py.", "",
         "| station | shot | weakest at floor | weakest inside | crew lantern min | APL | lit | must | crew | mood |",
         "|---|---|---|---|---|---|---|---|---|---|"]
for s in shots:
    at, ins = weakest(s, DIM, "at"), weakest(s, DIM, "inside")
    must, crew, mood = verdict(s, DIM)

    def cell(m):
        return "-" if m is None else f"{m['contrast']:.2f} [{m['office']:.2f}] {m['name']}"

    lines.append(f"| {s['label']} {s['station']} | {s['shot']} | {cell(at)} | {cell(ins)} | {fmt(crew_min(s, DIM))} | "
                 f"{s['apl']:.4f} | {s['lit']:.3f} | {'PASS' if must else 'FAIL'} | {'PASS' if crew else 'FAIL'} | "
                 f"{'PASS' if mood else 'FAIL'} |")

# the slider's range (45% only: the 25% pass is report-only). Minimum: reaction distance
# (thresholds.py), from the export's sprint speed and cone. Maximum: the highest floor up to
# which every brightest-lantern frame stays under the mood ceiling.
if DIM == "45" and EXPORT:
    with open(EXPORT, encoding="utf-8") as fh:
        game = json.load(fh)
    sprint = game["movement"]["sprint"]
    seconds = T.REACTION_S + T.STOP_S + T.LATENCY_S
    need = math.ceil(sprint * seconds)
    floor = game["visibility"]["radius"]
    cone, cone_perf = game["lantern"]["ConeRange"], game["visibility"]["budget"]["ConeRangePerformance"]
    radii = sorted({s["radius"] for s in run["shots"] if s["state"] == "bright"})
    high = None
    for r in radii:
        bright = [s for s in run["shots"] if s["radius"] == r and s["state"] == "bright"]
        if not all(verdict(s, "45")[2] for s in bright):
            break
        high = r
    lines += ["", "## Slider range", "",
              f"- reaction distance: sprint {sprint} studs/s x ({T.REACTION_S} + {T.STOP_S} + {T.LATENCY_S}) s"
              f" = {sprint * seconds:.1f} -> minimum {need} studs",
              f"- the default floor ({floor}) {'clears' if floor >= need else 'does NOT clear'} it all round;"
              f" the forward cone ({cone} Quality, {cone_perf} Performance)"
              f" {'clears' if cone >= need else 'does not clear'} / {'clears' if cone_perf >= need else 'does not clear'} it ahead",
              f"- mood ceiling holds (calm, brightest lantern, crew of 4, every view) up to: {high} "
              f"(swept {radii[0]}..{radii[-1]})"]

def gate_rows(title, rows, note):
    out = ["", f"## {title}", "", note, "",
           "| station | shot | weakest at floor | weakest inside | must |", "|---|---|---|---|---|"]
    for s in rows:
        at, ins = weakest(s, DIM, "at"), weakest(s, DIM, "inside")
        cell = lambda m: "-" if m is None else f"{m['contrast']:.2f} {m['name']}"  # noqa: E731
        out.append(f"| {s['label']} {s['station']} | {s['shot']} | {cell(at)} | {cell(ins)} | "
                   f"{'PASS' if verdict(s, DIM)[0] else 'FAIL'} |")
    return out


if SMOOTH:
    lines += gate_rows("Other falloff curve (1-(d/R)^2)^2: must-see", SMOOTH,
                       "Same shots, lights windowed by the brighter of the two common game curves.")
if CEIL:
    lines += gate_rows("What-if (not the game): every Tier A/B surface pure white", CEIL,
                       "The most albedo alone can do on the real ground and light: a FAIL here cannot be fixed by surfaces.")

# report only: does the fix leak past the pool? Tier A/B objects beyond 2x the floor still at 3:1
beyond = [b for s in shots if s["radius"] == run["shots"][0]["radius"] for b in s[DIM].get("beyond", [])]
if beyond:
    share = sum(b["contrast"] >= T.MUST_SEE_CONTRAST for b in beyond) / len(beyond)
    lines += ["", "## Dark beyond the pool (report only, no threshold)", "",
              f"- Tier A/B readings beyond 2x the floor at {T.MUST_SEE_CONTRAST}:1 or better: "
              f"{share:.1%} of {len(beyond)}"]
    for label in sorted({s["label"] for s in shots}):
        rows = [b for s in shots if s["label"] == label for b in s[DIM].get("beyond", [])]
        if rows:
            lines.append(f"  - {label}: {sum(b['contrast'] >= T.MUST_SEE_CONTRAST for b in rows) / len(rows):.1%} of {len(rows)}")
stand = [(s, s[DIM]["standin"]) for s in shots if s[DIM].get("standin")]
if stand:
    lines += ["", "## Monster stand-in at the floor's distance (report only)", "",
              "A 7-stud dark figure (not the game's Hollow) ahead at the floor radius, crew of 1, forward view.", ""]
    for s, m in stand:
        lines.append(f"- {s['label']} {s['shot']}: {m['contrast']:.2f}:1 at {m['distance']:.0f} studs ({m['px']} px)")

if WHATIF:
    lines += ["", "## What-if (not the game): lantern Range = floor x k, default floor", "",
              "| station | shot | weakest at floor | weakest inside | crew lantern min | APL | lit | must | crew | mood |",
              "|---|---|---|---|---|---|---|---|---|---|"]
    for s in WHATIF:
        at, ins = weakest(s, DIM, "at"), weakest(s, DIM, "inside")
        must, crew, mood = verdict(s, DIM)
        cell = lambda m: "-" if m is None else f"{m['contrast']:.2f} {m['name']}"  # noqa: E731
        lines.append(f"| {s['label']} {s['station']} | {s['shot']} | {cell(at)} | {cell(ins)} | {fmt(crew_min(s, DIM))} | "
                     f"{s['apl']:.4f} | {s['lit']:.3f} | {'PASS' if must else 'FAIL'} | {'PASS' if crew else 'FAIL'} | "
                     f"{'PASS' if mood else 'FAIL'} |")

with open(os.path.join(SHOTS, f"gates_{DIM}{TAG}.md"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")

# contact sheet: one row per (station, state, crew), three views across
groups = {}
for s in shots:
    if s["state"] == "bright" and s["radius"] != shots[0]["radius"]:
        continue  # the mood sweep is in the table, not on the sheet
    groups.setdefault((s["label"], s["radius"], s["state"] + ("/perf" if s.get("tier") == "perf" else ""),
                       s["crewCount"]), {})[s["view"]] = s
cols = ["fwd", "side", "back"]
w, h = T.WIDTH, T.HEIGHT
label_w = 150
sheet = Image.new("RGB", (label_w + w * len(cols), h * len(groups)), (18, 18, 20))
draw = ImageDraw.Draw(sheet)
for row, (key, views) in enumerate(sorted(groups.items(), key=lambda kv: (kv[0][0] != "early", kv[0][0] != "mid", kv[0][1], kv[0][2], kv[0][3]))):
    label, radius, state, crew = key
    draw.text((8, row * h + 8), f"{label}\nR{radius} {state}\ncrew {crew}", fill=(230, 230, 230))
    for c, view in enumerate(cols):
        s = views.get(view)
        if not s:
            continue
        img = Image.open(os.path.join(SHOTS, s["label"], f"{s['shot']}_{DIM}.png")).convert("RGB")
        sheet.paste(img, (label_w + c * w, row * h))
        must, crew_ok, mood = verdict(s, DIM)
        tag = f"{view} M{'+' if must else 'x'} C{'+' if crew_ok else 'x'} W{'+' if mood else 'x'}"
        draw.text((label_w + c * w + 6, row * h + 4), tag, fill=(255, 255, 255) if must and mood else (255, 90, 90))
sheet.save(os.path.join(SHOTS, f"sheet_{DIM}{TAG}.jpg"), quality=70)
print(os.path.join(SHOTS, f"sheet_{DIM}{TAG}.jpg"))
