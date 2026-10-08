# 004: Brief A: departure clock and warning cues
<!-- rbxmap:meta {"id":"004","created":"2026-10-07","query":"departure clock pocket watch warnings","hashes":{"src/client/UI/Hud.luau":"b2bbf27d89a793d0","src/server/Services/CarService.luau":"494e537848df5c96","src/server/Services/RunDirector.luau":"34fa0598a8745ed5","src/client/init.client.luau":"a53c88beef8ce151","src/client/UI/Overlay.luau":"ddbb821d1a19dc9e","src/shared/Config/Audio.luau":"406cee635ce38380","src/shared/Config/Tuning.luau":"763e1fddf8fb8c9d","src/client/Controllers/AudioController.luau":"46a105a61f5d66b0","src/client/Controllers/AtmosphereController.luau":"7725bda2a5fd14a9","src/client/Controllers/TrainVisualsController.luau":"1b180c662121365b"}} -->
Status: done

## Goal
Drive every stop countdown from one client DepartureClock that reads `run.station.departAt` (no second clock, no attributes), and add escalating warnings: a chalk slate at start/halfway/T-30, a ticking pocket watch at T-30, a faster tick, case shake and numerals at T-10, a 3D whistle from the locomotive, a steam burst at T-0, an additive amber grade and fog, edge pulses, and a Warnings SoundGroup with ambient ducking. Full brief: user's "BRIEF A" (2026-10-07).

## Context (auto-filled by rbxmap for query: "departure clock pocket watch warnings")
- StarterPlayer > StarterPlayerScripts > Client > UI > Hud — `src/client/UI/Hud.luau` lines 70-135 (Hud.mount)
- ServerScriptService > Server > Services > CarService — `src/server/Services/CarService.luau` lines 137-182 (depart)
- ServerScriptService > Server > Services > RunDirector — `src/server/Services/RunDirector.luau` lines 218-246 (Enter.Dwell)

## Files to edit
- `src/client/UI/Hud.luau`
- UNVERIFIED src/shared/Logic/DepartureSchedule.luau
- UNVERIFIED tests/DepartureSchedule.spec.luau
- UNVERIFIED src/client/Controllers/DepartureClock.luau
- `src/client/init.client.luau`
- `src/client/UI/Overlay.luau`
- `src/shared/Config/Audio.luau`
- `src/shared/Config/Tuning.luau`
- `src/client/Controllers/AudioController.luau`
- `src/client/Controllers/AtmosphereController.luau`
- `src/client/Controllers/TrainVisualsController.luau`
- UNVERIFIED HANDOFF.md

## Files NOT to touch
- `src/shared/Config/Difficulty.luau` (task 002, uncommitted)
- Server services (state already has dwell/startedAt/departAt)

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.

## Acceptance checks
- [ ] Warnings fire only from `departAt`; the pocket watch reads DepartureClock
- [ ] `lune run check` passes
- [ ] `rbxmap check` passes (rojo build, selene, stylua) where installed

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Start a run, reach a stop, use the dev console to shorten the dwell; watch the slate, the watch ticking at T-30/T-10 and the steam and whistle at T-0.

## Builder notes
- 2026-10-07 19:46: Built per brief A. No server change: state already carries dwell/startedAt/departAt. lune run check passes on HEAD+task files (main tree fails only Difficulty spec from task 002). Studio Play boots clean in lobby; a stop not reached. Manual: start a run, at a stop use dev 'warp' to near T-30, watch slate/tick/whistle/steam/grade.
