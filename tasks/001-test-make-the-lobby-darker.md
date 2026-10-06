# 001: Test: make the lobby darker
<!-- rbxmap:meta {"id":"001","created":"2026-10-06","query":"lobby lighting","hashes":{"src/client/Controllers/AtmosphereController.luau":"7725bda2a5fd14a9","src/server/Builders/LobbyBuilder.luau":"9f378fdb8c9c4cef","src/client/UI/Lobby.luau":"3046f2b6a91a4a72"}} -->
Status: done

## Goal
Setup test only: verify that lobby lighting selects AtmosphereController and the brief contains safe build/test instructions. No gameplay change is authorized by this test.

## Context (auto-filled by rbxmap for query: "lobby lighting")
- StarterPlayer > StarterPlayerScripts > Client > Controllers > AtmosphereController — `src/client/Controllers/AtmosphereController.luau` lines 465-530 (AtmosphereController.Start)
- ServerScriptService > Server > Builders > LobbyBuilder — `src/server/Builders/LobbyBuilder.luau` lines 419-484 (LobbyBuilder.build)
- StarterPlayer > StarterPlayerScripts > Client > UI > Lobby — `src/client/UI/Lobby.luau` lines 153-195 (task.spawn(fn))

## Files to edit
- `src/client/Controllers/AtmosphereController.luau`

## Files NOT to touch
- All game code for this setup test; the file above is a verified candidate for a future separately requested change.

## Constraints
- For a future authorized implementation, edit only listed script FILES on disk; Rojo syncs them to Studio. Never edit scripts with Roblox_Studio multi_edit or execute_luau.
- Studio-only content is not indexed. The present task validates this brief only.

## Acceptance checks
- [x] AtmosphereController is the sole verified file-to-edit candidate; ranges and source hashes are recorded.
- [ ] `rbxmap check` passes (rojo build, selene, stylua) where installed

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. For a future lighting implementation, use Roblox_Studio start_stop_play to start Play, get_console_output to inspect errors, and screen_capture to check the lobby.
3. Verify lobby brightness persists across frames, physical lamps remain intact, and Output has no new errors; stop Play with start_stop_play.
4. If tools are unavailable, perform the same Play/Output/screenshot checks manually and report that automation was unavailable.
5. No Studio playtest was performed for this metadata-only setup test.

## Builder notes

- Setup validation completed without editing game code. The CLI template is hardcoded; agent marker instructions require these constraints and checks in every future brief.
