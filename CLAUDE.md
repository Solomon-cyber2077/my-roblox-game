@AGENTS.md

<!-- rbxmap:start -->
## rbxmap workflow
- Read the brief first; use `find_script` first for code, then `read_lines` only for its returned range (max 150 lines). Never browse folders or grep the project.
- Do not use Roblox_Studio `script_search`, `script_grep`, or `search_game_tree` to find scripts. Studio-only content is not indexed; if no result, say so and ask me; never guess paths.
- Edit script files on disk; Rojo syncs them to Studio. Do not use Studio `multi_edit` or `execute_luau` for edits.
- Use Roblox_Studio only for checking: `start_stop_play`, `get_console_output`, `screen_capture`, `get_studio_state`.
- After every change, playtest, read the console for errors, and report what you saw. If unavailable, say so and list manual Studio steps.
- Never claim a change works without running it.
- Lobby brightness, exposure and ambient live in the LOBBY table in `Scenery/Sky.luau` and `AtmosphereController` cannot override them. The lobby floor is mostly lit by the fill and pendant PointLights in `Builders/LobbyBuilder` (about lines 438-482). Changes under 30% to the global values are barely visible. Rojo only updates Studio's edit copy, so stop and restart play to see changes.
- After adding or renaming scripts, call `refresh`; if MCP is unavailable, use the rbxmap CLI `index`.
- Edit only files listed in the brief; set task in-progress/done, run `check`, and report results plus Studio steps.
- Codex is the planner: it verifies paths and writes briefs without editing game code. Claude Code is the builder: it edits only the brief's listed files.
- Every generated brief must require on-disk edits (never Studio) and the checks `start_stop_play`, `get_console_output`, and `screen_capture`.
- CLI fallback: `C:\Users\tameg\Documents\rbxmap\.venv\Scripts\python.exe -c "from rbxmap.cli import main; main()" --project "C:\Users\tameg\Documents\Roblox\my-roblox-game" <command>`.
<!-- rbxmap:end -->
