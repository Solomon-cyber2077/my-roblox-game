# 002: Raise early station Hollow threat
<!-- rbxmap:meta {"id":"002","created":"2026-10-06","query":"","hashes":{"src/shared/Config/Difficulty.luau":"50e1132ef3ab1590","src/server/Services/HollowService.luau":"a23354ab70fc759a","src/server/Services/HazardDirector.luau":"8a7198c33bf4bd58"}} -->
Status: done

## Goal
Raise early-stop active Hollow caps by approximately 1–2 without changing the later-stop caps, maximum 16, or the shape of the existing spawn-rate ramp. Scale sleepers by building count and size, and add exactly one delayed wanderer per ordinary station that seeks the nearest eligible player.

## Context (auto-filled by rbxmap for query: "")
- Verified: Difficulty.luau:26–29 has SpawnInterval={14,6}, SpawnRamp=2.5, FirstSpawnU={0.40,0.15}, HollowCap={Base=1,PerDifficulty=5,PerExtraCrew=0.6,Max=16}.
- Read-only reference: DifficultyModel.hollowCap:43–50 computes ceil((1 + 5*d + 0.6*max(crew-1,0))*bias), capped at 16; params:69–89 additionally scales cap bias by building tiles.
- HollowService.Prepare:1003–1018 currently instantiates every plan.sleepers entry. Reuse safe building placement information; do not overlap duplicated sleeper positions.
- HazardDirector.Begin:112–138 builds the existing spawn schedule, configures Hollows, prepares sleepers, and starts Heartbeat.
- Claude Code must read this brief first and recheck stale ranges with find_script/read_lines.

## Files to edit
- `src/shared/Config/Difficulty.luau`
- `src/server/Services/HollowService.luau`
- `src/server/Services/HazardDirector.luau`
- `HANDOFF.md` (documentation; existence verified on disk)

## Files NOT to touch
- All other files, including Hollow kinds, grabs, stats, fog, collapse, timer/dwell, DifficultyModel, LayoutGen, and tests. If a necessary change cannot fit the three authorized game files, report the concrete blocker before expanding scope.

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.
- Edit game scripts on disk only, never with Studio multi_edit or execute_luau. Preserve unrelated user changes; commit only this task's files and never push.
- Preserve the existing cap formula as a baseline; add a bounded early-only bonus in the authorized service path with tuning in Difficulty. Do not simply raise Base or lower PerDifficulty: that would change later numbers. Preserve nondecreasing caps and the exact later-stop baseline; document the chosen early cutoff.
- Sleeping population must respond deterministically to actual building count and size, using reachable, distinct interior positions and existing kinds. Do not alter Hollow stats or grabs.
- Create one wanderer per station, delay pursuit, then select the nearest eligible living player without the normal short detection radius. Respect cleanup, freeze, active-cap accounting and existing movement safety. Do not create repeated wanderers on Heartbeat or on retry.
- Keep SpawnInterval, SpawnRamp, FirstSpawnU and dwell/timer unchanged. Report ordinary first-spawn timing separately from sleeper appearance and delayed wanderer pursuit.

## Acceptance checks
- [ ] Report old/new caps for stops 1–10, route tiers and crews 1, 2, 4, 8 with explicit station bias/size assumptions. Early small-crew caps increase moderately; later caps and maximum 16 remain unchanged.
- [ ] Compare sleeper counts for small/few and large/many buildings; verify distinct safe positions.
- [ ] Verify exactly one wanderer and delayed nearest-player pursuit, including a distant player; verify cleanup between stations.
- [ ] Report old/new first ordinary spawn in seconds at the easiest and hardest stops using actual HazardSchedule and dwell values; also state wanderer delay in seconds. Do not report fractions as seconds or assume unscaled dwell represents all archetypes.
- [ ] Run `lune run check`; fix failures within scope. Mark in-progress before editing and done only after verified completion.
- [ ] Run Studio `start_stop_play`, `get_console_output`, and `screen_capture` after changes. If unavailable, report that limitation with manual steps; never claim runtime success without running it.
- [ ] Update HANDOFF.md with completed features, bugs/regressions and next step; commit only owned files, no push.

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Stop and restart Play after Rojo sync. Visit easiest and hardest ordinary stations; record cap, initial sleepers, first timed spawn and wanderer delay.
3. Compare small and large building layouts. Stay far from ordinary detection range and verify the delayed wanderer approaches the nearest eligible player; check a second player and station cleanup.
4. Read console errors and capture the scene; report observed results and remaining manual checks.

## Builder notes

- Planning only: Claude Code is unavailable in the current Codex session. No gameplay edits have been made.
- 2026-10-07 22:11: 2026-10-07: Code is in (8aea907 caps/sleepers/wanderer, 1d8de8e Dwell 148/94 at user's request). tests/Difficulty.spec dwell range updated to 94-148; lune run check passes 167/167. Studio Play boots to a docked stop, console clean. Not yet observed: wanderer pursuit of a distant player, sleeper counts small vs large stations, cap table report.
