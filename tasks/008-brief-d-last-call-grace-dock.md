# 008: Brief D: Last Call grace dock

Status: done

## Goal
At T-0 (run.station.departAt) the whistle blows and the station stays docked for a grace window (default 3s,
`Tuning.LastCallGrace`, with an `Enabled` flag) before it actually departs. Publish `run.station.lastCallEndsAt`
(Types.StationInfo). Everything that keyed off T-0 (hazard freeze, Hollow let-go, station motion, the warning clear,
the "RUN"/"DOORS CLOSING" alert) keys off the actual departure. Snapshot who is not aboard at T-0; anyone in that set
aboard when the stop resolves is a close call (`CrewTally.closeCalls`, for brief F). Cues: "LAST CALL" slate, a
lantern pulse at the train's platform doors, the watch/route-board dial counting the grace. Full brief: user's
"BRIEF D" (2026-10-07). Depends on 004 (A).

## Files to edit
- `src/shared/Config/Tuning.luau` (LastCallGrace table)
- `src/shared/Types.luau` (StationInfo.lastCallEndsAt, CrewTally.closeCalls)
- `src/shared/Logic/RunRules.luau` (grace sub-state, close calls)
- `src/shared/Logic/Economy.luau` (emptyTally.closeCalls)
- `src/server/Services/RunDirector.luau` (grace sub-state in Departure)
- `src/server/Services/CrewService.luau` (T-0 snapshot, close calls)
- `src/client/Controllers/DepartureClock.luau` (grace, Departed signal, clear at grace end)
- `src/client/Controllers/FxController.luau` (alert on actual departure)
- `src/client/Controllers/StationVisualsController.luau` (fog freeze at actual departure)
- `src/client/Controllers/TrainVisualsController.luau` (door lantern pulse)
- `src/client/UI/Hud.luau` (LAST CALL during grace)
- `tests/Run.spec.luau`
- `tasks/008-brief-d-last-call-grace-dock.md`, `HANDOFF.md`

## Files NOT to touch
- `src/shared/Config/Difficulty.luau` (task 002, uncommitted); task 006 hunks in Tuning/HANDOFF/HollowAnimator

## Acceptance checks
- [x] `lune run check` passes (with HEAD Difficulty.luau)
- [x] Studio: `start_stop_play`, `get_console_output` (no errors), `screen_capture` at T-0 of a stop

## Builder notes
- 2026-10-07 21:38: Built as a sub-state of Departure (grace + chase). lune run check passes with HEAD Difficulty.luau. Studio Play: T-0 LAST CALL slate, watch counts grace, station docked ~3.3s then departs with full chase; 6 door lamps on in grace; platform at T-0 -> aboard in grace logged a close call. Console clean. Deviation: left-behind check kept at chase close (see HANDOFF). Studio steps: Play, READY, Dev skip to Dwell, skip, warp to ~T-5, watch the doors.
