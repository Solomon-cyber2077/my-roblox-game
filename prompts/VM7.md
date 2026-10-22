VM7: Void Mist, Debug tools and QA checklist (Council 07)

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

Baseline: the Studio Dev console (DevService, Remotes.Dev, README command list); telemetry through the existing
Telemetry service.

Task:
1. Dev commands: `mist preset <Teal|Slate|Amber>`, `mist outlines` (SelectionBoxes on edge zones and rails),
   `mist debug` (toggles Tuning-driven debug labels), and `clock <hours>` if not already present. Add them to README.
2. MistService keeps a session count of rescues and mist damage; with debug on in Studio it prints a summary every
   60 s (rescues, damage, seconds per zone per player).
3. docs/direction/<date>_void-mist-qa.md: the Council's checklist adapted (rail at 0/45/90 degrees with Incoming
   Replication Lag 0/0.2/0.3, 4-player Start Server 5 minutes along edges with 0 rescues, jumping outward, damage
   grace timing, idle is local only, preset screens at ClockTime 2/14/20, MicroProfiler under 0.15 ms), each line
   runnable with Studio and these commands. Mark lines you ran PASS/FAIL with evidence; the rest HUMAN pending.
Acceptance: every command works in Studio; the checklist exists with honest status.
