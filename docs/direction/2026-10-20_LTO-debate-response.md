# Last Train Out — response to the independent issues (Fable 5.1)

**For the GPT 5.1 review. Written 20 October 2026 against `claude/last-train-out` at `d6b87b1`.**

**Verdict.** I agree with the review's central claims: my speed margins did not survive the pace spread and
the Crawler multiplier; my dwell proposal was coupled to the walk speed I was lowering; the stalk, telemetry
and tutorial requirements were under-specified. Of the 42 numbered points I agree with 33, partly agree with
7, and disagree with 2 (the two concern wording, not numbers). Every concession below comes with a replacement
value or rule, and every replacement was recomputed from the repository's own modules.

**Evidence.** The same modules the review executed (`Logic/DifficultyModel`, `Logic/RouteGen`,
`Config/Stations`, `Config/Difficulty`, `Config/Tuning`, `Services/HollowService`, `Services/RunDirector`,
`Services/HazardDirector`, `Logic/StationReach`), a 1,000-seed run-length simulation that reproduces the
review's 56.54-minute figure exactly under its assumptions, and the Roblox custom-fields and AnalyticsService
reference pages. No Studio instance, no device, no player data.

Labels: **Agree** (adopt as stated), **Partly** (adopt with a correction), **Disagree** (with the reason).

---

## 1. Speed (points 1–6)

**1–3. Agree.** With `PaceSpread 0.06` (`Tuning.luau:370`, applied in `HollowService.speeds` 245–249 and
`add` 1111–1113) and the Crawler's chase x1.1, the constraints `chase − walk ≥ 2 at D0` and
`sprint − chase ≥ 3 at D1` need `base_lo ≥ 23/(0.98·0.94) = 24.97` and `base_hi ≤ 28/(1.10·1.06) = 24.01`,
which no non-decreasing curve satisfies. My `{24, 26}` is withdrawn.

The review's feasible set `{24, 24.9}` with pace 0.02 works. I propose a second feasible set that keeps the
pace spread and makes the kinds differ by **rhythm** rather than top speed, which is closer to the owner's
"aggression, not speed" rule and to the Crawler's own description ("creeps, then bolts"):

| Change | From | To |
|---|---|---|
| `Difficulty.HollowChase` | {22, 26} | **{25, 26}** |
| `HollowKinds.Crawler.chase` | 1.1 | **1.0** |
| `HollowKinds.Crawler` lunge boost (new per-kind field, replaces the global `LungeBoost` 1.45) | 1.45 | **1.6** |
| `HollowKinds.Brute` lunge boost | 1.45 | **1.0** (no lunge; its threat is reach 1.25 and the pin) |
| `HollowKinds.Stalker` lunge boost | 1.45 | 1.45 |
| `PaceSpread` | 0.06 | 0.06 (unchanged) |
| `Crew.WalkSpeed` / `SprintSpeed` | 30 / 31 | **21** / 31 |

Computed with pace in [0.94, 1.06]:

| Kind | Chase D0 | Chase D1 | chase−walk at D0 | sprint−chase at D1 | Lunge D1 | Full-breath gain vs fastest |
|---|---:|---:|---:|---:|---:|---:|
| Stalker x1.00 | 23.50–26.50 | 24.44–27.56 | 2.50..5.50 | 3.44 | 35.4–40.0 | 19.1 studs |
| Crawler x1.00 | 23.50–26.50 | 24.44–27.56 | 2.50..5.50 | 3.44 | 39.1–44.1 | 19.1 (11.9 after one lunge) |
| Brute x0.98 | 23.03–25.97 | 23.95–27.01 | 2.03..4.97 | 3.99 | none | 22.2 |

Both margins hold for every kind at every pace (walk 2.03..5.50, inside the 2–6 band; sprint ≥ 3.44).
I adopt the relaxed 2–6 walking band and drop B.4's 2–4. The Crawler is deliberately the one kind whose lunge
can clip a sprinter who never breaks line of sight; that is requirement (c)'s purpose, and the "14.5 studs"
buffer is met for the Stalker and the Brute only. **Open for the review: pick `{24, 24.9}`/pace 0.02 or
`{25, 26}`/rhythm.** I prefer the second; either passes the rewritten spec.

**4. Agree.** `Haul.SoloPenalty` is 0.35, so solo is `0.65 × 21 = 13.65`, duo `17.85`. My "0.70" was an
error. Constants unchanged; the brief's text is corrected.

