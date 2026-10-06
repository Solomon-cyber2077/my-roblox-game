# Start here: rbxmap
rbxmap finds Roblox scripts on disk. Rojo syncs those files to Studio.

## Start a fresh session
1. Close and reopen Codex or Claude Code, then open this project in a new session.
2. Approve the project rbxmap server if asked.
3. Paste one of the prompts below.

## Prompts to paste
- “Use rbxmap find_script for lobby lighting. Read only the returned lines.”
- “Use rbxmap find_script for shop purchase, then explain the handler.”
- “Use rbxmap find_script for player data saving, then write a brief.”

You should see a `find_script` call followed by a file path and line range. Folder browsing or broad grep means the workflow was not followed.

## Rules
Agents edit script files on disk; Studio is for playtesting and checking. After adding or renaming scripts, ask for MCP `refresh` or run rbxmap `index`.
If tools do not load, use the CLI fallback in AGENTS.md.

## Undo
Close the agents. Restore files from `C:\Users\tameg\Documents\rbxmap-backups\20261006-fix-02` to their original paths, including `.rbxmap\START_HERE.md`.
Copy files individually and preserve the `.rbxmap` paths; do not run `git reset`, checkout, or delete game source.
