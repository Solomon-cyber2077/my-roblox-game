# 1. DONE AND VERIFIED

- Preflight found the executable, default.project.json, Codex CLI 0.160.0, Rojo, Selene and StyLua. No existing .rbxmap/, MAP.md or DESIGN.md. Initial doctor only lacked an index; final doctor: `All good.` (Python 3.12.10, SQLite 3.49.1/FTS5, MCP 2.3.0, 119 scripts).
- Backed up before editing. Init created only .rbxmap/, MAP.md, DESIGN.md, AGENTS.md.new and CLAUDE.md.new; no tasks/ directory.
- Merged instructions inside rbxmap markers (21 added lines in AGENTS, 5 in CLAUDE). Original content remains byte-for-byte. See instruction-merge.diff. Only the two .new files were deleted, after displaying their merged diff.
- MAP has 119 descriptions and zero auto-generated ~ entries: no description overrides were necessary. Forced regeneration preserved text outside markers.
- Configured Net.Fire/On and NetService/Registry.NetService Handle, Fire, FireAll, FireList. Index/remotes generated 20 rows. Matching examples: BuyUpgrade -> TrainService, CastVote -> RouteService, ClientReady -> StateService. Dynamic helper names (`?`, `event`, `name`, `RemoteEvent`) remain scanner artifacts; Dev's handler is unresolved.
- .mcp.json parses and retains Roblox_Studio unchanged; exact final file below.
- `codex mcp add`: `Added global MCP server 'rbxmap'.` Subsequent `codex mcp list` shows rbxmap enabled (stdio Auth: Unsupported). Original Codex config bytes are preserved, with only the block below appended.
- Real stdio MCP client initialized the registered command, listed 11 tools and called find_script: `MCP PASS rbxmap 11 src/server/Builders/LobbyBuilder.luau 357`. See mcp-proof.json.
- `rbxmap check`: Rojo ok, exit 0; Selene ok, exit 0, 0 errors/0 warnings/0 parse errors; StyLua ok, exit 0. See check-results.json.
- Final integrity check: all 119 source files unchanged, no source additions, Git index hash unchanged. Original instructions/HANDOFF preserved. See integrity-proof.json.
- START_HERE.md is 36 lines. HANDOFF records setup, limitations and next step.

## Search output

| Query | Top result | Lines | Approximate search-response tokens |
|---|---|---|---:|
| lobby lighting | src/server/Builders/LobbyBuilder.luau | 419-484 | 357 |
| shop purchase | src/server/Services/ShopService.luau | 53-86 | 355 |
| player data saving | src/server/Services/DataService.luau | 196-237 | 354 |

All three search responses are under 500 tokens. Their JSON files retain full results. `rbxmap map` returned the complete compact map at approximately 873 tokens; the longer generated MAP.md is approximately 6,826 tokens (characters/4).

## First 10 remote rows

| Remote | Fired by | Handled by | Defined |
|---|---|---|---|
| ? | â€” | â€” | `src/server/Services/NetService.luau:54` |
| BuyUpgrade | `src/client/UI/Workshop.luau:115` (fire_server) | `src/server/Services/TrainService.luau:205` (on_server_event) | â€” |
| CastVote | `src/client/UI/RouteVote.luau:129` (fire_server) | `src/server/Services/RouteService.luau:23` (on_server_event) | â€” |
| ClientReady | `src/client/Controllers/StateController.luau:97` (fire_server)<br>`src/client/Controllers/StateController.luau:118` (fire_server) | `src/server/Services/StateService.luau:162` (on_server_event) | â€” |
| Dev | `src/server/Services/DevService.luau:196` (fire_server) | â€” | `src/server/Services/DevService.luau:177` |
| DropItem | `src/client/UI/Hud.luau:518` (fire_server)<br>`src/client/UI/Hud.luau:625` (fire_server) | `src/server/Services/InventoryService.luau:41` (on_server_event) | â€” |
| event | `src/client/Net.luau:18` (fire_server) | `src/client/Net.luau:22` (on_client_event) | â€” |
| Fx | `src/server/Services/BuildingService.luau:120` (fire_client)<br>`src/server/Services/BuildingService.luau:145` (fire_client)<br>`src/server/Services/CrewService.luau:247` (fire_client)<br>`src/server/Services/CrewService.luau:438` (fire_client)<br>`src/server/Services/CrewService.luau:501` (fire_client)<br>`src/server/Services/HazardDirector.luau:70` (fire_client)<br>`src/server/Services/HollowService.luau:411` (fire_client)<br>`src/server/Services/HollowService.luau:550` (fire_client)<br>`src/server/Services/HollowService.luau:554` (fire_client)<br>`src/server/Services/HollowService.luau:611` (fire_client)<br>`src/server/Services/InventoryService.luau:110` (fire_client)<br>`src/server/Services/InventoryService.luau:152` (fire_client)<br>`src/server/Services/LootService.luau:83` (fire_client)<br>`src/server/Services/LootService.luau:167` (fire_client)<br>`src/server/Services/ProgressionService.luau:119` (fire_client)<br>`src/server/Services/ShopService.luau:37` (fire_client)<br>`src/server/Services/ShopService.luau:81` (fire_client)<br>`src/server/Services/ShopService.luau:134` (fire_client) | `src/client/Controllers/FxController.luau:324` (on_client_event) | â€” |
| HullPatch | `src/client/UI/Workshop.luau:148` (fire_server) | `src/server/Services/TrainService.luau:208` (on_server_event) | â€” |
| JoinInProgress | `src/client/UI/Lobby.luau:127` (fire_server) | `src/server/Services/CrewService.luau:273` (on_server_event) | â€” |

