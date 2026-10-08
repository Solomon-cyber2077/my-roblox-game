# 006: Brief M: client-only monster cosmetics
<!-- rbxmap:meta {"id":"006","created":"2026-10-07","query":"hollow animator cosmetics","hashes":{"src/client/Controllers/HollowAnimator.luau":"3c9f933efaf63921","src/client/Animation/HollowPoses.luau":"e4c23c737cfa7645","src/server/Services/CrewService.luau":"d8bc6ec2d6b68b84","src/shared/Config/Tuning.luau":"0126535fbdeae1f5"}} -->
Status: in-progress

## Goal
Client-only Stalker/Crawler cosmetics: progressive grime, jaw stains/drips, hair, coat details, seeded accessories, aggression-driven eyes, reused dust/breath, chest smoke and small idle neck/jaw offsets. Full specification is Brief M in the user conversation. No gameplay or original rig geometry changes.

## Context (auto-filled by rbxmap for query: "hollow animator cosmetics")
- StarterPlayer > StarterPlayerScripts > Client > Controllers > HollowAnimator — `src/client/Controllers/HollowAnimator.luau` lines 195-243 (onState)
- StarterPlayer > StarterPlayerScripts > Client > Animation > HollowPoses — `src/client/Animation/HollowPoses.luau` lines 237-302 (stalkerGrab)
- ServerScriptService > Server > Services > CrewService — `src/server/Services/CrewService.luau` lines 123-164 (buildR6)

## Files to edit
- `src/client/Controllers/HollowAnimator.luau`
- `src/shared/Config/Tuning.luau`
- UNVERIFIED src/client/Visual/HollowCosmetics.luau
- UNVERIFIED src/shared/Logic/GrimeLevel.luau
- UNVERIFIED tests/GrimeLevel.spec.luau
- UNVERIFIED HANDOFF.md

## Files NOT to touch
- All server files, Difficulty.luau and every task 002 file; HollowPoses, Grabs, Types, Remotes, bootstrap and unrelated files.

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.
- On-disk edits only, never Studio edits. Read existing attributes only; no replicated state or new attributes. No original part size, joint-frame, physics, AI or gameplay changes.
- Cosmetics: welded, unanchored, Massless, non-colliding/non-querying/non-touching. One existing animator loop; no per-frame creation. At most 40 added parts, one light, four managed emitters, total rate <=10 and lifetime <=1.5 seconds; cull at 120 studs.
- Pure GrimeLevel: clamp((stop-1)/count,0,1), Terminus=1. Variation uses existing full Seed and dedicated Rng stream; factors within 0.9..1.1.
- Missing or unsafe features are flag-or-skip. No uploaded assets; preserve skeletal non-gory style.
- User explicitly authorized Codex implementation and proceeding despite the existing task 002 dwell test failure. Leave that work untouched, verify identical failure before/after and document separately. NO COMMIT unless full check passes or user authorizes otherwise.

## Acceptance checks
- [ ] Both kinds visibly differ at early/late stops; effects cull; no duplicated effects or gameplay/rig changes.
- [ ] Pure progression and variation tests pass; run lune run check and compare baseline failure.
- [ ] `rbxmap check` passes (rojo build, selene, stylua) where installed

## Manual test steps in Studio
1. Start `rojo serve`, connect the Rojo plugin, press Play.
2. Use start_stop_play, get_console_output and screen_capture (0.5 scale where supported). Compare both kinds at stops 1 and 10; check Prowl/Hunt/Grab, distance gating, cleanup and restart. Report unverified checks explicitly.

## Builder notes
