# my-roblox-game

A Roblox game built with [Rojo](https://rojo.space/). Code lives in `src/` and syncs into Roblox Studio.

## Folder layout

| Folder | Shows up in Studio as | Runs on |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Server |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | Each player |
| `src/shared` | ReplicatedStorage.Shared | Both (modules) |

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
3. Edit files in `src/`. Saving a file updates Studio straight away.
4. When something works, save a version:
   ```
   git add .
   git commit -m "Describe what you changed"
   git push
   ```
