# Train exterior: design bible (Phase 1)

One vehicle, built by one company and run hard through the night. Steam-era, original design:
no livery, crest or lettering from any real railway, film or game.

## Palette (sRGB)

| Role | Clean | Worn | Notes |
|---|---|---|---|
| Body (tintable, `Livery=Body`) | crimson 96,30,26 | sun-faded 120,52,42 on upper panels; soot 40,26,24 under the cornice | the paint is the part colour; wear is an overlay so livery still tints |
| Lining / gold leaf (`Trim`) | old gold 170,132,70 | chipped to the red undercoat at corners and door edges | gold leaf, never bright yellow |
| Doors (`Accent`) | bottle green 30,58,46 | plank grain shows through, scuffed pale at the hand height | doors must read before anything else |
| Roof (`Roof`) | tarred canvas 34,33,34 | soot streaks downwind of vents, pale salt at the edges | |
| Iron | blackened 38,37,38 | rust bleed 92,52,30 below rivets and bolts | buffers, bogies, steps, straps |
| Brass | aged 150,120,74 | darkened in recesses, rubbed bright on handles | handrails, lamp bodies, plates |
| Lantern glow | amber 255,196,120 | | emissive, plus a few real lights |

## Shape language

Chunky and slightly oversized so it reads at night and at distance: raised panel mouldings with a
bevel big enough to catch the lantern light, arched window heads in a deep frame, riveted iron straps
at the corners, fat buffers on long stocks, lamp housings with a hood. Every car shares the kit
(panel moulding, window frame, door frame, lamp bracket, rivet strap, step, handrail, buffer, coupling,
bogie) so the train is one family; silhouettes differ:

| Car | Silhouette and job details |
|---|---|
| Guard's van | raised lookout cupola, brake wheel on the open platform, tail lamps, signal mast kept |
| Crew car "LAST TRAIN OUT" | the flagship: longest gilt lettering, most lining |
| Crew Saloon (pilot) | the most inviting: warm curtained windows, a lantern either side of the door, a roof lamp-top per bay |
| Workshop | louvred roof vent with soot, pipe run along the solebar, tool rack on the far end |
| Stores | heavy plank-grain door with iron straps, strapped barrels and a tarp on the roof edge |
| Tender | coal rails and a water filler dome, toolbox, rivet seams |
| Locomotive and footplate | boiler bands, domes, whistle, steam pipes, firebox glow under the cab |

## Wear rules (every mark has a cause)

- Dirt collects under window sills (rain streaks down), along the bottom 1.5 studs (spray off the wheels)
  and under the cornice (smoke rolls back off the roof).
- Paint chips where hands and boots go: door edges, handrail ends, step treads, corners of panels.
- Rust bleeds down from rivets, bolts and strap ends, never upward.
- Soot darkens the roof and the area above vents and the chimney's downwind side.
- Scratches cluster around the door at hand height and low on the skirt near steps.

## Night readability

- The door is the brightest thing on each side: green leaves inside a pale gold frame, lit by a
  lantern either side. The door frame is never broken by trim.
- Car names are painted gilt on a dark board at the cant rail, big and high contrast, in the same
  hand-lettered serif as the ticket UI (Merriweather Bold / Fondamento).
- Each car keeps a distinct roof line so the silhouette is readable against the sky.
- Lanterns: emissive housings everywhere, real PointLights only at the doors (no shadows on them).

## Construction rules

- Studs throughout. The shell sits on the existing primitives: the side skin's outer face stays inside
  z = +-6.6 so the sliding doors (z 6.615..6.865) pass over it, nothing protrudes in a door's slide zone.
- Window and door holes are cut exactly over the existing openings so the interior still shows.
- Decorative meshes: CanCollide, CanQuery and CanTouch false. Collision stays on the primitives.
- Livery: one MeshPart per role per car (Body, Trim, Roof, Accent) so `applyLivery` still tints each;
  colour maps are a wear overlay (alpha) over the part colour.
- Optional later: one `Grime` attribute and one overlay texture for wear as the run goes on.
