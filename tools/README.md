# Last Train Out playtest tools

Drop the `tools/` folder in the repo root (next to `default.project.json`).

| Problem last session | Tool | One-liner |
|---|---|---|
| Full-size screenshots (~1.5-2k tokens each), wasted shots | `shot.ps1` | `powershell -File tools\shot.ps1 -Name stalker -SkipIfSame` |
| 9 shots = 9 images | `shot.ps1 -Sheet` | `... -Sheet a.jpg,b.jpg,c.jpg,d.jpg` (4 shots, cost of ~1) |
| Required a module that doesn't exist | `rbxfacts` | `lune run tools/rbxfacts find <name>` / `check` |
| Didn't know the ready-up remote | `rbxfacts` | `lune run tools/rbxfacts remote ready` |
| Monsters placed inside a building | `PhotoCommand` | roof + footprint + line-of-sight check, text report |
| Stalker/Crawler mix-up | `PhotoCommand` | floating name label on each model |
| ~40 calls to stage a photo | `PhotoCommand` | chat `/photo` (Studio only) |
| Click to Do overlay blocking clicks | `shot.ps1 -ReleaseKeys` | releases Win/Shift/Ctrl/Alt (a guess at the cause) |

## Token math
Image cost is about width x height / 750. Default output is 0.5 scale, capped at 960 wide, JPEG q60:
a 1920x1080 frame (~2.8k) becomes 960x540 (~690). `-Crop "x,y,w,h"` (fractions) cuts further.

## Setup
1. `rbxfacts.luau`: run from the repo root. It writes `.rbxfacts.md`; point CLAUDE.md at that file
   instead of letting each session rediscover remotes. Add `lune run tools/rbxfacts check`
   to `lune run check` if you want unresolved requires to fail the gate.
2. `PhotoCommand.luau`: place it in ServerScriptService (Rojo path of your choice),
   then call `bindChat` once with your Hollow kinds and spawn function (example at top of the file).
3. `shot.ps1`: nothing to install, Windows already has what it needs.
   Put the file in your repo's `tools` folder, open PowerShell in the repo, and run
   `powershell -File tools\shot.ps1 -Name test` with Roblox Studio open.
   It prints the path of the small picture it saved. Pictures go in `%TEMP%\claude-shots`
   (paste that into File Explorer's address bar to see them).
   Nothing is deleted automatically; delete those pictures yourself when you're done.

## Not tested
Written without access to your repo, Studio, or a Lune/PowerShell runtime.
- `PhotoCommand` needs your real spawn function wired in (the `spawn` option).
- `rbxfacts` is regex-based; remotes defined through a custom table or helper may not appear.
- Dev-command detection looks for `"/name"` strings and `Commands.name =` tables.

## Not fixable by tools
Loading Studio + screen-control tool definitions (~15%) and re-reading CLAUDE.md/AGENTS.md on
every call. Keep those two files short and ask for one specific proof per request.
