# 007: Brief C: route board in the train interior

Status: done

## Goal
A wooden route board with a brass rail on the crew saloon's end wall by the Workshop door (car 2, platform
half, in place of one painting) hosting B's paper tickets as SurfaceGuis, a lantern above each ticket, a coal
gauge and a station clock (DepartureClock). Each ticket gets a client ProximityPrompt that fires the existing
`CastVote`. Near the board the screen tickets move onto it (the same Ticket handles are reparented, so nothing
shows twice); far away, in Train Camera or in another car they stay on screen. Lanterns brighten by vote share
in the route's danger colour, hover/focus nudges a lantern and swings the gauge, and at lock-in the loser's
lantern goes out. Full brief: user's "BRIEF C" (2026-10-07). Depends on 005 (B), playtested this session.

## Files to edit
- `src/server/Builders/TrainInterior.luau` (board footprint, static parts)
- `src/client/UI/RouteBoard.luau` (new: SurfaceGuis, prompts, lights, gauge, clock)
- `src/client/UI/RouteVote.luau` (hand ticket handles to the board, hide the screen copy)
- `tasks/007-brief-c-route-board-in-the-train-interior.md`
- `HANDOFF.md`

## Files NOT to touch
- `src/shared/Config/Difficulty.luau` (task 002, uncommitted)
- Server services and remotes: voting stays on the existing `CastVote`

## Acceptance checks
- [ ] `lune run check` passes (audit: no clashes, Train part/light budget)
- [ ] Studio: `start_stop_play`, `get_console_output` (no errors), `screen_capture` of the board at a junction

## Builder notes
- 2026-10-07 20:36: 2026-10-07: Built. Board 17 parts / 2 lights (Train 1598/22, audit clean). lune run check passes with HEAD Difficulty.luau (WIP fails only the Dwell spec). Studio Play: B tickets render at junction; at the board tickets move on (screen hidden), E prompt votes via CastVote, lantern 1 red 2.25 vs 0.30; 13 studs away and Train Camera return them to screen; lock-in flares winner (2.7), loser lantern out. Console clean. Studio steps: Play, READY, Dev skip to a Junction, stand by the Workshop door in the saloon, press E on a ticket.
