VM2: Void Mist, Edge wall and fall rescue (Council 02)

Read AGENTS.md, CLAUDE.md and HANDOFF.md first. Source: The Council run 20261022-131445-would-a-mysterious-mist-that-p
(`tc pack 20261022-131445-would-a-mysterious-mist-that-p`, prompts/0N-*.md). The Council wrote generic Roblox prompts
(ReplicatedStorage/VoidMist, designer-placed tagged parts); these VM prompts are the same design mapped onto this
codebase. Where this file and the Council text disagree, this file wins. Work on branch `claude/void-mist`
(worktree ../LTO-mist, Studio place ../mist.rbxl, `rojo serve --port 34874`).
- Reconcile the "Baseline" below against the code first (rbxmap find_script, then read_lines); report drift.
- Edit on disk only. --!strict; numbers in Config/Tuning.VoidMist; pure rules in Logic/VoidMist with specs in tests/.
- Services go in the server ORDER and talk through Registry; remotes only via Net/Remotes + NetService; Lighting
  is client-owned (AtmosphereController); sounds are public ids in Config/Audio routed by Config/AudioPriority.
- Station-local space (StationService.ToLocal/ToWorld; the client mirrors it): x along the platform, z from the
  platform (0) back to plan.depth. The sinkhole is past +Z. The station MOVES on a PrismaticConstraint while
  arriving/departing, so store positions in station-local space, never as world CFrames.
- `lune run check` green. In Studio: start_stop_play, get_console_output, screen_capture (0.5 scale) per acceptance
  item; if Studio is unavailable say so and list manual steps. Visual work follows the AGENTS.md visual-quality rule.
- Update HANDOFF.md and the status column in prompts/README.md, commit once, do not push. Report honestly.

Baseline: the EdgeRail is the wall. It is only 3.6 studs tall, so a jumping player can clear it. Collision group
EdgeRail (WorldService) ignores Hollows, Train and Debris, so Hollows still climb over. FallenPartsDestroyHeight is
-500 in default.project.json. Characters are server-built R6 rigs (CrewService) with client network ownership:
never set crew velocity from the server for gameplay.

Task:
1. Raise the crew's stop: EdgeRail height Tuning.VoidMist.WallHeight (keep its bottom on the ground, keep it
   invisible, CanQuery/CanTouch false). Check the tutorial edge prompt and HollowService's edge logic still work.
2. New server service `MistService` (ORDER after StationService/CrewService). Every SafeSampleInterval, for each
   living crew member off the train and on the station: if FloorMaterial ~= Air and not inside an edge zone, store
   their root in station-local space. Each Heartbeat: if the root is more than KillDrop below the station ground
   (or past the sinkhole beyond the rail), PivotTo the stored spot (ToWorld) + 3 up, zero velocity once, deal
   RescueDamage via CrewService.TagDamage(character, "Mist") + TakeDamage (skip god mode), fire Fx "MistRescue" to
   that player, telemetry `mist_rescue` {stop, x, z, ping}. No stored spot: the platform middle (StationService
   safe spot). Clear state on leaving the station, boarding and death.
Acceptance: Studio: walking or jumping at the rail stops you; a Dev-teleported fall past the rail is rescued with 15
damage and one telemetry line; Hollows still climb over the rail.
