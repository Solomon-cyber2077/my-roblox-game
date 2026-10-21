# Last Train Out: the professional layer

## Final design and implementation draft

Consolidated design direction and implementation prompts, dated 2026-10-20, revised after the final-draft review. This draft retains the original brief’s creative direction and scope and incorporates the final decisions. It is the working specification for implementation; it does not certify that the work is already implemented or that live validation has passed. Repository observations refer to `last-train-out` at `6333312` unless stated otherwise. The follow-up review at `cc777d7` informs the revised requirements; it does not replace the baseline evidence. Reconcile the current repository before editing. Baseline observations describe the starting point; the resolved design and FIXED requirements below define the intended final behavior.

Final review: the speed-scaled grasp allowance and the simplified payroll bound check are accepted as the implementation direction. The allowance remains provisional until the two-client network checks pass. The payroll arithmetic gives 84.17–102.95 s of nominal slack at D1, stop 10, before any additional delivery-approach or door time. Implementation and Studio acceptance checks below remain required.

Revision note (round 4, market layer): adds A.4 and Prompt 10 and changes five earlier decisions on market evidence: (1) Brass stays earned and spendable, with Line Mastery (merged with the planned service record) gating only the status items, and the whole reward set capped at three layers; (2) tier-1 stop 1 gets a scripted, harmless Stalker sighting instead of pure dormancy; (3) first runs default to a 5-stop Short Line, tested against the full route; (4) the build order gains a real-player gate (Milestone 1) before the presentation prompts. The reasoning, sources and decision rules are in A.4.

