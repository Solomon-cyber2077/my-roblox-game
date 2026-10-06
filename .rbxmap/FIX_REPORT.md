# 1. FIXED AND VERIFIED
- Backup: `C:\Users\tameg\Documents\rbxmap-backups\20261006-fix-02`.
- Existing launcher works outside the Codex sandbox. Initial sandbox attempt failed with `uv trampoline failed to canonicalize script path`; existing Python CLI was a working fallback. `python -m rbxmap` is unsupported; use the fallback in AGENTS.md.
- `rbxmap --project <game> index`: added 0, updated 0, removed 0, unchanged 119, total 119.
- `rbxmap --project <game> doctor`: all checks OK, `All good.`
- `rbxmap --project <game> check`: Rojo exit 0; Selene exit 0, 0 errors/0 warnings/0 parse errors; StyLua exit 0. See check-fix-02.json.
- `codex mcp list`: rbxmap enabled, command `C:/Users/tameg/Documents/rbxmap/.venv/Scripts/rbxmap.exe`, args `--project C:/Users/tameg/Documents/Roblox/my-roblox-game serve`.
- Real local stdio MCP session: 11 tools, find_script returned AtmosphereController first, is_error=false. See mcp-fix-02.json. No code was sent over the network.
- Five of six required ranking cases pass; physical `lights` also returns LobbyBuilder first. Existing aliases retained, with new owner aliases and descriptions. Multiword aliases are saved as requested; additional time/day/build keys are needed because search expands individual words.

| Query | First result and lines | Second result and lines | Approx. tokens (entire response) |
|---|---|---|---|
| lobby lighting | `src/client/Controllers/AtmosphereController.luau:465-530` | `src/server/Builders/LobbyBuilder.luau:419-484` | 354 |
| make the lobby darker | `src/client/Controllers/AtmosphereController.luau:465-530` | `src/server/Services/LobbyService.luau:44-57` | 373 |
| change time of day | `src/client/Controllers/AtmosphereController.luau:456-521` | `src/server/Services/ProgressionService.luau:31-96` | 328 |
| sky color | `src/client/Scenery/Sky.luau:557-622` | `src/client/Controllers/AtmosphereController.luau:98-163` | 376 |
| lobby lamps | `src/server/Builders/LobbyBuilder.luau:92-157` | `src/server/Services/LobbyService.luau:44-57` | 347 |
| build the lobby | `src/server/Builders/LobbyBuilder.luau:92-157` | `src/client/Controllers/AtmosphereController.luau:465-530` | 349 |
| shop purchase | `src/server/Services/ShopService.luau:53-86` | `src/client/UI/Outfitter.luau:203-268` | 355 |
| player data saving | `src/server/Services/DataService.luau:196-237` | `src/client/UI/Summary.luau:35-100` | 354 |
| lights | `src/server/Builders/LobbyBuilder.luau:419-484` | `src/shared/Visual/Kit.luau:169-192` | 323 |

- Full compact CLI map: 873 approximate tokens. Full MAP.md document: approximately 6,979 tokens using characters/4; these are different outputs.
- AGENTS.md and CLAUDE.md edits are confined to their markers; bytes outside both blocks match the backup. MAP.md notes outside its markers also match byte-for-byte.
- See `instructions-fix-02.diff` for both requested instruction diffs. Both marker blocks and START_HERE.md are under 40 lines.
- Brief: `tasks/001-test-make-the-lobby-darker.md`, status done. Its sole candidate file is AtmosphereController; generated context includes verified ranges and source hashes. Added disk-only editing constraints and named Studio checks. No gameplay implementation was performed.
- All 119 source files and their file set are unchanged; Git index hash is unchanged. No .lua/.luau was edited, created, deleted, renamed or formatted. No commit, push, install, or history/staging change.
- Git status before: `MM AGENTS.md`, modified CLAUDE.md/HANDOFF.md, untracked .mcp.json/.rbxmap/DESIGN.md/MAP.md. After: same entries plus untracked tasks/. Existing HANDOFF.md modification predates this task.

# 2. NOT FIXED OR UNVERIFIED
- **Sky color ranking:** Sky remains first, AtmosphereController second. Attempt 1 added requested owner descriptions and aliases (including word aliases for time/day/build). Attempt 2 added color -> AtmosphereController. Search gives a literal script/path word 1.0 coverage versus 0.8 for aliases/descriptions: Sky gets 1.8 for this query and AtmosphereController 1.6. Further description weighting cannot override this ordering. No rbxmap source changed. Agent instructions explicitly route global sky changes to AtmosphereController; use its name for an unambiguous query.
- **Task template:** hardcoded in rbxmap's source, with no template configuration hook. The test brief is corrected and agent instructions require those constraints/checks for future briefs. The CLI itself will still generate the original template; changing its default requires a future rbxmap source change.
- **Remote names:** 20 table rows total, not 20 unresolved rows. Four unresolved names occur at eight locations: `?` at NetService:54; `name` at NetService:72/90/94/99; `event` at client Net:18/22; `RemoteEvent` at DevService:180 (actually Dev, assigned at 178). DevService:196 is an additional false-positive fire_server entry from printed text. Exact paths and reasons are in DESIGN.md, outside generated markers.
- Existing remote_wrappers already recover literal call sites. They map helper calls to operation kinds, not runtime name resolution or exclusions; no supported config fix exists for the remaining rows. Config left unchanged.
- Fresh Codex/Claude desktop session loading remains unverified. Local registration and server protocol work. Claude desktop's live server list/tool count was not inspected; its project .mcp.json declares both servers, and this Codex session exposes 28 Roblox_Studio tools.
- Studio Play was not run: this task changes search metadata and instructions only, and authorizes no game change. The brief records future Play, console and screenshot steps; existing Studio-only edits remain outside this index. No live appearance claim is made.