## Final project MCP JSON

```json
{
  "mcpServers": {
    "rbxmap": {
      "type": "stdio",
      "command": "C:/Users/tameg/Documents/rbxmap/.venv/Scripts/rbxmap.exe",
      "args": ["--project", "C:/Users/tameg/Documents/Roblox/my-roblox-game", "serve"]
    },
    "Roblox_Studio": {
      "type": "stdio",
      "command": "cmd.exe",
      "args": ["/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]
    }
  }
}
```

## Exact Codex config addition

```toml
[mcp_servers.rbxmap]
command = "C:/Users/tameg/Documents/rbxmap/.venv/Scripts/rbxmap.exe"
args = ["--project", "C:/Users/tameg/Documents/Roblox/my-roblox-game", "serve"]
```

See codex-registration.diff for the exact diff against the backup. The README's argument order fails on the installed CLI: global --project must precede the subcommand. This correction was tested. MCP has refresh; the CLI uses index, not refresh. A sandbox path-resolution failure was resolved by running the existing executable with approved permissions; no software was installed.

## File-reading cost estimates only

| Task | Without rbxmap | Find + first returned range | Ratio |
|---|---:|---:|---:|
| Lobby lighting | 16,965 | 971 | 17.5x |
| Shop purchase | 4,574 | 734 | 6.2x |
| Player data saving | 1,927 | 705 | 2.7x |

These are estimates of file-reading cost, NOT measured agent usage or costs for completing a change. Without: characters/4 for selected likely files; with: reported search tokens plus read_lines for the top match. Further investigation costs more. This repo has one LobbyBuilder.luau file, not a LobbyBuilder folder. Lobby baseline also includes AtmosphereController; shop uses ShopService and Outfitter; data uses DataService. See token-estimates.json.

## Git status before

```text
M  AGENTS.md
?? .mcp.json
```

## Git status after

```text
MM AGENTS.md
 M CLAUDE.md
 M HANDOFF.md
?? .mcp.json
?? .rbxmap/
?? DESIGN.md
?? MAP.md
```

AGENTS was already staged; its staged content remains unchanged. MM reflects the additional unstaged instruction merge. No .lua/.luau files changed.

# 2. DONE BUT NOT VERIFIED

Claude Code is not installed on this PC, so the .mcp.json entry is prepared but untested. Specifically, Get-Command claude found no command on PATH; an installation elsewhere cannot be ruled out.

Codex registration and actual stdio calls passed, but loading tools in a newly restarted Codex/Claude session needs your check. Ask the new agent to call find_script for lobby lighting and inspect its tool call.

# 3. NOT DONE

No software installation, game-code edit, Studio playtest, Git staging, commit or push. These were prohibited or outside setup scope. Existing unsynced Studio changes cannot be examined by the repository index. No description rewrites were needed. Dynamic remote resolution is incomplete as described above. Full Lune game gate was not run; the requested rbxmap check passed.

# 4. FILES CHANGED

Backup folder: `C:\Users\tameg\Documents\rbxmap-backups\20261006-setup-01`

