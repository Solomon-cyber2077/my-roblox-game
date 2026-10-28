# Limb-loss motion / framing references

Read before authoring (2026-10-28):
- `docs/direction/limb-loss-final-pass-2026-10-28.md`: clean separation; anticipation, counter-pull, recoil, recovery; no wound interiors or splatter.
- `src/client/Animation/CrewPoses.luau`: existing R6 shoulder convention, breath, weighted locomotion and held poses. These are the silhouette and motion reference, not a new avatar style.
- `src/shared/Visual/CosmeticModels.luau`: existing brass storm lantern, handle above lens; preserve this model and its readability radius.
- [Blender animation guidance](https://developer.blender.org/docs/features/interface/human_interface_guidelines/animations/): deliberate pacing with interpolation. Use eased preparation/recovery and a short separation accent.
- [Blender keyframes](https://docs.staging.blender.org/manual/en/latest/animation/keyframes/introduction.html): sample authored keys and interpolate between them.

Composition targets: brace through the shoulders while held, keep original grab contact; recoil away from the lost side; free arm stays clear of the torso; regrowth opens the restored shoulder then settles. The last-five-second pose bends the upper body while retaining the existing leg cycle. Collapse lowers the silhouette without moving the authoritative root. Witness view must contain the full standing-to-collapsed silhouette, with a fixed reduced-motion frame.

Render comparisons are in renders/. Blender is a pose/composition study; it cannot validate Roblox clothing, lighting, network ordering or collision.
