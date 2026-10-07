# HANDOFF
Updated at the end of every task. Read this, AGENTS.md, and git diff to resume.

## Features completed
- Full run loop: lobby, route vote, ten stops, Terminus, summary
- Hollows with grabs/struggle/pry; enterable buildings; station hazards
- Chunked landscape, sky with blood moon and omens, train camera, procedural crew animation
- AI kit installed (AGENTS.md, HANDOFF.md, TASKS.md, .claude, .codex)
- Fixed Studio Roblox.rbxl LobbyBuilder station master NPC startup error (`C.navy` undefined; corrected to existing `C.night`). Verified Studio Play starts the server, DepotHall has 2973 descendants, and the character, camera, and 4 GUI elements spawn. `lune run check` passes.
- Studio source contains unsynced additions absent from the repository; no repository gameplay source changed.
- Studio `ServerScriptService.Server.Builders.LobbyBuilder`: adjusted lobby fill lights, lowering them from y30 to18 and moving z13 to32; brightness/range changed from .4/38 to 1.1/60. Corner fills lowered y26 to16 with .35/32 changed to .8/44. Studio-only patch preserves unsynced additions.

- 2026-10-06: lobby back wall (departure board, ticket windows) was dark: front fills at z13 range 60 never reached z72. Added a back row of 3 FillLights (x -44/0/44, y26, z52, 0.85/45) in `Builders/LobbyBuilder`. Verified in Studio Play; `lune run check` passes.
- 2026-10-06: Workshop car's wall-side luggage rack removed (`Lining.bareSide` in TrainBuilder) and its sign lowered to y7.85. Lobby platform lamp standards replaced by two lanterns per platform-edge column on down-turned arms (same 0.75/22 lights). Lobby verified in Studio Play; `lune run check` passes.
- 2026-10-07: enterable buildings: back rooms (better loot, behind the corridor), rear/end exits on Hall and Row buildings, a lantern in every front room, moonlight at broken windows of dead rooms, and an upper floor (stairwell ramp, one-part slab, escape window) on School, Clinic and Hotel. New House type (not placed by any station yet). Hotel barrel z-fight fixed. Containers carry `y` upstairs (LayoutGen/StationBuilder pass-through); upstairs sleepers skipped. `lune run check` and `AUDIT_SEEDS=6 lune run audit` pass; not yet seen in Studio.
- 2026-10-07: upstairs Ward beds left a 1.2-stud aisle (beds on both long walls of a ~15-stud room), so only the narrow agent got past the landing. `wall="long"` now uses one row, on the wall away from the door, when the room is narrower than 2 rows + `Buildings.Aisle` (6); Clinic seed 1 lane is now ~6.8 studs. Stairwell ground floor gets a Lantern that always burns (its ceiling lamp sits at the upper roof). `lune run test` passes apart from the Dwell spec (fails from the uncommitted Difficulty.luau change); audit is clean; Studio Play boots without errors, but the upper floor was not walked.
- 2026-10-07: diegetic HUD pass. `UI/Hud`: the top clock and night dial are now a pocket watch, bottom right (hands = hour, moon aperture, a 60-pip ring for the time left with last call in red, a compass dial pointing to the train), with a ticket for the stop, countdown and danger. Gauges, crew list and backpack sit in CanvasGroups that fade when idle (`WAKE_SECONDS`). The stamina bar and Roblox health bar are gone: `Overlay.vitals` shows red edges, drained colour and grey breath, with a heartbeat below 35% health. New `UI/ChalkSlate` hangs a chalk slate under both CREW SALOON nameboards (stop, danger, leaks, firebox, coal short); it hangs on streamed-in boards. Theme: 2px corners, no neon or gradients on the gauges, `Theme.Font.chalk`. The train cam chip and bar were moved clear of the watch. Verified in Studio Play with no console errors and screenshots of each; `lune run check` passes apart from the existing Dwell spec.
- 2026-10-07: the edge vignettes (dread, vitals, hit pulses, fade) left a lighter strip under the Roblox top bar because the HUD ScreenGui respects the inset. `UI/Overlay` now puts them in their own `LastTrainOutEdges` ScreenGui (IgnoreGuiInset, DisplayOrder +1). Studio Play boots with no errors; the station view was not re-checked.

## Known bugs / regressions
- Place saved successfully to `C:\Users\tameg\OneDrive\Documents\Roblox.rbxl`; Studio DataStores are unavailable, so player profile saving is disabled for this session.
- Studio Play verified all eight adjusted lights and visible floor/rear-hall coverage; repository lune run check passes. Save the changed place in Studio.
- Upper-floor Hollows have no teleport recovery if they get stuck.

