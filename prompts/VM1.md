VM1: Void Mist, Tuning and zone math (Council 01)

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

Baseline: the sinkhole edge already exists. LayoutGen keeps row `rows-1` (and the side columns) as edge tiles;
StationDressing `Builders.EdgeMark` puts an invisible 3.6-tall `EdgeRail` part (collision group EdgeRail, tag
`SinkholeEdge` = Config/Tutorial.EdgeTag) on each open sinkhole-edge tile, its frame on the rail line with -Z toward
the train, `Stations.Edge.RailBack` 4.5 in from the edge. Station fog already damages past the fog front
(HazardDirector.damageInFog, 4 Hz, `params.fogDps`).

Task:
1. `Config/Tuning` gets a frozen `VoidMist` block: BufferDepth 6, DamagePerSecond 8, TickInterval 0.25,
   EntryGrace 0.5, CurrentMaxOut 12, ProximityRange 8, IdleSeconds 12, IdleOpacityBoost 0.15, IdleHumMult 1.5,
   HumVolume 0.3, RescueDamage 15, SafeSampleInterval 0.5, KillDrop 40 (studs below the station ground that count
   as fallen), WallHeight 50, Presets {Teal {Mist #3A5A5E, Tint #C8DEDF}, Slate {#4A5560, #D0D6DC}, Amber {#6B5A3A,
   #E6DCC8}}, DefaultPreset "Teal", Debug false. Comment: starting points for playtest.
2. Pure `Logic/VoidMist` (no engine globals beyond CFrame/Vector3/Color3 datatypes): an edge zone is built from a
   rail frame + width: the box of BufferDepth on the train side of the rail, as tall as WallHeight.
   `zone(railCFrame, width)`, `isInside(zone, pos)`, `depth01(zone, pos)` (0 at the inner face, 1 at the rail),
   `outward(zone)` (unit, flat, away from the train), `distanceTo(zone, pos)` (0 inside),
   `proximity(distance)` (1 - clamp(d / ProximityRange)), `outwardCap(depth01)` (CurrentMaxOut * (1 - depth01)),
   `clampOutward(velocity, outward, cap)` (removes only excess outward speed, keeps Y and sideways),
   `preset(name)` (falls back to DefaultPreset).
3. tests/VoidMist.spec.luau: depth01 at both faces and middle for rails rotated 0/45/90/180 degrees; outside points;
   clampOutward never changes Y, inward or sideways motion; unknown preset falls back.
Acceptance: check green. No Studio change in this prompt.
