"""Reference shot brightness bands (docs/FINAL-DESIGN.md Prompt 6, the lighting lock).

Measures each reference shot's mean relative luminance (sRGB decoded, Rec. 709 weights) and
compares it with docs/direction/reference/bands.json.

  python tools/refbands.py              check every shot in bands.json against its band
  python tools/refbands.py --write      record each shot's mean and a band of +-BAND around it
  python tools/refbands.py shot.jpg     measure one image (a new shot to compare by eye)

A mean in band says only that the overall level has not drifted. Local readability (edges,
obstacles, Hollow silhouettes) needs its own check; an average cannot certify it.
"""
import json
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
REF = ROOT / "docs" / "direction" / "reference"
BANDS = REF / "bands.json"
BAND = 0.2  # +-20% of the recorded mean


def linear(c: float) -> float:
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


LUT = [linear(i) for i in range(256)]


def mean_luminance(path: pathlib.Path) -> float:
    img = Image.open(path).convert("RGB")
    img.thumbnail((400, 400))
    raw = img.tobytes()
    total = 0.0
    for i in range(0, len(raw), 3):
        total += 0.2126 * LUT[raw[i]] + 0.7152 * LUT[raw[i + 1]] + 0.0722 * LUT[raw[i + 2]]
    return total / (len(raw) // 3)


def main() -> int:
    args = sys.argv[1:]
    if args and args[0] != "--write":
        for name in args:
            print(f"{name}: mean luminance {mean_luminance(pathlib.Path(name)):.4f}")
        return 0
    data = json.loads(BANDS.read_text()) if BANDS.exists() else {"shots": {}}
    if args and args[0] == "--write":
        for shot in sorted(REF.glob("*.jpg")):
            mean = mean_luminance(shot)
            entry = data["shots"].setdefault(shot.stem, {})
            entry.update({"file": shot.name, "mean": round(mean, 4),
                          "band": [round(mean * (1 - BAND), 4), round(mean * (1 + BAND), 4)]})
        BANDS.write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote {len(data['shots'])} bands to {BANDS}")
        return 0
    failed = 0
    for name, entry in data["shots"].items():
        mean = mean_luminance(REF / entry["file"])
        lo, hi = entry["band"]
        ok = lo <= mean <= hi
        failed += 0 if ok else 1
        print(f"{'ok  ' if ok else 'DRIFT'} {name}: {mean:.4f} (band {lo}-{hi})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
