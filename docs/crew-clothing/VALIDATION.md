# Crew clothing validation and activation

Implementation spans all six Council prompts, but the feature is **not release complete**. `Enabled=false`, `WearEnabled=false`, zero upload IDs and `validated=false` intentionally prevent replacing live avatars with missing assets.

## Implemented

1. Existing R6 lifecycle, authoritative ShopEquip, profile dictionaries and Outfitter reused; no extra remote or wardrobe service.
2. Stoker Blender pilot, original classic textures and half-scale before/after renders; source exports and measured geometry manifest.
3. Server-owned selection, migration, asset preloading, stale-request invalidation, idempotent apply and original-instance restoration. Player hats, hair and face accessories are retained. Uniform hats are deferred; recipes contain torso gear only. R6 joints and hitboxes unchanged.
4. Five free identities and two record variants in the existing Uniform category. Invalid/unuploaded outfits cannot equip, including through developer unlocks.
5. Clean/worn baked textures; client reads authoritative run stationsCleared and phase. Wear begins after three departures, persists through respawn, clears at RunEnd/lobby/start phases, never enters saves. Both feature switches remain off.
6. Veteran Stoker: 25 lifetime stations departed; Terminus Conductor: one Long Line victory. Existing milestone reward/save path, with threshold and duplicate-grant tests.

## Recorded checks

- Blender exports and renders succeeded. One accessory per recipe, 440–616 triangles against limits of three accessories / 1,500 triangles. Headless geometry evidence does not establish Roblox fit.
- Studio start/console/screenshot/stop with feature gated: lobby loads, avatar intact, no new clothing errors. Existing warnings: unpublished DataStores/telemetry and wrong-type sound asset 203785492.
- Full check result is recorded in HANDOFF.md after the final run. Pure tests cover recipe rejection, migration, developer gate, free catalog entries, record thresholds/idempotence and wear resets. They do not execute Roblox content loading or rendering.

## HUMAN pending: asset upload and engine acceptance

1. Stoker v2 clothing, atlas and torso mesh are uploaded (IDs in `assets/crew-clothing/stoker-v2/upload-status.json`). Upload the remaining outfits' original classic sheets, atlas and `gear.obj` under the owner's account. Hats are excluded. Use template image IDs for ShirtTemplate/PantsTemplate, not catalog clothing product IDs. Confirm permissions for the experience.
2. Bind clean/worn shirt/pants and accessory mesh/texture IDs in Config/CrewClothing. OBJ geometry is normalized; config size/offset come from manifest. Verify Roblox front (-Z), UV orientation, dimensions and torso gear fit before marking each recipe validated. Importer rotation/scale must be checked against the render.
3. Validate Stoker first in an isolated Studio copy: idle/walk/run, every grab/struggle/pry pose, sitting, death, respawn, slow/failed preload, rapid A→B→A selection, profile load/reconnect, hair/face preservation and restoration. Confirm no duplicate instances, joint/hitbox changes or forbidden client equip. Then validate all other outfits.
4. Review Outfitter previews, locks, selection feedback and keyboard/controller/touch navigation. Check lantern-lit darkness, fog, distance and four different crew bodies for readable silhouettes and clipping.
5. Record four-client cold/warm asset-cache runs, transition timings, memory/instances and frame times on the target low-end device. Check stop-three wear, late join, respawn, outcome reset and next run. Enable WearEnabled only if those measurements pass; keep clean uniforms if it does not.
6. Enable clothing only after uploaded recipes pass, rerun `lune run check`, start/console/screenshot/stop and record the visual/performance evidence. Task 021 stays in-progress until these acceptance items are complete.

## Detail pass (2026-10-24)

Original Blender equipment adds neck-hung Stoker goggles and belt pouch, Brakeman utility pouches, Conductor lapels/watch chain, Trackwalker folded scarf, and Wayfarer satchel. Classic sheets add fabric grain, seams, reinforcement and restrained scuffs. No body or joint geometry changes. Front-facing cloth normals are explicit for single-sided rendering.

Compared `stoker-v1.png` with `stoker-after.png` and `lineup-v1.png` with `lineup-after.png` at half scale. The later render adds readable relief and distinct occupational details while retaining muted railway-workwear palettes. These are source-asset renders, not evidence of engine fit or performance. All seven outfits remain unvalidated until the upload/engine checklist above passes.