## Next logical step
- Check the watch's compass afield at a station (only tested aboard), the winded vignette while sprinting, and the HUD at phone size. Option: shrink the Struggle plate to just a keycap prompt.
- Look at the workshop sign inside the train in Studio (it has not been checked on screen yet).
- Save the place in Studio, then reconcile Studio edits with Rojo before syncing.
- Walk the Clinic upper ward with a normal Hollow and check the stairwell lantern. Walk the School, Clinic and Hotel upper floors in Studio (ramp, escape window, moonlight). Decide whether a station should place the House (`Config/Stations` landmarks).

## rbxmap setup — 2026-10-06
- Completed: 119-script local index, agent instructions, remote wrappers, Codex/Claude registrations, real MCP call, and passing doctor/Rojo/Selene/StyLua checks. See .rbxmap/START_HERE.md. Game source and Git staged state unchanged; no commit or push.
- Limitations: Claude CLI absent; new agent-session loading and Studio appearance unverified. Remote scanner retains generic dynamic-name rows. README argument order is wrong: put --project before serve/doctor.
- Next: restart Codex and test find_script; optionally install/start Claude Code. Reconcile existing Studio-only edits before Rojo syncing.

## 2026-10-06: Lobby HUD restyle
1. Done: `UI/Lobby.luau` profile card and departure panel have no background; their text is bolder with a dark outline (white text, brass for BRASS). OUTFITTER is now a dark Secondary button like LINE MASTERY, and both sit in a row under the profile card on the left. Checked in Studio play, console clean.
2. Known issues: none. `Ui.ticket` is no longer used by the lobby.
3. Next: check that the outlined text reads well over bright lobby floor tiles at small screen sizes.

## 2026-10-06: Lobby HUD tweaks
1. Done: `UI/Lobby.luau` name reads `OPERATOR: <name>`; CREW RANK/XP line is Oswald Bold 20 (was 17); PROGRESS NOT SAVED is white Oswald Bold 17 (was red BuilderSans 13); LINE MASTERY now stacks under OUTFITTER with 8px gap; PROGRESS NOT SAVED sits left-aligned just above OUTFITTER. Studio play checked, console clean.
2. Known issues: very long display names may overflow the 260px name label.
3. Next: same as above (readability over bright tiles).

## 2026-10-06: 1800s locomotive look
1. Done: `Builders/TrainBuilder` locomotive now has a flared balloon smokestack with a brass rim (top still named ChimneyTop), a large brass-trimmed oil-lamp headlamp box with a peaked hood, a brass bell between the domes, and red driving wheels (`C.driver`). `lune run check` passes (audit clean); Studio Play console clean.
2. Known issues: not visually confirmed in Studio (train is built at runtime and the lobby is dark, so the screenshot showed nothing).
3. Next: eyeball the locomotive in Play (lobby display train); consider a wooden 1800s cab with arched windows and a slatted cowcatcher.

## 2026-10-06: full 1800s train restyle
1. Done (`Builders/TrainBuilder`, `Config/Cosmetics`): wood-plank coach siding, twin round-topped sash windows with mullions and sash bars, clerestory roofs with amber lights, queen-post truss rods; 4-4-0 locomotive (two red-spoked drivers that spin, brass splashers), Russia-iron boiler with brass domes, wooden cab with roof cap and ventilator, red slatted V cowcatcher, flared tender boards. Default livery is now "Heritage Mahogany" (mahogany, brass, green doors). Check passes (Train 1626 parts, audit clean); seen in Studio Play lobby, console clean.
2. Known issues: car size kept (seats, spawns, volumes, breach anchors depend on it). Other liveries still repaint the wood. Headless preview needs `npm install` in tools/preview.
3. Next: ride a run and look at the loco up close (spokes, pilot, stack smoke) in daylight.

## 2026-10-06: Display train gap barriers
1. Done: `Builders/LobbyBuilder` adds invisible `GapBarrier` parts in the four gaps between the display train's cars (ballast to roofline, tops flush with the roofs; gangway gaps fill only the open sides so the gangway stays walkable). `lune run check` passes; Studio play console clean.
2. Known issues: collision not walk-tested by hand. The live run train's gaps are untouched.
3. Next: the older request: per-car outward-swinging doors, solo ready, and car party rooms (up to 4) that auto-ready.

## 2026-10-06: Saloon and workshop split into four cars
1. Done: `Builders/TrainBuilder` splits the crew saloon (-63..-44.5, -41.5..-23) and workshop (-20..-1.5, 1.5..20) with covered gangways. Every carriage's double doors are now 5.6 wide and 7.5 tall (were 5x7); passenger walls pack windows between the ends and doors. Short cars put their bogies nearer the ends. `Builders/TrainInterior` moves the bays, route table (2nd saloon car, platform side), workbench/lathe (1st workshop car), cabinet (STORES car) and adds signs, pictures and car boards (LAST TRAIN OUT, CREW SALOON, WORKSHOP, STORES). `LobbyBuilder` adds gap barriers for the new gaps. Check passes and the Studio display train looks right; the console is clean.
2. Known issues: the saloon has 5 bays (10 seats), down from 8 bays, because of the extra door.
3. Next: ride a run and check boarding through the new doors and the route table and workbench prompts.