Revision note (round 5, Sol's six clarifications, all accepted): the discovery signals are corrected (playtime per user is a most-important signal; spend days counts Robux only; benchmarks do not affect ranking); Brass is kept provisionally, without a ranking claim; the Short Line is a hypothesis with its difficulty, sky, rewards and route policy specified; experiments are randomized per crew at exposure; the stop-1 sighting is placed inside the validated readable range with a minimum visible time; Milestone 1 includes the essential readability and sound work; G2 triggers a diagnosis, not a content freeze.

Revision note (round 6, 2026-10-21): adds the Budget and release decisions to A.4; G1 prerequisites (phone smoke test, durable telemetry read-back, recording consent), the G2 time box and icon testing and a budget-gate check to D.2, from the investment assessment. Canonical copy: `docs/FINAL-DESIGN.md` in the game repository.

Evidence labels: [OF] repository observation at the audited baseline; [OP] owner preference; [SF] official sourced information; [CALC] arithmetic or a stated simulation; [DI] design inference; [UH] hypothesis requiring observation. Implementation choices and validation requirements are identified separately.

**Contents:** [Baseline and platform checks](#a-professional-conclusion) · [Resolved design](#b-resolved-design-brief) · [Implementation prompts 0–10](#c-implementation-prompts) · [Completion and evidence](#d-completion-and-evidence)

## A. Professional conclusion

### A.1 Audited baseline

| Question a professional asks first | Method used | What it resolved |
| --- | --- | --- |
| How long is a run, really? | Lune calculation over Logic/DifficultyModel, Config/Stations and Logic/Threat | The original full route is roughly 50–55 minutes; final pacing is specified in B.4 [CALC] |
| Does the sprint/threat ladder hold? | Config/Tuning, Config/Difficulty, HANDOFF 10-18 | Walk 30 and sprint 31 leave little difference. Normal enemies on the default run curve are slower than walk; extreme D=1 Crawler pace reaches 30.316. Final speeds are in B.4 [OF, CALC] |
| Is there a stalking behaviour to extend? | HollowService.think (lines 859-1076) | No. States are Dormant, Emerge, Prowl, Hunt, Windup, Recover, Repelled, Stunned, Grab. Sensing goes straight to Hunt [OF] |
| What makes the stations read "modern"? | docs/stations/DESIGN.md, Config/Surfaces, HANDOFF visibility parts 1-3 | Hazard rails with yellow-and-black posts, striped tape, a red glow strip, whitewash coping, limewash bands and cyan grades [OF] |
| Can the visibility paint approach ever pass its own gate? | HANDOFF visibility part 3 | 45 of 81 failing readings stay under 3:1 even if painted pure white; the chase dim, not paint, is the ceiling [OF] |
| Is there any telemetry? | find_symbol AnalyticsService | None [OF] |
| Did the quality gate pass at the audit baseline? | lune run check at 6333312 | Format, lint, strict types, tests and visual audit passed then; lune run report failed on a stale neutral archetype missing dimensions [OF] |
| What do Roblox rules require? | Official Creator Hub documentation | Publishing, maturity, thumbnails and analytics constraints are listed in A.3 [SF] |

Baseline evidence limits: no Studio instance or real phone was available during the original audit. Existing render sheets, Oct 8 and Oct 13 Studio shots in docs/compare and docs/checks, and recorded HANDOFF observations were used. Live checks in this draft remain required and must be reported honestly.

### A.2 Diagnosis and priorities

Last Train Out has an unusual amount of system for its size and almost no orchestration. The pieces each work, but the clock, the threat, the light and the reward do not pull in the same direction. Four findings carry most of the weight:

The original run is long and stops contain dead time. The audited doors-open estimates were 185–240 s, with means of 213 s at stop 1 and 226 s at stop 10 for tier 2, four crew; fog begins taking ground at 36–94 s [CALC]. A crew that has finished looting cannot leave early. A complete original route is roughly 53 minutes. Tutorial dormancy applies to stop 1 only; it does not keep the entire first run asleep. The final stop clock and bell address idle waiting while retaining cruise and junction beats.

The original threat ladder makes ordinary walking too effective. Walk is 30 and sprint 31 studs/s. Base chase rises through the run with kind and ±6% pace modifiers; most ordinary chases on the default curve are slower than walking, although a maximum-pace D=1 Crawler reaches 30.316. The 2026-10-18 walk increase was not accompanied by a complete ladder adjustment. Final walk, sprint, chase, kind multipliers and tutorial overrides are specified in B.4; stamina, lunges, fog and the clock remain distinct sources of pressure.

The Hollows have no middle gear. They are either unaware or charging. There is no stalking state, so the "intent" the owner wants to read is binary, deaths at early stops arrive without a build-up, and the signature creature (the tall Stalker) is seen mostly in the 0.3 s before it strikes. The procedural animation is clean but has no look-at, no lean into acceleration, and 0.3 s of anticipation that cannot be read at 25 studs on a phone [OF, DI]. "Mechanical" is the right word for a body with no anticipation or attention.

The station look fights its own era. The modern read comes from three traceable sources: the safety furniture at the sinkhole edge (yellow-and-black posts, striped tape, a red glow strip: 20th-century industrial signage), the visibility pass's whitewash and limewash, and the cold cyan grades with heavy desaturation [OF]. The visibility harness has since shown that the paint approach cannot pass its own gate [OF], so the owner's objection and the measurement agree: readability has to come from light (lantern cone, moonlit rim, warm lamp pools) and from value steps in warm and cold materials, not from white.

Implementation priorities: telemetry; the speed ladder; stalk behavior and body language; the bell, stop clock and railing grasp; station materials, period edge treatment and the lighting lock; progression and narrative presentation. The first coherent instrumented speed/tell/pacing loop can be tested before all art, audio and progression work is complete.

### A.3 Platform requirements and release checks

Audience. Check the current Creator Hub eligibility and evaluation status at release. The official Kids and Select page currently specifies 250 unique plays from highly engaged players over the preceding 60 days, creator age verification, two-step verification, and the applicable fee or qualifying subscription route. Complete the actual evaluation; a 50,000 Robux expedited-review option is not the standard publishing fee. Do not plan around an unverified future CCU threshold. [Roblox: Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) [SF]

Blood and horror. Answer the questionnaire for the entire game. Blood realism, intensity and frequency matter; fear also contributes to the label. Keep effects visibly unrealistic and reduce the bite puff count by one third. Mild is an intended outcome to assess, not a guaranteed label. [Roblox: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) [SF]

Communication. All required crew coordination must work without text or voice chat: warnings, the watch, lantern ping, footsteps and readable actions carry it.

Thumbnails. Use 2–5 active thumbnails for personalization and compare actual results by audience segment. [Roblox: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) [SF]

Analytics. Use the current `AnalyticsService` Log APIs. Custom events accept three string custom fields, using `Enum.AnalyticsCustomFieldKeys`, with at most 8,000 unique field combinations per event. Native aggregates do not provide a median; use numeric values and explicit duration buckets. Published server verification is required in addition to Studio diagnostic output. [Custom fields](https://create.roblox.com/docs/production/analytics/custom-fields), [Custom events](https://create.roblox.com/docs/production/analytics/custom-events) [SF]

Networking. Client-owned character movement and a Jump event must not be assumed to arrive as one synchronized snapshot. Roblox documents replication-order limits for object changes and remote events; the receipt-time grasp rule is a design simplification, not a reconstruction of the exact client press pose. Validate the tolerance with measured networking behavior. [Roblox: Replication order](https://create.roblox.com/docs/scripting/attributes#replication-order) [SF, DI]

### A.4 Market and discovery layer

This section turns "what works on Roblox" into measurable rules. It has precedence over owner preference [OP] wherever the two conflict, and it changes only what the evidence touches.

**How Roblox decides who sees the game [SF].** Roblox lists its most important signals for the Home "Recommended for You" sort as **play-through rate** (players who play after seeing the tile), **first-play bounce rate** (leaving after a short first session, in two buckets: under 60 s and 61–180 s), **play days per user** and **playtime per user** (counted up to 60 minutes per user per game per day), each in D1, D2–7 and D8–28 windows. The next set of signals is qualified play sessions, **intentional co-play days** (returning with friends through joins, invites or private servers), **spend days** (unique days a user spends **Robux**) and Robux spent per user. Every signal is measured only on players who arrived organically from that sort. Creator Analytics shows benchmarks against games the same users play, but Roblox states that benchmarks do not affect the recommendation algorithm; they are comparisons, not requirements. A custom thumbnail is required to receive Home impressions at all. [Roblox: Discovery](https://create.roblox.com/docs/production/promotion/discovery)

**What that means for LTO [DI].** A run's ending is not the success unit. The units are the first 180 seconds, the first return day and a return with friends. Measured from the current code [OF]: a first-time player must find Ready (or board a car: `Tuning.Cars` MinPlayers 2, CountdownSeconds 40, a teleport, then ArrivalWaitSeconds up to 20), then sit through run Countdown 10, Boarding 4 and the first cruise (36–66 s) before stop 1 opens. Stop 1 is dormant, so the first threat arrives at stop 2, around minutes 7–9. The tightest ranking window is therefore spent waiting, and the game's hook (a tall silhouette at the edge of the light) is not shown inside it.

**Comparables [SF, third-party; treat as indicative].** Dead Rails is the closest live comparable: a co-op train journey to a terminus with scavenging stops. Rotrends lists its average session at 16.1 min (95th percentile), 6.6B visits and a 92.6% like ratio ([Rotrends](https://rotrends.com/game/7018190066/Dead-Rails)). GameAnalytics' 2025 Roblox benchmark puts healthy sessions at 7–18 min and hits at 19+ min, with D1 retention averaging about 12–15% ([GameAnalytics 2025](https://www.gameanalytics.com/reports/2025-roblox-report)). Both Dead Rails (Bonds, which buy classes) and DOORS (Knobs, for the pre-run shop) use an earned, spendable run currency [SF from play, re-verify before relying on it]. LTO's 38–44 min completed run is far longer than a 16-minute comparable session, so many first sessions may end mid-route, without an ending [UH]. A comparable's average session length cannot set the ideal length of a completed LTO run; it only motivates testing a shorter one.

**Decisions this changes.**
1. **First 180 s targets (FIXED as targets, measured by Prompt 0's timing event).** For a first-time player: join → control ≤ 10 s; join → run Countdown ≤ 45 s; join → doors open at stop 1 ≤ 120 s; join → first Hollow in line of sight ≤ 180 s. Prompt 10 implements this.
2. **Route length (hypothesis, tested by E1).** Add a 5-stop **Short Line** as the proposed default for new players, with the full 10-stop **Long Line** kept as the veteran and status route. Five stops is a hypothesis, not a derived optimum. [CALC, linear estimate from B.4's 47.57 min / 10-stop model: about 24–26 min no-bell and about 21–23 min with mixed bell use; Prompt 0's report must compute it exactly.] Prompt 10 specifies its difficulty, sky, rewards and route policy so that it plays as a complete journey rather than a truncated one.
3. **Brass (provisional).** Reverse the retirement provisionally. Both top comparables use an earned spend loop, and earning toward a chosen purchase may support return play [UH]. Brass does **not** feed Roblox's spend-days signal, which counts Robux only, so this rests on the return-play hypothesis and not on any ranking claim. Review it with Brass source/sink telemetry against D2–7 play days (descriptive) at G2. Prompt 8 records the details.
4. **Stop-1 hook.** Replace pure dormancy with a harmless scripted sighting (Prompt 5).
5. **Return and co-play hooks.** The existing daily first-run bonus, invites from the Depot and the run card, and private servers (Prompt 10, HUMAN for pricing).
6. **Reward budget, three layers, each with one job.** An earlier audit found too many overlapping reward systems (achievements, Brass, Line Mastery and more), and choice overload in a first session works against the bounce signal. Keep exactly three: **Brass** (earn and spend), **Crew Rank** (one number showing time served) and **Line Mastery** (the achievement list, with status cosmetics as rewards). The separate service record is folded into Line Mastery, Rank conditions on Brass items are removed, and no daily line or other new tracker is added. Run-scoped presentation (ticket stamps, charter stamps, the ledger) records a run; it is not a progression layer. A new reward system may only replace one of the three, never sit beside them.
7. **Plain-language UI.** Diegetic names (Hands, Relief, Coldharbour Depot) stay in flavour copy. Buttons and first-session prompts use plain verbs (START, RUN, BOARD, AGAIN).

**Decision rules, set before any data [DI].**
- **Gate G1, closed playtest after Milestone 1** (8–12 first-time players, at least half on phones, recorded think-aloud, no help given). Pass when the median time from join to stop 1 is ≤ 120 s, at least 75% see a Hollow by 180 s, and at least 9 of 12 (or the same share) reach stop 2 unaided. On a failure, fix the first 10 minutes before starting Milestone 2. Before G1: (i) one real phone (mid-range Android, Performance, landscape) completes a full first session, so G1 cannot fail on frame rate or touch controls; (ii) every G1 event is written to a durable sink (a DataStore keyed by session and player) and has been read back after the server closed, because `print` output and Creator Analytics' small-sample views do not survive or show a dozen testers; (iii) a written recording policy is in place: record only testers 13 and over, with written guardian consent for anyone under 18, and observe younger testers through telemetry and the debrief only. Recordings are kept privately and deleted after the review.
- **Gate G2, public soft launch.** Compare first-play bounce (both buckets), play-through rate, playtime per user and D1/D2–7 play days with Creator Analytics' benchmark. A signal below the benchmark median triggers a diagnosis, not an automatic content freeze. Prioritize a fix ahead of new content only when (a) the signal has adequate observations, with counts and intervals stated; (b) the comparison group is suitable; and (c) telemetry or a playtest identifies the funnel step and a plausible cause. Benchmarks are comparisons and do not drive ranking. Time box: after the experiments reach a directional read, give public play eight weeks (PROVISIONAL), then record one of three outcomes: iterate (one funnel step clearly fails and the cause is known), relaunch (players who arrive stay, but too few click: rework icon, thumbnails, title and clips), or stop (players bounce and do not return and no single step explains it; keep the codebase).
- **Experiments (co-op aware).** A train runs one route and one stop-1 treatment, so randomize **per crew at the moment of exposure**, not per player in advance. When a run starts with at least one eligible first-time player, derive the arm from the run seed and the experiment id. Every eligible player in that crew receives it, and their exposed arm is stored permanently and logged (`cohort_assigned`, with the actual exposure). Players are analyzed by the arm they actually received, with crews as clusters (cluster-robust intervals); per-crew outcomes are reported alongside. Veterans in the crew are not in the analysis population. Cross E1 and E2 with independent salts (a 2×2). Independent-sample sizes [CALC, two-sided α 0.05, power 0.8]: D1 return 15% → 18% needs about 2,400 per arm; leaving before stop 2 30% → 25% needs about 1,250 per arm. Multiply by the design effect `1 + (m − 1)ρ`, where m is eligible players per crew and ρ the within-crew correlation. For example, m = 1.6 and ρ = 0.3 give 1.18: about 2,830 and 1,480 per arm. Report the measured m and ρ. Below those counts, results are directional only. The existing 300-per-cohort gate gives about ±4 percentage points on a 15% rate (95% interval), which is descriptive, not comparative.
- **Planned experiments.** E1 Short Line vs Long Line as the first-run default (primary: D1 play days; secondary: first-session playtime and route completion). E2 stop-1 sighting vs no sighting. The primary metric is the share leaving before stop 2's doors open, among players present when stop 1's doors open. Both arms log that eligibility point, because the sighting cannot affect players who leave before it could occur.

**Acquisition [DI, HUMAN].** The owner already produces short-form video. Clip-ready moments are the acquisition channel: the Stalker at the edge of the light, the railing grasp near-miss and the crewmate pry. Creator mode (Prompt 9) exists for capture. The same three moments supply the 2–5 personalized thumbnails and the icon candidates. The icon is tested like a thumbnail. Rank both by play-through rate, not by taste.

**Budget and release [DI, OP].** Source: `docs/direction/2026-10-21_LTO-investment-assessment.md`, which holds the hours, cash and revenue reasoning; re-read it at G1 and before the soft launch.
1. **Budget gate.** Commit only to Milestone 1 and Gate G1. Milestone 2 starts only after G1 passes. If G1 still fails after one round of fixes and a re-test with new players, rethink the first ten minutes or shelve the game; do not add features.
2. **Positioning.** Present LTO as co-op horror first and a train game second, on the store page, thumbnails and clips. As "train survival" alone it sits beside Dead Rails in a comparison it loses.
3. **Release timing.** No seasonal date. Halloween 2026 is out of reach; launch when D.2 is complete.
4. **Money.** Plan for zero revenue until measured. Cash spend is $0–$300 (a test phone and test Robux); no paid ads before the G2 evidence gates.

## B. Resolved design brief

### B.1 Experience thesis

The fantasy. You are one of a small crew sent down a dead line on the last train that still runs. The train is the only warm, lit, moving thing left. Everything you want is out there in the cold and the dark, and the train will not wait for you.

The decisions that make it enjoyable. How far from the light to go, and for what; when to turn back; whether to run or walk (and what that costs); whether to face the thing watching you or keep working; whom to go back for; when to ring the bell and leave; and, at the end, whether to jump for the railing.

The emotional rhythm. Warm and busy aboard (prepare, vote, patch) -> cold and quiet on the platform (look, listen) -> a watched feeling that builds (stalk) -> a short violent problem (strike, grab, pry) -> a sprint with a clock on it (the whistle, the chase, the grasp) -> relief and a tally aboard (stamps, the ledger) -> the next ticket. Dread should be mostly anticipation; violence should be short and legible; relief should be warm and social.

What makes it recognizable. One amber light in a cold dark with a tall silhouette at its edge; a pocket watch and a paper ticket; a train you can hear leaving; a crew that pries each other free.

Why another run is worth it. Different route and stops; the stalk/commit rhythm produces different stories each time; Line Mastery with early, middle and long-term goals, including status for reaching the Terminus; crewmates who want to go again, and one tap to do so.

### B.2 The experience, mapped

| Beat | Today [OF] | Where it is raw | Direction |
| --- | --- | --- | --- |
| First minute | Depot Hall, Ready, car countdown (40 s), boarding | Many systems visible at once; nothing yet says what the trip is for | Premise on the walls and the ticket; one objective aboard (coal) |
| First station | Dormant Hollows at first-run stop 1, 25 s grace, loot/light/clock cues | Safe learning can turn into waiting | Teach loot, light, clock and bell; no attacks at stop 1, plus one scripted sighting (A.4) |
| First failure | Grab -> skill check (zone 70 deg at stop 1) -> pry; left behind -> eliminated -> spectate | Grabs arrive without build-up; left behind feels sudden | Stalk before strike; the railing grasp turns "left behind" into a near miss you can read |
| First successful return | Run card ticket and stamps, 12 s RunEnd, Lobby, Ready again | Two phases of waiting; no "again" | AGAIN on the card; the premise's status board |
| First completed run | Terminus, strongbox, ledger and rank | Original route around 50–55 min; overlapping rewards | Conditional 38–44 min completed-run target with mixed bell use; Short Line first runs (about 21–26 min, A.4); one Brass loop plus record-gated status items |
| Repeated play | Route vote, mystery ticket, tiers and cosmetics | Early stops and threat shape can become familiar | Stalk, door-forcing, bell and grasp vary decisions; the Rider remains future work |

### B.3 Decisions

These are the consolidated requirements. Numeric settings identified as provisional may be tuned only with the stated measurements and with related calculations and tests updated together.

#### Moment-to-moment feel

Speed ladder. Walk 21, sprint 31, base chase `{25, 26}`, pace spread ±6%. Stalker chase ×1.0 and lunge ×1.45; Crawler chase ×1.0 and lunge ×1.6; Brute chase ×0.98 with lunge disabled. Lunge duration remains 0.55 s for Stalker and Crawler. Preserve stamina and winded settings. B.4 defines the margins and separate tutorial override.

Haul crates. Preserve DuoPenalty 0.15 and SoloPenalty 0.35: duo speed is 17.85, solo speed 13.65, with no sprint. The crate lamp provides ordinary shared readability and does not become a repulsion SafeLight. The pair’s advantages are shared light, pry, drop-and-recover and avoiding the alone condition when within 14 studs. Both carrier speeds remain below normal Hollow chase. The solo strongbox route must also pass the actual-speed return check in Prompt 4; carrier speed alone does not establish reachability.

Glance key [OP: "a peeking option on an unused key"]. Decision: hold Q (gamepad RB, touch: a small LOOK button above RUN) swings the camera to look over the shoulder behind you while you keep moving. In a chase game, seeing the pursuer without turning is the useful "peek".

Camera, interaction and feedback: no change to the camera rig; add anticipation and follow-through to the Hollows (B.3 Enemies) and the grasp (B.3 Departure).

#### Tension and pacing

Early departure bell. Use elapsed share `u = (serverNow − doorsOpenAt) / original params.dwell`, where doorsOpenAt is run.station.startedAt; the denominator includes LastCall. During Dwell, allow the bell when all living crew are aboard after 40% of the original dwell, or at least half are aboard after 60%. Eliminated players are excluded. Pulling it can only shorten departure to `min(existing departAt, now + 30 s)`. The authoritative clock, warning, timed-event and hazard rules are in Prompt 4.

Dwell. Adopt stop clock B: WalkReference 30, Search `{80, 60}`, WalkMargin 1.4 and PerStop 3; retain Detour 1.2 and unmentioned terms. WalkReference sizes the timer only. Physical reach tests use actual walk 21. Target doors-open duration is 2–3.5 minutes and expected completed-run duration is 38–44 minutes under mixed bell use; neither is an observed result or a hard limit.

Rides are not shortened: cruise remains 36–66 s plus a 20 s junction. The lantern stays a readability floor and does not use a depletion resource. Ride attentiveness comes from leaks, boiler strain and, later, the deferred Rider event.

Variation that changes decisions: stalk commit rules vary by stop and crew (alone, in the dark, back turned), door-forcing at some stops, the bell decision, the mystery ticket. Not more archetypes.

#### Enemies and fairness

Stalk. Add a middle state between Prowl and Hunt. Use server-owned `Tuning.Stalk.ReferenceRadius = 30` studs, independent of every player's Visibility slider. The shadow band is `[0.8r, 1.1r] = [24, 33]` studs, outside every SafeLight and station lamp pool, with line of sight; red edge danger lamps are not those gameplay pools. Facing uses the root look vector, not the glance camera. Minimum stalk `{4, 1.5}` precedes timed commits; maximum stalk `{12, 6}` continues while faced and overrides facing when it expires. Back-turned time `{2.5, 1}` is halved only when alone and outside lamp light. Immediate commits remain possible for proximity, Surge and another Hollow seizing the target. Until a new target has received 1.5 s of readable Stalk/coil opportunity, block Windup, lunge and strike and prevent deliberate approach inside 16 studs, as specified in Prompt 2. Prompt 2 defines precedence, targeting and recovery.

Buildings. Preserve sleepers in unlit rooms and repulsion from lit rooms. Seed door-forcing on 40% of stops from stop 3 onward on every tutorial tier. BuildingService owns one force timer per door per force episode: 3 s plus one shared 4 s extension if held. Hollows queue; they do not each start a timer or add extensions. Lighting the room cancels forcing and repels. A forced door stays open for 6 s before it may close again.

Tells. Use the same fixed `r = 30` studs: lean the carried lantern away within 30, flicker by at most 15% without breaking the readability floor, stutter the pocket watch within 36, and use breath rolloff 15–30. Stop these tells within 1 s of leaving range. The Visibility slider controls presentation readability, not server NPC logic, warning credit or these cue thresholds. Warning exposure measures opportunity with line of sight; it does not prove the player noticed.

Animation. Add look-at, lean, plant-timed footsteps, a predictive visible coil, miss follow-through and a breathing Stalk freeze. Blend only ordinary Prowl/Stalk/Hunt/Recover/Repelled transitions over 0.2–0.35 s. Coil, Windup and lunge poses snap into readable silhouettes. The Stalker gains a shredded coat and pallor within its part and cosmetic budgets.

Future Hollow behavior. The Rider remains a later content phase, as described in B.6.

Readable threats. Every newly attacked target gets at least 1.5 s of readable Stalk or coil opportunity before the first strike, including scripted, alerted and immediate-commit encounters. During unmet warning time the Hollow coils and cannot deliberately advance inside 16 studs, wind up, lunge or strike. A player approaching it may reduce that separation; do not teleport either body to enforce it. This does not force a hit or guarantee survival. Fog, falls and left-behind outcomes have their own visible fronts, edge lamps and clock cues. There is no blanket immunity until a particular minute.

#### Train departure

Railing grasp. Preserve departure acceleration `{4, 6}`, the 3 s grace and chase windows `{7, 5}`. During the live Departure window, Jump may start a server-approved attachment, 0.6 s hang and 0.5 s haul. Use nominal root-to-rail reach 3 studs plus a PROVISIONAL replication tolerance: 0.5 studs plus the receipt snapshot's closing speed toward the rail × 0.1 s, the closing-speed term capped at 1.0 (effective reach 3.5–4.5). Compensate the estimated press time for window eligibility only, using measured one-way latency capped at 0.2 s; evaluate geometry from the server's replicated root and static rail at receipt, without position rewind or a history buffer. Credit Aboard at attachment before departure resolution. A miss plays a 0.5 s stumble and allows another attempt if the window remains open; it does not itself eliminate the player. Prompt 4 defines timing, latency checks, cleanup and shortfall presentation. Use the existing jump input; the timing is the skill, with no additional skill check or global slow motion.

#### Art direction and readability

Period language: Victorian railway company (brick, stone dressings, slate, cast iron, bottle green, oxblood, aged brass, mahogany) at the frontier (board-and-batten timber, tin, canvas, rope, oil lamps). The company builds the station buildings; the village and yard are the frontier. That is the Victorian/Western merge the owner asked for, as a material rule rather than a mood word.

Surface rule: no pure white and no pure black on station surfaces; use channel bounds 18–232, with bone and parchment only as trim. This is a style constraint, not proof of readability. Remove whitewash coping (keep the blue-brick margin on wet grey-brown stone) and station limewash bands. Replace hazard rails, tape and the red strip with red oil danger lamps on posts, rope, stakes and broken ground; keep SinkholeEdge and setback logic. Red communicates danger as light. Danger lamps provide visual warning only, with no SafeLight or stalk-exclusion effect. Prompt 6 caps their PointLights; extra lamps retain emissive glass.

Grades: keep the cold pendulum but take it off cyan; moon green-grey and blue-grey with less desaturation (0.18 -> 0.10 provisional) so brick and oxblood still read as materials.

Density [OP: "as well designed as the train"]: a layering pass (foreground clutter on routes, mid-height canopies and gantries, a skyline landmark readable from the platform) within the audit's budgets; not more scattered props.

Lighting lock. Establish a warm amber estate recipe for the Depot Hall and train interior: many small sources, polished glints, soft falloff, deep shadow and low ambient. Config/InteriorLight owns local fixture values only; existing AtmosphereController and Sky.LOBBY retain global Lighting ownership. Save named, locked reference shots and measured luminance bands, plus local silhouette/obstacle checks. The lobby recipe must not overwrite station lighting.

Interior doors [OP: low poly]: panelled doors with brass furniture and a glazed light, same pipeline as the train exterior meshes (needs the owner's upload) or primitives within budget.

#### Animation and audio

Sound hierarchy. Preserve the existing groups and sidechain ducks, with departure warnings above threat, threat above player feedback and ping, then ambience and lobby piano. Add stalk audio and four distinct crew-slot boot timbres. A 0.4 s predictive hush starts from replicated Intent, not from Windup; it may occur without a strike and does not change attack timing. Add 2 s of near-silence after arrival brakes. No score; sound design is the score.

Co-op ping. V, gamepad Y or a touch button raises the lantern: 1.5 s glow pulse, watch compass toward the pinger for 2 s and a soft whistle. Server rate limit: one per 3 s. Warnings and threat take priority; preserve visual equivalents.

#### Cooperation and onboarding

First-run escalation. Stop 1 teaches loot, light, clock and bell with 25 s grace and no attacks, plus one scripted harmless Stalker sighting at the edge of the platform light (A.4; Prompt 5). Stop 2 introduces the scripted Crawler and SkillCheck; pursuit 24, lunge 40 for 0.55 s, and at least 1.5 s readable warning before the first strike. Sprinting can evade it; no hit is required. Stop 3 has one Stalker as a wanderer-with-stalk, targeting the first player 20+ studs from the train after grace; remaining in the light need not cause an encounter. Tier 2 keeps zone 100 and grace 15 without its scripted grab; tier 3 stays unchanged. Hull and Vote prompts remain on the first cruise and junction.

Same-crew replay. AGAIN is available to all present run members, including eliminated players after a wipe. Queue RunEnd presses and apply them on Enter.Lobby after ResetReady. Keep the 12 s RunEnd card readable. Start the 20 s fallback at the first applied ready press in Lobby; begin when all present eligible members are ready or the timer ends with at least one ready. DEPOT closes the card and leaves that player unready. Late joiners ready normally.

#### Progression and replayability

Brass. Keep Brass provisionally as the one earned, spendable currency. Both top comparables run an earned spend loop, and choosing a purchase may support return days [UH]. Brass is not part of Roblox's spend-days signal, which counts Robux (A.4). Remove the overlap instead of the currency: Brass buys ordinary cosmetics and nothing else, and Line Mastery gates only the status items (Prompt 8). Keep the daily first-run bonus, which drives return days, unchanged. Keep Rank/XP. Progress includes stops departed, rescues, clutch boards, deepest stop and victories, with status for reaching the Terminus.

NPC errands [OP: lore and hints only]. Decision: Mabel's chain stays as the one errand line (it teaches "find and carry") but pays only its cosmetic and its story lines; the other residents stay reserved. Puzzle hints are deferred with the puzzles (B.6).

Deepest-stop mark: profile.stats.bestStation already exists [OF]; show it on the ticket book and the Depot roll.

#### Narrative

Premise (owner's number 7, preferred): the Depot is the last lit place. The Company sends its young down the dead line on the last train to strip the stations for coal, parts and valuables. Nobody believes in rebuilding; the trips delay the end. Those who return from the Terminus get their name on the roll, titles and liveries; those entered in the ledger as left behind are not recalled. The point of the premise is that status is enough of a reward even at the end of the world. This fits the existing haul strongbox, ledger, ticket book, stamps and the Line Mastery board almost exactly [OF], which is why it costs little.

Canon. The Depot’s departures are a standing order. Keep LORE’s rule that the Hollows are never explained and there is no explanatory twist. Lamps are kept lit by those who went before: communicate it on a plaque, without a mystery mechanic. The next ticket is simply issued; add no immortality explanation. Mabel remains a woman clerk in the post-collapse Depot, with a LORE note.

Names. Players are Hands (the Company’s Hands); a run is a Relief; the lobby is Coldharbour Depot. Keep Last Train Out as the game’s title. Change UI and copy through Config strings; retain code identifiers.

#### Long-term sustainability

What stays enjoyable after familiarity: stalk/commit rhythm, the bell decision, the grasp, crew stories and Line Mastery. Future content includes stop archetypes, Hollow behaviors such as Rider, omens and cosmetics. A behavior or event about every two months is a proposed production cadence, contingent on capacity; it is not a demonstrated cost or retention guarantee. Measure acquisition (thumbnails, clips, a listing led by co-op survival), onboarding, retention, monetization and content cadence separately.

Monetization: cosmetics, liveries and private servers only, bound after publishing. No energy timers, no pay-to-skip, no sunk-cost tiers. The earned Brass loop stays (A.4). The Robux catalogue entries stay as they are.

### B.4 Calculations and fixed numeric relationships

**Normal speed ladder.** Let `D` be difficulty, `p ∈ [0.94, 1.06]` the pace factor, and `k` the kind multiplier. Normal chase is `(25 + D) × k × p`, with `k = 1` for Stalker/Crawler and `0.98` for Brute. Walk is 21 and sprint 31.

| Kind | D0 chase range | D1 chase range | D1 minimum sprint advantage | Lunge |
|---|---:|---:|---:|---|
| Stalker | 23.50–26.50 | 24.44–27.56 | 3.44 studs/s | Chase ×1.45 for 0.55 s |
| Crawler | 23.50–26.50 | 24.44–27.56 | 3.44 studs/s | Chase ×1.60 for 0.55 s |
| Brute | 23.03–25.97 | 23.9512–27.0088 | 3.9912 studs/s | Disabled |

At D0, normal chase exceeds walk by 2.03–5.50 studs/s across all kinds and pace extremes. The 2–6 band is a D0 requirement; it is not a cap across all D. At D1, sprint exceeds every normal chase by at least 3.44 studs/s. Stalker/Crawler lunges are faster than sprint; Brute has no lunge. At D1 their lunge ranges are 35.438–39.962 and 39.104–44.096 respectively. These are speed relationships, not universal catch or escape guarantees.

**Stamina and carriers.** Max stamina 100 at drain 18 gives `100/18 = 5.5556 s` of full sprint. Preserve regen 22, regen delay 0.9 s, winded 1.6 s at ×0.85 and exhausted-resume share 0.35. Full sprint gains 19.1111 studs against the fastest normal D1 Stalker/Crawler in a straight-line idealization. Substituting one full 0.55 s lunge reduces that net gain to 12.2900 for Stalker or 10.0163 for Crawler; this ignores windup, navigation and collision. Do not treat this idealized gain as a guaranteed escape buffer. Duo carry is `21 × 0.85 = 17.85`; solo is `21 × 0.65 = 13.65`; neither may sprint or repel through a crate bubble.

**Scripted tutorial exception.** Tier-1 stop-2 Crawler uses absolute pursuit 24 and absolute lunge 40 for 0.55 s, overriding normal pace, kind chase and ChaseScale for this encounter. Walking loses ground and sprint gains ground between bursts. Provide at least 1.5 s of readable warning before the first strike; do not force a grab.

**Departure closure.** Time `t=0` is the end of the existing 3 s departure grace, when platform acceleration begins; it is not the earlier warning whistle. With acceleration `a`, ideal relative closure is `∫(v_player(t) − a t)dt`. For a full-stamina, uninjured, unloaded player sprinting at 31 for `100/18 s`, then winded at `21 × 0.85 = 17.85` for 1.6 s before returning to walk 21, D0 (`a=4`, window 7 s) closes about 100.01 studs by window end and peaks near 110.49 at stamina exhaustion. D1 (`a=6`, window 5 s) closes 80 studs by window end. These are geometric idealizations, not guaranteed successful starting distances; include initial gap, nominal reach 3 plus the provisional speed-scaled tolerance (3.5–4.5 effective), press time, replication error, obstacles and actual movement state in tests. Upgrades.SteamWhistle keeps its existing chase-window extension; recompute trajectories for that variant. If the player instead spends 54 stamina sprinting throughout the preceding 3 s grace, acceleration begins at stamina 46. With sprint until that stamina is exhausted, then sprint released (no re-sprint), the same ideal model gives D0 closure 69.52 studs at 7 s, peak 75.64 at 5.25 s; D1 closure 50.52 at 5 s, peak 60.16 at 2.975 s. Holding sprint through regeneration is a different trajectory and must be simulated using MovementController. Validate estimated press-time window eligibility separately from receipt-time geometry; these calculations do not reconstruct a networked press position.

**Stop clock and route simulation.** Final clock: WalkReference 30, Search `{80,60}`, WalkMargin 1.4, PerStop 3, Detour 1.2; other terms unchanged. WalkReference is used for timer sizing only; StationReach uses actual player speeds. In the supplied 1,000-seed model (first offered route, run tier 1, no upgrades, Countdown through RunEnd including the final Terminus leg), mean no-bell duration is 47.57 min and mean doors-open time 187 s. This mean is not a ceiling.

| Modeled bell use | Mean complete-route duration | Eligibility assumption |
|---|---:|---|
| No bell | 47.57 min | Full schedule |
| Every stop at elapsed share 0.40 | 33.85 min | All living crew aboard |
| Every stop at elapsed share 0.60 | 40.09 min | At least half aboard |
| 60% of stops at elapsed share 0.50 | 41.21 min | All living crew aboard on those stops |

Target expected completed duration is 38–44 min under mixed bell use; about 34 min requires aggressive universal early departure. Doors-open target is 2–3.5 min, not the whole station cycle. These modeled scenarios exclude behavioral evidence and do not establish a hard run cap. Elapsed shares are measured from doorsOpenAt over original params.dwell, including LastCall, not over the shorter Dwell phase. Re-run the report against the implemented clock, legal bell eligibility and any reach-related clock change.

**Outcome denominators and success.** Keep per-player outcomes (aboard departure, left behind, Taken, fall and rescue) separate from per-crew outcomes (cleared, wiped and derailed). A run can continue with one living crew member; flares and join-in-progress matter. Overall victory probability can be expressed as the product of conditional crew-level transition-clear probabilities, including Terminus, only when those probabilities use the matching crew state and denominator. Do not substitute independent player survival rates. No success probability follows from these settings without observations.

Completed-run duration is Countdown to victory RunEnd; failed-run duration is Countdown to Wiped/Derailed; a visit is player join to leave. For acquisition planning, steady-state average CCU equals daily visits × mean **visit** minutes / 1,440; completed-run duration is not a substitute. Define a measurable success goal and time horizon before assigning commercial odds; that definition does not block implementation.

### B.5 Preserved strengths

Server authority, the phase machine, the deterministic layouts and hazard schedules, the grab/skill-check/pry loop and its audit, the train interior and exterior, the lobby shell work, the haul strongbox and payroll accounting, the sky and omens, the mixing groups and ducks, the Settings and Visibility slider, the ticket book and run card, the Studio dev console.

### B.6 Scope boundaries and future work

Keep the lantern continuously available as the readability floor. Use a local camera kick for grasp feedback and no extra grasp skill check. Use readable consequences rather than a blanket time-based death exemption. Readability comes from materials, light and local checks. Measure observed behavior and outcomes; do not use invented physiological measures or unsupported market-cycle predictions.

Future work: Rider during Cruise (roof or alongside, up to 5 hull per bang unless driven off with lantern or flash, two to four players only); lantern-message puzzles and a pass ticket for Dutch; Dutch, Varga, Pip and the Conductor; broader player-category content strategy after sufficient evidence. Ads follow the sample and phone criteria in Prompt 9. These are outside the initial implementation scope, not prerequisites for first testing.

### B.7 Validation plan

| Question | Probe or dataset | Observe | Interpretation / response |
| --- | --- | --- | --- |
| Does stalk read as intent? | 6 first-run testers, including 3 phones | Turning to face it and whether 4 of 6 report seeing it coming | Diagnostic usability probe only; inspect exposure and comprehension before adjusting stalk timers |
| Is grasp fair? | 2 testers, 10 departures each, controlled starting gaps with D, stamina at acceleration start, grace use, input policy and latency recorded | Boards, misses, client-observed press gap versus server receipt gap, window estimate and unfairness reports | Small usability probe, not a conversion estimate. Use the calculated trajectory for each setup; an 80-stud D1 setup assumes full stamina at acceleration start. Check tolerance under the network matrix in Prompt 4; no fixed board-count target overrides correct geometry |
| Does the bell get used? | Instrumented stops, segmented by run experience | Bell share, legal branch used and doors-open buckets; provisional 40% share after run 2 | Behavioral hypothesis; inspect reasons for non-use rather than automatically shortening Search |
| Phone readability | Real phone, 40% brightness, Performance quality | Edge, nearest obstacle and Stalker at 24, 30 and 33 studs at Visibility 18 and 30 in motion and chase dim | All must be readable; adjust local light/rim/value steps within the material direction and recheck |
| First 180 seconds | Prompt 0 first_session_timing, G1 playtest | Join → control, run start, stop 1, first Hollow seen, per device | A.4 targets; fix the largest gap before Milestone 2 |
| Route length | E1 Short vs Long default | D1 play days, first-session playtime, completion | Pre-registered; directional until about 2,400 per arm |
| Run length | Completed and failed runs kept separate | Duration histogram, doors-open distribution, quit-by-stop curve | Conditional 38–44 min completed-run target; distinguish bell use, routes, crew and visit duration |

Telemetry schema and denominator rules are fixed in Prompt 0. Before tuning from quit curves, collect at least 300 unique first-run players per device cohort and 150 completed crew runs; report uncertainty intervals and counts. These are minimum evidence gates, not proof of an effect. Six-person and two-person probes find usability problems and cannot establish population success rates. D1 retention 15% and reaching-stop-3 70% remain unvalidated hypotheses. Quit-after-outcome comparisons are descriptive, not causal.

## C. Implementation prompts

Execute Prompts 0–10 in Milestone and dependency order. Reconcile each baseline reference against the current repository, and edit on disk only. Keep `--!strict`; put constants in Config and pure rules in Logic. Update meaningful specs and run `lune run check`. Use Studio playtests with console inspection and screenshots where available; otherwise record the missing check and exact manual steps. Update HANDOFF; use one commit per prompt and do not push. Script execution alone is not evidence of correct gameplay. The audit baseline was 6333312; subsequent prompts build on completed earlier prompts. Respect existing changes. Presentation work may proceed independently where files permit, but coordinate shared files. Test the first coherent instrumented speed/tell/pacing loop before waiting for every presentation feature. **Milestone 1** = Prompts 0, 1, 2, 3, 4, 5 and 10, followed by Gate G1 (A.4) with real first-time players. Milestone 1 also brings forward the essentials that players need to read danger, so G1 tests the design rather than missing presentation. From Prompt 6: only the local readability check (sinkhole edge, nearest obstacle, Stalker at 15, 24 and 33 studs, chase dim, Performance quality, phone preset), with fixes limited to local light, rim and value steps; the current edge furniture stays for now because it is functional. From Prompt 7: the priority table and ducks (departure warnings above threat above ambience) and the Intent hush. Stalk breath is already in Prompt 2. **Milestone 2** = the rest of Prompts 6 and 7 (materials, period edge, grades, density, lighting lock, crew-slot footsteps, ping, arrival silence) plus Prompts 8 and 9, started only after G1 passes or its failures are fixed. Do not polish stations, audio or progression ahead of evidence that the first ten minutes hold players.

Conventions: **FIXED** = required design rule or initial setting; **CHOICE** = implementation detail the builder decides; **PROVISIONAL** = tunable value, changed only with its dependent calculations and acceptance checks; **HUMAN** = asset, account action or real-device judgment unavailable to the builder. A pending HUMAN or post-release check must remain explicitly pending.

### Prompt 0: Telemetry and the balance report

**Outcome.** Make later decisions measurable. Add telemetry and repair the balance report before using it as evidence.

**Audited baseline.** No AnalyticsService usage was found. Logic/RunLog holds per-stop outcomes, close calls and haul; Logic/DeathCause defines causes. .lune/report.luau builds a stale neutral archetype without length/depth, causing DifficultyModel.farWalk to fail. Verify the current implementation and Roblox API before editing.

#### Design — FIXED

New server module Services/TelemetryService, added to ORDER after DataService, is the only caller of AnalyticsService. Interface: `Funnel(player, funnel, sessionId, step, name, fields)` and `Event(player, name, value, fields)`. For `funnel = "onboarding"`, dispatch to `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name, fields)` with no funnel session ID. Other named funnels use `AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, name, fields)` with a server-generated nonempty stable session ID for that occurrence. Keep these API differences inside the wrapper. Wrap calls with Util/Safe.call; Init must not yield. Use a valid connected Player for every Log call. Crew events emit once per crew run or stop and are attributed to the first connected run member, with a connected-member fallback. Do not emit them once per player. Use event counts, not unique representative users, for crew rates. Player events emit once per relevant player occurrence. Deduplicate internally with run/stop/player identity; keep run IDs out of custom fields. No dynamically generated event names.

Use exactly three string slots, `Enum.AnalyticsCustomFieldKeys.CustomField01.Name` through `CustomField03.Name`. Numeric measurements go in `value`. An em dash means leave the slot unused. Freeze bounded enum vocabularies in Config and test that combinations remain below 8,000 per event.

| Event | Scope / value | Field 1 | Field 2 | Field 3 |
|---|---|---|---|---|
| run_started | Once per crew run / 1 | crewSize | runTier | tutorialTier |
| run_joined | Once per player entering a run / 1 | device | experience | crewSize |
| stop_resolved | Once per crew stop / dwellUsedShare × 100 | stop | outcome | bell |
| stop_archetype | Once per crew stop / 1 | stop | archetype | crewSize |
| stop_timing | Once per crew stop / doorsOpenSeconds | stop | stopDurationBucket | crewSize |
| player_stop_resolved | Once per connected participating player/stop / doorsOpenSeconds | stop | device | experience |
| player_eliminated | Once per terminal player outcome / secondsIntoStop | cause | stop | heldBy |
| tell_exposure | Every attacked player before each strike attempt / tellSeconds | tellBucket | crewmatesNearBucket | stop |
| tell_cohort | Companion to tell_exposure / tellSeconds | tellBucket | device | experience |
| grasp | Each validated grasp attempt / gapStuds | result | secondsLeftBucket | device |
| grasp_shortfall | Companion to grasp / shortfallStuds | result | secondsLeftBucket | device |
| run_ended | Once per crew run / runMinutes | outcome | crewSize | runDurationBucket |
| run_progress | Once per crew run / stopsReached | outcome | crewSize | runTier |
| player_run_outcome | Once per participating player at run end, if connected / participationMinutes | outcome | device | experience |
| player_progress | Once per player at terminal participation outcome / deepestStopThisRun | device | experience | crewSize |
| again_pressed | First accepted press per player/card / secondsAfterCard | precedingRunOutcome | device | experience |
| session_ended | Once per visit, best effort / visitMinutes | lastPhase | device | experience |
| quit_after_outcome | Companion on leaving after a recorded outcome / secondsSinceOutcome | lastOutcome | device | experience |

Definitions: device = phone/tablet/desktop/console/unknown, validated server-side from the client’s one-time device report; experience = first-run/returning from the persistent run counter, snapshotted at participation start; crewSize = 1–4, snapshotted for each crew run; tutorialTier = 1/2/3/0. Late joins and reconnects emit run_joined without creating another run_started; deduplicate participation and progression milestones within the run. Crew rates use actual crew outcomes, while player/cohort rates use player events and matching denominators. Record join-in-progress status internally and exclude those players from first-run onboarding completion denominators that require an earlier start.

Bell enum is none/all/half; record the eligibility branch accepted by the server, not the word majority. Stop outcomes are cleared/wiped/derailed/aborted as applicable; run outcomes are victory/wiped/derailed/aborted. Preserve DeathCause’s real cause enum. heldBy is Stalker/Crawler/Brute/none. crewmatesNear counts other living crew within 20 studs, bucketed 0/1/2+. Use an explicit pre-stop marker where needed; never invent a stop number or cause to fill a field. A disconnect during active participation records Disconnected if that player has not already received a terminal elimination; leaving Lobby is not an elimination.

Buckets are mutually exclusive: run minutes `<20`, `[20,30)`, `[30,40)`, `[40,50)`, `50+`; doors-open seconds `<90`, `[90,150)`, `[150,210)`, `210+`; tell seconds `0`, `(0,1.5)`, `[1.5,3)`, `3+`; seconds left `<1`, `[1,2)`, `2+`. Keep exact numeric duration in value. Native histograms locate a median bucket; do not claim an exact median from coarse buckets. Completed-run time begins at Countdown and ends at victory RunEnd; failed-run time ends at Wiped/Derailed. Stop timing is doors-open duration, not the whole cycle. Visit time is player join to leave. Separate those populations.

`tellSeconds` is the attacking Hollow’s accumulated Stalk or coil time with line of sight within the fixed 36-stud warning range of that attacked player, using `Tuning.Stalk.ReferenceRadius = 30`, independent of Visibility before the strike. Track it per Hollow/target; emit for every strike target, not only grabs or Taken deaths. It measures warning opportunity, not perception. Keep per-attempt exposure and the terminal outcome distinct. Track target changes correctly. Bell flags are stored when accepted and emitted with the stop’s one resolution event. Grasp gap/shortfall values use the same receipt-time geometry and effective reach as the decision in Prompt 4. The later prompts supply bell, grasp and AGAIN instrumentation.

Additional events (A.4): `first_session_timing` (first visit only; value = seconds since join; Field 1 milestone control/run_start/first_stop/first_hollow_seen; Field 2 device; Field 3 entry hall/car/join_in_progress); `cohort_assigned` (once per player per experiment; value 1; Field 1 experiment id; Field 2 arm; Field 3 device); `invite_prompted` (value 1; Field 1 source depot/runcard; Field 2 device; Field 3 experience). Log Brass sources and sinks through `AnalyticsService:LogEconomyEvent` with bounded transaction types and item SKUs, not custom events. Route length (short/long) replaces `runTier` in Field 3 of `run_progress`; keep runTier on run_started.

Main onboarding sequence: joined → first_board → first_off_train → survived_stop1 → reached_stop3. Use LogOnboardingFunnelStepEvent via the wrapper and emit each eligible milestone once per player, with persistent eligibility/deduplication. Grab/escape/pry are optional milestones or separate eligible subfunnels (`first_grab`, `first_escape`, `first_pry`); a player may pry without having been grabbed, so do not require them in one linear chain. Replay uses a separate funnel first_run_ended → second_run_started, including after an early wipe. Use separate named LogFunnelStepEvent funnels for optional eligible sequences and replay. Persist the replay funnel ID from the first run's terminal outcome until the second run starts so a later visit can complete it; do not generate a new ID for its second step. Keep optional milestones independent when their prerequisites differ. Funnel IDs belong only in the API's session-ID argument, never in custom fields.

Device reporting: read UserInputService once on the client and extend the existing ClientReady payload and Remotes validation. Do not add a telemetry remote. Validate the bounded device enum and use unknown when unavailable. Later Prompt 7’s Ping remote is independent of this rule.

Repair .lune/report.luau to iterate Stations.Order using actual archetypes and their dimensions. Print doors-open dwell, Logic/Threat.total, normal chase ranges including kind/pace, fog start and complete-route duration for crew sizes 1 and 4; retain the D table. Include all route legs through Terminus, seed/scenario assumptions, actual bell eligibility and the timer/reach speed distinction. Report deterministic balance outputs separately from player observations.

**Preserve.** RunLog, DeathCause, the state tree. Remove. Nothing.

**Edge cases.** Preserve RunLog, DeathCause and state ownership. Studio uses an explicit diagnostic-output path; printed events do not prove backend ingestion. Handle disconnects, missing representative players and shutdown best-effort without blocking gameplay or inventing an outcome. Do not claim that a silent API call proves a dashboard event.

**Acceptance.** `lune run check` passes and `lune run report` prints valid tables. Studio Output shows correctly timed, deduplicated crew and player events for join, boarding, leaving train, warning/strike, stop resolution, run end and retry as features become available. Verify field shape and bounded vocabularies. Confirm actual ingestion in a published server with the real APIs; record this as pending if unavailable. No new telemetry remote.

**Handoff.** HANDOFF includes the event/field table, scope and denominator rules, report assumptions, diagnostic versus published verification status, and pending manual steps. Regenerate rbxfacts.

### Prompt 1: The speed ladder, stamina, carriers and the glance

**Outcome.** Sprint creates distance against normal pursuit while stamina lasts, walking loses distance and running dry creates commitment. Validate catches and escapes under controlled geometry rather than promising an outcome from any starting position.

**Audited baseline (verify current code).** Tuning.Crew: WalkSpeed 30, SprintSpeed 31, StaminaDrainPerSecond 18, Regen 22, Delay 0.9, ExhaustedResume 0.35, Winded 1.6 s x0.85. Difficulty.HollowChase {22, 26}, HollowWalk {11, 14}; kinds in Tuning.HollowKinds (Crawler chase 1.1, Brute 0.98). Tuning.Hollow.LungeBoost 1.45, LungeSeconds 0.55, LungeCooldown 3.5. Config/Haul DuoPenalty 0.15, SoloPenalty 0.35; carriers cannot sprint (MovementController lines 46-50, 101). tests/HollowSpeed.spec asserts the old relationships; tests/Haul.spec asserts the carry constants against walk. HollowService isLit/safeLightAt repel Hollows from parts tagged SafeLight with attribute Radius (lines 220-239). The crate lamp is built in Builders/HaulBuilder and moved by HaulService (lines 59-78, ~402).

#### Design

**FIXED:** WalkSpeed 21, SprintSpeed 31, Difficulty.HollowChase `{25,26}`, pace spread ±6%. Stalker chase ×1.0, lunge ×1.45; Crawler chase ×1.0, lunge ×1.6; Brute chase ×0.98 with no lunge. Stalker/Crawler lunge duration 0.55 s and existing cooldown 3.5 s. Preserve stamina max 100, drain 18, regen 22, delay 0.9, exhausted resume 0.35 and winded 1.6 s ×0.85.

**FIXED:** preserve Haul.DuoPenalty 0.15 and SoloPenalty 0.35, producing 17.85 and 13.65; carriers cannot sprint. Preserve ordinary crate light, shared carrying, dropping and recovery. Do not tag the crate as a repulsion SafeLight.

**FIXED:** rewrite HollowSpeed.spec for every kind at D0/D1 and both pace extremes. Assert D0 normal chase minus walk is 2–6; D1 sprint minus normal chase is at least 3; every carrier is slower than normal chase; Stalker/Crawler lunge is faster than sprint; Brute lunge is disabled. Include tutorial overrides as a separate case. Remove the old duo-holds-distance assertion; update Haul.spec without changing the real penalty shares.

**FIXED:** tier-1 stop-2 scripted Crawler uses absolute pursuit 24 and lunge 40 for 0.55 s, overriding normal pace, chase multiplier and ChaseScale 0.55 for this encounter. Keep at least 1.5 s readable first-strike warning. Do not force a hit, promise a grab within a fixed number of lunges, or slow the chase below walk.

**FIXED:** Glance: hold Q / gamepad RB / touch LOOK button (placed above RUN by the same touchTop logic the HUD uses) swings the camera 150 degrees behind over 0.18 s and back on release; movement continues; no effect in the lobby or while held by a Hollow. Sprint FOV kick unchanged.

**CHOICE:** whether the glance is a CameraController mode or a ContextActionService bind in MovementController. Keep touch LOOK above RUN using the HUD’s placement logic.

**PROVISIONAL:** these are the selected initial speeds. Tune only after stalk and telemetry exist, using actual warning exposure, outcomes and controlled chase tests. Any speed or pace change requires recalculating every margin, stamina trajectory, tutorial exception and dwell reach check. Do not freely adjust walk within an old range.

**Dependencies.** Prompt 0. Order: speeds and kind behavior, specs, carrier verification, tutorial override, glance. Prompt 5 installs the tutorial encounter using these settings.

**Preserve.** Stamina, winded, carrier penalties, shared light and Logic/Payroll accounting. Update the earlier carrier speed requirement to the relationships above.

**Edge cases.** Solo carries at 13.65 with no sprint; two carriers at 17.85 with no sprint. Joining or dropping a carry does not create a SafeLight. A grabbed carrier drops the crate as today. LOOK must not overlap jump on landscape phones; verify in the device simulator. Glance changes camera direction, not root facing for Stalk.

**Acceptance.** `lune run check` passes. In Studio, use documented starting gaps, line of sight and movement state at early and late stops to demonstrate normal chase closing on walking, sprint gaining while stamina remains and winded vulnerability; distinguish lunge bursts from normal chase. Verify both carrier speeds and lack of repulsion, keyboard/gamepad glance and touch placement. Console clean; capture glance and carrier behavior. No universal catch-time or escape guarantee.

**Handoff.** HANDOFF with the final ladder table (walk, sprint, each kind at D0/D1, lunge, carriers).

### Prompt 2: Stalk, commit, door-forcing and tells

**Outcome.** Hollows show intent before violence. Stalk timers and commits tighten with difficulty while the separate speed ladder stays within Prompt 1’s margins. Some stops introduce a readable door-forcing episode.

**Audited baseline (verify current code).** HollowService.think (859-1076) and setState (204-212) replicate State as a model attribute; HollowAnimator.onState and VisibilityController read it (chase detection: Hunt/Windup/Grab/ Recover within 60 studs). Sensing: Difficulty.Aggression SightRange 118.75, AwarenessRange 37.5, Persistence 5.2, StrikeCooldown 0.72. Wanderers and alerted Hollows ignore range. Threat.total gives 1-2 Hollows at stops 1-3 (crew 1-4) and 3-6 at stop 10. Lit buildings repel (isLit, Repelled); sleepers start in buildings (Difficulty.Sleepers). BuildingService owns doors and ExitPoint. Audio has DoorForce, HollowStep, HollowWake, Breath. The HUD's pocket watch is in UI/Hud (~537-602); the carried lantern is Controllers/VisibilityController and Visual/CosmeticMotion (flicker).

#### Design — FIXED

New Stalk state. Enter from Prowl when a crew member is sensed, the target is beyond CommitRange, and the Hollow’s per-target budget permits it. Ordinary wanderers/alerts may commit directly; Prompt 5’s tutorial Stalker is explicitly a wanderer-with-stalk. Define server-owned `Tuning.Stalk.ReferenceRadius = 30` studs; do not derive NPC distances from Logic/Visibility or a client setting. Seek line-of-sight shadow points in `[0.8r,1.1r] = [24,33]` studs, outside every SafeLight and station lamp pool. Red edge danger lamps do not create gameplay pools. Assert `0.8 × ReferenceRadius ≥ max(CommitRange) + 4` (24 ≥20), so the band cannot overlap the immediate proximity-commit range. Facing means the target root look vector is within 25 degrees and distance within 40 studs. While faced, stop locomotion/step sounds and sway/breathe with the head still tracking. Glance does not count as facing. Move between cover while unobserved.

Commit rules in Config/Difficulty.Stalk, interpolated by D:

| Setting | D0 | D1 |
|---|---:|---:|
| MinStalkSeconds | 4 | 1.5 |
| MaxStalkSeconds | 12 | 6 |
| BackTurnedSeconds | 2.5 | 1 |
| CommitRange | 12 studs | 16 studs |
| AloneRadius | 14 studs | 14 studs |

Immediate Hunt commits: Surge, within CommitRange, or another Hollow seizes the target. Timed back-turn commits require MinStalkSeconds and an uninterrupted not-facing interval of BackTurnedSeconds; reset that back-turn interval when faced. Halve the back-turn threshold only if there is no crewmate within 14 studs AND the target is outside all lamp/SafeLight pools. Being alone does not commit immediately. MaxStalkSeconds runs while faced and overrides facing on expiry; it never creates an endless staring contest. Minimum stalk precedes timed commits, not immediate Hunt transitions.

First-strike guard: every new target, including immediate-commit, scripted and alerted targets, must receive at least 1.5 s readable warning opportunity before the first strike. Accumulate Stalk/coil exposure per Hollow/target only with line of sight within fixed `1.2 × ReferenceRadius = 36` studs. Hunt may begin sooner, but while exposure is below 1.5 s, block Windup, lunge, strike and grab initiation. In Hunt, replicate a warning-coil flag while guarded so the client displays the coil even outside the normal 16-stud Intent range. Cap approach movement so the Hollow cannot deliberately close inside 16 studs: from farther away, approach at no more than normal chase speed, then pace a retreating target without exceeding normal speed or crossing the boundary. If already inside 16, stop deliberate forward approach and coil; do not snap, push or teleport either character. A player approaching it or being moved by another system can reduce separation; the attack lock still holds. Occluded time adds no exposure. Preserve the guard through an immediate commit and re-entry for the same target; never clear it by leaving Stalk. New targets start at zero; ordinary short kind windups begin only after the guard is satisfied. The guard does not reset on every think tick, so staring cannot restart the delay indefinitely.

Budget and targeting: one stalk per Hollow per target per stop. After a grab, preserve the existing post-grab immunity and reset that target’s stalk budget when immunity ends. Switch to another crew member only when that member is within 0.6× the current target distance; reset target warning. If multiple Hollows sense the same target, only the nearest stalks and the rest Prowl; preserve Hunt fan-out. Lost line of sight for Persistence returns to Prowl. With no legal shadow point, hold, retry once per second and keep the stalk timer running. Disconnect ends the target’s stalk. Stun/stagger returns to Prowl and excludes Stalk for 6 s.

Door-forcing. Logic/HazardSchedule or a pure Logic/Doors uses the stop seed: initial probability 40%, stop ≥3 on every tutorial tier. A hunting Hollow targeting an unlit closed room requests forcing from BuildingService. One per-door/per-episode timer owns shake, DoorForce and opening: 3 s base; holding through a server-validated door ProximityPrompt adds 4 s once total, shared across all attackers. Queue additional Hollows; no per-Hollow timer or stacking hold credit. On expiry open the real path, allow entry without clipping and hold the door open 6 s before reclose is possible. Room light cancels forcing, cleans the timer/queue and repels. Preserve ordinary door ownership and cleanup.

Tells. Use fixed `r = Tuning.Stalk.ReferenceRadius = 30`: lantern lean within 30 studs, brightness flicker up to 15% respecting Logic/Visibility floors, watch stutter within 36; clear within 1 s of leaving range. Compute direction and phase in a pure Logic/Tells module with specs, using replicated State and positions. Watch, flame, breath and server warning thresholds use this fixed reference, independent of the Visibility slider; retain the slider's normal readability function.

Audio. Stalk Breath rolls off from 15 to 30 studs (`0.5r` to `1.0r` with fixed r=30). No steps while frozen; unobserved locomotion uses half-rate steps. Until Prompt 3 adds foot plants, use the existing timer at half rate; then replace its timing with plant callbacks. The existing nearness drone remains.

Replication: State attribute values are extended with Stalk; VisibilityController treats Stalk as not a chase (no black flicker) so the stalk stays quiet. Replicate the guarded warning-coil flag and target identity for Prompt 3 without requiring that later presentation work to enforce the server attack/movement lock. Use a basic readable existing coil pose until the refined animation is installed.

**CHOICE.** Implement shadow-point selection and state integration within existing navigation. Facing is fixed to the root look vector; do not add a camera remote. BuildingService owns door concurrency and timers; HollowService requests and responds to that ownership.

**Dependencies.** Prompt 1 (speeds). Prompt 3 reads the new state.

**Preserve.** Ordinary wanderer/alert commits, sleepers, grabs, post-grab protection, tier selection and lit-room repulsion, with the new first-strike warning guard. Replace direct ordinary Prowl-to-Hunt sensing with Stalk where eligible.

**Edge cases.** Solo alone-condition still requires being outside lamp light and minimum stalk before a timed back-turn commit. Tier-1 stop 1 has no attacks, only Prompt 5's scripted sighting. A glance never freezes a Hollow. Keep all per-target state independent; no warning credit leaks across targets, stun or run resets. Touch uses the door’s hold ProximityPrompt. Client Visibility changes must not change stalk position, commit distance, tell thresholds or warning credit. The warning hold constrains the Hollow's own approach, not player movement; close-spawn and player-approach cases still prohibit attack until the guard completes.

**Acceptance.** `lune run check` passes, including pure-rule tests for the fixed reference and band invariant, facing, minimum/maximum precedence, solo timing, target switching, warning exposure, approach clamp and door concurrency; Grabs audit unchanged. Change Visibility between 18 and 30 and assert identical server decisions. In Studio, show the 24–33-stud band, freeze/head tracking, timed back-turn commit and max-time commit while faced. Verify the guarded coil and at least 1.5 s opportunity for fresh targets on immediate Hunt from 30 studs, an alert, the scripted encounter and an already-inside-16 case. Confirm no deliberate crossing of 16 while guarded from outside, no early Windup/lunge/grab, and no target-state reset exploit. Show one shared door timer with multiple attackers, one hold extension, light cancellation and a real opened path at a seeded stop ≥3. Console clean; capture freeze/door and all kinds in Stalk via /photo. Check band silhouettes and tells on a phone at Visibility 18 and 30; correct local presentation if the fixed band is unreadable.

**Handoff.** HANDOFF with the state diagram and the provisional table; rbxfacts regenerated.

### Prompt 3: Body language

**Outcome.** The Hollows move like bodies with attention, weight, anticipation and follow-through. The Stalker looks the part. Problem: no look-at, no lean, 0.3 s windup unreadable at distance [OF, DI].

**Audited baseline (verify current code).** Animation/HollowPoses (pure CFrame math, gaits per kind, pose at 896-1030, cadence, IK reach); Controllers/HollowAnimator (Motor6D transforms every Stepped, onState, bursts, trails); Tuning.HollowMotion SpeedResponse 8, TwitchAngle 0.12; Tuning.HollowContortion; Visual/HollowCosmetics (MaxParts 40, shedding); the Stalker rig is 60 visible parts (HANDOFF 10-15). The audit's Grabs target fails poses whose hands or feet cannot reach. Tuning.Hollow.WindupSeconds 0.3 x kind windup.

#### Design — FIXED

Look-at: in Stalk, Hunt and Windup the head and neck turn toward the target with a 0.25 s lag and a cap per kind (Stalker 70 degrees, Crawler 50, Brute 35); in Prowl the head scans slowly; in the Stalk freeze the head keeps tracking while the body is still.

Weight: the torso leans into acceleration (from the root's velocity derivative, clamped), out of deceleration; stride length scales with speed as well as cadence; foot plants are timed to HollowStep (the animator emits the step cue at plant, not on a timer).

Anticipation. Replicate Intent when a hunting Hollow is within LungeRange 16 with line of sight and begins its committed approach. Intent drives a readable coil (shoulders back, head low) and the predictive 0.4 s audio hush. Separately, Prompt 2's guarded warning-coil flag displays that pose throughout the unmet first-strike warning, including beyond 16; it must not wait for Intent. The guarded flag does not repeatedly retrigger the hush. Intent's hush is not a guaranteed 0.4 s lead before contact and does not delay an otherwise eligible attack; the first-strike guard independently blocks approach/attack as specified in Prompt 2. Preserve kind windups (Crawler 0.21 s, Stalker 0.3 s, Brute 0.42 s) after the guard, with arms wide, haunches coiled or shovel raised so silhouettes read at 25 studs on a phone.

Follow-through: a missed strike over-reaches and stumbles for RecoverSeconds (0.4) with a readable recovery pose (this is the counterplay window; do not shorten it).

Transitions. Blend Prowl, Stalk, Hunt, Recover and Repelled transitions over 0.2–0.35 s with ease-out. Coil, Windup and lunge poses snap; do not blend away short attack tells. Stalk freeze uses sway and breath rather than a static pose.

The Stalker's look: a shredded coat (3 to 5 thin strips hinged at the hem, driven by velocity and wind from CosmeticMotion), pallor (skin toward Colors.Bone, darker eye sockets), within the existing part and cosmetic budgets (MaxParts 40 cosmetics; the audit's per-model budgets). Pallor and shredding grow with the run's progression value already used for contortion (30% at stop 1 to 100% at stop 10).

**CHOICE.** Implement look-at with a two-bone neck or head-only aim. Use primitive coat strips within budget, or the Blender rig pipeline if available; any required mesh upload is a HUMAN deliverable and stays pending until completed.

**Dependencies.** Prompt 2 supplies Stalk, warning guards and temporary half-rate steps. This prompt introduces plant-timed steps; remove timer-based HollowStep emission once plants own timing, preserving the no-step freeze and half-rate Stalk behavior. Preserve IK reach rules, grab poses and CrewPoses.

**Edge cases.** Performance quality: look-at and lean run on every client for every Hollow; cap at 6 Hollows with full secondary motion and simplify beyond 60 studs. Touch: nothing input-related.

**Acceptance.** lune run check green including the Grabs audit; /photo report lists every kind in every state with IK shortfall 0; a Studio clip (or 4 screenshots at 0.5 scale) at a phone-sized viewport shows the coil and windup readable at 25 studs; steps audible on plants; console clean.

**Handoff.** HANDOFF; note any HUMAN asset (mesh strips) left as primitives.

### Prompt 4: The bell, the dwell and the railing grasp

**Outcome.** A ready crew can shorten a stop and the departing train offers a readable, validated last-second grasp. Preserve a meaningful clock and physical reach; validate outcomes using actual player movement and latency.

**Audited baseline (verify current code).** Logic/RunRules phases and durations; Tuning.Run LastCallSeconds 15, LastCallGrace 3 s; Difficulty.StopClock Search {105, 75}, PerStop 4; Difficulty.DepartureAccel {4, 6}, ChaseWindow {7, 5}; RunDirector Enter/Exit.Departure (429-478), ExtendPhase; StationService.BeginDeparture and step (prismatic motor); CrewService.positionTick (boarding = TrainService.IsInside), MarkLastCall, ResolveDeparture, ClutchBoardSeconds 2 and the Clutch Fx; Logic/DepartureSchedule milestones; UI/ Hud watch; TrainBuilder doors/railings (RailingPilot exists); Animation/CrewPoses (locomote, limp, grabbed). Upgrades.SteamWhistle adds chase seconds.

#### Design — FIXED

Bell. Put an E/touch ProximityPrompt on a bell rope in the crew saloon, near the route board (exact position CHOICE). Set `doorsOpenAt = run.station.startedAt` and snapshot the original `params.dwell` when the stop opens. During Dwell calculate `u = (serverNow − doorsOpenAt) / original params.dwell`. The denominator includes the final 15 s LastCall; it is not the Dwell phase duration. Keep both baseline values unchanged after a bell pull, and use this exact definition in the balance report. Eligibility is `(all living, non-eliminated crew aboard AND u ≥0.40) OR (aboardLivingCount ≥ceil(livingCount/2) AND u ≥0.60)`, with livingCount >0. Solo counts as its own crew; AFK aboard counts as aboard; eliminated players are excluded. The second branch is at least half, not a strict majority. Server-validate phase, proximity and eligibility.

Set `newDepartAt = min(existingDepartAt, now + 30)`, accepting only if it strictly shortens. Implement authoritative RunDirector.ShortenStop: update departAt, set Dwell.endsAt to departAt − LastCallSeconds (15), republish run.station, and retain startedAt. Repeated requests are idempotent and cannot extend or restart a clock. DepartureSchedule returns only the latest crossed milestone after a jump, so T-30 fires once and T-10 follows normally; do not replay every skipped warning. Play WarnBell and store BellUsed/branch once for stop resolution; do not emit stop_resolved on the pull. Stepping off afterward invokes normal departure rules.

Keep original params.dwell for fog/collapse timing: shortening departure must not jump a hazard front. Cancel and clean an active timed event, schedule no further event for the shortened stop and attach no reward to a canceled event. Village has no bell.

Dwell. Set Difficulty.StopClock.WalkReference 30, Search `{80,60}`, WalkMargin 1.4 and PerStop 3. Preserve Detour 1.2 and unmentioned terms. DifficultyModel.dwell uses WalkReference for its timer’s walk term. StationReach and actual round-trip checks use walk 21 and real sprint/stamina, not reference 30. Extend reach checks to payroll. StationReach currently measures containers and loose loot only. LayoutGen deliberately places `plan.payroll` at the back of the yard; keep that risk/reward placement. For an uninjured solo Hand starting at doorsOpenAt, require `farWalk/21 + farWalk/13.65 + 0.5 s (pickup and delivery holds) + deliveryApproachSeconds + any mandatory door interaction ≤ original params.dwell − 15`, with no sprint or upgrades, where farWalk is DifficultyModel's far-corner bound (Detour 1.2 included) and bounds every payroll cell. Use the existing StationReach breadth-first route distance to the payroll cell, rather than straight-line distance, for the audit seed set. Assert in `tests/StationReach.spec`, for every payroll-enabled archetype at D0 and D1, that the cell is reachable and its route distance fits farWalk. Check the time inequality at stops 1 and 10; stop 1 has the shortest clock at fixed D, while stop 10 reproduces the reviewed calculation. `deliveryApproachSeconds` covers the additional return from the platform route endpoint to the actual delivery marker at carry speed; do not silently omit that segment. [CALC] At clock B, D1, stop 10, the bound gives a solo carry of 65.8–87.5 s against 152–187 s of open doors before LastCall, so nominal slack before additional delivery-approach or door time is 84.17–102.95 s (about 84–103 s). CoalYard is the minimum; Market is the maximum. Because that slack is wide, use no pathfinding harness or nearer-placement fallback. Confirm the Detour 1.2 assumption once in Studio with PathfindingService (crate-width agent) from the payroll cell through the usable boarding entrance to the delivery marker on the archetype with the greatest farWalk (Minehead). Record the path length and delivery-approach time, and verify the complete return fits the inequality. If any case fails, raise the affected allowance and re-run the route model; never use an unreal player speed to pass. This tests physical feasibility on a clear route, not guaranteed survival, complete looting or success after a voluntary early bell. Doors-open target 2–3.5 min; mixed-bell completed-run target 38–44 min, conditionally.

Grasp. During the live Departure chase window after grace, Jump may attempt a grasp for an off-train player not held by a Hollow. Use train-local door railing anchors; the train/rail stays static in world space while the station moves. Nominal root-to-nearest-rail reach is 3 studs. Add `ReplicationTolerance = 0.5 + min(max(0, closingSpeed) × ReplicationLagSeconds, 1.0)` (PROVISIONAL: 0.5 studs, `ReplicationLagSeconds = 0.1`), giving effective accepted reach 3.5–4.5. `closingSpeed = rootVelocity:Dot((railPosition − rootPosition).Unit)`, using server-observed velocity, root position and the chosen static rail point from the same receipt snapshot; use zero when the direction has zero length. Negative closing speeds add nothing. The extra term is capped at 1.0 stud, bounding accepted reach at 4.5; this cap alone is not an anti-cheat guarantee. [CALC] At ideal closing speed 27 studs/s (31 − 4·1 at D0), a hypothetical 50 ms stale position is 1.35 studs behind the press pose; 100 ms is 2.7 studs. The maximum total tolerance of 1.5 studs covers the former geometric error but not the latter. These are illustrative offsets, not measured replication delays or proof that presses will be accepted. Retain the bounded setting for the network test below. Snapshot the server's replicated root position and rail geometry when the request is received, and use that single snapshot for reach, telemetry and the decision. Do not subtract latency from a player-position history, extrapolate the root or search multiple favorable samples. Add no position-history buffer for this mechanic. Estimate press time as receipt server time minus measured one-way latency clamped to 0–0.2 s; use this estimate only to check the actual boarding window, not to rewind geometry. Accept only if the estimated press lies in `[chaseStartAt, chaseEndAt]`, receipt is no later than `chaseEndAt + 0.2`, receipt-time gap is ≤ effectiveReach and the player is still alive and eligible. Never trust a client-reported earlier timestamp or position to authorize boarding. Capture the snapshot before any queue or animation delay. Before final elimination, process eligible pending inputs with at most a 0.2 s resolution buffer; the buffer does not extend the estimated press window or reopen it for a new late press.

On success credit Aboard immediately at attachment, before ResolveDeparture; maintain Aboard throughout Grasp so positionTick cannot undo it. Attach to the static train anchor, Grasp=Hang for 0.6 s then Haul for 0.5 s along the doorway’s local axis, then release into the doorway. Disable door-frame collision for that 1.1 s sequence and restore it on completion or cleanup. Preserve server validation and the existing client movement owner outside this attachment; avoid competing position authorities. Death/disconnect cleans attachment, collision state, input and animation; disconnect retains the existing cause. Award Clutch, stationsDeparted and run-log credit once only, including a valid press just before window closure.

Presentation. Successful grasp gives the local 0.35 s camera kick, Clutch and existing MADE IT notification. A failed attempt gives Grasp=Miss and a 0.5 s fall-short/stumble, without eliminating the player. Rate-limit attempts and ignore Jump during the stumble; allow another attempt afterward if the real window is still open. Define `gapStuds` as the receipt-time root-to-nearest-rail distance, `effectiveReach = 3 + ReplicationTolerance` (from the same snapshot), and `shortfallStuds = max(0, gapStuds − effectiveReach)`. Keep exact values internally and in numeric telemetry. If ultimately left behind following a reach miss, show the measured shortfall to 0.1 stud (use “less than 0.1 stud short” for a positive smaller miss); “3 studs short” requires a shortfall of 3, not a root gap of 3. A window/state rejection gets its actual reason, not a fabricated distance miss. With no grasp attempt, show no measured miss. Add pure CrewPoses hang/haul/fallShort.

Touch: the existing jump button is the grasp input; no new button. Gamepad: A.

**CHOICE.** Reuse verified door/railing anchors already used by boarding/LeakArrows where appropriate. Select WeldConstraint or AlignPosition to fit existing movement ownership; preserve the receipt-time geometry, attachment and credit rules.

**Dependencies.** Prompt 0 (events), Prompt 1 (speeds; the gap math assumes sprint 31).

**Preserve.** T-0, LastCall 15, grace 3, acceleration `{4,6}`, base chase windows `{7,5}`, SteamWhistle extension, Clutch, close calls and stamps. Change only the timer-sizing walk reference, Search/PerStop values, bell clock synchronization and grasp interaction specified here.

**Edge cases.** A held off-train player prevents the all-aboard branch, but cannot prevent the half-aboard branch after 60% if enough living members are aboard. Two players may grasp the same doorway using two anchors. Joiners spawn aboard as today. Village has no bell but permits grasp. Repeated bell or grasp messages must not duplicate credit. A valid attachment that finishes after the chase window retains its credited board.

**Acceptance.** `lune run check` passes with tests for both bell branches (1/2/3/4 living crew), exact original-dwell percentage calculation, authoritative phase ends, no extension, warning deduplication, hazard continuity and canceled events. Add the payroll route/placement checks above and regress ordinary loot reach. Test grasp estimated press just inside/outside both window boundaries, receipt after the 0.2 cap, receipt gaps just below/at/above effective reach, closing speeds negative/zero/5/10/27 studs/s (tolerance 0.5/0.5/1.0/1.5/1.5), zero-length rail direction, no favorable-history search, simultaneous grasps and once-only Aboard/Clutch/stat credit. In a two-client network test, use measured one-way delays 0/50/100/200 ms, variable replication/event timing and frame rates; log client-observed press gap for diagnosis only, server receipt gap, timing estimate, tolerance and decision. Client-owned physics does not establish that a button event and position update represent the same instant. The tolerance (0.5 + closing-speed term) is a starting setting; use the matrix to measure actual input/physics timing and assess `ReplicationLagSeconds`, rather than treating it as proof of fairness throughout that delay range. Repeated rejection of visually in-reach presses or acceptance beyond the specified server reach fails the check: repair input/geometry handling and update this specification and affected calculations before accepting Prompt 4; do not silently enlarge reach or claim latency coverage. Studio: demonstrate legal bell use, T-10/T-0, hang/haul, retry and measured shortfall. Record starting gap, stamina at acceleration start, grace use and re-sprint policy; compare only with matching trajectories. Console clean; screenshots of hang/miss. Keep unavailable two-client/real-device checks explicitly pending.

**Handoff.** HANDOFF with the bell and grasp numbers and the Studio steps.

### Prompt 5: First run and AGAIN

**Outcome.** The first three stops introduce safe exploration, a readable Crawler encounter and stalking. A wipe or victory offers one tap to ready the same crew for another run.

**Audited baseline (verify current code).** Config/Tutorial tiers (tier 1: stop1Cap 1, dormant, grace 25, no scripted grab; tier 2: scripted Crawler, zone 100; tier 3: hull/leaks/stamina/vote prompts), prompts list, ScriptedGrab; Logic/Tutorial.crewTier (least experienced); TutorialService, TutorialController; Difficulty.Leaks EarlyCap 1 to stop 3; RunDirector Enter.RunEnd (12 s) -> Lobby -> LobbyService.ResetReady; UI/RunCard (CLOSE, H toggles); UI/Lobby ready toggle and SetReady; runs happen in car servers of at most 4 (Tuning. Cars), so after RunEnd the same players are in the same server's Lobby phase.

#### Design — FIXED

Tier 1: stop 1 keeps grace 25 and no attacks. When the first crew member steps off, one scripted Stalker appears in line of sight 15–17 studs from that player. That is inside `Tuning.Visibility.RadiusMin` 18, so it falls within the validated readable range at every Visibility setting. It stands at least 4 studs outside every lamp pool, at the edge of the light. With no legal point there, use the nearest legal point up to 24 studs (the ReferenceRadius band's inner edge). It holds the Stalk freeze for at least 3 s after anyone first has line of sight. It then withdraws at walking pace, visibly, into the dark; it never vanishes in place. It withdraws when faced for 1 s (after the 3 s minimum), or once every living crew member who is off the train has had 1.5 s of line of sight, or at 12 s after appearing, whichever comes first. Crewmates still aboard are not waited for. The existing tells (lantern lean within 30 studs, watch stutter within 36) and one breath cue draw attention; there is no screen shake. It cannot Hunt, strike or grab. Log each player's line-of-sight seconds (`sighting_exposure`). Server line of sight records an opportunity to see it; G1's think-aloud establishes whether players noticed it. This is E2's treatment arm; the control arm has no sighting. Stop 1 also keeps no leaks on the first cruise (EarlyCap 0 for tier 1 until stop 2), with Move/Loot/Light/Edge/Bell prompts. Stop 2 moves in the scripted Crawler and SkillCheck prompt with oversized zone 100, using pursuit 24, lunge 40 for 0.55 s and at least 1.5 s readable first-strike warning. A player may sprint away without a grab. Stop 3 caps to one awake Stalker as a wanderer-with-stalk, targeting the first player 20+ studs from the train after grace; if nobody leaves the light, no encounter is required. The no-attack rule is stop 1 only. Tier 2 retains zone 100 and grace 15 without its scripted grab; tier 3 unchanged. Hull/Vote prompts remain on the first cruise/junction.

Readable threat rule. Enforce the per-target 1.5 s warning guard from Prompt 2 on every first strike, including the scripted Crawler; its ordinary short windup is insufficient. Preserve stop-1's no-attack rule and keep unrelated Surge/ordinary wanderer interference out of tier-1 stops 1–2. The controlled scripted encounter at stop 2 is an explicit exception to that ordinary wanderer exclusion. Teach facing with root orientation (“Face it and it waits”), while explaining that staring only delays commitment and glance merely looks behind.

AGAIN. Add AGAIN/DEPOT to the RunCard (gamepad A/B and touch), keeping the card and crew-ready count readable. Eligible members are the present participants of the ended run, alive or eliminated. Queue accepted RunEnd presses; on Enter.Lobby, after LobbyService.ResetReady, apply them to ready state. Start the 20 s fallback at the first applied press in Lobby, including queued presses applied then. A later Lobby press starts it if none was queued. Start when all present eligible members are ready or when 20 s expires with at least one ready. Keep RunEnd’s 12 s presentation. DEPOT closes the card, clears that player’s queued/ready state and leaves them unready in the hall. Late joiners can use normal ready controls; leaving updates the eligible count. Server-validate and emit again_pressed once per accepted player/card.

Deepest stop: show stats.bestStation on the ticket book cover and the Depot roll (Prompt 8 styles it).

**CHOICE.** Card layout and ready-count presentation, within the existing RunCard style. The stop-3 wanderer-with-stalk behavior is fixed.

**Dependencies.** Prompts 2 and 4. Preserve. Tutorial.crewTier (least experienced rules the crew). Replace. Tier 2's scripted grab moves to tier 1 stop 2. Remove. Nothing.

**Edge cases.** Lowest-experience Tutorial.crewTier continues to rule mixed crews; show “Riding at a new Hand’s pace.” Do not impose a lifetime cap on how often a veteran may join new players. Solo and all-dead crews can retry. A leaving player is removed from the ready denominator. Touch buttons use a large bottom row without covering stamps.

**Acceptance.** `lune run check` passes with tutorial and ready-state tests. At tutorialRuns override 0: stop 1 has no hunt/first-cruise leak, stop 2 shows the readable ambush and allows escape or a real skill check, stop 3 offers the single Stalker when someone ventures out. After a wipe, AGAIN survives ResetReady and starts a new run without another lobby-UI action; also test queued/late presses, 20 s fallback, DEPOT, leaving and solo. Console clean; capture the card.

**Handoff.** HANDOFF.

### Prompt 6: Station material, edge, grade and density; the lighting lock

**Outcome.** Stations read Victorian-at-the-frontier, cold and lonely but legible, and no longer medical or modern; the Depot Hall and the train interior have one settled warm-amber state with a reference. Problem: hazard furniture, whitewash, limewash and cyan grades [OF]; lighting retuned repeatedly with no reference [OF].

**Audited baseline (verify current code).** Config/Surfaces, Logic/Luminance, Builders/Limewash (station and train), Builders/StationDressing (edge rails, tape, red strip; SinkholeEdge tag), Config/Stations palettes and edges, Tuning.Visibility.Grades/Rim/Beacon/Budget, Scenery/StationFog, tools/visibility harness and docs/visibility/*; Scenery/Sky LOBBY table (brightness 0, exposure -0.1, ambient 10/10/12), Builders/ LobbyBuilder PointLights (~438-482), Builders/TrainInterior lights and doors, tasks 001/011/012, tools/ shot.ps1, the audit's part/light budgets, LORE sections 5-8 and the period checklist.

#### Design — FIXED

Surface rule in Config/Surfaces: keep station colour channels within 18–232, with bone/parchment on trim only; enforce palettes and dressing colours in a spec. This is a style rule, not the readability acceptance test. Whitewash coping becomes wet grey-brown stone (about 120,112,100), keeping the blue-brick margin. Remove Limewash.station bands. Preserve Limewash.train lining where consistent with the train’s separate material direction; retain brass. Do not apply a station-only clamp indiscriminately to the train.

Edge: StationDressing replaces yellow-and-black posts, striped tape and the glow strip with a red oil danger lamp on a timber post every 4 tiles, rope between stakes, broken ground and ember cracks (red emissive material in the ground, not a strip). Every danger lamp has emissive glass. Set `DangerLampMaxLit = 8` initially (PROVISIONAL); allocate red PointLights of range 10 to evenly spaced lamp positions only after reserving all other station lights. The count is `min(lampCount, DangerLampMaxLit, max(0,96 − otherLightCount), max(0,64 − otherLitLightCount))`; count all created PointLights against the 96 total and enabled ones against 64 lit. Danger PointLights cast no shadows. Do not create extra disabled PointLights to evade the total count. Performance quality uses emissive glass only, with zero danger PointLights. These red lamps are warning decoration: no SafeLight tag, repulsion, gameplay lamp-pool registration or shadow-point exclusion; actual lit platform/building pools retain their existing behavior. The SinkholeEdge tag and Edge.RailBack/TapeBack logic are untouched.

Grades: Tuning.Visibility.Grades saturation 0.18 -> 0.10 (PROVISIONAL 0.08..0.14), tints shifted off cyan toward moon green-grey and blue-grey; Infirmary "carbolic cyan" becomes gaslit green-grey. The train and lobby stay warm (unchanged ramp).

Material language per archetype (LORE 7 gets the table): company buildings (booking hall, station house, hotel, infirmary, school) in brick, stone dressings, slate, cast iron, bottle green and oxblood joinery; yard and village in board-and-batten timber, tin, canvas, rope, oil lamps; lettering painted on boards in the LORE typography. Period checklist run before finishing.

Density pass. Every archetype has foreground route-side clutter at 1–3 studs, midground canopies/gantries/water towers at 8–20 studs and one skyline landmark visible from the platform. Run `AUDIT_SEEDS=6 lune run audit Stations` using the shell’s environment syntax. Preserve routes, loot access and silhouettes.

Audit budgets copied into this brief; reconcile classification against the current .lune/audit.luau before editing:

| Target | Parts | Triangles | Lights | Lit lights | Shadow lights | Emitters |
|---|---:|---:|---:|---:|---:|---:|
| Station stop | 9,000 | 375,000 | 96 | 64 | 0 | 60 |
| Train | 1,800 | Existing audit | 34 | Existing audit | 10 | 4 |
| Lobby | 3,200 | Existing audit | 48 | Existing audit | 16 | 12 |
| Haul | 2,000 | Existing audit | 36 | Existing audit | Existing audit | 12 |

The audited per-model entry (130 parts, 1 light, 3 emitters, at .lune/audit.luau:395) applies to its configured target after the station list. Confirm that target before applying it; do not assume it is a blanket Hollow limit. Preserve HollowCosmetics.MaxParts 40 and the established rig budget separately. A table entry saying Existing audit means no new limit is invented here.

Lighting lock. Config/InteriorLight centralizes local Depot Hall/train fixture colour, brightness, range and fixture-specific bloom inputs only. AtmosphereController and Sky.LOBBY retain global Lighting/ambient/exposure ownership; station presentation must not inherit the interior recipe. Character is fixed, values provisional: low warm ambient, bright 2600 K amber fixtures (about 255,190,120), brightness about 1.2, range 20–24, brass/glass glints, bloom restricted to flames and deep shadow between lamps. Trial lobby ambient about 26,20,14 and exposure 0 only through the existing global lobby owner; do not put them in InteriorLight or apply them to stations.

Save spawn, ready-position, saloon and workshop reference shots in docs/direction/reference/ using tools/shot.ps1. Lock named camera position, grade, quality, hour and exposure in the shot script. Measure a reference mean-luminance band per shot and check future drift; pair averages with local edge, nearest-obstacle and Hollow-silhouette checks in motion, chase dim and Performance mode. Record whether the harness renders Highlights. Mark tasks 001/011/012 superseded once the new reference state is approved.

Interior doors: panelled, with brass furniture and a glazed light. CHOICE primitives within budget, or a Blender mesh through the train pipeline (HUMAN: owner upload).

**Dependencies.** Independent of gameplay behavior, with shared-file coordination for builders, visibility tuning, Sky.LOBBY, LobbyBuilder and TrainInterior. Do not assume file isolation without checking Prompt 1–5 changes.

**Preserve.** Rim highlights, beacon, lantern cone, the Visibility slider and floors, the chase dim logic, station layouts and loot. Replace. Whitewash, limewash, hazard furniture, cyan grades, scattered lighting numbers. Remove. The white edge line (already gone) and the limewash builder's station path.

**Edge cases.** Verify danger-light allocation against the combined station totals (96 lights, 64 lit), including ordinary lamps and other effects; extra danger lamps retain emissive glass and Performance creates no danger PointLights. Assert no danger lamp contributes to SafeLight, repulsion or stalk-pool exclusion. Re-run the dim-screen harness as a regression record and document Highlight support. Add local edge, obstacle and Stalker checks at 24, 30 and 33 studs, with Visibility 18 and 30, under chase dim and Performance; a whole-frame luminance average cannot certify them. HUMAN: verify the same targets in motion on a real phone at 40% brightness. If unreadable, correct local light/rim/value contrast while preserving the material direction and fixed server distances, then recheck.

**Acceptance.** `lune run check` passes with palette specs; `lune run preview Halt out.json --hour=22 --grade=Halt`, rendered with `--cam=station`, is compared under locked conditions with Oct 8/13 references. Inspect platform stop 1, hall and saloon in Studio at 0.5 screenshot scale. Report all applicable part/triangle/light/shadow/emitter counts, local readability results and LORE period-checklist results. Owner judges the look; the builder records measured results and any pending phone check. Mean bands and palette compliance alone do not pass readability.

**Handoff.** HANDOFF; LORE updated (materials table, danger lamps, Mabel note); reference shots committed.

### Prompt 7: Sound hierarchy, stalk audio, footsteps and the ping

**Outcome.** The mix tells you what matters, where it is, and who is near you, without chat; silence is used on purpose. Problem: 60 cues with ducks but no stated hierarchy; nothing before sight; identical footsteps [OF].

**Audited baseline (verify current code).** Config/Audio (cue table), Controllers/AudioController (groups LastTrainOut > Ambience > Outdoor, Cues, Steps; Warnings beside; three sidechain compressors), Controllers/ FootstepController and Logic/Footsteps (takes per surface), ThresholdController (walls EQ), the drone, Tuning.Departure.Duck*, omens (Hush), Remotes, NetService rate limits. The baseline HANDOFF records no recent audition; perform the audition gate rather than assuming existing audio is verified.

#### Design — FIXED

A priority table in Config/Audio (data, read by AudioController for duck depth and polyphony): 1 departure warnings and the clock; 2 threat (windup swipe, slam, scream, DoorForce, stalk breath, wake); 3 player feedback (footsteps, hit, winded, loot, deposit, UI, ping); 4 ambience (drone, wind, rain, train run, station eerie); 5 lobby piano. Higher duck lower; the existing compressors are rewired to this table.

Silence. Intent from Prompt 3 starts a 0.4 s predictive duck of ambience and steps; do not trigger it from a Windup that has already begun or promise a fixed lead before contact. It may fire without a strike and never changes attack timing. After arrival brakes, 2 s near-silence (ambience −12 dB, no drone). Preserve the Hush omen. Warning cues remain audible throughout.

Stalk audio. Breath rolloff is 15–30 studs, using fixed `r = Tuning.Stalk.ReferenceRadius = 30` as in Prompt 2, independent of Visibility. No steps while frozen; unobserved walking has half-rate plant-timed steps once Prompt 3 is installed. Occasional board creak or pebble accompanies a step between cover.

Per-player footsteps. Assign four distinct boot timbres (hobnail, soft leather, clog, heel) by stable crew slot/join order, not user-ID hashing. Preserve slot identity during the run and allocate a free slot for a joiner. Use pitch offsets within PitchJitter; crewmates’ steps audible to 40 studs, own steps low-passed.

Ping: new remote Ping (ToServer, no payload, rate-limited 1 per 3 s in NetService), V / gamepad Y / touch button beside RUN: a 1.5 s glow pulse at the pinger (client Fx from a Fx "Ping" event), the watch compass flicks to them for 2 s, a soft whistle cue. Never in the lobby.

HUMAN audition gate. Owner checks headphones and phone speaker: departure warning priority over drone/threat/ping, Intent hush, arrival hush, stalk-breath direction, distinct footsteps and ping. Keep cue IDs unless an audition justifies a Creator Store replacement from HANDOFF 10-17; document old/new IDs and any required asset permission.

**Dependencies.** Prompt 2 supplies Stalk/audio rules; Prompt 3 supplies Intent and plant timing. Preserve groups, Settings’ Ambience row, established ducks and cue IDs except documented audition-based replacements. Warnings > threat > ping; retain watch/glow visual equivalents.

**Edge cases.** Touch: the ping button must not crowd RUN/LOOK/jump; use the HUD's touch-top logic. Solo: ping does nothing but the whistle (fine).

**Acceptance.** `lune run check` passes, with Footsteps coverage for distinct crew-slot assignment. Studio AudioAnalyzer or instrumented Output verifies Intent-triggered duck and arrival hush; audition four test characters in a multi-client simulator when available. Confirm warning priority, planted timing, directional stalk cues and ping’s visual/audio behavior, with clean console. Output confirms scheduling, not subjective audibility; leave owner audition pending until performed.

**Handoff.** HANDOFF with the priority table and the audition checklist.

### Prompt 8: One Brass loop, Line Mastery as the record, errands as story, the Depot premise

**Outcome.** Three reward layers (Brass, Crew Rank, Line Mastery), each with one job, support early, middle and long-term status goals, while the world explains why the Hands travel the line. Keep Rank/XP, cosmetic milestones and established non-Brass unlock paths.

**Audited baseline (verify current code).** Logic/Economy (brass payout, daily double, solo charter), Tuning.Economy, Config/ Progression (milestones with brass or cosmetic rewards, stats), Config/Cosmetics (unlock paths default/ milestone/brass/robux/gamePass/charter/npc), Logic/Catalog, Services/ShopService, UI/Outfitter (BUY), Services/ProgressionService.PayRun, Types.Profile.brass, Config/NpcQuests (brass per errand), Config/NpcDialogue/Mabel, UI/Summary, HUD "+BRASS BANKED" for relics, Builders/PosterArt, the lobby's Line Mastery board and departure board, UI/RunCard stamps, LORE sections 1-4, Logic/RunTicketModel.

#### Design — FIXED

Brass stays earned, shown and spendable (provisional; A.4 states why and how it is reviewed). Remove the overlapping rewards rather than the currency. Brass buys ordinary cosmetics in the Outfitter and nothing else: no Brass discounts layered on top of other unlocks, and no Brass on status items. Keep payout, the daily first-run bonus, the solo charter and relic +BRASS BANKED. Check that a typical first run (Short Line) earns enough for the cheapest Brass item within two runs, and print that from the report. Log sources and sinks through LogEconomyEvent. Preserve charter stamps and their unlocks.

Line Mastery is the record. Do not build a separate service record. Add the rows below as Line Mastery milestones (Config/Progression, evaluated by Logic/Milestones) whose reward is the cosmetic; extend the milestone schema only enough for livery_royal's AND condition. Remove Rank conditions from Brass-priced items. The milestones gate the status items only, the ones whose names claim an achievement: lantern_aurora, hat_topper and livery_royal, plus hat_lampcap and trail_brass. The other Brass-priced items stay Brass-priced. Status items listed below lose their Brass price and keep only this fixed requirement. Store the rule in Config/Cosmetics and evaluate it through Logic/Catalog with a schema that supports AND conditions. Use existing Profile.stats keys: verify the actual rescues/clutch-board key names rather than introducing parallel counters.

lantern_signal, hat_conductor, hat_goggles and trail_steam keep their Brass prices.

| Cosmetic ID | Fixed requirement |
|---|---|
| hat_lampcap | bestStation ≥8 |
| trail_brass | profile.stats.clutchBoards ≥5 |
| lantern_aurora | victories ≥3 |
| hat_topper | victories ≥5 |
| livery_royal | longVictories ≥1 AND stationsDeparted ≥50 |

A stop is credited when the player is aboard at departure, including a validated grasp or early-bell departure. Partial runs keep earned stop credit; repeat departures follow the existing cumulative rule. Disconnection earns no future credit. Preserve existing rescue and victory accounting and prevent duplicate credit. Existing Robux/gamePass/milestone/charter/NPC paths remain as specified for their own items; audit that every cosmetic has one coherent intended unlock path. The profile-local Roll uses existing stats; this pass adds no global leaderboard. The goals span progression, but make no promise that an item unlocks in a first evening or a week.

Errands: NpcQuests.brass removed; Mabel's chain pays its cosmetic at the end and a story line per stage; the quest tracker copy stays.

Premise in the world (copy only, no new systems): lobby posters and notices (PosterArt): "THE DEPOT STANDS WHILE THE LINE RUNS", "RELIEF DEPARTS AT DUSK. HANDS REPORT TO THE CLERK", a Roll of the Terminus (the Line Mastery board becomes the Roll: names and liveries of those who reached it, per profile stats); the departure board names the Relief; the run card's left-behind stamp reads "ENTERED, NOT RECALLED"; Mabel's lines rewritten to the premise (issuing the Relief's tickets, counting who comes back); a lamp-post plaque at every station "KEPT LIT BY THOSE WHO WENT BEFORE" (one static part). The Hollows remain unexplained (LORE 3 unchanged). No immortality text anywhere.

Names. In UI/copy, players are Hands, a run is a Relief and the lobby is Coldharbour Depot. Use Config strings, keeping code identifiers. The game’s title remains Last Train Out.

LORE.md gets a new section 0 "Premise" with the canon above, and the Mabel note.

**CHOICE.** Poster and Line Mastery layouts within the established ticket/ledger style. Item goals and credit rules above are fixed.

**Dependencies.** Prompt 0 telemetry; Prompt 5 shows bestStation. Coordinate shared files with presentation prompts; the full reward pass is not a prerequisite for first loop testing.

**Preserve.** Rank/XP, the Brass payout and daily double, milestones that grant cosmetics, charter stamps, haul and payroll, the mystery ticket. Replace: Brass prices on the five status items with the record. Remove: Brass discounts that overlap other unlock paths.

**Edge cases.** Preserve existing Brass balances; avoid empty Summary rows. Test Economy, Catalog, Ledger/Summary, AND record rules and once-only departure/rescue/victory credit. Keep existing rewards and ownership migrations intact. Phone Outfitter rows show record requirements, no Brass prices, at the usual half-scale review size.

**Acceptance.** `lune run check` passes; Studio shows correct XP payout with Brass earned, shown and spent on ordinary cosmetics only, record progress and each unlock rule including both livery_royal conditions. Existing milestone/Robux/charter/NPC paths still work. Roll/posters are readable from spawn and ready positions; Mabel’s lines and LORE carry the premise without explaining the Hollows. Document account-bound product/asset checks as pending when unavailable.

**Handoff.** HANDOFF; LORE updated; rbxfacts regenerated.

### Prompt 9: Release plumbing

**Outcome.** Release has an honest maturity classification, a real phone pass, measurable acquisition assets and verified analytics. Separate code changes from human/account actions and post-release observations.

**Audited baseline (verify current code).** Blood: bite puffs are smoke-textured dark red with dark debris (HollowAnimator.burst), the Hit effect is a red screen pulse, the Stalker has "bloody hands" colouring; no realistic injuries [OF]. Settings has Hud Show/Hide (a creator mode already) [OF]. Touch: HUD lays out around the touch controls and the car prompt taps; last device test several sessions ago (HANDOFF). Robux ids nil.

#### Design — FIXED

Blood audit. Keep blood visibly unrealistic in colour and shape; reduce bite puff count by one third as requested. No realistic wounds or pooling. Audit bite debris, red hit pulse and Stalker hand colouring as well as fear across the full experience. Do not certify a maturity label from one effect. HUMAN: answer the current questionnaire accurately; record the assigned label and any discrepancy from the intended Mild presentation.

Creator mode: Hud Hide also hides name tags and the ping glow for the local player; document the setting as "Creator mode" in Settings copy.

Phone pass (HUMAN, with the builder's checklist): a real phone in landscape and portrait, Performance quality, 40% brightness: lobby, boarding, stop 1 loot, a grab and skill check, the bell, the grasp, the run card, the Outfitter; note every overlap or unreadable element; resolve blocking issues before release and record the result.

Store listing: "co-op survival" first; thumbnails: 2 to 5 active for personalization, one of them the amber lantern in the dark with the tall silhouette at the edge of the light (the owner's composition); HUMAN art.

Audience. HUMAN: complete the current verification, two-step security, applicable fee/subscription route and Kids/Select evaluation shown in Creator Hub. Use A.3’s official source and recheck it at release; this draft does not substitute for account eligibility or a passed evaluation.

Chat: nothing to build; the ping and footstep identity are the comms.

Ads. Require a passed phone check and verified analytics before spending. Before tuning or scaling from quit curves, require at least 300 unique first-run players per device cohort plus 150 completed crew runs, with counts and uncertainty intervals. Use measured mean visit minutes in the visits-to-CCU identity. Do not treat elapsed calendar time, a simulator result or an unvalidated success percentage as sufficient evidence.

**Acceptance.** HANDOFF lists completed code work, actual human/device/account checks, pending actions and exact steps. Record unresolved asset IDs, product setup, publishing permissions, references, auditions and device results explicitly. Never mark those passed because the scripts ran.

### Prompt 10: First three minutes, route length and return hooks

**Outcome.** A first-time player has control within 10 s, reaches stop 1 within 120 s and sees a Hollow within 180 s (A.4). First runs fit a normal Roblox session, and bringing a friend is one tap.

**Audited baseline (verify current code).** Tuning.Cars (MinPlayers 2, CountdownSeconds 40, ExitWindowSeconds 10, ArrivalWaitSeconds 20); CarService (teleports a car to a reserved server; solo players use the hall's Ready through LobbyService); Tuning.Run (CountdownSeconds 10, BoardingSeconds 4, CruiseSecondsPerKm 6, StationCount); RunDirector sets `run.stopCount = Tuning.Run.StationCount` and calls `DifficultyModel.forStop(nextStop, Tuning.Run.StationCount, …)`; JourneyPlan, Hud and ChalkSlate already read `run.stopCount`; Logic/Economy `dailyBonus` (DailyFirstRunMultiplier, DailyBonusCap); the route vote.

#### Design — FIXED

First visit. Spawn facing the hall's START board, with one plain prompt: START (ride now) or BOARD A CAR (ride with others). Cars CountdownSeconds 40 → 20 (PROVISIONAL); keep MinPlayers and ArrivalWaitSeconds and measure them. For tier 1, plan the first leg short enough that its cruise lasts ≤ 25 s, with the coal objective inside it. Journey must plan the shorter leg deterministically from the run seed; do not speed up the scenery. Later legs are unchanged.

Route length. `Tuning.Run.Routes = { Short = 5, Long = 10 }`, replicated as `run.stopCount`. **Difficulty:** Short Line stop k reads the Long Line index `m(k) = {1, 2, 4, 6, 8}` for every stop-indexed difficulty input (`forStop(m(k), Routes.Long, …)`, Threat, Hollow caps, leaks). The stop clock's PerStop and the tutorial stop rules use the real k. [CALC, Base 0.08 + 0.80·t^1.4, tier offset 0] Short D = 0.080, 0.117, 0.252, 0.431, 0.643; Long D at stops 1–10 runs from 0.080 to 0.880. Stops 1–2 are identical on both routes (tutorial intact), and the Short Line still climbs to a late-run climax, below the Long Line's peak, which stays the status challenge. The Terminus keeps `d = 0` on both routes, as today (RunDirector). **Sky:** keep `Journey.hour(progress, stops)` with stops = 5. The existing Share/End keys then resolve to 18.3 (Depot), 18.9 (stop 1), 19.6 (stop 2), 22:00 at progress 2.4, 26:00 at 3.9, 28.9 at the last stop and sunrise 30.5 at the Terminus. That is the full dusk-to-dawn arc, compressed; no new keys are needed. Verify that Logic/Omens and the timed-event schedule read `run.stopCount`, not `Tuning.Run.StationCount`. **Rewards:** per-stop Brass, XP and haul are unchanged, so a Short Line pays for the stops it covers. The Terminus finale (strongbox, ledger, ticket, sunrise) is identical, with the ticket stamped SHORT LINE. A Short Line victory counts toward `victories` (lantern_aurora, hat_topper). `longVictories` counts Long Line victories only and gates livery_royal and the Roll of the Terminus. The report prints both routes' durations and Brass per run under the same scenarios as B.4.

Route policy. A player is **new** until they have 2 runs that reached RunEnd (any outcome). If any present member is new, the route length is fixed: Short, or E1's crew arm while E1 runs. The route vote then offers no length choice, and the crew sees "Short Line: a new Hand rides with you." If no present member is new, the route vote offers Short or Long. This replaces both "first two runs default to Short" and "vote after any completed run".

Daily bonus. Keep the existing daily first-run bonus unchanged. Do not add a daily line or another tracker (A.4 reward budget).

Invites and co-play. An INVITE button on the Depot board and the RunCard calls `SocialService:PromptGameInvite` after `CanSendGameInviteAsync`; hide the button when that check fails. A friend who joins lands in the Lobby, or aboard through the existing join-in-progress. Log `invite_prompted`. HUMAN: enable private servers at a low price in Creator Hub and record the price.

Experiments. Pure `Logic/Experiments`: at run start, if any present member is eligible, `arm = hash(runSeed, experimentId) % 2` for the whole crew. Each eligible player's exposed arm is stored permanently and logged once (`cohort_assigned`, Field 2 = the arm actually run). Run E1 and E2 as specified in A.4 (crew-randomized, cluster-analyzed). A Studio Dev command can force an arm.

Plain UI. First-session prompts and buttons use plain verbs. Diegetic names stay in flavour copy.

**Dependencies.** Prompt 0 (events and report), Prompt 4 (clock), Prompt 5 (tier-1 sighting, AGAIN).

**Preserve.** Car parties, solo Ready, join-in-progress, the route vote, Journey determinism (a rebuilt chunk comes out the same), tutorial tiers and the Long Line as the full experience.

**Edge cases.** Invites unavailable because of privacy settings: hide the button. A Short Line crew joined mid-run by a veteran stays Short. A first-timer who joins a Long Line in progress keeps it. A player's stored exposed arm never changes; later runs follow the route policy.

**Acceptance.** `lune run check` passes with specs for experiment determinism, the Short Line D mapping and both route durations. In Studio, from a fresh profile (Dev reset), measure the four first-session timings on desktop and in the device simulator's phone preset, then report them against the A.4 targets. Console clean; capture the START board, the stop-1 sighting and the RunCard invite. Real-device timings and private-server setup stay HUMAN and pending.

**Handoff.** HANDOFF with the measured timings, both route durations, the experiment definitions and rbxfacts regenerated.

## D. Completion and evidence

Report these three statuses separately. Implementation completion does not certify unperformed human checks or future behavioral results.

### D.1 Implemented and verified

- `lune run check` is green at the final commit; `lune run report` prints valid stop and route tables with scenario assumptions.
- Telemetry schema, once-only scope and funnels are implemented. Studio diagnostics verify timing/shape; published-server ingestion is independently confirmed or explicitly pending.
- Speed specs cover kinds, difficulty and pace extremes, both carrier speeds, no crate repulsion, no Brute lunge and the absolute tutorial override. Controlled Studio chases document geometry and stamina without universal outcome claims.
- Stalk demonstrates shadowing, root-facing freeze, minimum timing, maximum timeout while faced, the fixed 24–33-stud band independent of Visibility, guarded coil/16-stud approach boundary and per-target warning protection, target switching, solo rules and shared door concurrency. Exposures represent opportunity, not awareness.
- Bell uses original doors-open dwell percentages, changes the authoritative phase deadline and never extends time or jumps hazards. Grasp checks estimated press time for window eligibility and a single receipt snapshot for reach, credits boarding once at attachment, handles late input inside the cap and shows shortfall against the effective reach. Ten recorded controlled departures inspect success/miss geometry with starting stamina and grace use stated; the two-client latency checks validate the provisional tolerance.
- Pacing uses WalkReference only for timer sizing and actual speed for reach, including the payroll farWalk bound with solo 13.65-stud/s return and interaction time, plus one recorded Studio path check on the largest archetype. Recomputed route scenarios support the conditional targets; no no-bell ceiling is claimed.
- Reference shots, local readability checks, budget reports and period checklist are recorded. Palette rules and image averages are separate from local visibility.
- Intent-driven hush, arrival silence, crew-slot footsteps and ping are implemented with warning priority and visual equivalents.
- XP/Rank, non-Brass unlock paths and accounting remain; Brass buys ordinary cosmetics and the five status items use the fixed record mapping. Roll, posters, ticket copy, Mabel and LORE carry the final premise.
- AGAIN works after wipe and victory, across ResetReady and the 20 s fallback, including DEPOT and leaving.
- First-session timings are measured from a fresh profile against the A.4 targets; the Short Line keeps Long Line difficulty per stop; experiments assign deterministically and log once; invites work; the reward set is still Brass, Crew Rank and Line Mastery only. Gate G1 is reported with its pass/fail numbers before Milestone 2 starts.

### D.2 Human and release checks

- Real phone at 40% brightness in Performance, landscape and portrait: lobby, boarding, stop-1 loot, grab/skill check, bell, grasp, RunCard and Outfitter. No blocking overlap or unreadable edge/obstacle/Stalker remains.
- Owner approves the locked lighting/look references and completes headphones/phone-speaker audition.
- Required asset uploads, product IDs, publishing permissions and verification/evaluation are completed.
- Maturity questionnaire is answered accurately for the full experience; the actual label is recorded. Active thumbnails meet current personalization requirements.
- Budget gate (A.4, Budget and release): G1 result and the go/stop decision for Milestone 2 are recorded before Milestone 2 work starts.
- Every unavailable device, account or asset action stays marked pending with exact steps.

### D.3 Observations after release

Collect the stated cohort samples before quit-curve tuning. Report counts, uncertainty and matching denominators for first/returning, solo/crew and phone/desktop cohorts; include tablet/console separately when sufficient. Observe stalk comprehension through the usability probe and turning-to-face behavior, not through mandatory grab-funnel completion. Monitor tell exposure for every attacked player; 80% at ≥1.5 s is only an investigation trigger, not permission to violate the first-strike guard or proof of perception.

Track bell eligibility/use after run 2, doors-open histograms, completed and failed run durations, actual visit minutes, replay, quit-after-Taken/left-behind and other causes, stop progression, D1/D7 retention, thumbnail acquisition and reward pace. Quit comparisons are descriptive. The provisional 40% bell share, 38–44 min mixed-bell completed-run target, D1 15% and stop-3 70% are hypotheses to test, not claimed results or guarantees. No numerical commercial-success probability is established by this draft.

