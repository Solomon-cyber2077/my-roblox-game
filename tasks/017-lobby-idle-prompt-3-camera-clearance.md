# 017: Lobby idle prompt 3 camera clearance
<!-- rbxmap:meta {"id":"017","created":"2026-10-23","query":"","hashes":{"src/shared/Config/Tuning.luau":"0c93780ac63daaa5"}} -->
Status: done

## Goal
(planner: one or two sentences: what should be different when this is done)

## Context (auto-filled by rbxmap for query: "")
- (no query given)

## Files to edit
- `src/shared/Config/Tuning.luau`
- UNVERIFIED src/shared/Logic/CameraClearance.luau
- UNVERIFIED tests/CameraClearance.spec.luau
- UNVERIFIED src/client/Camera/IdleClearance.luau
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
- Claude: 8 CameraClearance specs pass, `lune run check` exit 0; Studio mesh hits pending prompt 4 wiring.
