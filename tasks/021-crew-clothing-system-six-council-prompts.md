# 021: Crew Clothing System: six Council prompts
<!-- rbxmap:meta {"id":"021","created":"2026-10-24","query":"","hashes":{"src/shared/Config/CrewClothing.luau":"287699bff9c86bff","src/shared/Logic/CrewClothing.luau":"d04730973f202975","src/shared/Visual/CrewClothing.luau":"68f4a6dc7d7eddf3","src/shared/Config/Cosmetics.luau":"9c613d26fcb8d25e","src/shared/Config/Progression.luau":"520066e061d36d85","src/shared/Logic/Catalog.luau":"49940ec929139fe9","src/server/Services/CosmeticService.luau":"02e2af58dd1a0adb","src/server/Services/DataService.luau":"39e4a680342584d0","src/shared/Visual/CosmeticPreview.luau":"d6174d7e8e2a57b0","src/client/UI/Outfitter.luau":"2ff001158fc30b36","src/client/Controllers/CrewClothingController.luau":"7aa1930ab8120ce3","src/client/init.client.luau":"3d8182fd6ce9a03e"}} -->
Status: in-progress

## Goal
Implement the six Council Crew Clothing System prompts. Asset-bound features remain disabled until real uploaded assets pass Studio validation.

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `docs/crew-clothing/IMPLEMENTATION.md`
- `docs/crew-clothing/REFERENCES.md`
- `docs/crew-clothing/VALIDATION.md`
- `HANDOFF.md`
- `src/shared/Config/CrewClothing.luau` (new)
- `src/shared/Logic/CrewClothing.luau` (new)
- `src/shared/Visual/CrewClothing.luau` (new)
- `src/shared/Config/Cosmetics.luau`
- `src/shared/Config/Progression.luau`
- `src/shared/Logic/Catalog.luau`
- `src/server/Services/CosmeticService.luau`
- `src/server/Services/DataService.luau`
- `src/shared/Visual/CosmeticPreview.luau`
- `src/client/UI/Outfitter.luau`
- `src/client/Controllers/CrewClothingController.luau` (new)
- `src/client/init.client.luau`
- `tests/CrewClothing.spec.luau` (new)
- `tools/crew-clothing/build.py` (new)
- `tools/crew-clothing/textures.py` (new)
- `assets/crew-clothing/` (new sources, exports, manifest, renders)

## Files NOT to touch
- Existing unrelated dirty files, NPC Config/Outfits and Builders/OutfitKit.

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.

## Acceptance checks
- [ ] `lune run check` passes.
- [ ] Seven recipes, server validation, safe migration and original avatar retained when assets unavailable.
- [ ] Blender sources/exports and 0.5-scale before/after renders; asset ids and engine-validation gaps explicit.
- [ ] `start_stop_play`, `get_console_output`, `screen_capture`; report unavailable checks honestly.

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Test equip, respawn, sitting, grabs, death, fog/lantern views and reconnects after binding validated assets. Profile four-client transitions with cold/warm cache. Do not enable wear until profiling passes.

## Builder notes
- 2026-10-24 10:26: Implemented all six code/source-asset workstreams on disk. Source renders reviewed at 50%; seven recipes use one hat each, 440–616 triangles. Upload IDs remain zero, validated/Enabled/WearEnabled false. Studio start/console/screenshot/stop: avatar retained, no clothing errors; existing DataStore/telemetry and sound 203785492 warnings. Remaining HUMAN acceptance: uploads, R6 pose/grab/sit/death/respawn/UI/device checks and four-client cold/warm profiling; see docs/crew-clothing/VALIDATION.md. Task remains in-progress.
- 2026-10-24 10:27: Final validation: lune run check passed, 553 tests / 0 failures, strict/lint/format and visual audit clean. Studio smoke repeated after final production edits; no new errors. Code/source-asset checkpoint ready; feature remains disabled pending documented HUMAN engine acceptance.
