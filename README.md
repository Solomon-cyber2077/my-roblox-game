# Last Train Out

A co-op Roblox game for 1 to 4 players. The crew rides the last train across a dead country. At every stop
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
| `src/server` | ServerScriptService.Server | `Services/`: 19 services, booted in order by `init.server.luau`. `Builders/`: the train and its interior, stations and their dressing, Depot Hall and Hollows, built from primitives |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | `Controllers/`: state mirror, camera and the train camera, movement, the crew's and the Hollows' animation, grabs, scenery, atmosphere, audio and effects. `Animation/`: the bodies as pure pose math (R6 crew, Hollows with IK). `Scenery/`: the chunked landscape (biomes, props, layers, set pieces, sinkholes), the sky and the stations' fog. `UI/`: HUD, modals and prompts |
| `src/shared` | ReplicatedStorage.Shared | `Config/`: every tunable number. `Logic/`: pure game rules, unit-tested. `Net/`, `Types`, `Util/`, `Visual/` |
| `tests` | Not synced | Lune specs for `src/shared` |
| `.lune` | Not synced | The test runner, the quality gate, the visual audit, the preview exporter and the report script |
| `tools/preview` | Not synced | The three.js viewer that draws preview exports outside Roblox |

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

## Playing

| Key | Does |
| --- | --- |
| WASD, Shift | Move; sprint while your breath lasts |
| E | Search, take, sit, patch, pull a crewmate free (whatever the prompt says) |
| 1-6, G, right-click | Use a tool, drop the last item, drop the one you click |
| Space (gamepad A, or tap the plate) | In a Hollow's grip: struggle. Mash it to break free |
| C (gamepad D-pad up) | Aboard: the train camera, watching the train from outside. F (D-pad right) cuts between shots |

The train camera also has **Next**, **Back**, and **+ / −** buttons for touch and mouse.
Drag to orbit, scroll to zoom, or use the right stick and triggers on a gamepad. The Moon
shot keeps the whole train and the moon in view across wide and portrait screens.

A Hollow that catches you holds on and bites, squeezes or yanks on its own rhythm until you fight free, a
crewmate pulls you loose, or a Flashbulb makes it let go; each kind has three holds. The clock under the
station ticket is the night's: the moon rises with the sunset, turns copper, and at two in the morning hangs
blood red.

## Commands

| Command | What it does |
| --- | --- |
| `lune run check` | Formatting, lint, strict type check, the unit tests and the visual audit, stopping at the first failure |
| `lune run audit` | Builds every model the game makes (train, lobby, stations, Hollow, items, every prop, a landscape window per biome) headless and fails on z-fighting, clashing objects or budget overruns. The `Sky` target poses the sky objects through a whole night in every biome and every omen. `lune run audit Scenery` filters by name; `AUDIT_SEEDS=6` sweeps more world seeds, `AUDIT_PROP_SEEDS=24` more prop seeds, `AUDIT_SHOW=n` prints more findings |
| `lune run preview <biome> <out.json> [seed] [odometer]` | Exports a stretch of the journey (train, landscape, set pieces, and the sky the client would draw) as JSON, for viewing outside Roblox. `--hour=26` sets the time of night, `--dread=0.6` a Hollow's nearness, `--omen=Blink@0.35` an omen part-way through, `--flash=1` lightning. `--ride=12 --fps=24` exports twelve seconds at cruise with a sky frame per 1/24 s (`--hours=19.5:22` sweeps the hour, `--omen=Blink@3,Eye@9` starts omens at those seconds). `Gallery` as the biome lays every prop in a row |
| `node tools/preview/render.mjs <out.json> <out.png>` | Draws a preview export with three.js in headless Chromium (`npm install` in `tools/preview` once). `--cam=ahead` (or `station`, `far`, `wide`, `behind`, or `x,y,z:x,y,z`), `--video=12` renders a ride to MP4 with ffmpeg. An approximation of Roblox's lighting for judging mood and layout, not a pixel match |
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
| `hollow`, `hollow Crawler` | Spawn a Hollow near you (of a kind: `Stalker`, `Crawler` or `Brute`) |
| `grab`, `grab Brute` | A Hollow seizes you at once (a station must be docked): to try the holds and the struggle |
| `coal 50`, `parts 20` | Set the train's stores |
| `state` | Print the run, crew, train and backpack to the Output |
| `sky 26` / `sky` | Pin every client's sky to an hour (18.3 dusk, 21 the amber moon rising, 26 the blood moon, 30.5 sunrise), or let it follow the run again |
| `omen Eye` | Every client sees an omen now: `Hush`, `TallOnes`, `Blink`, `Bleed` or `Eye` |
| `strike` | A lightning strike now |

The remote does not exist in live servers.
