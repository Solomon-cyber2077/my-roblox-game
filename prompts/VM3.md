VM3: Void Mist, Edge mist damage (Council 03)

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

Baseline: fog damage stays exactly as it is in HazardDirector.damageInFog (owner rule: mist on the station
damages, never pushes). Only the sinkhole-edge buffer is new damage.

Task: in MistService, every TickInterval for each living off-train crew member: zone = edge zone containing the
root (Logic/VoidMist). Track enteredAt per player keyed by presence, not by rail part (moving between adjacent rail
tiles keeps the grace). Inside and now - enteredAt >= EntryGrace: damage DamagePerSecond * TickInterval through
TagDamage "Mist" (god mode skipped), Fx "FogTick" for the hit feedback. Not stacked with fog: skip the tick if the
player is already past the fog front (HazardSchedule.fogFront). Outside: clear enteredAt. Set player attribute
`MistZone` = "Edge" | "Fog" | nil (Fog from the same fog-front test). Clean up on leave/death/board.
Acceptance: 100 HP standing in the buffer dies in about 12.5 s + 0.5 s; in-and-out under 0.5 s deals nothing;
fog damage unchanged; MistZone readable in the Studio attribute pane.
