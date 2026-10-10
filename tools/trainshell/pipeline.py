"""
Builds a car's exterior end to end (needs Lune, Blender 5.2 and Python with NumPy + Pillow):

  python tools/trainshell/pipeline.py <Car|Kit> [--size 2048] [--views three_quarter,far]

  1. lune: dump the primitive train (assets/train/train_dump.json)
  2. blender: model the car (build_car.py / build_kit.py)
  3. python: paint the name board (make_sign.py)
  4. blender: unwrap, bake and paint the maps (bake.py)
  5. blender: export the FBX for Studio's 3D Importer (export.py)
  6. blender: preview renders (preview.py) into docs/train-exterior/preview/

Outputs go to assets/train/. See docs/train-exterior/README.md.
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
    ap.add_argument("--views", default="three_quarter,far,low,roof")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    dump = os.path.join(OUT, "train_dump.json")
    run(["lune", "run", "tools/trainshell/dump_train.luau", dump])
    if a.car == "Kit":
        blender("build_kit.py", OUT)
        blender("bake.py", OUT, "Kit", str(a.size or 1024), blend=os.path.join(OUT, "Kit.blend"))
        blender("export.py", os.path.join(OUT, "Kit.fbx"), blend=os.path.join(OUT, "Kit_baked.blend"))
        return
    blender("build_car.py", dump, a.car, OUT)
    run([sys.executable, os.path.join(TOOLS, "make_sign.py"), SIGNS[a.car], os.path.join(OUT, f"{a.car}_sign.png"), fonts_dir()])
    blender("bake.py", OUT, a.car, str(a.size or 2048), os.path.join(OUT, f"{a.car}.json"), blend=os.path.join(OUT, f"{a.car}.blend"))
    blender("export.py", os.path.join(OUT, f"{a.car}.fbx"), blend=os.path.join(OUT, f"{a.car}_baked.blend"))
    prev = os.path.join(ROOT, "docs", "train-exterior", "preview")
    os.makedirs(prev, exist_ok=True)
    for view in [v for v in a.views.split(",") if v]:
        blender(
            "preview.py", OUT, a.car, os.path.join(prev, f"{a.car}_{view}.png"), view,
            os.path.join(OUT, "Kit_baked.blend"), "Kit", blend=os.path.join(OUT, f"{a.car}_baked.blend"),
        )


main()