# 3. THE HANDOFF.md EXPLANATION
Both the 20261006-setup-01 backup and Git show the same addition: a blank line, an `rbxmap setup — 2026-10-06` heading and three bullets about completion, limitations and next steps. Nothing original was removed or edited. No restoration was needed, and HANDOFF.md was left byte-for-byte unchanged during this task. The old suggestion to optionally install Claude Code is unnecessary for your existing desktop setup; start a fresh desktop coding session instead.

# 4. FILES CHANGED
Project root: `C:\Users\tameg\Documents\Roblox\my-roblox-game`.
Existing files changed:
- AGENTS.md
- CLAUDE.md
- MAP.md (generated descriptions; personal notes preserved)
- DESIGN.md (remote limitations outside generated markers)
- .rbxmap/descriptions.json
- .rbxmap/aliases.json
- .rbxmap/START_HERE.md
- .rbxmap/index.db (generated local index/cache; ignored by Git; SQLite may create sidecars)
New deliverables:
- tasks/001-test-make-the-lobby-darker.md
- .rbxmap/instructions-fix-02.diff
- .rbxmap/ranking-fix-02.json
- .rbxmap/check-fix-02.json
- .rbxmap/mcp-fix-02.json
- .rbxmap/integrity-fix-02.json
- .rbxmap/FIX_REPORT.md
Unchanged: HANDOFF.md, .mcp.json, .rbxmap/config.json, gameplay source, Git index, and the pre-existing .rbxmap/tmp/check.rbxl. No new scratch files remain.
Backup folder: `C:\Users\tameg\Documents\rbxmap-backups\20261006-fix-02`. It includes original setup files, .rbxmap JSON files/START_HERE, the generated brief before supplementation, the pre-existing temporary build, source hashes and Git status/index hash. Do not confuse the generated brief backup with a pre-task file.

# 5. WHAT I MUST DO MYSELF
1. Start a NEW Codex or Claude Code desktop session in this project so the registered tools and revised instructions load.
2. Paste: “Use rbxmap find_script for lobby lighting; show the owner and returned range.” Expect AtmosphereController, lines 465-530.
3. For a future actual lighting change: sync only after reconciling the pre-existing Studio-only edits noted in HANDOFF.md; Play, check lobby appearance, inspect Output for new errors, take a screenshot, and Stop. Ask the agent to perform the named Studio checks if available.

# 6. HOW TO UNDO
Run the following in PowerShell after closing agent sessions. This restores only setup files changed by this task, regenerates the derived index from the restored settings, and removes only this task's newly created deliverables. It leaves existing gameplay, HANDOFF, registration and Git staging/history alone. Save any later edits to these specific files first.

```powershell
$ErrorActionPreference = 'Stop'
$project = 'C:\Users\tameg\Documents\Roblox\my-roblox-game'
$backup = 'C:\Users\tameg\Documents\rbxmap-backups\20261006-fix-02'
foreach ($file in @('AGENTS.md','CLAUDE.md','MAP.md','DESIGN.md')) {
    Copy-Item -LiteralPath (Join-Path $backup $file) -Destination (Join-Path $project $file) -Force
}
foreach ($file in @('aliases.json','descriptions.json','START_HERE.md')) {
    Copy-Item -LiteralPath (Join-Path "$backup\.rbxmap" $file) -Destination (Join-Path "$project\.rbxmap" $file) -Force
}
& 'C:\Users\tameg\Documents\rbxmap\.venv\Scripts\python.exe' -c 'from rbxmap.cli import main; main()' --project $project index
if ($LASTEXITCODE -ne 0) { throw 'Index rebuild failed; original files are restored.' }
# Preserve the exact original generated documents after rebuilding the cache.
foreach ($file in @('MAP.md','DESIGN.md')) {
    Copy-Item -LiteralPath (Join-Path $backup $file) -Destination (Join-Path $project $file) -Force
}
foreach ($file in @('tasks\001-test-make-the-lobby-darker.md','.rbxmap\instructions-fix-02.diff','.rbxmap\ranking-fix-02.json','.rbxmap\check-fix-02.json','.rbxmap\mcp-fix-02.json','.rbxmap\integrity-fix-02.json','.rbxmap\FIX_REPORT.md')) {
    $target = Join-Path $project $file
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
}
```
