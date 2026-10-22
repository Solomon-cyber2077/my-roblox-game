# HANDOFF

## 2026-10-22: PHONE HUD IN-RUN CHECKS (continues Astra's follow-up below)
1. Completed
- Studio, iPhone 7 preset (viewport 666x374), solo, stop 1 doors open: roster hidden; errands panel hidden; pocket watch y101-199 clear of LOOK/RUN (y218-263, LOOK beside RUN) and of the leak slot (y9-36); in-run SETTINGS tab 70x19 on screen; tutorial slot clear.
- Fixed: the TRAIN CAMERA chip (fixed at 236 px above the bottom) overlapped the lifted watch on a phone (y78-118 vs 101). It now sits just above the watch wherever the HUD puts it (TrainCamController): y50-94.
- Camera setting: Locked -> zoom 10-10, Free -> 0.5-30, switched live through SetSetting.
- Sinkhole edge: 36 rope sections on the far line at the test stop; the edge reads as a barrier in the phone view.
- Console: only the known DataStore, TrainVolumes yield, cab-sill and asset 203785492 warnings. `lune run check` passed (514 tests, audit clean).
2. NOT verified (need a real touch device or a crew)
- RUN tap toggle and its idle/winded shutdown, long-press drop, the touch wording of tutorial prompts and the "TRAIN CAM" label (the simulator's clicks count as mouse, so it shows "[C]"), errands panel showing for 6 s on a change (no errand was active), roster with 2-4 crew, camera lock inside buildings.
3. Next logical step
- Play one first run on a real phone with that list, then Gate G1.

## 2026-10-22: PHONE HUD VERIFICATION FOLLOW-UP
1. Completed
- Started `main-s1.rbxl` successfully through Studio MCP on the existing iPhone 7 Device Simulator preset; the lobby rendered in third person with LOOK beside RUN and no visible overlap in that row. Playtest was stopped afterward. The published `LAST TRAIN` Studio window was left untouched.
2. Known gaps
- In-run checks were blocked because the computer-use helper repeatedly returned “Computer Use helper already has an active request,” including after window recovery. Console output contained the expected unpublished-place DataStore warning, fixed-size EditableMesh cab-sill warning, and asset `203785492` type mismatch.
- The network-enabled `lune run check` retry passed: 514 tests across 69 spec files, visual audit clean. The initial sandbox attempt failed while fetching Roblox’s API dump.
3. Next logical step
- Finish the phone run checklist: solo roster hidden; errands hide after 6 seconds; no watch/ticket/LOOK/RUN overlap; RUN toggle and idle/winded shutdown; long-press backpack drop; locked/free camera in train and buildings; visible sinkhole rope; clean console; then test on a real phone.

## 2026-10-22: PHONE HUD DECLUTTER, TOUCH CONTROLS, CAMERA LOCK, VISIBLE EDGE (from the owner's phone screenshots)
1. Completed (code only; `lune run check` passed, audit clean)
- Crew Errands (UI/QuestTracker): always shown in the hall; in a run, only for 6 s after an errand changes (it covered LOOK, the stop ticket and the watch on phones).
- Operators roster hidden on a solo run; the leak slot moves up when it is hidden.
- Touch: LOOK now sits beside RUN on the same row (the watch no longer climbs over a stack); RUN is a tap toggle (WALK/RUN title; ends after 1 s standing still or when out of breath); Shift stays hold-to-run.
- Alerts are said once: the big centre alert for the crew, the feed only for others (hull breach showed three times).
- In-run SETTINGS is a small tab (104x28); TRAIN CAMERA chip drops "[C]" on touch; tutorial prompts have touch wording (Move, Loot, Drop); press-and-hold a backpack slot drops it on touch (there was no touch drop at all).
- Camera setting (Settings: CAMERA, Locked default / Free): Locked pins zoom at Tuning.Camera.LockZoom 10 on PC and touch (no pinch/wheel zoom, never first person); boarding cars bring min and max in together.
- The invisible wall: StationDressing EdgeMark (the unseen stop 4.5 studs short of the sinkhole lip) now has a timber stake and a rope at hip height per tile, non-colliding; the collider is unchanged.
- Route ballot text: "THE DRIVER TAKES THE SHORTER LEG" (was "SHORT LINE", now a route name).
2. NOT verified
- No Studio playtest of any of this yet (the Device Simulator was being opened when usage ran out). Check: phone preset HUD in a run (no overlaps, LOOK beside RUN, solo roster gone, errands hide after 6 s), RUN toggle, long-press drop, camera lock in the train/buildings, rope visible at the edge, console clean.
- A second Studio window "LAST TRAIN" (the published place) is open with a Rojo connect prompt; it was left alone.
3. Next logical step
- Run the checks above in Studio on the phone preset, then on a real phone; then Gate G1.

## 2026-10-22: S8 / MILESTONE 1 ESSENTIALS (PROMPT 6 READABILITY, PROMPT 7 PRIORITY + INTENT HUSH)
1. Completed
- Priority table (Config/AudioPriority; beside Config/Audio so the cue table keeps its `{ [name]: Cue }` shape): 1 Warnings (WarnTick/Bell/Whistle/WhistleLong, own group outside the main mix) > 2 Threat (mix "Cues": swipe, slam, scream, wake, strike, spawn, scrabble, heartbeat, alarm, DoorForce, and the stalk breath, now on the Cues group) > 3 Feedback (mix "Steps" and new "Feedback": hit, loot, deposit, heal, flash, eliminated, purchase, clutch, clicks, ticket sounds, the player's winded breath) > 4 Ambience (Ambience/Outdoor beds, TrainRun moved in, so the Settings Ambience row now scales the train run too) > 5 Piano (LobbyPiano, mix "Piano").
- AudioController builds every compressor from the table: each tier's groups carry one sidechain per group of every higher tier, using that tier's duck (Warnings and Threat -30 dB / 8:1 / 0.5 s, Feedback -26 / 2.5 / 0.18 as before, Ambience -24 / 1.5 / 0.4 onto the piano only, CHOICE). The old three compressors on Ambience are replaced by the same values plus Feedback. Voice caps per tier for one-shots (Feedback 10, Ambience 8, Piano 2); Warnings and Threat never drop.
- Intent hush (FIXED 0.4 s): HollowAnimator calls AudioController.IntentHush on the rising edge of a Hollow's replicated Intent while its State is Hunt (never a Windup under way), when it targets this player or is within 40 studs. Ambience to 0.3 and Steps to 0.4 of their level (CHOICE); warnings and threat untouched. SoundService attribute IntentHushAt marks each one.
- Spec: tests/AudioPriority.spec.luau (tier order, named cues in their tiers, every group/mix has a tier, warnings/threat uncapped, 0.4 s hush).
2. Verified / known gaps
- `lune run check` passed: 514 tests, 69 spec files, audit clean.
- Studio Output (compressor dump): Ambience <- Warnings, Cues, Steps, Feedback; Cues <- Warnings; Steps/Feedback <- Warnings, Cues; Piano <- all five above; Warnings has none and sits outside LastTrainOut. Scheduling only, not audibility.
- Studio Intent hush, one timeline: every HUSH within 0.01 s of a hunting Hollow's Intent rising edge (a live Hollow cycling Hunt/Windup/Recover on a god-mode player, about every 1.1 s); Ambience 1.00 -> 0.30 and Steps 1.00 -> 0.40 for about 0.4 s, then back. Intent set on a rig already in Windup fired no hush.
- Readability (docs/direction/readability/2026-10-22, Studio, default Visibility): sinkhole edge at 8 studs at two stops (iron railing / picket fence against fog and trees: clear); nearest obstacles at 6-12 studs (crate, brick rubble, timber pile: clear, warm-lit or dark on pale ground); Stalkers frozen at 15.5 / 24.2 / 33.0 studs: all three read (dark coats, pale faces) on desktop, under Performance, and on the iPhone 7 preset; under chase dim while grabbed with fog rolling in, the 24 and 33 figures are faint but visible. No light/rim/value fix was needed, so none was made. Weakest frame: phone preset at Ashgrove before the dread grade, a dark-coated Stalker against unlit buildings (low contrast, still visible). Hollows carry no rim Highlights by design (rims are for props and buildings).
- NOT verified: Visibility 18 vs 30 side by side; a real phone at 40% brightness; any subjective audibility. HUMAN: the owner's headphone and phone-speaker audition (warning priority over drone/threat, the Intent hush, stalk-breath direction).
- Studio tooling found broken (not fixed, out of scope): Dev `tp` does not move the player (server PivotTo on a client-owned character); `warp` with a negative number is rejected by the Dev remote's id argument check, so a stop cannot be held open. God mode repeats tell_exposure on every missed strike (known since S3).
3. Next logical step
- Stop for Gate G1 (docs/direction/2026-10-21_after-the-prompts.md Stage 1 and A.4's prerequisites: one real phone full first session, durable sink read back, recording policy). S9-S11 only after G1 passes.

## 2026-10-22: S7 / PROMPT 10, FIRST THREE MINUTES, ROUTES, INVITES, EXPERIMENTS
1. Completed
- First visit: hall spawns face the departure board, which reads "START · OR BOARD A CAR" with one line for each. The panel button is START (CANCEL once ready; JOIN RUN mid-run). Above it: BOARD A CAR (walks you to the door of a car with riders, else the nearest; then hold E to Board) and INVITE. Cars CountdownSeconds 40 -> 20 (PROVISIONAL); MinPlayers and ArrivalWaitSeconds unchanged.
- Short first leg: on a tier-1 run every leg-1 option is Tuning.Run.FirstLegKm 1 km (cruise 18 + 6 = 24 s). RouteGen makes the same draws, so stations, tiers and later legs are unchanged (spec'd). The scenery is not sped up.
- Routes (Logic/Routes + spec): Tuning.Run.Routes {Short 5, Long 10}, replicated as run.stopCount. Short stop k reads Long stop m(k) = {1,2,4,6,8} for every stop-indexed difficulty input:
  - forStop over the Long count
  - Threat.total (Hollow caps) and Threat.protection
  - leaks, skill checks, door-forcing
  These read HazardParams.level. The stop clock, HollowSpeed's first-Crawler rule and the tutorial stop rules use the real k. Short D = 0.080 / 0.117 / 0.252 / 0.431 / 0.643; the Terminus keeps d = 0.
- Sky, omens and timed events:
  - The sky already reads run.stopCount (Journey.hour with stops 5).
  - Omens get `dark` from AtmosphereController's hour, so they follow it.
  - Timed events depend only on the layout seed and D, not the route length.
- Route policy: a player is new until 2 runs reached RunEnd (profile.stats.runs; Studio's `/tutorial reset` sets a session override).
  - Any new crew member fixes the line: Short, or E1's arm while E1 runs. The hall shows "Short Line: a new Hand rides with you."
  - Otherwise each hall player votes SHORT or LONG (remote VoteLine); the crew's votes decide at Boarding, and a tie or no votes goes Long (CHOICE).
- Rewards:
  - Per-stop Brass/XP/haul unchanged; a Short Line victory is stamped SHORT LINE and counts toward `victories`.
  - New stat `longVictories` counts Long victories only (Ledger "Long Line arrivals").
- INVITE (UI/Invite): on the Depot hall row and the run card. Shown only when CanSendGameInviteAsync allows; opens PromptGameInvite and logs invite_prompted (depot/runcard).
- Experiments (Config/Experiments, Logic/Experiments + spec): arm = Rng(hash(runSeed, salt)) for the whole crew.
  - E1: Short/Long; eligible = new Hands; exposed at run start.
  - E2: Sighting/None; eligible = players on their own first run; exposed at stop 1's doors in both arms; it drives hazards.sighting.
  - Each player's first arm is stored in profile.telemetry.cohorts and logged once (cohort_assigned, arms A/B). Telemetry vocabulary narrowed to E1/E2 and A/B.
  - Both are `enabled = false` until the soft launch (G2). Dev `experiment <E1|E2> <arm|auto>` forces an arm.
- Telemetry first_session_timing `first_hollow_seen`: the first clear line between any Hollow and the player (declared in S1, sent now).
- Report (`lune run report`): a Short Line difficulty table, and both routes through the new Logic/RouteModel (spec'd) with Brass per winning run and Brass per minute. No bell: Long 47.60 min / Short 24.26. Every stop u=0.40: 33.87 / 17.65. 60% of stops u=0.50: 40.98 / 21.07. brass_win 140 / 110 (per-stop + Terminus only).
- Fixed (S6 bug): the stop-1 sighting got one placement try, at the first step off the train. Near the train the 24-stud safe strip counts as lit, so it usually never appeared. It now retries every Sighting.RetrySeconds 1 while pending.
2. Verified / known gaps
- `lune run check` passed: 510 tests, 68 spec files, audit clean.
- Studio first-session timings, fresh tutorial (Dev reset), scripted player, against the A.4 targets:

  | Timing | Target | Desktop | iPhone 7 preset (Device Simulator) |
  |---|---|---|---|
  | control | ≤10 s | 1.23 s | 0.66 s |
  | run Countdown | ≤45 s | 14.75 s | 17.67 s |
  | stop-1 doors | ≤120 s | 82.82 s | 85.73 s |
  | first Hollow in line of sight | ≤180 s | 149.31 s | 92.12 s |

  - The Countdown timing includes a scripted START press about 13–17 s after join, slowed by the Studio script's latency.
  - The desktop Hollow time was inflated by a debugging pause; the phone run walked out about 5 s after the doors opened.
  - Doors opened 68.6–68.9 s after START (Countdown 10 + Boarding 4 + Junction 20 + Cruise 24 + Arrival 10).
- Studio:
  - The spawn faces the board; the hall row shows the fixed line for a new Hand, and the vote buttons (✓ SHORT LINE · 5 (1)) for a veteran.
  - A veteran's Short vote gave STOP 1/5. The HUD read STOP 1/5 on the first run.
  - Short victory: SHORT LINE stamp, payout 110 Brass (5 x 6 + 80), run_progress `short`.
  - INVITE showed on the card and in the hall; the wipe card's stamp sits clear of the buttons.
  - Console clean apart from the known asset/cab-sill/TrainVolumes warnings.
- NOT verified:
  - An actual invite send and a friend's join.
  - longVictories after a real Long victory (only code and spec'd stats paths).
  - E1/E2 live (both off; covered by specs and Dev force only).
  - BOARD A CAR's walk.
  - Multi-player line votes.
- Drift / known issues:
  - Device Simulator reports touch+keyboard+mouse, so telemetry logged the device as `unknown` there; real phones are HUMAN.
  - From some spawn points a hall post hides part of the board's text (the START panel is always on screen).
  - ProgressionService passes `dailyBonus = false`, so the daily first-run bonus is off in code today (left unchanged, as Prompt 10 says).
  - livery_royal is still a 2400 Brass item, and the Roll of the Terminus does not exist: longVictories gating is Prompt 8's (S11).
  - JoinInProgressMaxStation 6 lets anyone join a Short Line at any stop.
- HUMAN: real-device timings; enable private servers in Creator Hub and record the price.
3. Next logical step
- S8 (Milestone 1 essentials from Prompts 6 and 7), then the G1 playtest. Still pending from before: S5's two-client latency matrix, multi-client AGAIN.

## 2026-10-22: S6 / PROMPT 5, FIRST RUN AND AGAIN
1. Completed
- First run (tier 1, Config/Tutorial): stop 1 has no Hollows (stop1Cap 0) and a scripted sighting; stop 2 has only the scripted Crawler (ScriptedGrab.Stop 2, non-lethal, zone 100 degrees; yard lamps at stop 2); stops 1-2 are quiet (quietUntilStop 2: no wanderer, no timed events); stop 3 has one awake Stalker wanderer that stalks (Stop3, `StalkWanderer`) and leaves anyone within 20 studs of the train alone (`AwayStuds`, measured in station-local Z); no leak on the first cruise (Difficulty.Leaks.FirstCruiseCap 0, `Leaks.cap/count(..., tutorialTier)`). Tier 2 keeps the old stop-1 cap and drops the scripted grab.
- Sighting (Logic/Sighting + spec, HollowService): a Stalker shows 15-17 studs off (fallback 24) in the dark, out of lamp reach, holds 3-12 s (1 s faced / 1.5 s seen), then walks 60 studs deeper and is dismissed after 8 s. Telemetry `sighting_exposure`. `Tutorial.Sighting.Enabled` is the E2 flag.
- AGAIN/DEPOT (Logic/Again + spec, LobbyService, UI/RunCard): RunEnd opens a card for the run's present members. AGAIN (gamepad A) during RunEnd is queued and applied after ResetReady on Enter.Lobby; in the hall it applies at once. The hall holds its countdown (RunRules `holdCountdown`) until every present, non-DEPOT member is ready, or 20 s after the first applied press with one ready. DEPOT (gamepad B) leaves the player unready. Card shows the crew's ready count (`lobby.again`). Remote `Again(boolean)`, telemetry `again_pressed`.
- Prompts "Face" (on being stalked) and "Bell" (once back aboard); a crew member past the crew's tier is told the run goes at a new Hand's pace (TutorialService.AnnouncePace). Lobby and TicketBook show DEEPEST STOP. Dev `tutorial <reset|0-3>`.
- Fixed: HollowService.think now advances dt/lastThink before its early returns, so a Hollow leaving Emerge no longer banks the jump into its first-strike warning (the stop-2 Crawler's coil was 1.0 s real; now 1.51 s logged).
- Run card layout: the stamp sits just above the foot, the three buttons share the foot, the H hint moved under the ticket.
2. Verified / known gaps
- `lune run check` passed: 495 tests, 66 spec files, audit clean.
- Studio (solo, main-s1): stop 1 no Hollows, sighting at 16.2 studs, froze, withdrew, gone after 8 s (sighting_exposure 3.01). Stop 2: only the scripted Crawler, coil then Windup and a non-lethal grab released after ~7 s; no wanderer or timed event. Stop 3: no Hollow within 20 studs of the train for 30 s; beyond 20 the Stalker stalked, hunted and struck after tell_exposure 1.51 s. AGAIN in the hall started the countdown at once; AGAIN during RunEnd showed READY 1/1, survived the reset and the next run counted down with no lobby input; DEPOT stayed unready (0/1 after 25 s). Console: only the known asset 203785492 and cab-sill warnings.
- NOT verified: multi-client AGAIN (the 20 s fallback hold, late joiners, a member leaving mid-wait), real gamepad A/B and click input on the card, the "Face"/"Bell" prompt text on screen, tier 2 in Studio, phone-sized card layout.
3. Next logical step
- S7 (Prompt 6), then S8, then the G1 playtest. S5's two-client latency matrix is still pending.

## 2026-10-22: S5 / PROMPT 4, BELL, STOP CLOCK B AND THE RAILING GRASP (Astra started, Claude finished)
1. Completed
- Bell: a rope by the route board (TrainInterior), `TrainService.RingBell` (Dwell, alive, aboard, within 9 studs) -> `RunDirector.ShortenStop`. u = elapsed since doorsOpenAt / the ORIGINAL params.dwell (LastCall included); "all" at u >= 0.40 with every living member aboard, "half" at u >= 0.60 with at least ceil(living/2) aboard. departAt = min(departAt, now + 30) only if strictly shorter (idempotent, never extends); Dwell ends 15 s before; startedAt and the hazard dwell are kept; timed events cancel; the branch is stored and reported on stop_resolved. No bell at the Emergency Village or the Terminus. Logic/DepartureBell + spec.
- Stop clock B shipped: WalkReference 30 (timer only), Search 80/60, WalkMargin 1.4, PerStop 3. Report: 47.57 min no bell / 33.85 at u 0.40 / 40.09 at u 0.60 / 41.09 with 60% of stops at 0.50 (was 58.3 min after S2's walk 21).
- Payroll reach: StationReach measures the payroll cell's BFS route; specs hold it inside farWalk and the solo inequality (farWalk/21 + farWalk/13.65 + 0.5 + approach <= dwell - 15) at D0/D1, stops 1 and 10. Studio Minehead (largest farWalk 720): PathfindingService route 435.5 studs (agent radius 1.6) / 448.7 (2.2), straight 425.4; solo return ~54.8 s against 175 s.
- Grasp: Jump during the live chase window sends `Grasp`; GraspService snapshots the server's root and the nearest static GraspRail once at receipt (no history, no extrapolation). Logic/RailingGrasp: reach 3 + 0.5 + min(closing x 0.1, 1.0) (3.5-4.5), press estimate = receipt - one-way latency clamped 0-0.2 s for the window only, receipt <= chaseEnd + 0.2 (RunDirector holds Departure that long). Aboard credited at attachment and held until the departure resolves; 0.6 s hang, 0.5 s haul into the doorway, collisions off then restored; miss = 0.5 s stumble, retry allowed; left-behind line gives the measured shortfall ("less than 0.1 stud short" under 0.1; window/state reasons stated as such). CrewPoses hang/haul/fallShort; 0.35 s camera kick on Clutch. Telemetry grasp/grasp_shortfall (+ grasp_reach, grasp_press_offset diagnostics); GraspResult adds window/state/occupied.
- Studio-only: Dev `bell`, `grasp [studs]` (server holds the pose then runs the normal attempt).
2. Verified / known gaps
- `lune run check` passed on the merge: 479 tests, audit clean (Grabs 0.00 short).
- Studio: bell at u ~0.45 cut 1:43 to 0:29 ("all"), a second pull was refused; grasp from 6 studs missed (shortfall 2.64, stumble), from 2 studs caught (Hang 0.56 s, Haul 0.51 s, released inside the cab, stop cleared, Clutch + "made it", no fall). Merged build: bell, Stalk/guard/grab and telemetry ran together without script errors.
- Fixed during testing: TrainShell was swapping the GraspRails out (kept by name now); a credited grasp could be undone by positionTick after release (now held to departure).
- PENDING: the two-client latency matrix (0/50/100/200 ms) and real Jump/touch/gamepad presses. A scripted client could not hold a pose on the moving platform for the receipt snapshot, so the network path of the grasp is unverified; Studio checks used the server-held Dev path. T-10 after a bell jump not observed separately (DepartureSchedule returns only the latest milestone, spec'd before).
3. Next logical step
- S6 (Prompt 5, first run and AGAIN), then S7, S8, then the G1 playtest.

## 2026-10-22: S4 / PROMPT 3, BODY LANGUAGE
1. Completed
- Logic/HollowMotion (pure, spec'd): look-at yaw with the 0.25 s lag and per-kind caps (Stalker 70, Crawler 50, Brute 35), prowl scan, lean from forward acceleration (clamped 0.3 rad), blend rules (Prowl/Stalk/Hunt/Recover/Repelled ease out over 0.28 s; Coil, Windup and Lunge snap), and foot plants by gait phase (bipeds at pi/2 and 3pi/2, the Crawler's four limbs as each swing ends).
- Server: HollowService replicates `Target` (the head's prey) and `Intent` (+ IntentAt): a hunter in sight within LungeRange 16 once its first-strike guard is met. Intent drives the coil only; it never delays an attack. The 0.4 s Intent hush is S8's (audio), not done here.
- HollowPoses: coil pose per kind (crouch, head low, arms swept back and out; the Crawler sunk on its haunches; while moving the legs keep the gait's stride), shown for Intent and for the S3 WarningCoil; breathing, swaying Stalk freeze; miss follow-through (strike to 0.18 s, then an over-reach stumble until RecoverSeconds 0.4); the Stalker's windup arms flung wider. Kind windups unchanged (Crawler 0.21, Stalker 0.3, Brute 0.42 s).
- HollowAnimator: look-at and lean for the nearest 6 Hollows within 60 studs; blending/snapping per HollowMotion; HollowStep on plants only (the timer emission is gone): Brute heavy + ground shake, Stalker soft, Crawler skitter; every other plant while stalking, none while frozen.
- HollowCosmetics: the Stalker's 3-5 coat strips (primitive parts on Welds, hinged at the hem, trailing with speed and stirring in the wind, count by stop progression) and pallor (head, jaw, hands toward Bone, a darkening socket band), within MaxParts 40 (the chain accessory drops to two links to make room). Mesh strips were not used: no HUMAN upload pending.
- Audit: the Grabs target now poses every kind in every state (Prowl, Stalk, Stalk frozen, Hunt, Hunt coil, Windup, Recover, Dormant, Emerge, Repelled, Reel, Stunned). Studio /photo prints each kind's IK shortfall over those 12 states; `photo <State> [coil|frozen]` poses the lineup (only roots are anchored now, so the animator moves the joints).
2. Verified / known gaps
- `lune run check` passed (461 tests); Grabs audit 6,606 poses, furthest reach 0.00 studs short. Studio /photo: Stalker, Crawler and Brute IK shortfall 0.00 over 12 states.
- Studio captures at 25 studs (desktop viewport, Depot Hall): Hunt vs coil vs Windup vs Stalk frozen read as distinct silhouettes. NOT checked at a phone-sized viewport (Device Simulator needs manual setup).
- Studio run: a stalking Stalker's head turned toward me (bearing -62 degrees, head -79: the cap limits the look-at itself; the Stalker's existing contortion twist adds on top); Target replicated; Intent toggled on in the close hunt and off at Windup/Recover. Console clean.
- NOT verified by ear: steps on plants (no audio capture); coat strips seen only in code paths, not photographed from behind.
3. Next logical step
- S5 is running with Astra (codex/s5-bell-astra); merge it when done, then S6 (Prompt 5, first run and AGAIN).

## 2026-10-22: S3 / PROMPT 2, STALK, FIRST-STRIKE GUARD, DOOR-FORCING, TELLS
1. Completed
- State diagram (Logic/Stalk header): Prowl -> Stalk when a crew member is sensed beyond CommitRange, this Hollow is the nearest prowler sensing them, nobody already hunts them, its one stalk per target per stop is unspent and no stun/stagger exclusion (6 s) runs. Stalk -> Hunt on Surge, proximity (CommitRange), a seized target, MaxStalk (overrides facing) or a turned back (after MinStalk; halved when alone within 14 and unlit). Stalk -> Prowl when sight is lost for Persistence, on a stun, or when the target leaves. Hunt -> Windup only once the first-strike guard is met. Wanderers, Surges and the scripted Crawler commit directly; `StalkWanderer` on a wanderer opts it into Stalk (for Prompt 5's tutorial Stalker).
- Provisional/fixed table: Difficulty.Stalk Min {4,1.5}, Max {12,6}, BackTurned {2.5,1}, CommitRange {12,16}, AloneRadius {14,14}; Tuning.Stalk ReferenceRadius 30, band 0.8-1.1r (24-33), exposure 1.2r (36), WarnSeconds 1.5, GuardDistance 16, facing 25 degrees within 40, switch at 0.6x distance, LampPool 22 (CHOICE), breath 0.5-1.0r, lean/flicker within 1.0r (flicker max 15%, lean 18 degrees CHOICE), watch stutter 1.2r; Tuning.DoorForce Chance 0.4 from stop 3, 3 s + one 4 s hold, open 6 s.
- First-strike guard per Hollow per target: warning counts only in sight within 36 during Stalk or the guarded coil; while under 1.5 s the Hollow replicates WarningCoil/WarningTarget, holds outside 16 (or holds still if already inside), and cannot wind up, lunge or strike. A landed grab spends the guard (first strikes only). Post-grab immunity resets that target's stalk budgets.
- Door-forcing: Logic/Doors (seeded per stop) + BuildingService owns one episode per door: shared timer, Hollows queue, "Hold the door" prompt adds 4 s once, light on the door cancels, expiry opens the door for good (the same opening as the crew's Force the lock).
- Tells: Logic/Tells (pure, fixed r) drives the local cone's lean away, the lantern Glow's gutter through a TellDim attribute in Visual/CosmeticMotion (brightness only, reach untouched), and the pocket watch needle stutter in UI/Hud. HollowAnimator: Stalk borrows the prowl pose, Frozen gives no steps, unobserved stalk sounds every other footfall, a looped breath rolls off 15-30, a guarded hunter holds a half-reared windup as its coil.
- Telemetry: tell_exposure and tell_cohort on every strike attempt (Astra's S2 first-Crawler block is replaced by the general guard, which covers scripted targets).
- Studio-only: Dev `stalker [kind] [studs]` (ordinary prowler at a range, tagged DevSpawn), `doors` (forcing stop + shut doors), `photo stalk` / chat `/photo stalk`.
2. Verified / known gaps
- `lune run check` passed (450 tests, audit clean); specs cover the fixed reference and band invariant, facing, min/max precedence, solo timing, target switching, warning exposure, approach clamp, door concurrency, tells, and identical decisions at Visibility 18 and 30.
- Studio (main-s1, god mode): faced Stalker froze at 30.1 studs, committed at max stalk (~10.9 s); back turned, it moved 4.9 studs within 30.8-32.4 and committed at ~3.5 s; spawned at 10 studs it hunted at once, held at 10.0, coil cleared at 1.49 s, first Windup 1.92 s; a stop's wanderer approaching from far never got inside 17.2 studs while coiled; at seeded forcing stop 3 a Stalker behind a locked door forced it open and came through. Console: no script errors (only the long-standing TrainVolumes yield, audio 203785492 and cab-sill warnings).
- NOT verified in Studio: the hold extension (needs real prompt input), several attackers queued on one door, light cancellation (no lit rooms exist since the fuse boxes went; only tutorial SafeLights can cancel), head tracking while frozen (left for S4 body language), the /photo lineup shows build poses because the freeze anchors parts, and tells/band readability on a phone at Visibility 18 and 30 (manual).
- Drift recorded: buildings have no lit rooms (IsLitAt is always false) and the only shut doors are locked ones, so forcing happens at a still-locked door between a hunter and its prey.
- tell_exposure fires per strike attempt as specified; in god mode that repeats each missed strike.
3. Next logical step
- S4 (Prompt 3, body language): read Stalk, Frozen, WarningCoil and WarningTarget; add head tracking and plant-timed steps (replace the half-rate timer).

## 2026-10-22: S1 / PROMPT 0, TELEMETRY AND THE BALANCE REPORT
1. Completed
- `Services/TelemetryService` (ORDER after DataService) is the only AnalyticsService caller: `Event`, `Funnel` (onboarding via LogOnboardingFunnelStepEvent, other funnels via LogFunnelStepEvent with server-made ids kept in `profile.telemetry`), `Brass` (LogEconomyEvent). Vocabularies frozen in `Config/Telemetry`; `Logic/Telemetry` checks every field and buckets; specs keep every event under 8,000 combinations (largest: tell_exposure, 168).
- Events wired now: run_started, run_joined, stop_resolved (bell always `none` until Prompt 4), stop_archetype, stop_timing, player_stop_resolved, player_eliminated (heldBy from the last grab), run_ended, run_progress (route length), player_run_outcome, player_progress, session_ended, quit_after_outcome, first_session_timing (control, run_start, first_stop). Funnels: onboarding (joined, first_board, first_off_train, survived_stop1, reached_stop3), grab (first_grab, first_escape), pry, replay (first_run_ended, second_run_started). Brass: run payout and milestone sources, shop sink.
- Declared but waiting for their prompts: tell_exposure/tell_cohort (S3), grasp/grasp_shortfall (S5), again_pressed (S6), cohort_assigned, invite_prompted, first_hollow_seen (S7). GraspResult and ExperimentId/Arm lists are PROVISIONAL.
- Scope rules: crew events once per run/stop to the first connected member (UserId order); player events per occurrence; join-in-progress players get run_joined and first_board but not survived_stop1/reached_stop3 that run. Doors-open time runs from Dwell to the T-0 whistle; stop_resolved value = that over the original params.dwell x 100. Stop field: `pre` before stop 1, `between` after a stop resolved, `village`, `terminus`. The Terminus leg is the run's end, not a stop. Run time starts at Countdown (Boarding when launched without one) and ends at RunEnd entry.
- Device: the client classifies once (`Logic/Telemetry.classify`) and sends it in ClientReady (new arg kind `device`); the server keeps the first report. No new remote.
- Durable sink (`Logic/TelemetrySink`, spec'd): per player per server key `<placeId>/<serverId>/<userId>`, flushed every 30 s, on leave and at BindToClose through Logic/Retry, capped at 2,000 with one `sink_overflow` record. On in Studio and private servers; `Tuning.Telemetry.SinkEnabled` (true until G1) for public ones. Dev `telemetry`, `telemetry flush`, `telemetry dump [serverId]` (CSV).
- `.lune/report.luau` repaired: real archetypes and dimensions, clock now vs clock B, chase ranges by kind and pace, Threat.total, fog start, and a 1,000-seed route model through the Terminus with bell scenarios (u over original dwell, departAt = min(departAt, pull + 30)), Long and placeholder Short Line. Clock B reproduces B.4 exactly: 47.57 / 33.85 / 40.09 min (60%@0.5: 41.09 vs B.4's 41.21, which stops ring differs).
2. Known bugs / pending
- `lune run check` passed (420 tests, audit clean). Studio (unpublished main-s1.rbxl): join, boarding, off-train, stop 1 resolution, elimination, run end, Brass and the replay funnel all printed once each with valid fields. session_ended was not seen (a stopped server's last output does not reach the console).
- Sink read-back NOT verified: DataStores need a published place. Manual: open the published place, enable Studio API access, play, `Remotes.Dev:FireServer("telemetry")` to note the server id, stop, play again, `Remotes.Dev:FireServer("telemetry dump <old id>")`.
- Published ingestion pending (Creator Analytics). Funnels need a loaded profile outside Studio.
- After S2 lands (walk 21), the clock's walk term uses Crew.WalkSpeed, so dwell grows until Prompt 4 adds WalkReference 30. Re-run the report then.
- S2 (Astra, `codex/s2-speed-astra`, see HANDOFF-ASTRA.md) merged here with no conflicts; merged `lune run check` passed (422 tests, audit clean) and a merged Studio run reached stop 1 with walk 21 and telemetry intact. Report after merge: chase ranges match B.4's table exactly; the clock the game runs now gives 58.3 min no-bell runs and 252 s doors-open stops (walk 21 in its walk term) against clock B's 47.57 min / 187 s. S5 (Prompt 4) fixes it with WalkReference 30.
- Astra left a `-- S1 hook:` in HollowService at the scripted Crawler's first warning: that is tell_exposure work for S3.
3. Next logical step
- S3 (Prompt 2), wiring tell_exposure/tell_cohort at Astra's hook. Consider S5's clock change early, since runs are now ~58 min.

## 2026-10-21: FINAL DESIGN DRAFT IN THE REPO (docs only)
1. Completed
- `docs/FINAL-DESIGN.md`: copy of the Codex final draft, plus A.4 "Budget and release" (budget gate at G1, co-op horror positioning, no seasonal date, zero-revenue plan, $0-300 cash) and a D.2 budget-gate check. Linked from README and AGENTS.
- `docs/direction/2026-10-21_LTO-investment-assessment.md`: fact check of the outside assessment and a staged second opinion.
2. Known gaps
- The Codex original (`Documents/Codex/2026-10-20/o/outputs`) is now a second copy; edit the repo copy. `Last Train Out - Organized.html` there is the older professional layer, not the final draft.
- Added later the same day: G1 prerequisites (phone smoke test, durable telemetry read-back, recording consent), G2 eight-week time box, icon testing; `after-the-prompts.md` no longer gives success odds and points to `docs/FINAL-DESIGN.md`.
- Prompt 0 now specifies the durable DataStore telemetry sink and a `telemetry dump` dev command. `lune run check` passed in full on 2026-10-21 (exit 0, audit clean); Selene's API-dump fetch worked this time.
3. Next logical step
- Prompt 0 (telemetry and report fix), then Prompt 1 (speed ladder).

## 2026-10-20: PROFESSIONAL LAYER DIRECTION (design only, no game code changed)
1. Completed
- `docs/direction/2026-10-20_LTO-professional-layer.md`: audit of the analytical audit and the owner's response, the resolved design brief, nine ordered implementation prompts (telemetry; speed ladder; stalk state and tells; body language; bell, dwell and railing grasp; first run and AGAIN; station material, edge, grade and lighting lock; sound hierarchy and ping; retire Brass and the Depot premise; release checklist) and the completion standard.
- Facts established from the shipped modules: a full ten-stop run is about 53 min (doors open 185-240 s per stop); Hollows (chase 22.3-25.5 before kind) are slower than the 30 stud/s walk everywhere except lunges, so sprint and stamina currently do not matter; no stalking state exists; no AnalyticsService use; the stations' modern read traces to the hazard rails/tape/red strip, whitewash, limewash and cyan grades.
- `lune run check` passed in full at 6333312 this session (format, lint, strict types, tests, audit). `lune run report` crashes: its "neutral" archetype has no length/depth (`DifficultyModel.farWalk`); Prompt 0 fixes it.
2. Known gaps
- No Studio instance was running: nothing play-tested live; no real phone. The "v2 decisions and algorithms" document was not found anywhere on disk or in the bridge; the owner's raw response was used as the authoritative intent.
3. Next logical step
- `docs/direction/2026-10-20_LTO-debate-response.md` answers the GPT review point by point (ladder, dwell decoupling, grasp, stalk, telemetry mapping, service record); the brief's prompts are to be updated with those values once the review confirms.
- Run Prompt 0 (telemetry + report fix), then Prompt 1 (speed ladder). Prompts 6, 7 and 8 can run in parallel with 1-5 on separate files.

## 2026-10-18: Prompt 8 audit of 38b14e1
1. Completed
- Audited claude/last-train-out at 38b14e1. Existing MAP.md changes preserved and excluded.
- One targeted fix: Config/Haul DuoPenalty 0.05 -> 0.15, SoloPenalty 0.40 -> 0.35. Updated Tuning's speed comment and Haul.spec to assert the requested constants against actual walk tuning. No monster or visual changes.
- Source/test verdicts (live presentation remains unverified):
  1. PASS: slots and cargo separation (tests/Haul.spec.luau:7); non-spendable haul XP (Config/Haul.luau:26, Services/ProgressionService.luau:64); representative physical stacks, no floating balance (Builders/HaulBuilder.luau:103).
  2. PASS: stores strongbox/marked receiving spot (Builders/HaulBuilder.luau:67); E and server reach check (Services/HaulService.luau:42); deposit/visible stacks (:160).
  3. PASS: Terminus opens lid (Services/RunDirector.luau:484, Services/HaulService.luau:284), timed ledger rows (UI/HaulReceipt.luau:93), Crew Rank XP and persistent placeholder stats (Services/ProgressionService.luau:64, :95). Actual outfit/pin awards and Crew Pass presentation remain placeholders, as recorded below.
  4. PASS: lost valuables only and 0.45-second stamp (UI/HaulReceipt.luau:64), M1 closes whole report (:49); haul discarded (Services/HaulService.luau:298), existing progression only incremented (Services/ProgressionService.luau:80).
  5. PASS: drop removes inventory only on successful station pickup creation (Services/InventoryService.luau:179); pickups belong to current station model (Services/LootService.luau:61).
  6. PASS for the ten normal loot stops: one sealed crate (Services/HaulService.luau:234, Builders/HaulBuilder.luau:12), back row (Logic/LayoutGen.luau:312), six valuables versus three loose, ticket and scrap/tonic, no coal (Config/Haul.luau:15; LORE.md:226); delivery reveals contents (Services/HaulService.luau:172). Explicit scope caveat: LayoutGen:316 excludes Terminus and the EmergencyVillage rescue stop.
  7. FAIL at audited commit: penalties were 5%/40%; fixed to requested 15%/35% (Config/Haul.luau:5). Sprint blocked (Controllers/MovementController.luau:95), inventory dropping blocked (Services/InventoryService.luau:179); consumables allowed for duo, blocked solo (:134). Universal monster balance has exceptions below.
  8. PASS: server-owned carrier list and movement validation (Services/HaulService.luau:252, :365); only new nearest-distance duo progress (Logic/Payroll.luau:59); 60% threshold (:82); only valuables doubled (Services/HaulService.luau:186); membership changes preserve accounting (Logic/Payroll.luau:38, :49), disconnect uses leave (Services/HaulService.luau:429). Entirely solo routes never double; an already earned duo threshold survives a solo final leg by design (tests/Payroll.spec.luau:70).
  9. PASS in source: lamp copy/restore (Services/HaulService.luau:59, :78), one PointLight (Builders/HaulBuilder.luau:28), 30 solo/45 duo range, both colored lamp models and blended pool (Services/HaulService.luau:402), faint dropped glow, crate center two studs below carrier roots (:385). Runtime visibility/clearance is not certified.
  10. PASS: tests/Payroll.spec.luau:4 (distance), :18 (double), :27 (solo), :35 (swaps), :51 (drop/recovery), :70 (disconnect), :85 (once-only). These are pure accounting tests, not Studio integration tests.
2. Checks and remaining limitations
- 397 tests passed in 56 specs; full visual audit clean (Haul 1837 parts, 24 lights); fresh Rojo sourcemap and strict luau-lsp passed (existing TimedEventDirector deprecated API warning).
- Full lune run check: formatting passes, Selene blocked fetching Roblox API dump. Tests lint also cannot complete in this environment. Full gate is not green.
- Studio lists zero instances: start_stop_play, get_console_output and screen_capture unavailable. No live claims. Blueprint URL was inaccessible; this audit uses the user's ten explicit requirements. No visual fix, so Blender/web visual work was unnecessary. No scratch files or downloads created.
- Final speeds, studs/sec: walk 30; sprint 31; duo 25.5; solo 19.5. Chase envelope over D=0..1 and +/-6% pace: Stalker 20.68..27.56; Crawler 22.748..30.316; Brute 20.2664..27.0088; scripted tutorial Crawler 12.5114..16.6738 (0.55 multiplier; envelope, not a claim all difficulties occur in its stop).
- Duo exceeds the global slowest regular chase by 5.2336, but cannot hold every Brute: fastest Brute closes by 1.5088 (Stalker up to 2.06, Crawler 4.816). Solo is below all regular monsters (minimum margin 0.7664), but outruns tutorial Crawler by 2.8262..6.9886. Existing HollowSpeed spec compares duo to the global minimum, not every Brute; passing it does not prove the stronger guarantee.
3. Next logical step
- Recommend accepting the scripted Crawler as a tutorial-only exception: it intentionally teaches a visible, nonlethal grab; adding 10 percentage points to its multiplier still leaves its minimum 14.7862 below solo 19.5. Monster tuning was left untouched.
- Two-client Studio checklist: stop/restart after Rojo sync; check crate at rear and E strongbox; verify 25.5/19.5, blocked sprint/drop and duo tonic; circle then approach, drop/recover, swap and disconnect; compare six versus twelve valuables with one ticket/supply bundle; check both lamp colors, restoration, faint glow and camera clearance; recover loose valuables at the same station; test Terminus lid/tally/persistence, then failure and immediate M1; inspect server/client Output.

## 2026-10-18: PHYSICAL HAUL + PAYROLL (claude/last-train-out)
1. Features completed
- Station-back sovereigns, silver watches and share certificates occupy inventory slots. E deposits them in a new locked stores-car strongbox; physical stacks/glints show the haul. Existing chest retained.
- One square wax-sealed payroll crate uses the existing back-of-station payroll location: six valuables versus three loose valuables, one burnt railway ticket, scrap and tonic; no coal. Delivery at the marked stores-car spot reveals contents. Unclaimed tonic bottles remain available in separate slots; the ticket is represented physically.
- Server-owned carrier membership (maximum two), per-carrier distance and record-low approach distance survive drops, recoveries, swaps and disconnects. Only simultaneous duo progress counts; >=60% of initial pickup-to-delivery distance doubles valuables, never supplies/trophy. Circling and solo approach cannot build duo credit. Movement budget rejects implausible crate jumps.
- Carrying blocks sprint and inventory drops; only duos may use consumables. Lamps transfer to crate sides and restore on release/delivery; both lens colours remain, one blended 360-degree pool uses range 30 solo / 45 duo (+50% constant), and a dropped crate glows faintly. Grab-dropped valuables use existing station-owned pickups, so they cannot follow to another station.
- Terminus opens the strongbox, tallies the ledger and adds haul XP to existing Crew Rank. Failure discards the haul and shows only lost valuables, with a 0.45-second stamp; M1 dismisses stamp and report together. Earned permanent progress is retained. No new currency, Robux connection, wheel or daily reward; the previous daily payout bonus is disabled.
- Persistent non-spendable placeholders in profile.stats: payrollTickets (keepsake/trophy), payrollOutfitProgress, payrollCrewPassProgress, recoveredValuables. These survive profile reconciliation; actual outfit-piece/pin awards and Crew Pass presentation are not implemented.
- LORE.md records primary-source checks for the specific coins, watch, certificate, cardboard ticket and sealed box used. Colours of fictional fittings are explicitly artistic choices. Blender blockout source: tools/haul/blockout.py; no uploaded assets or temporary outputs.

2. Balance, checks and limitations
- Approved base walking change: 20 -> 30 studs/sec (+10). Duo penalty 15% -> 5% (-10 percentage points); solo 35% -> 40% (+5). Sprint stays 31. Footstep stride 5.6 -> 6.2 preserves distinct walking/sprint cadence at the higher walk speed. Monster/lobby/NPC code untouched; HollowSpeed.spec changed with explicit approval.

| Movement | Minimum | Maximum (studs/sec) |
|---|---:|---:|
| Walk / sprint | 30 | 31 |
| Duo / solo carrier | 28.5 | 18 |
| Stalker chase, difficulty endpoints and +/-6% pace | 20.68 | 27.56 |
| Crawler chase | 22.748 | 30.316 |
| Brute chase | 20.2664 | 27.0088 |
| Scripted tutorial Crawler (0.55 chase multiplier) | 12.5114 | 16.6738 |

- Regular monsters satisfy the requested balance: duo holds distance against the slowest even at maximum difficulty/pace; solo cannot outrun any regular monster. **Exception: the deliberately slowed tutorial Crawler is slower than solo.** A single global walk speed and allowed penalties cannot satisfy both that tutorial minimum and the regular Brute maximum. Resolving it needs a separately approved tutorial/monster rule; its tuning was not changed.
- 397 Lune tests passed (56 spec files), including threshold/circling, solo, drops/recovery, carrier swaps, disconnect handoff, exactly-once delivery, inventory slots and regular monster speed comparisons. Full headless visual audit passed; final Haul target: 1837 parts, 24 lights, no z-fights/clashes. Blender blockout passed. Strict luau-lsp passed with the existing TimedEventDirector GetRankInGroupAsync deprecation warning.
- `lune run check` stops at Selene: "error when getting API dump" while collecting Roblox standard library. This is not Windows Application Control: `rojo sourcemap` succeeds. Remaining checks ran separately; full gate is not green.
- No Studio instance connected: live playtest, console inspection and rendered UI/lamp verification were unavailable. Crates left undelivered are discarded with their station; collapsed station pickups are lost. MAP.md's pre-existing changes excluded from this task commit.

3. Next logical step
- Connect Rojo and run Studio with two clients: find the back crate, compare solo/duo movement and consume/drop restrictions, circle then approach, swap carriers, disconnect one, drop/recover, and deliver. Check both lamp colours, restoration and view clearance; collect several crates while leaving tonic unclaimed. Trigger a grab and recover valuables at that same station. Test Terminus rank/stat persistence, then failure and immediate M1 dismissal; inspect server/client consoles. Resolve the tutorial-speed exception and rerun the full check when Selene can fetch its API dump.

## 2026-10-17: AUDIO + THRESHOLD PASS (Prompt 7, branch claude/last-train-out)
Monster, lobby and NPC files untouched; footsteps and breathing unchanged (only their mix group, task 4).
Rojo: the plugin failed only because no `rojo serve` was running; started it and accepted the sync. No WDAC block.
1. Features completed
- T1 relief: `Logic/Threshold` (+ spec) and `Controllers/ThresholdController` check the local character against the
  carriage/cab boxes (TrainService publishes `ReplicatedStorage.TrainVolumes`, the same boxes as `IsInside`), with a
  0.6-stud sill margin. AudioController: outdoor cues sit in an `Outdoor` SoundGroup (inside `Ambience`) whose
  `Walls` EQ (mids -10 dB, highs -30 dB) shuts within 0.08 s of stepping aboard; the outside beds dip 45% and the hall
  room tone rises. Studio: walls read -30 dB on the first sample after stepping in; stepping out they open over ~1.2 s.
  Frost on the windows: skipped (would mean per-window parts or decals across the consist for a cosmetic).
- T2 station crossfade: the station's cold grade (AtmosphereController) now follows `ThresholdController.Out()`,
  a 1.2 s eased crossfade off the train and 0.9 s back (was a spatial 8-stud ramp); brightness and exposure are not
  touched, controls never blocked. `DoorThud` (ProSoundEffects "Door Bang Rattle 8", 9114129572, pitch 0.78, highs
  -32 dB) plays on each crossing during a run, not on teleports. Studio: tint R 0.999 -> 0.844 in ~1.5 s, back in ~1.3 s.
- T3 station drone: `Drone` is now ProSoundEffects "Hollow Rumble 1" (9112795295), measured in Studio with an
  AudioAnalyzer at 86% of its energy in 60-120 Hz and 6% below 60; `DroneHarmonic` is the same take at 4x (77% in
  250-500 Hz) so small speakers hear it. No sub boost (EQ low 0). Level follows danger = max(hazard intensity, Hollow
  nearness), rising with a 0.6 s half-life and ebbing with 3.5 s; volume sways on 9.5 s / 6.3 s cycles and pitch drifts
  +-1.2% over 17 s, the harmonic locked to the body. Studio at stop 2: calm body 0.13 / harmonic 0.06; a Hollow at
  15 studs took it to ~0.37 / 0.10 within 2 s; after it left it eased back to ~0.18 / 0.06 over ~12 s.
- T4 mixing: main `LastTrainOut` holds `Ambience` (> `Outdoor`), `Cues` (Alarm/Surge, Heartbeat, Hollow spawn,
  strike, scream, wake, swipe, slam, scrabble) and `Steps` (every footstep cue, HollowStep); `Warnings` stays beside
  main. Three sidechain CompressorSoundEffects on `Ambience` (`DuckCues`, `DuckWarnings`: -30 dB, 8:1, 0.5 s release;
  `DuckSteps`: -26 dB, 2.5:1, 0.18 s) so the drone and beds make way. Footstep and breath sounds themselves unchanged.
  Studio: tree and sidechains verified; the duck depth itself cannot be measured (legacy Sounds are not analysable).
- T5 settings: new "DRONE & AMBIENCE" row (Full / Half / Low / Off = Ambience group 1 / 0.6 / 0.3 / 0; warnings, cues,
  footsteps outside it), saved through the existing SetSetting path (`Config/Settings` Choices/Defaults). The
  Visibility ("LANTERN") slider already existed (UI/LanternSlider, Prompt 6 part 2) and keeps its 18..30 range and
  its floor; its default is now `Tuning.Visibility.Default = 30` (was 18, the darkest end): the top of the
  measured-safe range, nearest the 31-stud reaction rule, under the 38-stud mood ceiling. Graphics, Broken Thing
  Markers and HUD rows unchanged. Studio: Off -> 0, Half -> 0.6, a bad value rejected; button click works; layout
  checked at half scale. Saving across sessions not testable in Studio (DataStore 403); same path as the other rows.
- T6 UI sounds: every `Ui.button` press plays `MenuClick`; a vote landing (`TicketStamp`, RouteVote) is a heavy paper
  rustle layered with a brass click (new cue field `with`); the ticket stamp (`TicketPunch`, run card, unseal, route
  chosen) is a wooden thud. Config only for the tickets: RouteVote/RunCard untouched. Studio: all ids load; a menu
  press played MenuClick; a Junction vote played TicketStamp + BrassClick together, then TicketPunch.
  Audio to audition (all free Creator Store, ProSoundEffects = Roblox-licensed; store page
  https://create.roblox.com/store/asset/<id>):
  | Cue | Id | Source | Settings |
  |---|---|---|---|
  | MenuClick | 9120300134 | "Typewriter Key 2 (SFX)" / ProSoundEffects | vol 0.3, pitch 0.9, cut 0.25 s |
  | TicketStamp | 9125725195 | "Paper Tear Heavy Paper Bag Slow Rustle 5 (SFX)" / ProSoundEffects | vol 0.45, cut 0.7 s |
  | BrassClick | 9117028601 | "Moviola Toggle Switch Single Clicks Sharp 6 (SFX)" / ProSoundEffects | vol 0.35, pitch 0.85 |
  | TicketPunch | 9119909448 | "Table Hit Hand Smacks On Wood Table 14 (SFX)" / ProSoundEffects | vol 0.6, pitch 0.8, lows +4 |
  | DoorThud | 9114129572 | "Door Bang Rattle 8 (SFX)" / ProSoundEffects | vol 0.5, pitch 0.78, highs -32 |
  | Drone / DroneHarmonic | 9112795295 | "Hollow Rumble 1 (SFX)" / ProSoundEffects | 0.42 at 1x / 0.14 at 4x |
  Alternatives found: brass 9125921369 (seat-belt latch), thud 9114129501 (Door Bang Rattle 7), drone 9112795571
  (Hollow Rumble 2: 39% under 60 Hz, rejected), rustle 125259363733255 (ballersman155, origin unverified).
2. Known bugs / not verified
- Nothing heard by ear (MCP cannot hear audio): levels, duck depth and the UI sounds need an ear in Studio.
- The Visibility default moved 18 -> 30; old saves that already stored "18" keep 18 (game unpublished, so none real).
- Studio's own warnings remain (EditableMesh/Image access, DataStore 403, UIBlox FoundationProvider, asset 203785492).
- Window frost skipped (cost); MAP.md has an uncommitted edit from before this session, left alone.
3. Next logical step
- Audition in Studio with headphones and a phone speaker: skip to a stop, walk in and out of a door, let a Hollow
  close in, open Settings and try the Ambience row; swap any id in `Config/Audio` that does not fit.

## 2026-10-17: VISIBILITY PART 3: SURFACE FIX + RE-PROOF AT 45% (branch claude/last-train-out), STOPPED: GATES FAIL
No Studio session. All gate numbers are headless Blender renders (`tools/visibility`, approximations in its README,
items 11-16 new); the luminance floors are Lune logic. Monster, NPC, lobby files and MAP.md untouched. No
`Tuning.Visibility` number changed. A stale Codex worktree (.codex/worktrees/7b23, detached at 4cfc05b, uncommitted
since 2026-10-03) also edits StationBuilder/TrainBuilder/TrainService: the train fix lives in `Builders/Limewash`.
1. Features completed
- 8c7161a Task 1: `tools/visibility/classify.py` sorts objects mechanically (Tier A hazards near their lip, Tier B
  obstacles incl. the train side, Tier C counted) -> `tiers.json`; `offenders.py` -> `docs/visibility/offenders_45.md`.
- 509047e coping: fresh whitewash (250,250,244), 2.35 studs wide (inner half clears the train's overhang), the old
  yellow strip repainted as a dark blue-brick margin. `Config/Surfaces`, `Logic/Luminance`, `tests/Surfaces.spec`.
- 641d2b9 obstacles: `Builders/Limewash.station` (called by StationBuilder): hand-varied lime-washed bands low on
  crates, barrels, churns, benches, lamps, planters, carts, stalls, trunks...; grime per grade held above MinPale.
  About 230 non-colliding parts per station; audit clean (each band avoids its siblings' planes).
- 57b4c5c train side: `Limewash.train` (called by TrainService, audit, exporter): pale foot and waist lining, polished
  brass; 12 parts, one train build for both tiers (there is no separate Performance train).
- e8099d2 lanterns: `Cosmetics.LanternMinLuminance` (lens 0.50, light 0.30); Ember hot-orange glass over a red pool,
  Signal glass lit, Aurora violet -> lavender; `tests/LanternLuminance.spec` loops every lantern; slider fairness test.
- a241311 Task 4 evidence: `gates_45_fix1.md`, `gates_25_fix1.md`, `sheet_r18_45_fix1.jpg`, `offenders_45_fix1.md`.
2. Gate results (45%, flare 1%) and known gaps
- Crew PASSES everywhere: min 3.84:1 (Ember worst case; was 1.16-1.56).
- Must-see FAILS: 12 of 108 gate shots pass (Minehead, 2 views per state). Coping 2.65-3.22:1 (was 1.66-2.46; calm passes at Halt and
  Minehead). Train side (now judged as one object) 1.15-2.30 (was 1.08-1.68). Container_10 (Halt), lamp posts and
  plinth (Market), canopy column (Halt) also under. Other falloff curve: same picture (coping 2.74-4.16).
- Surface limit: 45 of 81 failing readings stay under 3:1 even if that object were painted pure white (or black):
  the chase's ambient minimum, not paint, is the ceiling at the floor's distance (the lantern is zero at its Range).
- Mood ceiling PASSES: APL <= 0.034 vs 0.059, lit <= 0.004 vs 0.083; holds up to a 38-stud floor.
- Beyond the pool (report only): 3.0% of Tier A/B readings past 2x the floor read at 3:1 (early 6.8%).
- Monster stand-in at 18 studs: 1.02-1.34:1. Hollow silhouettes vanish at the pool edge too (report only).
- Performance cone 26 < 31-stud sprint reaction distance (Quality 34 clears it): a Tuning decision, not made.
3. Next logical step (owner's call; nothing below is done)
- Decide the light side: raise the chase ambient minimum (`Tuning.Visibility.Chase`/floor), or accept the measured
  shortfall at the floor's distance; or move the gate's "at the floor" band inside the lantern's reach.
- Surfaces still in reach (limit > 3): taller bands on canopy columns and lamp posts, Container_10's body.
- Performance cone: 26 -> 31 studs (~1.4x the cone's lit area, no shadow) or accept 0.84 s of reaction.
- Slider stays 18..30 (no lower floor passes; mood allows 38): "Dread" shares the end with "Steady", a design question.
- Studio playtest (checklist in the report).

## 2026-10-17: VISIBILITY PART 2: DIM-SCREEN PROOF + SLIDER (branch claude/last-train-out), STOPPED FOR A GO
No Studio session. Everything below comes from headless Blender renders (`tools/visibility`, approximations listed in
its README) or Lune logic, not in-engine. Monster, NPC and lobby files untouched. Tuning.Visibility unchanged.
1. Features completed
- d824c59 harness: `lune run visibility` exports real Halt/Market/Minehead stops + the docked train, grades, sky
  (compose/chase/floor) per radius; `tools/visibility/render.py` (Blender, StationKit.blend meshes), `measure.py`
  (exposure, grades, dread vignette, rims, dim x0.45 / x0.25), `sheet.py`, `refs.py`; every threshold in
  `thresholds.py`. Evidence: `docs/visibility/sheet_r18_45.jpg`, `gates_45.md`, `gates_25.md`, `refs.json`.
- 7e417d8 slider: `UI/LanternSlider` (brass wick winder, Dread / Steady / Clear, no numbers, local fading ring),
  mounted once in `UI/Settings`; `Visibility` saved as a whole-number string, clamped on load and on the server
  (`Logic/Settings.clamp`, `Config/Settings.Ranges`); `tests/VisibilitySetting.spec.luau` (clamp, default, round
  trip, floor in chase, visual-only scan). Range is Tuning's existing 18..30 (unchanged). `lune run check` green.
2. Gate results at 18 studs, 45% brightness (flare 1%)
- Must-see FAILS in every station and every state, calm included: weakest object at the floor 1.00-1.13:1, coping
  1.66-2.08:1 (need 3:1); only 6-10 of 36-54 targets per state pass. Dark props and the train side sit on dark
  ground. A what-if with lantern Range = floor x 1.6 barely moves it: light is not the fix, edge contrast is.
- Crew: Brakeman lanterns 3.3-7.5:1 PASS; the Ember (crimson) cosmetic 1.1-1.3:1 FAILS; silhouettes ~1.0-1.2.
- Mood ceiling PASSES easily: APL <= 0.038 vs 0.059 ceiling (Outlast/Darkwood/Alan Wake upper quartile; lobby
  "Walmart" 0.092), lit share <= 0.003 vs 0.083, up to a 38-stud floor.
- Reaction distance (slider minimum): sprint 31 x (0.75 Green 2000 + 0.10 stop + 0.15 latency) = 31 studs. 18 does
  not clear it all round; the forward cone does on Quality (34) but not Performance (26).
3. Next logical step (needs the owner's go; none of it is done)
- Edge contrast without lifting ambient: extend the rim Highlights (or limewash/edge paint) to obstacles and the
  coping inside the floor; give the Ember lantern a brighter glass/glow floor; raise ConeRangePerformance to >= 31.
- Decide the slider minimum: the reaction rule puts it above the default (31 > 18), which would change the default.
  Until then the slider runs 18..30 and "Dread" shares the Steady end. Then Studio playtest (checklist in report).

## 2026-10-17: VISIBILITY + CHASE LIGHTING PASS (Prompt 6, branch claude/last-train-out)
Monster, lobby and NPC files untouched (another agent owns them). Studio was not running, so nothing was play-tested in
Studio; looks were judged in `lune run preview` + `tools/preview/render.mjs`, dimmed to 45% brightness, at half scale.
1. Features completed
- T1 readability floor: `Tuning.Visibility` (Radius 18 studs all round, ambient/outdoor floors, exposure floor 0.26 (raised in T6),
  Atmosphere density cap 0.62) and pure `Logic/Visibility` (+ spec). `Sky.floor` clamps the drawn sky last every frame
  (AtmosphereController; the departure fog is capped too). The lobby keeps its own look. The normal night already sits
  above the floor; it bites in tunnels, the fog bank and the chase. `lune run preview ... --floor=0` shows the sky without it.
- T2 lantern: one PointLight per lantern (was two), reach `Tuning.Visibility.Radius` for every cosmetic; a look's
  glow (>= 1) only brightens it, CosmeticMotion still flickers brightness only. New `Controllers/VisibilityController`
  (after AtmosphereController in ORDER) keeps every crew lantern on the floor's radius and gives the local player a
  forward SpotLight cone (`CarriedLantern.Cone*`, 34 studs, 62 deg) in their lantern's colour; no cone in the lobby.
  rbxmap index refreshed (CLI) after T8.
- T3 rim + edges: a fixed pool of 8 Highlights (4 under Performance; `Tuning.Visibility.Rim`) outlines the
  nearest canopy, gate piers, chimneys, elms, statues, obelisks, fountains, notice boards and station buildings within
  90 studs in moonlight blue (outline 0.55, fill 0.94), re-chosen every 0.75 s; Adornee changes only when the pick does.
  Canopy column feet and gate-pier plinths now lime-washed Plaster (`C.limewash`); platform coping whitewashed
  (226,226,218). Colour/material only, no new parts. LORE.md notes the period evidence (fog whitening, pre-1914 at best).
- T4 return beacon: a billboard over the train's roof (`Tuning.Visibility.Beacon`): three soft amber rings, 84 px on
  screen, AlwaysOnTop, LightInfluence 0, no light. Shown only while docked (Dwell, LastCall, Departure), outside the
  lobby; it fades from full at 90 studs to gone at 40 so it never dazzles near the train. Performance: inner ring only.
- T5 station grade: `Tuning.Visibility.Grades` gives every archetype its own cold tint and extra desaturation
  (cyan for Halt/SignalWorks/Viaduct/Infirmary, olive-grey for CoalYard/Market/RailwayHotel/EmergencyVillage, a mild
  dawn grade at the Terminus; sealed Mystery uses Default). AtmosphereController weighs it in over the first 8 studs
  past the platform edge (`GradeRamp`), so aboard the train and in the lobby the warm amber is untouched; the floor
  still clamps it. Preview: `lune run preview <biome> out.json --grade=CoalYard`.
- T6 chase (the only chase effect; Prompt 2's item 5 had been deferred, so no older cue existed to remove):
  `Logic/Visibility.chaseStep/chaseLook` (+ specs), `Tuning.Visibility.Chase`. VisibilityController reads the Hollows'
  replicated `State` (Hunt/Windup/Grab/Recover) and calls it a chase when that Hollow is within 60 studs and you are
  its nearest crew member, or a grab is on you; no monster file touched. Onset: a 0.36 s black flicker (ScreenGui),
  then the dark stays: `Sky.chase` halves ambient/outdoor, Brightness x0.6, exposure -0.18, all before the floor; the
  station's lights x0.65 brightness and x1.15 range (building lamps through `LightScale`, a 2-line change in
  BuildingVisuals); lanterns keep brightness and reach x1.15; the dread vignette drops to 8%. Escaped 4 s: snap
  back with +0.1 exposure relief that eases away over 10 s. Caught again before the relief: no second flicker. Floor
  retuned after a dimmed chase preview: ambient (54,58,66), outdoor (88,96,110), exposure 0.26.
  Preview: `--chase=1`, `--relief=1`.
- T7 performance (`Tuning.Visibility.Budget`): one light per player (the lantern; the cone is local to its bearer),
  lantern shadows forced off, one shadow-casting light at most (your own cone, Quality only). Performance: no
  shadows, cone 26 studs (still above the floor), 4 rims, a one-ring beacon, crewmates' lanterns beyond 90 studs
  switched off locally. No new light is ever created per frame; the chase only rescales existing station lights
  when its dim changes.
- T8 slider hook: the floor is one value, `Tuning.Visibility.Radius` (18), overridden per player by the attribute
  `Tuning.Visibility.Setting` ("Visibility", studs, clamped 18..30 by `Visibility.radius`). `VisibilityController.Radius()`
  reads it and `SetRadius(studs?)` writes it; lantern reach, the cone's least reach and the sky's ambient floors
  (`Visibility.scale`, up to +35% at 30) all follow. Not persisted yet: the Settings slider/SettingsService save is the
  later task (Settings choices are strings today, so it needs a numeric setting).
2. Known bugs/regressions
- Not verified in Studio (Studio closed). Density cap 0.62 thins the station fog bank a little.
- Coloured lanterns (Signal green, Ember crimson) light the same reach but read darker than amber.
- Rim, limewash and coping not seen in Studio; there is no headless station renderer to preview them.
- Beacon is AlwaysOnTop by design (seen through buildings); if it reads as UI, set AlwaysOnTop false in VisibilityController.
- Chase detection approximates the Hollow's target (nearest crew member); two crew equally close may both or neither get it.
3. Next logical step
- Owner: play a stop at low screen brightness (lantern pool + cone, rims, beacon, limewash/coping), then trigger a
  chase (dev console Hollow spawn) and escape it; tune `Tuning.Visibility` / `.Chase`. Then add the Settings
  "Visibility" slider calling `VisibilityController.SetRadius` and persisting it.

## 2026-10-15: Prompt 5 lobby shell (codex/lobby-shell-prompt5)
- Completed: revised PROMPT5.md; checked the materials/furniture used against museum and heritage sources in LORE.md (clothing unchanged, not globally verified). Added English-bond wear maps, bottle-green/cream dado, warm stone flags, mahogany benches/frames, plaster panels, trim and wordless crests. Reused Blender fluted shafts/capitals and curved bentwood chair backs; Performance restores simple server parts. Large mastery text explains XP/rank, lifetime records and milestones; departure layout unchanged. Lobby signage uses Oswald/Merriweather; shared HUD/Settings untouched.
- Lighting protected against pre-task 011bf55: reverted the earlier mastery LightInfluence edit to 0.85. Instantiated comparison found all 70 lights (including display train), their parent fixture properties, and 51 Seat transforms identical. Sky, AtmosphereController, project configuration, roof/trusses and existing lamp colour constants unchanged. The active hall audit still counts 47 lights; source colours/materials change surface appearance only.
- Orange-object review: slatted bench timber is now mahogany. Orange luminous objects are existing pendants, lanterns, kiosk/board lamps, stove glow and piano candles; retained under the owner's stronger instruction to leave lighting/fixtures unchanged. Existing marble tea tables, cast-iron bench ends, brackets, skirting, NPCs, piano, emblem, red walk, windows and storm retained.
- Checks: full gate passed (361 tests, 49 specs; strict types, lint, formatting and all visual audits). Lobby: 2,442 server parts (+17), no z-fights/clashes. Studio stop/start and console checked on lobby studio f238ea4f; no LobbyShell errors, existing TrainVisuals fixed-size EditableMesh warning remains. Spawn/ready captures reviewed at half scale; mastery readable nearby. Performance switched and Quality restored. EditableMesh/image API failures have per-asset fallbacks; unsupported devices were not available to test.
- Studio now uses this checkout's dedicated Rojo server on 34875; other servers untouched. Next: owner visual review, then confirm Claude is finished before merging into claude/last-train-out. Do not merge without that confirmation.

## 2026-10-15: ASTRA RESUME + BOTH BRANCHES MERGED
- Finished the pending movement task in dc0705d: eased waking transitions, smoothed gait/cadence and subtle continuous twitches. Earlier tall/crawler/progression commits retained; third monster design unchanged. Pushed codex/hollow-design.
- Claude's lobby worktree was stable across two status/mtime checks over 20 seconds apart. Reviewed and committed his remaining lobby stamina, candle and bare noticeboard edits as 660290c, then pushed claude/lobby-npc-pass (including its prior unpushed storm fix).
- Integration: 022162b merged Hollow work; bdafb78f2e93ae686a841b059836f899c7008e70 merged the lobby pass into claude/last-train-out. Both are normal --no-ff merges. This documentation commit follows that final integration hash; use git rev-parse HEAD for the branch's final documentation-inclusive hash.
- Preservation: all three original tips are ancestors. Parent comparisons verified all files changed on only one side exactly (46 in the first merge, 26 in the second). Shared files: HANDOFF kept both note sets (the sole conflict); LORE kept both source corrections; Tuning kept Hollow motion/progression and lobby/lantern constants. Lobby/NPC/cosmetics retained; both settings files unchanged. Pre-existing unstaged MAP.md left byte-for-byte untouched.
- Checks: own branch full gate passed. Merged gate passed formatting, lint, fresh Rojo sourcemap, strict types and 361 tests / 49 spec files. Audit has exactly one existing failure: Lobby lights 49 > 48. Preserved Claude's candle light; no budget increase. Windows Application Control did not block this run.
- No Studio opened, connected or changed. Movement, merged lobby storm/audio and integration still require manual Studio verification. Earlier photo-rig progression comparison at stops 1/3/6/10 is recorded below; runtime movement has not been validated here.
- Backups retained: backup/pre-lobby-merge-2026-10-15-{hollow,lobby,main}, respectively dc0705d30e4c4d0fbdb24939f45dae6f0f5162ea, 660290cb8493c16edde9a2dd296f9c9194a0271c, 1129148fab6cc4c29f2648298bc47139c2d7af6e. LTO-lobby and its Rojo 34874 remain intact.
- Merged source folder: C:/Users/tameg/Documents/Roblox/my-roblox-game; serve with rojo serve --port 34872. Existing Rojo listeners 34872/34873/34874 were left running.
- Cleanup: removed only our motion-check.log, astra-lobby-check.log, astra-merged-check.log and temporary monster-progression.png contact sheet; reusable photo tools and individual design renders retained.
- Next: manually verify movement and lobby integration, resolve the one-light budget overage and Mabel period-role question with the owner. Prompt 3 tasks 5-8 (obstacle pursuit, guaranteed encounters, sound foreshadowing and per-run variation) remain outstanding; this resume finished task 4 rather than starting them.

## 2026-10-15: LOBBY + NPC PASS, REVISION (items 4 and 8 rewritten, LORE spot-check)
`lune run check`: format, lint, types and 360 specs pass; the audit fails only on Lobby lights 49 > 48, caused by the
owner's uncommitted candle firelight in LobbyBuilder (left as is; the owner decides: drop one light or raise the budget).
1. Features completed
- Item 4: the carried lantern's gameplay light is one shared constant, `Tuning.CarriedLantern` (LightRange 16, the
  original reach; LightBrightness 0.55), the same for every cosmetic. A look's `glow` now only brightens the close
  pool (CoreRange 6). Cosmetics change colour, glow style and flicker only. Verified in play: lights r6 and r16.
- Item 8 (Controllers/LobbyStorm, owner's wide cloud deck and no horizon band kept): natural silhouettes only, no
  buildings: eight mountain peaks, eleven hills on one dark ground, nine bare trees, 500 studs either way; a distant
  veiled moon; churning black cloud (smoke particles in two layers, lit by the flash); heavier rain (320/s per window);
  the interior flash cut to 1.8 x amount over 34 studs so the hall stays amber; resting sky lightened (58,62,84) so the
  silhouettes read. Once per session at a random time (60-480 s) one strike shows 1-2 TallOnes on the hill line out
  beyond a window, drawn from the sky's own shape (`Heavens.TallOneShape`, new export); they never move and vanish
  with the light. Studio-only hook: player attribute `DevStormGlimpse` calls it on the next strike. Verified: glimpse
  seen through a window, nothing shown again in the next 35 s, 13 flickers, no errors. Performance: no rain, bolt or
  flash lights; thinner churn.
- Guard re-dressed from the sources: `StaffFrock` cut (double-breasted frock coat buttoned to the neck) and a
  patent-leather shoulder belt with pouch (`belt`), peaked cap.
- LORE.md spot-checked against web sources (listed there): guard's uniform, women's railway work (no women booking
  clerks before 1915, so Mabel is flagged), bustle/sleeve dates, service dress, Edmondson tickets, bookstalls, piano
  sconces, and a caution that green engines with chocolate-and-cream coaches is the GWR livery.
- Owner's manual changes noticed and left untouched: commits 806b57d and f2aa492 (town/church skyline and horizon
  band removed, wider cloud deck, booth set into the back wall with the clerk moved in, lamp standards replacing all
  sconces, touch-to-sit seats with `Tuning.Lobby.SeatRetouchDelay`, piano chair back removed, outfitter posts and back
  board removed, end-wall floor gap closed, black underlay, new corner bookcase and palm); uncommitted: lobby stamina
  never drains (MovementController), the candle stand's flame, wick and firelight, the notice board left bare
  (LobbyBuilder). None of them were staged in my commits.
2. Known bugs/regressions
- Lobby audit over its light budget by one (see above).
- Mabel as a woman ticket clerk is an anachronism for 1884-92 (LORE.md 6); her role is unchanged pending the owner.
- The new thunder/rain sounds still not auditioned by ear.
3. Next logical step
- Owner: decide the light budget and Mabel's role, then merge after Claude Code is finished.

## 2026-10-15: LOBBY + NPC PASS (branch claude/lobby-npc-pass, own worktree ../LTO-lobby, Rojo 34874, ../lobby.rbxl)
Not merged into claude/last-train-out yet (owner merges after Claude Code's HUD/train/station work is done).
1. Features completed
- T1 solo ready: already fixed server-side (one Ready starts the Countdown, `LobbyService.TakeCrew` takes only readied
  players). Removed "everyone in the hall boards"; the Countdown line reads "N ready to depart". Play-tested solo.
- T2 ready button (UI/Lobby): flat brass face with a 5 px darker brass lip on the bottom and right; hover sinks it
  halfway, mouse-down pushes it flush. Signal lamps (the green circle) removed; status and detail lines moved down
  into the gap.
- T3 outfitter: OUTFITTER shortcut button gone (the stand's prompt opens it); LINE MASTERY stays. Kiosk back wall
  lowered from 9 to 4.4 studs (counter height), swatches moved onto it, two slim rear posts carry the awning.
- T4 cosmetics: Ember crimson (196,22,40 glass), Signal a deep signal green, Founder's gilt body and gold light,
  Curio warmer and brighter, Aurora more saturated teal/violet (cycle kept); optional `look.glow` multiplier.
  Every lantern now lights with two PointLights (strong range 6 + soft range 18) so it is brightest at the lamp.
  Trails 9-11 particles/s per foot (was 4-6), slightly larger, steam/mist a bit denser. Checked in Studio per lantern.
- T5 piano (LobbyBuilder): rebuilt at x=0 under the departure board: toe plinth, panelled knee board, turned
  consoles, cheek blocks, 52 white/36 black keys, fallboard up, music desk with open music, red silk behind fretwork,
  brass sconces with candles, photo and music books on the lid, brass pedals. Buttoned velvet piano chair with turned
  legs, H-stretcher, balloon back. Candle stand at its left (+x, the bass end): round base, slim turned post ~4.3 tall,
  small round top, one lit candle (neon flame only; the hall is at its 48-light audit budget).
- T6 lighting: the two back-wall lamps nearest the piano (x=+-30) replaced by gas lamp standards at x=+-24, z=66
  (plinth, fluted cast-iron shaft, ladder bar, square glazed amber lantern, gabled cap). Truss pendants now amber
  globes (236,150,72) with warmer light (255,178,98, brightness 1). Lights stay at 48/48.
- T7 floor emblem: green rosette and its axe-and-cross bars replaced by a wordless roundel: slate field in a brass
  ring, brass rails and closing-up sleepers running away (toward the train) into a round tunnel mouth, with the red
  tail lamp of the last train inside the bore. Layer tops at distinct heights (audit: 0 z-fights).
- T8 windows + storm: back wall now laid in courses around four real openings (x=+-66,+-90), lowered to y 10.6-20
  with the lintel under the roof spring (22); iron casement, 3x3 glazing bars, faint pane (SmoothPlastic 0.82, not
  Glass: Glass hides particles behind it), stone sill and lintel. Back area not expanded. New client controller
  `Controllers/LobbyStorm` (in init ORDER after PianoNotes) builds, outside the panes tagged StormWindow: a black
  Gothic skyline (needle-spired church, ruined chapel lancet gable, gabled houses with stacks, bare trees, hills)
  within 15-110 studs (the hall Atmosphere hazes anything further), a cloud deck and a bruised horizon band, rain
  sheets past each window, a muffled rain loop, and a strike every 7-16 s: 2-3 flickers, a forked neon bolt, four
  shadowed flash lights, thunder 0.35-2.4 s later (new cues LobbyRain 9112855439, LobbyThunder 9116282646,
  LobbyThunderFar 9113218938, all ProSoundEffects). Performance setting: no rain, no bolt, no flash lights (verified).
  New script: run rbxmap `refresh` after merging.
- T9 ticket stalls: west office (x=-36) removed. The east one (x=36) is now an open booth no wider or taller than
  the old office (16 x 11), 6.5 deep: panelled sides, turned corner posts, fascia with the TICKETS board, panelled
  counter with marble top, brass edge and grille rail, and room behind for the clerk (Edmondson card rack, date press,
  ledger, stool, oil lamp).
- T10 sittable chairs: LobbyBuilder adds unseen Seats (Kit.seat, SeatName attribute, returned as `Built.seats`) on
  every bench (3 places each), both armchairs, the settee (2), the tea-room chairs, the piano chair and the booth
  stool (34 in all); LobbyService puts a Sit prompt on each, hidden while occupied, same checks as TrainService.
  Verified in Studio: every seat seats a player; piano chair faces the keys.
- T11 posters (PosterArt, LobbyBuilder): the pale-blue regulation (COUNTED) and the notebook appeal (lost brother)
  removed. Mind the Fog untouched (same slot). Reworked: coast is now WYVERN SANDS / BY THE NIGHT EXPRESS with an
  S. & W. C. R. footer; coal is a buff letterpress bill (SEVERN & WESTERN COUNTIES RAILWAY / WANTED / STOKERS for the
  Night Services, shovel woodcut, By Order 1889); moon is NOTICE TO PASSENGERS / WHEN THE MOON IS RED. All three
  carry wear (torn corner, damp stains, soot at the foot). Layout: coast + fog west, stokers + moon east.
- T12 floor boxes and life: the two luggage trolleys with their leather boxes removed. Added glazed-door
  bookcases of cloth-bound books under the windows at x=-90, 66 and 90, a railway bookstall (BOOKS · NEWSPAPERS,
  shelves of books, a sloped counter of papers) where the west ticket office stood, and a rack of four leather fire
  buckets at x=-50. Lobby now 2048 parts (budget 3200), lights unchanged at 48.
- T13 NPCs: one reusable kit. `Config/Outfits` (pure data: Look = cut Frock/Sack/Reefer/Bodice, trousers or
  Plain/Bustle skirt, waistcoat, cravat/neckerchief, apron, hat Top/Bowler/Peaked/Lace/Bonnet/Visor, prop; Pose = lean,
  armL, armR, head) and `Builders/OutfitKit.figure` (R6-proportioned part body, dressed and posed; body/skirt collide).
  Placed by LobbyBuilder (audited, 0 z-fights): Mrs. Pell at the tea-room counter (bodice, apron, lace cap), Mr. Pyle
  in the outfitter booth (frock coat, crimson waistcoat, tailor's tape), Mr. Lethbridge the booking clerk (navy reefer,
  peaked cap, ticket punch), the Line Superintendent by the honours board (frock coat, top hat, pointer) with a speech
  card within 18 studs saying what Line Mastery is, and the Guard lying over the display train's guard's van end
  balustrade, looking down the line (no dialogue yet). Counter staff stand on a 1-stud step. New scripts: run rbxmap
  `refresh` after merging.
- T14 Mabel: dressed from the same kit (Npcs.Look is now Outfits.Look; NpcFigure is a thin wrapper over
  OutfitKit): navy bodice with brass buttons, plain navy skirt, bun, clerk's eyeshade, ticket punch. Her 15 lines
  rewritten short and plain (what to do, friendly, no puzzle talk); every line id, topic and condition kept, so
  Logic/NpcDialogue and its specs are unchanged. Seen aboard in Studio with her Talk prompt; the new lines themselves
  were not read through the dialogue UI in play (specs cover which line is picked).
2. Known bugs/regressions
- Multi-player boarding (two in the hall, one ready) checked by reading TakeCrew, not in a Local Server.
- Storm: strikes verified by sampling (flash, bolt, flash lights) and one frame on screen; the new rain/thunder ids
  (ProSoundEffects 9112855439, 9116282646) were not auditioned by ear.
- Mabel's new lines were not read through the dialogue UI in play (specs cover the picking).
- Period checklist #2: `LobbyBuilder.label` (TICKETS, BOOKS · NEWSPAPERS, OUTFITTER, DEPARTURES) still uses
  HighwayGothic; not changed here (shared helper, older than this pass).
- The display train's own seats (bunks, saloon) have no Sit prompts; only the hall's chairs were asked for.
- New scripts (Controllers/LobbyStorm, Builders/OutfitKit, Config/Outfits) are not in the rbxmap index yet.
3. Next logical step
- Owner: check Claude Code is finished, then merge claude/lobby-npc-pass into claude/last-train-out and run rbxmap refresh.

## 2026-10-15: ERRANDS, PYLONS, ARVO FONT, CAB DOOR SILLS
`lune run check` passes (360 specs). **Not play-verified:** Rojo was disconnected from the reopened Studio (Studio still ran
the older sources), and the laptop screen was covered, so the plugin could not be reconnected.
1. Features completed
- NpcService `hideItems`: errand items go only beside Far ground containers (Mid dropped; falls back to any non-Safe).
- Pylons off in every biome (`Scenery/Biomes` `pylons = false`; the code stays, flag-driven).
- Arvo: not a Roblox font (no `Enum.Font.Arvo`, no Arvo.json in Studio's fonts) — that was the "Arvo.json failed to load"
  line. Ticket, RunTicket, Stamp, Unseal heads now use Merriweather (ships with Studio). TrainInterior signs untouched.
- Last Light cab door: the leaves' teak glazing sills were baked into the static `Locomotive_FittingsP` mesh
  (engine2.py line ~615 adds them to `teak`, not the leaf), so they hung in the doorway when the doors opened.
  `TrainVisualsController.cutCabSills` cuts them from a client EditableMesh copy and rebuilds them as parts with the
  leaves' `DoorSlide`. Also on disk: `Locomotive_P_baked.blend` and `Locomotive_FittingsP.fbx` with the 24 sill tris cut.
2. Known bugs/regressions
- The cab cut needs **Game Settings > Security > Allow Mesh / Image APIs** on. Until then the client warns once
  ("EditableMesh is not accessible") and the cab looks as before. If the cut FBX is re-imported instead, the runtime cut
  finds nothing and adds no sills: then add the two sills to the leaves elsewhere (and fix engine2.py line ~615).
- Lobby departure board names (LobbyBuilder) still unchanged.
3. Next logical step
- Reconnect Rojo, enable the Security toggle, play: open the cab doors (dock) and check the sills slide with the leaves.

## 2026-10-15: PROMPT 2 PASS (stations, scenery, signs, audio; tasks 1-4, 6-12; item 5 moved to Prompt 6)
`lune run check` passes (360 specs, 49 files); `AUDIT_SEEDS=6 lune run audit Station` and `AUDIT_SEEDS=6 lune run audit Scenery` clean.
Every task play-tested in Studio (stop 1 docked, console clean apart from the existing DataStore/Arvo lines).
1. Features completed
- T1 (436bbf1): edge hazard rail, tape, red neon lip and red edge lights gone; an unseen EdgeRail stop (tagged SinkholeEdge) keeps the crew out.
- T11 (ba3c8b5): fuse boxes and their power-up removed (prompt, lamp switch-on, window glow, Breaker cue, PowerCost/Hold). `BuildingService.IsLitAt` kept (HollowService calls it), always false. Ceiling lamps stay as ambient light.
- T2/T3/T12 (012e776, tuned in 8a4ac9d): no barrier fences/wrecks/decks; tall solid cover (GatePier, Chimney, Elm) stood `Stations.Cover.Spacing` tiles apart until no yard tile is far from something; sights (Statue, Jubilee Obelisk, temperance DrinkingFountain, parish NoticeBoard with open-ended notices) max 2 each (`layout.sights`). Each piece collides only through an unseen block taller than a jump; cover tiles keep open ground all round (PathfindingService radius 2.2 checked). Gate piers flank every route where it leaves the platform. Loot by depth (`Stations.Depth`): coal bins/lumps by the platform, crates/scrap at the back, tool chests deeper, safes deepest, no ground containers in Mid. `plan.payroll` = the clear spot (middle 3 tiles of the last inner row) for the payroll crate. Specs in tests/StationLayout.
- T4 (babb820): past every sinkhole a treeline, rolling hills and a low massif (`Features.backdrop`, `Tuning.Journey.Backdrop`, `World.backdrop` keeps the land clear). **Found: the Atmosphere now fogs BillboardGuis**, so the moon/glows/TallOnes/bolts at 16000 studs were invisible; Heavens anchor now 750 studs, moon x2.6 bright. Early moon higher/larger, first night's cloud thinned.
- T6 (ef43475): `Scenery/StationSnow`: snow sheets on yard Floor slabs and pitched roof wedges at snowcap-biome stops (Minehead, Viaduct, Infirmary); none under the Performance setting (verified 0 sheets).
- T7 (ddbadff): platform clock: iron band, brass bezel, enamel dials (radial Roman IIII, minute track, S. & W. C. R., "E. Tozer, Bristol"), blued hands stopped at 9.40, crest, scrolled drop rods, pendant.
- T8 (8a4ac9d): `BuildingGen.decor` + `Builders/RoomDecor`: each stop's main building (first landmark) dressed per room on clear wall: drop-dial clock, gilt pictures, framed texts/By Order notices, unlit gas brackets, hat pegs with bowler and coat, book shelves.
- T9 (7c10539): running-in boards white Oswald on ultramarine enamel, timber frame, mustard-pot posts, soot, chips; other station lettering off modern faces (Bodoni cast-iron notice, Oswald FIRE, Garamond timetable, Fondamento notes/chalk). Station names to LORE: Ashcombe Halt, Coldharbour Siding, Culverhay, Brendon Cross, Exmoor Gate, Brannoc Road. Ashgrove Board School: date stone A.D. 1876, bell-cote; wooden cloak presses instead of steel lockers. LORE.md spot-checked, sources added.
- T10: footsteps by surface (`Logic/Footsteps` + spec, `Controllers/FootstepController`, `Tuning.Footsteps`), every crew member, spatial; heavy breathing loop while stamina is spent (verified swelling in and dying away).
  Audio to audition (all free Creator Store, loaded in Studio 2026-10-15; uploader origins NOT verified, check licensing before publishing):
  | Cue | Asset id | Store name / uploader |
  | --- | --- | --- |
  | StepPlank1 / StepTrain1 (pitch 0.8) | 136507037003210 | "Black Laboratory wood plank footstep 1" / Diman_x86 |
  | StepPlank2 / StepTrain2 (pitch 0.76) | 137526436035209 | "Black Laboratory wood footstep 5" / Diman_x86 |
  | StepGravel1 | 131788428206726 | "Black Laboratory gravel footstep 5" / Diman_x86 |
  | StepGravel2 | 132387836053582 | "Black Laboratory gravel footstep 6" / Diman_x86 |
  | StepSnow1-3 | 103816422099881, 135918121539048, 103079968724414 | "Footstep - Snow 1/2/3" / zefyras74 |
  | Breath | 100147087354736 | "shortness-of-breath" / dfddfghrty |
  Store pages: https://create.roblox.com/store/asset/<id>. Rejected: Half-Life 2 and CS:GO rips (TheAngelMGR, "Old csgo ..."). Alternatives found: gravel 9083852561 (nebulimity, a walking loop), breath 78661511671754, 134336321560595.
2. Known bugs/regressions
- Lobby files (not mine) still list "Coaling Yard", "Signal Works" (LobbyBuilder departure board); station display names changed.
- NpcService (not mine) hides errand items beside Far *or Mid* containers; Mid ground is now empty, but Mid buildings' containers still qualify. For errands strictly at the back, make its pool Far only.
- Coal bins now sit in Near, so they roll Near (1x) loot: less coal per run than before. Retune if runs starve.
- Not changed, against LORE: the Mid landscape's electric power-line pylons (checklist 1); TrainInterior's HighwayGothic signs (last pass's file); UI Arvo font fails to load in Studio.
- BrokenThingMarkers (HUD file) still looks for Power prompts; none exist now (harmless).
3. Next logical step
- Audition the footstep/breath ids by ear and swap any that do not fit; Prompt 6 (chase lighting); decide on the pylons.

## 2026-10-15: FLUID HOLLOW MOVEMENT (Astra task 4)
1. Completed: eased gait speed/cadence, smooth waking and neck transitions, smaller eased twitches and continuous cosmetic pulses. Existing monster designs preserved.
2. Verification: Full `lune run check` passed again on resume, including fresh Rojo sourcemap, strict types, tests and visual audit. No Studio opened or changed during this resume, per owner instruction. Movement feel and crawler shedding still need owner playtesting.
3. Next: tasks 5-8 (bounded obstacle pursuit, roster encounters, sound-before-sight, shared run-seeded variation) remain outstanding. Owner now authorizes merging completed work with Claude's stable lobby branch.


## 2026-10-15: EARLY MONSTER PROGRESSION (Codex task 3)
1. Completed: progression starts at 30% at stop 1 and reaches 100% at stop 10; Stalker torso/neck and Crawler spine/head contort progressively. Brute pose/model unchanged. Photo rig accepts stop number; compared stops 1/3/6/10 in Blender at half resolution, all eight poses have IK shortfall 0.
2. Verification/limits: full `lune run check` passed. Isolated Studio reached stop 1 and teleported to the station route without game-script errors; known local DataStore/font/UIBlox warnings only. The four-stop comparison is photo-rig evidence, not four live runs. Comparison saved outside repository as monster-progression.png.
3. Next: eased motion, obstacle handling, encounter opportunities and sound-led seeded variation. Do not merge until owner confirms Claude has finished.

## 2026-10-15: CRAWLER DESIGN (Codex task 2)
1. Completed: longer uneven matted hair, three hanging skin strips and three pooled local shedding flakes. No new crawler clothing/blood changes; Brute unchanged. Blender photo: 110 visible parts, IK shortfall 0.
2. Verification/limits: full `lune run check` passed. Isolated HollowDesignTest.rbxl reached stop 1; no game-script errors, Roblox UIBlox/font and local DataStore warnings. Dev crawler spawn/grab both returned false, so in-engine shedding remains unverified; photo confirms static model only.
3. Next: stronger early progression and stop 1/3/6/10 comparisons; verify shedding in a roster encounter. Do not merge until owner confirms Claude has finished.
## 2026-10-15: TALL HOLLOW DESIGN (Codex task 1)
1. Completed: gaunt long-armed Stalker, hunched face-cradling gait, dark wool-inspired ragged coat and bloody hands; 60 visible parts. Period clothing/palette sources recorded in LORE. Prompt 3 amended; reusable Blender photo rig added.
2. Verification/limits: full `lune run check` passed; Blender pose IK shortfall 0. Isolated `HollowDesignTest.rbxl` played to stop 1 and a tall Hollow was visible; no gameplay script errors, local DataStore/font warnings. Dev extra spawn returned false; controlled roster/stop comparisons remain pending.
3. Next: crawler hair/shedding flesh, then progression, motion and encounters. Branch codex/hollow-design; do not merge until owner confirms Claude is finished.

## 2026-10-14: SLIDING GRAB ZONE
`lune run check` passes (354 specs). Play-tested: `grab Stalker` at a dock, zone moves ~100 px/s, console clean.
1. Features completed
- Grab check zone (grey + white block) slides along the bar at `Difficulty.SkillCheck.ZoneDrift` = 85 deg/s, bouncing off
  the ends; odd check ids go left, even right (`SkillCheck.drift`, `zoneStartAt`; `Check.drift` rides the Fx). `judge`
  follows the moving zone (look-back window in 12 slices); `minimumSeconds` counts a full turn per check. GrabController
  redraws the zone each frame. Audit harness (`.lune/lib/HollowLifecycle`) presses on the moving zone.
2. Known bugs/regressions
- Last Light cab: the door-side grab irons (2 rods, 4 standoffs) are cut from Locomotive_FittingsP (baked .blend edited
  in place, UVs kept; re-imported as 83128914590753, bounds updated by hand in asset_ids.json and Config/TrainShell).
  engine2.py no longer makes them. Do not run gen_config.py blind: it rewrites the hand-tuned cab leaf z (6.66 -> 6.77).
3. Next logical step
- Tune ZoneDrift after real play.

## 2026-10-14: HUD, LEAKS, GRAB BAR, TRAIN INTERIOR PASS (16 tasks, one commit each, pushed)
`lune run check` passes (352 specs incl. new LeakRoute, CrewChest, SkillCheck press-time). Each task play-tested in Studio, console clean.
1. Features completed
- HUD: backpack "right-click drops" hint gone; tutorial run 1 has a "Drop" prompt on a new `Carrying` moment. Operators panel has no
  toggle/setting (key removed from Config/Settings) and no longer fades out (idle 0.2). Leak notice moved top right, riding under the
  Operators panel's live height; Settings button now 14,146 under the gauges (tutorial slot 14,196). Pocket watch 2% smaller (UIScale),
  Victorian enamel dial: railroad minute track, 12 radial Roman hours (IIII) in Bodoni (`Theme.Font.dial`), blued spade hands.
- Leaks (LeakController): small red "!" per leak (BillboardGui; aboard always, off-train within 20 studs; Last Light included);
  BrokenThingMarkers now plates only Power. Overhead arrow replaced by amber floor chevrons (`Logic/LeakRoute`, `Tuning.LeakArrows`):
  aboard down the aisle to the nearest non-cab leak, curving to its wall; on the platform while Dwell/LastCall to the Last Light door
  when the cab leaks. TrainBuilder publishes `Origin` on the Train model. "Steam leak in the Last Light car" fades at top centre when
  the cab starts leaking; leak texts call CAB "Last Light". Patch prompt: iron plate, brass rim, pressure gauge needle that climbs
  with the hold. All of it follows Broken Things Markers (verified Off hides all three).
- Grab check: horizontal bar, grey zone + centred white block (GreatShare 0.2, was 0.25). Client sends the server time at key-down
  and shows the verdict at once; server judges that instant within the ping tolerance (`SkillCheck.judgePress`). HollowService:
  only the SkillCheck handler changed (owner approved).
- Train: saloon seats lose L·T·O, benches 3.2 wide with the sitter at z 3.42 (arm clears wall: 5.42 vs 5.62). Train camera hides
  prompts (ProximityPromptService.Enabled) and in-train markers; RMB/right stick free-look on fixed shots. Last Light door leaves
  flush (TrainShell config z 6.66, were 6.77 floating). Crew chest in the stores car facing the platform door (E opens UI/CrewChest;
  flares/tonics/flashbulbs; `train.chest` in state, empties per run). Backpack 6 slots.
- Coal: `Tuning.Train.CoalGaugePerCoal = 2` (deposit only; items/stacks unchanged). Values it shifts, none retuned: BurnPerKm 2.0
  (leg cost + HUD LegCost marker), StartCoal 40, CoalMax 100 (+25/CoalBunker level), bunker spill (coalWasted), Hull
  StarvingPerSecond 3 (empty firebox now reached later), Economy BrassPerTenCoal 2 (coal brass doubles), coalDelivered stats and
  milestones, LowCoalFraction 0.25. Leak hull drain (Difficulty.Leaks) is not affected.
2. Known bugs/regressions
- RMB free-look not driven in test: MCP/computer-use mouse gives zero deltas; logic mirrors Orbit drag. Check by hand: C, F to
  Lineside, hold RMB and move. Server press-time judging verified by specs + error-free presses, not by a timed hit.
- Carriage door leaves likely float the same ~0.12 off their sides (not asked; Locomotive only fixed).
3. Next logical step
- Hand-check free-look and a few grab presses for feel; decide whether the coal doubling needs BurnPerKm/BrassPerTenCoal retuned.

## 2026-10-14: LORE BIBLE
1. Features completed: `LORE.md` at repo root (era 1884-1892, tone, vague Hollows, names, signage, clothing, props, period checklist). No game code changed.
2. Known bugs/regressions: none; existing in-game names/fonts not yet audited against LORE.md. No Blender sheet made.
3. Next logical step: audit station names, sign fonts and crew outfits against the LORE.md checklist.

## 2026-10-14: FOLLOW-UP PASS (multi-player checks, rally grace, fence mesh, sounds, initials) -- READ THIS FIRST
Shots (0.5 scale) in `docs/checks/P_*`. `lune run check` passes (343 specs).
**Methods that worked (reuse them):** read run state from any client by firing `Remotes.ClientReady` and catching one
`Remotes.Snapshot` (rate-limited: 1.5 s apart). Rally repair prompts share E with the Workbench: stand ~2.5 studs off the
wall and turn character *and* camera to the prompt, then `InputHoldBegin`/`End`. Local Server: only clients the Studio MCP
lists can be scripted (4 requested -> 1 or 3 reachable; 2 -> both); kill everyone on the Server to end a run fast. A
grab lasts ~10 s, so arm the crewmate's watcher in a `task.spawn` *before* `grab`. MCP `screen_capture` does not show
BillboardGui prompt chips; a real screenshot of the client window does. In Edit, `require` keeps modules cached from
earlier sessions (it built with the pre-f5cacd7 config): place the new mesh by hand for A/B triangle reads.
1. Features completed / verified
- **Vote card (T1a):** 3 live voters (Local Server): seal clear of title 6 px, DANGER 5, stamps frame 6, own ring 3,
  button 14, flap 15. 4 stamps (1 live + Studio-only `fakevote 1 3`, 00696c8, because the 4th client never attached to
  tools): title 3.3 px, DANGER 5, stamps 4.4, ring 1.7, button 16.5, flap 14.8 (`P_vote_three_stamps`, `P_vote_four_stamps`).
- **Pull free (T1b):** Player2 facing grabbed Player1 at 5.8 studs sees "E PULL FREE · Player1" (`P_pull_free_crewmate`);
  Player1's own prompt read disabled in all 4 grabs.
- **Rally path measured (T2, before T5):** 2 dev leaks + hull 1 on the first trip -> village (0 parts) -> halt -> rally ->
  3 repairs: hull 15.0 right after, 3 leaks open, drain 0.64 -> 0.74 %/s (rising with severity), 1% ~21 s after the last
  repair, then the second breakdown fired: **train lost**. Which breakdown goes where (code + runs): the **1st** breakdown
  of a run, at any stop, always goes to the Emergency Village (`BreakdownService.step` asks `RunDirector.BeginVillageStop`,
  refused only outside Cruise, which `step` never runs in). Village with 3 parts -> hull 40, runs on. Village short ->
  4 s halt -> **rally** (45 s, 3 repairs): done -> hull 15, limp; not done -> lost. The **2nd** breakdown, any stop, any
  path -> lost at once (no village, no rally). So the rally only ever follows a short village.
- **Repair grace (T5, f78e5f6):** `Difficulty.Breakdown.RepairGraceSeconds = 30` (+ `GraceTitle`/`GraceText`) after either
  success (shared `Logic/Breakdown`: `repair(state, now)` and `villageDone` set `graceUntil`; `inGrace`, `graceLeft`);
  `TrainService` holds leaks during it (`Ledger.drain(..., leaksHeld)`: no drain, no aging, no bursts; starving still
  drains); toast "REPAIRED / Hull holding: N s to patch the leaks". Spec `tests/RepairGrace.spec.luau`. Play: hull held
  at 15.00 for the full 30 s with 3 leaks hissing, toast counted down, no new leaks, then drain resumed; **repair -> 1%:
  ~21 s before, ~42 s after** (30 grace + ~12 at that leg's rate); left unpatched it still ends in the second breakdown.
  Alternative design not built: "close all open leaks on success" = `Registry.TrainService.ClearBreaches()` at the two
  places `BreakdownService` starts the grace (`onRepair` done branch, `VillageDone`).
- **Fence mesh (T3, 1d2eff9):** picket rebuilt in `tools/stationkit/build_kit.py` (`--only=FencePicket` exports
  `assets/stationkit/FencePicket.fbx` and updates only its JSON entry): the primitives' layout and paint (C.paint
  184,190,192; posts x0.92, rails x0.9; Wood material via the new `material` config field), nothing unseen: **122 tris**
  a tile vs 12.2 blocks = ~146 for the primitives (1559 blocks / 128 tiles at Halt). A first 158-tri cut was uploaded
  (121758508051446) and dropped: it would have drawn ~1.5k more than primitives. Uploaded id **133613114902851**; the
  other six ids unchanged. Edit, Ctrl+Shift+F2, seed 424244, from above: **Halt 232,333 mesh vs 235,151 primitives;
  Schoolhouse 283,593 vs 286,853.** Standing height at Halt reads as a picket fence (`P_fence_kit_halt`). Play: Halt
  docked with 117 fence meshes, new id, Wood, console clean.
- **Unused kit pieces (T4): none applied.** Crate 168 tris vs the loot crate's 4 blocks (48) and a decor crate's 1 block
  (12); RoofSlate 132 a bay vs 2 wedges for a whole roof; WallBrick: walls are split around generated doors/windows (no
  fixed 12x12 bay with one window) and collide, so dressing could only add parts; SignBoard is 8 wide on 5.8 posts vs the
  14-wide running-in board with its name text (a landmark). `dress()` keeps primitives for collision, so no piece can cut
  parts without changing that. Noticed: each running-in Sign's two ball finials cost 2 x 432 tris (a primitive fix like
  the iron railings' caps; not done, not asked).
- **Sounds (T6):** Dev `sound hiss|creak|alarm` (e9bfa44, Studio only): hiss = a real leak (shapeLeak, follows markers)
  6 studs ahead for 30 s, walk away to hear the falloff; creak/alarm = HullController's own Emergency-tier calls.
  Method: PlaybackLoudness **ignores Volume** (A/B on one Sound: 25-28 at volume 1, 0.5, 0.25 and 0), so level =
  PlaybackLoudness x Volume x SoundGroup volume; hiss distance by its InverseTapered roll-off (min 12, gain
  min(12/d, taper)). Cruise bed (TrainRun 0.55, Wind 0.22, DepotHall 0.15, Eerie 0.06): mean 20.7, peak 41.7. Loudest
  cue HollowSlam mean 81 / peak 238 (HollowStrike peak 60). Creak (one-shot, its peak vs bed mean): markers on 43-55
  (2.1-2.7x) **pass**, off 48-52 **pass**, below HollowSlam. Alarm: on peak 15 (0.7x), off 20-23 (1.1x) **fail**; +25%
  gives 19/29 (<1.5x), so **unchanged**. Hiss mean (on/off): 5 studs 9.1/12.8, 20 studs 5.5/7.7, 35 studs 1.6/4.4 vs bed
  20.7: **markers-off at 20 studs fails** (7.7); +25% gives 9.6, still under, so **unchanged**. Spectra (AudioAnalyzer on
  AudioPlayers, 512 bins to 24 kHz): bed 9% <300 Hz / 69% 300-2k / 22% >2k; hiss 91% >2 kHz, alarm 93% >2 kHz, creak
  100% <300 Hz; overlap with the bed 0.22 / 0.15 / 0.01 (none masked); peaks at volume 1: hiss 0.13, alarm 0.31, creak
  0.17 (no clipping). So the two fails are level, not masking: they sit in bands the train barely fills.
- **Initials (T7, 1727d6b):** the "?" came from `UI/RouteVote`: it looked voters up in `Session.crew()`, which is the
  local player's *own* crew entry, not the crew map, so every stamp got `name = nil` -> `initials(nil)` = "?" (real
  accounts hid it under the headshot). Now it reads the crew map and falls back on the Player's DisplayName, then Name;
  the rule moved to `TicketModel.initials` with awkward-name specs. Own account: stamp reads **OO** (display name
  5O10M0N: the first Latin letter leads, then a capital after a digit) (`P_vote_stamp_initials`, headshot hidden for
  the shot). Local Server stamps now read "P". **Same initials:** Player1/2/3 all stamp "P"; only the voter's own stamp
  is told apart (brass ring) plus a few degrees of hashed tilt; real accounts show headshots over the letters.
2. Known bugs / open items
- Alarm (0.7-1.1x bed) and markers-off hiss at 20 studs (0.37x bed) fail the loudness rules by more than the allowed
  25%; left unchanged. Owner: judge by ear with `sound`; a fix needs more than +25% (alarm gain 0.4 in HullController)
  or a different rule (band level).
- Running-in Sign ball finials (864 tris per sign), above.
- 4-client Local Server: tools reach only some clients (see methods).
3. Next logical step / needs the owner
- Answer after `Remotes.Dev:FireServer("sound hiss")` (and creak, alarm; Settings > Broken Things Markers off for the
  hiss): (1) Can you tell the three sounds apart over the train? (2) Is any harsh or too loud? (3) Can you find a leak by
  ear with markers off?
- **Live 2-account test (needs you + one friend), on a private published test place:** both join, ready, vote different
  lines, then the same line. Look at: each stamp shows that player's headshot (letters under it are their initials,
  never "?"), your own stamp has the brass ring, the seal stays clear with 2 stamps. Then one gets grabbed at a stop and
  the other sees "Pull free" and frees them; the grabbed player's plate says "Your crew can pull you free".

## 2026-10-13: COMPLETION PASS (tasks 1-7 of the blocked/skipped list) -- READ THIS FIRST
Shots (0.5 scale) in `docs/checks/` (K_ kit, L_ hull, M_ fences, N_ hedge, O_ vote). `lune run check` passes.
1. Features completed / verified
- **Station kit uploaded (68def42).** Studio 3D Importer, Upload to Roblox on, creator Me. All 7 pieces came back with sizes identical to `StationKit.json`, rotation 0; ids matched by name into `Config/StationKit`. Imported model deleted. **No Open Cloud key was created.**
- **Kit in Studio.** Meshes load (`AssetService:CreateMeshPartAsync`), are welded to their props, show their vertex colours, and sit within 0.3 studs of the primitives' centre and 0.6 of their size; none invisible. Checked at Halt, Minehead, Infirmary, SignalWorks. Only GasLamp and HazardRail dress anything now: **picket fences are no longer dressed** (see triangles); Crate, SignBoard, WallBrick, RoofSlate were never wired to a prop (`dresses = {}`), so they load but appear nowhere. Kit picket colour is light grey (`PAINT`), the primitives sage green.
- **Triangles measured** (Studio render stats, Ctrl+Shift+F2 in this Studio, not Shift+F2; Scene draw count with the whole stop in view from above, station minus no-station). Per-shape costs measured with 1000 test parts: block 12, cylinder ~88, ball ~432 (the audit had 48 and 192). Before fixes, in Play: Minehead 214k, Halt 294k, Infirmary 206k (part-collapsed), **RailwayHotel 456k (over)**. After fixes, every archetype at the audit seed, kit on, quality 21, in Edit: CoalYard 272k, EmergencyVillage 72k, Halt 287k, Infirmary 231k, Market 235k, Minehead 221k, PostTown (Wickham Cross) 207k, RailwayHotel 256k, Schoolhouse 294k, SignalWorks 274k, Terminus 52k, Viaduct 147k; Schoolhouse #424244 (largest on 4 seeds) 334k with kit pickets, 294.5k without. From a player's eye on the platform Halt draws ~99k (buildings occlude); the shadow pass is the bigger cost (~0.9-1.2M tris).
- **Triangle fixes (f5cacd7):** hedge = block + one rounded cylinder top (was 3 balls; RailwayHotel hedge 219k -> ~15k); iron railing finials are 0.5-stud block caps (was balls; Infirmary/SignalWorks -150k each); picket fences keep primitives (kit mesh 456 tris vs 168). Audit: costs corrected, tri limit 375k geometry (it counts every part, no occlusion, no kit meshes; 372k geometry measured 294.5k drawn). Audit parts (default seed): CoalYard 7403, EmergencyVillage 4485, Halt 7212, Infirmary 7773, Market 8856, Minehead 7739, PostTown 8656, RailwayHotel 6858, Schoolhouse 8268, SignalWorks 8672, Terminus 1741, Viaduct 7034 (in game +1 MeshPart per dressed lamp/rail).
- **Two players (Local Server, Player1 + Player2):** grabbed Player1's plate shows "Your crew can pull you free"; with the crewmate eliminated Player2's plate leaves it out. Player1's own Pull free prompt is disabled; Player2's is enabled (range 11) and `PromptShown` fired on Player2 at 8 studs. Vote card, 1 and 2 stamps: seal (Wax) clear of title 6 px, DANGER 4, stamps 2+ px, button 14, flap 15 (`O_vote_two_stamps`). 3+ stamps: not seen live (2 players); `TicketModel.stampX` + spec prove a pile of any size lies between the 2-stamp ends (6ece0a1). Weaker than a live 3-player look only in that the stamps' hashed +-4 px vertical jitter was not seen for 3.
- **Hull warnings and sounds (in Play):** 75 -> "HULL BELOW 75%: SHE'S STARTING TO GIVE" (amber 232,158,60); 50 -> "HULL BELOW 50%: THE LIGHTS ARE FAILING" (amber); 25 -> "HULL BELOW 25%: EMERGENCY! REPAIR AT THE WORKBENCH" (red 179,38,30) (`L_hull_25_toast`). Creak (SkyGroan) and Alarm: in SoundService (non-spatial, same at every distance), group LastTrainOut vol 1, loaded (16.0 s / 8.2 s), 8 creaks and 4 alarms in 48 s across the tiers, PlaybackLoudness peaks 524 and 91; creak vol up to 0.235, alarm 0.18. Leak hiss (SteamLeak): on the breach part, looped, loaded (5.05 s), vol 0.82, InverseTapered 12-40 studs, LastTrainOut group; output ~15 mean / ~60 peak out to 36 studs, 0 beyond 40 (the engine stops mixing it): full volume within 12 studs, about half at ~24, silent past 40. Nothing silent or broken.
- **Leak after a rally (observed, unchanged):** this run's first breakdown went to the Emergency Village (stop 3); 3 parts aboard (dev `parts 7`, the village counts parts above those on arrival) -> 3/3, parts 7 -> 4, hull restored to 40 (`VillageRestore`). 2 leaks stayed open; hull 31.7% at the first Cruise sample, then a steady 0.81 %/s; 1% would come ~48 s after the repair, but this leg ended first: arrived at stop 3 with 2.6%, held through Dwell. No second breakdown this time.
- **Fences:** pickets (1.0 stud, primitives) at Halt and Schoolhouse and iron railings (2.25) at Infirmary and SignalWorks all still read as fences at standing height; no spacing change.
2. Known bugs / open items
- Vote stamps show "?" instead of initials in a Local Server test (test players have negative user ids); not checked with real accounts.
- Kit picket mesh and the 4 unwired kit pieces are uploaded but unused. A lighter picket mesh (<= ~200 tris per 12 studs) would let fences use the kit within budget.
- Schoolhouse is the stop nearest the budget (294k drawn on two seeds).
3. Next logical step
- Owner: decide whether the 4 unwired kit pieces (crate, sign, brick wall, slate roof) should dress anything; that is new content.

## 2026-10-13: FOLLOW-UP PASS (grab plate, multi-seed stations, kit upload) -- READ THIS FIRST
1. Features completed
- **Solo grab plate (8b762b2):** "Your crew can pull you free" shows only when another crewmate is Aboard/Afield/Straggler (`RunRules.hasLivingCrewmate`, spec in `tests/Run.spec.luau`; `GrabController` passes it to `Struggle.show`). Studio, solo: Dev `grab` -> plate lines "DRAGGED BY THE ANKLE | A STALKER HAS YOU | WHEN THE NEEDLE HITS THE ZONE | (blank)"; console clean. The 2-player case (line shown) is **not checked** in Studio.
- **Stations clean on `AUDIT_SEEDS=4` (20e0e65):** picket fences one picket per 1.0 stud (was 0.75), iron railings per 2.25 (was 2.0); Schoolhouse `lampSpacing` 36 -> 44 (one platform lamp fewer than before on most seeds); stall goods each get their own height band (Market z-fight); the lip neon in `EdgeMark` is turned 0.3 deg so its ends can never lie flush with a wall stone (PostTown z-fight; insetting it only moved the clash). No building counts or landmarks changed. Worst case over 4 seeds: Schoolhouse 8721 parts / 96 lights, SignalWorks 8898 / 76, PostTown 8875 / 96 (64 lit), Market 8856 / 85. Default seed: Schoolhouse 8324 / 93 (57 lit), SignalWorks 8672, Halt 7212, Market 8856, PostTown 8656. Studio: Schoolhouse docked at stop 1 with 8570 parts, 94 lights (61 lit), console clean.
- `lune run check` passes.
2. Known bugs / open items
- **Station kit upload: blocked.** No uploader script exists (the train FBX went up through Studio's 3D Importer) and no Open Cloud key is set, so `Config/StationKit` ids stay nil (primitives in use, unchanged). Owner: create an Open Cloud API key (create.roblox.com > Open Cloud > API Keys) with **Assets API: read + write**, scoped to your user, and set it as the user environment variable `ROBLOX_API_KEY` (never in the repo or chat); or import `assets/stationkit/StationKit.fbx` yourself (3D Importer, creator Me) and paste the 7 ids. Then: dock Halt (`station Halt`), compare against primitives, re-run the audit.
- Triangles: not measured (TRIANGLES block was left empty); still the part-shape estimate.
- Leak after a successful rally: not re-observed this pass (D.6, unchanged).
- Still for the owner from the last pass: 2-player checks (vote stamps, crewmates' Pull free, now also the plate line with a crewmate), hull toasts/creaks and hiss by ear.
3. Next logical step
- Upload the station kit (above), then the Halt check and fresh part counts.

## 2026-10-13: CLEANUP PASS, FIX PASS PARTS 1-2 (Studio checks) -- READ THIS FIRST
Two Play sessions in the "Last Train" window, solo. Shots (0.5 scale) in `docs/checks/`. Console clean in both sessions apart from the one bug below.
- **Fixed (46e0973):** `UI/RunCard` showed only the *first* run ticket in a Studio/server session; every later one threw "The Parent property of Close is locked" (CLOSE and its hint were destroyed with the old ticket). They are lifted back onto the backdrop first. Verified: 2nd and 3rd tickets in one session showed with CLOSE. UI only, so no spec.
- **Verified in Studio:**
  - A: spawn faces down the car (+X); camera forced to 25 studs and turned into the side wall stays inside in a middle car (5.4 of 6.0 studs) and the guard's van at x -88 (`A_*`). The van's rear balcony (x -92) and open door gaps have no wall, by design.
  - B: seal right of the danger rows, clear of title, marks, stamp and button with **one** stamp (`B_vote_one_stamp`). Several stamps need 2+ players: **not checked**.
  - C: panel up the whole run, readable under the vignette; vignette near a Hollow is blue-grey and drained, not black (`C_vignette_near_hollow`). Stamina: 0.7 transparent when full, opaque by half while warming brass -> ember, red pulse when spent, recovers (sampled, no shot).
  - D: stop-1 death (`D1`, cause "LOST / Something on the line took you." because the test kill carried no damage tag), win (`D2`, TERMINUS, MADE IT), breakdown loss (`D3`, WRECKED, TRAIN LOST AT STOP 5). 3 stats each, no receipt.
  - E: live grab, release and lobby respawn without errors; your own "Pull free" prompt is disabled on your screen. **Not checked:** that crewmates see it (2-player Local Server opens extra windows; left for the owner).
  - F: ring on screen (`F_skillcheck_ring`). Logged: an early press = Miss (clock jump), a repeat 0.03 s later and a replay 0.33 s later ignored; a press in the zone = Great (+1.5); no press = Miss at turn end + 0.2 s (-0.5); 3 progress frees ("Escaped"). Zone 70 deg at stop 1, 58 at stop 3, 140 on the tutorial grab; sweep 1.25 s; first check ~1.1 s after the grab, 0.56-0.93 s between. Dev `grab` returns false while `god` is on (seize refuses god players).
  - G: alert "STEAM LEAK · CREW CAR · 16 m" + arrow (`G_leak_alert_arrow`); patching cleared tag, plate, arrow and chip together. Markers on: steam rate 40 x sev, hiss rolloff 40. Markers off: no plate/arrow, rate 90 x sev, lifetime 1-1.9 s, size 1.2, hiss rolloff 95, volume 0.98. **Sound not heard** (no audio from the tools).
  - H: run 1 "WASD to move..." at boarding and "Stay in the lantern light..." off the train, text as `Config/Tutorial`. Run 2: the teaching Crawler (Pin) grabbed, 140 deg zone, "Press SPACE when the needle is in the zone." beside the plate; two misses then two Greats freed me. It stalled 6 studs short while I stood among market stalls; it reached me on open ground.
  - I: Boiler strain toast at a stop; its 2 leaks burst only once Cruise began (none in Dwell/Departure, hull held). Rally failed (1/3) -> train lost; rally done (3/3) -> hull 15%, trip clock extended, limping -> the leaks still open drained it back to 1% in ~20 s -> second breakdown -> lost at stop 3 (`I_rally_ok_then_lost`).
  - J: hull 70/45/20: tier 2 lamps drop out (0.33 vs 0.7), tier 3 dim red pulse. Workbench repair: 2 parts for +10% (20 -> 30, parts 3 -> 1), refused with 1 part. Tier warning toasts and creaks not confirmed (not captured as new labels/sounds).
- **For the owner:** several-stamp vote card and crewmates' "Pull free" (2 players); hull tier toasts/creaks and the hiss by ear; a successful rally with leaks open is lost within ~20 s (D.6 rule, not changed); the struggle plate's "Your crew can pull you free" shows in solo runs; Dev `skip` does nothing in LastCall at a normal stop (use `warp 300`); `/tutorial` works through the legacy chat box.
- Owner decisions untouched: markers default, brass/XP placement, failed rally loses the train, existing players get the tutorial once, all tuning numbers.

## 2026-10-13: FIX PASS PART 3 (stations) -- READ THIS FIRST

### Resume point
- Done: steps 1-10 (audit, design notes, shared generator, kit, ten archetypes, Emergency Village, tutorial stop 1, specs).
- Cleanup pass (2026-10-13), verified in Studio:
  - PostTown (Wickham Cross): docked at stop 1, console clean; `docs/stations/posttown_overview.jpg`. It docked with **67 lit lights** (budget 64): the audit builds one seed only. Fixed: `Stations.Lamps.LitMax = 64`, StationBuilder turns off moonlit panes, then working room bulbs (power relights them) past it, for any seed. `AUDIT_SEEDS=n lune run audit Station` now also sweeps n station seeds.
  - Emergency Village: success (halt, toast "Repair parts aboard: n/3", 133 s Dwell + 15 s Last Call, loot all Scrap, parts 8 -> 5, hull 40, Cruise resumed with its time left (~33 s), no landscape inside the next stop's footprint) and failure (falls back on the rally toast "Repairs aboard 0/3 · 30 s"); nextStop stays 1, no vote, next HUD reads stop 1/10, console clean. No logic bug, so no new spec. The hull still drains after the restore when a steam leak is running (by design).
  - Tutorial stop 1: `/tutorial reset` = tier 1, which has **no** teaching Crawler (`scriptedGrab` is tier 2 only); use `/tutorial 1` to see it. Tier 1: all 14 yard lamps SafeLight, 87 EdgeMarks each with a SinkholeEdge rail; 10% of floor tiles inside a pool, mean 23 studs and at most 69 studs to a pool edge. Tier 2: the Crawler rose 19 s after stepping off (grace 15 + 4), 18 studs away on yard floor (y 3.5), inside the rail.
- Known (other seeds, from `AUDIT_SEEDS=4`, not fixed): Schoolhouse 9061-9189 parts and 97-98 lights on seeds 424243-5; SignalWorks 9013 parts on 424244; a Market stall z-fight (424243) and a PostTown boundary stone vs edge glow sliver (424244). The default gate (seed 424242) passes.
- **Not done (needs the owner):** triangle measurement and the station-kit upload both need Studio's GUI (render stats Shift+F2 / the 3D Importer); the GUI pass was stopped (see below). Triangles stay the part-shape estimate (~139-300k, budget 300k). Kit ids still nil (primitives in use). AGENTS.md now carries the kit upload exception.
- Two extra blank Studio windows were opened by mistake during this pass (started 19:43); the "Last Train" window is the real one.
- Per archetype recipe: new `length`/`depth` (+ `village` rows), more `landmarks` (new `Config/Buildings` defs as needed; Spine 4x4+ may have `upper`, measure its `tiles` from the slab), new structures in `StructureKit` + `Stations.Footprints`; `lune run stations` (walkable area >= 3x before), `lune run check`, then Studio: Dev `station <Id>` before Ready, skip to Dwell, one overview + one edge shot (`docs/stations/<id>_*.jpg`).

### After (per archetype, seed 424242)
| archetype | size | walkable | bldgs | structs | loot | far | jog2x | spr2x | dwell1 | dwell10 | parts | lights (lit) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Halt | 432x348 | 138672 (3.4x) | 8 (was 3) | 5 | 77 (was 23) | 450 | 45.0 | 34.0 | 232 | 240 | 7579 | 86 (58) |
| CoalYard | 480x372 | 162720 (3.1x) | 8 (was 2) | 16 (was 9) | 85 (was 37) | 462 | 46.2 | 35.0 | 237 | 246 | 7403 | 64 (47) |
| SignalWorks | 468x420 | 182592 (3.1x) | 8 (was 1) | 14 (was 7) | 78 (was 24) | 570 | 57.0 | 43.4 | 257 | 263 | 8774 | 76 (51) |
| Market | 480x408 | 181152 (3.2x) | 8 (was 1) | 20 (was 10) | 98 (was 23) | 534 | 53.4 | 40.6 | 271 | 273 | 8856 | 82 (59) |
| Viaduct | 612x216 | 118224 (3.1x) | 8 (was 1) | 6 (was 2) | 78 (was 20) | 390 | 39.0 | 29.3 | 219 | 226 | 7034 | 88 (62) |
| Minehead | 480x432 | 189504 (3.1x) | 8 (was 3) | 11 (was 6) | 76 (was 30) | 606 | 60.6 | 46.2 | 270 | 272 | 7739 | 70 (49) |
| Schoolhouse | 480x408 | 184320 (3.3x) | 7 (was 1) | 4 (was 3) | 82 (was 29) | 546 | 54.6 | 41.5 | 261 | 267 | 8720 | 95 (59) |
| Infirmary | 456x396 | 169488 (3.3x) | 8 (was 1) | 4 (was 2) | 88 (was 31) | 510 | 51.0 | 38.7 | 257 | 261 | 7867 | 82 (53) |
| RailwayHotel | 480x408 | 183744 (3.1x) | 8 (was 1) | 5 (was 3) | 91 (was 32) | 546 | 54.6 | 41.5 | 262 | 267 | 7196 | 93 (61) |
| PostTown | 492x420 | 192816 (3.0x) | 8 (was 2) | 9 (was 4) | 81 (was 27) | 582 | 58.2 | 44.4 | 260 | 265 | 8656 | 96 (64) |

- CoalYard: coaling tower, brick chimney (new), 7 heaps, 5 hoppers, 3 sidings; boiler house, engine shed (now searchable), coal office (new); village: two railwaymen's terraces (new), chapel, cottage. Studio stop 1: docked, 3:49, no errors; `docs/stations/coalyard_overview.jpg`.
- SignalWorks: two-storey signal cabin (new: locking room below, lever rooms above), 2 signal gantries (new), workshop, goods shed, lineman's cottage, 8 cable-drum stacks, 3 sidings; village: terrace, general store, cottages. Iron fences now have bars every 2 studs (2339 -> ~1200 parts). Studio stop 1: 4:05, no errors; `docs/stations/signalworks_overview.jpg`.
- Market: covered market hall (new, its floor a grid of searchable stalls), clock tower (new), fountain square (8x5), 16 stalls, general store, the inn as the public house; village: two terraces, chapel, cottage. Studio stop 1: 4:17, no errors; `docs/stations/market_overview.jpg`.
- Viaduct: kept long and shallow (an embankment); broken viaduct arches (new, x3, one span fallen: hiding under them), chapel, two-storey signal cabin, signal box, coal office as the ganger's hut; village (5 rows): terrace, inn, cottages. Platform lamps every 40 studs (lit budget). Studio stop 1: 3:22-3:25, no errors; arch wedges were inverted on the first look, fixed; `docs/stations/viaduct_arches.jpg`.
- Minehead: pit yard (8x4) round the headframe, chimney, winding house (new), lamp room and baths, pit office, 5 spoil heaps, the drift (tunnel mouth) at the far edge, a pit-row terrace; village: chapel, terrace, cottages. Studio stop 1: 4:20, no errors; `docs/stations/minehead_overview.jpg`.
- Schoolhouse (Ashgrove): the board school (two storeys), schoolmaster's house (new, two storeys), chapel and churchyard graves, water tower, swings; village: terrace, inn, cottages. A near shop was dropped to stay under 96 light instances. Studio stop 1: 4:10, no errors; `docs/stations/schoolhouse_overview.jpg`.
- Infirmary: cottage hospital (two storeys), doctor's house (new, two storeys), mortuary (new; sleeper-heavy, Crawlers), laundry (new), boiler chimney, graves; village: terrace, shop, cottages. Studio stop 1: 4:06, no errors; `docs/stations/infirmary_overview.jpg`.
- RailwayHotel (Gallowmere Junction): the hotel (two storeys, cellar room), stables and coach house (new; Brute sleepers), the inn as the public house, shop, a bandstand (new) at the centre of the square, a signal gantry, fountain; village: two terraces, cottages. Studio stop 1: 4:13, no errors; `docs/stations/railwayhotel_overview.jpg`.
- PostTown (Wickham Cross): sorting office, counting house (new, two storeys, strongroom), clock tower at the crossing, stalls, shop, the inn; village: two terraces, cottages. At the light limits (96 / 64 lit). **Not yet seen in Studio** (Studio's place closed before the shot).
- Halt: stationmaster's house (2 storeys), goods shed, booking hall, cattle dock (new), water tower, sheds; village: the Lamp & Anchor inn (2 storeys), cottages. Studio (stop 1): docked, clock 3:39-3:48, no errors after the fix below; shots `docs/stations/halt_overview.jpg`, `halt_edge.jpg`. Fixed in Studio: loot zone `Village` was missing from `Config/Loot` (LootService errored at Dwell); spec added.

### Performance budgets (per stop, `.lune/audit.luau`, enforced by `lune run check`)
- 9000 parts, 300k triangles (estimate: block 12, wedge 8, cylinder 48, ball 192; MeshParts not counted), 96 light instances of which at most 64 lit at docking (the rest are dead room lamps a building's power wakes), 0 shadow-casting lights, 60 emitters.
- Now: 7034-8856 parts, ~139-283k tris, 70-96 lights (47-64 lit), 0 shadows. Emergency Village 4485 parts, 29 lights. Before: 2742-3746 parts, 18-36 lights.
- Savings made to fit: rock keels only under edge and foundation slabs; iron railings every 2 studs; drums no longer overlapping; lamp pools capped (YardMax 14, Viaduct platform lamps every 40).
- Not done yet (next levers for weak machines / the planned Performance setting): the Blender kit meshes once uploaded (one MeshPart per fence tile or lamp instead of 6-20 parts); StreamingEnabled is not used (the station is one welded moving assembly); no LOD. A Performance setting could skip dressing, trees and dead room lamps.

### Walk-time maths (step 7)
- Inputs (Tuning.Crew, read by MovementController): jog 20 studs/s, sprint 31, stamina 100, drain 18/s, regen 22/s after 0.9 s.
- Sprint pace: a full bar sprints 100/18 = 5.6 s (172 studs), refilling takes 0.9 + 100/22 = 5.4 s at a jog (109 studs), so the best sustained pace is 281 studs / 11.0 s = 25.5 studs/s. `StationReach.roundTrip` uses this (the first burst from a full bar).
- Farthest loot = the longest walk (BFS over the tiles, round structures and barriers, through buildings) from the platform in front of the train (|x| <= 72) to any container or pickup. Worst case per stop (seed 424242): Minehead 606 studs: 60.6 s there and back at a jog, 46.2 s mixing sprints.
- The clock: dwell = (Search(D) {105 -> 75} + 0.5 s x building tiles, cap 90) x dwellMultiplier + 2 x far-corner walk / 20 x 1.6 + 4 s x (stop - 1), plus the 15 s Last Call.
  Example Minehead at its first stop (5, tier 3): far corner (240 - 72 + 432) x 1.2 = 720 studs -> 115 s of walk budget; ~270 s total. The farthest loot round trip is 60.6 s at a jog: 4.5x margin; at stop 10, tier 3: 272 s (4.5x).
  Every stop's margin (dwell at stop 10, tier 3 / jog round trip) is 4.5x-5.8x (table above, column dwell10 / jog2x).
- Enforced in `tests/StationReach.spec`: for every archetype and 8 seeds at loot x1.35, dwell + Last Call at D = 1 and the archetype's first stop >= 2.5x the jog round trip to the farthest loot. The Emergency Village: 150 s window vs its farthest part, also >= 2.5x (`tests/EmergencyVillage.spec`).

### Shared generator (commit "Stations: shared generator")
- `Config/Stations`: `village` (rows, landmarks, containers; zone `Village` = the last rows), `Lamps` (PoolGap 4.5 tiles, YardMax 22), `VillageFill`, `Edge` (RailBack 4.5, TapeBack 6.6, GlowLights 6), `Reach.DoorHalfSpan` 72.
- `Logic/LayoutGen`: village street, a third barrier line at the village, sidings kept out of the village, village containers, no loot on edge tiles, lamp pools along the routes (`YardLamp`, not SafeLight; the platform's `Lamp`s still are), `EdgeMark` on every open edge tile and a few `EdgeGlow`s, `plan.blocked`.
- `StationDressing`: `EdgeMark` (hazard rail, tape, glowing lip; rail tagged `SinkholeEdge`, collision group `EdgeRail` so Hollows climbing from the edge pass it), `EdgeGlow`, `YardLamp`. `Builders/HazardRail` deleted (part 2 stand-in).
- `StationBuilder`: rock keel only under edge and foundation slabs (saves ~1 part per tile).
- Stop clock (`Difficulty.StopClock`, `DifficultyModel.dwell`): (Search {105, 75} + 0.5 s per building tile, cap 90) x dwellMultiplier + 2 x far corner walk / jog x 1.6 + 4 s per stop after the first. `params(..., stop)`; RunDirector passes the stop.
- Budget per stop (audit): 9000 parts, 64 lights, 0 shadow lights, 60 emitters.
- Tests: `tests/StationReach.spec` (all loot reachable, no cut-off ground, spawn lanes valid, loot off the edge, every open edge tile marked, the farthest loot fits the clock 2.5x at a jog at D=1, clock grows with stop), Difficulty and TimedEventSchedule specs updated.

### Shared kit (step 4)
- Blender: `tools/stationkit/build_kit.py` (headless, Blender 5.2) builds GasLamp 260 tris, HazardRail 180, FencePicket 456, Crate 168, SignBoard 48, WallBrick 120, RoofSlate 132 into `assets/stationkit/StationKit.fbx` (+ `.blend`, `StationKit.json` sizes/centres); preview `docs/stations/kit_preview.png`.
- Runtime: `Config/StationKit` (mesh ids nil), `Builders/StationKit` (Preload via AssetService at server start; `dress` puts the mesh over YardLamp, EdgeMark and FencePicket props, hides their solid primitives, keeps collision, Neon and lights). With nil ids nothing changes.
- **Needs the owner:** upload `assets/stationkit/StationKit.fbx` with Studio's 3D Importer (creator Me), paste the 7 mesh ids into `Config/StationKit`, then check one stop in Studio (axes and centres are unverified until then). AGENTS.md's upload exception covers the train only; extending it to this kit is your call.


Generator: `Logic/LayoutGen` lays a 12-stud tile grid (x along the track, z away from the platform; Safe strip 24, zones Near < 0.4 depth < Mid < 0.75 depth < Far). Per archetype (`Config/Stations`): a layout style (Street, Plaza, Yard, Sidings) carves routes, enterable landmarks (`Config/Buildings`, rooms by `Logic/BuildingGen`, upper floors only on the big Spine buildings, no cellars) go first, then structures (`StructureKit`), barriers pinch the Mid/Far boundaries, then containers, loose pickups, platform props, boundary fence and trees, yard lamps (`cols // 5`), dressing and broken ground. Built by `Builders/StationBuilder` (one welded assembly; every floor tile is a 3-part slab: top, earth, keel).
- Loot spots: `containers` (Crate/CoalBin/ToolChest/Vault counts x lootMul, zone-weighted, `FarLoot` bias; furniture containers inside buildings) and `looseItems` (60% Near).
- Hollow spawns: 8 `spawnLanes` along the far edge (shuffled x), sleepers in building rooms (`Difficulty.Sleepers`), wanderers after `WandererDelay`.
- Edge hazards: the station is an island over a sinkhole (`Journey.sinkhole`: length + 2x70, depth + 60). Fog front from the far edge, collapse front trailing it (slabs fall). Part 2's stand-in `Builders/HazardRail` (tag `SinkholeEdge`) only at stop 1.
- Tags: `SafeLight` on every Lamp lens (radius 16) and the train's side lights (34); `SinkholeEdge` on the stand-in rail tops.
- Departure timer: `DifficultyModel.params` dwell = blend(`Difficulty.Dwell` {148, 94}, D) x `dwellMultiplier` x (1 + 0.02 x building tiles); `RunDirector` sets `startedAt`/`departAt` from the server clock at Dwell; clients count down via `DepartureClock`/`Logic/DepartureSchedule`.
- Movement (Tuning.Crew, read by MovementController): jog 20, sprint 31, stamina 100, drain 18/s (5.6 s sprint), regen 22/s after 0.9 s.

Before (seed 424242, `lune run stations`; far = studs on foot from the nearest door to the farthest loot; jog2x/spr2x = seconds there and back; dwell at the archetype's first stop / at stop 10 tier 3; margin = dwellN / jog2x):

| archetype | size | walkable area | bldgs | structs | loot | far | jog2x | spr2x | dwell1 | dwellN |
|---|---|---|---|---|---|---|---|---|---|---|
| Halt | 276x168 | 41040 | 3 | 4 | 23 | 210 | 21.0 | 15.3 | 157 | 101 |
| CoalYard | 312x192 | 52128 | 2 | 9 | 37 | 258 | 25.8 | 19.0 | 170 | 112 |
| SignalWorks | 300x216 | 58320 | 1 | 7 | 24 | 282 | 28.2 | 20.9 | 176 | 118 |
| Market | 312x204 | 57168 | 1 | 10 | 23 | 258 | 25.8 | 19.0 | 172 | 118 |
| Viaduct | 372x120 | 38448 | 1 | 2 | 20 | 162 | 16.2 | 11.5 | 144 | 106 |
| Minehead | 300x228 | 60336 | 3 | 6 | 30 | 306 | 30.6 | 22.8 | 170 | 130 |
| Schoolhouse | 312x204 | 56592 | 1 | 3 | 29 | 306 | 30.6 | 22.8 | 244 | 164 |
| Infirmary | 300x192 | 52128 | 1 | 2 | 31 | 246 | 24.6 | 18.1 | 221 | 152 |
| RailwayHotel | 324x204 | 59616 | 1 | 3 | 32 | 270 | 27.0 | 19.9 | 206 | 152 |
| PostTown | 336x204 | 63792 | 2 | 4 | 27 | 282 | 28.2 | 20.9 | 187 | 143 |

Audit build (`lune run audit Station`): 2742-3746 parts, 18-36 lights, 0 shadows per station (budget 4200 parts / 40 lights). Terminus 2230 parts (not part of this pass).

**Rule change (user, 2026-10-10): commit AND push after every step** (plain `git push` of `claude/last-train-out` only, never force, never another branch or worktree). The older "commit, never push" rule in AGENTS.md is retired.

## 2026-10-13: FIX PASS PART 2 (grabs, threat curve, tutorial, hull and leaks) -- READ THIS FIRST
Part 1 was finished and pushed before this started. One commit per task, each pushed. `lune run check` ran in full (rojo was not blocked).

### A.1 One config table (`Config/Difficulty`)
- New sections, all first drafts: `Aggression`, `GrabDamage`, `Threat`, `PostGrab`, `SkillCheck`, `Hull`, `Leaks`, `Breakdown`, and `Tutorial` (= `Config/Tutorial`, the tutorial's own data file, re-exported so Difficulty stays the one table).
- Moved in (values unchanged): `Tuning.HollowCount` -> `Difficulty.Threat` (`FullByCrew` 3/4/5/6, `SleeperShare`); `Tuning.Grab.DpsShare/MaxBiteShare/Pin.DpsShare` + Brute crush -> `Difficulty.GrabDamage` (Tuning's Brute `crush` now reads it); `Tuning.Hollow.SightRange/AwarenessRange/StrikeCooldown` and HollowService's hard-coded 4 s search -> `Difficulty.Aggression`. Brief 002's `EarlyHollowCap` deleted (was unused). `WandererDelay`, `Sleepers`, `HollowDamage`, `Dwell` were already in Difficulty.
- Sections not yet read by code are wired by the later tasks below. `tests/Part2Config.spec` checks the schema.

### A.2 Aggression and damage up (speed unchanged)
- `Difficulty.Aggression`: SightRange 95 -> 118.75 (+25%), AwarenessRange 30 -> 37.5 (+25%), Persistence (search after losing sight) 4 -> 5.2 s (+30%), StrikeCooldown 0.9 -> 0.72 s (-20%). `HollowDamage` {20, 32} -> {25, 40} (+25%). Counts stay 3/4/5/6 full.
- Speed: every kind's chase must sit between the crew's jog (`Tuning.Crew.WalkSpeed` 20) and sprint (31), pace spread included. The Brute's chase was 0.82 (18-21, slower than a jog at easy stops) -> 0.98. Lunges (x1.45 for 0.55 s within 16 studs) still briefly beat a sprint, as before.
- `tests/HollowSpeed.spec` reads MovementController's source to confirm it moves the crew at `Tuning.Crew.SprintSpeed/WalkSpeed`, then checks every kind at D 0..1. The old masher spec now mashes 7/s (B.1 replaces the mash).
- Unverified in Studio: how the harder Hollows feel.

### B.1 Grab escape: skill checks on Space (Q mash gone)
- Rules: `Logic/SkillCheck` (+ `tests/SkillCheck.spec`), numbers in `Difficulty.SkillCheck`. The needle turns once in `SweepSeconds` (1.25) on the server clock; the zone starts 110-230 degrees ahead (pulled in for wide zones), the leading 25% is great. Good = +1, great = +1.5, miss (early, late, or no press in one turn) = -0.5 and the grab clock 1.5 s closer. 3 progress frees you. Crewmates' Pull free adds 0.15 per pry (PryInterval 0.15 s still applies).
- Server (`HollowService`): picks each check with `Random` when it appears (Fx `SkillCheck` to the victim), first one >= 1.1 s after the grab, 0.45-0.9 s between checks. `SkillCheck` remote (arg kind `check`, 10/s) carries only the check id; the server judges on arrival with tolerance 0.05 s + half the player's `GetNetworkPing()`, capped 0.2 s. One judged press per check (replays and stale ids ignored), presses closer than 0.12 s ignored. Verdict back as Fx `SkillResult`.
- Grab clock: `FinishByStop` 12 -> 9 s by stop (`HazardParams.stop`, set in `RunDirector` Enter.Cruise), never shorter than the worst-case time to win the minimum checks + 1 s (`SkillCheck.finishSeconds`, tested for every stop and zone). Bites still hurt (+25% from A.2) but never take the last 1 HP (`Grab.survivable`); the clock running out kills (`finishHold`, death cause Taken). Replaces `Tuning.Grab.MaxSeconds`/`Escape`/`AllyPresses`, `Difficulty.GrabMash/GrabSlip`, `HazardParams.grabMash/grabSlip` (all removed). Zone width shrinks with the stop (70 -> 38 degrees by stop 7); tutorial run 2 and the scripted grab use `Config/Tutorial` zones (wired in C.3).
- Client: `UI/Struggle` plate (now 460x236 at 0.5/0.62) keeps title, meter and crew line; the keycap+mash hint became a ring (track, zone segments, needle, verdict) plus a keycap showing SPACE / A / TAP by last input type (also the touch button). The red rule on top is the grab clock. `GrabController` binds Space and ButtonA only (Q and R2 removed), sinks them while held; MovementController already zeroes JumpHeight while `GrabStyle` is set and restores it each frame after. README controls row updated.
- Audit `GrabLifecycle` now wins holds with skill checks and checks an early press misses (clock jumps) and a replay is ignored.
- Unverified in Studio: the ring and needle on screen, input feel, ping tolerance on a real connection.

### B.2 Post-grab protection by stop
- `Logic/Threat.protection(stop, tutorialTier)` from `Difficulty.PostGrab.Schedule`: stops 1-2 5 s + stagger, 3-4 4 s + stagger, 5-6 3 s + stagger, 7+ 2 s no stagger. Any tutorial tier: 5 s + stagger everywhere (`Config/Tutorial` `postGrab`). `tests/Threat.spec`.
- `HollowService.release`: immunity applies to every release the victim survives (no Hollow may seize them: `graceUntil`), also published as the character attribute `GrabImmuneUntil` (server time; no UI reads it yet). Stagger on a break-free (skill checks or crew): the holder goes to Reel for `StaggerSeconds` (1.5) and is shoved back at `StaggerPush` (16 studs/s) easing off; it cannot strike while reeling. Without stagger it just recovers. Replaces `Tuning.Grab.Grace/Stagger` (removed). `HazardParams.tutorial` added (set in C.1).
- Unverified in Studio: how far the shove carries.

### C.1 Threat curve and the crew's tutorial tier
- `Logic/Threat.share/total`: a stop holds `round(full x share)` Hollows (sleepers, fog spawns, wanderer all count), share 35% at stop 1 rising in even steps to 100% at stop 7 (`Difficulty.Threat` StartShare/FullAtStop), never fewer than 1. Full counts unchanged 3/4/5/6. E.g. solo 1,1,2,2,2,3,3; four players 2,3,3,4,5,5,6. `HazardDirector.Begin` now sets `hazards.hollowCap = Threat.total(hazards.stop, members)`, replacing the flat `HollowBudget.total` override (HollowBudget still caps sleepers).
- `Logic/Tutorial.tier/crewTier/def`: tier 1-3 on a player's first three runs, 0 after; the crew rides at its least experienced player's tier via `NpcQuest.runStage` (the errands' lowest-stage rule; a spec checks they agree). An unreadable count counts as finished. Wired to save data in C.2.
- Specs: `tests/Threat.spec` (curve), `tests/Tutorial.spec`.

### C.2 Tutorial runs in the save
- One new profile field `tutorialRuns` (default 0, filled by `reconcile` for old profiles, so **existing players, the owner included, get the tutorial once**). No other schema change. `DataService.IsLoaded(player)`: false when the load failed or there is no DataStore (e.g. unpublished Studio).
- New `Services/TutorialService` (in ORDER before RunDirector): `CrewTier(players)` fixed at Boarding (`RunDirector` state.tutorial -> `run.tutorial` in state and `HazardParams.tutorial`); polls who is Afield/Straggler; at RunEnd adds 1 for each member who stepped off at least once (`Tutorial.afterRun`). Not loaded -> plays as finished (tier 0) and nothing is written.
- Owner reset: chat `/tutorial reset` or `/tutorial 0-3`, only for UserId `Config/Tutorial.OwnerUserId` = 11744048795 (the uploader id in AGENTS.md; **owner to confirm it is their account**). On a not-loaded profile (Studio) it is a session-only override, so the tutorial can be tested there.
- Specs: counting, load-failure fallback (`tests/Tutorial.spec`). Unverified live: a real DataStore save of the field.

### C.3 Tutorial effects (draft, all in `Config/Tutorial`)
- Stop 1 of runs 1-2 (`stop1Cap` 1, `stop1Dormant`): `HazardDirector.Begin` caps the stop at 1 Hollow and sets `HazardParams.dormantStart`: no fog spawns, no wanderer, no timed events; `HollowService.Prepare` lets the whole cap sleep and they never stir on their own (only crew coming close wakes them). A station without building sleeper spots then has none.
- SafeLight: parts tagged `SafeLight` with attribute `Radius` (studs). Platform lamps (`StructureKit` Props.Lamp lens, radius 16) and 6 invisible parts along the train's platform side (`TrainService.safeLights`, radius 34, warm PointLight on only while the tutorial lights them). Effective radius = Radius x tier `safeLightScale` (1 / 0.7 / 0.45; 0 after the tutorial). `HollowService.isLit` includes them: Hollows hold at the edge of a lit target, cower and walk out if caught inside, and never spawn inside one. Part 3 can tag more parts; HollowService reads the tag at each stop's Configure.
- Grace: Hollows ignore a player until they have been off the train `grace` seconds at that stop (25 / 15 / 10; first time off per stop, recorded in `tutorialStep`).
- Run 2's teaching grab (`ScriptedGrab`): at stop 1, 4 s after a player's grace ends (off the train, not in a safe light), a Crawler claws up 18 studs behind them, chases only them at 0.55 of its speed (slower than a jog: you see it coming), its hold has a 140-degree zone and cannot kill (the clock running out drops you). It is dismissed after its grab ends. One per run (its stop only).
- Run 3: grace 10 s, small lights, no stop-1 cap. After the tutorial: none of this; only the curve and B.2.
- Unverified in Studio: all of it (sleeper placement at stop 1, the edge-holding at light radii, the Crawler's spawn spot on real geometry).

### C.4 Tutorial prompts (ROUGH DRAFT)
- Every stage and message is data in `Config/Tutorial` (`Prompts`, `PromptSeconds` 7, `PromptGap`, `AwaySeconds`, `EdgeDistance`, `EdgeTag`): run 1 Move / Loot / Light / Edge, run 2 SkillCheck ("Press {KEY} when the needle is in the zone.", {KEY} = SPACE / A / TAP), run 3 Hull / Leaks / Stamina / Voting. Moments: RunStart, OffTrain, AwayFromTrain, NearEdge (a `SinkholeEdge`-tagged part, C.5), Grabbed, Cruise, Leak, Exhausted, Junction.
- `Controllers/TutorialController` (client): once per run per prompt, on runs of the crew's tier (`run.tutorial`), one at a time in data order. Drawn in a new HUD slot `Hud.tutorialSlot()` at (14, 250, 236x84), left column under the in-run Settings button; it yields exactly like the leak slot (hidden under any modal/full-screen UI, and the prompt's time pauses while hidden). It sits left of the grab plate, so the run-2 skill-check line shows beside the ring, not on it.
- Spec: prompt schema in `tests/Part2Config.spec`. Unverified on screen.

### C.5 Stop 1 sinkhole edge marker (stand-in for part 3)
- New `Builders/HazardRail`, built by `StationService.Spawn` at stop 1 only (not the Terminus): yellow posts with black bands every 8 studs, a yellow top rail and red mid rail (both collide), and a painted yellow line on the ground in front, 4.5 studs in from the far edge (inside the boundary fence and tree line), only over Floor slabs (buildings keep their own edge). Welded to the slab under it, so it falls with the ground. Top rails carry the `SinkholeEdge` tag the run-1 "edge" prompt uses.
- Not covered by the visual audit (it is built at runtime); unverified in Studio for clashes with edge props.

### D.1 Hull and leak root causes
- Hull draining before the train left: `TrainService.tick` used `RunRules.isTravel`, which is true in the **Junction** (the vote) as well as Cruise, so leaks burst and the hull drained (leaks and an empty firebox) through the 20 s vote. On top, round 2's timed **Breakdown** event opened two leaks at a *stop* (Dwell); they sat there and then drained through the vote and the trip at the old fixed 0.5 %/s each (+3 %/s if the firebox was empty), which fits 100 -> 1% in ~90 s. Fix: new `RunRules.hullDrains(phase)` = Cruise only; leaks burst and the hull drains only then. A timed Breakdown at a stop now queues its leaks to burst once moving (`pendingBursts`), and its toast reads "BOILER STRAIN ... It will burst once we're moving!" (id stays `Breakdown`, so `/event breakdown` still works).
- "1 steam leak" staying up after patching: two causes. (1) The HUD line was a count over the replicated `train.breaches`, not the leaks; and the stop's Breakdown event opened **two** leaks at once, so patching one left "1 STEAM LEAK" up for the other, unmarked one. (2) `UI/Prompts` only removed a custom prompt's chip on `PromptHidden`, which does not reliably fire when the server destroys the prompt (a patched leak), so a "Steam leak / Patch" chip could stay on screen. Fix: every open leak's anchor now carries the `Leak` tag (+ `LeakId`), removed on patch; the HUD counts `CollectionService:GetTagged("Leak")` and re-renders on tag added/removed, so patching clears it at once; Prompts drops the chip on PromptHidden, Destroying or leaving the game. D.3 moves the leak alert into the reserved slot.
- Spec: `tests/HullDrain.spec`. Unverified live: I could not reproduce the original session, so the two causes above are from the code, not a capture.

### D.2 Leak system (numbers in `Difficulty.Leaks`)
- `Logic/Leaks` (+ `tests/Leaks.spec`): each trip plans its leaks at Cruise start (`TrainService.BeginLeg(km, seconds, stop, d)`): count from `ExpectedPerTrip` {0.8, 2.2} by station difficulty (x0.75 per Armour Plating level), at most 1 for stops 1-3 and 3 after; they burst at 10%, 15%, 20% of the trip (+/- 2%). Severity grows with the travel time a leak is left open: 1 + 0.5 x age/trip (max 2). Drain = K x severity / tripSeconds per second, K = 12.7 from `OneLeakTrip` 14: **one unattended leak costs ~14% over its trip, three ~39%, on any trip length** (spec rides 30-90 s trips frame by frame). Replaces `Difficulty.BreachRate`, `HazardParams.breachRate`, `DifficultyModel.breachRate`, `TrainService.SetBreachRate` and `Tuning.Train` BreachDrainPerSecond/StarvingDrainPerSecond/MaxBreaches/BreachPatchCost/BreachPatchHold (all removed; starving drain now `Difficulty.Hull.StarvingPerSecond` 3, Cruise only).
- `Ledger.drain(train, dt, tripSeconds)` keeps integrity's fraction (the old round to 0.1 per 0.25 s tick distorted slow drains) and never goes below `Hull.Floor` (1); `Ledger.atFloor`. Each breach carries `age`. TrainService publishes integrity in tenths.
- World object: the leak anchor (tag `Leak`, `LeakId`, `LeakSeverity` 1-2 in tenths) with steam (`SteamRate` 40 x severity) and the positional SteamLeak hiss (rolloff `HissRange` 40, louder with severity), always on. A timed Breakdown's queued bursts count toward the trip's cap.
- `.lune/report` prints leaks_per_trip instead of breach_per_min. Unverified in Studio: how the hiss and steam read.

### D.3 Broken Things Markers: leak arrow and alert
- `Logic/LeakAlert.view(leaks, me, markersOn)` (+ `tests/LeakAlert.spec`): from the tagged leak objects only; nil with no leaks or markers off; names the nearest leak's car (`LeakAlert.Cars`, now also used by TrainService's alarm) and distance in metres (`StudsToMetres` 0.28).
- New `Controllers/LeakController` (client, after TutorialController): markers ON (`BrokenThingMarkers.visible()`, now public; the existing setting, unchanged default FirstFew) -> a red-rimmed plate in `Hud.leakSlot()` ("STEAM LEAK · CREW CAR · 7 m" / "3 STEAM LEAKS · NEAREST ...") and a neon chevron arrow 4.2 studs over your head pointing at the nearest leak with a "7 m" tag (hidden within 7 studs). Re-evaluated every frame and on the Leak tag being removed, so the last patch clears both at once. The slot already yields to modals/full-screen UI. The gauge's leak line is gone (only FIREBOX EMPTY stays there).
- Markers OFF: no plate, no arrow; `TrainVisualsController.shapeLeak` makes the steam thicker and longer-lived (`SteamRateOff` 90 x severity, bigger puffs: visible through doorways) and the hiss louder (x`MarkersOffBoost` 1.4) carrying `HissRangeOff` 95 studs into neighbouring cars; it re-shapes when the setting changes. Fuse-box and leak billboard markers (`UI/BrokenThingMarkers`) unchanged.
- Unverified on screen (screenshot below if Studio was reachable).

### D.4 Hull tiers
- `Logic/HullTier` (+ spec): tier 1 below 75%, 2 below 50%, 3 below 25% (`Difficulty.Hull.Tiers`); `strength` x1.4 (`MarkersOffBoost`) with markers off.
- New `Controllers/HullController` (client): a one-time warning toast (`Overlay.alert`) per tier crossed per run (again after a repair takes it back up); creaks (SkyGroan cue, pitched down) every ~9/6/4 s by tier; the Alarm cue every 3.4 s at tier 3; all faster/louder with markers off. `TrainVisualsController`'s lamp loop (StoveGlow/LanternFlame lights) multiplies by `HullController.LightScale` (random dropouts at tier 2, dim red pulse at tier 3) and takes `LightTint` (emergency red), restoring each lamp's `BaseColor` otherwise. Always on in a run.
- Unverified: the sound mix and how the flicker reads.

### D.5 Repair hull at the Workbench
- The Workbench (E "Upgrades - Workbench") panel's hull row is now "REPAIR HULL · +10% for 2 parts · hull N%" (`Difficulty.Hull.RepairParts/RepairAmount`, replacing `Tuning.Train.HullPatchCost/Amount` 5/20). Button reads REPAIR, NEED n MORE (disabled) or HULL SOUND (disabled).
- Server: remote `HullPatch` renamed `RepairHull` (aboard-gated, 3/s); `TrainService.RepairHull` also requires a run phase; `Ledger.repairHull` refuses when short of parts or already full and never goes past the max (spec in `tests/Ledger.spec`).

### D.6 Breakdown at the hull floor
- `Logic/Breakdown` state machine (+ `tests/Breakdown.spec`): None -> (hull at `Hull.Floor` 1% during Cruise) first breakdown -> Village if `BreakdownService.requestVillageStop()` (returns false until part 3) else Stopped (`StopSeconds` 4) -> Rally (`RallySeconds` 45 for `RallyRepairs` 3) -> Limp (hull set to `RallyRestore` 15%, `LimpShare` 0.5 speed for the rest of the trip) -> None on arrival. A second breakdown in the run, or a rally that runs out, -> Lost.
- New `Services/BreakdownService` (ORDER after TutorialService): watches the hull each Heartbeat in Cruise; rally = 3 hold-1.5 s "Repair / Breakdown" prompts aboard, one per car where possible (attachments under the leak anchors), any aboard player; countdown in the timed-event toast ("BREAKDOWN! Repairs aboard: 1/3 · 32 s", cue Alarm); notifications for each step. While stopped/limping it pushes the trip's clock back (`RunDirector.ExtendPhase`: stopped time whole, limp's shortfall) and TrainService pauses drain and leak bursts while stopped (bursts follow distance when limping). `run.breakdown` replicates the state; `JourneyPlan.speed` brakes the scenery to 0 / limps it, and skips re-predicting the dock while broken down (Arrival re-cuts if needed).
- Lost: `RunDirector.EndRun("Derailed")` (new); `CrewService.MarkWrecked` as before. Ticket: hero "THE TRAIN WAS LOST", stamp "TRAIN LOST AT STOP n" (`RunLog.final`, spec updated), cause line "The train broke down for good and was lost."
- **Owner decision taken for you:** a failed rally loses the train (the brief only said what success does; with the hull at 1% any further drain would be the second breakdown anyway). Easy to change in `Logic/Breakdown.tick`.
- Part 3 notes: implement `requestVillageStop()` (true once per run when a village can be offered). The Village phase stops the train with no timer, so part 3 must move the run to the village stop. Village rules: yields repair parts only, once per run, not one of the ten stops, threat on the same curve and tutorial tier.
- Unverified live: the full sequence on a real run (use `/event breakdown` + leaving leaks, or the Studio console to drain the hull).

### Part 2: next session starts here
- All 15 tasks (A.1-D.6) are committed and pushed, plus Dev `leak` / `hull N` commands. `lune run check` passed in full before every commit (311 tests, audit clean; rojo was not blocked).
- **No screenshots.** Studio was open in edit mode with no play session. My attempt to focus it launched a second Studio instance (blank start page), which I closed straight away. The owner still needs to see: the skill-check ring (Dev `grab` at a docked stop), the leak plate and arrow (Dev `leak` during Cruise, markers on), and a tutorial prompt (`/tutorial reset` as the owner, then start a run: "WASD to move..." in the left column at boarding).
- Owner decisions open: Broken Things Markers default (`FirstFew` vs `Always`, from part 1); a failed breakdown rally loses the train (D.6); existing players get the tutorial once (C.2); confirm `OwnerUserId` 11744048795 (C.2); the Brute now chases at 0.98 so it outpaces a jog (A.2); the timed Breakdown at a stop now only strains the boiler, and its leaks burst on the next trip (D.1).
- Tune first: `Difficulty.SkillCheck` (ZoneByStop, SweepSeconds, FinishByStop, Required), `Difficulty.Aggression` and `HollowDamage`, `Difficulty.Leaks.OneLeakTrip` / `ExpectedPerTrip`, `Difficulty.Threat.StartShare`, `Config/Tutorial` grace and safe-light scales, `Difficulty.Breakdown.RallySeconds`.
- Part 3: Emergency Village (`BreakdownService.requestVillageStop`, Village phase), proper sinkhole edge (replace `Builders/HazardRail`), more `SafeLight` parts.

## 2026-10-13: FIX PASS PART 1 (merge, bug fixes, HUD/UI)
Parts 2 and 3 run after this one. One commit per task, each pushed to `claude/last-train-out`.

### Phase 0: setup, merge, brief 002
- Main worktree and `LTO-astra` were both clean, so no backup branch was needed (`backup/pre-astra-merge` from an older merge still exists). `lune run check` passed in full at the start (rojo was not blocked).
- Astra merge: `codex/settings-astra` (96d75f3) was already fully merged into this branch by b402157; `git log HEAD..codex/settings-astra` is empty, so there was nothing to merge and no conflict.
- Broken Things Markers: setting key `BrokenThingMarkers` (`Config/Settings`), choices FirstFew/Always/Off, saved in the profile (`SettingsService` -> `DataService` `profile.settings`, replicated as a player attribute). **Default is `FirstFew`: markers are on for a player's first 3 runs, then off** (owner's 2026-10-11 decision). Not changed; owner to confirm whether "default ON" should mean `Always`.
- Brief 002 (`tasks/002`): superseded by fix pass. It was already built and marked done (8aea907, 1d8de8e); round 2 then replaced its count bump with `Logic/HollowBudget`.
  - Dropped: early-station count bump `Difficulty.EarlyHollowCap` (Difficulty.luau ~line 40, already unused). Part 2 must delete it and replace the flat `Tuning.HollowCount.ByCrew` override in `HazardDirector.Begin` (~line 152, `hazards.hollowCap = HollowBudget.total(...)`) with the stop-index threat curve. `DifficultyModel.hollowCap` (Difficulty `HollowCap`) still computes a cap that this override discards.
  - Carry into part 2 config table (aggression/damage kept): `Difficulty.WandererDelay` {18, 10} s (one wanderer per stop, hunts the nearest player off the train); `Difficulty.Sleepers` TilesPerSleeper 6 (now capped by `HollowCount.SleeperShare` 0.5); `Difficulty.HollowDamage` {20, 32}; `Tuning.Grab.DpsShare` 0.6, `MaxBiteShare` 0.35, `Pin.DpsShare` 0.5, Brute `crush` 1.2; `Difficulty.Dwell` {148, 94} (002's dwell change, kept).

### 1.1 Grab errors (GrabController)
- Still present: `lock()` set `player.DevEnableMouseLock` (server-only, threw every grab) and `unlock()` set it back. Both lines and `saved.mouseLock` removed. A thrown `lock()` used to skip `hidePry`, so the grabbed player saw their own "PULL FREE (E)"; a thrown `unlock()` skipped the camera reset, the outcome alert and (on respawn) `watch(model)`.
- New `safely(name, fn)` pcall helper (warns "GrabController: <name> failed: ..."): `lock` in `begin` (hidePry always runs after), every `unlock` call (finish, respawn, phase change), `Struggle.hide`. Inside `unlock` the AutoRotate restore, camera reset and mouse free are separate steps so one failing does not skip the next.
- Verified: `lune run check` passes (250 tests). Unverified: a live grab in Studio (no console errors, pry prompt only on crewmates' screens).

### 1.2 Death cause
- New `Logic/DeathCause` (+ `tests/DeathCause.spec`): sources Hollow/Fog/Fall/Train -> causes Taken/Smothered/Fell/Wrecked; no tag, unknown tag or a tag older than `StaleSeconds` (8) -> `Other`; a body below `FloorY - FallDepth` -> Fell. `DeathCause.Lines` holds every cause's title and line (death screen and, later, the run ticket). `Types.Cause` gained `Wrecked` and `Other`.
- Server: `CrewService.TagDamage(character, source)` sets `LastDamageSource` + `LastDamageAt` (HollowService grab/bites, HazardDirector fog); cleared in `LoadCharacterAt`. `onDied` uses `DeathCause.fromDeath`. `CrewService.MarkWrecked()` (called in `RunDirector` Enter.RunEnd on Derailed) sets cause Wrecked on everyone still alive. Fell via the 10 Hz position check is unchanged.
- `UI/Spectate` reads `DeathCause.line`; with no other living crew it no longer says a crewmate can bring you back.
- Audit stub `.lune/lib/HollowLifecycle.luau` gained `TagDamage`.
- Verified: `lune run check` passes (255 tests). Unverified in Studio: each death screen line. No source tags "Train" or "Fall" damage yet (no such damage exists); add `TagDamage` wherever such damage is added.

### 1.3 HUD resource panel vanishing
- Cause: the panel (`UI/Hud`, `GaugeCase`) is built once in `Hud.mount`; the ScreenGui has `ResetOnSpawn = false`, so it survives respawns and runs. But its idle look was `HIDDEN` (fully transparent): it only appeared for 5 s after coal went in, parts/hull changed or a leak opened. A run whose figures matched the last run never woke it, so it looked missing.
- Fix: the train renderer is a named `renderTrain`, re-run with the current state whenever the HUD becomes visible (run start); the gauges also wake on `CharacterAdded` and on Boarding/Departure. Task 2.1 then removes the idle fade entirely.
- Verified: `lune run check` passes. Unverified in Studio.

### 1.4 Camera clipping and spawn facing
- Cause: the train's visible skin is non-colliding mesh over invisible (Transparency 1) colliding walls. Roblox's Poppercam only treats opaque AND colliding parts as occluders, so it ignored both and the view went through the walls.
- Fix (`CameraController`): `wallPull` raycasts each frame from `camera.Focus` to the camera against `Workspace.Train` and the lobby's `DisplayTrain` (Include filter, `RespectCanCollide = true`) and pulls the view in to 0.6 studs short of the hit. The pull is folded into the existing shake offset (`applied`), so the unshake step undoes it before the camera module runs (no drift). Skipped in first person and when the camera is not Custom. Open doors (blockers non-colliding) let the view through.
- Spawn facing (`TrainBuilder` spawnPoints): each aisle spawn is turned a quarter about Y to look down its car toward the farther end, instead of the default -Z (the side wall ~7 studs away).
- Verified: `lune run check` passes. **Not verified: Studio access for screenshots was declined this session**, so the spawn view and wall clipping need the owner's eyes.

### 1.5 Vote card seals (`UI/Ticket` full ticket)
- Cause: the wax render is 1.7x the 32 px disc, so it spilled ~11 px past the disc onto the DANGER title above and the first chalk tally beside it.
- Fix: the seal (and a mystery's lantern) moved to the right of the danger rows: disc at x 173, wax x 161-217 / y 89-145 on the 224x214 card, so it clears the name (ends y 85), the title (now width-limited to end before x 161, and shrinks to fit), the tallies (now at x 16-32 under the title), the stamps (x 48-157) and the vote button (y 160). Positions are fixed offsets on a fixed-size card, scaled as a whole, so this holds at any card size. `WAX_SPREAD` names the 1.7.
- Verified: `lune run check` passes; geometry checked by arithmetic. Not seen on screen (Studio access declined).

### 2.1 Resource panel always on
- `UI/Hud`: `GaugeCase` is a plain Frame (no longer a fader CanvasGroup), so coal/parts/hull stay up for the whole run; the change-detection wake code (and 1.3's extra wakes) is gone, `renderTrain` still refreshes on run start.
- Readability: the hit pulses, dread and vitals edges moved from `LastTrainOutEdges` (DisplayOrder 6, over the HUD) to a new `LastTrainOutEdgesUnder` ScreenGui (DisplayOrder 3, under the HUD (5) and the train camera gui (4)), still IgnoreGuiInset + ScreenInsets None, so the inset fix holds. Only the full-screen fade stays above the HUD.
- Verified: `lune run check` passes. Not seen on screen.

### 2.2 Vignette (`UI/Overlay` dread, driven by `AtmosphereController` as a Hollow nears)
- Black edges at up to 0.8 opacity -> cold blue-grey `SHADE_COLOR` (34,42,56) at up to `SHADE_MAX` 0.55, with a gradient that clears faster toward the centre (0.6 at 35% in, 0.92 at 70%). A `Dread` ColorCorrectionEffect drains saturation (`SHADE_DESATURATE` 0.35) and cools the tint toward `SHADE_TINT` with the same level. Never pitch black; it draws under the HUD (2.1). Inset fix unchanged (the edges ScreenGui ignores the inset).
- Verified: `lune run check` passes. Not seen on screen: owner to judge the tone near a Hollow.

### 2.3 Stamina bar (`UI/Hud`, reads `MovementController.StaminaFraction/IsExhausted`)
- `Stamina` CanvasGroup, 200x8, bottom-centre, its bottom 10 px above the hotbar slots (`Position (0.5, 0, 1, -22 - CELL - STAMINA_GAP)`); the backpack hint line sits higher (40-24 px above the slots), so nothing overlaps. Steel track, blackened-brass rim, brass fill with a sheen that warms to ember as it drains. Group transparency 0.7 (`STAMINA_REST`) when full, fully opaque at half or less; pulses moon red while exhausted. The pocket watch/departure ticket (bottom right) and the slate (top centre) are elsewhere.
- Verified: `lune run check` passes. Not seen on screen; on very narrow phone screens the centred hotbar row was already close to the watch.

### 2.4 Leak alert slot (for part 2)
- `UI/Hud` `LeakSlot` Frame, empty: **AnchorPoint (0, 0), Position `UDim2.fromOffset(14, 152)`, Size `UDim2.fromOffset(236, 40)`** (`LEAK_SLOT`), in the HUD container, directly under the gauge case (14, 12, 236x136, ends y 148). ZIndex 1, ClipsDescendants on. Get it with `Hud.leakSlot()` and parent the alert into it.
- Yields: every frame `Visible = not slotBlocked()`; blocked while `Modal.anyOpen()` (new; covers Settings, Dialogue, the Run receipt, Workshop, Outfitter, Ledger, Ticket book) or any of `RouteVote`, `RunCard`, `Unseal`, `CarBoarding`, `Eliminated` is visible (`FULL_SCREEN`). There is no tutorial UI in the code yet; add its root's name to `FULL_SCREEN` when one exists. Also hidden with the rest of the HUD outside a run or with the HUD setting off.
- Settings button in a run moved from (14, 156) to **(14, 200)** (`UI/Settings`), below the slot; lobby (14, 244) and HUD-hidden (14, 14) positions unchanged.
- Verified: `lune run check` passes. Not seen on screen.

### 2.5 Route choices fully random
- Cause: the run seed was already fresh each run (`RunDirector` Enter.Boarding, unseeded `Random.new()`), but `RouteGen` only allowed stations whose `minStation <= leg`, and only Halt and CoalYard have `minStation = 1`, so stop 1 was always those two.
- Fix: `RouteGen.options` ignores `minStation` (any station with weight > 0 that is not the Terminus, at any leg). Kept: distinct archetypes per ballot, no repeat of the previous stop unless nothing else is left, tier <= 2 on legs 1-2, one leg of 5 km or less. `Mystery.pick` no longer falls back to a station already on the ballot (no mystery beats a duplicate).
- Design effect for the owner: harder stations (e.g. minStation 4-5 ones) can now be stop 1, still capped at danger tier 2 and still on the stop-index difficulty curve. Part 2's threat curve should own early danger.
- Tests: new `tests/RouteGen.spec` (no duplicate on any ballot over 300 seeds incl. mystery; every eligible station opens a run across 400 seeds; >40 of 50 seeds give distinct first-three ballots; same seed same ballot). `Run.spec` and `Mystery.spec` lost their `minStation` assertions. `lune run check` passes (259 tests).

### 2.6 One end screen: the run ticket
- New `Logic/RunTicketModel` (+ `tests/RunTicketModel.spec`, 6 tests): builds the data table `{ serial, won, hero, causeTitle, causeLine, stats (max 3: STOPS REACHED, LOOT, CREW), crew = { initials, name, lost }, stamp }` from outcome, run log, nextStop, runId, crew state and the local user key. Your own line: MADE IT on a win you survived, otherwise `DeathCause.line(cause)` (Wrecked for those aboard when the train failed). No line mentions a crewmate, so solo players are never told one can bring them back.
- New `UI/RunTicket.build(data, z, strike?) -> (ticket, play)`: 520x340 paper ticket (Ui.ticket stock, worn double border, moonlight/lamp tint), stub with company line + serial, perforation, hero line (Arvo 32), cause title + line, rule, three stat columns (crew as initials, lost ones struck through in red), stamp (`RunLog.final`, e.g. TERMINUS / LOST AT STOP 1) struck on the right of the foot. The foot's left (`RunTicket.FOOT` = 58 px) is left for the host's buttons. Brief F's ticket book can call `RunTicket.build` with stored data tables.
- `UI/RunCard` is now only the host: dim backdrop named `RunCard` (the leak slot yields to it), CLOSE + "H hides this button", B/backdrop close, shown once per runId at RunEnd (+0.3 s), stamp lands 0.6 s later. The old banner/crew-row/stub-cascade card is gone.
- The run receipt is no longer shown: `FxController` ignores `RunSummary`, `UIController` no longer mounts `UI/Summary` (file kept). **Brass/XP/rank-up figures are therefore not shown at run end any more** (still paid and saved server-side); owner to decide where they belong (part 2/3 or brief F).
- Verified: `lune run check` passes (265 tests). Not seen on screen (Studio access declined).

### Next session starts here
- Owner's eyes needed (no screenshots were possible): spawn view and wall clipping (1.4), vote card seal (1.5), panel + vignette near a Hollow (2.1/2.2), stamina bar (2.3), run ticket at a stop-1 death, a win and a derail (2.6), a live grab (1.1).
- Open questions for the owner: Broken Things Markers default (`FirstFew` = on for 3 runs) vs `Always`; harder stations may now open a run (2.5); where brass/XP should show now the receipt is gone (2.6).
- Part 2: threat curve replacing `HollowBudget.total` in `HazardDirector.Begin` (see Phase 0 carry-over values), leak alert into `Hud.leakSlot()`.

## 2026-10-13: Round 2 (enemies, combat, timed events)
Not playtested (told to stay out of Studio). `lune run check` passes in full (rojo was not blocked this time): 250 tests, audit clean.
1. Completed:
   - Counts: before, a stop held up to `Difficulty.HollowCap` active Hollows (1 + 5*difficulty + 0.6 per extra crew, times station bias and size, max 16) PLUS every sleeper (one per 6 building tiles, uncapped, not counted). Now one budget per stop, `Tuning.HollowCount.ByCrew` = 3/4/5/6 for 1-4 players in the run (`Logic/HollowBudget`, set in `HazardDirector.Begin`), counting sleepers, fog spawns and the wanderer. Sleepers take at most half (`SleeperShare`), leaving room for the wanderer. `Difficulty.EarlyHollowCap` is now unused.
   - Damage: `Tuning.Grab.DpsShare` 0.4 -> 0.6 (+50%). Each bite capped at `MaxBiteShare` 0.35 of MaxHealth (`Grab.bite`). Brute `crush` 1.4 -> 1.2 so a 6/s masher still survives the hardest stops.
   - Brute slam and pin: new `Slam` grab (`Config/Grabs`, `pin = true`), the Brute's only attack (`Grab.order`). The victim is slammed face down over `Tuning.Grab.Pin.SlamSeconds`, damage ticks every `Pin.Tick` at `Pin.DpsShare` of the stop's damage. It reuses the grab lock, Q struggle, E "Pull free" (object text "<name>: Brute pin"), plate "PINNED BY THE BRUTE" and release, death and run-end restore. Poses: CrewPoses reuses the face-down Drag pose and HollowPoses the shovel pose (blade on the back).
   - Timed events: `Config/TimedEvents`, `Logic/TimedEventSchedule` (+spec), `server/Events/TimedEventDirector` (driven by HazardDirector), toast `client/UI/EventToast` + `client/TimedEventToast.client`. 9 s warning toast with an existing cue, Dwell only, 1 per short stop and 2 per long one, never overlapping, 30-45 s cooldown, all end 8 s before Last Call. Surge (15 s): every Hollow wakes and hunts, plus one extra Hollow at the fog front, removed at the end unless winding up or holding someone. Breakdown: two steam leaks burst at once via the new `TrainService.OpenBreach` (wraps the existing local `openBreach`).
   - Testing: the owner (or anyone in Studio) types `/event surge` or `/event breakdown` in chat while the doors are open.
2. Known: outside the brief's area: `TrainService.OpenBreach` (4-line wrapper) and one-line pose hooks in `Animation/CrewPoses` and `HollowPoses`. Fuse boxes cannot break (no code exists to cut a building's power), so Breakdown bursts steam leaks only. Crew count is the run's member list, which includes mid-run joiners. `Player.Chatted` is the trigger, so if TextChatService stops firing it, the command does nothing.
3. Next (playtest checklist):
   - [ ] Solo stop: at most 3 Hollows in `Workspace.Hollows` (sleepers included); 4 players: at most 6.
   - [ ] Stalker/Crawler holds hurt clearly more; no single bite over 35 HP; mashing Q still frees you.
   - [ ] Brute strike: slammed face down, camera and body locked, Q breaks free, a teammate's E prompt reads "<name>: Brute pin", damage ticks once a second, upright and unlocked after escape, death and run end.
   - [ ] `/event surge`: toast counts down 9 s with a scream, Alarm at start, all Hollows come for you, one extra appears and is gone after 15 s (stays if it is mid-attack).
   - [ ] `/event breakdown`: toast with steam cue, two "Hull breach" alarms, two patchable leaks on the train.
   - [ ] Let a long stop run: 1-2 events, never overlapping, none after Last Call; a non-owner's `/event` does nothing.

## 2026-10-11: Round-1 Studio job done on disk (revive marker, door check, railing pilot)
1. Completed:
   - Revive marker (Astra's edit, verified): the guard's van bunk is now `Train.Bunk` (base, mattress, cover, pillow, two hidden Bunk seats) with `ReviveSpawn` on the mattress at train (-86.5, 1.6, -4.53), invisible, anchored, no collide/query/touch, LookVector -X toward the pillow. One bed in the train; the display train gets its own copy.
   - Door check: every carriage's side doors come from one `sideWall` path in `TrainBuilder` (DoorBlocker + DoorPanel leaves with `DoorSlide`), opened for everyone by `TrainService.SetDoors` (model attribute + blocker CanCollide). No per-car model mismatch, nothing changed. Suspicious: the guard's van has leaves only on the platform (+Z) side; Workshop/Stores/loco use their own leaf meshes (`car.pieces`); round 1's streaming fix in `TrainVisualsController` was never tested on a second client.
   - Railing pilot: `Builders/RailingPilot` builds `ServerStorage.PerformanceTrain_Pilot` (12 Parts: Rear/Side Rail1-3, Post1-2, Infill) at the run train's position, called from `TrainService.Init`. Stand-in for the guard's van veranda balustrade baked into `GuardsVanFittings` (~41 balusters, 6 rails, 14 knobs, ~1000 tris est.); pilot ~144 tris. Live railing untouched.
   - Verified: `lune run check` passes; Play: folder has 12 parts, ReviveSpawn as above, console only the DataStore notices.
2. Known: the pilot was not judged by eye (the lobby night left the train black in screenshots). Doors not tested with two clients.
3. Next: drag the pilot into Workspace in Play (daylight) and compare with the van's railing from the platform; Test > Clients and Servers (2 players) to check doors in cars 1, 2, 5 and the loco.

## 2026-10-11: HUD toggle in Settings; Settings button rides up in a run
1. Completed: no hotkey (F1 is the user's monitor switch, V did not suit). Settings has a HUD row (TURN OFF / TURN ON), saved as setting `Hud` (Show/Hide, `Config/Settings`, spec updated). `UI/Hud` hides only an outer `HudRoot` frame, so tool keys keep working. The Settings button sits at 14,244 under the lobby pass, and at 14,156 (just under the coal/hull gauges) while the lobby panel is hidden. Verified in Play: button 244 -> 156 in a run, Hide/Show flips the HUD; console only the old DataStore/Arvo notices.
2. Known: none.
3. Next: none for this.

## 2026-10-11: Settings menu, operators toggle, Ashgrove door ledge
1. Completed:
   - Settings button moved top left under the lobby pass and its shortcuts (`UI/Settings`, offset 14,244); it no longer covers the route ballot.
   - Settings menu text much larger (titles 26, notes 19, buttons 24). Broken thing markers: only Always / Off (first few runs is the default, not a button).
   - Operators panel: no top-right button; panel sits in the corner (`UI/Operators`). Settings has one toggle that reads TURN OFF / TURN ON (status ON / OFF), stored in the existing `OperatorsPanel` setting.
   - Ashgrove: when the school sits on the island's end edge its corridor exit opened over the drop. `StationBuilder` now builds a 14-stud ledge of ground (plus earth under it) outside any ground-floor way out that leads off the island, one per wall, welded with the building.
   - Verified: `lune run check` passes (240 tests, station audit with 6 seeds, no z-fights). Headless: of 30 Ashgrove seeds, the 2 with the school on the edge both got a ledge. In Play: button position, the bigger menu, the toggle hiding the panel. Console: only the DataStore/Arvo notices that were already there.
2. Known: the ledge was not walked in Studio (no dev command to force the Schoolhouse stop). Players who saved "FirstFew" see neither Always nor Off highlighted (intended).
3. Next: on an Ashgrove stop, `tp mid` and walk out the school's end exit to confirm the ledge.

## 2026-10-11: Round 1 bug fixes (input, grab, hotbar, doors, vote, Ready)
Not playtested: this round was told to stay out of Studio. `lune run check` could not run whole because Windows Application Control blocks `rojo.exe` (sourcemap step); every other step (StyLua, selene, luau-lsp on the existing sourcemap, 233 tests, audit) passes.
1. Completed:
   - Grab (`GrabController`): the server pins the grabbed root every tick and shift lock/AutoRotate turned it locally, so the body spun and the camera swung. While held: Scriptable camera dragged to the Hollow's face, AutoRotate and shift lock off, mouse freed; an idempotent `unlock` runs on release, death, respawn, phase change/run end and a missed attribute.
   - Stuck cursor: Shift was sprint and Roblox's shift-lock switch, so sprinting toggled LockCenter (`MovementController` now sinks Shift at High priority, so keyboard shift lock is effectively off). The train camera restored a stale MouseBehavior snapshot (`TrainCamController` now restores Default + visible cursor). K (`UIController`, ignored while typing) frees the mouse, closes modals and the train camera, clears gamepad selection and hands back a Scriptable camera unless held.
   - Mash key is Q (Space swallowed, not counted); keycap reads Q. Pull free stays on E.
   - Hotbar (`Hud`, rules in `Logic/Inventory` + spec): slot key/click holds a tool (brass outline), same key puts it away, E uses it only while no E prompt is showing; clicking/tapping the held tool uses it.
   - Doors (`TrainVisualsController`): rig parts register on DescendantAdded/Removing, so cars that stream in late (or stream out and back) slide their doors for everyone.
   - Vote (`RouteVote`, `TicketModel.ballotShown` + spec): the punch linger re-armed on every render, bringing a closed ballot back; it now lingers once and the ballot shows only at an open Junction.
   - Ready (`LobbyService`, `RunRules`, Run spec): one Ready starts the countdown and the crew is only the ready players. `Tuning.Run.MinReadyShare` removed.
2. Known: none of this was seen in Studio. Gamepad has no hotbar select/use (never had slot keys). Breach steam listeners in TrainVisualsController still bind only parts present at start (leak markers are another area). A run occupies the server's one train, so other hall players wait for it to end; only the host can change the run tier. `.claude/settings.json` has an uncommitted change (the commit was blocked by permissions). The rbxmap MCP server failed to start (CLI fallback works).
3. Next: playtest each fix (see the round-1 report): grab and every way it ends, sprint/train-cam cursor, K, Q mash, hotbar + E near a Pick up prompt, doors in cars 1, 2, 5 and Last Light on a second client, vote after walking between cars, solo Ready with two in the hall.

## 2026-10-10: Engine watched in a run: rods and drivers fixed
1. Completed:
   - Rode a run with the sky pinned at noon (`sky 12`) and watched the engine docked and moving.
   - Fixed the coupling rods: they were built on the top crank, but `CrankPhase` 0/90 told the animator they started at the front/bottom, so each rod orbited a centre 1.1 studs off the axle (the far-side rod rose above the wheel tops). Both rods now carry `CrankPhase` -90 (`Builders/TrainBuilder`), so they ride the crank pins opposite the kit wheels' balance weights. The far side is no longer quartered, because the kit wheels have their weights in the same place on both sides.
   - Fixed the wheel direction: wheels without a `WheelPivot` (the kit drivers and bogie wheels) turned about their local X, which runs backwards on these wheels. They now turn about world Z through their own centre, the same way as the spokes and rods (`TrainVisualsController`).
   - Verified in Play: the far-side rod sits 1.14 studs from the axle and stays level with the wheel angle (34 vs 37 degrees), on the crank pins with the weights opposite. At 60 coal the tender shows 9 of 16 lumps; at 31.8 coal it shows 5; at 0 coal it shows none. While moving, smoke streams back over the train (rate 14). Console clean (DataStore/Arvo notices only). `lune run check` passes.
2. Known: smoke at a dock (rate 6, dark grey, fast 8-12) is barely visible against the sky. "Noon" still renders as a dusky red sky at this biome/dread. The near-side drivers are hidden behind the platform when docked. The bogie wheels now turn the other way than before; they were not watched closely.
3. Next: look at the gangways and couplings between cars; maybe thicken the idle smoke (slower and paler at a dock).

## 2026-10-10: Stores stencils moved, door slide watched in a run
1. Completed:
   - Stores stencils (`tools/trainshell/identity.py`): the big STORES now sits above the security strap (y 2.15), and the L.T.O. No 5 / TARE / KEEP DRY block is at the blind end (x1 - 2.1, y 2.3/2.0/1.77) on both sides, away from the door leaves. Stores was rebuilt. Its geometry and UVs match the uploaded meshes (checked vertex by vertex), so the mesh ids stay and the FBX is unchanged. Only the 8 changed maps were re-uploaded (old ids in `unused.round3_superseded_images` `*_prestencilmove`). `gen_config.py` was run.
   - Verified in Play: the Stores car shows the new maps (24 SurfaceAppearances, none stale), and the stencils read clear of the strap and leaves on the display train and on the run train. In a run (client-side sampling): every car's leaves closed on departure, each sliding 2.85 studs (the Loco cab 2.05), meeting at the door centre, and opened again at stop 3, clear of their openings. Console clean (DataStore/Arvo notices only). `lune run check` passes.
2. Known: the Stores' "No 5" on the platform side is painted on the right door leaf, so it slides away with the leaf (intended?). Coal heap and drivers/rods are still not watched in daylight.
3. Next: ride a run in daylight and watch the drivers, rods, coal heap filling and smoke. Then the gangways and couplings between cars.

## 2026-10-10: Train exterior round 3: Tender and Locomotive
1. Done:
   - `tools/trainshell/engine2.py` models both (run with `pipeline.py Tender|Locomotive`). Tender: riveted U-tank with round corners, a lined panel with gilt shaded "LAST TRAIN OUT" (canvas.py `letters`), flared coal boards with a rolled edge and coal rails, rear deck with the water filler, tool lockers and brake column at the front, steps, grab irons, ladder, lamp irons, buffers, drawbar. Locomotive: panelled 1800s cab (arched roof with ribs and a louvred ventilator, glowing spectacles, cast "LAST LIGHT / No. 1931" plates over the door), Russia-iron boiler (bake2 `Boiler` is now blue-grey) with gilt bands, wagon-top firebox with a glowing ash pan, sand and steam domes, bell on its yoke, whistle, safety valves, smokebox with dished door and dart, balloon stack, headlamp box round the kept Headlamp (its beam stays), cylinders and valve chests, plate frames, axle boxes and springs, running boards on a lined valance, handrails, sand and feed pipes, clack valves, buffer beam, slatted pilot, its own cab door leaves. The boiler has a 4th atlas, `Locomotive_B`.
   - Kit rebuilt: driving wheels have red-painted centres (runtime colour `C.driver`); round-3 wheel, bogie, leaves, rods and coal heap uploaded with it (new ids; old ones under `unused.round3_kit_superseded_*`).
   - Runtime (`Builders/TrainShell`): `engine` cars retire exactly the primitives in their `retire` list (`engine2.retire_list`; colliders and ChimneyTop are hidden in place, the rest archived), put DriveWheelP/N on the drivers (spokes and balance weights archived), RodP/N on the coupling rods and a scaled CoalLump on every CoalTier ball (attributes carried over, so TrainVisualsController animates them). Carriage heuristics are off for engine cars.
   - Uploaded (same flow as the cars): 40 maps via MCP `upload_image`, Tender/Locomotive/Kit FBX via the Import Queue (creator Me); imported models removed from Workspace. `gen_config.py` run.
   - Verified in Play: both trains dressed (Tender 35 meshes, Locomotive 26, every textured one with its SurfaceAppearance, no primitive left visible past the cab); at a docked stop the cab's own leaves slide open with their glass, nameplate and panels read; console clean (DataStore/Arvo notices only). `lune run check` passes.
2. Known: the run's first stop is a dark blood-moon dusk, so the engine was only seen in low light in Studio (previews in `docs/train-exterior/preview/Tender_*`, `Locomotive_*`). Coal heaps and spinning drivers/rods not watched while moving. Loco + tender ~24k tris (meshes) plus kit wheels. The pilot is mahogany (Body livery), not red. The previous Stores stencil note and door-slide watch in a moving run still stand.
3. Next: ride a run in daylight and watch the drivers, rods, coal heap filling and smoke; then gangways/couplings between cars.

## 2026-10-10: Train exterior round 3: Studio check, painted details, upload
0. Steps 2-3 (later the same day):
   - Painted details (`canvas.py`, `bake2.py` stencil layer): Last Train Out crest (gilt garter, star, LTO monogram) and double gilt lining in every lined panel; Stores stencils (Oswald Bold, off-white, worn, mirrored on the far side so they read right); Workshop scorch round the stovepipe and door grips. Last Train Out, Stores and Workshop rebuilt.
   - Uploaded (user approved in chat): all five cars' FBX via the 3D Importer (creator Me) and their 70 maps via MCP `upload_image`. Ids in `asset_ids.json` (superseded ids under `unused.round3_superseded_*`); `gen_config.py` run, `Config/TrainShell` and `TrainLooks.model.json` regenerated.
   - Runtime (`Builders/TrainShell`): a car's own DoorLeafL/R replace the kit leaves on the door they were modelled on (they keep `DoorSlide`); pieces may carry a `color` (the Guard's Van tail lenses are red).
   - Verified in Play: both trains dressed (all five cars, 2 leaves each, every textured piece has its SurfaceAppearance), console clean (DataStore notice only), `lune run check` passes (228 tests).
   - **Review these** (decided on the user's behalf):
     - Stores CrateP (6 tris) was the outboard end caps of the three roof chocks, cut off by the side split at z 5.9. The chocks now end at 5.85 (`identity.py`), so the caps stay in Stores_Crate. Workshop_CrateP (156 tris) is real side-mounted kit and stays.
     - Guard's Van tail: livery role Lamp (Neon) with a red `color` override.
     - Car-specific leaves are matched to a door panel by side and |x| within 2 studs; door sliding with them is not yet watched in a run.
     - Stores: the small "L.T.O. No 5 / TARE / KEEP DRY" block on the platform side sits at x0+2, half over the left door leaf's edge, and the big STORES stencil is crossed by a security strap. Moving them needs a Stores rebake and re-upload.
     - Crew Saloon was re-uploaded with its round-3 build (new mesh ids).
     - Pushing is denied for Claude by `.claude/settings.json` (`deny: Bash(git push:*)`); the user pushes, or removes that rule.
1. Step 1, Studio check:
   - Why nothing new showed in Studio: Rojo 7.7.0 serves this folder (branch `claude/last-train-out`) and Studio ("Untitled Experience", place 140367160674731) is synced (`Config/TrainShell` and `Builders/TrainShell` match disk byte for byte). But only the Crew Saloon's round-2 uploads are in `asset_ids.json` / `Config/TrainShell`; the round-3 Saloon rebake and the four new cars exist only as local FBX/PNG files, which Studio cannot see until they are uploaded.
   - Viewed without uploading: a scratch primitive train built in edit mode (`TrainBuilder.build` at y 300, z 3000) with every car's meshes streamed from a local server into EditableMeshes and 512 colour maps into EditableImages (HttpEnabled on only for that, then restored). All removed afterwards.
   - Per car: **Crew Saloon** (round 3): sits exactly on the primitive car, both sides and gangways line up; nothing broken. **Workshop**: scale and placement right, roof crate and tarp sit on the roof; its own door leaves fit the opening (the colour map is an overlay: they take the Accent livery green, so they look white with no livery). **Guard's Van**: veranda, cupola and tail all on the primitive; nothing broken. **Last Train Out**: fits; crest and double lining missing (step 2). **Stores**: fits; door leaves fit; stencils missing (step 2).
   - Nothing was plainly broken, so step 1 needed no code fix.
## 2026-10-10: Recovery check, train exterior round 3 cars built (Workshop, Guard's Van, Last Train Out, Stores)
1. Completed:
   - Recovery: every committed lobby change from the last days is on HEAD (`LobbyBuilder`, `UI/Lobby`, `Sky`, `PianoNotes`, `LobbyService` unchanged since 0f43aa9); the Astra merge a3563a1 had no conflict resolutions; both codex branches are contained in HEAD. The rear lobby lamps are 9118e1c. The lobby's changed look is the new train shell (round 2, `docs/train-exterior/round2/before_after_lobby.jpg`).
   - Dropped by the user: the Roblox Assistant piano/lamp edits. They were not in the autosave (10-09), `astra.rbxl` (10-08), `OneDrive/Documents/Roblox.rbxl` (10-07) or the open place. **Studio-only edits are never saved by Rojo** (it syncs disk -> Studio only and overwrites synced scripts); put changes in files.
   - Pipeline fixes: `build_car2.py` bakes identity.py's Crate and Tarp pieces (side-split like Fittings) and joins each car's door leaves with their iron/brass (`spec.leafJoins`) into the platform-side atlas (before, they rendered untextured white). `build_car.measure` derives `rearDeck` from the dump: the WoodPlanks slab behind a rear wall ending at it, the Guard's van veranda (-96 to -90) gives -96, matching the posts, tail rail and lamps.
   - Built and committed (previews checked, `lune run check` passing each time): Workshop a7a428a, Guard's Van 6047405, Last Train Out 9ba88fa, Stores 5a6bed1.
2. Known / open:
   - `canvas.py` does not paint `feat.crests`, `feat.stencils` or `feat.scorch` yet: Last Train Out's crest and double gilt lining, Stores' stencilled lettering and Workshop's stovepipe/tool scorch are missing. The crest panel (kind "crest") gets no lining either.
   - The four new cars are not uploaded (no ids in `asset_ids.json`) and not wired in `Config/TrainShell` (`gen_config.py`); the runtime places only the kit's DoorLeafL/R, not car-specific leaves (`leafAnchors`).
   - Not viewed in Studio: Crew Saloon round 3 FBX (80611a8), Workshop, Guard's Van, Last Train Out, Stores.
   - Guard's Van `far` preview crops the longer car (camera framing only).
3. Next: paint crests/stencils/scorch in `canvas.py` and rebake those three cars; then upload, run `gen_config.py`, place car-specific leaves in `TrainShell`, and check every car in Studio.

## 2026-10-10: Train exterior round 2, Crew Saloon rebuilt at the new bar, awaiting sign-off
1. Completed:
   - Found why round 1 looked soft: Roblox serves SurfaceAppearance maps at 1024 whatever is uploaded (a 4096 upload comes back 1024), so the whole car had one effective 1024 map (~10 texels/stud). Each side now has its own 1024 atlas (`CrewSaloon_P`, `_N`: ~47 texels/stud on side-facing surfaces, ~25 on moulding returns) plus `CrewSaloon` for ends, roof, underframe and gangway. Door leaves have their own `Doors` atlas.
   - New pipeline alongside round 1 (`pipeline.py <Car>` runs round 2, `--v1` round 1): `carriage2.py` (panels carved into a thick skin with bolection mouldings, half-round gilt beads and painted pinstripes, T&G boards, fluted pilasters, corbels, dentils, drip moulds, deep arched windows with glazing bars, leaded amber fanlight, brass curtain rail and velvet curtains, warm veil; hooded door track and caged lamp; tubular grab rail on standoffs; riveted solebar, corner straps and knee plates; step with nosing and mud guards; builder's and number plates; truss rods and valance; panelled ends with ladder, handrails and downspouts; buffers and coupling hook; gangway bellows, frames, chains and hoses over the front gap; roof seams, gutters, lamp-tops, torpedo vents), `canvas.py` (wear drawn at its cause: streaks under every ledge and sill, rust from every rivet and strap, soot under the cornice and over the lamp, spray at the skirt and step, scuffs and chips at hands and boots, crazing on upper panels, gilt corner ornaments), `bake2.py` (weighted UVs, Bevel-shader rounded edges and canvas height in the normal map, metals by cause), `make_sign2.py` (boards with crests at both ends, cast brass plates, sign normal map), `build_car2.py` (per-side split), kit v2 (`kitparts.door_leaf2`: framed and braced leaves, strap hinges, flush brass pull, kick plate; `bogie2`).
   - Runtime: `TrainShell` lights each door lamp at the lamp (`lights`), supports Neon/transparency per piece and per-kit looks, and for round-2 cars (`hideWalls`) hides the side-wall primitives and the window-arch decoration behind the carved skin (collision kept).
   - Triangles (car + kit): round 1 22.5k (car 10.7k, leaves 1.6k, bogies 5.8k, wheels 4.4k); round 2 32.8k (car 26.3k: platform side 7.2k, far side 10.2k, ends/roof/under 8.9k; leaves 0.9k, bogies 1.2k, wheels 4.4k). Other cars unchanged.
   - Verified in Play: both trains dressed (26 meshes on the saloon), 1 door light, livery roles and looks on every piece, walk platform -> doorway -> aisle -> both gangways -> platform without snags, console clean (DataStore notice only), `lune run check` passes (228 tests). Shots in `docs/train-exterior/round2/` (lobby before/after with the same camera; station night before/after, sky 23, different stations; door/window close-up; wide).
   - Asset ids in `assets/train/asset_ids.json`; superseded uploads (round 1 and the first round-2 4096 attempt) listed under `unused`. AGENTS.md notes the approved upload exception.
2. Known: car + kit is 32.8k tris, over the ~30k hero guide (wheels are 4.4k and mostly hidden; slimming them saves ~2k). Door leaves still use round-1 bake wear (speckled chips). Gilt brightness follows the Trim livery colour (bright in the lobby). Interior-window view, undercarriage close-up and the low-end test are not done. `docs/train-exterior/preview/CrewSaloon_far.png` is a stale round-1 render. Round-1 superseded mesh ids were never recorded.
3. Next: user sign-off on the round-2 Saloon. Then roll the same language out car by car (one commit each), then gangways for every gap, roofs and undercarriage, then the remaining checks.

## 2026-10-09: Train exterior overhaul, Phase 0-4 pilot (Crew Saloon), awaiting sign-off
1. Completed:
   - Phase 0/1 docs in `docs/train-exterior/`: INVENTORY (7 vehicles, sizes, openings, every script that touches the exterior), DESIGN_BIBLE, REFERENCES (Roblox limits verified on the docs, railway refs, licences), README (pipeline and upload steps). Night before shots in `before/`.
   - Blender pipeline `tools/trainshell/` (one command: `python tools/trainshell/pipeline.py <Car|Kit>`): measures the primitive train headless (`dump_train.luau`), models the car in Blender with bevel/boolean modifiers (`kit.py`, `carriage.py`, `kitparts.py`), letters the name board (`make_sign.py`), bakes AO/position/edge/noise/normal passes in Cycles and paints wear by the bible's rules in NumPy (`bake.py`), exports the FBX (`export.py`), renders previews (`preview.py`).
   - Pilot Crew Saloon: Shell 8.2k, Trim 1.5k, Roof 1.0k, Lens, Sign; shared kit DoorLeafL/R 780 each, Bogie 2.9k, Wheel 552 (instanced). 2048 car atlas + 1024 kit atlas + sign. Uploaded with Studio's 3D Importer and the MCP image upload under user 11744048795; ids in `assets/train/asset_ids.json`.
   - Runtime: `Builders/TrainShell.luau` (called once in `TrainBuilder.build` before parenting) creates the meshes with `AssetService:CreateMeshPartAsync`, adds SurfaceAppearance templates from `src/server/TrainLooks.model.json` (Rojo; scripts cannot set texture ids), drops kit leaves/wheels/bogies on the primitives' CFrames and moves their `DoorSlide`/`WheelRadius`/`WheelPivot` over, hides covered colliders and archives decorative primitives in `ServerStorage.TrainExteriorArchive`. `Config/TrainShell.luau` is generated by `gen_config.py`; `Enabled = false` restores the old look. Livery tint verified on every role.
   - Verified in Play: both the run train and the lobby DisplayTrain dressed (17 meshes on the saloon); doors slide on the existing animation; walk aisle -> doorway -> platform -> back -> both gangways with no snags; console clean (DataStore noise only); `lune run check` passes.
2. Known: the importer turns FBX geometry 180 degrees about Y (export.py pre-turns it); 2 superseded mesh uploads and 2 superseded colour maps are listed in asset_ids.json. Exterior tris for the saloon are ~22k incl. 8 wheels and 2 bogies (bogie bevels are the main cost; trim it in the rollout). Before/after shots are at different stations (each Play rolls a new run). Phase shot "view from an interior window" and low-end device test not done yet.
3. Next: user sign-off on `docs/train-exterior/pilot_before_after.jpg`; then roll out to Last Train Out car, Workshop, Stores, Guard's van (cupola), Tender, Locomotive, then gangways/couplings/buffers.

## 2026-10-08: UI polish pass (lobby, watch, workshop, close tab, route tickets, run card)
1. Completed (one commit each, `lune run check` passing after every one; Studio Play checked each with no new console errors):
   - `UI/Lobby`: departure panel 440x168 -> 360x124 with a tighter head strip and text; READY is one flat brass tone (gradient, rim, keel and brass rim off). The tier plate is the panel's width and sits 6 px above it; the round arrow knobs are gone, so the host presses the plate to step the tier (wrapping back to 1).
   - `UI/Hud` pocket watch: metal sheen on the bezel, ring, bow and a ribbed crown; a crystal highlight; 60 minute ticks and finer pips; tapered hands with tails and counterweights; an aged dial.
   - `UI/Workshop`: crew-pass leather window (cardLeather plus falloff), oxblood rows ruled in old brass, bone text; plates you cannot afford are tarnished brass (74,58,40) with dim text; affordable plates stay bright brass.
   - `UI/Dialogue`: CLOSE is a plain card stub with centred text. The triangle was the right end of the baked ticketTab image (`Theme.Image.ticketTab` is now unused). The Modal and run card CLOSE plates never had one.
   - `UI/Ticket` + `UI/RouteVote`: tickets 224x310 -> 224x214, keeping serial, type, name, danger seal, stamps and the vote button only. The flap unfolds one line ("6 KM · 12 COAL") plus a warning when coal is short; the full dossier sheet and its helpers are removed. The dial is a small brass-cased watch, still swept by the vote timer. Tickets are centred in the route board's slots, which are cut for 310 high.
   - `UI/RunCard` (+ `bare` option on `Ticket.stub` and `TicketBook.track`): fitted card (720-1056 wide, height to content), worn double border, brass corner fittings and rivets, leather title banner, punched holes, ring stain, and a stained red edge instead of the glow. Stubs are 0.8 scale with no km/coal/haul line and only the GAMBLED stamp, on a rail-and-sleeper line. Totals are one line (km, stops, loot). The final stamp sits at the foot beside CLOSE; H still hides CLOSE and the hint.
2. Known / not verified: the sealed (mystery) ticket and a victory run card were not seen in Play; hover and pressed states were not checked (Studio MCP mouse clicks do not reach the GUI). The in-world route board shows the shorter tickets centred in taller slots, so there is paper-less space above and below them. The Talk prompt would not trigger from MCP key input, so the dialogue was opened through the Dialogue remote.
3. Next: user reviews in Studio, especially the sealed ticket, the route board in the saloon and a long (6+ stop) run card. If wanted, shorten the route board slots in `Builders/TrainInterior` to the new ticket height.

## 2026-10-08: UI v2 Step 1: ticket-office dialogue (hero) + lobby fix-up, awaiting review
1. Completed:
   - `UI/Dialogue`: speaking through a booking-office window. Mahogany 9-slice surround with a gilt bead, the resident's Blender portrait (`Theme.Portrait`, Mabel under a hanging lamp behind a brass grille, eyeshade and spectacles), engraved brass name plate, the line typed in bone on a leather blotter with a faint ember halo, the company's COUNTED stamp in moon red, and a punched ticket tab as CLOSE (hover glow, pressed state, gamepad focus via new `Modal.focus`). Sizes to the text (GetTextBoundsAsync); the portrait grows to the column height; lamp glows flicker while open.
   - `UI/Lobby`: crew pass on tooled leather in a brass rim with lamp falloff, an engraved gilt plate and a crest; text about 15-20% larger; NOT SAVING bright red. OUTFITTER/LINE MASTERY/READY get brass rims and an amber hover halo. The tier selector is an engraved plate with brass knobs. Ready lamps are amber glass and light up when ready.
   - Art: `tools/uiart/render_booth.py` (Blender) and `tools/uiart/make_booth.py` (stamp, ticket tab, grain). 14 PNGs in `assets/ui`, uploaded; ids are in `Theme.Image`; credits are in `docs/ASSET_CREDITS.md`. `docs/ui-hero/before-after.png`.
   - Verified: `lune run check` passes (223 tests, audit clean). Studio Play: dialogue fired via the Dialogue remote; window, lobby card, tier plate, and the lamp lit after SetReady. Console: only the known DataStore notice.
2. Known: the knobs show at 55% when disabled (tier 1 of 1), by design. Other residents have no portrait yet; the window drops the picture column for them. Not tested on phone or with a real gamepad.
3. Next: user reviews the hero. After approval, start Step 2: build a shared theme module and components, then restyle in the brief's order.

## 2026-10-08: UI art overhaul "Blood Moon Mail" (pass 1)
1. Completed: darker material design system plus baked textures, applied to the shared components and the main surfaces. Full list and screenshots: `docs/ui-overhaul/REPORT.md`.
   - `UI/Theme`: new palette (leather, lacquer, mahogany, ember, amber, moon red), aged amber card, Merriweather body, Fondamento hand, `Theme.Image` (uploaded ids), `Theme.Slice`.
   - Assets in `assets/ui`, regenerated by `tools/uiart/render_ornaments.py` (Blender) and `tools/uiart/make_textures.py` (NumPy). Credits are in `docs/ASSET_CREDITS.md`. After re-rendering, re-upload (Studio MCP `upload_image` via a local http server) and update `Theme.Image`.
   - Restyled: Ui.panel, ticket, button and meter; Modal; Prompts; HUD watch, hotbar and stop-ticket idle; route tickets, vote banner and dossier; Run Receipt (rebuilt as a ledger slip); Run Card; Line Mastery stats; Workshop rows; Struggle keycap.
   - Verified: `lune run check` passes (223 tests, audit clean). Studio Play shows no console errors. Captured lobby, run HUD, junction vote, a lost-run receipt and the modal shell.
2. Known / not verified: computer-use access to Studio was declined, so I could not check hover, pressed or gamepad focus, the phone/tablet Device Simulator, the voted, expanded or sealed ticket states, a victory receipt, or the Outfitter and Workshop with real data. TicketBook, Unseal, Spectate, CarBoarding, ChalkSlate and the Overlay toasts only pick up the palette. Paper grain was softened after the last capture and is not yet re-checked.
3. Next: the user reviews in Studio (above all at phone size). Then a second pass on TicketBook, Unseal, Spectate and the toasts, plus filigree corners on the large modals.

## 2026-10-08: Train residents, pass 1 (Mabel end to end) — awaiting user test
1. Completed: data-driven NPC system plus Mabel Orrin (ticket clerk) with 15 lines, a 3-errand chain, saving, dialogue UI and tracker.
   - Data: `Config/Npcs` (roster; Dutch, Varga, Pip, Conductor reserved with `enabled = false`), `Config/NpcQuests`, `Config/NpcDialogue/Mabel`. Logic: `Logic/NpcQuest` (co-op rules), `Logic/NpcDialogue` (line picking), `Logic/NpcSave` (schema v2 + migrate), `Logic/Retry`.
   - Server: `Services/NpcService`, `Builders/NpcFigure`. Client: `UI/Dialogue` (train modal), `UI/QuestTracker` (right edge, in-run only).
   - Targeted edits: DataService (schema 2, `NpcSave.migrate` in reconcile, save wrapped in `Retry.run`, 3 tries, 1s/2s backoff), ProgressionService ("Crew errands" summary line), TrainService (`Origin()`), DevService (`npcreset`), Items (UnclaimedValise, TicketStub as kept Tools), Cosmetics (`hat_clerk`, unlock path `npc`), Catalog, Types, Remotes (`Dialogue`), Tuning (`Data.SaveRetries`, `Npc`), init ORDER.
   - Co-op: each player's story saved separately in `profile.npcs`. A run carries one errand per NPC from the crew's lowest stage; it is shared (anyone carries or delivers), and finishing it credits every crew member still alive. Players at that stage advance; others get "Lent a hand" (10 Brass) and keep their stage. Unfinished at run end = failed, stage unchanged, NPC remarks on it once.
   - Rewards: 25/30/40 Brass, paid at run end; finishing the chain grants `hat_clerk`.
   - Verified: `lune run check` passes (223 tests, 0 failures, audit clean). Studio Play: Mabel built in the saloon; greeting in lobby; tracker at run start; offer accepts; valise hidden beside a station container at stop 1; carrying it updates the tracker; delivery says the done line and notifies the crew; run summary showed "Crew errands +25"; a lost run gave the failed line in the lobby; next run offered stage 2 (with recall); `npcreset Mabel` restored the greeting. Console: no errors.
2. Known / not verified:
   - DataStore saving across sessions is untested live: this place has Studio API access off, so profiles are in memory ("NOT SAVING"). Save/migrate/retry are covered by Lune specs with a mock store.
   - Real pickup by keypress at a stop was not completed in the test (the character was taken by a Hollow); the item was given with `give` instead. Pickup reuses LootService's existing prompt.
   - Errand Brass is held until run end; a player who disconnects first keeps the story stage but loses that Brass. A save that fails all 3 tries on leave is lost, as before (it stays dirty for autosave while in-server).
   - Story choices: Mabel has none. For Dutch and Varga, choices are personal: saved per player, and lines filter on them with `when.choice`. Planned for the shared objects (the fuel, Varga's secret): each NPC speaks to each player according to that player's own choice. When the crew's choices differ, the NPC adds a line acknowledging the split. Nothing in the world changes based on another player's choice. To build in pass 2.
3. Next: user tests Mabel in Studio; after approval build Dutch (Footplate) and Varga (Guard's van sick bay) with their choices.

### Studio test steps
- Play; on the client `game.ReplicatedStorage.Remotes.Dev:FireServer("god")`, then `Remotes.SetReady:FireServer(true)`.
- Walk into the saloon to Mabel (Workshop end, left of the gangway) and press E: offer; tracker shows the errand.
- `Dev:FireServer("skip")` twice to dock at stop 1; the valise lies beside a Mid/Far container. Or `Dev:FireServer("give UnclaimedValise")`. Talk to Mabel to deliver.
- End the run (die, or win) to see "Crew errands" on the summary. `Dev:FireServer("npcreset Mabel")` or `("npcreset all")` wipes your story with her.
- npcreset gate: the Dev remote only exists when `RunService:IsStudio()` (DevService.Init), and `NpcService.DevReset` checks `IsStudio()` again and refuses otherwise.

### Mystery clues (planted so far; the ending is undecided)
| Clue | NPC | Unlocked |
|---|---|---|
| She punches tickets for passengers who are not aboard; keeps a list nobody asked for | Mabel | greeting / stage 1 |
| "Forty-one tickets for seats nobody sat in"; the punch is never wrong, so "it's the seats" | Mabel | lore, stage 2+ after small talk |
| A ticket stub sewn into the valise lining, with a name already on her list, which she never told anyone about | Mabel | stage 2 offer |
| The found stubs match her list exactly; the final manifest is "everyone who ought to be aboard" | Mabel | stage 3 offer |
| She must be holding the manifest when it reaches the Terminus, and does not know why | Mabel | stage 3 offer |
| The open entry is "longer than I've been aboard, and I've been aboard forever" | Mabel | errand done |
| Failed entries are copied into the next book "a little smaller each time" | Mabel | errand failed |
| No ticket in her files was ever punched for the journey back from the Terminus | Mabel | near the Terminus |
| Things never go missing on this line; they "wait where nobody thinks to look" | Mabel | errand in progress |

## 2026-10-08: Rear lobby lamps implemented
- Completed: replaced four small wall bulbs with eight shaded warm-cream lamps, evenly spaced on either side of the departure board. Their overlapping light replaces the three hidden rear fill lights; 48-light budget retained. User authorized direct implementation.
- Verified: lune run check passed; restarted Studio Play and inspected screenshots from center and both ends. Rear floor, posters and seating are brighter; lamps clear windows and signs. Console only reports existing disabled DataStore API access.
- Known: no new regression observed. Next: user review of warmth in the rear lounge.

## 2026-10-08: Brief 012 prepared
1. Done: prepared `tasks/012-replace-small-rear-lobby-bulbs-with-even.md` with verified LobbyBuilder ranges and concrete lamp placement, warmth, overlap, and Studio verification requirements. No game code changed.
2. Known: task 012 remains todo; implementation and visual acceptance have not been run.
3. Next: Claude implement the rear lobby lamp replacement on disk, run `lune run check`, restart Play after Rojo sync, inspect rear center and both ends, and report console/screenshot results.

## 2026-10-08: Lobby road edging
- Completed: split the two brass road borders at the black rosette boundary, accounting for strip width to remove coplanar overlap. User authorized direct Codex implementation.
- Validation: lune run check passed; restarted Studio Play and captured lobby with no yellow edging crossing the black ring. Console only reports existing disabled DataStore API access.
- Known: no new regression observed; moving-camera visual acceptance remains manual.
- Next: walk around the rosette and check the endpoints from low angles.

## Brief 011 implemented — visual acceptance pending (2026-10-08)
- Interior lights use RGB(255,190,120); ceiling globes use RGB(255,214,150). Brightness/ranges unchanged; exterior lamps and global lighting untouched. User authorized Codex implementation.
- Validation: lune run check passed. Studio restarted; server running, only existing DataStore API-access error. Captures showed lobby/exterior, not carriage interior; Rojo application and visual warmth unverified.
- Next: confirm Rojo connection, restart Play, board each car and compare with platform-post lamps. Brief stays in-progress pending visual acceptance.
Updated at the end of every task. Read this, AGENTS.md, and git diff to resume.

## 2026-10-08: Brief 011 prepared
1. Done: prepared `tasks/011-gently-warm-train-interior-lighting.md` for a subtle, localized warmer train interior, with verified TrainBuilder/TrainInterior references and required exterior post-lamp inspection. Game code unchanged; warmth remains unverified.
2. Known: exact exterior post-lamp source and Studio visual comparison still need verification.
3. Next: Claude implement task 011 on disk, run checks, restart Play after Rojo sync, inspect interior versus nearby post lamps, and report console/screenshot results.

## Brief M / task 006 — implemented, acceptance pending (2026-10-07)
- Client-only `Visual/HollowCosmetics` decorates Stalker/Crawler with seeded primitive accessories, grime/stains, skull cracks, crawler hair, coat tear accents, badge/buttons/ticket, eyes, drip, breath and chest smoke. Reuses crawler Dust/Breath and Stalker Drip; locally disables/restores old FootMist. All added parts are welded, massless and non-colliding/non-queryable/non-touchable. No custom assets/placeholders.
- `Controllers/HollowAnimator` owns the single update loop and fresh additive neck/jaw offsets (nearby, stationary Prowl only). Existing aggression State drives eye brightness. Lights/continuous effects stop beyond 120 studs; no new attributes/state. `Tuning.HollowCosmetics` holds cosmetic settings. `Logic/GrimeLevel` plus its three pure tests covers stop progression (1=0, 5=.4, 10=.9, Terminus=1) and deterministic +/-10% variation. Actual limb lengths/extra joints skipped to preserve rig geometry; missing joints receive no motion.
- Protected files verified byte-identical by SHA256 before/after: Difficulty.luau, task 002 brief, HollowService.luau, HazardDirector.luau. This task edited no server files, AI, collision geometry or existing animation poses. Other sessions' server changes are not part of M.
- Separate pre-existing blocker (now resolved by another session): before changes `lune run check` had 158 passes/1 failure; after implementation 161 passes/1 failure. Exact same failure: `DifficultyModel: matches the published dwell range of 60 to 95 seconds before archetype scaling`, `tests/Difficulty.spec.luau:105: expected 95, got 148`. Commit `cacfecd` subsequently corrected the dwell spec; task 002 is now done. M did not change Difficulty or task 002 work.
- Verification after Brief C completed: full `lune run check` PASSES, 167 tests / 0 failures, audit clean, including formatting, lint and strict analysis. Builder/pose audits do not exercise the new client decorator. Previous TrainInterior formatting blocker is also resolved externally. Briefs C and D are marked done.
- Repository reconciliation: another session already committed M as `1402502` (acceptance pending); working tree was clean at verification, HEAD `972552c`. No duplicate cosmetic commit or push is needed.
- Studio started/stopped and console/screenshot checked earlier: lobby only, DataStore API access errors. A subsequent process check outside the sandbox confirms Rojo is serving this project; the earlier claim that no Rojo process existed was a sandbox visibility limitation. Studio plugin connection and actual monster visuals remain unverified. No saved temporary files created.
- Next: confirm the Rojo connection while preserving Studio-only work, restart Play, compare Stalker/Crawler at stops 1 and 10/Terminus; inspect accessories/hair/rib stains, aggression eyes, stationary micro-motion versus moving/grabbing, >120-stud effect cutoff, missing player root and despawn cleanup. Read console and take 0.5-scale screenshots. Task 006 remains in-progress until this visual acceptance; automated checks alone do not establish appearance.

## Features completed
- Full run loop: lobby, route vote, ten stops, Terminus, summary
- Hollows with grabs/struggle/pry; enterable buildings; station hazards
- Chunked landscape, sky with blood moon and omens, train camera, procedural crew animation
- AI kit installed (AGENTS.md, HANDOFF.md, TASKS.md, .claude, .codex)
- Fixed Studio Roblox.rbxl LobbyBuilder station master NPC startup error (`C.navy` undefined; corrected to existing `C.night`). Verified Studio Play starts the server, DepotHall has 2973 descendants, and the character, camera, and 4 GUI elements spawn. `lune run check` passes.
- Studio source contains unsynced additions absent from the repository; no repository gameplay source changed.
- Studio `ServerScriptService.Server.Builders.LobbyBuilder`: adjusted lobby fill lights, lowering them from y30 to18 and moving z13 to32; brightness/range changed from .4/38 to 1.1/60. Corner fills lowered y26 to16 with .35/32 changed to .8/44. Studio-only patch preserves unsynced additions.

- 2026-10-06: lobby back wall (departure board, ticket windows) was dark: front fills at z13 range 60 never reached z72. Added a back row of 3 FillLights (x -44/0/44, y26, z52, 0.85/45) in `Builders/LobbyBuilder`. Verified in Studio Play; `lune run check` passes.
- 2026-10-06: Workshop car's wall-side luggage rack removed (`Lining.bareSide` in TrainBuilder) and its sign lowered to y7.85. Lobby platform lamp standards replaced by two lanterns per platform-edge column on down-turned arms (same 0.75/22 lights). Lobby verified in Studio Play; `lune run check` passes.
- 2026-10-07: enterable buildings: back rooms (better loot, behind the corridor), rear/end exits on Hall and Row buildings, a lantern in every front room, moonlight at broken windows of dead rooms, and an upper floor (stairwell ramp, one-part slab, escape window) on School, Clinic and Hotel. New House type (not placed by any station yet). Hotel barrel z-fight fixed. Containers carry `y` upstairs (LayoutGen/StationBuilder pass-through); upstairs sleepers skipped. `lune run check` and `AUDIT_SEEDS=6 lune run audit` pass; not yet seen in Studio.
- 2026-10-07: upstairs Ward beds left a 1.2-stud aisle (beds on both long walls of a ~15-stud room), so only the narrow agent got past the landing. `wall="long"` now uses one row, on the wall away from the door, when the room is narrower than 2 rows + `Buildings.Aisle` (6); Clinic seed 1 lane is now ~6.8 studs. Stairwell ground floor gets a Lantern that always burns (its ceiling lamp sits at the upper roof). `lune run test` passes apart from the Dwell spec (fails from the uncommitted Difficulty.luau change); audit is clean; Studio Play boots without errors, but the upper floor was not walked.
- 2026-10-07: diegetic HUD pass. `UI/Hud`: the top clock and night dial are now a pocket watch, bottom right (hands = hour, moon aperture, a 60-pip ring for the time left with last call in red, a compass dial pointing to the train), with a ticket for the stop, countdown and danger. Gauges, crew list and backpack sit in CanvasGroups that fade when idle (`WAKE_SECONDS`). The stamina bar and Roblox health bar are gone: `Overlay.vitals` shows red edges, drained colour and grey breath, with a heartbeat below 35% health. New `UI/ChalkSlate` hangs a chalk slate under both CREW SALOON nameboards (stop, danger, leaks, firebox, coal short); it hangs on streamed-in boards. Theme: 2px corners, no neon or gradients on the gauges, `Theme.Font.chalk`. The train cam chip and bar were moved clear of the watch. Verified in Studio Play with no console errors and screenshots of each; `lune run check` passes apart from the existing Dwell spec.
- 2026-10-07: the edge vignettes (dread, vitals, hit pulses, fade) left a lighter strip under the Roblox top bar because the HUD ScreenGui respects the inset. `UI/Overlay` now puts them in their own `LastTrainOutEdges` ScreenGui (IgnoreGuiInset, DisplayOrder +1). Studio Play boots with no errors; the station view was not re-checked.
- 2026-10-07 (task 004, brief A): departure clock and warnings. New `Controllers/DepartureClock` is the only client countdown: it reads `run.station.departAt` against `Session.now()`; the pocket watch (`UI/Hud`) uses it. No server change (state already had `dwell`/`startedAt`/`departAt`). Pure `Logic/DepartureSchedule` (milestones start/halfway/T-30/T-10/T-0, 15s gap rule, late-join skip with a 2s catch-up, slate wording) with `tests/DepartureSchedule.spec.luau`. Cues: `Overlay.slate` (top-centre chalk slate, newest replaces), T-30 bell, low whistle from the chimney and a smoke puff, the watch's red departure hand ticks and its case glows; T-10 long 3D whistle (rollOff 1600), double-speed tick, ±1px case shake, seconds in the moon aperture; T-0 smoke burst then `DepartureClock.Clear()` (the one place the warning ends, for brief D). New cues `WarnTick/WarnBell/WarnWhistle/WarnWhistleLong` reuse existing library ids in a `Warnings` SoundGroup beside the main mix; `AudioController.Duck` dips the main mix 20% for 0.3s. Amber grade `Lighting.DepartureWarning` (own ColorCorrectionEffect) plus `AtmosphereController.SetWarning` fog offset; amber edge pulse once a second. Numbers in `Tuning.Departure`. `lune run check` passes on HEAD plus these files (worktree); in the main tree only the Dwell spec fails, from task 002's uncommitted Difficulty.luau. Studio Play boots with no errors in the lobby; a stop was not reached in Studio.
- 2026-10-07 (task 005, brief B; closes 003): paper junction tickets. Pure `Logic/TicketModel` (seal + 1-3 tallies, coal lumps in fives capped at 20 with the true "x12" label, inked track scaled shortest-longest, nil-safe `view` adapter, stamp `pile` by user id with the local player on top and max 4, `dial` sweep with numerals in the last 10s, `tieNote` stating Logic/Vote's real tie-break, seeded `tilt`) with `tests/TicketModel.spec.luau`. New host-agnostic `UI/Ticket` (`full` + read-only `stub`: cream gradient stock, ragged edge, perforated stub, string hole, Arvo/SpecialElite, "No. NN", name shrinks to one line, 2-line description, DANGER on its own line, wax seal, fold-out flap replacing the chevron, 44px buttons with a caution focus ring) and `UI/Stamp` (cached headshot or initials, larger ringed local stamp, 1.8->1 land in 0.12s). `UI/RouteVote` builds tickets once per ballot, updates stamps/selection in place (moves, removals, 0.3s land debounce), sits along the top of the screen, sweeps the dial off `run.phaseStartedAt`/`phaseEndsAt` (the junction timer; DepartureClock only covers stops), and at lock-in lingers 1.6s to punch the winner and slacken the rest. No state/server change: per-player votes and coal were already in state. Cues `TicketStamp`/`TicketPunch` reuse the library Click id (no placeholders). Hud moon caption shrinks/widens instead of truncating; train cam chip is 44px tall and moved clear of the watch bow. `lune run check` passes with HEAD Difficulty.luau; Studio Play boots without errors in the lobby, the junction ballot was not reached in Studio.
- 2026-10-07 (task 007, brief C): route board in the train interior. `Builders/TrainInterior` builds a `RouteBoard` model on the crew saloon's end wall by the Workshop door (car 2, platform half, z 2.4-5.7; the painting that hung there is gone): board, cap, brass rail, 2 clear `TicketSlot` faces, 2 lanterns (arm, cap, base, neon glass with a 0.4/12 PointLight), coal gauge and clock (brass rim + clear dial face). **17 parts, 2 lights**; Train audit 1598 parts / 22 lights (was 1585 / 20), 0 clashes or z-fights. New `UI/RouteBoard` (client): SurfaceGuis on the slots and dials, a client ProximityPrompt per ticket (`OnePerButton`) calling the existing `CastVote` through RouteVote's `castVote`, lanterns lit by vote share in the danger colour by tier (tie = even), hover/selection/prompt focus nudges the lantern and swings the gauge to the coal left after that line, the winner flares and the loser's lantern goes out at lock-in, and the clock shows the hour plus a red DepartureClock hand. `UI/RouteVote` reparents its own Ticket handles onto the board when you are within 10 studs on the saloon side (released at 12), so a ticket is never on screen and board at once; Train Camera, another car, dead or more than 2 lines keep the screen ballot. No server, state or remote change. Studio Play (dev `skip` via execute_luau, allowed for testing): B's screen tickets render at a junction; at the board the tickets moved on (screen hidden), E voted, the lantern went red at 2.25 vs 0.30, walking 13 studs away and Train Camera put them back on screen, and lock-in flared the winner to 2.7 with the loser out. No console errors. `lune run check` passes with HEAD Difficulty.luau.

- 2026-10-07 (task 008, brief D) AUDIT before changes. Stop timeline today: `Dwell` (dwell-15s) -> `LastCall` (the last 15s, ends exactly at `run.station.departAt`, T-0) -> `Departure` (`params.chaseWindow` s, Difficulty-scaled) -> `Junction`. `Logic/RunRules` owns order and durations (`duration("Departure") = chaseSeconds`), shared with the client only through `isStationOpen`/`isRunPhase`. `Enter.Departure` (T-0): `HazardDirector.Freeze`, `HollowService.LetGo`, `StationService.BeginDeparture(accel)` (mode Departing, `modeStartedAt` = now; `Logic/Motion.departureOffset(t) = -a t^2/2`, 0 for t <= 0). `Exit.Departure` (chase closes): `CrewService.ResolveDeparture` (Aboard -> `stationsDeparted` +1; god mode -> respawn aboard; anyone else alive -> `Eliminate(player, "LeftBehind")`, which clears the inventory, fires Fx/Notify and destroys the body after 2.5s), then doors shut, hazards stop, station released after `DepartureLingerSeconds`. Consumers of T-0 / the Departure phase: RunDirector Enter.Departure (above); CrewService.positionTick clutch boards (reads `PhaseEndsAt` = chase end); client FxController.onPhase("Departure") (RUN!/DOORS CLOSING alert, `Departure` whistle, camera shake); DepartureClock T-0 milestone (steam burst + `Clear`, the one warning clear); Hud (DEPARTING status); RouteBoard clock hand (DepartureClock.Remaining); StationVisualsController (fog frozen at `run.phaseStartedAt` in Departure); JourneyPlan (`beginLeg` on entering Departure; scenery speed follows the station's real velocity); JourneyPlan.spec models the station moving from Departure start.
- Task 008 DESIGN CALL: a sub-state inside `Departure`, not a 12th phase (no `Types.Phase`, client phase lists or RunRules order change). `Departure` now lasts grace + chase; the first `Tuning.LastCallGrace.Seconds` (3, `Enabled` flag) keep the station docked and are published as `run.station.lastCallEndsAt`. Deviation from the brief, on purpose: the left-behind check stays where the chase window closes (now measured from the actual departure), because evaluating it at the end of the grace would delete the existing Difficulty-scaled chase window (running alongside the moving platform and the clutch-board bonus). Name clash to know about: the existing `LastCall` phase is the 15s before T-0; the new grace is after T-0.
- 2026-10-07 (task 008, brief D): Last Call grace dock. `Tuning.LastCallGrace` (`Enabled`, `Seconds` 3, door-lamp pulse). `RunRules.graceSeconds/hasDeparted/closeCalls`; `duration("Departure")` = grace + chase. `RunDirector`: `Enter.Departure` (T-0) calls `CrewService.MarkLastCall` (snapshot of alive crew not aboard) and publishes `run.station.lastCallEndsAt` (`Types.StationInfo`); `tick` runs the new `depart()` when the grace ends; DevWarp shifts it too. `CrewService.ResolveDeparture` counts `CrewTally.closeCalls` (+`Economy.emptyTally`) for anyone in the snapshot who is aboard, for brief F (no payout yet). Consumers moved to the actual departure: HazardDirector.Freeze, HollowService.LetGo, StationService.BeginDeparture (so the Motion profile starts at grace end), the client fog freeze (`StationVisualsController`), `DepartureClock.Clear` (warning clear), the RUN!/DOORS CLOSING alert and camera shake (`FxController`, via the new `DepartureClock.Departed` signal). Left at T-0: the departure whistle and steam burst. Cues: `Overlay.slate("LAST CALL")` at T-0; `DepartureClock.InGrace/Remaining` count the grace, so the pocket watch reads LAST CALL 0:03-0:01 and the route board's red hand follows; the tick keeps going; a pulsing warm PointLight at each platform-side (+Z) `DoorBlocker` (6, client-only, made at the first grace because of streaming). Tests in `tests/Run.spec.luau`: phase order and Departure duration, hasDeparted, Motion still through the grace and full chase drift after it, close calls, a late joiner (not a close call; their tracker still gets the T-0 cue). `lune run check` passes (with HEAD Difficulty.luau). Studio Play (dev skip/warp from execute_luau): T-0 showed the slate, the station stayed at x=0 for ~3.3s, then DOORS CLOSING and the station pulled away, with the full chase after; 6 door lamps on during the grace; out on the platform at T-0 and back aboard 1s into the grace logged `[Crew] ... close call at stop 2`. Console clean (only DataStore/font Studio noise). No placeholder assets.
- 2026-10-08 (task 009, brief E): mystery ticket. AUDIT: `Logic/Vote.tally`/`counts` and `TicketModel.tieNote` were already N-option (wide junctions 4 and 8 have 3); no fix, the tie-break rule is unchanged; 3-option tests added. `Config/Mystery` (Enabled, Chance 0.25, PityAfter 5, FirstLeg 2, LootBonus 1.3, DangerBias 0, MaxTier 3). Pure `Logic/Mystery`: `offers` (never junction 1, never two in a row, never the Terminus leg, pity after 5 without, else a roll on `Rng.derive(runSeed, "mystery", leg)` injected as a number), `record`, `pick` (the real station from `RouteGen.options` on a server-only seed, re-rolled until it is off the ballot; the run seed is public so RouteGen on it would leak), `redact` (archetype "Mystery", tier 0, hint "", real distance), `place` (appended to a 2-way ballot, over the longest line of a 3-way), `sealed` destination, `lootMul`. `RouteService` holds the real option server-only; `Close` returns (index, public, real). `RunDirector`: `openBallot` at Junction; at Cruise a sealed leg publishes `Mystery.sealed` (distance + coal only) and multiplies `params.lootMul`; at Arrival the full `run.destination` (mystery = true, sealed = false) is the reveal. `Types.RouteOption.mystery`, new `Types.Destination`. Danger bias is applied to the hidden tier only, not wired into Difficulty. Client: `TicketModel.view` prints "????"/SEALED LINE/no seal; `UI/Ticket` mystery variant (soot smears, "DANGER UNKNOWN", flickering neutral "?" lantern, no flap); RouteVote never opens a dossier for it; `UI/RouteBoard` gets three `WideSlot`s and a middle `Lantern3` (TrainInterior, +6 parts, +1 light) used when 3 lines are up, mystery lantern flickers in a neutral lamp colour; Hud/ChalkSlate show "DANGER ???"/"danger unknown"; new `UI/Unseal` drops a ticket at Arrival, wipes the soot and stamps the name and danger. Dev command `mystery` forces one (reopens the ballot at a junction). `tests/Mystery.spec.luau` (chance/pity/first/consecutive with injected rolls and 400 seeded runs, valid station, LayoutGen with the bonus, no hidden words in the ballot option, sealed destination or ticket view, 3-option tally/tie note). `lune run check` passes (182 tests, audit clean). Studio Play: mystery ticket rendered third on screen; the client's Patch stream showed only the redacted option before lock-in; HUD read NEXT: ???? / DANGER ???; at Arrival the reveal patch named Whistle-Stop Halt (not on the ballot) with lootMul 1.34; the Unseal card showed (sealed frame captured; the wipe end state was not captured); at the board all 3 tickets hung on the WideSlots. Game console clean. No placeholder assets.
- 2026-10-08: mystery fixes. `Mystery.sealed(distance, coal, archetype)` adds `biome` (Journey.biomeFor of the real station); `JourneyPlan` plans that land during the sealed cruise (`transition` split out of `setUpcoming`, once per leg) so Arrival no longer switches it; joiners start on it too. `UI/Ticket` soot is 3 thin smears on the name line only. `UI/Unseal` card slides in at the right edge (30% down), ~3.0s total (was ~5s at the top), and plays for any client that sees the unsealed mystery during Arrival/Dwell (no longer needs to have seen the seal). Specs: sealed land in Mystery and JourneyPlan. `lune run check` passes (183). Studio Play: soot only over "????", description readable; reveal card at x1234/1530, y 30%, 3.0s, stamped BRANNOC INFIRMARY / DANGER 3; console clean.

## Known bugs / regressions
- Place saved successfully to `C:\Users\tameg\OneDrive\Documents\Roblox.rbxl`; Studio DataStores are unavailable, so player profile saving is disabled for this session.
- Studio Play verified all eight adjusted lights and visible floor/rear-hall coverage; repository lune run check passes. Save the changed place in Studio.
- Upper-floor Hollows have no teleport recovery if they get stuck.
- Mystery: a joiner's reveal (mid-cruise or mid-stop) follows the code path (plays on any client that sees an unsealed mystery in Arrival/Dwell) but was not tested with a second client. The sealed destination's `biome` narrows the hidden station to its biome's archetypes (a deliberate clue: the land is visible anyway).
- Departure warnings: no reduce-motion setting exists, so the shake and edge pulse are always on. The existing LastCall phase (T-15) still plays its own whistle and "LAST CALL" banner between the T-30 and T-10 cues. No placeholder assets: every new cue reuses a library id already in `Config/Audio`.
- Junction tickets seen in Studio (task 007 playtest); still check overlap with the top-centre slate/ top bar on small screens. Stamp avatars use `GetUserThumbnailAsync` (initials until it returns).
- Route board: three-line ballots stay on screen until brief E adds a third slot (`SLOTS` in `UI/RouteBoard`, a third TicketSlot/Lantern in TrainInterior). The tie note stays with the screen ballot (hidden at the board). Studio captures of the saloon came out overexposed, so check the tickets' readability (SurfaceGui `LightInfluence` 0.35) by eye. In the first B playtest the screen tickets sat top-right over the CREW SALOON banner rather than centred.
- Last Call grace (task 008): the left-behind check stays where the chase closes, not at the end of the grace (see the design call). The door lamps were confirmed on by script, not seen on screen (the capture camera could not be moved off the player). Lamps take the +Z doors as the platform side. Possible follow-up (out of scope): a station that slides away while players jump across the gap.

## Next logical step
- Mystery ticket (task 009): watch the Unseal wipe and stamp by eye, judge the smudge weight and lantern flicker on the board up close, then tune `Config/Mystery` (Chance, LootBonus, DangerBias) with play.
- Look at the route board in Studio by eye (readability, lantern tint on the walls, gamepad prompt), then brief E (third ticket: add a third slot and lantern, raise `SLOTS`).
- Play a stop in Studio (dev `warp` to jump toward T-30) to check the slate, tick, whistles, amber grade and fog; tune volumes in `Config/Audio`. Then brief B (paper tickets).
- Check the watch's compass afield at a station (only tested aboard), the winded vignette while sprinting, and the HUD at phone size. Option: shrink the Struggle plate to just a keycap prompt.
- Look at the workshop sign inside the train in Studio (it has not been checked on screen yet).
- Save the place in Studio, then reconcile Studio edits with Rojo before syncing.
- Walk the Clinic upper ward with a normal Hollow and check the stairwell lantern. Walk the School, Clinic and Hotel upper floors in Studio (ramp, escape window, moonlight). Decide whether a station should place the House (`Config/Stations` landmarks).
- Brief F: reward or show `CrewTally.closeCalls` (summary line, Economy payout, a milestone). Look at the door lamps by eye at a stop at night.

## rbxmap setup — 2026-10-06
- Completed: 119-script local index, agent instructions, remote wrappers, Codex/Claude registrations, real MCP call, and passing doctor/Rojo/Selene/StyLua checks. See .rbxmap/START_HERE.md. Game source and Git staged state unchanged; no commit or push.
- Limitations: Claude CLI absent; new agent-session loading and Studio appearance unverified. Remote scanner retains generic dynamic-name rows. README argument order is wrong: put --project before serve/doctor.
- Next: restart Codex and test find_script; optionally install/start Claude Code. Reconcile existing Studio-only edits before Rojo syncing.

## 2026-10-06: Lobby HUD restyle
1. Done: `UI/Lobby.luau` profile card and departure panel have no background; their text is bolder with a dark outline (white text, brass for BRASS). OUTFITTER is now a dark Secondary button like LINE MASTERY, and both sit in a row under the profile card on the left. Checked in Studio play, console clean.
2. Known issues: none. `Ui.ticket` is no longer used by the lobby.
3. Next: check that the outlined text reads well over bright lobby floor tiles at small screen sizes.

## 2026-10-06: Lobby HUD tweaks
1. Done: `UI/Lobby.luau` name reads `OPERATOR: <name>`; CREW RANK/XP line is Oswald Bold 20 (was 17); PROGRESS NOT SAVED is white Oswald Bold 17 (was red BuilderSans 13); LINE MASTERY now stacks under OUTFITTER with 8px gap; PROGRESS NOT SAVED sits left-aligned just above OUTFITTER. Studio play checked, console clean.
2. Known issues: very long display names may overflow the 260px name label.
3. Next: same as above (readability over bright tiles).

## 2026-10-06: 1800s locomotive look
1. Done: `Builders/TrainBuilder` locomotive now has a flared balloon smokestack with a brass rim (top still named ChimneyTop), a large brass-trimmed oil-lamp headlamp box with a peaked hood, a brass bell between the domes, and red driving wheels (`C.driver`). `lune run check` passes (audit clean); Studio Play console clean.
2. Known issues: not visually confirmed in Studio (train is built at runtime and the lobby is dark, so the screenshot showed nothing).
3. Next: eyeball the locomotive in Play (lobby display train); consider a wooden 1800s cab with arched windows and a slatted cowcatcher.

## 2026-10-06: full 1800s train restyle
1. Done (`Builders/TrainBuilder`, `Config/Cosmetics`): wood-plank coach siding, twin round-topped sash windows with mullions and sash bars, clerestory roofs with amber lights, queen-post truss rods; 4-4-0 locomotive (two red-spoked drivers that spin, brass splashers), Russia-iron boiler with brass domes, wooden cab with roof cap and ventilator, red slatted V cowcatcher, flared tender boards. Default livery is now "Heritage Mahogany" (mahogany, brass, green doors). Check passes (Train 1626 parts, audit clean); seen in Studio Play lobby, console clean.
2. Known issues: car size kept (seats, spawns, volumes, breach anchors depend on it). Other liveries still repaint the wood. Headless preview needs `npm install` in tools/preview.
3. Next: ride a run and look at the loco up close (spokes, pilot, stack smoke) in daylight.

## 2026-10-06: Display train gap barriers
1. Done: `Builders/LobbyBuilder` adds invisible `GapBarrier` parts in the four gaps between the display train's cars (ballast to roofline, tops flush with the roofs; gangway gaps fill only the open sides so the gangway stays walkable). `lune run check` passes; Studio play console clean.
2. Known issues: collision not walk-tested by hand. The live run train's gaps are untouched.
3. Next: the older request: per-car outward-swinging doors, solo ready, and car party rooms (up to 4) that auto-ready.

## 2026-10-06: Saloon and workshop split into four cars
1. Done: `Builders/TrainBuilder` splits the crew saloon (-63..-44.5, -41.5..-23) and workshop (-20..-1.5, 1.5..20) with covered gangways. Every carriage's double doors are now 5.6 wide and 7.5 tall (were 5x7); passenger walls pack windows between the ends and doors. Short cars put their bogies nearer the ends. `Builders/TrainInterior` moves the bays, route table (2nd saloon car, platform side), workbench/lathe (1st workshop car), cabinet (STORES car) and adds signs, pictures and car boards (LAST TRAIN OUT, CREW SALOON, WORKSHOP, STORES). `LobbyBuilder` adds gap barriers for the new gaps. Check passes and the Studio display train looks right; the console is clean.
2. Known issues: the saloon has 5 bays (10 seats), down from 8 bays, because of the extra door.
3. Next: ride a run and check boarding through the new doors and the route table and workbench prompts.

## 2026-10-06: Boarding cars (party doors on the display train)
1. Done: all 5 display-train carriages (Stores car included) are boarding rooms. Hold E (tap on touch) at the door to board or get out. 2-4 players per car. The 40s countdown starts at 2 aboard and starts over when anyone gets out or drops. People can get out before the countdown starts and in its first 10s. A full car, or a countdown reaching 0, blacks the screen and teleports the car to a reserved server, which starts the run (Boarding, then route vote) once the car arrives and sends everyone back to a public hall after RunEnd. In Studio the run starts on this server instead. Being aboard counts as ready: the Ready panel hides and the solo Ready flow ignores car players. Green floor-edge glow pulses while a countdown runs. Gangways and the brake van's rear doorway are sealed. Files: `Logic/CarBoarding` (+spec), `Services/CarService`, `UI/CarBoarding`, `Config/Tuning.Cars`, small edits in TrainBuilder (cabins), LobbyBuilder, LobbyService, RunDirector (`Launch`), Lobby UI, UIController. Check passes; Studio: board/exit verified solo, console clean.
2. Known issues: the 2+ player countdown, black screen and departure are unit-tested only, not playtested. Teleport works only in the published game. Prompt chips do not appear in MCP screenshots (the hold still triggers).
3. Next: Studio Test > Clients and Servers with 2-4 players to confirm the countdown, exit lock, black screen and the Studio launch. Then publish and test a real teleport.

## 2026-10-06: train car clutter removed
1. Done: `Builders/TrainInterior` no longer builds the saloon table items (cups, books, candles), rack luggage and hat box, the stove's kettle, the guard's teapot and cups, the workshop drawer cabinet, anvil and chain hoist, or the spare wheel. All light sources (table lamps, stove, lantern, desk and bench lamps), paintings, signs, tables and chairs stay. `Builders/TrainBuilder`: car 3's route table (and its brass label, and the unused `routeTable` field) removed. Check passes; Studio Play console clean.
2. Known issues: not visually inspected inside the cars.
3. Next: walk the cars in Play to confirm the look.

## 2026-10-06: Lobby piano music and notes
1. Done: Satie's Gnossienne No. 3 (APM, id 1837474268, cue `LobbyPiano` in `Config/Audio`, volume 0.48 after a +20% bump) loops from a hidden `PianoVoice` part in the lobby piano (`Builders/LobbyBuilder`), full volume across the whole hall (roll-off min 170, max 180 studs). New client `Controllers/PianoNotes` floats gold/cream/amber note glyphs off it (rise, sway, fade over 3-4.6 s; none when the camera is >110 studs away). Notes checked in Studio play, console clean; `lune run check` passes.
2. Known: music audibility/volume not checked by ear (MCP can't hear audio).
3. Next: listen in Studio and tune `LobbyPiano.volume` or the roll-off if it masks the DepotHall bed.

## 2026-10-07: Station layouts (streets, squares, yards, sidings)
1. Done: every station except the Terminus has a `layout` in `Config/Stations` (Street, Plaza, Yard or Sidings). `Logic/LayoutGen` now carves the routes first, then places buildings and structures on lots facing them. Plazas get a Fountain in the middle and stalls around it. Barriers (fences, walls, Wreck) close parts of the Near/Mid and Mid/Far boundaries, leaving the routes open and every tile reachable. Broken ground goes beside the routes. ToolChests and Crates lean toward the Far zone (`Stations.FarLoot`). New basic-part builders in `Builders/StationDressing`: Siding, Wreck, Rubble, BrokenRoad, Deck, Trench. Spec: `tests/StationLayout.spec.luau`. `lune run check` and `AUDIT_SEEDS=6 lune run audit` pass. Station parts at seed 424242 are 2666-3720 (budget 4200), 5-22% heavier; the Terminus is unchanged.
2. Known issues: not yet checked in Studio. Hollows walk straight at their target (MoveTo) and may catch on barrier runs. Pre-existing z-fights on other seeds, outside these files: DecorCrates (Infirmary, seed 1234) and Hotel interior (RailwayHotel, seeds 7/1234/98765).
3. Next: walk a few stops in Studio and check that Hollows get through the barrier gaps. If they get stuck, lower `layout.fill`.

## 2026-10-07: Train interior and run HUD pass
1. Done: paintings are full scenes (sky, orb with halo, peaks, lake, viaduct with a train and smoke, pines, signal, telegraph poles, varnish) with a gilt slip and a titled brass plaque (`Builders/TrainInterior`). Saloon seats are single window seats (aisle seats removed), smaller, with smaller tables; the guard's van chair in the doorway is gone and the other is 0.88 scale. A red runner with gilt borders runs from the workshop to the guard's van, cut at every car end (`Builders/TrainBuilder`). Route vote cards are black, with danger boxes, Montserrat type and a dossier arrow that opens a paper sheet in mid-screen (`UI/RouteVote`). Gauges: solid black, figure between label and neon tube. Roster is OPERATORS with call signs (A1, B4...). `lune run check` passes; Studio Play console clean; cards, dossier, HUD, saloon seats, runner and paintings seen on screen.
2. Known: the guard's van was not reached on screen (character navigation could not route there). Call-sign letters follow sorted user keys, so a player leaving can shift later letters.
3. Next: look at the guard's van and the paintings up close in Studio.

## 2026-10-07: Opt-in run difficulty tiers
1. Done: tiers 1-5 (`Config/Difficulty.RunTier`, `Logic/RunTier`). Host = longest-present hall player; picks with < > in the lobby, capped by the lowest `profile.unlockedTier` in the hall (and re-capped by the actual crew at Boarding). Each tier above 1 adds 0.06 to every stop's D and +20% Brass ("Tier N bonus" line, before charter/daily). A Victory at tier N unlocks N+1. Tier shown in the lobby and the run receipt ("RUN TIER N UNLOCKED"). New remote `SetRunTier`, state `lobby.tier` and `run.tier`. `lune run check` passes (new `tests/RunTier.spec.luau`); not played in Studio.
2. Known issues: saving only verifiable in a live server. The in-world departure board text does not show the tier.
3. Next: in a published server, win a tier-1 run and rejoin to confirm tier 2 stays unlocked.

## 2026-10-07: landmarks, upstairs fixes, crate z-fight, stairwell width
1. Done:
   - b270c15: landmarks: Halt hamlet, Minehead pit row, Coaling Yard engine shed, and a decor flag on landmark rules.
   - ccb4303: `BuildingService.IsLitAt` now counts upper floors. Its 2.02 lift on the stacked DecorCrate did not remove the z-fight.
   - 54789c0: leftover loot pickups spawn on the container's own floor (upstairs too).
   - This task: `StructureKit` `Props.DecorCrates` draws the second ground crate 0.03 shorter (bottom still at y 0; same rng calls, sizes, positions and count). The z-fights at Infirmary seed 1234 and Halt seed 7 are gone, and no other station or seed changed. `Config/Buildings` `Furniture.Stairs.d` went from 4.6 to 6.2 (School, Clinic and Hotel are the only users), so the doorway at the top of the ramp is 6.0 wide and Hollows can path up. The ramp still clears the stairwell door by 14 studs. Tiles, Hollow cap, stay time and part counts are unchanged on seeds 424242, 7, 1234 and 98765. `lune run check` and `AUDIT_SEEDS=6 lune run audit` pass. Not playtested in Studio.
2. Known issues: upper-floor Hollows have no teleport recovery if stuck.
3. Next: in Studio, watch a Hollow climb the School, Clinic and Hotel ramps.

## 2026-10-07: Hollows climb the stairwell ramp
1. Done: Studio playtest found Hunt Hollows stuck at the foot of the Clinic ramp. Cause: the ramp foot sits 2 studs from the stairwell wall, so the 2.2-radius path agent found no way onto it (radius 1 does), and with the target in sight they walked straight into the ramp's side. `HollowService`: walk straight only when the seen target is within `SameFloor` (4) in height; retry a failed path with `NarrowRadius` (1); a hunter that stays within `StallRadius` (2) for `StallSeconds` (2) drops its path and follows a fresh one for `StallRepath` (3) s. New constants in `Config/Tuning` `Hollow`. Verified in Studio at Brannoc Infirmary: a Stalker went from the ramp foot to the landing in about 2 s, and two followed back down. No console errors. `lune run check`: format, lint and types pass; 140/141 tests pass. The one failure (Difficulty dwell range) comes from the uncommitted `Config/Difficulty` Dwell change, not this task.
2. Known issues: the upstairs ward beds leave gaps a 2.2 agent cannot pass, so Hollows reach the landing but only reach the rest of the Clinic upper floor through the narrow fallback. The stairwell ground floor has no light. Not yet watched on the School or Hotel ramps. Uncommitted Difficulty Dwell change fails `tests/Difficulty.spec.luau`.
3. Next: decide on the Difficulty Dwell change (update the spec or revert), then check the School and Hotel ramps and the escape window, moonlight and upstairs loot in Studio.

## 2026-10-07: dwell spec fixed, Brief D platform-side guard
1. Done: `tests/Difficulty.spec` dwell range now 94-148 s (task 002's Dwell change, kept). New `Run.spec` guard: stations dock on +Z (`PlatformEdgeZ > 0`), which the Last Call door lamps rely on. `lune run check` passes (167/167). Studio Play boots to a docked stop, console clean.
2. Known issues: Last Call door lamps not yet seen on screen; station sliding away mid-jump during the chase not playtested.
3. Next: task 002 Studio checks (distant player chased by the wanderer, sleeper counts small vs large stops), then mark 002 done.

## 2026-10-07: task 002 Studio acceptance (done)
1. Done: Studio playtest. Wanderer spawned (Prowl) at stop 3 Market, ran ~120 studs to a lone player on the far platform and took them ("Taken at stop 3"); it correctly ignores players still aboard. Sleepers live: Halt 3, SignalWorks 2, Market 2, matching a headless LayoutGen sweep (one-building stops 2, Halt 3, CoalYard/Schoolhouse 5, PostTown 6). Sleepers scale with building tiles, not platform depth. Last Call door lamps: 6 LastCallLamp PointLights turn on at T-0 and off 3.1 s later when the station pulls away. Task 002 marked done.
2. Gap jump: the user tested the last-second jump by hand in Studio and it works (a scripted bot jump 0.4 s after pull-away missed; that was the script, not the game). `Dev warp` moves only the hazard clock, not `departAt`, so Last Call has to be waited out in real time.
3. Next: the first unchecked item in TASKS.md.

## 2026-10-08: Brief F, run ticket book (task 010)
1. Done: `Logic/RunLog` (pure) builds a `run.log` entry per resolved stop (`Types.LogEntry`): stop, name/type/danger/km, coal burned, vote split per option, unanimous (2+ ballots all for the winner), mystery and whether it was revealed, close-call display names (CrewService.ResolveDeparture now returns them), outcome (Cleared/Victory/Wiped/Derailed). RunDirector builds it at Cruise, reveals it at Arrival, appends it when the stop departs (Wiped if the last of the crew was left behind) or at RunEnd; reset at Boarding; late joiners get it in the snapshot. `UI/TicketBook`: B / D-pad left opens the book in a run (stubs on an inked track, CLOSE CALL, GAMBLED · PAID OFF / LOST, UNANIMOUS word stamps from new `Stamp.word`). `UI/RunCard`: at RunEnd a 1056x594 card above the receipt with crew headshots, the track in rows of 6 with a stamp cascade, km/coal/stops/close calls and the final stamp (TERMINUS, LOST/DERAILED AT STOP n); CLOSE, backdrop or B close it, H hides CLOSE. No DataStore writes. Spec `tests/RunLog.spec.luau`. `lune run check` passes; Studio play checked (see task 010 notes), console clean.
2. Known: per-stop loot and downs are not logged (no per-stop source exists; fields left out). The Victory card (TERMINUS) was not reached in Studio. `run.stationsCleared` still counts a stop where the whole crew was left behind (pre-existing). No asset placeholders.
3. Next: play a full run to the Terminus and check the card with 10+ stubs (two rows) and the TERMINUS stamp.

## 2026-10-08: Brief F follow-ups (task 010 known issues)
1. Done: per-stop haul. `CrewService.Downs()` counts eliminations this run; RunDirector snapshots stats (coal/parts/relics) + downs when each stop resolves and logs the difference as `LogEntry.haul` (`Types.StopHaul`, via `RunLog.haul`). `RunLog.haulText` prints "x12 COAL · 3 PARTS · 1 DOWN" under each stub (TicketBook/RunCard, scaled to the stub width); totals add LOOT and DOWNS. A stop where the whole crew is left behind no longer adds to `stationsCleared` (run, stats and payout). Spec added in `tests/RunLog.spec.luau`; `lune run check` passes. Studio Play: a full run to the Terminus showed 11 stubs in two rows (6+5), the TERMINUS stamp, haul lines on the 3 stops with coal and "48 LOOT · 0 DOWNS"; a left-behind wipe at stop 1 logged cleared=0, "x8 COAL · 1 DOWN" and LOST AT STOP 1. Console clean.
2. Known: downs count every elimination (including Fell/LeftBehind), not only Hollow takes; a rescued player's down still counts. Close calls/downs were not seen with 2+ players.
3. Next: decide whether a down should feed the payout or a stamp (e.g. a "NO DOWNS" stamp).

## 2026-10-08: Visual overhaul ("night mail" art direction)
1. Done: palette (Theme): grey-green Edmondson card replaces cream ticket stock, cooler whites, fog-teal accent for selection; no cream left in UI, signs, posters, notes, liveries or cosmetics. `Ui.button` is an enamel plate (keel, hover sheen, pressed collapse, gamepad corner brackets, dull disabled; `Ui.setButtonStyle`). Lobby UI: crew pass card + platform indicator with ready lamps. Modal shell: iron header, brass rule, corner rivets. Outfitter cards show item thumbnails (milliner's dummy for hats). Train: varnished panelled body with gilt beading, open clerestory ceiling with long-rod gasoliers, green lincrusta, raised wainscot fields, mahogany frames, teal/LTO antimacassars, banker's-green lamps, Mansell-wheel bogies on leaf springs (Train audit budget 1800 -> 2000). Depot Hall: slate flags in bays, oxblood quarry walk, green glazed dado, amber lamp glass, cooler fill/ambient (same luminance); six posters redrawn in new `Builders/PosterArt`. Stations: teal enamel running-in boards, typeset timetable bill. `lune run check` passes; Studio Play checked lobby, saloon, exterior, HUD, Outfitter, Line Mastery and two stations; console clean (DataStore 403 only).
2. Known: warm lamp/night grading still warms pale colours, so world whites are deliberately blue-leaning; check by eye. Not seen this session: Workshop modal, route vote, summary/run card, tablet/phone sizes (only the UIScale math was checked). No uploaded assets (kept the no-upload rule; Blender not used).
3. Next: look at the Workshop, route vote and run card with the new plates; check the lobby on a phone-size viewport; tune `C.paving` if the hall feels too dark.

- Brief 011 planning validation: lune run check passed (2026-10-08); no lighting implementation or Studio visual acceptance yet.

## 2026-10-08: Refuge pass (train budget, palette under light, unverified screens, phones)
1. Done:
   - Train budget back to 1800 (`.lune/audit.luau`): 1960 -> 1752 parts, 440 -> 375 colliders. Bogies keep their silhouette (bolster, deeper side frames, Mansell tyre + teak centre) but lose hub bosses, axle boxes and springs, and no longer collide or cast shadows (they sit below the platform edge). Window heads: 4 corner wedges -> 3 spandrel blocks per bay. Clerestory glazing bars ~4.8 apart, spread evenly. Curtained windows: the valance covers the head. Matched Studio test (edit mode, 8 trains, same script on old and new code): build 28.6 -> 25.8 ms median per train, graphics part memory 11.0 -> 9.4 MB, physics 19.3 -> 18.0 MB; frame time showed no measurable difference (CPU ~5.0-5.3 ms, GPU 5.2-5.9 ms both, within noise). The train exists twice in a lobby server (display + run), so the savings count twice.
   - Palette under light: the lobby's full-frame warm tint (`Sky` lobby state, 255/238/222) was what turned whites cream and the mahogany flat red; now near-neutral (255/251/248), saturation -0.06. Heritage livery and TrainBuilder base: mahogany 60/33/28, aged brass trim 150/120/74, deep green doors 38/70/58 (readable entrances from the platform), lamp 240/184/116. Lobby: aged brass/gilt, deeper amber lamp glass (`C.flame`), whitewashed platform edge (was saturated yellow), cool coping stone, paving a step lighter, pendant lamps 0.7 -> 0.9. Interior brass aged to match. Boarding glow is signal green (96/214/150), not neon.
   - Care/refuge: tea tray with a brown betty and two cups, a folded blanket, a darned seat back in the saloons (+7 decor parts). Audio "shelter" (`AudioController`): aboard during a run the outside beds (wind, eerie, drone, howl) drop 45% and lose highs/mids through an EQ, and the Depot Hall room tone returns at half level (the lobby's sound inside the train); stepping off brings the outside back fast (half-life 0.35 s), boarding settles in 0.8 s.
   - Screens: route vote tickets were pushed right by the tie note sitting in their list layout; tickets now in their own row, centred, with the tie note on a soot-iron strip. Workshop rows show LV n/m, larger pips and the state on the plate (FIT · n PARTS / NEED n MORE / FULLY FITTED; hull SOUND/NEED n MORE). Disabled plates stay legible (shade dulls, label stays opaque). Run card: stubs sized to the run (up to 4 large, 5-6 per row for long runs), rows centred, brass rule, totals pulled up. Receipt sizes to its contents; success lines in `Theme.Color.goInk` (dark green on card), mastery no longer printed in failure red. Outfitter: selected outline no longer clipped, lanterns framed whole, EQUIPPED/TODAY tags readable.
   - Phones/tablets (Studio Device Simulator, iPhone XR 896x414, iPhone 7 667x375, iPad 6th gen 1024x768): `UIController` sets a `Compact` attribute and a larger scale on short touch screens (0.6 -> 0.76 on iPhone XR); modals shrink to fit the safe area (`Modal`); on touch screens the feed moves to top centre (it sat on the thumbstick) and the pocket watch lifts above the measured jump/RUN buttons (and draws at 80% on phones) so it no longer covers them.
   - Blender (5.2, headless): `tools/blender/mansell_wheel.py` builds `assets/blender/MansellWheel.fbx/.blend` (1308 tris, 0.84x3.2x3.2 studs, axle on +X, origin at the centre, iron/teak vertex colours, preview `docs/compare/blender_mansell_wheel_preview.jpg`). Not in the game: using it needs an upload (the 3D importer uploads), which waits for the user's yes. It would replace tyre + teak per carriage wheel (-52 parts per train).
   - Evidence: matched before/after captures in `docs/compare/` (same camera and state): lobby hall, long view, platform/train, saloon, HUD, Outfitter, Workshop, route vote, run card, receipt, station platform; phone and tablet after shots plus phone before shots.
   - Checks: `lune run check` passes (193 tests, audit clean: Train 1752/1800, Lobby 1304, 0 z-fights, 0 clashes). Studio console: only the known DataStore 403 and `Arvo.json failed to load: Temp read failed` (Studio font cache, appears every boot, also before this pass).
2. Known: gamepad navigation not verified (Studio's VirtualInput refuses ButtonB). Modal body text on phones is still small (the modal fits but is drawn at ~0.6). The quarry-tile walk still shows bright grout lines and the rosette brass still reads yellow under the pendant (left alone: another session is editing that area). Station grading at the first stops is warm dusk by design of the sky keys; the colder outside is carried by sound and the later night stops, not changed here. `after_lobby_spawn_hud.jpg` and `after_saloon.jpg` were shot before the door green changed. The vertex colours of the Blender wheel are not verified inside Roblox.
3. Next: decide on uploading `MansellWheel.fbx` (then a `Config` mesh id and a MeshPart path in `TrainBuilder.bogie`, keeping the primitives as the fallback); give modals a compact phone layout; check gamepad by hand.

## HUD toggle hides lobby cards (2026-10-11)
1. Settings HUD = Hide now also hides the lobby's crew pass, Outfitter/Line Mastery, tier bar and waiting box; the Settings button moves to the top left (14,14) and returns when HUD is shown.
2. Hidden state not playtested by tool (needs a click in the Settings menu); shown state verified, no console errors.
3. Next: confirm in Studio by toggling HUD in the lobby and in a run.

## Lobby pass (2026-10-15)
1. Done: storm skyline removed from the back windows; bookcases solid; ticket booth set into the back wall (wall opening cut); outfitter colour posts and back board removed; back-wall sconces replaced by gas lamp standards (range 30 -> 31.5 on all eight); piano chair back removed; lobby seats sit on touch (no prompt), 1.5 s retouch delay.
2. Known: the playtest screen capture came back dark, so the look still needs checking by eye. Count the hall's lights against the audit budget if it complains.
3. Next: walk the lobby, try every seat and check the booth opening from both sides.
- Follow-up: floor now meets the end walls (the corner gap is gone), black ground under the hall, the waiting-corner bookcase replaced with a glazed one, a new palm, the window backdrop widened and lowered with no horizon band.

- Lobby storm flash: hidden PointLights (range 34) replaced by SpotLights aimed through each pane at the floor strip under it; amber hall lamps no longer washed white. Lobby audit light budget failure predates this.

## 2026-10-15 lobby night lighting
1. Lobby lit only by its lamps: LOBBY ambient/outdoor near black, sun off, sky diffuse 0 in lobby, hall FillLights removed. End gables are brick right up to the roof (no sky gaps).
2. Known: none seen; lobby is intentionally dark, tune LOBBY.exposure in Scenery/Sky if too dark.
3. Next: add lamps to any corner that reads too dark.

## 2026-10-15 Run Tier button removal
1. Completed: removed the lobby Run Tier plate, input handlers, and UI refresh references. AGENTS.md now gives Codex and Claude Code the same implementation role and project checks.
2. Verification: Studio lobby playtest screenshot confirms no Run Tier plate and Ready remains visible. Console reports DataStores unavailable, fixed-size EditableMesh warning, and Roblox FoundationProvider warnings; no Lobby UI errors observed. Ready/Join interaction not exercised. Full check result recorded in task 014.
3. Next: manually click Ready/Unready and verify Join during a run.
- Check result: lune run check passed (361 tests, clean visual audit; existing deprecated API warning).

## 2026-10-17 Merge completed Claude work and Prompt 5
1. Completed: integrated the Run Tier UI removal, Studio photo tool, developer documentation/index updates, and Prompt 5 lobby shell. Lobby lighting files and fixtures were not changed during integration.
2. Verification: full gate result recorded below. Studio has no connected instances, so this integration was not playtested; prior UI verification is recorded above.
3. Next: reconnect Rojo in Studio, stop/start Play, check Output, exercise Ready/Unready and Join, and try /photo in an open clearing.
- Check result: lune run check passed, including formatting, lint, strict type analysis, tests, and clean visual audit. PhotoCommand received strict annotations and formatting fixes before validation.
