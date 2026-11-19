"""Write src/server/StokerLooks.model.json (one SurfaceAppearance per close-up piece) from the uploaded image ids.

  python looks_json.py <ids.json> <path to src/server/StokerLooks.model.json>

ids.json: { "head": { "color": 123, "normal": 456, "rough": 789 }, "jaw": { ... }, ... } using the piece names of
Config/BruteMeshes (eyes and embers are Neon and take none). HollowBuilder finds the folder as "StokerLooks" and
gives each piece its look in place of the plain TextureID, so sweat shines, soot stays matte and the folds and
pores of the normal map catch the light."""
import json
import sys
from pathlib import Path

ids = json.loads(Path(sys.argv[1]).read_text())
children = []
for name, m in sorted(ids.items()):
    props = {"ColorMap": f"rbxassetid://{m['color']}"}
    if m.get("normal"):
        props["NormalMap"] = f"rbxassetid://{m['normal']}"
    if m.get("rough"):
        props["RoughnessMap"] = f"rbxassetid://{m['rough']}"
    children.append({"name": name, "className": "SurfaceAppearance", "properties": props})
Path(sys.argv[2]).write_text(json.dumps({"className": "Folder", "children": children}, indent=1) + "\n", encoding="utf-8")
print("wrote", sys.argv[2], len(children), "looks")
