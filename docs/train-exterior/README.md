# Train exterior

The train is still built from primitives by `Builders/TrainBuilder` (collision, interior, every name
the scripts look for). `Builders/TrainShell` then dresses it in Blender meshes listed in
`Config/TrainShell` and archives what they replace. `Config/TrainShell.Enabled = false` brings back
the old look. Read `INVENTORY.md` (what exists and what touches it) and `DESIGN_BIBLE.md` first.

## Making or changing a car

```
python tools/trainshell/pipeline.py Kit           # shared door leaves, bogie, wheel (1024 atlas)
python tools/trainshell/pipeline.py CrewSaloon    # a car: model, sign, bake 2048 atlas, FBX, previews
```

Needs Lune, Blender 5.2 and Python with NumPy and Pillow. Outputs land in `assets/train/`;
previews in `docs/train-exterior/preview/`. The car is measured from the primitive train
(`tools/trainshell/dump_train.luau`), so openings always line up with the interior.

To re-paint without moving UVs (they are baked into the uploaded meshes), run `bake.py` on the
`_baked.blend`: it keeps existing UVs.

## Uploading (Studio)

1. Home > Import (3D Importer) > the car's `.fbx`. Creator: the game's owner. Import.
   `export.py` turns the geometry 180 degrees about the vertical first because the importer turns it
   back; the meshes then sit in train space exactly. Read the new `MeshId`s, `Position`s (centre)
   and `Size`s, then delete the imported model from Workspace.
2. Serve `assets/train` (`python -m http.server 8765`) and upload the PNGs with the Studio MCP
   `upload_image`. It dedups by content: an unchanged map keeps its id.
3. Put the ids, centres and sizes in `assets/train/asset_ids.json`, then
   `python tools/trainshell/gen_config.py` and `stylua src`.

## Rules the meshes keep

- Skin outer face z = +-6.58; nothing in a door's slide zone stands proud of 6.64 below y 7.5;
  nothing beyond |z| 6.98 (original 6.92).
- Decorative meshes: CanCollide, CanQuery, CanTouch false. Collision stays on the primitives.
- One MeshPart per livery role (Body, Trim, Roof, Accent, Lamp) so `applyLivery` tints each;
  the colour map's alpha is the wear over that colour (AlphaMode Overlay).
