# Last Train Out

A co-op Roblox game for 1 to 8 players. The crew rides the last train across a dead country. At every stop
they have a few minutes to strip the station for coal and parts while fog, collapsing floors and Hollows close
in from the far edge, and anyone not aboard when the train pulls out is left behind. Ten generated stops, then
the Terminus.

Everything is built with [Rojo](https://rojo.space/): every model is made from primitives at runtime and every
rule and number lives in this repository. The production blueprint (state machines, difficulty curves,
monetization and the backlog) is the
[Last Train Out blueprint doc](https://claude.ai/code/artifact/a12ce9e8-62ff-4d1b-8abf-f28e088c42fa).

## Folder layout

| Folder | Shows up in Studio as | Holds |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | `Services/`: 18 services, booted in order by `init.server.luau`. `Builders/`: the train, stations, Depot Hall and Hollows, built from primitives |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | `Controllers/`: state mirror, camera, movement, scenery, audio and effects. `UI/`: HUD, modals and prompts |
| `src/shared` | ReplicatedStorage.Shared | `Config/`: every tunable number. `Logic/`: pure game rules, unit-tested. `Net/`, `Types`, `Util/`, `Visual/` |
| `tests` | Not synced | Lune specs for `src/shared` |
| `.lune` | Not synced | The test runner, the quality gate and the report script |

`init.server.luau` and `init.client.luau` are the entry scripts. Other `.luau` files are ModuleScripts.

## First-time setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run:
   ```
   rokit install
   rojo plugin install
   ```
2. Open the folder in VS Code and click **Install** when it asks about recommended extensions.

## Every time you work on the game

1. In VS Code's terminal run `rojo serve`.
2. In Roblox Studio open your place, go to the **Plugins** tab, click **Rojo**, then **Connect**.
3. Press **Play**. Edit files in `src/`; saving a file updates Studio straight away.
4. Before you commit, run the quality gate. It must pass:
   ```
   lune run check
   ```
5. Save a version:
   ```
   git add .
   git commit -m "Describe what you changed"
   git push
   ```

## Commands

| Command | What it does |
| --- | --- |
| `lune run check` | Formatting, lint, strict type check and the unit tests, stopping at the first failure |
| `lune run test` | The unit tests only. `lune run test Ledger` runs the specs whose file name contains `Ledger` |
| `lune run report` | Prints the difficulty and hazard tables the blueprint quotes |

## Studio developer console

In Play mode, switch the command bar to the client and fire the Studio-only `Dev` remote:

```
game.ReplicatedStorage.Remotes.Dev:FireServer("state")
```

| Command | Effect |
| --- | --- |
| `skip` | End the current phase now |
| `warp 30` | Move the station clock forward 30 seconds |
| `god` | Toggle no damage, no falling and never left behind |
| `search` | Search the nearest unsearched container |
| `tp train`, `tp edge`, `tp mid`, `tp far` | Move to the train or a station zone |
| `give CoalSack` | Put an item in your backpack |
| `hollow` | Spawn a Hollow near you |
| `coal 50`, `parts 20` | Set the train's stores |
| `state` | Print the run, crew, train and backpack to the Output |

The remote does not exist in live servers.
