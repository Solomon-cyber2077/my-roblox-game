# 003: Show route station type numeric danger and loot hazard hint
<!-- rbxmap:meta {"id":"003","created":"2026-10-07","query":"","hashes":{"src/client/UI/RouteVote.luau":"73841d64b2b189c3"}} -->
Status: done

## Goal
Update the route vote tickets to show each station's type name, its existing numeric danger level (`Danger 1`–`Danger 3`), and a short loot/hazard hint such as `Lots of coal, heavy fog`, while preserving the current vote UI styling and behavior.

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/client/UI/RouteVote.luau`
- `HANDOFF.md`

## Files NOT to touch
- `src/server/RouteGen.luau` (client route data already includes archetype and tier)
- Any other game or project files

## Constraints
- Edit only the files listed above, on disk; never edit through Studio.
- Keep the existing station name, distance/coal cost, selection state, and vote behavior.
- Derive the hint from `Stations.List[option.archetype].loot` and `.hazard` with deterministic tie handling and readable fallback wording.
- Preserve Terminus handling and existing ticket layout; make only minimal wrapping/spacing adjustments.
- Do not change voting rules, tie-breaks, junction logic, or danger values.

## Acceptance checks
- [ ] Each route option visibly includes its station type name and literal numeric danger label.
- [ ] Each option shows a concise loot/hazard hint when source values support one; long names and hints remain readable.
- [ ] Existing selected/voted states and Terminus presentation remain intact.
- [ ] `lune run check` passes.
- [ ] In Studio, restart Play after Rojo sync, inspect two or three options, and verify console output has no errors and the vote screen is visible in a screenshot.

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Open the route vote screen and inspect two or three options: confirm station type, `Danger 1`–`Danger 3`, distance/coal cost, and the hint line are visible and styled consistently.
3. Check a long station/hint, selected and voted states, and Terminus if available; confirm `get_console_output` reports no errors and capture the screen.
4. If Studio tools are unavailable, report that limitation and provide these manual steps instead of claiming runtime verification.

## Builder notes
 - 2026-10-07 00:08: Read this brief first, recheck stale ranges with `find_script`/`read_lines`, then mark in progress. `RouteGen.options` already exposes `archetype`, `tier`, `distanceKm`, and `hint`; no RouteGen edit is needed. Use existing `Stations` data to derive deterministic strongest loot and hazard wording, with neutral fallbacks. Commit only the listed files and do not push.
- 2026-10-07 19:49: Closed: superseded by 005 (Brief B), which shows station type, numeric danger and the loot/hazard hint on the new paper tickets.
