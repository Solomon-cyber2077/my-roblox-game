# 011: Gently warm train interior lighting
<!-- rbxmap:meta {"id":"011","created":"2026-10-08","query":"","hashes":{"src/server/Builders/TrainBuilder.luau":"b3e55cd7f989eb84","src/server/Builders/TrainInterior.luau":"199bde7a307ddb8e"}} -->
Status: todo

## Goal
Make the train interior feel gently warmer, like the amber hanging lamps on the posts near the train, while keeping the change subtle and localized. The cars should read as comfortably warm inside without changing the exterior, global sky/atmosphere, lobby lighting, geometry, gameplay, or light brightness/range unless inspection shows a color-only adjustment cannot achieve the request.

## Context
- Verified `TrainBuilder.luau` lines 53-88 define `C.warm = 255,206,150` and `C.globe = 255,226,176`; ceiling PointLights around lines 950-974 use brightness 1.15 and range 18.
- Verified `TrainInterior.luau` lines 907-972: banker and lantern fixtures use `C.warm`; `BenchLamp` uses a paler `255,232,196` PointLight.
- Identify the exact nearby exterior post-lamp implementation with `find_script` and only its returned `read_lines` range. Inspect all `C.warm` usages before changing the shared constant so exterior lamps are not warmed accidentally.

## Files to edit
- `src/server/Builders/TrainBuilder.luau`
- `src/server/Builders/TrainInterior.luau`
- `HANDOFF.md` (handoff metadata only)

## Files NOT to touch
- Any game source file outside the two source files above, including shared config, Sky/Atmosphere, lobby lighting, tests, and Studio-only content.

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.
- Read this brief first, re-check stale ranges, set status in-progress/done, edit on disk only (never Studio), and preserve unrelated work.
- Prefer a modest amber color shift on interior lamp colors/fixtures; preserve brightness and range initially. Do not alter light counts, geometry, signals, or gameplay.
- Commit only this task's changes with a clear message; never push.

## Acceptance checks
- [ ] Inside each train car is visibly and gently warmer, with a hanging-post-lamp amber character, while adjacent exterior post lamps and global lighting remain unchanged.
- [ ] No harsh orange cast, blown highlights, altered brightness/range, geometry changes, or console errors.
- [ ] `lune run check` passes.
- [ ] `rbxmap check` passes (Rojo build, selene, StyLua) where installed.

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Restart Play after Rojo sync. Visit each train car, including banker/lantern fixtures and BenchLamp, and compare against nearby hanging post lamps from the same camera exposure.
3. Use `screen_capture` at 0.5 scale and `get_console_output`; confirm subtle interior warmth, unchanged exterior post lamps, and no new errors. If unavailable, report the limitation and manual steps instead of claiming visual acceptance.

## Builder notes
- Before editing, use `find_script` with plain words to locate the exterior post lamp, then read only its returned range (maximum 150 lines). Recheck all cited ranges before patching.
- After editing, run checks, then `start_stop_play`, `get_console_output`, and `screen_capture`. Mark done only after these checks and the visual comparison pass; otherwise leave in-progress with the precise blocker.
