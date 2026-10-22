VM6: Void Mist, Hum and idle reaction (Council 06)

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

Baseline: Config/Audio cues and Config/AudioPriority tiers (Ambience tier for beds). VM5 exposes
SetOpacityOffset. Client only: no remote, another player's view never changes; the camera never moves.

Task: in the client (MistVisuals or a small sibling): one looped hum (public library id in Config/Audio, Ambience
tier), volume HumVolume * proximity, smoothed ~1/s. Idle = no input (InputBegan/InputChanged incl. thumbsticks and
mouse) and no MoveDirection for IdleSeconds while within 10 studs of an edge zone: tween opacity offset to
IdleOpacityBoost and hum to IdleHumMult over 3 s; any input returns both over 0.5 s.
Acceptance: idle 12 s at the rail thickens the mist and raises the hum; input reverts it; a second client sees no
change (two-client Studio test).
