"""
Builds a car's exterior end to end (needs Lune, Blender 5.2 and Python with NumPy + Pillow):

  python tools/trainshell/pipeline.py <Car|Kit> [--size 4096] [--views ...] [--out dir] [--v1]

Round 2 (default for cars):
  1. lune: dump the primitive train (assets/train/train_dump.json)
  2. blender: model the car (build_car2.py: carved skin, hardware, gangway)
  3. python: paint the sign atlas and its normal map (make_sign2.py)
  4. python: paint the side wear canvases (canvas.py)
  5. blender: unwrap (weighted), bake and paint three 1024 atlases (bake2.py): one per side, and one
     for the ends, roof and underframe (Roblox caps a SurfaceAppearance map at 1024)
  6. blender: export the FBX for Studio's 3D Importer (export.py)
  7. blender: preview renders (preview.py) into docs/train-exterior/preview/
--v1 runs round 1 (build_car.py, make_sign.py, bake.py at 2048).

Outputs go to assets/train/ (or --out). See docs/train-exterior/README.md.
"""

import argparse
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(ROOT, "tools", "trainshell")
OUT = os.path.join(ROOT, "assets", "train")
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
SIGNS = {
    "GuardsVan": "GUARD'S VAN",
    "LastTrainOut": "LAST TRAIN OUT",
    "CrewSaloon": "CREW SALOON",
    "Workshop": "WORKSHOP",
    "Stores": "STORES",
}
NUMBERS = {"GuardsVan": 1, "LastTrainOut": 2, "CrewSaloon": 3, "Workshop": 4, "Stores": 5}


def fonts_dir():
    found = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")))
    return found[-1] if found else ""


def run(cmd):
    print(">", " ".join(cmd[:4]), "...")
    res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    lines = (res.stdout + res.stderr).splitlines()
    for line in lines:
        if line.startswith(("PART", "TOTAL", "DONE", "EXPORTED", "sign", "BAKE")) or "Error" in line or "Traceback" in line:
            print("  ", line)
    if res.returncode != 0:
        sys.exit(f"failed: {cmd[0]}")


def blender(script, *args, blend=None):
    # --python-expr runs first: no .blend1 backups next to the files we save
    cmd = [BLENDER, "-b"]
    cmd += [blend] if blend else ["--factory-startup"]
    cmd += ["--python-expr", "import bpy; bpy.context.preferences.filepaths.save_version = 0"]
    cmd += ["-P", os.path.join(TOOLS, script), "--", *args]
    run(cmd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("car")
    ap.add_argument("--size", type=int, default=0)
    ap.add_argument("--views", default="three_quarter,far,low,roof,platform,closeup")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--v1", action="store_true")
    ap.add_argument("--r2", action="store_true", help="the kit as round 2 built it")
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    dump = os.path.join(OUT, "train_dump.json")
    run(["lune", "run", "tools/trainshell/dump_train.luau", dump])
    if a.car == "Kit":
        blender("build_kit.py", OUT, *(["--v1"] if a.v1 else []), *(["--r2"] if a.r2 else []))
        if a.v1:
            blender("bake.py", OUT, "Kit", str(a.size or 1024), blend=os.path.join(OUT, "Kit.blend"))
        elif not a.r2:
            # round 3: the leaves are painted by cause like the cars (posed as a closed door on a
            # car side), and the bogie, wheels, rods and coal through bake2 too
            posed = os.path.join(OUT, "Kit_posed.blend")
            blender("kitpose.py", "car", OUT, posed, blend=os.path.join(OUT, "Kit.blend"))
            for atlas in ("Doors", "Kit"):
                run([sys.executable, os.path.join(TOOLS, "canvas.py"), os.path.join(OUT, f"{atlas}.json"), os.path.join(OUT, f"{atlas}_canvas.npz")])
            blender("bake2.py", OUT, "Doors", "2048", os.path.join(OUT, "Doors.json"), os.path.join(OUT, "Doors_canvas.npz"), blend=posed)
            blender("bake2.py", OUT, "Kit", "2048", os.path.join(OUT, "Kit.json"), os.path.join(OUT, "Kit_canvas.npz"), blend=os.path.join(OUT, "Doors_baked.blend"))
            blender("kitpose.py", "home", os.path.join(OUT, "Kit_baked.blend"), blend=os.path.join(OUT, "Kit_baked.blend"))
            os.remove(posed)
        else:
            # round 2: the door leaves have their own 1024 atlas, the bogie and wheel share another
            blender("bake.py", OUT, "Doors", "1024", blend=os.path.join(OUT, "Kit.blend"))
            blender("bake.py", OUT, "Kit", "1024", blend=os.path.join(OUT, "Doors_baked.blend"))
        blender("export.py", os.path.join(OUT, "Kit.fbx"), blend=os.path.join(OUT, "Kit_baked.blend"))
        return
    if not a.v1:
        j = os.path.join(out, f"{a.car}.json")
        blender("build_car2.py", dump, a.car, out)
        run([sys.executable, os.path.join(TOOLS, "make_sign2.py"), j, SIGNS[a.car], str(NUMBERS[a.car]), os.path.join(out, a.car), fonts_dir()])
        run([sys.executable, os.path.join(TOOLS, "canvas.py"), j, os.path.join(out, f"{a.car}_canvas.npz")])
        # each atlas bakes into the previous one's .blend, so the last holds every UV set
        blend = os.path.join(out, f"{a.car}.blend")
        for atlas in (f"{a.car}_P", f"{a.car}_N", a.car):
            blender("bake2.py", out, atlas, str(a.size or 2048), j, os.path.join(out, f"{a.car}_canvas.npz"), blend=blend)
            blend = os.path.join(out, f"{atlas}_baked.blend")
        blender("export.py", os.path.join(out, f"{a.car}.fbx"), blend=blend)
        previews(a, out)
        return
    blender("build_car.py", dump, a.car, OUT)
    run([sys.executable, os.path.join(TOOLS, "make_sign.py"), SIGNS[a.car], os.path.join(OUT, f"{a.car}_sign.png"), fonts_dir()])
    blender("bake.py", OUT, a.car, str(a.size or 2048), os.path.join(OUT, f"{a.car}.json"), blend=os.path.join(OUT, f"{a.car}.blend"))
    blender("export.py", os.path.join(OUT, f"{a.car}.fbx"), blend=os.path.join(OUT, f"{a.car}_baked.blend"))
    previews(a, OUT)


def previews(a, out):
    """Renders into docs/train-exterior/preview/ (the kit comes from assets/train)."""
    prev = os.path.join(ROOT, "docs", "train-exterior", "preview")
    os.makedirs(prev, exist_ok=True)
    for view in [v for v in a.views.split(",") if v]:
        blender(
            "preview.py", out, a.car, os.path.join(prev, f"{a.car}_{view}.png"), view,
            os.path.join(OUT, "Kit_baked.blend"), "Kit", blend=os.path.join(out, f"{a.car}_baked.blend"),
        )

main()
