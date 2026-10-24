# Crew Clothing System implementation brief

Status: implementation and source assets added; upload and engine acceptance pending. This brief is for the six design steps in build order. The source of truth is the current repository and `docs/FINAL-DESIGN.md`; the external blueprint link was unavailable during verification.

## Verified integration points

- `src/server/Services/CrewService.luau`: `buildR6` creates a classic R6 body, resets package body asset IDs, and currently preserves clothes, colours, and accessories. The clothing system must keep the visible R6 body, Motor6Ds, hitboxes, death behavior, and procedural animation.
- `src/server/Services/CosmeticService.luau`: `Start` owns deferred `CharacterAdded` application with a same-character guard and reapplies on `ProfileLoaded`/`ProfileChanged`. `Apply` owns the per-character `Cosmetics` folder, belt lantern, hat attachment, and hair visibility.
- `src/server/Services/ShopService.luau`: `ShopEquip` validates the submitted id through `Catalog.canUse`, saves `profile.equipped[category]`, then calls `CosmeticService.Apply` (or livery refresh). New uniform selection must follow this server-authoritative path and submit identifiers only.
- `src/server/Services/DataService.luau`: `reconcile` fills missing profile fields and runs migrations; `publish` exposes `owned`, `equipped`, `milestones`, and stats. Existing profile dictionaries can carry uniform ownership and selection without replacing the save system.
- `src/shared/Types.luau`: `Profile.owned` and `Profile.equipped` are string dictionaries. Add a type only if a new replicated shape is actually needed.
- `src/shared/Config/Cosmetics.luau`: current categories are Lantern, Headwear, Trail, and Livery. A Uniform category may be added deliberately; do not replace the NPC wardrobe in `Config/Outfits.luau` or `Builders/OutfitKit.luau`.
- `src/client/UI/Outfitter.luau`: existing card and `ViewportFrame` preview flow uses `CosmeticPreview`; extend it rather than creating a second locker.
- `src/server/Services/ProgressionService.luau`: milestone rewards already grant `reward.cosmetic`; existing `Config/Progression` record awards are the integration point for earned variants.

## Ownership and lifecycle

`CosmeticService` remains the single engine-side application owner. On character spawn, after the R6 rig has its parts, it applies the saved uniform id idempotently. On equip, the server validates ownership and unlock criteria, updates the existing profile, and reapplies the current character. A replaced character must never receive a stale application. Transient wear is run-scoped state and belongs in the existing state replication path; it must not be saved as an outfit recipe.

Pure recipe validation, unlock predicates, serialization, and wear-state selection belong in `src/shared/Config/CrewClothing.luau` and `src/shared/Logic/CrewClothing.luau`. Engine instance work belongs in the existing server visual/service modules. The client renders replicated state and previews only; it never chooses an owned item or authoritative tone.

## Migration and compatibility

Use `DataService.reconcile` and its existing migration hook to add absent uniform fields with safe defaults. Existing profiles must retain `owned`, `equipped`, milestones, stats, and all current cosmetic categories. Invalid or unavailable saved selections fall back to a validated free starter. Do not persist grime/wear or duplicate a second profile service. Migration tests must cover old profiles, missing nested fields, invalid ids, and repeat reconciliation.

## Scope by design step

1. Verify this brief and rehash task 021 if the file list changes.
2. Build one production-quality Stoker pilot: references, Blender model/refinement, classic clothing templates, up to three rigid accessories, ≤1,500 added triangles, source/export manifest, pose/grab/sit/death/fog/lantern checks. Track upload and texture IDs as HUMAN pending until uploaded and verified.
3. Integrate authoritative selection, respawn-safe application, persistence, validation, migration, and meaningful tests.
4. Extend the pilot to free Stoker, Brakeman, Conductor, Trackwalker, and Wayfarer identities with preview, equip feedback, touch/controller/keyboard support, and no gameplay statistics.
5. Prototype one restrained journey-wear treatment behind a feature gate. Derive it from authoritative run milestones, replicate small state changes, preserve within a run, and reset on a new run. Disable it if rendering or performance checks fail.
6. Add only two earned variants through existing progression and persistence. Grants are idempotent; defer Rank 50 variants until measured pacing supports them. Complete release validation and report remaining approvals.

## Planned files and dependencies

Planned additions are `src/shared/Config/CrewClothing.luau`, `src/shared/Logic/CrewClothing.luau`, `src/shared/Visual/CrewClothing.luau`, `tests/CrewClothing.spec.luau`, `tools/crew-clothing/build.py`, `assets/crew-clothing/`, and this documentation folder. Integration may touch `CosmeticService`, `ShopService`, `Cosmetics`, `CosmeticPreview`, `DataService`, `Types`, `Progression`, `Outfitter`, remotes, and state declarations only after their current symbols are rechecked. Rehash task 021 whenever the listed files change.

## Asset and validation gates

Every player-visible change requires railway-workwear and in-game lighting references first, Blender modeling or refinement, and before/after renders at 0.5 scale compared against those references. Use classic R6 Shirt/Pants where supported and keep the body visible. Do not add a cosmetic ForceField, layered-clothing dependency, shader assumption, or placeholder geometry. Mesh uploads are owner-authorized through Studio; the importer and classic texture uploads remain HUMAN pending. Until assets are uploaded and validated, the feature remains disabled and no engine validation is claimed.

Required checks for each completed prompt: on-disk edits only; `lune run check`; Studio `start_stop_play`, `get_console_output`, and `screen_capture`. Manual coverage must include all reachable poses, grabs, sitting, death, respawn, fog and lantern lighting, four-player transitions, reconnects, warm/cold asset caches, and low-end frame/instance measurements. Headless audits may establish structure and budgets only; Studio and player tests establish rendered readability, depth behavior, and preference.

## Current blockers and next step

Code, Blender sources, textures and renders are implemented. The gated Studio smoke check passed. See VALIDATION.md for upload, pose, input and four-client profiling acceptance that still prevents activation.
