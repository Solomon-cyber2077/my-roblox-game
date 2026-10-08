# 005: Brief B: paper tickets, stamps, countdown dial

Status: done

## Goal
Restyle the junction ballot as cream paper tickets (full + stub variants, reusable by briefs C, E, F) with a
wax danger seal and chalk tallies, an inked distance track, coal lumps in fives, voter stamps from
`run.route.votes`, a countdown dial synced to the junction timer (`run.phaseStartedAt`/`phaseEndsAt`), a punch
at lock-in, and HUD layout fixes. Supersedes task 003. Full brief: user's "BRIEF B" (2026-10-07).

## Files to edit
- `src/shared/Logic/TicketModel.luau` (new, pure)
- `tests/TicketModel.spec.luau` (new)
- `src/client/UI/Ticket.luau` (new)
- `src/client/UI/Stamp.luau` (new)
- `src/client/UI/RouteVote.luau`
- `src/client/UI/Hud.luau` (moon caption truncation)
- `src/client/Controllers/TrainCamController.luau` (chip spacing)
- `src/shared/Config/Audio.luau` (punch/stamp cues from existing licensed ids)
- `HANDOFF.md`

## Files NOT to touch
- `src/shared/Config/Difficulty.luau` (task 002, uncommitted)
- Server services: per-player votes and the tie-break are already in state / Logic/Vote

## Acceptance checks
- [ ] `lune run check` passes
- [ ] Studio: `start_stop_play`, `get_console_output` (no errors), `screen_capture` at the junction

## Builder notes
- 2026-10-07 19:59: Built. lune run check passes (with HEAD Difficulty.luau; task 002 WIP fails only the Dwell spec). Studio Play boots with no errors in the lobby; junction not reached (needs READY click). Studio steps: Play, READY, at the junction check tickets/stamps/dial/punch.