Modified existing files:
- AGENTS.md (appended marked rules)
- CLAUDE.md (appended marked reference)
- .mcp.json (added server; already untracked before setup)
- HANDOFF.md (appended setup status)
- C:\Users\tameg\.codex\config.toml (appended MCP server)

Added project files:
- MAP.md
- DESIGN.md
- .rbxmap/.gitignore
- .rbxmap/SETUP_REPORT.md
- .rbxmap/START_HERE.md
- .rbxmap/aliases.json
- .rbxmap/check-results.json
- .rbxmap/codex-registration.diff
- .rbxmap/config.json
- .rbxmap/descriptions.json
- .rbxmap/find-data.json
- .rbxmap/find-lobby.json
- .rbxmap/find-shop.json
- .rbxmap/index.db
- .rbxmap/instruction-merge.diff
- .rbxmap/integrity-proof.json
- .rbxmap/mcp-proof.json
- .rbxmap/tmp/check.rbxl
- .rbxmap/token-estimates.json

Only AGENTS.md.new and CLAUDE.md.new were created then deleted. check.rbxl is retained because deletion was not authorized. Backup files: AGENTS.md, CLAUDE.md, .mcp.json, HANDOFF.md, config.toml, status-before.txt, source-hashes.json, git-index-hash.json.

# 5. THE LIGHTING FINDING

AtmosphereController owns global Lighting, ClockTime, atmosphere and sky; it initializes effects then applies lighting on every RenderStepped frame.
LobbyBuilder builds physical lamps and PointLights; it does not set global Lighting or ClockTime, so these scripts do not compete for those properties.
LobbyService builds the lobby during server Init; the client initializes then starts AtmosphereController after loading its controllers. Remotes replication is a dependency, not a guarantee the entire lobby is already built.
Near the lobby, the controller selects lobby time and Sky's lobby adjustments (unless a developer hour override is active). It overrides global Studio lighting values each frame.
This is certain for repository code; Studio-only edits and the live appearance remain unverified.

# 6. WHAT I MUST DO MYSELF

1. Close and reopen Codex; start a new chat in this project. Paste: `Use rbxmap find_script for lobby lighting. Do not open files yet.` Confirm an actual tool call.
2. If you want Claude Code and it is not already installed elsewhere, follow the official installation instructions: https://code.claude.com/docs/en/setup . The documented Windows PowerShell command is below. Nothing was installed by this setup.

```powershell
irm https://claude.ai/install.ps1 | iex
```

Then open a NEW terminal:

```powershell
claude --version
cd C:\Users\tameg\Documents\Roblox\my-roblox-game
claude
```

Complete login and approve the project's rbxmap MCP server if prompted. Ask the same find_script prompt. Use START_HERE.md for future sessions. Reconcile existing Studio-only edits before future game changes.

# 7. HOW TO UNDO

Close Codex and Claude first. These commands restore the pre-setup files and archive the additions without deleting them. If you have made later edits, merge the backups instead of overwriting those later edits. Run once in PowerShell:

```powershell
$rbxBackup = 'C:\Users\tameg\Documents\rbxmap-backups\20261006-setup-01'
$rbxProject = 'C:\Users\tameg\Documents\Roblox\my-roblox-game'
foreach ($rbxName in @('AGENTS.md', 'CLAUDE.md', '.mcp.json', 'HANDOFF.md')) {
    Copy-Item -LiteralPath (Join-Path $rbxBackup $rbxName) -Destination (Join-Path $rbxProject $rbxName) -Force
}
Copy-Item -LiteralPath (Join-Path $rbxBackup 'config.toml') -Destination 'C:\Users\tameg\.codex\config.toml' -Force
$rbxArchive = Join-Path $rbxBackup ('disabled-setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $rbxArchive | Out-Null
foreach ($rbxName in @('.rbxmap', 'MAP.md', 'DESIGN.md')) {
    $rbxSource = Join-Path $rbxProject $rbxName
    $rbxResolved = (Resolve-Path -LiteralPath $rbxSource).Path
    if ((Split-Path -Parent $rbxResolved) -ne $rbxProject) { throw 'Unexpected path; stopped.' }
    Move-Item -LiteralPath $rbxResolved -Destination $rbxArchive
}
```

Restart agents. Existing Roblox_Studio registration and original staged state remain intact. The separate original rbxmap tool installation is left in place.
