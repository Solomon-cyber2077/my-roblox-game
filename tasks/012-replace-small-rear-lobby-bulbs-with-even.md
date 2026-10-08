# 012: Replace small rear lobby bulbs with evenly spaced warm lamps
<!-- rbxmap:meta {"id":"012","created":"2026-10-08","query":"","hashes":{"src/server/Builders/LobbyBuilder.luau":"3100f73eef13a453"}} -->
Status: todo

## Goal
Replace the four tiny rear-wall globe sconces in LobbyBuilder (around lines 1479-1485) with evenly spaced, substantial period brass/iron shaded lamps spanning the full rear width, including both ends and the central seating/ticket/board area. Use soft warm cream light with overlapping ranges so rear seating, floor, posters and wall read clearly without saturated orange or changing the lobby's overall lighting character.

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/server/Builders/LobbyBuilder.luau`
- `HANDOFF.md` (read and update the verified handoff entry)

## Files NOT to touch
- Preserve ceiling, column, table lamps, and global lighting. Keep unrelated builder geometry and scripts unchanged.

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.

## Acceptance checks
- [ ] Four tiny rear wall bulbs are removed/replaced by evenly spaced substantial shaded warm lamps across the full back wall, including both ends.
- [ ] Lamp placement avoids the board, windows and posters; central seating/ticket/board area remains unobstructed.
- [ ] Rear seating, floor and posters are visibly illuminated by overlapping soft warm cream pools without saturated orange.
- [ ] `lune run check` passes (including Rojo, StyLua, selene, strict checks, tests and audit).

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. After Rojo sync, stop and restart Play. Inspect the rear lobby from center and both ends: confirm even lamp spacing, no overlaps with board/windows/posters, and readable rear seating/floor/posters with soft warm cream light.
3. Run `start_stop_play`, `get_console_output`, and `screen_capture` for the rear center and both ends. If Studio tools are unavailable, report exact manual steps and do not claim visual acceptance.

## Builder notes
Read this task first, recheck stale LobbyBuilder ranges 307-372, 547-612, and 1432-1497, then set status to in-progress. Make on-disk edits only through Rojo, preserve dirty changes, and set status to done only after all checks and Studio verification pass. Rear fill lamps around lines 599-609 may be redistributed locally if needed; leave ceiling/column/table lamps and global lighting intact. Commit only this task after checks pass; never push. This brief is prepared; implementation has not been run.
