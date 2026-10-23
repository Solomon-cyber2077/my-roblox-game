# Lighting lock: reference shots (Prompt 6)

The locked reference state for the Depot Hall and the train interior (Config/InteriorLight for fixtures;
Scenery/Sky LOBBY for global light). Taken 2026-10-22 after the lighting session's commit c4d7886.

Conditions, locked for every shot:
- Studio play, main-s1, Device Simulator iPhone 7 preset (viewport 666 x 374), GraphicsQuality "Quality".
- The lobby's fixed sky: ClockTime 18.30, Brightness 0, Exposure -0.10, Ambient (13, 10, 7).
- All game and core UI hidden; the camera bound at RenderPriority.Last + 50 to these world points:

| Shot | File | Camera | Looks at |
|---|---|---|---|
| Hall spawn (the START board) | hall-spawn.jpg | (0, 9, -11986) | (0, 13, -11929) |
| Ready position (hall floor to the display train) | hall-ready.jpg | (14, 7, -11960) | (-20, 5, -12020) |
| Crew saloon (display train) | train-saloon.jpg | (-36, 6.2, -12028) | (-23.7, 5.2, -12028) |
| Workshop (display train) | train-workshop.jpg | (-19, 6.2, -12029) | (-6.8, 3, -12032) |

Bands: `python tools/refbands.py` measures each shot's mean relative luminance against bands.json (recorded mean
+-20%); `--write` re-records after an approved change. Measured means: hall-spawn 0.036, hall-ready 0.046,
train-saloon 0.065, train-workshop 0.051.

A mean in band says the overall level has not drifted, nothing more. Readability is judged locally (edges,
obstacles, Hollow silhouettes) in motion, under the chase dim and Performance; the owner judges the look.
Highlights: the harness here is a screen capture, so the edge Highlights render as in play.