## 2026-10-06: Boarding cars (party doors on the display train)
1. Done: all 5 display-train carriages (Stores car included) are boarding rooms. Hold E (tap on touch) at the door to board or get out. 2-4 players per car. The 40s countdown starts at 2 aboard and starts over when anyone gets out or drops. People can get out before the countdown starts and in its first 10s. A full car, or a countdown reaching 0, blacks the screen and teleports the car to a reserved server, which starts the run (Boarding, then route vote) once the car arrives and sends everyone back to a public hall after RunEnd. In Studio the run starts on this server instead. Being aboard counts as ready: the Ready panel hides and the solo Ready flow ignores car players. Green floor-edge glow pulses while a countdown runs. Gangways and the brake van's rear doorway are sealed. Files: `Logic/CarBoarding` (+spec), `Services/CarService`, `UI/CarBoarding`, `Config/Tuning.Cars`, small edits in TrainBuilder (cabins), LobbyBuilder, LobbyService, RunDirector (`Launch`), Lobby UI, UIController. Check passes; Studio: board/exit verified solo, console clean.
2. Known issues: the 2+ player countdown, black screen and departure are unit-tested only, not playtested. Teleport works only in the published game. Prompt chips do not appear in MCP screenshots (the hold still triggers).
3. Next: Studio Test > Clients and Servers with 2-4 players to confirm the countdown, exit lock, black screen and the Studio launch. Then publish and test a real teleport.

## 2026-10-06: train car clutter removed
1. Done: `Builders/TrainInterior` no longer builds the saloon table items (cups, books, candles), rack luggage and hat box, the stove's kettle, the guard's teapot and cups, the workshop drawer cabinet, anvil and chain hoist, or the spare wheel. All light sources (table lamps, stove, lantern, desk and bench lamps), paintings, signs, tables and chairs stay. `Builders/TrainBuilder`: car 3's route table (and its brass label, and the unused `routeTable` field) removed. Check passes; Studio Play console clean.
2. Known issues: not visually inspected inside the cars.
3. Next: walk the cars in Play to confirm the look.

