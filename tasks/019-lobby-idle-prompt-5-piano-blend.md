# 019: Lobby idle prompt 5 piano blend
<!-- rbxmap:meta {"id":"019","created":"2026-10-23","query":"","hashes":{"src/shared/Config/Tuning.luau":"eebb19eccae0f44b","src/shared/Logic/LobbyIdle.luau":"5144001818a7d6b7","src/client/Controllers/AudioController.luau":"71cdd97019b7d2a7","src/client/Controllers/PianoNotes.luau":"2dc17f9f2d358a84","src/client/Controllers/LobbyIdleController.luau":"e0280e657c989c55"}} -->
Status: done

## Goal
(planner: one or two sentences: what should be different when this is done)

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/shared/Config/Tuning.luau`
- `src/shared/Logic/LobbyIdle.luau`
- UNVERIFIED tests/LobbyIdle.spec.luau
- `src/client/Controllers/AudioController.luau`
- `src/client/Controllers/PianoNotes.luau`
- `src/client/Controllers/LobbyIdleController.luau`
- UNVERIFIED HANDOFF.md

## Files NOT to touch
- (planner: list files the builder must leave alone)

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.

## Acceptance checks
- [ ] (planner: observable result, e.g. "lobby is darker at spawn")
- [ ] `rbxmap check` passes (rojo build, selene, stylua) where installed

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. (planner: what to look at / click, and what you should see)

## Builder notes
- Claude: fades verified in Studio by readout (not by ear); gate passes.
