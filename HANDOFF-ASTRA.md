# S5 handoff: bell, dwell and railing grasp (Prompt 4)

Branch `codex/s5-bell-astra`, worktree `LTO-s2`. Started by Astra (Codex), who ran out of usage mid-session; finished, tested and committed by Claude Code. Merged into `claude/last-train-out`; see HANDOFF.md for the full entry.

## Completed
- Bell: rope prompt in the crew saloon (TrainInterior), `TrainService.RingBell` (phase, alive, aboard, within 9 studs), `RunDirector.ShortenStop`: u over the original dwell, branches all (u >= 0.40, everyone living aboard) / half (u >= 0.60, at least ceil(living/2) aboard), departAt = min(departAt, now + 30) only if strictly shorter, Dwell ends at departAt - 15, startedAt and the hazard dwell kept, timed events cancelled, branch stored on the stop for `stop_resolved`. Village and Terminus have no bell. Logic/DepartureBell + spec (1-4 crew, both branches, idempotence).
- Stop clock B shipped: WalkReference 30, Search 80/60, WalkMargin 1.4, PerStop 3. Report: 47.57 / 33.85 / 40.09 / 41.09 min.
- Payroll reach: StationReach measures the payroll cell; specs hold its BFS route inside farWalk and the solo inequality at D0/D1, stops 1 and 10.
- Grasp: GraspService (Jump -> `Grasp` remote), one receipt snapshot of the server root and the nearest static GraspRail, Logic/RailingGrasp (reach 3 + 0.5 + min(closing x 0.1, 1.0); press estimate clamped 0-0.2 s for the window only; receipt <= chaseEnd + 0.2), Aboard credited at attachment and held until the departure resolves, 0.6 s hang + 0.5 s haul into the doorway, 0.5 s miss stumble with retry, left-behind line with the measured shortfall ("less than 0.1 stud short" under 0.1). CrewPoses hang/haul/fallShort, camera kick on Clutch. Telemetry grasp / grasp_shortfall (+ grasp_reach, grasp_press_offset diagnostics).

## Studio (astra-s2.rbxl)
- Bell at u ~ 0.45: clock 1:43 -> 0:29 ("all"), second pull refused (already_shortened).
- Grasp via Studio `grasp [studs]` (server holds the pose, then the normal attempt): 6 studs -> missed, shortfall 2.64, 0.5 s stumble; 2 studs -> caught (gap 2.39 <= 3.5), Hang 0.56 s, Haul 0.51 s, released inside the cab, stop cleared, BY A WHISKER / made it, no left-behind or fall.
- Minehead payroll path (PathfindingService): 435.5 studs (radius 1.6) / 448.7 (2.2), farWalk 720; solo return ~54.8 s against 175 s.
- Bugs found and fixed: the grasp rails were swapped out by TrainShell (now kept by name); a credited grasp could be undone by positionTick after release (now held until departure resolves).

## Pending
- Two-client latency matrix (0/50/100/200 ms) and real Jump/touch/gamepad presses: scripted client movement on the moving platform could not hold a pose for the receipt snapshot, so the network path is unverified.
- T-10 warning after a bell jump not observed separately (DepartureSchedule already returns only the latest milestone).
