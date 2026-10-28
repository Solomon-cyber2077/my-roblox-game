# Stoker v2 — local design candidate

Olive chore jacket, leather apron and brass clasp. Uniform hats are deferred; the cap source and upload are retained for later work, but current recipes and the pilot do not use them. `hat-free.png` is the current half-scale source render.
References: [short waxed-canvas cap](https://randijofab.com/products/copy-of-waxed-canvas-cap),
[work apron construction](https://www.hardmill.com/collections/aprons). Original geometry and textures; no reference images embedded.

`before.png` and `front.png` compare the old and new source under matching camera framing and lighting, rendered at 50% (700 x 700). `back.png` and `profile.png` show fit from other angles. Blender previews approximate R6 appearance; they do not prove Roblox fit or shading.

Rebuild with Pillow Python running `tools/crew-clothing/stoker_textures.py`, then Blender 5.2 `--background --python tools/crew-clothing/stoker_v2.py`. The packed `stoker-v2.blend` preserves the candidate. `hat.obj` and `gear.obj` are unit-bounds exports; use manifest size/offset values after import. Combined mesh budget: 832 triangles.

Validation (2026-10-27): all seven uploaded assets fetched successfully in the rebuilt Studio pilot. Apply, repeated apply, clean/worn creation and restoration checks passed. Optional accessory yaw is 180 degrees for both imported meshes; front/back/side screenshots confirmed goggles, brim, collar and pouch face forward. Production remains disabled. Existing wrong-type asset 203785492 still logs errors.

Full `lune run check` passed: 556 tests and visual audit clean.

Hat-free follow-up (2026-10-27): rebuilt and played the isolated pilot. All six remaining asset loads and Visual.Preload succeeded. Apply/Restore, original hat/hair/face accessory identity, head/face, joints and part properties passed. Front screenshot showed clean/worn clothes and torso gear with no generated hats. The existing wrong-type asset warning remains. See HANDOFF.md for the final full-check result.

Remaining release acceptance: torso gear fit during running/crouching/seated poses and arm movement, followed by multiplayer checks. Hats are excluded. Source before/after renders are retained above; Blender previews do not replace these engine checks.
