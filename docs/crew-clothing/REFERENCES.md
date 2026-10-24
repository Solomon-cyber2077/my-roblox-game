# Crew clothing references

Reviewed 2026-10-24 before authoring the textures and Blender hats. Designs are original, stylized railway workwear; these references are not claims of exact period reconstruction.

- [Roblox classic clothing documentation](https://create.roblox.com/docs/avatar/classic-clothing): 585 × 559 classic shirt/pants sheet layout. Official template inspected to establish face coordinates; generated sheets contain original artwork.
- [North Eastern Railway stationmaster jacket, circa 1865](https://collection.sciencemuseumgroup.org.uk/objects/co220804/station-masters-jacket-north-eastern-railway): collar contrast and formal button hierarchy.
- [British Railways driver cap](https://collection.sciencemuseumgroup.org.uk/objects/co220777/br-steam-locomotive-driver-cap): practical crown and visor silhouette; later-period shape reference.
- [LNER porter cap](https://collection.sciencemuseumgroup.org.uk/objects/co220772/lner-porter-cap): crown/band distinction, later-period workwear reference.
- [Leather machinist cap](https://modemuze.nl/collecties/zwarte-leren-machinisten-pet): material and softened crown reference.

## Render review

`assets/crew-clothing/stoker-before.png` is a neutral R6-shaped mannequin baseline, not a screenshot of the player's original avatar. `stoker-after.png` adds the work apron, seams, collar, belt, boots and modeled cap. `lineup-after.png` compares all five free identities and two record variants. All render at 50% resolution.

The Stoker crown was softened after the first review. The lineup separates dark workwear, brown Brakeman, blue formal Conductor, olive Trackwalker and rust Wayfarer using silhouettes, collars and equipment details. Earned versions retain their base identity with restrained insignia/color changes. Fine fabric detail and dark seams remain a Studio lighting/readability check, not a headless pass.

## Rebuild

Run `tools/crew-clothing/textures.py` with Python/Pillow, then Blender 5.2 with `--background --python tools/crew-clothing/build.py`. Sources are in those scripts and the packed `assets/crew-clothing/crew-clothing.blend`. Per-recipe folders contain classic clean/worn sheets, hat atlas, normalized OBJ and render crops. The manifest records measured accessory bounds and triangle totals (440–616 per outfit, one accessory).
