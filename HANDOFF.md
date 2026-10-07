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

- 2026-10-06: lobby back wall (departure board, ticket windows) was dark: front fills at z13 range 60 never reached z72. Added a back row of 3 FillLights (x -44/0/44, y26, z52, 0.85/45) in `Builders/LobbyBuilder`. Verified in Studio Play; `lune run check` passes.

## Known bugs / regressions
- Place saved successfully to `C:\Users\tameg\OneDrive\Documents\Roblox.rbxl`; Studio DataStores are unavailable, so player profile saving is disabled for this session.
- Studio Play verified all eight adjusted lights and visible floor/rear-hall coverage; repository lune run check passes. Save the changed place in Studio.

## Next logical step
- Save the place in Studio, then reconcile Studio edits with Rojo before syncing.

## rbxmap setup — 2026-10-06
- Completed: 119-script local index, agent instructions, remote wrappers, Codex/Claude registrations, real MCP call, and passing doctor/Rojo/Selene/StyLua checks. See .rbxmap/START_HERE.md. Game source and Git staged state unchanged; no commit or push.
- Limitations: Claude CLI absent; new agent-session loading and Studio appearance unverified. Remote scanner retains generic dynamic-name rows. README argument order is wrong: put --project before serve/doctor.
- Next: restart Codex and test find_script; optionally install/start Claude Code. Reconcile existing Studio-only edits before Rojo syncing.

## 2026-10-06: Lobby HUD restyle
1. Done: `UI/Lobby.luau` profile card and departure panel have no background; their text is bolder with a dark outline (white text, brass for BRASS). OUTFITTER is now a dark Secondary button like LINE MASTERY, and both sit in a row under the profile card on the left. Checked in Studio play, console clean.
2. Known issues: none. `Ui.ticket` is no longer used by the lobby.
3. Next: check that the outlined text reads well over bright lobby floor tiles at small screen sizes.

## 2026-10-06: Lobby HUD tweaks
1. Done: `UI/Lobby.luau` name reads `OPERATOR: <name>`; CREW RANK/XP line is Oswald Bold 20 (was 17); PROGRESS NOT SAVED is white Oswald Bold 17 (was red BuilderSans 13); LINE MASTERY now stacks under OUTFITTER with 8px gap. Studio play checked, console clean.
2. Known issues: very long display names may overflow the 260px name label.
3. Next: same as above (readability over bright tiles).
