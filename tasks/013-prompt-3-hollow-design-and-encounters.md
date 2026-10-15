# 013: Prompt 3: Hollow design and encounters
<!-- rbxmap:meta {"id":"013","created":"2026-10-14","query":"hollow monster cosmetics","hashes":{"src/client/Visual/HollowCosmetics.luau":"2494f196b5045aeb","src/shared/Logic/GrimeLevel.luau":"7fd1d2392133e9c5","src/client/Controllers/HollowAnimator.luau":"f7f53015614a6a31","src/server/Builders/HollowBuilder.luau":"e2356c9136ab276f","src/client/Animation/HollowPoses.luau":"8ea432120a311e87","src/shared/Config/Tuning.luau":"8bf0f73a8cd64506","src/server/Services/HollowService.luau":"b454460bbc10e76b"}} -->
Status: in-progress

## Goal
Give the Tall Stalker and Crawler distinct, source-aware silhouettes and progressively more contorted station variants,
with fluid movement, obstacle-aware pursuit, seeded encounter variation, and sound-led reveals. Preserve the Brute and
keep all changes within the monster systems.

## Context (auto-filled by rbxmap for query: "hollow monster cosmetics")
- StarterPlayer > StarterPlayerScripts > Client > Visual > HollowCosmetics — `src/client/Visual/HollowCosmetics.luau` lines 43-79 (part)
- ReplicatedStorage > Shared > Logic > GrimeLevel — `src/shared/Logic/GrimeLevel.luau` lines 20-32 (GrimeLevel.variation)
- StarterPlayer > StarterPlayerScripts > Client > Controllers > HollowAnimator — `src/client/Controllers/HollowAnimator.luau` lines 380-445 (register)

## Files to edit
- `src/client/Visual/HollowCosmetics.luau`
- `src/server/Builders/HollowBuilder.luau`
- `src/client/Animation/HollowPoses.luau`
- `src/client/Controllers/HollowAnimator.luau`
- `src/shared/Config/Tuning.luau`
- `src/shared/Logic/GrimeLevel.luau`
- `tests/GrimeLevel.spec.luau`
- `src/server/Services/HollowService.luau`
- `LORE.md`
- `HANDOFF.md`
- `.lune/hollow-photo.luau`
- `tools/preview/hollow-photo.py`

## Files NOT to touch
- HUD/UI files
- train interior files
- station files
- lobby files
- NPC files
- Brute design files

## Constraints
- Edit only the files listed above. Studio-only content is not visible to agents.

## Acceptance checks
- [x] Task 1: Tall Stalker has ragged period clothing, bloody hands, long limbs, gaunt hunched silhouette, hands near face, and low-poly geometry.
- [x] Task 2: Crawler has long matted hair and shedding flesh; ragged clothing and bloody hands remain Stalker-only; Brute is unchanged.
- [ ] Task 3: Cosmetic milestones begin early and contortion increases visibly at stops 1, 3, 6, and 10 via half-scale captures or photo rig.
- [ ] Task 4: Hollow movement uses eased transitions, natural gait, and subtle twitches.
- [ ] Task 5: Hollows do not climb or hop; they route around solid cover and drop obstructed chases after bounded persistence.
- [ ] Task 6: Each station offers a sightline or patrol crossing for every enemy type in its roster; aggression changes detection, persistence, and cooldown, not sprint-relative speed.
- [ ] Task 7: Every reveal is foreshadowed by scraping, breath, or footsteps before sight.
- [ ] Task 8: Timing, patrols, and approach directions vary from a run-seeded shared source while preserving roster coverage and telegraphing danger.
- [x] Task 9: Tall Stalker silhouette remains suitable for later lobby window-storm reuse.
- [ ] `lune run check` passes; if Windows Application Control blocks Rojo, record the precise failure and run remaining checks.

## Manual test steps in Studio
1. Open the isolated `HollowDesignTest.rbxl`, start `rojo serve` on port `34873`, connect the Rojo plugin, and press Play.
2. Use the documented Dev hollow commands to spawn Stalker, Crawler, and Brute at stops 1, 3, 6, and 10.
3. Confirm each roster enemy is visible from the objective route, movement is fluid, cover is routed around, and audio/shadow telegraphs precede sight.
4. Capture scaled-down screenshots or use the photo rig for the four stop comparisons; run `get_console_output` and `screen_capture`.

## Builder notes

## Amended Prompt 3 (owner-authorized implementation, 2026-10-14)
The owner explicitly overrides the Codex-planner-only rule. Implement on codex/hollow-design based on claude/last-train-out; edit files on disk only, never through Studio. Small changes; one commit per numbered task and push each commit to this branch. Before merging notify the owner and wait for confirmation that concurrent Claude Code work is finished.

1. Tall Stalker first: ragged period clothing, bloody hands, very long limbs, gaunt hunched silhouette and hands near the face. SCP-096 is an inspiration only: original identity, no copied face-trigger mechanics. Keep geometry low-poly for later window-storm silhouette reuse. Commit first.
2. Crawler second: long matted hair and shedding flesh, suggesting an enduring never-dying creature. No added ragged clothing or bloody hands; those belong to Stalker only. Preserve Brute design. Commit second.
3. Bring late cosmetic milestones into early stops and build progressively stronger contortion through all stops. Compare stops 1, 3, 6, 10 using half-scale captures or the photo rig.
4. Fluid movement: eased transitions, natural gait and subtle twitches.
5. No climbing or hopping over fences/solid cover. Path around obstacles; abandon an obstructed chase after short bounded persistence. Work with Claude's tall solid station cover without editing station files.
6. Each station presents every enemy type in its roster on objective routes or crossing patrols. Guarantee an encounter opportunity, never force a grab. Aggression uses detection, persistence and attack cooldown; top speed remains below sprint.
7. Sound before sight for every reveal: distant scraping, breathing or footsteps.
8. Run-seeded timing, patrol and approach variation shared by the crew; preserve roster coverage. Sound/shadow telegraphs precede attacks.
9. Maintain the tall monster's low-poly silhouette for future lobby reuse, without editing the lobby.

## Exclusions and verification
Never edit HUD/UI, train interior, station files, lobby or NPC files. Shared configuration changes must be restricted to monster-owned entries. Web-check any period clothing, prop or colour claim before using it; correct LORE only where contradicted. Use Blender for design/preview as useful; no new uploaded assets without authorization.
Run lune run check before every commit; if Windows Application Control blocks Rojo, record the precise failure and run remaining checks. Run start_stop_play, get_console_output and screen_capture on a test instance synced to this worktree; do not interrupt Claude's instance. If unavailable, record manual restart/play steps and do not claim runtime verification. Update HANDOFF after each numbered task. Delete only self-created temporary files; ask before any other deletion. Refresh index after new scripts, rehash after brief file-list changes. Builder reads this brief first, rechecks stale ranges, sets in-progress/done and reports evidence.
