# Dim-screen render harness (headless)

Proves (or disproves) the readability floor on a dim phone, from real game data, without Studio.

```
lune run visibility <scratch>/vis.json                      # real stations, grades, sky, lanterns
python -I tools/visibility/refs.py <refs_dir> <scratch>/refs.json   # mood ceiling anchors
blender -b --factory-startup --python tools/visibility/render.py  -- <scratch>/vis.json <scratch>/shots <0|1|2>
blender -b --factory-startup --python tools/visibility/measure.py -- <scratch>/shots <scratch>/refs.json <scratch>/vis.json
python -I tools/visibility/sheet.py <scratch>/shots --dim=45 --export=<scratch>/vis.json  # --dim=25: report only
blender -b --factory-startup --python tools/visibility/render.py  -- --calibrate   # light units check
python -I tools/visibility/classify.py <scratch>/vis.json tools/visibility/tiers.json  # the tiers, as data
python -I tools/visibility/offenders.py <scratch>/shots <out.md>   # failures ranked by family
```

render.py flags: `--tier=perf` (Performance: cone 26, no cone shadow, 4 rims; `<shot>_perf`),
`--falloff=smooth` (the other curve, `f2_<shot>`), `--ceiling` (what-if: every Tier A/B surface
white, `ceil_<shot>`: what albedo alone could ever reach), `--reach=k` (what-if lantern range).
sheet.py `--tag=_fix1` names its outputs `gates_45_fix1.md` / `sheet_45_fix1.jpg`.

Must-see targets are mechanical (`classify.py`, saved as `tiers.json`): Tier A hazards (a
walk-level top with a lower neighbour: the coping, steps, plinths; judged within 1 stud of the
lip), Tier B obstacles (collidable, rising more than a step above walk level and starting below
head height beside it; the train's side included), Tier C everything else (counted only).

- `.lune/visibility.luau` builds the stops the server builds (LayoutGen + StationBuilder, docked;
  TrainBuilder's train beside them) for an early (Halt, stop 1), mid (Market, stop 4) and late
  (Minehead, stop 8) grade, and writes every part, kit mesh (Builders/StationKit's dressing,
  recorded), light and the sky Scenery/Sky composes at that stop's hour (grade, chase, floor) for
  every floor radius the sweep needs. Lantern, cone, chase, rim, dread-vignette and camera numbers
  come from Tuning, Config/Cosmetics, UI/Overlay and AtmosphereController, never from this folder.
- `render.py` builds that in Blender (Cycles, direct light only, like Roblox Future), reusing the
  kit meshes in `assets/stationkit/StationKit.blend`, places R6 crew with their lanterns and your
  cone, and renders each shot plus 1-sample index and position passes.
- `measure.py` applies haze, exposure, the sky's ColorCorrection grades, the dread grade and
  vignette, the rim Highlights, then the dim device (linear light x 0.45, and 0.25), and measures
  the three gates. `sheet.py` writes the 0.5-scale contact sheet and `gates_<dim>.md`.
- `thresholds.py` holds every threshold and every Roblox approximation, with its source.

Shots per station: calm, chase (ambient at its chase minimum, vignette on) and worst (chase +
the darkest cosmetic lantern, Ember), each with a crew of 1 and of 4 spread at 26/40/60 studs,
each looking forward (away from the train), sideways (along the platform) and back (at the
coping and the train); and a brightest-lantern (Aurora, glow 1.6), crew-of-4 sweep above the default for
the slider's top (the mood ceiling). The slider's bottom is reaction distance, not contrast:
contrast at the floor's own distance gets easier as the floor shrinks (thresholds.py).
`--reach=k` renders a what-if (lantern Range = floor x k) for the report; it is not the game.

## What is not Roblox (headless renders are evidence, not in-engine confirmation)
1. Light falloff `(1 - d/Range)^2`; Roblox's curve is undocumented (pessimistic choice).
2. Ambient as albedo x Ambient plus a sky dome of OutdoorAmbient - Ambient (ray-traced occlusion).
3. Moonlight: one directional light at Brightness x 0.25 in ColorShift_Top.
4. Atmosphere: a depth haze, not Roblox's scattering. The visible night sky is dark air colour.
5. Post: no tonemapper shoulder, no bloom; ColorCorrection order brightness, contrast, saturation, tint.
6. Highlights drawn as a 2-pixel outline + fill wash on the visible pixels (DepthMode Occluded).
7. Characters are blocky R6 in a dark coat; the lantern lens is a glowing ball at the hip.
8. Camera: classic third person at StartZoom behind a focus 1.5 studs above the root, 12 deg down.
9. The landscape around the station (land chunks, sinkhole, fog bank) is not built.
10. The black flicker (0.36 s) is not rendered: the gates measure the held chase after it.
11. Tiers come from boxed parts on a 0.5-stud grid; beyond the station's slabs the land is taken
    as level (the landscape and the sinkhole are not exported), so only the track side has gaps.
12. Kit-dressed props (YardLamp, FencePicket) are drawn but not judged (no object index).
13. Surface treatments are plain diffuse colour: Roblox's Plaster/Concrete/Brick textures
    (normal and roughness maps) are not modelled, only the part's colour. No specular: brass
    "catching the flame" is not credited (the gate holds on albedo alone).
14. The monster stand-in is a 7-stud block figure in a dark hide, not the game's Hollow.
15. The train's platform side (every Tier B train part on that side, and its lining) is judged as
    ONE object: TrainBuilder parents each panel to the train on its own, and judged one by one a
    panel only meets the panel beside it (part 2's "Train/Part" readings were that artefact).
16. The surface limit (`--ceiling` + sheet.py) relies on direct light only: an object's luminance
    in the white what-if is exactly what white paint would give it there. It ignores textures.

## Sources
- WCAG 2.1 SC 1.4.11 Non-text Contrast (3:1), relative luminance and contrast ratio.
- IEC 61966-2-1 sRGB viewing conditions: 64 lux reference, 1% viewer flare; ~5% typical
  (ICC sRGB registry, color.org; W3C sRGB note).
- Android Developers Blog, "Getting screen brightness right for every user" (2018): perceptual sliders.
- Roblox Creator Docs: PointLight / Light sources (Range in studs; falloff not documented).
- Darkwood (Acid Wizard, Push Square 2019; Engadget 2013): field of view and light as the horror.
- Outlast (Red Barrels, GamingBolt 2013; Outlast wiki on night vision and brightness settings).
- Alan Wake (GamesRadar "The making of Alan Wake": light as safety, darkness as threat).
- Steam store screenshots of Outlast (238320), Darkwood (274520) and Alan Wake (108710), measured
  by refs.py (fetched at 600x338, not kept in the repo).
- Hinks duplex burner and wick winders (oldcopper.org, "Oil Lamp Burners") for the slider.
