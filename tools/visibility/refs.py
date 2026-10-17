"""
Anchors the mood ceiling ("Walmart" limit) in real frames:

    python tools/visibility/refs.py <refs_dir> <out refs.json>

<refs_dir> holds the horror reference frames, named <steam app id>_<n>.jpg (the store
screenshots of Outlast 238320, Darkwood 274520 and Alan Wake 108710, fetched at 600x338 from
store.steampowered.com/api/appdetails?appids=<id>&filters=screenshots). The lobby captures in
docs/compare/ are the "too bright" end: before_lobby_hall.jpg is the hall that was called
"like a Walmart".

Per frame: APL (mean linear luminance at full brightness) and the lit share (pixels above
mid-grey, thresholds.LIT_LEVEL). The ceilings are the horror frames' upper quartile:
store screenshots are picked to be seen, so they run brighter than play; a station frame
brighter than three in four of them is no longer the horror tone.
"""

import glob
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thresholds as T  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAMES = {"238320": "Outlast", "274520": "Darkwood", "108710": "Alan Wake"}


def stats(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    lum = lin @ np.array([0.2126, 0.7152, 0.0722])
    return float(lum.mean()), float((lum > T.LIT_LEVEL).mean())


def main():
    src, out = sys.argv[1], sys.argv[2]
    frames = []
    for path in sorted(glob.glob(os.path.join(src, "*.jpg"))):
        game = GAMES.get(os.path.basename(path).split("_")[0])
        if game:
            apl, lit = stats(path)
            frames.append({"game": game, "file": os.path.basename(path), "apl": apl, "lit": lit})
    lobby = []
    for name in ("before_lobby_hall.jpg", "after_lobby_hall.jpg"):
        apl, lit = stats(os.path.join(ROOT, "docs", "compare", name))
        lobby.append({"file": name, "apl": apl, "lit": lit})
    apl = np.array([f["apl"] for f in frames])
    lit = np.array([f["lit"] for f in frames])
    result = {
        "apl_ceiling": float(np.percentile(apl, 75)),
        "lit_ceiling": float(np.percentile(lit, 75)),
        "horror": {g: {"apl_median": float(np.median([f["apl"] for f in frames if f["game"] == g])),
                       "lit_median": float(np.median([f["lit"] for f in frames if f["game"] == g])),
                       "frames": sum(1 for f in frames if f["game"] == g)} for g in GAMES.values()},
        "lobby": lobby,
        "frames": frames,
    }
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=1)
    print(json.dumps({k: v for k, v in result.items() if k != "frames"}, indent=1))


main()
