## Prompt 1 contract record

This is the discovery contract for the Depot Hall idle camera/piano feature. It records verified interfaces before implementation; it does not authorize new camera or audio frameworks.

### Verified contracts

| Concern | Existing source of truth | Contract |
|---|---|---|
| Replicated state | `src/client/Controllers/StateController.luau` | Do not enter until the first snapshot is received; read `run.phase` from the mirror. |
| Lobby/member check | `src/client/Session.luau` | Use established session membership and physical character checks; a default `Lobby` phase before snapshot is not proof of eligibility. |
| Camera ownership | `src/client/Controllers/CameraController.luau`, `TrainCamController` | Idle mode is subordinate to train, spectate, grab and respawn cameras; preserve the current framing and never restore stale ownership. |
| Modals and UI | `src/client/UI/Modal.luau`, `UI/Menu.luau` | `Modal.anyOpen()` is the verified modal accessor. Any open modal/menu, text/chat focus, or focus loss blocks entry and resets the quiet interval. Observe input without consuming it. `Menu` exposes `close()`; its dropdown visibility remains private until a public accessor is verified. |
| Audio composition | `src/client/Controllers/AudioController.luau`, `src/shared/Config/Audio.luau` | Reuse the local tagged `PianoVoice`/`Audio.LobbyPiano` source and existing `Piano` group; compose gains with existing user, hush and priority controls. |

### Eligibility truth table

| State | Idle timer | Orbit | Piano |
|---|---:|---:|---:|
| No state snapshot, non-Lobby, dead, aboard, or outside Depot Hall | reset | off | off |
| Menu/modal/chat/text focus, app focus lost, camera replacement | reset | off | off |
| Lobby, living local character physically in hall, focused app, free third person, reduced motion off, VR off | count continuous quiet | eligible after 12 s and safe clearance | eligible after 12 s if source exists |
| Locked/first-person/VR/reduced motion | count may continue | off | piano may remain eligible separately |
| Any deliberate input or meaningful held movement/look | reset | cancel immediately | fade out and restore bed |

### Release acceptance

- Contract names and paths above are rechecked with `find_script` before edits; no invented `StateService.phase`, `CarService`, camera stack, or mouse-target API.
- Quiet timing, input observation, UI/focus reset, and one-attempt-per-interval behavior have pure tests or documented gaps.
- Camera clearance returns a bounded valid pose or unavailable; it never forces a radius through geometry. Existing train camera behavior is unchanged.
- Audio fades and ducking are local-listener only; unavailable piano never ducks the hall bed. Owner selects the final song from paid-model suggestions after listening to their samples; this remains a required final-draft/release decision.
- Studio playtest records `start_stop_play`, console output, and a half-scale screenshot. Desktop, gamepad, and real touch audition, three-player isolation, and headphone/phone checks remain HUMAN until performed.
- `lune run check` passes, `HANDOFF.md` records completed work and pending checks, and the feature remains default-off until the final audition gate passes.

### Pending discovery

The physical Depot Hall predicate, camera viewport-change signal, and full PianoVoice gain/loop binding still require targeted indexed reads and Studio confirmation. `Menu` has no verified public open-state accessor yet; do not implement against guessed names.

### Baseline evidence (2026-10-23)

`lune run check` passed on 135b67e. Isolated Studio `lobby-idle-test.rbxl` started, console read, screenshot captured, and stopped. The hall rendered with crew and lobby UI. Existing warnings: unpublished-place DataStore access and asset 203785492 type mismatch. No idle runtime changes were loaded. Subsequently integrated both Claude commits through 53097e3; the integrated gate passed exit 0. A second isolated build/playtest also rendered the hall and reported the same existing warnings.

`LobbyService.Init` constructs the hall at `Tuning.World.LobbyOrigin` and replicates `lobby.origin`; this is an origin, not a verified occupancy predicate. The implementation must derive a conservative hall boundary from the builder before enabling. `AudioController.Init` creates the Piano SoundGroup under LastTrainOut and applies priority compressors: idle gain must compose with that group. `Audio.LobbyPiano` currently points to 1837474268, labeled Gnossienne No. 3; no replacement song is approved.

