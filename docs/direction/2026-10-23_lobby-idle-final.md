## Audit answers

1. **No: neither `wallPull()` nor a passing audit guarantees zero clipping. Confidence: high.** The indexed project has no `CameraUtils` module. The existing local `CameraController.wallPull(camera)` casts one focus-to-camera ray against the run train and `DisplayTrain`; it is not general lobby collision coverage. A center ray cannot protect the near-plane corners. Runtime movement, mesh collision fidelity, query filters, streaming and camera ownership changes add cases a headless model audit cannot prove. Even a spherecast misses geometry intersecting its starting shape; initial overlaps need a separate check. [Roblox's spatial-query documentation](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/WorldRoot.yaml).

   **Cheapest test before building:** capture the current camera at a wall, inside corner, doorway and display-train window; move another player through its path and change phase. Use Studio's existing camera and record failures. Before wiring the feature, test the proposed query adapter in the same locations. Acceptance is no observed clipping in a documented matrix, with the orbit cancelling when clearance is uncertain; never an all-geometry guarantee.

2. **No: 12–15 seconds is a starting hypothesis, not an established optimum. Confidence: high about the uncertainty; low about the winning delay.** No player evidence supports an optimum. The claimed ten-second Dark Souls/Elden Ring timings were not verified from primary sources and should not justify this decision. Resting at a checkpoint also differs from reading, chatting and readying up in a co-op lobby.

   **Cheapest test before building:** show matched lobby recordings with drift beginning at 10, 12 and 15 seconds to five people in varied order. Ask which feels intrusive. Then use a disposable local prototype to test actual interaction; video cannot test agency. Include reading an open menu and holding a movement stick. Start at 12 seconds and keep the threshold fixed, not randomly selected per activation.

3. **No: `0.85 × MaxZoom` is neither a clearance test nor a safe preset rule. Confidence: high.** Current tuning has MaxZoom 30, StartZoom 11 and LockZoom 10. The proposed radius is 25.5 studs, so it can abruptly more than double normal viewing distance and contradict Locked mode. UI closure, portrait aspect ratios and FOV changes also invalidate a previously checked pose. [Roblox's camera controls](https://create.roblox.com/docs/workspace/camera).

   **Cheapest test before building:** inspect the same lobby position at 10, 11 and 25.5 studs, in portrait and landscape, before and after Settings. Reject any forced zoom jump. Enter from the current camera pose, bound distance by the current effective limits, and revalidate clearance each frame. Skip orbit for Locked mode, first person and VR.

## Final draft

### Owner music selection

The owner will choose the final song from paid-model suggestions with listening samples. No suggestion is approved automatically. The existing piano is the implementation baseline only. Suggested auditions: [Satie, Gnossienne No. 3](https://commons.wikimedia.org/wiki/File:Gnossienne_3_(Satie).ogg) for spare unease; [Chopin, Prelude in E minor, Op. 28 No. 4](https://www.youtube.com/watch?v=CU9RgI9j7Do) for a more mournful tone. These are listening references, not approved replacement uploads.

### Pitch

When a player stops interacting in Depot Hall, the view may slowly circle their character while the hall piano comes forward and the lobby bed recedes. One deliberate input immediately returns camera control and gradually restores the normal mix. The effect adds a moment of stillness without interrupting menus, chat or readying up.

### Core loop

Eligible lobby client → 12 seconds of continuous quiet → fade into the existing piano and, where allowed, begin a slow orbit from the current view → input or loss of eligibility cancels the effect → require a fresh quiet interval.

Eligibility requires a received state snapshot, phase `Lobby`, a living local character physically in Depot Hall and not aboard the run train, a focused application, and no modal, dropdown, chat/text focus or Roblox menu. Use `StateController` and established `Session`/camera occupancy logic; the draft's client `StateService.phase`, `CarService` and camera state stack are not established contracts. Other players' actions and automated UI updates do not reset local idleness.

### Features

**Must**

- Count intentional keyboard, mouse, touch and gamepad activity, including UI-processed input. Observe without consuming the event. Held movement/look input and character movement inhibit entry, even without fresh `InputBegan` events. Ignore measured device jitter, not deliberate micro-movements. Touch-down cancels immediately; do not wait for a ten-pixel drag.
- Block entry throughout an open menu, dialogue, shop or text field. Closing it starts a new timer. Focus loss cancels; focus regain starts a new timer. Do not discard UI events using the draft's nonexistent `UserInputService.CurrentMouseTarget` property.
- Keep a small explicit idle lifecycle; do not introduce a general camera framework. Existing train, spectate, grab and respawn cameras take precedence. Capture the current yaw, pitch, distance and subject; preserve FOV and zoom preferences. Releasing idle ownership must not overwrite a newer camera owner or replay a stale pre-idle view.
- Orbit only in Free third person, with reduced motion off and VR off. Start without a position jump. Recheck lobby structures, props, train meshes and moving characters using a near-plane-sized query volume, explicit query filters, an initial-overlap check, and a sweep from the previous accepted pose. Exclude the subject's own body. Decorative non-query geometry requires verified collision proxies or exclusion from eligible paths.
- Pull inward promptly for safety; ease outward only after checking the whole path. Cancel orbit if no valid third-person pose is available or the camera/viewport changes unexpectedly. Permit one orbit attempt per quiet interval to prevent obstruction retry loops. Piano can continue when orbit is unavailable.
- **Reuse the existing hall piano first.** `Audio.LobbyPiano` already names Gnossienne No. 3; `LobbyBuilder` already creates its looping sound on tagged `PianoVoice`; `AudioController` already has a `Piano` group. Convert that local listener's piano gain from always-on to idle-only. Do not layer another performance or seek/restart the existing loop on every cancellation. Leave the shared/server sound and other listeners unaffected.
- `AudioController` composes the idle gain with existing user volume, phase, hush and priority controls. Duck only the `DepotHall` bed, preserving storm, footsteps, dialogue and warnings. Bind/rebind the existing piano locally and clean up replacements. Missing or denied audio leaves the normal mix intact; never duck into silence while waiting to load.
- Read and observe `GuiService.ReducedMotionEnabled`. It disables automatic camera motion and floating piano-note motion; it need not disable music or gentle audio fades. Suppress note spawning while the piano is inaudible and restore existing behavior on exit where appropriate. Honor existing audio preferences. [Roblox accessibility guidance](https://create.roblox.com/docs/production/publishing/accessibility).
- Cancellation is idempotent. Release camera ownership before the next camera render, let the triggering input reach normal controls, cancel stale fades, and restore only this feature's gain factors. Clean up on phase change, death, respawn, teardown and camera replacement.

**Should**

- Tune with five unfamiliar players and a real touch device; record accidental activations, cancellations within two seconds, discomfort and successful immediate control recovery. These are diagnostic observations, not statistically representative retention results.
- Document before/after framing and audibility, including a three-player lobby with only one idle player. Add bounded Studio diagnostics through existing tools if needed; avoid a production telemetry project.

**Later**

- Alternative music, persistent per-feature settings or multiple orbit compositions, only if playtests establish a need. If replacing the recording, offer 3–5 thirty-second previews with provenance before owner selection. A public-domain composition does not establish rights to a particular performance. Verify recording rights, Roblox asset permission and moderation separately; custom upload remains HUMAN pending. [U.S. Copyright Office](https://www.copyright.gov/register/pa-sr.html), [Roblox audio assets](https://create.roblox.com/docs/audio/assets).

### Numbers

All new values are provisional designer settings under one `Tuning.LobbyIdle` table. Keep `Audio.LobbyPiano` as the asset source; do not replace the entire Tuning module or store runtime preferences in pure config.

| Item | Starting value | Test or bound |
| --- | --- | --- |
| Idle delay | 12 s | Compare 10 / 12 / 15 s |
| Yaw speed | 2 degrees/s; 180 s per revolution | Compare 2 / 3.5 / 5.5; 5.5 gives 65.45 s |
| Motion onset | Ramp angular speed over 1.5 s | No zoom, pitch, FOV or roll flourish |
| Desired distance | Current entry distance | Effective preset limits plus per-frame clearance; no 0.85 rule |
| Piano gain | Existing cue level × idle envelope 0–1 | Audition existing 0.48 cue volume; it is not a loudness measurement |
| Lobby-bed idle gain | 0.35 | Compare 0.2 / 0.35 / 0.5; bed remains audible |
| Audio entry / exit | 1.5 s / 1.0 s | Restore bed over 1.2 s; interruption starts from current gain |
| Gamepad deadzone | 0.15 magnitude | Starting drift filter; held intent still inhibits entry |
| Clearance volume | Derived from near plane, FOV and viewport | Include a tunable safety margin; tune in Studio |
| Runtime target | Under 0.5 ms p95 added client frame time on target phone | Engineering budget, not a measured result |
| Implementation effort | 12 / 24 / 40 developer hours | Optimistic / planning / difficult integration; excludes asset approval wait |

Drop the unsupported microseconds/frame, median lobby dwell and re-encoded file-size claims. No new audio download is required for the first version. LUFS is an offline mastering measurement, not a Roblox `Sound.Volume` control; only specify a master target if a replacement recording is actually measured and auditioned.

### Risks

- **Intrusion or motion discomfort:** conservative speed, no forced zoom, blocked UI entry, reduced-motion support and immediate input cancellation. Keep ordinary sound and camera behavior available when the effect cannot run.
- **Clipping or competing camera writers:** volume/path/overlap checks plus cancellation and ownership tests. A headless model audit complements Studio coverage; it cannot certify live rendering.
- **Duplicate piano or fighting volume writers:** reuse one existing source, compose gains in the audio owner and retain warning priority. Test repeated interruptions and source replacement.
- **Overbuilding:** no new lobby art, server gameplay protocol, music procurement or camera framework in the first implementation. A session-only feature does not require a data migration.

### Open questions

1. Do players prefer the existing always-on piano to making it idle-only? Audition both before enabling the new mix by default; preserve the existing mix behind the feature flag until that decision.
2. Does 12 seconds feel natural after menus close, and does 2 degrees/s read as atmosphere rather than unwanted camera control?
3. Are the hall's actual mesh/query representations sufficient at every eligible position and viewport, especially near the display train?
4. Does the mix read on headphones and a phone speaker without masking lobby cues? Existing asset availability must be verified in the intended experience.

## Build prompts

=== PROMPT: Verify contracts and lock the scope ===
Design a client-local Depot Hall idle atmosphere for Last Train Out: twelve seconds quiet, current-pose slow orbit, existing piano foreground, immediate cancellation. Read AGENTS.md, README.md and docs/direction/2026-10-23_lobby-idle-final.md. This step is discovery and documentation only. Use rbxmap `find_script` first, then `read_lines` only within returned ranges, maximum 150 lines. Verify CameraController ownership/aboard logic, Session/StateController snapshot semantics, Modal/Menu/text focus, AudioController gain ownership, PianoVoice and PianoNotes. CameraUtils, CarService and a push/pop camera stack are not existing contracts. Create a brief with a verified file allowlist, eligibility truth table and acceptance matrix; rehash when its file list changes. Keep other sessions' edits. Run `lune run check` and establish the Studio baseline using `start_stop_play`, `get_console_output` and `screen_capture`. Report baseline failures accurately. Update HANDOFF.md; commit only on a passing quality gate. Do not implement yet.

=== PROMPT: Implement quiet-time policy and input observation ===
Implement the input layer for a client-local lobby idle effect, initially disabled and not connected to camera/audio. Entry requires twelve uninterrupted eligible seconds after a valid state snapshot. Use rbxmap to verify the brief's allowlist and stale ranges first. Add strict pure logic under shared Logic with injected time and meaningful Lune specs; add a thin client observer using real APIs. Count UI-processed activity without sinking it, touch-down, mouse intent, sustained sticks, held keys and character motion. Block menus/dropdowns/dialogue/chat, lost focus, non-Lobby phase, dead/missing character and run-train occupancy. Ignore device jitter; initial stick deadzone is 0.15 magnitude. Focus/menu return resets the full timer. Test boundary timing, held-input stalls, repeated cancellation and teardown. Edit disk only; refresh rbxmap for new scripts. Run `lune run check`, `start_stop_play`, `get_console_output`, `screen_capture`; record unavailable checks and exact manual steps. Update HANDOFF.md and commit only after the gate passes.

=== PROMPT: Add a bounded camera-clearance helper ===
Build the clearance layer for a Depot Hall idle orbit without enabling the feature. Current CameraController.wallPull is a train-only center ray; merely extracting it is insufficient. Verify indexed paths and the brief first; add strict camera-query code and pure geometry tests in verified/new allowlisted locations. Protect near-plane corners for current FOV/aspect, query hall props and train geometry, handle initial overlap, and sweep from the previous accepted pose. Define treatment of local/other characters, transparent query parts, mesh proxies and missing geometry. Return a valid bounded pose or an explicit unavailable result, never force a minimum radius through a wall. Keep existing train-camera behavior unchanged until separately verified. Test zero-length spans, corners, thin obstacles and invalid inputs in Lune; actual mesh hits require Studio. Edit disk only, refresh new scripts, and run `lune run check`, `start_stop_play`, `get_console_output`, `screen_capture`. Update HANDOFF.md and commit on pass. Do not claim universal clipping safety.

=== PROMPT: Integrate the interruptible orbit ===
Add a small idle camera mode to Last Train Out using the quiet-time policy and clearance helper from previous prompts. Verify the brief and indexed CameraController/TrainCamController contracts; edit only allowlisted files on disk. Capture current framing; start at 2 degrees/s with a 1.5-second angular-speed ramp, preserving pitch/FOV and entry distance within effective limits. Orbit only in Free third person with reduced motion and VR off. Train/spectate/grab/respawn cameras preempt it. Cancel on deliberate input, changed camera/viewport, lost eligibility or unsafe clearance; allow one attempt per quiet interval. Release ownership before the next camera render without swallowing input or restoring stale state. For this visible change, gather reference framing first, model/refine a faithful lobby-camera staging scene in Blender, render before/after at 0.5 scale, compare against references and fix weak framing; use finished existing art, no placeholder blocks. Confirm real collision in Studio. Run `lune run check`, `start_stop_play`, `get_console_output`, `screen_capture`; report renders, console and handoff behavior. Update HANDOFF.md; commit on pass.

=== PROMPT: Reuse and blend the existing hall piano ===
Implement the audio portion of Last Train Out's lobby idle effect; do not procure or upload a new recording. Verify the brief and indexed AudioController, Config/Audio, PianoVoice creation and PianoNotes before disk edits. Existing Audio.LobbyPiano/Gnossienne and the Piano group must supply one performance per listener. Bind the server-created source locally; keep its loop position, handle replacement and compose gains with existing user/hush/priority control. Feature-off preserves today's mix. Feature-on makes local piano gain idle-only; fade in 1.5 seconds/out 1 second and duck only DepotHall to 0.35, restoring over 1.2 seconds. Never duck while the piano is unavailable. Do not alter shared playback or other clients. Stop floating-note spawning when inaudible or reduced motion is enabled. For changed note presentation, references first; model/refine the existing piano staging in Blender, render before/after at 0.5 scale and compare to references, with no placeholder assets. Verify audible transitions and three-player isolation in Studio, not just Sound properties. Run `lune run check`, `start_stop_play`, `get_console_output`, `screen_capture`. Report headphone/phone audition as HUMAN pending if unavailable. Update HANDOFF.md and commit on pass.

=== PROMPT: Connect eligibility and accessibility safely ===
Wire Last Train Out's idle input, camera and piano behind a default-off Tuning.LobbyIdle feature flag until the final audition. Verify the brief and rbxmap paths before disk edits. Use received StateController data, Session and verified physical hall/aboard checks, not invented services. Block all menus, text/chat focus and background application time. Observe GuiService.ReducedMotionEnabled dynamically: stop orbit and note motion while allowing music fades. Locked camera, first person and VR skip orbit; piano remains separately eligible. Compose normal audio preferences. Death, respawn, phase change, source/camera replacement and teardown must cancel idempotently without stealing another camera or leaving a duck active. Avoid new settings UI/server schema. This changes visible behavior: gather references, model/refine faithful existing lobby staging in Blender, render before/after at 0.5 scale, compare and correct; no placeholders. Test UI browsing, held controls, focus return and countdown during entry/exit. Refresh added scripts; run `lune run check`, `start_stop_play`, `get_console_output`, `screen_capture`. Update HANDOFF.md and commit on pass.

=== PROMPT: Tune, validate and document the release gate ===
Finish the client-local Depot Hall idle effect, using the final design and verified brief. Edit allowlisted disk files only. Compare 10/12/15-second delay, 2/3.5/5.5-degree yaw and bed gains 0.2/0.35/0.5; change one variable at a time. With five unfamiliar players, compare current always-on piano to idle-only piano before enabling the feature by default. Gather visual references first; refine the lobby staging in Blender, render before/after at 0.5 scale and compare against references, correcting anything below finished quality. Verify actual Studio footage on desktop, gamepad and real touch hardware; emulation is supplemental. Cover corners, doors, display-train windows, moving players, portrait/landscape, UI/zoom changes, reduced motion, first person, Locked mode, respawn and phase/camera preemption. Run a five-minute idle session and 100 activation/cancellation cycles; check bounded connections/sounds, profile added client cost against a provisional 0.5 ms p95 budget, and verify three-player local isolation. Run `lune run check` plus `start_stop_play`, `get_console_output`, `screen_capture`. Report tested coverage, renders, audibility and HUMAN pending checks honestly. Update README/TASKS acceptance criteria and HANDOFF.md; do not tick unverified requirements. Commit only on a passing gate; do not push without the owner's instruction.
