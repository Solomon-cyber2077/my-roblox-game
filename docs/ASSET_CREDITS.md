# Asset credits

Every UI texture in `assets/ui` was made for this project; nothing third-party is bundled.

| Asset | Made with | Source | Roblox id | License |
|---|---|---|---|---|
| paper_grain, iron_grain, edge_burn, glow, stamp_grunge, vignette, punch | Python/NumPy | `tools/uiart/make_textures.py` | see `Theme.Image` | own work |
| panel_iron, card_aged (9-slice composites) | Python/NumPy over the brass render | `tools/uiart/make_textures.py` | see `Theme.Image` | own work |
| brass_frame, enamel_plate, rivet, wax_seal, watch_bezel | Blender 5.2 (Cycles) | `tools/uiart/render_ornaments.py` | see `Theme.Image` | own work |

Fonts are Roblox built-ins (Oswald, Merriweather, Special Elite, Fondamento, Patrick Hand,
Highway Gothic), all under the SIL Open Font License as shipped with Roblox.

Regenerate: `blender -b -P tools/uiart/render_ornaments.py -- assets/ui`, then
`python tools/uiart/make_textures.py assets/ui`, then upload and update `Theme.Image`.
