"""
Where each painted board and cast plate sits in a car's sign atlas (shared by build_car2.py, which
sets the UVs, and make_sign2.py, which paints the image). Pixels, origin top-left.
"""

W, H = 2048, 1024
GROUND = (2040, 1016)  # a plain dark texel for the faces nobody reads


def layout(labels):
    rects = {}
    y = 0
    for lab in labels:
        if lab["label"].startswith("board"):
            x0, y0, x1, y1 = lab["rect"]
            h = max(96, min(220, round(W * (y1 - y0) / (x1 - x0))))
            rects[lab["label"]] = (0, y, W, y + h)
            y += h + 8
    rects["builders"] = (0, y, 512, y + 307)
    rects["number"] = (520, y, 776, y + 128)
    if any(lab["label"] == "nameplate" for lab in labels):
        rects["nameplate"] = (784, y, 1684, y + 270)  # the engine's cast nameplate (3.0 x 0.9 studs)
    return rects


def uv_for(rect_px, u, v):
    """u, v in 0..1 over a label (v up) -> atlas UV (Blender: v up from the bottom)."""
    x0, y0, x1, y1 = rect_px
    px = x0 + u * (x1 - x0)
    py = y1 - v * (y1 - y0)
    return px / W, 1 - py / H
