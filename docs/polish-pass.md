# Polish pass: world, atmosphere, camera, train

The user's request: polish the atmosphere, the look and the mechanics to AAA quality. Two specific complaints:
the camera "couldn't zoom in, distant 3rd person view", and "no environment to look at" while riding.
Delete this file when the pass is done.

## Findings so far

- **Camera.** In a fresh Studio session, zoom works in the lobby and on the train, down to first person. The
  user most likely played in an old session where a test command had set `CameraType = Scriptable`. Still
  harden it: on every CharacterAdded set `CameraType = Custom` and `CameraSubject` to the humanoid; clamp zoom
  (`CameraMinZoomDistance` 0.5, `CameraMaxZoomDistance` about 30); set a closer starting zoom (about 11) by
  briefly pinning min = max for one frame.
- **Environment.** `Controllers/SceneryController` is a causeway over a void with 34 sparse floating islands
  at |z| 170–900. Replace it.
- **Train interior.** Car walls are livery-tagged single parts, so the inside shows the green Body colour.
  Add non-livery interior linings in `Builders/TrainBuilder`: a dark wood wainscot below 3.4, a cream upper
  wall, brass window frames, luggage racks, curtains, a ceiling lining, and brass lamp fixtures whose
  PointLights cast shadows.

## Coordinates and timing (from the code)

- The train is static: x −96..96 (brake van −96..−66, crew car −63..−23, workshop −20..20, tender 23..49, loco
  52..96). Floor y = 0, rail top about y −5.2, track centreline z = 0, platform side +Z, `PlatformEdgeZ` 7.
- Boarding volumes: cars (116 × 11 × 13 at x −38) and cab (12 × 11 × 13 at x 58).
- Stations slide in from x = +550 (`Motion.arrivalDistance`, Ta = 10 s) and leave toward −X at
  a = 4 + 2D studs/s². Archetype length × depth: Halt 240×144, CoalYard 300×180, SignalWorks 288×204,
  Market 300×192, Viaduct 360×108, Minehead 288×216, plus the Terminus (`Config/Stations`).
- Scenery speed: 0 in the lobby, Dwell and LastCall. It ramps to `Tuning.Motion.CruiseSpeed` (110) at
  9 studs/s² during Boarding and Junction, holds constant in Cruise, and follows the station's
  `AssemblyLinearVelocity` during Arrival and Departure. Drop the current 0.65 starving slowdown so docking
  stays predictable; show starving with smoke and firebox cues instead.
- `Tuning.World.LobbyOrigin` is (0, 0, −3200), which the new landscape would overlap. Move it to about
  (0, 0, −12000); `AtmosphereController` finds the lobby through it.

## Landscape design (client, replaces SceneryController internals)

Proposed new modules: `src/client/Scenery/` (Chunk, Biomes, Props, Land, Features) and a pure
`src/shared/Logic/Journey.luau` with Lune specs.

- **Chunks.** Each chunk is a Model with one anchored invisible root. Its parts are built in chunk-local
  space, welded (`Kit.weldAll`) and unanchored. Every frame, one `Workspace:BulkMoveTo` moves only the roots
  to x = chunkStart − odometer. All decor sets CanCollide, CanQuery and CanTouch to false. Only near, tall
  props cast shadows.
- **Layers** (chunk length, window in x, |z| band):
  - Bed: 48, −480..1800, track. Holds the ballast, rails, and embankment wedges down to land at y −14. A
    WedgePart is full height at +Z, so rotate the +Z shoulder 180° about Y.
  - Sleepers: 48, −300..600.
  - Trackside: 60, −400..1500, |z| 10–70. Holds telegraph poles on −Z with sagging wires, fences,
    mileposts, signals and tufts.
  - Near field: 120, −700..2200, |z| 18–420. Holds the ground slab (top y −14), patches, field strips
    perpendicular to the track, mounds made from buried balls, trees and buildings.
  - Mid field: 400, −2000..4400, |z| 18–1600. Its ground sits 0.3 lower so it shows past the near window;
    it also holds hills and groves.
  - Horizon: 1200, −6000..8400, |z| 1600–4000. Holds wedge ridges with snowcaps.
  - Target: about 2,500 moving parts on PC, with a density scale from the quality level. Cap generation at
    2–3 chunks per frame. Build the first leg at Boarding, under the fade.
