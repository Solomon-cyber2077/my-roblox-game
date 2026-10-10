# Train exterior: inventory (Phase 0, 2026-10-09)

The train is not in the place file. `Builders/TrainBuilder.build(origin)` makes it from 1,752 primitives
every time the server starts (the run train at the world origin, and the lobby's `DisplayTrain` in
`LobbyBuilder`). Train space: +X is the engine's front, y = 0 is floor level, z = 0 is the track
centreline, +Z faces the platform. Body: 13 studs wide, walls 0..9, clerestory to 11.4, bogies to -5.2.

Measured with `lune run tools/trainshell/dump_train.luau out.json` (headless build, every part's
size, CFrame, colour, material and attributes). Bounding boxes are of visible parts and include half
of each gangway.

| Car (board text) | Body x | L x W x H (studs) | Side doors (+Z) | Windows +Z / -Z | Parts | Signage |
|---|---|---|---|---|---|---|
| Guard's van ("GUARD'S VAN") | -90..-66, open platform -96..-90 | 30.8 x 13.8 x 21.1 (signal mast) | 1 at x -78 | 2 / 4 | 358 | cant-rail board x2, door signs, nameboard |
| Crew car 1 ("LAST TRAIN OUT") | -63..-44.5 | 21.8 x 13.7 x 16.6 | 1 at x -49.75 | 1 / 3 | 322 | cant-rail board x2 |
| Crew Saloon ("CREW SALOON") | -41.5..-23 | 21.8 x 13.7 x 16.6 | 1 at x -36.25 | 1 / 3 | 317 | cant-rail board x2, route board inside |
| Workshop ("WORKSHOP") | -20..-1.5 | 21.8 x 13.7 x 16.6 | 1 at x -6.25 | 1 / 3 | 248 | cant-rail board x2 |
| Stores ("STORES") | 1.5..20 | 22.9 x 13.7 x 16.6 | 1 at x 6.25 | 1 / 3 | 224 | cant-rail board x2 |
| Tender ("LAST TRAIN OUT" lettering) | 23..49 | 28.7 x 13.7 x 16.1 | none | none | 62 | gilt lettering both sides |
| Locomotive + footplate ("LAST LIGHT No. 1931") | cab 52..64, boiler to ~99 | 48.9 x 14.0 x 21.0 | cab door at x 58 | cab spectacles | 221 | brass cab nameplate x2 |

Side doors are 5.6 wide x 7.5 high (cab 4 x 7), two sliding leaves of 2.8 at z 6.74. Windows are
3.6 x 3.6, sill 3.4, head 7.0, glass at z +-6.25. Gangways (3 long, 4.4 wide diamond plate,
bellows to 7.2) sit between every pair of carriages. Every carriage rides on two Mansell-wheel bogies.

## Scripts that touch the exterior (keep these working)

| Script | What it relies on |
|---|---|
| `Builders/TrainBuilder` | builds everything; `Livery` attribute (Body, Trim, Roof, Accent, Lamp) on 392 parts; `applyLivery` recolours them |
| `Builders/TrainInterior` | cant-rail boards, tender lettering, cab nameplates (SurfaceGui text), door signs, lamps |
| `Services/TrainService` | `ApplyLivery` on the run train and the display train; seats, mast lamp (flare), breaches |
| `Services/LobbyService`, `LobbyBuilder`, `CarService` | `DisplayTrain` and its cabins (door CFrames) for the lobby boarding prompts |
| `Controllers/TrainVisualsController` | attributes `WheelRadius`/`WheelPivot` (76 spinning parts), `CrankRadius`/`CrankPhase`, `DoorSlide` (24 door parts), `CoalTier` (Transparency toggled); names `ChimneyTop` (smoke), `SteamVent` (steam), `Firebox`, `FireFlame`, `StoveGlow`, `LanternFlame`, `DoorBlocker` (Last Call lamps, z > 0), `Breach_*` anchors |
| `UI/RouteBoard`, `ChalkSlate` | saloon board slots and lanterns (inside, not touched) |
| `Controllers/TrainCamController` | outside camera framing (volumes from `Built.carVolume`) |
| `FxController`, `AudioController` | whistle and steam cues by remote, not by part |

Nothing moves the train: stations slide past it (`Logic/Motion`), so new pieces only need to be in the
same anchored `Train` model.

## Backup

The old exterior is code, so it cannot drift: the shell is added on top by `Builders/TrainShell`
and `Config/TrainShell.Enabled = false` brings the primitive look back. At runtime, primitives a
mesh replaces are hidden if they collide (Transparency 1, collision kept) or, if purely decorative,
moved into `ServerStorage.TrainExteriorArchive` (one folder per built train), where they can be
inspected and cost clients nothing.

Before shots (night, sky pinned to 22:00, Play, docked at stop 1): `docs/train-exterior/before/`.
