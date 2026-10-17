# 014: Remove lobby run tier button
<!-- rbxmap:meta {"id":"014","created":"2026-10-15","query":"","hashes":{"src/client/UI/Lobby.luau":"fe5c84ec2ba75d08"}} -->
Status: in-progress

## Goal
Remove the Run Tier button and plate from the lobby UI, including its UI-only handlers and refresh references. Preserve existing Ready and Join controls.

## Context (auto-filled by rbxmap for query: "")
- Verified with find_script and read_lines: src/client/UI/Lobby.luau, lines 407-446 create the RunTier frame and Pick button.

## Files to edit
- `src/client/UI/Lobby.luau`
- `HANDOFF.md`
- `AGENTS.md`

## Files NOT to touch
- All files except the listed UI module, HANDOFF.md, and AGENTS.md; preserve server tier behavior and remotes.

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.

## Acceptance checks
- [ ] Run Tier plate/button is absent; Ready/Unready and Join controls remain functional.
- [ ] `lune run check` passes; run builder rbxmap check where installed.

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Use start_stop_play to restart Play, get_console_output to check errors, and screen_capture to verify the missing Run Tier plate. Exercise Ready/Unready. Report unavailable playtesting with these manual steps.

## Builder notes
- 2026-10-15 21:10: Implementation brief for Claude Code: Remove the lobby Run Tier plate/button (RunTier frame, Pick TextButton, hover/activation handlers) from src/client/UI/Lobby.luau, confirmed at lines 407-446. Remove its remaining UI update references and any imports/locals made unused; locate them with find_script and read_lines, rechecking stale ranges. Keep underlying run-tier rules/state/remotes intact; this request removes the lobby control only. Read this brief first, mark in-progress, and edit only listed files ON DISK, never through Studio. Update HANDOFF.md with completed feature, known bugs/regressions, and next logical step. Run lune run check. Stop/restart Studio using start_stop_play, inspect get_console_output, and capture screen_capture to verify the Run Tier plate is absent and ready/join controls still work. If Studio tools are unavailable, explicitly report that limitation and manual steps: connect Rojo, stop then Play, confirm no Run Tier plate, exercise Ready/Unready and check Output. Never claim runtime success without playtesting. Mark done only after implementation and report checks; commit completed task with a clear message after check passes, do not push.
- 2026-10-15 21:12: Owner override 2026-10-15: Codex now implements as well as plans. AGENTS.md updated to grant Codex and Claude Code the same project role, permissions, and checks.
