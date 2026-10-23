# 015: Lobby idle prompt 1 contracts
<!-- rbxmap:meta {"id":"015","created":"2026-10-23","query":"","hashes":{}} -->
Status: done

## Goal
Verify lobby idle contracts and record eligibility, ownership and release checks before implementation.

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- UNVERIFIED docs/direction/2026-10-23-lobby-idle-contracts.md
- UNVERIFIED HANDOFF.md
- UNVERIFIED docs/direction/2026-10-23_lobby-idle-final.md

## Files NOT to touch
- All runtime scripts: this prompt is discovery and documentation only.

## Constraints
- Edit only the files listed above. Make on-disk edits only, never Studio edits.

## Acceptance checks
- [x] Record verified contracts, unverified integration boundaries, and eligibility matrix.
- [x] Owner song choice with listening samples is explicit in the final draft.
- [x] Baseline start_stop_play, get_console_output, screen_capture performed in isolated Studio.
- [x] Integrated lune run check passed exit 0 (53097e3 plus quiet-policy work in progress; session 20397).
- [x] Full project gate includes Rojo, Selene and StyLua.

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Use start_stop_play, get_console_output, screen_capture on the isolated lobby-idle-test instance; observe hall, player, and lobby UI; stop afterward.
3. Record existing errors separately. Runtime idle functionality belongs to later prompts.

## Builder notes