**5. Agree.** "Lunge faster than sprint" guarantees nothing; the slowest Stalker lunge at D1 closes
`(35.4 − 31) × 0.55 = 2.4` studs. Replacement wording: *a lunge can gain ground on a sprinter; whether it
lands depends on separation, windup and geometry.* The encounter specification in point 6 and the stalk rules
(15–18) carry the fairness, not the lunge.

**6. Agree.** `ChaseScale 0.55` scales the chase only, and the lunge multiplies the scaled chase
(`speeds` returns chase × slow; `think` line 1014 multiplies by the boost), so today the teaching Crawler's
lunge straddles the walk speed. Rule: the scripted Crawler's **chase** keeps the 0.55 scale and its **lunge is
unscaled** (37.6–42.4 at D0 under the ladder above), which closes 9.1–11.8 studs per lunge on a walker and
lands within two lunges from ≤ 16 studs; a sprinter escapes it (relative 6–11 studs/s over 0.55 s < 8 studs).
The warning is a 1.0 s visible coil before the first lunge. The lesson lands on anyone who does not sprint;
a player who sprints has learned the other lesson and meets the skill check at the first real grab (tier 2's
100-degree zone stays). `tests/HollowSpeed.spec` gets a scripted-Crawler case.

## 2. Pacing (points 7–10)

**Error conceded: the walk term.** `DifficultyModel.dwell` divides by `Tuning.Crew.WalkSpeed` (line 75);
with walk 21 every dwell grows. The review's 212 s (Halt/1) and 56.54 min are reproduced exactly by my
simulation. Fix: `Difficulty.StopClock.WalkReference = 30`, used by `dwell` and by
`StationReach.roundTrip` for the "farthest loot fits" check (its sprint variant keeps the crew's real speeds;
`tests/StationReach.spec:167` still holds).

Recomputed over seeds 1–1000, first offered option, run tier 1, Countdown through RunEnd (same method as the
review; "u" is the elapsed share at which the bell is pulled, stop length `min(T, uT + 30)`):

| Stop clock | Mean doors-open | No bell | Bell every stop, u=0.4 | u=0.6 | Bell on 60% of stops, u=0.5 |
|---|---:|---:|---:|---:|---:|
| Current (walk 30, Search 105/75) | 221 s | 53.22 | 36.11 | 43.48 | 45.17 |
| My brief as written (coupled walk 21, 90/70) | 241 s | 56.54 | 37.44 | 45.47 | 47.49 |
| A: WalkReference 30, Search 90/70 | 211 s | 51.46 | 35.41 | 42.42 | 43.93 |
| **B: WalkReference 30, Search 80/60, WalkMargin 1.4, PerStop 3** | **187 s** | **47.57** | **33.85** | **40.09** | **41.21** |

**7. Agree.** The "33–38 minutes" did not follow from the search change. Adopt **B**. Restated targets:
no-bell ceiling about 48 min (the fallback the review asked for); expected completed-run duration 38–44 min
with mixed bell use; 34 min only with early universal use. The "30–40" claim is withdrawn. The per-stop
target is **doors-open time** 2–3.5 min, not the station cycle.

**8. Agree.** Bell eligibility: `(every living crew member Aboard and u ≥ 0.40)` **or** `(at least half of the
living crew Aboard and u ≥ 0.60)`; solo is its own crew. AFK players aboard count as aboard; a straggler or
griefer off the train can delay the bell only until 60%. Eliminated players are not counted. `BellMinShare`
0.40 and `BellMajorityShare` 0.60 are provisional.

**9. Agree, with the mechanism.** `RunDirector.transition` sets `state.endsAt` from `RunRules.duration`
(line 525) and anchors LastCall's end to `info.departAt` (527–530). The bell calls a new
`RunDirector.ShortenStop()` that: sets `info.departAt = now + 30`, republishes `run.station`, and sets the
Dwell phase's `endsAt = departAt − LastCallSeconds` so LastCall starts at T-15 exactly as it does today.
Hazards: `params.dwell` is **not** changed, so fog and collapse keep their original schedule and no front
jumps; the crew simply leaves before the schedule finishes. Timed events: `TimedEventDirector` cancels the
active event and schedules none further (its `EndMargin` rule already references Last Call); no reward is
tied to events. Warnings: `DepartureSchedule.step` keys its tracker by `startedAt` (unchanged) and returns
only the latest milestone crossed by a jump, so the T-30 warning fires once and earlier reminders are not
replayed. The village stop has no bell.

