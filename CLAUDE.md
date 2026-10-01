# Last Train Out: working notes

Co-op Roblox game synced with Rojo. The design source of truth is the blueprint doc linked in README.md.
Read this file before changing code.

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
  strict mode and the unit tests. It must pass before every commit.
- New pure logic gets a spec in `tests/`. Spec files receive `Shared`, `describe`, `it` and `expect` as globals.
- In Studio, `Remotes.Dev` (Studio-only) runs the developer console commands listed in README.md.
