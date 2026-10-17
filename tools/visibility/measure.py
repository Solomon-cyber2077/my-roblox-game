"""
Dim-screen render harness, part 2 of 2: turns render.py's linear frames into what a dim
phone shows, and measures the three gates. Runs in Blender's Python (OpenImageIO + numpy):

    blender -b --factory-startup --python tools/visibility/measure.py -- <shots_dir> <refs.json> <vis.json>

Per shot it applies, in the game's order: the Atmosphere haze (approximation), exposure,
the ColorCorrection grades Scenery/Sky exports (night + station grade), the dread grade and
vignette (UI/Overlay, at the chase's share), the rim Highlights (VisibilityController's pick),
then the dim device (linear * DIM, thresholds.py). It writes <shot>_45.png and _25.png (sRGB,
already 0.5 scale) and <shots_dir>/results.json; sheet.py makes the contact sheet and table.
"""

import glob
import json
import math
import os
import sys

import numpy as np
import OpenImageIO as oiio

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thresholds as T  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
SHOTS, REFS, EXPORT = argv[0], argv[1], argv[2]
with open(REFS, encoding="utf-8") as fh:
    refs = json.load(fh)
APL_CEILING, LIT_CEILING = refs["apl_ceiling"], refs["lit_ceiling"]
Y = np.array([0.2126, 0.7152, 0.0722])


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def rgb255(v):
    return to_lin(np.array(v, dtype=np.float64) / 255.0)


def pixels(path):
    return oiio.ImageBuf(path).get_pixels(oiio.FLOAT).astype(np.float64)


def read(path, camera):
    """The lit frame and its index and position passes (render.py writes all three)."""
    rgb = pixels(path)[..., :3]
    ids = pixels(path[:-4] + "_id.exr")
    pos = pixels(path[:-4] + "_pos.exr")
    sky = pos[..., 3] < 0.5
    depth = np.linalg.norm(pos[..., :3] - np.array(camera), axis=-1)
    depth[sky] = np.inf
    return {"rgb": rgb, "index": np.where(sky, 0, np.rint(ids[..., 0])).astype(np.int64), "pos": pos[..., :3], "depth": depth}


def dilate(mask, n):
    out = mask.copy()
    for _ in range(n):
        m = out.copy()
        m[1:, :] |= out[:-1, :]
        m[:-1, :] |= out[1:, :]
        m[:, 1:] |= out[:, :-1]
        m[:, :-1] |= out[:, 1:]
        out = m
    return out


def grade(display, g):
    """Roblox ColorCorrectionEffect on display values: brightness, contrast, saturation, tint."""
    out = display + g.get("brightness", 0)
    out = (out - 0.5) * (1 + g.get("contrast", 0)) + 0.5
    luma = (out @ Y)[..., None]
    out = luma + (out - luma) * (1 + g.get("saturation", 0))
    if "tint" in g:
        out = out * (np.array(g["tint"]) / 255.0)
    return np.clip(out, 0, 1)


def vignette(display, level, color, h, w):
    """UI/Overlay dread shade: four edge bands, opacity level*SHADE_MAX at the edge, 0 inside."""
    if level <= 0:
        return display
    ys = (np.arange(h) + 0.5) / h
    xs = (np.arange(w) + 0.5) / w
    out = display
    c = np.array(color) / 255.0
    bands = [
        np.clip(1 - ys / 0.34, 0, 1)[:, None] * np.ones((1, w)),
        np.clip(1 - (1 - ys) / 0.34, 0, 1)[:, None] * np.ones((1, w)),
        np.ones((h, 1)) * np.clip(1 - xs / 0.26, 0, 1)[None, :],
        np.ones((h, 1)) * np.clip(1 - (1 - xs) / 0.26, 0, 1)[None, :],
    ]
    for band in bands:
        a = (band * level)[..., None]
        out = out * (1 - a) + c * a
    return out


def contrast(a, b, flare):
    hi, lo = max(a, b), min(a, b)
    return (hi + flare) / (lo + flare)


