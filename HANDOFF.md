# HANDOFF
Updated at the end of every task. Read this, AGENTS.md, and git diff to resume.

## Features completed
- Full run loop: lobby, route vote, ten stops, Terminus, summary
- Hollows with grabs/struggle/pry; enterable buildings; station hazards
- Chunked landscape, sky with blood moon and omens, train camera, procedural crew animation
- AI kit installed (AGENTS.md, HANDOFF.md, TASKS.md, .claude, .codex)
- Fixed Studio Roblox.rbxl LobbyBuilder station master NPC startup error (`C.navy` undefined; corrected to existing `C.night`). Verified Studio Play starts the server, DepotHall has 2973 descendants, and the character, camera, and 4 GUI elements spawn. `lune run check` passes.
- Studio source contains unsynced additions absent from the repository; no repository gameplay source changed.

## Known bugs / regressions
- Place saved successfully to `C:\Users\tameg\OneDrive\Documents\Roblox.rbxl`; Studio DataStores are unavailable, so player profile saving is disabled for this session.

## Next logical step
- Playtest a full run and reconcile Studio edits with Rojo before syncing.
