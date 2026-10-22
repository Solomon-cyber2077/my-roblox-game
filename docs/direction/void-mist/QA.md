# Void mist QA checklist (VM7), 2026-10-22

Adapted from The Council's prompt 07 (run 20261022-131445). Every line runs with Studio and the Dev console
(`game.ReplicatedStorage.Remotes.Dev:FireServer("...")` from the client command bar; commands in README.md).
To reach a docked stop: `Remotes.SetReady:FireServer(true)`, then `skip` five times about 3 s apart.
Set `god` for the look and feel lines, never for damage lines. Status as of this commit; evidence is in the
commit messages of VM2-VM7 and in this folder.

| # | Check | How | Status |
|---|---|---|---|
| 1 | Walking into the rail stops flush, no jitter | `mist outlines`, walk straight at a back rail | PASS: stops 0.7 studs from the rail centre |
| 2 | Jumping at the rail never crosses it | hold jump while walking at the rail | PASS: peak +8.8 studs, closest 0.46 |
| 3 | The current slows a walk over the zone, at 0, 45 and 90 degrees | `mist debug` (label: depth, cap, outward speed) | PASS at Incoming Replication Lag 0: 21 to 3.6 studs/s over 6 studs, largest frame step 1.6; 45 deg keeps sideways speed; 90 deg (along) untouched |
| 4 | Same at Incoming Replication Lag 0.2 and 0.3 | Studio Settings > Network > Incoming Replication Lag | HUMAN pending |
| 5 | 4-player Start Server, everyone runs along all edges for 5 minutes: 0 rescues | Test > Start (4 players), then `mist summary` | HUMAN pending |
| 6 | A fall past the rail is rescued once, 15 damage, one `mist_rescue` telemetry line | teleport a root below KillDrop on the server | PASS: back at the last safe spot, 15.0 HP lost, one line |
| 7 | Edge damage: none for an in-and-out under the grace; about 8 HP/s after it | stand in the zone (not god) | PASS: 0 for 0.4 s; 18 HP over 3 s |
| 8 | Fog damage unchanged; never stacked with edge damage | stand in the edge zone after the fog front reaches it | Code path only (MistService skips the edge tick past the fog front); not timed in Studio |
| 9 | Idle reaction is local only | two clients (Test > Start, 2 players), one idles at the rail | HUMAN pending (structural: no remote, client only) |
| 10 | Idle: nothing for 12 s, then thicker mist and a louder hum over 3 s; any input reverts in 0.5 s | stand 8 studs from a rail, hands off | PASS: veil 0.30 to 0.15, hum 0.218 to 0.320; back within 0.6 s of a step |
| 11 | Preset screenshots at ClockTime 2, 14 and 20 | `sky 26`, `sky 14`, `sky 20` with `mist preset Teal/Slate/Amber` | Teal at all three and Amber at 20 captured (this folder, iteration shots at 26); Slate checked by colour value only |
| 12 | Presets recolour live | `mist preset Amber` | PASS: half-way at 1 s, exact at 3 s |
| 13 | Proximity tint comes in near the edge | stand 25, 14, 10, 6, 2 studs from a side rail | PASS: red channel x0.80 between 14 and 6 studs (preset tint 0.78) |
| 14 | MicroProfiler: mist under 0.15 ms per frame | Ctrl+F6 at a stop, on Intel HD 620-class hardware | HUMAN pending (570 beams; frame time stayed at the 60 fps cap with them on or off) |
| 15 | The hum sounds right on headphones and a phone speaker | listen at the rail | HUMAN pending |

Open questions for playtest (Council): does the current plus rail feel like a dense current or a wall? (CurrentMaxOut
is now 21, the crew's walk; compare 14 / 21 / 28.) Is 8 HP/s readable before the grace ends? Is the idle reaction
noticed without annoying? Which preset reads best under the blood moon, at sunset and by day?
