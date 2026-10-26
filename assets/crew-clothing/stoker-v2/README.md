# Stoker v2 — local design candidate

Compact work cap with parked goggles, olive chore jacket, leather apron and brass clasp.
References: [short waxed-canvas cap](https://randijofab.com/products/copy-of-waxed-canvas-cap),
[work apron construction](https://www.hardmill.com/collections/aprons). Original geometry and textures; no reference images embedded.

`before.png` and `front.png` compare the old and new source under matching camera framing and lighting, rendered at 50% (700 x 700). `back.png` and `profile.png` show fit from other angles. Blender previews approximate R6 appearance; they do not prove Roblox fit or shading.

Rebuild with Pillow Python running `tools/crew-clothing/stoker_textures.py`, then Blender 5.2 `--background --python tools/crew-clothing/stoker_v2.py`. The packed `stoker-v2.blend` preserves the candidate. `hat.obj` and `gear.obj` are unit-bounds exports; use manifest size/offset values after import. Combined mesh budget: 832 triangles.

Validation: Blender export/render succeeded; `lune run check` passed. Classic sheets are 585 x 559; pants torso is transparent and worn sheets retain alpha. No new Roblox IDs, uploads or production configuration changes. Previous uploaded Stoker remains untouched. Blender's optional OS thumbnail cache write was denied; renders and blend saved successfully.

HUMAN pending: upload both meshes through Studio 3D Importer and five images; record fresh image/mesh IDs separately from previous uploads. Bind only the isolated pilot, restart Play, read Output and capture screenshots. Check front/back UVs, cap/head clearance, clean/worn clothing, running, crouching, seated poses, and arm movement before enabling production. Current Creator Hub automation remains policy-blocked.
