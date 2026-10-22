# S2 handoff — speed ladder, stamina, carriers, glance

Branch: `codex/s2-speed-astra`. Worktree: `LTO-s2`. No S1 files or boot order changed.

## Completed
- Crew walks at 21 and sprints at 31. Hollow chase base is 25–26 across difficulty; pace remains ±6%. Stalker/Crawler chase multipliers are 1, Brute is 0.98. Lunge multipliers are 1.45/1.6/0, last 0.55 seconds, and retain the 3.5-second cooldown. Brute cannot lunge.
- Stamina remains 100, drain 18/s, regen 22/s after 0.9s, resume threshold 35%, winded 1.6s at 85%. Tests lock this envelope. Existing carrier penalties remain 15% duo / 35% solo: 17.85 / 13.65 studs/s. Carrying still blocks sprint; shared lantern, crate SafeLight exclusion, drop/recovery and Payroll code are unchanged.
- New pure `Logic/HollowSpeed` resolves production pursuit and lunges. Scripted Tier 1 / stop 2 Crawler uses absolute 24 chase / 40 lunge / 0.55s, bypassing pace, difficulty and legacy scripted ChaseScale. Its first clear, unlit, off-train target opportunity holds a Windup for at least 1.5s; occlusion/light/stun resets the warning. Normal distance/grace/strike rules remain; no forced grab.
- Hold Q / RB / touch LOOK for a view-only 150-degree glance, blending in/out over 0.18s. Camera offset is removed before movement input each frame. No root, movement or FOV write added. Glance is blocked in lobby, grabs, death, spectate, non-Custom cameras and text input; disabled bindings pass through to other actions. Focus loss clears it.
- LOOK is aligned above RUN using the existing touchTop layout, with an 8px gap; the watch lifts above it. Refreshed MAP.md and the worktree index.

## Numerical verification (model, not measured play)
| Normal chase | Difficulty 0 | Difficulty 1 |
| --- | --- | --- |
| Stalker / Crawler | 23.50–26.50 | 24.44–27.56 |
| Brute | 23.03–25.97 | 23.9512–27.0088 |

All kind/pace endpoints meet walk+2..6 at difficulty 0 and sprint-minus-at-least-3 at difficulty 1. Both carrier speeds are slower than every normal chase. Every non-Brute lunge exceeds sprint, including the slowest difficulty-0 Stalker (34.075).
A full stamina bar lasts 100/18 = 5.556s; ideal straight-line gain against the fastest normal chase is 19.111 studs. With one 0.55s lunge during that interval, ideal gains are 12.290 studs (Stalker) / 10.016 studs (Crawler). These exclude acceleration, pathing, collisions and strike range.

## Validation and remaining acceptance
- `lune run check`: PASS after the final code change; format, lint, strict types, unit specs and model audit passed (audit clean).
- Only `astra-s2.rbxl` (Rojo 34873) was playtested, then stopped. A run reached Abingdon Cross and DOORS OPEN. A discrete Q press/release caused no new console error. After the final input passthrough fix, a fresh lobby start and screen capture succeeded.
- Existing console warnings: DataStores unavailable; ThresholdController line 75 waiting for TrainVolumes; audio asset 203785492 type mismatch; cab-sill EditableMesh fixed-size limitation. No S2 script error observed. These warnings were not changed.
- Held-Q, controller and touch behavior are NOT runtime-verified. Available UI input sends discrete key presses; no held-key/controller injection was used. Actual chase/sprint distance and two-player carrier measurements are also pending. Do not treat numerical specs or smoke tests as those acceptance results.

## Next steps / manual Studio acceptance
1. In astra-s2.rbxl, restart Play after Rojo sync. Start a run, hold W then Q for >0.18s and release: view should turn 150 degrees and return while travel/root facing stay straight. Repeat during sprint; verify FOV unchanged by glance, and no glance in lobby/grab. Check spectate Q/RB still cycles.
2. Repeat with RB on a controller. Use phone/tablet emulation, hold LOOK, release and rotate viewport: LOOK must remain above RUN without overlap and the watch must stay clear.
3. On unobstructed ground, measure walk/sprint and each kind at difficulty 0/1 and pace extremes; compare with table. Measure full-bar sprint lead with and without a lunge. With two clients measure duo 17.85 and solo 13.65; verify sprint denial, lantern sharing, drop/recovery and Payroll.
4. S6 / Prompt 5 must schedule the Tier 1 stop-2 scripted Crawler; this session deliberately preserves the existing Tier 2 stop-1 encounter scheduler. Once wired, confirm 24/40 speeds and >=1.5s visible warning before pursuit; interrupt line of sight/light to verify reset, and confirm escape remains possible.

## S1 telemetry integration
`HollowService` has a one-line `-- S1 hook:` at completion of the first Crawler warning opportunity. Record this as an opportunity, never proof the player saw it. S1 owns telemetry wiring/config; none was added here. Useful future measurements: chase separation, full-bar sprint gain, carrier survival and glance use; wire through the S1 telemetry interface after merge.
