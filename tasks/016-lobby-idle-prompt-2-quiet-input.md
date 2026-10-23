# 016: Lobby idle prompt 2 quiet input
<!-- rbxmap:meta {"id":"016","created":"2026-10-23","query":"","hashes":{"src/shared/Logic/LobbyIdle.luau":"1896b8827438674d"}} -->
Status: done

## Goal
Add an injected-time quiet policy and an unbooted, disposable client input observer. No camera/audio connection; eligibility integration belongs to prompt 6.

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/shared/Logic/LobbyIdle.luau`
- UNVERIFIED tests/LobbyIdle.spec.luau
- UNVERIFIED src/client/Controllers/LobbyIdleInput.luau
- UNVERIFIED HANDOFF.md

## Files NOT to touch
- All camera, audio, boot and existing UI scripts.

## Constraints
- Edit only the files listed above. Make on-disk edits only; never edit through Studio.

## Acceptance checks
- [x] Twelve continuous eligible seconds, held-input stalls, first-snapshot boundary, backward clock and one-attempt behavior have passing specs.
- [x] `rbxmap check` passes (rojo build, selene, stylua) where installed

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Run start_stop_play, get_console_output, screen_capture in the isolated window; existing lobby behavior must remain unchanged. Observer is deliberately unbooted until prompt 6, so hardware behavior remains pending that integration.

## Builder notes
- Finished by Claude (2026-10-23): five LobbyIdle specs pass; `lune run check` exit 0 (StyLua, selene, luau-lsp strict, tests, audit clean). LobbyIdleInput is not in the client boot list, so Studio behaviour is unchanged until prompt 6.