## 2026-10-06: Lobby piano music and notes
1. Done: Satie's Gnossienne No. 3 (APM, id 1837474268, cue `LobbyPiano` in `Config/Audio`, volume 0.48 after a +20% bump) loops from a hidden `PianoVoice` part in the lobby piano (`Builders/LobbyBuilder`), full volume across the whole hall (roll-off min 170, max 180 studs). New client `Controllers/PianoNotes` floats gold/cream/amber note glyphs off it (rise, sway, fade over 3-4.6 s; none when the camera is >110 studs away). Notes checked in Studio play, console clean; `lune run check` passes.
2. Known: music audibility/volume not checked by ear (MCP can't hear audio).
3. Next: listen in Studio and tune `LobbyPiano.volume` or the roll-off if it masks the DepotHall bed.

## 2026-10-07: Station layouts (streets, squares, yards, sidings)
1. Done: every station except the Terminus has a `layout` in `Config/Stations` (Street, Plaza, Yard or Sidings). `Logic/LayoutGen` now carves the routes first, then places buildings and structures on lots facing them. Plazas get a Fountain in the middle and stalls around it. Barriers (fences, walls, Wreck) close parts of the Near/Mid and Mid/Far boundaries, leaving the routes open and every tile reachable. Broken ground goes beside the routes. ToolChests and Crates lean toward the Far zone (`Stations.FarLoot`). New basic-part builders in `Builders/StationDressing`: Siding, Wreck, Rubble, BrokenRoad, Deck, Trench. Spec: `tests/StationLayout.spec.luau`. `lune run check` and `AUDIT_SEEDS=6 lune run audit` pass. Station parts at seed 424242 are 2666-3720 (budget 4200), 5-22% heavier; the Terminus is unchanged.
2. Known issues: not yet checked in Studio. Hollows walk straight at their target (MoveTo) and may catch on barrier runs. Pre-existing z-fights on other seeds, outside these files: DecorCrates (Infirmary, seed 1234) and Hotel interior (RailwayHotel, seeds 7/1234/98765).
3. Next: walk a few stops in Studio and check that Hollows get through the barrier gaps. If they get stuck, lower `layout.fill`.

## 2026-10-07: Train interior and run HUD pass
1. Done: paintings are full scenes (sky, orb with halo, peaks, lake, viaduct with a train and smoke, pines, signal, telegraph poles, varnish) with a gilt slip and a titled brass plaque (`Builders/TrainInterior`). Saloon seats are single window seats (aisle seats removed), smaller, with smaller tables; the guard's van chair in the doorway is gone and the other is 0.88 scale. A red runner with gilt borders runs from the workshop to the guard's van, cut at every car end (`Builders/TrainBuilder`). Route vote cards are black, with danger boxes, Montserrat type and a dossier arrow that opens a paper sheet in mid-screen (`UI/RouteVote`). Gauges: solid black, figure between label and neon tube. Roster is OPERATORS with call signs (A1, B4...). `lune run check` passes; Studio Play console clean; cards, dossier, HUD, saloon seats, runner and paintings seen on screen.
2. Known: the guard's van was not reached on screen (character navigation could not route there). Call-sign letters follow sorted user keys, so a player leaving can shift later letters.
3. Next: look at the guard's van and the paintings up close in Studio.

## 2026-10-07: Opt-in run difficulty tiers
1. Done: tiers 1-5 (`Config/Difficulty.RunTier`, `Logic/RunTier`). Host = longest-present hall player; picks with < > in the lobby, capped by the lowest `profile.unlockedTier` in the hall (and re-capped by the actual crew at Boarding). Each tier above 1 adds 0.06 to every stop's D and +20% Brass ("Tier N bonus" line, before charter/daily). A Victory at tier N unlocks N+1. Tier shown in the lobby and the run receipt ("RUN TIER N UNLOCKED"). New remote `SetRunTier`, state `lobby.tier` and `run.tier`. `lune run check` passes (new `tests/RunTier.spec.luau`); not played in Studio.
2. Known issues: saving only verifiable in a live server. The in-world departure board text does not show the tier.
3. Next: in a published server, win a tier-1 run and rejoin to confirm tier 2 stays unlocked.

## 2026-10-07: landmarks, upstairs fixes, crate z-fight, stairwell width
1. Done:
   - b270c15: landmarks: Halt hamlet, Minehead pit row, Coaling Yard engine shed, and a decor flag on landmark rules.
   - ccb4303: `BuildingService.IsLitAt` now counts upper floors. Its 2.02 lift on the stacked DecorCrate did not remove the z-fight.
   - 54789c0: leftover loot pickups spawn on the container's own floor (upstairs too).
   - This task: `StructureKit` `Props.DecorCrates` draws the second ground crate 0.03 shorter (bottom still at y 0; same rng calls, sizes, positions and count). The z-fights at Infirmary seed 1234 and Halt seed 7 are gone, and no other station or seed changed. `Config/Buildings` `Furniture.Stairs.d` went from 4.6 to 6.2 (School, Clinic and Hotel are the only users), so the doorway at the top of the ramp is 6.0 wide and Hollows can path up. The ramp still clears the stairwell door by 14 studs. Tiles, Hollow cap, stay time and part counts are unchanged on seeds 424242, 7, 1234 and 98765. `lune run check` and `AUDIT_SEEDS=6 lune run audit` pass. Not playtested in Studio.
2. Known issues: upper-floor Hollows have no teleport recovery if stuck.
3. Next: in Studio, watch a Hollow climb the School, Clinic and Hotel ramps.

## 2026-10-07: Hollows climb the stairwell ramp
1. Done: Studio playtest found Hunt Hollows stuck at the foot of the Clinic ramp. Cause: the ramp foot sits 2 studs from the stairwell wall, so the 2.2-radius path agent found no way onto it (radius 1 does), and with the target in sight they walked straight into the ramp's side. `HollowService`: walk straight only when the seen target is within `SameFloor` (4) in height; retry a failed path with `NarrowRadius` (1); a hunter that stays within `StallRadius` (2) for `StallSeconds` (2) drops its path and follows a fresh one for `StallRepath` (3) s. New constants in `Config/Tuning` `Hollow`. Verified in Studio at Brannoc Infirmary: a Stalker went from the ramp foot to the landing in about 2 s, and two followed back down. No console errors. `lune run check`: format, lint and types pass; 140/141 tests pass. The one failure (Difficulty dwell range) comes from the uncommitted `Config/Difficulty` Dwell change, not this task.
2. Known issues: the upstairs ward beds leave gaps a 2.2 agent cannot pass, so Hollows reach the landing but only reach the rest of the Clinic upper floor through the narrow fallback. The stairwell ground floor has no light. Not yet watched on the School or Hotel ramps. Uncommitted Difficulty Dwell change fails `tests/Difficulty.spec.luau`.
3. Next: decide on the Difficulty Dwell change (update the spec or revert), then check the School and Hotel ramps and the escape window, moonlight and upstairs loot in Studio.
