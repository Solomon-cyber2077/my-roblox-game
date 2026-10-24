# 020: Lobby idle prompt 6 eligibility and accessibility
<!-- rbxmap:meta {"id":"020","created":"2026-10-23","query":"","hashes":{"src/shared/Config/Tuning.luau":"4eb61bc3f23937be","src/shared/Logic/LobbyIdle.luau":"b6047db9d37d1b5e","src/client/UI/Menu.luau":"efe33a05ef1428cb","src/client/Controllers/LobbyIdleController.luau":"8ccd4a341d266a50"}} -->
Status: done

## Goal
(planner: one or two sentences: what should be different when this is done)

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/shared/Config/Tuning.luau`
- `src/shared/Logic/LobbyIdle.luau`
- UNVERIFIED tests/LobbyIdle.spec.luau
- `src/client/UI/Menu.luau`
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
- Claude: hall bound, MENU dropdown and Roblox menu verified in Studio; respawn/death/countdown not exercised.
