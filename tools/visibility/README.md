# Dim-screen render harness (headless)

Proves (or disproves) the readability floor on a dim phone, from real game data, without Studio.

```
lune run visibility <scratch>/vis.json                      # real stations, grades, sky, lanterns
python -I tools/visibility/refs.py <refs_dir> <scratch>/refs.json   # mood ceiling anchors
blender -b --factory-startup --python tools/visibility/render.py  -- <scratch>/vis.json <scratch>/shots <0|1|2>
blender -b --factory-startup --python tools/visibility/measure.py -- <scratch>/shots <scratch>/refs.json <scratch>/vis.json
python -I tools/visibility/sheet.py <scratch>/shots --dim=45 --export=<scratch>/vis.json  # --dim=25: report only
blender -b --factory-startup --python tools/visibility/render.py  -- --calibrate   # light units check
```

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
