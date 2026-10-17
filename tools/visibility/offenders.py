"""
Must-see failures ranked by object family (system Python):

    python -I tools/visibility/offenders.py <shots_dir> <out.md> [--title=...]

Reads measure.py's results.json and, at 45% brightness with 1% flare (the gate: thresholds
.MUST_SEE_CONTRAST, at and just inside the floor, both graphics tiers, the game's falloff),
lists every family with a Tier A or B object under the bar: how many objects and how many
(object, shot) readings fail, and the range of their contrast. Tier A first, then by the
weakest reading. Tier C is never judged (classify.py).
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thresholds as T  # noqa: E402

SHOTS, OUT = sys.argv[1], sys.argv[2]
TITLE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--title=")), "Must-see offenders")
with open(os.path.join(SHOTS, "results.json"), encoding="utf-8") as fh:
    run = json.load(fh)

shots = [s for s in run["shots"] if s.get("reach", 1) == 1 and s.get("falloff", "linear") == "linear"
         and s["state"] != "bright" and not s["shot"].startswith("ceil_")]
fams = {}
for s in shots:
    for m in s["45"]["must"]:
        f = fams.setdefault((m.get("tier") or "?", m.get("family") or m["name"]), {
            "objects": set(), "fail_objects": set(), "readings": 0, "fails": 0, "lo": 9e9, "hi": 0,
            "stations": set(), "states": set()})
        key = (s["station"], m["id"])
        f["objects"].add(key)
        f["readings"] += 1
        if m["contrast"] < T.MUST_SEE_CONTRAST:
            f["fail_objects"].add(key)
            f["fails"] += 1
            f["lo"] = min(f["lo"], m["contrast"])
            f["hi"] = max(f["hi"], m["contrast"])
            f["stations"].add(s["station"])
            f["states"].add(s["state"] + ("/perf" if s.get("tier") == "perf" else ""))

rows = sorted(((k, v) for k, v in fams.items() if v["fails"]), key=lambda kv: (kv[0][0], kv[1]["lo"]))
passing = sorted(k[1] for k, v in fams.items() if not v["fails"])
lines = [f"# {TITLE} (45% brightness, flare {T.FLARE:.0%}, bar {T.MUST_SEE_CONTRAST}:1)", "",
         f"{len(shots)} shots (3 stations x calm/chase/worst x crew 1/4 x fwd/side/back x Quality/Performance), "
         "at and just inside the floor. Tiers from tools/visibility/classify.py (tiers.json).", "",
         "| order | tier | family | objects failing / seen | readings failing / taken | contrast range (failing) | stations | states |",
         "|---|---|---|---|---|---|---|---|"]
for n, ((tier, fam), v) in enumerate(rows, 1):
    lines.append(f"| {n} | {tier} | {fam} | {len(v['fail_objects'])} / {len(v['objects'])} | {v['fails']} / {v['readings']} | "
                 f"{v['lo']:.2f} - {v['hi']:.2f} | {', '.join(sorted(v['stations']))} | {', '.join(sorted(v['states']))} |")
lines += ["", f"Families judged with no failing reading: {', '.join(passing) if passing else 'none'}."]
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
print(OUT, len(rows), "failing families")