- **Biome by destination archetype:**
  - Halt: farmland. Fields, farmhouses, barns, windmills (Motor6D blades), haystacks, fences, scarecrows.
  - CoalYard: coalfields. Slag heaps, smoking chimneys, pit headframes, brick terraces, wagons, brown smog,
    ash.
  - SignalWorks: railway corridor. Parallel sidings, semaphores, signal boxes, water towers and gantries.
  - Market: burning town. House rows, church spires, fires with PointLights, smoke and embers.
  - Viaduct: highland gorges. Pines, boulders, mist, drizzle.
  - Minehead: mountains and quarry. Snowy pines, rock walls, snow.
  - Terminus: coast at dawn. Sea plane, lighthouse, dunes.
  - The first leg starts in the railway corridor. Blend from the previous biome to the next at about 35% of
    the leg.
- **Set pieces** (deterministic per leg from `Rng.derive(seed, "journey", leg)`, spaced at least 700 studs
  apart, and skipped if they would come within 400 studs of the next dock):
  - Tunnel: a rock cutting, then a portal, then walls, ceiling and lamps every 40 studs. While inside, the
    sky is darkened, `SoundService.AmbientReverb` is set to Hallway, and the whistle sounds at entry.
  - Gorge: a void under both sides, crossed on a through-truss girder bridge or a stone viaduct, with
    canyon walls running out to the mid field.
  - Burning town.
  - An abandoned halt with a Hollow standing on it.
  - A derailed wreck.
  - A signal gantry over the track at y 16.
  - A field of Hollow silhouettes with glowing eyes.
  - A graveyard.
  - A lake.
  - A level crossing.
- **Station sinkhole.** Each station sits in a sinkhole on the +Z side: x within ±(L/2 + 70) of the dock and
  z from 7 to depth + 60 is void. It has rock rim cliffs, a dark abyss floor with ember emitters and mist
  layers, and a causeway wall replacing the +Z embankment. The −Z side stays land.
  - Predicting the dock: in Cruise, dockO = odometer + 110 × (phaseEndsAt − now) + 550. Size it from
    `run.destination` and `Config/Stations`.
  - At Arrival, compare against odometer + station Root X. If they are more than 30 studs apart, rebuild the
    affected chunks (this covers dev skips and late joins).
  - Keep hiding Bed chunks that overlap the docked station's own track bed.

## Sky and atmosphere (`AtmosphereController` becomes the one owner of Lighting)

- **Time of day runs across the run.** Lobby 17.4, stop 1 17.9, stop 2 18.6, mid-run night (about 22,
  then 2), pre-dawn about 4.8, and the Terminus at sunrise 6.4. Interpolate by progress (stops cleared plus
  the share of the leg travelled).
- **Keep night readable.** Raise OutdoorAmbient to about (78, 86, 118) and ExposureCompensation to about
  +0.6, and tint the Atmosphere blue.
- **Clouds.** Add a `Clouds` instance under Terrain, with cover and density set per biome.
- **Weather.** Biome weather (ash, snow, rain drawn as squashed sparkles, embers) and lightning in storms.
- **Keep the existing modifiers:** the lobby grade, fog proximity, the Last Call pulse, spectate
  desaturation and the flare flash.
- **Lighting technology.** Add `"Lighting": {"$properties": {"Technology": "Future"}}` to
  `default.project.json`.

## Camera and feel

Apply ride sway while aboard and moving: a ±0.35° roll from noise and a tiny kick at each rail joint (about
every 0.45 s at cruise). Add a little more rumble in tunnels and on bridges. Use the existing remove-at
Camera−1 and apply-at Camera+1 pattern so the offset never drifts.

## Finish

- Run `lune run check` (it must pass), add Journey specs, and update the README if commands change.
- Studio cannot run in the cloud. Leave a manual Studio test list for the user: `rojo serve`, then Connect,
  then Play. Check zoom, the scenery in every biome, the sinkhole alignment at each stop, tunnel and bridge
  lighting, and frame rate.
- Commit on `claude/last-train-out`. Optionally update the blueprint doc's build status and backlog
  (LTO-410, LTO-312, LTO-350).
