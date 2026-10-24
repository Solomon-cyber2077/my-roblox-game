# 018: Lobby idle prompt 4 interruptible orbit
<!-- rbxmap:meta {"id":"018","created":"2026-10-23","query":"","hashes":{"src/shared/Config/Tuning.luau":"04e0904fe5d1ab3d","src/shared/Logic/LobbyIdle.luau":"1896b8827438674d","src/client/init.client.luau":"a14293efceb392e6"}} -->
Status: done

## Goal
(planner: one or two sentences: what should be different when this is done)

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/shared/Config/Tuning.luau`
- `src/shared/Logic/LobbyIdle.luau`
- UNVERIFIED tests/LobbyIdle.spec.luau
- UNVERIFIED src/client/Camera/IdleOrbit.luau
- UNVERIFIED src/client/Controllers/LobbyIdleController.luau
- `src/client/init.client.luau`
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
- Claude: orbit verified in Studio (starts after 12 s, D key cancels); Focus-held bug fixed in LobbyIdleInput (added to scope).
