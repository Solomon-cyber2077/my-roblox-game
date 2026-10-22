# Void Mist handoff to Astra (Claude Code ran out of usage, 2026-10-22)

Branch `claude/void-mist`, worktree `../LTO-mist`. Prompts: `prompts/VM1.md`-`VM7.md` (adapted from Council run
20261022-131445; status in prompts/README.md). Place for a separate Studio window: `../mist.rbxl` (copy of
main-s1.rbxl, not opened yet); serve with `rojo serve --port 34874` from ../LTO-mist and point the Rojo plugin there.

## Done (`lune run check` green: format, lint, types, tests, audit)
- VM1: Config/Tuning.VoidMist, Logic/VoidMist (zone, depth01, distanceTo, proximity, outwardCap, clampOutward,
  preset) + tests/VoidMist.spec.luau (7 specs).
- VM2 + VM3 (code only, NOT run in Studio): EdgeRail now WallHeight 50 tall, CanQuery off (StationDressing
  EdgeMark); TutorialController NearEdge measures on the ground plane; new Services/MistService (in ORDER after
  GraspService): last safe spot in station-local space, rescue below KillDrop (15 dmg, Fx MistRescue,
  telemetry mist_rescue), edge-zone damage with 0.5 s grace, not stacked with fog, attribute MistZone;
  HazardDirector.FogFront(); Config/Telemetry mist_rescue; FxController MistRescue pulse.

## Next (in order)
1. Studio-verify VM2/VM3 per their acceptance lines (rail stops walk+jump; Hollows still climb over; rescue fires
   once with 15 dmg; edge death ~13 s; quick in/out no damage; fog damage unchanged). Fix, commit.
2. VM4, VM5 (visual-quality rule applies), VM6, VM7. Update HANDOFF.md, commit; do not push or merge.
