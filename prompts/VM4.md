VM4: Void Mist, Client current, the soft push (Council 04)

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

Baseline: the client owns its character's physics. Edge rails are tagged SinkholeEdge.

Task: a client controller `Controllers/VoidCurrentController` (started like the other controllers). On
RunService.PreSimulation: for rails within 20 studs of the local root (cache via CollectionService), take the zone
with the largest depth01 containing the root; set root.AssemblyLinearVelocity = VoidMist.clampOutward(v, outward,
outwardCap(depth01)). Never touch Y, inward or sideways motion. Only while off the train and alive; never during a
grab (GrabController). Studio + Tuning.VoidMist.Debug: a small label with depth01, cap and outward speed.
Not spring-like: no impulse back, only the excess outward speed is taken away.
Acceptance: sprinting at the rail at 0/45/90 degrees slows over ~6 studs and stops at the rail without jitter;
walking back or along it is unaffected. If the Humanoid controller jitters, switch to a VectorForce opposing the
excess and say why in a comment.
