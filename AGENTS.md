# Last Train Out: working notes

Co-op Roblox game synced with Rojo. The design source of truth is the blueprint doc linked in README.md.
Read this file before changing code.

## Project
1-8 player co-op survival on a train: ten generated stops to loot, then the Terminus. Luau, Rojo, Lune tests.
Run: `rojo serve`, connect the Rojo plugin in Studio, press Play. Gate: `lune run check`.

## File map
- src/server: `init.server.luau` boots `Services/` (19); `Builders/` make train, stations, lobby, Hollows
- src/client: `Controllers/`, `Animation/`, `Camera/`, `Scenery/` (land, sky, fog), `UI/`
- src/shared: `Config/` numbers, `Logic/` pure rules, `Net/Remotes`, `Types`, `Util/`, `Visual/Kit`
- tests/: Lune specs; .lune/: check, test, audit, preview; tools/preview: three.js viewer

## Features that exist now
- Lobby, route vote, 11-phase run, stations with loot, fog/collapse hazards, left-behind rule
- Hollows (several kinds) with grabs, struggle and crewmate pry; enterable buildings
- Chunked biome landscape, set pieces, day-night sky, blood moon, shared omens, weather
- Inventory, ledger, shop/workshop, cosmetics/outfitter, progression, spectate, summary
- Train camera, R6 procedural crew animation, Studio dev console

## Known bugs / unfinished work
- No TODO/FIXME notes in src. Robux product ids unbound until publish (`Config/Cosmetics`).
- Commit 2d369e2 passed `lune run check` (verified 2026-10-04).

## Architecture

- **Server-authoritative.** `src/server/init.server.luau` requires every service in `ORDER`, puts each in
  `Registry`, calls every `Init`, then every `Start`. `Init` builds instances and wires references and must not
  yield on players; `Start` connects events and begins loops.
- **Service calls go through `Registry`** (`Registry.CrewService.IsAboard(player)`) so modules never require
  each other in a cycle. A direct `require` of another service is allowed only when that service comes earlier
  in `ORDER` (StateService, NetService, DataService, WorldService and StationService are the ones used today).
- **State replication.** StateService holds one public tree and a private tree per player. `Set(path, value)`
  records a patch; patches flush once per Heartbeat with a sequence number. The client mirror
  (`Controllers/StateController`) asks for a snapshot when it sees a gap. Every replicated shape is declared in
  `src/shared/Types.luau`; change the type and the producer together.
- **Remotes** are declared in `src/shared/Net/Remotes.luau`. Every handler goes through NetService, which
  validates arguments, rate-limits and gates by phase. Clients send ids only, never amounts.
- **Run flow.** `Services/RunDirector` owns the 11-phase state machine (`Enter`/`Exit` tables, `transition`).
  Phase rules shared with the client live in `Logic/RunRules`.
- **World motion.** The train never moves. A station is one welded assembly on a PrismaticConstraint, driven by
  `Logic/Motion` profiles while arriving or departing and anchored while docked. Scenery is client-only.
- **The landscape.** `Logic/Journey` plans it in land coordinates (odometer studs): a biome per leg from the
  destination archetype, seeded set pieces (tunnels, gorges, burning towns and more) and a sinkhole on the +Z side
  of every station, cut where Cruise predicts the dock and re-cut at Arrival if the station lands elsewhere.
  `Controllers/SceneryController` builds it in chunks (`Scenery/Land` layers, `Scenery/Features`), each welded to
  one anchored root, and scrolls the roots with one `BulkMoveTo` per frame. Chunk content must depend only on
  `Scenery/World` (the plan) and the chunk's own Rng, so a rebuilt chunk comes out the same.
- **Lighting is client-owned.** `Controllers/AtmosphereController` builds the sky, atmosphere, clouds, post effects
  and weather and sets them every frame (time of day by run progress, biome air, tunnels, storms). The server
  does not touch Lighting; `Lighting.Technology` is set to Future in `default.project.json`.
