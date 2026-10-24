VM5: Void Mist, Mist visuals and proximity tint (Council 05)

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

Baseline: Scenery/Features `abyss` draws the sinkhole (cliffs, spires, floor, embers); Scenery/StationFog draws the
station fog; AtmosphereController owns Lighting and post effects. No uploaded assets except the approved Blender
exceptions; no ParticleEmitters for the mist (budget under 0.15 ms/frame).

Task (client only, a real design pass: references first, then build, render before/after at 0.5 scale):
1. Edge mist: layered, slowly scrolling translucent sheets along every sinkhole edge, denser toward the rail plus
   a vertical veil past the rail so the abyss is not visible from standing height. Colour from the preset (workspace
   attribute `MistPreset`, default Teal). Built per station like the other station visuals, removed with it.
2. Proximity tint: a ColorCorrection contribution owned by AtmosphereController (not a second effect fighting it):
   t = VoidMist.proximity(nearest edge distance); TintColor white -> preset Tint, Saturation 0 -> -0.15 by t.
3. Expose `MistVisuals.SetOpacityOffset(x)` for VM6. Preset change recolours over 2 s.
4. CHOICE, report it: whether the station fog (StationFog) takes the same preset colour so both mists read as one.
   Faint lightning in the mist is LATER (Council cut it from v1); leave a note, do not build it.
Acceptance: abyss hidden through the edge mist from standing height at ClockTime 2, 14 and 20 (screens); presets
recolour live; MicroProfiler cost noted; the readability check of S8 (edge at 8 studs) still reads.
