# Asset credits

Every UI texture in `assets/ui` was made for this project; nothing third-party is bundled.

| Asset | Made with | Source | Roblox id | License |
|---|---|---|---|---|
| paper_grain, iron_grain, edge_burn, glow, stamp_grunge, vignette, punch | Python/NumPy | `tools/uiart/make_textures.py` | see `Theme.Image` | own work |
| panel_iron, card_aged (9-slice composites) | Python/NumPy over the brass render | `tools/uiart/make_textures.py` | see `Theme.Image` | own work |
| brass_frame, enamel_plate, rivet, wax_seal, watch_bezel | Blender 5.2 (Cycles) | `tools/uiart/render_ornaments.py` | see `Theme.Image` | own work |
| booth_mabel, frame_mahogany, plate_engraved, blotter, card_leather, rim_brass, lamp_lit, lamp_dark, knob_left, knob_right, crest | Blender 5.2 (Cycles); sign text in Blender's bundled Inter (OFL) | `tools/uiart/render_booth.py` | see `Theme.Image`, `Theme.Portrait` | own work |
| stamp_company, ticket_tab, grain_wood (and the plate clean-up) | Python/NumPy/Pillow; stamp lettering in Special Elite and Oswald (OFL, from Roblox's content/fonts) | `tools/uiart/make_booth.py` | see `Theme.Image` | own work |

Fonts are Roblox built-ins (Oswald, Merriweather, Special Elite, Fondamento, Patrick Hand,
Highway Gothic), all under the SIL Open Font License as shipped with Roblox.

Regenerate: `blender -b -P tools/uiart/render_ornaments.py -- assets/ui`, then
`python tools/uiart/make_textures.py assets/ui`, then upload and update `Theme.Image`.
Ticket office: `blender -b -P tools/uiart/render_booth.py -- assets/ui`, then
`python tools/uiart/make_booth.py assets/ui <Roblox>/content/fonts`. Upload with Studio MCP
`upload_image` from a local http server (`python -m http.server` in assets/ui).