- **The sky.** `Scenery/Sky` is the look as data and math: hour keys, the moon's path and colour through the night,
  and `compose`/`approach`/`finish`, which turn the hour, biome, dread and the omen into Lighting values.
  `Scenery/Heavens` draws what the engine cannot: the moon (the engine's is hidden), horizon glows, the TallOnes
  and lightning bolts, as BillboardGuis of Frames on one anchor that follows the camera at 16000 studs, so they sit
  at infinity behind the landscape. `Logic/Omens` schedules omens and lightning from the run seed and the server
  clock, so every client sees and hears the same ones; the controllers only read it. `lune run preview` and the
  audit's `Sky` target run the same modules headless.
  `Journey.skyProgress` keeps the hour running through stops (the moon rises at dusk); the HUD's night dial reads
  `AtmosphereController.Hour()` and `Sky.phase`.
- **The crew's bodies.** CrewService builds every character as an R6 rig from the player's HumanoidDescription
  (attribute `Procedural`, no Animate script, joints kept on death). Every client animates every rig in
  `Controllers/CharacterAnimator` from `Animation/CrewPoses` (pure; the R6 transform conventions are at its top).
- **Hollows and grabs.** HollowService paces each Hollow by kind (`Tuning.HollowKinds`) and its own `Pace`, fans
  hunters round shared prey, and turns a landed strike into a hold from `Config/Grabs` (rules in `Logic/Grab`):
  both roots anchored, bites on the grab's rhythm, escape from the `Struggle` remote and crewmates' `Pry` prompts.
  `HollowAnimator` poses from `Animation/HollowPoses` (two-bone IK); the audit's `Grabs` target fails any pose
  whose hands or feet cannot reach. `GrabController` and `UI/Struggle` are the victim's side.
- **Train and stations.** TrainBuilder builds the shell, `Builders/TrainInterior` furnishes it (its Seats get Sit
  prompts in TrainService); `Controllers/TrainCamController` is the outside camera. LayoutGen lays out the platform
  (canopy, clutter kept apart), a boundary on every open edge and the yard dressing (`Config/Stations` edge and
  dressing); `Builders/StationDressing` builds them. The fog is `Scenery/StationFog`.
- **Determinism.** `Util/Rng` (Mulberry32) is derived per purpose from the run seed, so the server, clients and
  tests generate the same layouts, loot and hazard schedules. Clients evaluate fog and collapse fronts locally
  from `run.station.hazards`.

## Conventions

- `--!strict` in every `src` module. Wrap long-lived loop bodies in `Util/Safe.call`.
- `src/shared/Logic` and `src/shared/Config` are pure: no `game`, `workspace`, `Instance`, `task` or other
  engine globals, and requires only through `script`. That is what lets Lune test them.
- No magic numbers: constants go in `Config/Tuning`; anything that scales with difficulty is a `{ D0, D1 }`
  pair in `Config/Difficulty`, read through `Logic/DifficultyModel`.
- No uploaded assets. Models are built from parts through `Visual/Kit` and `Builders/`; sounds are public
  library ids in `Config/Audio`.
- Engine-guarded properties (such as `Workspace.FallenPartsDestroyHeight`) go in `default.project.json`
  `$properties`, never in a script.
- Escape belongs to the Roblox menu. Modals close with gamepad B, the backdrop or a CLOSE button.
- Robux product ids are bound after publishing (`Config/Cosmetics`, `robux.productId`); `nil` means not for sale.

## Checks

- `lune run check` runs StyLua, selene (tests use `tests/selene.toml`), a fresh Rojo sourcemap, luau-lsp in
  strict mode, the unit tests and the visual audit (`.lune/audit.luau`). It must pass before every commit.
- The audit builds every model headless (through `.lune/lib/Shim`) and fails on z-fighting (two visible faces in
  one plane, `lib/Faces`), clashes (separate props or set pieces sunk into each other, `lib/Clash`), props
  outgrowing their `Props.radius` footprint, and part, light, emitter and particle budgets. Before a landscape
  change, also run `AUDIT_SEEDS=6 lune run audit Scenery`.
- Landscape rules the audit relies on: every ground layer has its own height band (`Scenery/Bands`); flat overlays
  never overlap; props are packed inside their chunk and band by footprint; set-piece ground that props may stand
  in carries the `Earth` attribute; members between two points use `Kit.between`, never `CFrame.lookAt`.
- New pure logic gets a spec in `tests/`. Spec files receive `Shared`, `describe`, `it` and `expect` as globals.
- To look at a change without Studio: `lune run preview <biome> out.json --hour=26`, then
  `node tools/preview/render.mjs out.json out.png --cam=ahead` (see README.md). The viewer approximates Roblox's
  lighting; use it to judge composition and mood, and confirm in Studio.
- In Studio, `Remotes.Dev` (Studio-only) runs the developer console commands listed in README.md.

## Rules
- Make small changes. Never rewrite working files. Explain before deleting anything.
- One task per session. Stop when the task is done.
- Verify before saying done: run the tests, or state exactly how I can check it.
- Commit after each completed task with a clear message. Never push.
- Never print or commit secrets (keys, tokens, passwords).
- At the end of every task, update HANDOFF.md with: 1. features completed, 2. known bugs/regressions, 3. next logical step.
- When asked for "the next task": do only the first unchecked item in TASKS.md, tick it off, then stop. If none are left, say so and stop.
- Keep output short. Name files instead of pasting them. Do not dump large logs.
- Codex: use medium effort and delegate small scoped edits to the grunt subagent.
