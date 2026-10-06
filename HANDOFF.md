# HANDOFF
Updated at the end of every task. Read this, AGENTS.md, and git diff to resume.

## Features completed
- Full run loop: lobby, route vote, ten stops, Terminus, summary
- Hollows with grabs/struggle/pry; enterable buildings; station hazards
- Chunked landscape, sky with blood moon and omens, train camera, procedural crew animation
- AI kit installed (AGENTS.md, HANDOFF.md, TASKS.md, .claude, .codex)
- Fixed Studio Roblox.rbxl LobbyBuilder station master NPC startup error (`C.navy` undefined; corrected to existing `C.night`). Verified Studio Play starts the server, DepotHall has 2973 descendants, and the character, camera, and 4 GUI elements spawn. `lune run check` passes.
- Studio source contains unsynced additions absent from the repository; no repository gameplay source changed.
- Studio `ServerScriptService.Server.Builders.LobbyBuilder`: adjusted lobby fill lights, lowering them from y30 to18 and moving z13 to32; brightness/range changed from .4/38 to 1.1/60. Corner fills lowered y26 to16 with .35/32 changed to .8/44. Studio-only patch preserves unsynced additions.

## Known bugs / regressions
- Place saved successfully to `C:\Users\tameg\OneDrive\Documents\Roblox.rbxl`; Studio DataStores are unavailable, so player profile saving is disabled for this session.
- Studio Play verified all eight adjusted lights and visible floor/rear-hall coverage; repository lune run check passes. Save the changed place in Studio.

## Next logical step
- Save the place in Studio, then reconcile Studio edits with Rojo before syncing.
