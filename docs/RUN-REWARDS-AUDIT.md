# Run, departure and reward paths (launch hardening, step 1)

Audit of the code as it stands on 2026-10-29, as the base for steps 2-4 (stop rewards once, departure cap,
stop-five cash-out). Everything here was read from src; nothing was changed in game code.

## Run flow
- `Services/RunDirector` owns the 11 phases: Lobby, Countdown, Boarding, Junction, Cruise, Arrival, Dwell,
  LastCall, Departure, Terminus, RunEnd. `tick()` moves on when `state.endsAt` passes; `RunRules` holds the
  phase rules shared with the client.
- A run is started by `LobbyService` through `RunDirector.Launch(crew)` in the same server. There is no
  TeleportService, matchmaking, quota or reconnect code anywhere in src.
- Route length is Short (5 stops) or Long (10) (`Tuning.Run.Routes`, `Logic/Routes`), chosen per run.
- Join in progress already exists: `CrewService.SpawnPendingJoiners()` at each Dwell, up to stop
  `Tuning.Run.JoinInProgressMaxStation` (6).

## Clocks at a stop
| Clock | Where | Value |
|---|---|---|
| Arrival | `Tuning.Run.ArrivalSeconds` | 10 s |
| Doors open (dwell) | `DifficultyModel.dwell` from `Difficulty.StopClock` | search 80→60 s by difficulty + 0.5 s per building tile (cap 90) × archetype multiplier + 2 × far walk × 1.4 + 3 s per stop after the first |
| Departure warnings | `Tuning.Departure` (`Logic/DepartureSchedule`, `Controllers/DepartureClock`) | 30 s bell + low whistle, 10 s escalated tick + long whistle, halfway reminder on stops ≥ 60 s |
| Last Call | `Tuning.Run.LastCallSeconds` | 15 s before T-0 |
| Grace after T-0 | `Tuning.LastCallGrace` | 3 s docked, then `depart()` |
| Chase window | `HazardParams.chaseWindow` | per stop |

- The dwell is fixed when the doors open (`Enter.Dwell` sets `departAt = startedAt + dwell`). Nothing a player
  does lengthens it. The only change is the departure bell (`RunDirector.ShortenStop`, `Logic/DepartureBell`),
  which can only bring departure forward.
- `RunDirector.ExtendPhase` is called only by `BreakdownService` while the train is stopped or limping between
  stops; it does not touch a docked stop.
- So the server already owns a hard maximum: an idle player, an open bag or an undeposited load cannot hold
  the train. What is missing for step 3 is a **minimum** dwell (the bell has its own eligibility rules, but no
  30 s floor) and a check that the 10 s warning reads on a phone.

## Departure outcome
- `Exit.Departure` → `CrewService.ResolveDeparture()` marks anyone not aboard as left behind (cause
  `LeftBehind`) and returns close calls. The stop counts as cleared if anyone is alive; the last of the crew left
  behind ends the run there as Wiped.
- `CrewService` credits `tally.stationsDeparted += 1` to every member who is Aboard at that moment.

## Rewards: what pays and when
All Brass and XP are paid **once, at RunEnd**, by `ProgressionService.PayRun` (`Logic/Economy.payout`):

| Line | Amount (`Tuning.Economy`) | Earned during run? |
|---|---|---|
| Stations departed alive | 6 Brass each | yes, `tally.stationsDeparted` |
| Coal delivered | 2 per 10 | yes, tally |
| Parts delivered | 2 per 5 | yes, tally |
| Relics banked | relic Brass | yes, tally |
| Flare rescues | 10 each | yes, tally |
| Terminus | 80 aboard / 40 if the crew won without you | Victory only |
| XP | that base Brass + 25 per run, + haul XP (`HaulService.Settle`) | at RunEnd |
| Tier bonus, daily first-run ×2 (cap 400), solo charter ×0.6, charter daily cap 1500 | modifiers | at RunEnd |
| Milestones | Brass/cosmetics from `Config/Progression` | inside the same `DataService.Update` |

Findings that matter for steps 2 and 4:
1. **A disconnect forfeits the whole run.** `CrewService`'s `PlayerRemoving` drops the member and its tally;
   `CrewService.Tallies()` only returns players still in the server. Brass already earned (stations, coal,
   relics, rescues) is lost.
2. **Death keeps the tally** until RunEnd (the member stays in `members`), so a dead player who stays to watch is
   paid; one who leaves is not.
3. There is **no per-stop grant** today, so there is nothing that can double-pay yet. Step 2 should add the
   grant key (run id + stop) at the point it starts paying per stop, not before.
4. Stats (`runs`, `stationsDeparted`, `bestStation`, ...) are also only written at RunEnd, so a leaver loses
   those too.
5. The daily first-run bonus is decided per payout; if step 2 pays per stop, decide whether the ×2 applies to
   each grant or to the run total, or it will be spent on stop 1's small grant.
6. `HaulService` settles the haul (trophies, valuables, haul XP) only at RunEnd; the payroll keepsake stats
   only count on Victory. A leaver is removed as a payroll carrier (`Payroll.leave`), and gets no haul XP.

## Events (durable)
`TelemetryService` is the only caller of AnalyticsService and already writes every call to a DataStore sink
(`Logic/TelemetrySink`, flushed every `SinkFlushSeconds`, on leaving and at shutdown; dev `telemetry dump`).
Run and stop outcomes are covered:

| Brief asks for | Existing event |
|---|---|
| Starts | `run_started`, `run_joined` (incl. join in progress) |
| Stops | `stop_resolved` (stop, outcome, bell), `stop_archetype`, `stop_timing` (doors-open seconds), `player_stop_resolved` |
| Departures | `stop_timing`, `player_eliminated` with cause `LeftBehind`, bell field on `stop_resolved` |
| Endings | `run_ended`, `run_progress`, `player_run_outcome`, `session_ended` (phase at leave), `quit_after_outcome` |
| Cash-outs | none yet: add in step 4 (`player_cashed_out`, fields Stop, Device, CrewSize) |

No new event was added in this step: the only missing one, cash-out, has nothing to report until step 4 exists.
Adding it to `Config/Telemetry.Events` must keep each event under 8,000 field combinations
(`tests/Telemetry.spec` checks this).

## Open questions carried forward
- Step 2: pay per stop at `Exit.Departure` (what was earned that stop) and keep the Terminus/tier/daily
  modifiers at RunEnd, or keep one RunEnd payout and also pay it on `PlayerRemoving`? The second is smaller and
  fixes finding 1 without changing the economy.
- Step 4: the Short Line already ends at 5 stops. A stop-five cash-out on the Long Line reuses the same payout
  path for one player; the run card (`LobbyService.OpenCard`) is the natural safe state.