def post(shot, info, vis):
    rgb, index, depth = shot["rgb"], shot["index"], shot["depth"]
    h, w = index.shape
    sky = info["sky"]
    # 1. haze toward the air colour (approximation, thresholds.HAZE_STUDS)
    air = rgb255(sky["atmosphere"]["color"]) * 0.3
    f = 1 - np.exp(-sky["atmosphere"]["density"] * np.minimum(depth, 5000) / T.HAZE_STUDS)
    rgb = rgb * (1 - f[..., None]) + air * f[..., None]
    # 2. exposure, 3. the sky's grades in display space
    rgb = rgb * 2 ** sky["exposure"]
    display = to_srgb(rgb)
    for g in sky["grades"]:
        display = grade(display, g)
    # 4. dread grade + vignette: a Hollow at DREAD_NEAR is full dread, the chase keeps a share
    chase = info["state"] in ("chase", "worst")
    level = (1.0 * vis["chaseShare"]) if chase else 0.0
    if level > 0:
        display = grade(display, {"saturation": -vis["desaturate"] * level})
        tint = np.array([1, 1, 1]) + (np.array(vis["shadeTint"]) / 255.0 - 1) * level
        display = display * tint
    display = vignette(display, level * vis["shadeMax"], vis["shadeColor"], h, w)
    # 5. rim Highlights on the nearest rim targets (DepthMode Occluded: their visible pixels)
    rim = np.isin(index, info["rims"])
    if rim.any():
        rc = np.array(vis["rimColor"]) / 255.0
        outline = dilate(rim, T.RIM_PIXELS) & ~rim
        a_out, a_fill = 1 - vis["rimOutline"], 1 - vis["rimFill"]
        display = np.where(outline[..., None], display * (1 - a_out) + rc * a_out, display)
        display = np.where(rim[..., None], display * (1 - a_fill) + rc * a_fill, display)
    return display


def measure(path, vis):
    with open(path[:-4] + ".json", encoding="utf-8") as fh:
        info = json.load(fh)
    shot = read(path, info["camera"])
    display = post(shot, info, vis)
    full = to_lin(display)  # linear light at full panel brightness
    lum_full = full @ Y
    index = shot["index"]
    pos = shot["pos"]
    root = info["root"]
    # horizontal distance from the player, Blender (x, y) = Roblox (x, -z)
    dist = np.hypot(pos[..., 0] - root[0], -pos[..., 1] - root[2])
    result = {k: info[k] for k in ("shot", "station", "label", "radius", "state", "view", "lantern")}
    result["reach"] = info.get("reach", 1)
    result["crewCount"] = len(info["crew"]) + 1
    for dim, tag in ((T.DIM_DEFAULT, "45"), (T.DIM_STRESS, "25")):
        lum = lum_full * dim
        out = (to_srgb(full * dim) * 255 + 0.5).astype(np.uint8)
        spec = oiio.ImageSpec(out.shape[1], out.shape[0], 3, oiio.UINT8)
        o = oiio.ImageOutput.create(path[:-4] + f"_{tag}.png")
        o.open(path[:-4] + f"_{tag}.png", spec)
        o.write_image(out)
        o.close()
        # gate 1: must-see, per target, in each band
        radius = info["radius"]
        must = []
        for key, target in info["targets"].items():
            obj = index == int(key)
            if not obj.any():
                continue
            for band_name, band in (("at", T.BAND_AT), ("inside", T.BAND_INSIDE)):
                m = obj & (dist >= band[0] * radius) & (dist < band[1] * radius)
                if m.sum() < T.MIN_PIXELS:
                    continue
                ring = dilate(m, T.RING) & ~obj
                if ring.sum() < T.MIN_PIXELS:
                    continue
                lo, lb = float(lum[m].mean()), float(lum[ring].mean())
                must.append({
                    "id": int(key), "name": target["name"], "kind": target["kind"], "band": band_name,
                    "px": int(m.sum()), "contrast": contrast(lo, lb, T.FLARE),
                    "office": contrast(lo, lb, T.FLARE_OFFICE), "L": lo, "Lbg": lb,
                })
        # gate 2: crew, lantern glass and silhouette beyond the floor
        crew = []
        for mate in info["crew"]:
            row = {"distance": mate.get("distance")}
            for part, idx in (("lantern", mate["lens"]), ("body", mate["body"])):
                m = index == idx
                if part == "lantern":
                    m = dilate(m, 1) & (index == idx)  # the glass itself
                if m.sum() == 0:
                    row[part] = None
                    continue
                ring = dilate(m, T.RING) & ~m & (index != mate["lens"]) & (index != mate["body"])
                row[part] = contrast(float(lum[m].mean()), float(lum[ring].mean()), T.FLARE)
                row[part + "Px"] = int(m.sum())
            crew.append(row)
        result[tag] = {"must": must, "crew": crew}
    # gate 3: mood, at full brightness (comparable with the reference frames)
    result["apl"] = float(lum_full.mean())
    result["lit"] = float((lum_full > T.LIT_LEVEL).mean())
    return result


def main():
    with open(EXPORT, encoding="utf-8") as fh:
        data = json.load(fh)
    rim = data["visibility"]["rim"]
    vis = dict(data["dread"], rimColor=rim["Color"], rimOutline=rim["Outline"], rimFill=rim["Fill"])
    results = []
    for path in sorted(glob.glob(os.path.join(SHOTS, "*", "*.exr"))):
        if path.endswith(("_id.exr", "_pos.exr")):
            continue
        results.append(measure(path, vis))
        print("MEASURED", results[-1]["label"], results[-1]["shot"], flush=True)
    with open(os.path.join(SHOTS, "results.json"), "w", encoding="utf-8") as fh:
        json.dump({"apl_ceiling": APL_CEILING, "lit_ceiling": LIT_CEILING, "shots": results}, fh)


main()