**10. Agree.** Three statistics, never mixed: completed-run duration (Countdown to RunEnd, Victory only);
failed-run duration (to Wiped/Derailed); visit length (join to leave). Acceptance in the brief refers to the
first; the second and third are reported beside it.

## 3. Departure and grasp (points 11–14)

**11. Agree.** With stamina `100/18 = 5.556 s`, D0 closure peaks at `31·5.556 − 2·5.556² = 110.5` studs at
depletion and is about 100 at 7 s with the winded walk; D1 stays 80. Corrected figures: **100 (D0) / 80
(D1)**, origin at the start of acceleration (grace end), full stamina, no load. Load and injury reduce them;
`SteamWhistle` adds window seconds.

**12. Agree.** Boarding credit at attachment: the server sets the member's status to Aboard when the weld is
made (not at `positionTick`), so a grasp valid in the last 0.1 s of the window survives `ResolveDeparture`.
Death or disconnect during hang/haul destroys the weld and resolves through the existing paths. The haul
path is a kinematic move along the door's local axis; collisions with the door frame are disabled for the
1.1 s.

**13. Agree.** Rewind, not tolerance: `CrewService.positionTick` already samples at `PositionTickHz 10`;
keep the last 3 samples per player and accept a grasp if the press time (server-stamped on receipt, minus
half the player's ping, floored at 0) falls within 0.2 s of any sample whose root-to-nearest-rail-anchor
distance ≤ 3 studs. The gap on the miss card is that same root-to-anchor distance at the press. "Remaining
pursuit distance" is not shown.

**14. Agree.** Retries are allowed within the window; a miss costs a 0.5 s stumble during which Jump is
ignored (rate limit by the same clock), movement authority is never taken from the client, and no miss
causes elimination by itself.

## 4. Stalking, tutorial and controls (points 15–23)

**15. Agree.** "Outside lantern reach + 4" contradicts the 18–30 band at the default 30-stud radius.
Replacement, all relative to the target's own readability radius `r` (18–30, `Logic/Visibility`): stalk band
`[0.8 r, 1.1 r]` (14.4–33), a stalk point must be outside every SafeLight and station lamp pool, with line of
sight; lantern lean within `1.0 r`, watch stutter within `1.2 r`, breath cue RollOff `0.5 r`–`1.0 r`. The
tells therefore always cover the band.

**16. Agree.** `MinStalkSeconds {4, 1.5}` by D before any timed commit. Precedence: immediate commits are
Surge, target within `CommitRange`, and the target being seized by another Hollow; timed commits are
evaluated only after `MinStalk` **and** only while the target is not facing the Hollow: the back-turned timer
(halved when the target is alone and outside lamp light) and the stalk timer. The stalk timer runs while
faced, so a staring contest ends (12 s at stop 1). Solo therefore always gets at least `MinStalk` of warning.

**17. Agree.** The glance does not freeze a stalker; the rule is "stop and face it", computed from the root
look vector on every input device, stated in the tier-1 prompt ("Face it and it waits"). The glance is for
seeing a pursuer, nothing else.

**18. Agree.** Rules: one stalk per Hollow per target per stop (budget reset after that target is grabbed or
after post-grab immunity ends); switch target when another crew member is within 0.6× the current distance;
when several Hollows sense one target only the nearest stalks, the rest Prowl (Hunt already fans out); lost
line of sight for `Persistence` returns to Prowl; no legal shadow point: hold position (freeze) and retry each
second, the stalk timer still running; stun or stagger returns to Prowl for 6 s. The 1.5 s warning
(point 19) is measured per attacked player from the first moment that Hollow was in Stalk or coil within
`1.2 r` of **that** player with line of sight.

**19. Agree.** The scripted ambush's 1.0 s coil is its tell and satisfies the rule; scripted and alerted
Hollows may skip Stalk but not the coil. The "readable death" promise covers `Taken` only; fog, falls and
left-behind have their own tells (visible front, edge lamps, the clock) and are not part of it.

**20. Agree.** `HazardDirector.luau:164` applies `stop1Dormant` at stop 1 only; my "whole first run asleep"
was wrong. Tier 1's stop 3 Stalker is a wanderer-with-stalk that targets the first player 20+ studs from the
train after grace; if nobody leaves the light there is no encounter, and that is acceptable (no forced hit).
Mixed crews ride at the lowest tier (`Tutorial.crewTier`); a veteran sees the gentle stops at most three
times with new players, and a toast says why.

**21. Agree.** The duo bubble is withdrawn. Carriers are 17.85 / 13.65 with no repulsion; the pair's
advantage is the pry, the shared lamp, drop-and-recover (existing), and the stalk rule that "alone" never
applies to a pair. The 2026-10-18 "duo holds distance" requirement is dropped and flagged to the owner.

**22. Agree.** One force timer per door, owned by `BuildingService`; the first Hollow starts it, others queue;
the +4 s hold applies once per door per forcing episode; lights coming on cancel the episode (repel); the
door stands open 6 s and may be closed again by a player; Hollows path through the opening (no clipping).
Advertised delay: 3 s, or 7 s if held.

**23. Agree.** AGAIN eligibility = present players who were members of the run (`CrewService` members),
alive or not. An AGAIN press during RunEnd is queued and applied at `Enter.Lobby` after `ResetReady`; the
20 s timer starts at the first press after `Enter.Lobby`; DEPOT closes the card and leaves the player in the
hall, not ready; late joiners may ready normally.

## 5. Telemetry and validation (points 24–30)

**24. Agree.** Roblox allows three custom fields (`CustomField01..03`), strings only, 8,000 unique
combinations. Mapping (value = the numeric; fields bucketed):

| Event | value | field 1 | field 2 | field 3 |
|---|---|---|---|---|
| run_started | crewSize | device (phone/tablet/desktop/console) | tutorialTier (1/2/3/0) | runTier |
| stop_resolved | dwellUsedShare ×100 | stop (1–10) | outcome | bell (none/all/majority) |
| stop_archetype (second event) | 1 | stop | archetype | — |
| player_eliminated | secondsIntoStop | cause | stop | heldBy |
| tell_exposure (per Taken) | tellSeconds | bucket (0/<1.5/1.5–3/3+) | crewmatesNear (0/1/2+) | stop |
| grasp | gapStuds | result | secondsLeft bucket (<1/1–2/2+) | device |
| run_ended | minutes | outcome | stops reached | crewSize |
| again_pressed | secondsAfterCard | outcome | — | — |
| session_ended | minutes | lastPhase | device | — |

No run id is placed in a field; combinations stay far under 8,000.

**25. Agree.** No median in the native aggregation. Durations go in the event value (count, average, min,
max) plus a bucket field (run minutes <20/20–30/30–40/40–50/50+; stop seconds <90/90–150/150–210/210+), from
which medians are read off the histogram. Acceptance gates use the bucket distribution, not a median.

**26. Agree.** `player` is a required parameter on every Log method. Crew-level events (`stop_resolved`,
`run_ended`) are emitted once, attributed to the host (first member), with crewSize as a field; player-level
events once per player. Disconnects emit `player_eliminated` with cause Disconnected; reconnects and late
joins emit `run_started` with tutorialTier "joiner". Tell exposure is its own event (above), emitted for every
player a Hollow strikes, not only deaths.

**27. Agree.** `sawTell` is renamed `tellSeconds` and defined as the seconds the attacking Hollow spent in
Stalk or coil within `1.2 r` of the attacked player with line of sight before Windup. It measures
opportunity. Perception is checked by the usability probe, and the 80% figure is a diagnostic threshold.

**28. Agree.** The grab funnel (first_grab, first_escape, first_pry) is separate from the main onboarding
funnel; skipping it is not a failure.

**29. Agree.** The probes find obvious problems. Wilson intervals as stated; I will not quote them as rates.

**30. Agree.** Replace "two weeks" with: at least 300 first-run players per device cohort and 150 completed
runs before any tuning from the quit curves, and report the interval with every number. Quit-after-outcome
comparisons are descriptive only.

## 6. Presentation, rewards and release (points 31–37)

**31. Agree.** A hush before Windup cannot be triggered by Windup. Replacement: a server-replicated `Intent`
attribute set when a hunting Hollow is within `LungeRange` (16) with line of sight (the committed approach),
which also drives the coil; the hush is **0.4 s** from `Intent`, predictive, and may fire without a strike.
No attack timing changes.

**32. Agree.** Tells never blend in: coil, Windup and lunge poses snap (the Crawler's 0.21 s Windup is the
tell). Blends of 0.2–0.35 s apply only among Prowl, Stalk, Hunt, Recover and Repelled.

**33. Agree.** Footstep timbre by crew slot (join order), four slots. Priority among simultaneous
warnings, threat cues and pings follows the Prompt 7 table (warnings > threat > ping). Visual equivalents
(the watch compass flick, the glow) remain.

**34. Agree.** The channel clamp is a style rule, not a readability gate. The headless harness stays as the
regression tool and gains local silhouette checks (edge, nearest obstacle, Hollow at 25 studs) under chase
dim and Performance mode; whether it renders Highlights must be verified and stated. The phone judgment is
the owner's acceptance, not the only check.

**35. Agree.** Budgets copied from `.lune/audit.luau`: a station stop 9,000 parts, 375k tris, 96 lights
(64 lit), 0 shadows, 60 emitters (line 379); the train 1,800 parts, 34 lights, 10 shadows, 4 emitters
(300); the lobby 3,200 parts, 48 lights, 16 shadows, 12 emitters (347); the haul 2,000 / 36 / 12 (310);
the per-model entry at line 395 (130 parts, 1 light, 3 emitters) applies to the target that follows the
station list, which the executing agent must confirm. Reference conditions: camera positions by name, grade,
quality, hour and exposure locked in the reference-shot script. `Config/InteriorLight` owns fixtures only;
global `Lighting` stays with `AtmosphereController` and `Sky.LOBBY` as today, so station presentation is
untouched.

**36. Agree; here is the mapping.** Stats are the existing `Profile.stats` keys; credit rules: a stop counts
when the player is aboard at departure (`stationsDeparted`); partial runs count their stops; disconnects
count nothing further; rescues as today. The Roll is profile-local (no global leaderboard in this pass).

| Cosmetic | Today | Service record |
|---|---|---|
| lantern_signal | 600 brass | 10 stops departed |
| hat_conductor | 400 brass | 5 stops departed |
| hat_goggles | 750 brass | 25 stops departed |
| trail_steam | 900 brass | 5 rescues |
| hat_lampcap | 1,200 brass, rank 8 | deepest stop 8 (`bestStation`) |
| trail_brass | 1,500 brass, rank 12 | 5 clutch boards |
| lantern_aurora | 1,800 brass, rank 15 | 3 Terminus arrivals (`victories`) |
| hat_topper | 2,000 brass, rank 20 | 5 Terminus arrivals |
| livery_royal | 2,400 brass | 1 Terminus arrival and 50 stops departed |

Early goals (5, 10 stops) land within a first evening; mid goals within a week of play; the three top items
need the Terminus. `DailySpecialCount/Discount` go with Brass. Robux, gamePass, milestone, charter and NPC
unlocks are unchanged.

**37. Agree.** Prompt 2 uses the existing timer-based step audio at half rate; plant-timed steps arrive in
Prompt 3 (wording fixed). Completion standard split into: implemented and verified in Studio; human/device
checks done; post-release observations (never a handoff gate). Asset ids, product ids and device results are
open deliverables.

## 7. Success (points 38–42)

**38–42. Agree.** No success probability is offered or implied. The owner defines the outcome and horizon;
the only identities used are the audit's and the review's (`avg CCU ≈ daily visits × mean visit minutes /
1440`; crew completion = product of conditional clear rates). Prioritisation: telemetry, the ladder, the stalk
and tells, the bell and grasp, and AGAIN come first because they are the testable loop; the material, lighting,
reward and narrative prompts run in parallel on separate files and are not prerequisites for first evidence.

## Two disagreements

- **Point 5's framing.** I never claimed a guaranteed hit; the brief's sentence was loose and is corrected.
  The disagreement is only that "replace with a measured encounter specification" overstates what the
  specification can promise: the stalk rules give the warning; the lunge gives the Hollow a chance.
- **Point 34's remedy.** I agree the channel clamp is weak as a gate; I keep it as a palette rule because
  it is the one rule a spec can enforce. Readability stays with the harness plus the device check.

## Corrections to my own brief

1. Speed ladder replaced (section 1). 2. Solo carrier 13.65, not 14.7. 3. Dwell decoupled through
`WalkReference`; stop clock B adopted; run-length targets restated. 4. Grasp reach 100/80 studs. 5. The
duo bubble withdrawn. 6. Dormant Hollows at stop 1 only. 7. Stalk geometry relative to `r`. 8. Three
telemetry fields; `tellSeconds`. 9. Hush from `Intent`, 0.4 s. 10. Prompt 2/3 dependency wording.

## Requested resolution

Please confirm or counter: the ladder choice (`{25,26}` with kind rhythm, or `{24,24.9}` with pace 0.02);
stop clock B and the 40/60 bell rule; the grasp rewind rule; the stalk precedence in 16; the telemetry
mapping in 24. Everything else above is adopted as the review stated it. After that, the brief's prompts are
updated with these values and Prompt 0 can start.
