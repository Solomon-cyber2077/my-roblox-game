# Last Train Out: the professional layer

Design direction and implementation prompts. Written 2026-10-20 against `claude/last-train-out` at 6333312.
Source documents: `2026-10-20_LTO-analytical-audit.md` (Downloads) and the owner's raw response (pasted
in the assignment). The "v2 decisions and algorithms" document was not found on disk, in the Claude Bridge
vault or in the artifact list, so it was not used; where the raw response and the audit disagree, the raw
response is the owner's intent.

Evidence labels used throughout: **[OF]** observed fact (read in code, measured, or run this session);
**[OP]** owner preference; **[SF]** sourced finding (official or primary page opened); **[CALC]** arithmetic from
shipped modules; **[DI]** design inference; **[UH]** untested hypothesis; **[UV]** inherited claim, unverified.

---

## A. Professional conclusion

### A.1 What was investigated beyond the request, and with what

| Question a professional asks first | Method used | What it resolved |
|---|---|---|
| How long is a run, really? | Scratch Lune script over `Logic/DifficultyModel`, `Config/Stations`, `Logic/Threat` | A full ten-stop run is about **50 to 55 minutes**, not 15 to 25 [CALC] |
| Does the sprint/threat ladder still hold after the 2026-10-18 walk change? | `Config/Tuning`, `Config/Difficulty`, HANDOFF 10-18 | No: Hollows are now slower than a walking player everywhere except lunges [OF] |
| Is there a stalking behaviour to extend? | `HollowService.think` (lines 859-1076) | No. States are Dormant, Emerge, Prowl, Hunt, Windup, Recover, Repelled, Stunned, Grab. Sensing goes straight to Hunt [OF] |
| What makes the stations read "modern"? | `docs/stations/DESIGN.md`, `Config/Surfaces`, HANDOFF visibility parts 1-3 | Hazard rails with yellow-and-black posts, striped tape, a red glow strip, whitewash coping, limewash bands and cyan grades [OF] |
| Can the visibility paint approach ever pass its own gate? | HANDOFF visibility part 3 | 45 of 81 failing readings stay under 3:1 even if painted pure white; the chase dim, not paint, is the ceiling [OF] |
| Is there any telemetry? | `find_symbol AnalyticsService` | None [OF] |
| Does the quality gate pass today? | `lune run check` (this session) | Yes: format, lint, strict types, tests and visual audit all pass at 6333312 [OF]. `lune run report` crashes on a stale "neutral" archetype that has no length or depth [OF] |
| What do current Roblox rules say about audience, blood and chat? | Opened the Creator Hub content-maturity page, the April 2026 publishing-requirements announcement, the thumbnails page, and news on chat age checks | See A.3 [SF] |

Not possible this session: no Studio instance was running, so nothing was play-tested live, and no real phone
was available. Existing render sheets, the Oct 8 and Oct 13 Studio shots in `docs/compare` and `docs/checks`,
and the HANDOFF's recorded Studio observations stand in. Everything that needs a live device is marked.

### A.2 The strongest diagnosis

Last Train Out has an unusual amount of **system** for its size and almost no **orchestration**. The pieces
each work, but the clock, the threat, the light and the reward do not pull in the same direction. Four
findings carry most of the weight:

1. **The run is long and the stops have dead time.** A stop's doors stay open 185 to 240 s (mean 213 s at
   stop 1, 226 s at stop 10, tier 2, four crew) [CALC]. The fog starts taking ground at 36 to 94 s and never
   lets the crew leave early; a crew that has looted what it wants stands on the platform for a minute or
   more waiting for T-0. Ten stops plus junctions, cruises and arrivals come to about 53 minutes [CALC]. The
   owner's "early stations feel repetitive" is most simply explained by this: early stops are safe (tutorial
   tier 1 keeps every Hollow asleep for the first run) *and* slow. Nothing in either document measured this.
2. **The threat ladder is inverted.** Walk is 30 and sprint 31 studs/s [OF]. Hollow chase speed is 22.3 at
   stop 1 and 25.5 at stop 10 before the kind multiplier (Crawler x1.1, Brute x0.98) [OF, CALC]. Every Hollow
   on the hunt is slower than a *walking* player; only the 0.55 s lunge (x1.45) is faster. So stamina is a
   system that does not matter, sprint is a 3% bonus, and all real danger comes from lunges, grabs, fog and the
   clock. The audit's "monster at 29.1 to 32.4" was a guess from walk x0.97..1.08; the real numbers are
   lower, and the conclusion ("sprint doesn't work") is right for a different reason: walk was raised from
   20 to 30 on 2026-10-18 for the payroll crate and the Hollows were never re-laddered [OF, HANDOFF 10-18].
3. **The Hollows have no middle gear.** They are either unaware or charging. There is no stalking state, so
   the "intent" the owner wants to read is binary, deaths at early stops arrive without a build-up, and the
   signature creature (the tall Stalker) is seen mostly in the 0.3 s before it strikes. The procedural animation
   is clean but has no look-at, no lean into acceleration, and 0.3 s of anticipation that cannot be read at
   25 studs on a phone [OF, DI]. "Mechanical" is the right word for a body with no anticipation or attention.
4. **The station look fights its own era.** The modern read comes from three traceable sources: the safety
   furniture at the sinkhole edge (yellow-and-black posts, striped tape, a red glow strip: 20th-century
   industrial signage), the visibility pass's whitewash and limewash, and the cold cyan grades with heavy
   desaturation [OF]. The visibility harness has since shown that the paint approach cannot pass its own gate
   [OF], so the owner's objection and the measurement agree: readability has to come from light (lantern cone,
   moonlit rim, warm lamp pools) and from value steps in warm and cold materials, not from white.

What the previous reasoning got right: the hook, the co-op format, the warm/cold pendulum, "analytics first",
"sprint before monsters", the Victorian material set, the readability-from-value-steps rule, and the ranking of
story as a layer rather than the hook.

What it got wrong or left unsupported: the run length; the monster-speed arithmetic; the first-ten-minutes
timeline (stop 1 ends near minute 5, stop 2 near minute 10, not 4:30 and 6:00); the "no new player dies before
minute 6" absolute; completion math that never says whether it models a player or a crew (a run continues as
long as one crew member lives, flares bring people back, and joiners may enter until stop 6 [OF]); thresholds
("250 engaged players", "50,000 Robux") that the official page does not state [SF]; the Gemini thumbnail
"matrix" (no source; the only sourced fact is that thumbnail personalization raised qualified play-through by
8.5% on average across Roblox [SF]); colour-psychology claims resting on one small 2000 study [UV]; and
"cortisol" as a metric (unmeasurable; replace with quit-after-death and quit-after-left-behind rates).

The most consequential missing work, in order: telemetry; the speed ladder; the stalk state and body language;
player-driven stop length and the railing grab; the station material and edge rework with a lighting lock;
then the meta simplification and the narrative frame.

### A.3 Time-sensitive platform facts checked this session [SF]

- **Audience.** New games are trialled with age-checked 16+ users. Kids (under 9) and Select (9-15) access
  needs ID verification, two-factor auth, an active Roblox Plus subscription *or* a one-time refundable
  1,000 Robux fee per game, and a passed evaluation. The official page gives **no** numeric engaged-player
  threshold; secondary sources disagree (250 or 500 highly engaged players over 60 days). The owner's "the
  threshold drops to 100 CCU in November" is unverified [UV]. Action: read the evaluation progress in Creator
  Hub rather than planning around a number.
- **Blood and horror.** Maturity is set by realism, not quantity. Unrealistic blood (colour, shape or
  pixelation unlike real blood) stays Mild even when heavy; any realistic blood is at least Moderate; heavy
  realistic blood is 18+. Jump scares, creepy NPCs, heartbeat and screams are Mild. The game's bite effect is
  a dark-red smoke-textured puff with dark debris [OF], which is unrealistic in shape. So "reduce blood for a
  younger audience" is not the lever; keeping blood **unrealistic and infrequent** is.
- **Chat.** Facial age checks are required for chat worldwide since January 2026, with chat limited between
  age bands. Crews must be able to coordinate without text or voice.
- **Thumbnails.** Personalization runs when 2 to 5 thumbnails are active and allocates traffic to the winner
  per user segment; test, do not pick.
- **Analytics.** `AnalyticsService:LogFunnelStepEvent`, `LogCustomEvent`, `LogOnboardingFunnelStepEvent` and
  `LogProgressionEvent` are the current API (the `Fire*` methods are deprecated).

---

## B. Resolved design brief

### B.1 Experience thesis

**The fantasy.** You are one of a small crew sent down a dead line on the last train that still runs. The
train is the only warm, lit, moving thing left. Everything you want is out there in the cold and the dark, and
the train will not wait for you.

**The decisions that make it enjoyable.** How far from the light to go, and for what; when to turn back;
whether to run or walk (and what that costs); whether to face the thing watching you or keep working; whom to
go back for; when to ring the bell and leave; and, at the end, whether to jump for the railing.

**The emotional rhythm.** Warm and busy aboard (prepare, vote, patch) -> cold and quiet on the platform (look,
listen) -> a watched feeling that builds (stalk) -> a short violent problem (strike, grab, pry) -> a sprint
with a clock on it (the whistle, the chase, the grasp) -> relief and a tally aboard (stamps, the ledger) ->
the next ticket. Dread should be mostly anticipation; violence should be short and legible; relief should be
warm and social.

**What makes it recognizable.** One amber light in a cold dark with a tall silhouette at its edge; a pocket
watch and a paper ticket; a train you can hear leaving; a crew that pries each other free.

**Why another run is worth it.** Different route and stops; the stalk/commit rhythm produces different stories
each time; a service record that only reaching the Terminus can fill (status is the reward, which is the
premise); crewmates who want to go again, and one tap to do so.

### B.2 The experience, mapped

| Beat | Today [OF] | Where it is raw | Direction |
|---|---|---|---|
| First minute | Depot Hall, Ready, car countdown (40 s), boarding | Many systems visible at once; nothing yet says what the trip is for | Premise on the walls and the ticket; one objective aboard (coal) |
| First station (minute ~2-5) | Dormant Hollows, 25 s grace, 200 s doors, fog takes 55% of the ground; departure cues at T-30/T-10 | Safe then idle: nothing hunts, and the clock cannot be hurried | Shorter first stops; the bell to leave when all are aboard; one Hollow seen stalking at a distance, never charging |
| First failure | Grab -> skill check (zone 70 deg at stop 1) -> pry; left behind -> eliminated -> spectate | Grabs arrive without build-up; left behind feels sudden | Stalk before strike; the railing grasp turns "left behind" into a near miss you can read |
| First successful return | Run card ticket and stamps, 12 s RunEnd, Lobby, Ready again | Two phases of waiting; no "again" | AGAIN on the card; the premise's status board |
| First completed run (~50 min) | Terminus, strongbox opens, ledger, rank | Too long for the platform's sessions [DI]; brass and milestones overlap | 30-40 min target through player-driven stops; one unlock track (the service record) |
| Repeated play | Route vote, mystery ticket, tiers, cosmetics | Early stops repeat; threat is same-shaped each time | Stalk rules that change with stop and crew; occasional door-forcing and the rider event |

### B.3 Decisions

Each line names the owner's candidate, the evidence, and the decision.

**Moment-to-moment feel**
- Speed ladder [OP: "decide it algorithmically"]. Decision: derive from four relationships (B.4). Walk 21,
  sprint 31, chase 24 to 26 base, lunge x1.45 for 0.55 s. Stamina as today (about 5.5 s), winded as today.
- Haul crate penalties [OF: duo 25.5, solo 19.5 were set to out-walk Hollows]. The requirement "the duo holds
  distance against the slowest Hollow" cannot coexist with a pursuit model in which Hollows out-walk the crew.
  Decision: carriers walk at 0.85/0.7 of the new walk and cannot sprint; the **duo's** crate lamp becomes a
  SafeLight pool (radius 12) that Hollows will not enter, so the pair is safe because it is a pair and lit,
  not because it is fast. Solo carriers get no bubble. This replaces the 2026-10-18 speed requirement and
  needs the owner's awareness.
- Glance key [OP: "a peeking option on an unused key"]. Decision: hold **Q** (gamepad RB, touch: a small
  LOOK button above RUN) swings the camera to look over the shoulder behind you while you keep moving. In a
  chase game, seeing the pursuer without turning is the useful "peek".
- Camera, interaction and feedback: no change to the camera rig; add anticipation and follow-through to the
  Hollows (B.3 Enemies) and the grasp (B.3 Departure).

**Tension and pacing**
- Early departure bell [DI, new]. Once every living crew member is aboard and at least 40% of the dwell has
  passed, a bell rope in the saloon (E, ProximityPrompt) moves `departAt` to now + 30 s. The warning and
  escalation cues play as normal; anyone may still hop off for a last grab. Solo works the same. This turns a
  fixed 3.5-minute stop into a 1.5 to 3.5 minute stop chosen by the crew and removes the dead time without
  touching the hook. The "last train leaves without you" rule is unchanged: T-0 still departs.
- Dwell: `StopClock.Search` {105, 75} -> provisional {90, 70}. `TimedEvents` unchanged. Target full run 30 to
  40 min [UH, tune from the analytics median].
- Rides: not shortened. Cruise is 36 to 66 s plus a 20 s junction; it is already the short beat. The owner's
  "lantern oil during rides" is **rejected as a resource** (the lantern is the readability floor and must not
  go out) and **kept as an intent**: attentiveness on rides comes from leaks, boiler strain and, later, the
  rider event (deferred, B.6).
- Variation that changes decisions: stalk commit rules vary by stop and crew (alone, in the dark, back turned),
  door-forcing at some stops, the bell decision, the mystery ticket. Not more archetypes.

**Enemies and fairness**
- Stalk state [OP: "stalker-like", aggression grows, not speed]. Decision: add `Stalk` between Prowl and Hunt.
  A Hollow that senses crew shadows them from the dark at 18 to 30 studs, freezes when faced, and commits to
  the hunt when a condition is met: the target's back is turned for a while, the target is alone and outside
  lamp light, the stalk timer runs out, the target comes too close, or a Surge. Every one of those numbers
  tightens with the stop number. That is "aggression grows as the stations progress" made concrete, and it
  separates aggression from speed as asked.
- Buildings [OP: enter and cause commotion]. Decision: Hollows already rest in unlit rooms and flee lit ones
  [OF]. Add door-forcing at a seeded 40% of stops from stop 3: a Hollow at the door of an unlit room bangs
  (the `DoorForce` cue exists) for 3 s, then enters; a crew member holding the door (hold E) adds 4 s. Not
  every stop, as the owner asked.
- Tells [OP: indicator wheel glitch, lanterns blowing away from Hollows]. Decision: the pocket watch's second
  hand stutters and the carried lantern's flame leans away and gutters (never below the readability floor)
  when a Hollow in Stalk or Hunt is within 24 to 30 studs. Client-only, read from the replicated `State`.
- Animation [OP: "VERY lacking, too mechanical"]. Decision: look-at, lean, foot plants, a visible coil before
  the windup, follow-through on misses, blended transitions, a breathing freeze in Stalk. The Stalker gets a
  shredded coat and pallor within the cosmetic part budget.
- Train-attacking Tall One / a new rider Hollow [OP, "ignore if too much"]. Decision: deferred to a later
  phase as the **Rider** event (B.6). It is the right idea for ride-time attentiveness, but it depends on the
  stalk and animation work and is the least certain to pay back.
- "No new player dies before minute 6" [audit]. Rejected as an absolute. Replacement rule: on a first run, no
  elimination at stops 1 and 2 without a tell the player could have seen for at least 1.5 s (stalk, coil,
  windup). Learning needs real consequences with readable causes, not immunity.

**Train departure**
- Railing grasp [OP]. The chase already exists in data: the station accelerates at 4 to 6 studs/s^2 while the
  boarding volume stays live for 7 to 5 s [OF]. A sprinter can still close on the door until the platform
  outruns them at 31/a = 7.75 s (D0) to 5.2 s (D1) [CALC], so the windows are already derived from those
  relationships and no "5 seconds" constant is needed. What is missing is the interaction: today you board by
  being inside the train volume. Decision: during Departure, pressing Jump within 3 studs of a door railing
  starts a server-validated **grasp**: the character is attached to the train (so the sliding platform no
  longer matters), hangs for 0.6 s, is hauled in; a press out of reach plays a fall-short and the existing
  left-behind rule applies. No second skill check: the sprint-and-jump timing is the skill check; a mash on
  top would feel cinematic rather than earned. Touch uses the existing jump button; the server tolerates
  press latency as the skill check does (base 0.05 s plus half the ping, capped at 0.2 s).

**Art direction and readability**
- Period language: Victorian railway company (brick, stone dressings, slate, cast iron, bottle green, oxblood,
  aged brass, mahogany) at the frontier (board-and-batten timber, tin, canvas, rope, oil lamps). The company
  builds the station buildings; the village and yard are the frontier. That is the Victorian/Western merge
  the owner asked for, as a *material* rule rather than a mood word.
- Surface rule: no pure white and no pure black on station surfaces; bone and parchment only as trim. Remove
  whitewash coping (keep the blue-brick margin on wet grey-brown stone) and limewash bands. Replace the hazard
  rails, tape and red strip with period danger lamps (red oil lamps on posts), rope and stakes and broken
  ground; keep the `SinkholeEdge` tag for logic. Red stays "danger as light", which R4 allowed.
- Grades: keep the cold pendulum but take it off cyan; moon green-grey and blue-grey with less desaturation
  (0.18 -> 0.10 provisional) so brick and oxblood still read as materials.
- Density [OP: "as well designed as the train"]: a layering pass (foreground clutter on routes, mid-height
  canopies and gantries, a skyline landmark readable from the platform) within the audit's budgets; not more
  scattered props.
- Lighting lock [OP: "no settled state"]. The lobby's values have been retuned at least four times (tasks 001,
  011, 012; the `LOBBY` table in `Scenery/Sky` carries its previous values in a comment) [OF]. The problem is
  process: three places set light with no reference. Decision: one lighting recipe for the Depot Hall and the
  train interior (warm amber estate: many small sources, polished glints, soft falloff, deep shadow, no flat
  ambient), one table that owns the numbers, reference screenshots in the repo, and a shot check. "Brighter"
  is not "warmer": the audit's mood ceiling and the owner's ballroom warmth both hold if sources are bright and
  ambient is low.
- Interior doors [OP: low poly]: panelled doors with brass furniture and a glazed light, same pipeline as the
  train exterior meshes (needs the owner's upload) or primitives within budget.

**Animation and audio**
- Sound hierarchy with explicit priorities, sidechain ducks already in place [OF]. Add stalk sounds before
  sight, per-player footstep timbre (crewmates can be told apart without chat), a 0.8 s hush before a strike,
  and two seconds of near-silence after the brakes at every arrival. No score; the sound design is the score.
- Co-op ping [audit, owner agreed]: raise the lantern (V, gamepad Y, touch button) -> a glow pulse at the
  pinger, the watch compass flicks to them for 2 s, a soft whistle. Rate-limited.

**Cooperation and onboarding**
- "One mechanic per stop" [owner: "might work"]. Decision: adopt it for the **first run only**, stops 1 to 3:
  stop 1 loot, light, the clock and the bell; stop 2 the scripted Crawler ambush and the skill check (moved
  from tier 2); stop 3 the first awake stalker. Tier 2 and 3 prompts stay as they are. All systems remain
  live aboard; the voting and hull prompts stay on run 1 because the junction and the cruise happen anyway.
- Same-crew replay [OP]: AGAIN on the run card readies you in place; the run card stays readable; the
  countdown starts when everyone alive has pressed it or after 20 s with at least one ready.

**Progression and replayability**
- Brass [OP: "removal might be favorable"; audit: "enough, arguably too much"]. Decision: **retire Brass as a
  currency.** Every brass-priced cosmetic becomes a service-record unlock (stops cleared, Terminus reached,
  rescues, clutch boards, deepest stop). Robux cosmetics stay as they are. Rank/XP stays. The daily double is
  removed (it was the only compulsion-shaped mechanic). The profile keeps a read-only `brass` field for
  migration. This makes the reward system *be* the premise: status for reaching the Terminus.
- NPC errands [OP: lore and hints only]. Decision: Mabel's chain stays as the one errand line (it teaches
  "find and carry") but pays only its cosmetic and its story lines; the other residents stay reserved. Puzzle
  hints are deferred with the puzzles (B.6).
- Deepest-stop mark: `profile.stats.bestStation` already exists [OF]; show it on the ticket book and the
  Depot roll.

**Narrative**
- Premise (owner's number 7, preferred): the **Depot** is the last lit place. The Company sends its young
  down the dead line on the last train to strip the stations for coal, parts and valuables. Nobody believes in
  rebuilding; the trips delay the end. Those who return from the Terminus get their name on the roll, titles
  and liveries; those entered in the ledger as left behind are not recalled. The point of the premise is that
  status is enough of a reward even at the end of the world. This fits the existing haul strongbox, ledger,
  ticket book, stamps and the Line Mastery board almost exactly [OF], which is why it costs little.
- Conflicts resolved: LORE's "one night the line keeps running while everything goes wrong" becomes the
  Depot's standing order; LORE's rules on the Hollows (never explained, no twist) are kept; the audit's
  "who lights the lamps" mystery is dropped as *the* story and kept as a plain fact (the lamps are kept lit by
  those who went before: a plaque, no mechanic). No immortality explanation: the next ticket is simply issued.
  Mabel as a woman clerk stops being an anachronism inside a post-collapse Depot; LORE gets a note.
- Names [OP: placeholders to change]. Players are **Hands** (the Company's Hands); a run is a **Relief** (the
  relief train goes out); the lobby is **Coldharbour Depot** (from LORE's usable names). "Last Train Out" is
  kept as the game's name; the owner's "change the name" is read as the Depot's name, flagged as an assumption.

**Long-term sustainability**
- What stays enjoyable after familiarity: the stalk/commit rhythm (different every time), the bell decision,
  the grasp, crew stories, and the service record. What needs content: new stop archetypes, new Hollow
  behaviours (Rider), omens, and cosmetics. Cadence: a behaviour or event every two months costs far less than
  an archetype and changes decisions more. Keep acquisition (thumbnails, clips, a store listing led by
  "co-op survival"), onboarding (first run), retention (stalk, bell, AGAIN, service record), monetization
  (cosmetics only) and content cadence as separate questions with separate measures.
- Monetization: cosmetics and liveries only, bound after publishing; no timers, no sunk-cost tiers, no
  currency. The Robux catalogue entries stay as they are.

### B.4 Calculations that fix the numbers

**Speed ladder [CALC].** Let W walk, S sprint, C chase (base, before kind), L lunge.
Requirements: (a) a sprinter gains on a hunting Hollow by at least 3 studs/s, so 5 s of breath buys more than
the strike range plus hit range (6.5 + 8); (b) a Hollow gains on a walker by 2 to 4 studs/s, so a Hollow 16
studs behind catches a walker in 4 to 8 s (the pressure that makes sprint matter); (c) a lunge is faster than
a sprint for its 0.55 s so a sprinter who never breaks line of sight still gets clipped; (d) the readability
floor stays at 30 studs by default (about one second of sprint).
Result: S = 31 (unchanged), C = {24, 26} (Stalker 24-26, Crawler 26.4-28.6, Brute 23.5-25.5), W = 21
(S/W = 1.48), L = 1.45 C = 35-41. A full breath (5.5 s) buys 16 to 38 studs on a Stalker, 13 to 25 on a
Crawler at D1; running dry leaves 17.9 studs/s for 1.6 s, which a Hollow at 24+ closes at 6+ studs/s: the
commitment stays. Carriers: duo 0.85 W = 17.9, solo 0.7 W = 14.7; both slower than every Hollow, which is
why the duo gets the lit bubble instead.

**Departure [CALC].** Platform speed a t, a = 4 (D0) to 6 (D1). A sprinter closes at 31 - a t and stops
closing at t = 31/a = 7.75 s (D0), 5.2 s (D1). The chase windows {7, 5} s already sit just inside those
points, so they are kept. The largest gap a full-breath sprinter can close from the whistle: 31 t - a t^2 / 2
at the window's end = 119 studs (D0) and 80 studs (D1). The grasp reach (3 studs) and the latency tolerance
(0.05 s + ping/2, capped at 0.2 s) come from the skill check's own tolerance so that the two feel alike.

**Stop and run length [CALC].** Doors open: 185 to 240 s per stop today; junction 20 s; arrival 10 s; cruise
36 to 66 s; grace 3 s; chase 5 to 7 s. Per stop about 5.3 min; ten stops about 53 min. With `Search` at
{90, 70} and the bell used at about 60% of dwell on average, a stop is about 2.5 to 3 min and a run about 33
to 38 min [UH: the bell's usage rate is the unknown; the analytics median decides].

**Completion math, corrected [CALC].** Define per stop and per player: departed aboard, left behind, taken,
fell, rescued; per crew: cleared, wiped, derailed. A run continues while one crew member lives, so the crew's
Terminus rate is the product of crew-level clear rates, which is at least the player-level survival product.
Use the audit's table only as a sensitivity tool (small changes in per-stop clear rate move the Terminus rate
a lot); never as an estimate until the events exist.

### B.5 Preserved strengths (do not touch)

Server authority, the phase machine, the deterministic layouts and hazard schedules, the grab/skill-check/pry
loop and its audit, the train interior and exterior, the lobby shell work, the haul strongbox and payroll
accounting, the sky and omens, the mixing groups and ducks, the Settings and Visibility slider, the ticket
book and run card, the Studio dev console.

### B.6 Rejected or deferred

- Rejected: lantern oil as a resource; global slow-motion at the jump-on (multiplayer time cannot slow per
  player; a client-side camera kick is used instead); a second skill check on the grasp; "no death before
  minute 6"; white or cream as the readability tool; cortisol as a metric; building the plan around a
  "horror saturates after four quarters" tracker claim; pushing players toward a successor game (strategy,
  not design); the Gemini thumbnail matrix.
- Deferred: the **Rider** event (a Hollow on the roof or alongside during Cruise that costs up to 5 hull per
  bang unless a crew member drives it off with the lantern or a flash; two to four players only); lantern-
  message puzzles and a pass ticket for Dutch; Dutch, Varga, Pip and the Conductor; a station-wide "player
  categories" content strategy (it needs months of telemetry first); ads (after analytics and a phone pass;
  the audit's visit-to-CCU arithmetic stands as the planning tool).

### B.7 Remaining uncertainties and the smallest useful validations

| Question | Participants / device | Observe | Pass / fail | Decision that follows |
|---|---|---|---|---|
| Does the stalk read as intent? | 6 first-run testers, 3 on phones | Do they turn to face a stalking Hollow before its first strike? | 4 of 6 say they saw it coming | Keep commit timers; else lengthen stalk at stops 1-3 |
| Is the grasp fair? | 2 testers, 10 departures each from 40-80 studs | Boards, misses, "unfair" verdicts | 6+ boards of 10, 0 "unfair" | Keep reach 3 and windows; else reach 4 |
| Does the bell get used? | Analytics after P0 | Share of stops ended by the bell; median stop length | Bell on 40%+ of stops after run 2 | Keep Search {90,70}; else lower further |
| Phone readability | 1 phone at 40% brightness, Performance | Platform edge, obstacles and a stalker at 25 studs | All three readable in motion | Keep no-white rule; else raise floor to 31-33 |
| Run length | Analytics | Median full-run minutes; quit-by-stop curve | 30-40 min; no quit spike at one stop | Tune Search and bell share |

Event definitions (denominators first): `run_started` (per run id, crew size, device per player, tutorial
tier); `stop_resolved` (stop number, archetype, outcome, bell used, dwell used); `player_eliminated` (cause,
stop, seconds into stop, crewmates within 20 studs, held by which kind, had a stalk tell); `grasp`
(result, gap at whistle, seconds remaining); `run_ended` (outcome, minutes, stops); `again_pressed`;
`session_ended` (minutes, last phase). Cohorts: first run vs returning; solo vs crew; phone vs desktop.
No targets are set until two weeks of these exist; the audit's D1 15% and stop-3 70% remain hypotheses.

---

## C. Implementation prompts

Run in order. Each prompt is self-contained for an agent working from `claude/last-train-out` with the
project's rules (`AGENTS.md`, `CLAUDE.md`): read the current state before editing, edit on disk only, keep
`--!strict`, constants in `Config`, pure logic in `Logic` with a spec, `lune run check` green, a Studio
playtest with console read and screenshot where Studio is available (say so when it is not and list the
manual steps), HANDOFF updated, one commit per prompt, no push. Never declare success from script execution
alone. Every prompt must reconcile its "current state" lines against the repo before editing; this document
was written at 6333312 and later prompts build on earlier ones.

Conventions: **FIXED** = design requirement; **CHOICE** = the executing agent decides; **PROVISIONAL** =
a number to tune, with the method; **HUMAN** = needs an asset or a device the agent does not have.

### Prompt 0: Telemetry and the balance report

**Outcome.** Every later decision can be measured. Problem: no analytics exist [OF]; `lune run report`
crashes [OF], so nobody can print the difficulty tables.

**Current state.** No `AnalyticsService` use anywhere. `Logic/RunLog` already holds per-stop outcomes, close
calls and haul. `Logic/DeathCause` holds causes. `.lune/report.luau` builds a "neutral" archetype without
`length`/`depth` and `DifficultyModel.farWalk` divides nil. `Config/Settings` has no telemetry opt-out (none
is needed on Roblox; AnalyticsService data is first-party).

**Design (FIXED).**
1. New server module `Services/TelemetryService` (add to `ORDER` after DataService). It is the only place
   that calls `AnalyticsService`. Methods: `Funnel(player, funnel, sessionId, step, name, fields)`,
   `Event(player, name, value, fields)`. Wrap every call in `Util/Safe.call`; never yield in `Init`.
2. Events, with these exact names and fields (custom fields through `Enum.AnalyticsCustomFieldKeys`):
   `run_started` {crewSize, runTier, tutorialTier, device}; `stop_resolved` {stop, archetype, outcome,
   bellUsed, dwellUsedShare}; `player_eliminated` {cause, stop, secondsIntoStop, crewmatesNear, heldBy,
   sawTell}; `grasp` {result, gapStuds, secondsLeft}; `run_ended` {outcome, minutes, stops};
   `again_pressed` {secondsAfterCard}; `session_ended` {minutes, lastPhase}. `bellUsed`, `grasp` and
   `again_pressed` are emitted by later prompts; declare them now so names never drift.
3. Onboarding funnel through `LogOnboardingFunnelStepEvent`: joined, first_board, first_off_train,
   first_grab, survived_stop1, reached_stop3, first_run_ended, second_run_started.
4. Device: read `UserInputService` on the client once and send it through the existing `ClientReady` remote
   payload (extend `Remotes` validation), not a new remote.
5. Fix `.lune/report.luau`: iterate `Stations.Order` with the real archetypes (as the scratch calculation in
   B.4 did) and print dwell, Hollow count (`Logic/Threat.total`), chase speed and fog start per stop for crews
   of 1 and 4. Keep the D table.

**Preserve.** `RunLog`, `DeathCause`, the state tree. **Remove.** Nothing.

**Edge cases.** Players who leave mid-run emit `player_eliminated` with cause Disconnected (already a Cause).
Studio: AnalyticsService calls are no-ops in Studio; guard with `RunService:IsStudio()` logging to Output so
the events can be seen in a playtest.

**Acceptance.** `lune run check` green; `lune run report` prints without error; a Studio run shows each event
in Output at the right moment (join, board, step off, grab, stop end, run end); no new remotes.

**Provisional.** None. **Handoff.** HANDOFF entry with the event list; `rbxfacts` regenerated.

### Prompt 1: The speed ladder, stamina, carriers and the glance

**Outcome.** Running matters again. A walker is caught; a sprinter escapes while the breath lasts; running
dry is a commitment. Problem: Hollows are slower than a walking player [OF]; the 10-18 walk change inverted
the ladder [OF].

**Current state.** `Tuning.Crew`: WalkSpeed 30, SprintSpeed 31, StaminaDrainPerSecond 18, Regen 22, Delay
0.9, ExhaustedResume 0.35, Winded 1.6 s x0.85. `Difficulty.HollowChase` {22, 26}, `HollowWalk` {11, 14};
kinds in `Tuning.HollowKinds` (Crawler chase 1.1, Brute 0.98). `Tuning.Hollow.LungeBoost` 1.45,
`LungeSeconds` 0.55, `LungeCooldown` 3.5. `Config/Haul` DuoPenalty 0.15, SoloPenalty 0.35; carriers cannot
sprint (`MovementController` lines 46-50, 101). `tests/HollowSpeed.spec` asserts the old relationships;
`tests/Haul.spec` asserts the carry constants against walk. HollowService `isLit`/`safeLightAt` repel
Hollows from parts tagged `SafeLight` with attribute `Radius` (lines 220-239). The crate lamp is built in
`Builders/HaulBuilder` and moved by `HaulService` (lines 59-78, ~402).

**Design.**
- FIXED: WalkSpeed 21, SprintSpeed 31, `HollowChase` {24, 26}. Kinds unchanged. Lunge unchanged.
- FIXED: carriers at 0.85 and 0.70 of walk (keep the penalty constants, they already are shares), no sprint
  (unchanged). The duo's crate lamp is tagged `SafeLight` with `Radius` 12 **only while two carry it**; a
  solo carrier's lamp is never a SafeLight. Hollows therefore stalk the pair at the pool's edge and strike
  the solo carrier.
- FIXED: `tests/HollowSpeed.spec` is rewritten to assert the four relationships in B.4 (sprint margin >= 3 over
  every kind at D1 except the lunge; chase margin over walk 2..6 at D0 for every kind; lunge > sprint for
  every kind; carriers below every kind). The old "duo holds distance" assertion is removed and the reason
  recorded in the spec's header.
- FIXED: the tutorial's scripted Crawler keeps `ChaseScale` 0.55 but lunges from 10 studs when its target is
  within 12, so the teaching grab lands on a player who walks away (it must land to teach).
- FIXED: Glance: hold Q / gamepad RB / touch LOOK button (placed above RUN by the same `touchTop` logic the
  HUD uses) swings the camera 150 degrees behind over 0.18 s and back on release; movement continues; no
  effect in the lobby or while held by a Hollow. Sprint FOV kick unchanged.
- CHOICE: whether the glance is a `CameraController` mode or a `ContextActionService` bind in
  `MovementController`; where the LOOK button lives (recommend `UI/Hud` beside the existing RUN placement).
- PROVISIONAL: WalkSpeed 21 (20..23), HollowChase {24, 26} (D1 up to 27). Tune after the Prompt 2 stalk
  exists, from `player_eliminated.cause == Taken` with `sawTell` true at stops 1-3, and from how often
  sprint is used in a chase (log `sprint_used` as a custom event if needed).

**Dependencies.** Prompt 0 (events). **Order.** Speeds, specs, haul bubble, glance.

**Preserve.** Stamina drain/regen numbers; winded; haul accounting (`Logic/Payroll`). **Replace.** The
10-18 speed requirement, with the bubble. **Remove.** Nothing else.

**Edge cases.** Solo play: the bubble never applies. Touch: LOOK must not overlap the jump button on a phone in
landscape; verify with the device simulator. Crew change: a second carrier joining mid-carry turns the bubble
on at once; dropping it turns it off. Failure: a grabbed carrier drops the crate (existing).

**Acceptance.** `lune run check` green with the new spec; Studio: spawn a Stalker (`hollow Stalker`), walk away
and be caught within ~8 s; sprint away and escape; run dry and be caught; carry the crate as a duo with a
Hollow present and see it hold off at the pool's edge; glance works on keyboard and in the touch simulator;
console clean. Screenshot the glance and the duo bubble.

**Handoff.** HANDOFF with the final ladder table (walk, sprint, each kind at D0/D1, lunge, carriers).

### Prompt 2: Stalk, commit, door-forcing and tells

**Outcome.** The Hollows read as intent before violence; aggression grows with the stops, speed does not;
some stops have a Hollow forcing a door. Problem: sensing goes straight to Hunt [OF]; early deaths have no
build-up.

**Current state.** `HollowService.think` (859-1076) and `setState` (204-212) replicate `State` as a model
attribute; `HollowAnimator.onState` and `VisibilityController` read it (chase detection: Hunt/Windup/Grab/
Recover within 60 studs). Sensing: `Difficulty.Aggression` SightRange 118.75, AwarenessRange 37.5,
Persistence 5.2, StrikeCooldown 0.72. Wanderers and alerted Hollows ignore range. `Threat.total` gives 1-2
Hollows at stops 1-3 (crew 1-4) and 3-6 at stop 10. Lit buildings repel (`isLit`, `Repelled`); sleepers
start in buildings (`Difficulty.Sleepers`). `BuildingService` owns doors and `ExitPoint`. Audio has
`DoorForce`, `HollowStep`, `HollowWake`, `Breath`. The HUD's pocket watch is in `UI/Hud` (~537-602); the
carried lantern is `Controllers/VisibilityController` and `Visual/CosmeticMotion` (flicker).

**Design (FIXED).**
1. New state `Stalk`. Enter from Prowl when a crew member is sensed (visible within SightRange, or within
   AwarenessRange), the distance is above `CommitRange`, the Hollow is not a wanderer and not alerted, and
   the per-Hollow stalk budget is positive. Behaviour: hold a band of `StalkBand` {18, 30} studs from the
   target, move to points outside every SafeLight radius and outside the target's lantern reach + 4, with
   line of sight; when the target faces it (root look vector within 25 degrees, within 40 studs) it stops and
   sways (no step audio) until the target looks away; it may step between cover while unobserved.
2. Commit (Stalk -> Hunt) on the first of: target's back turned (not facing, within 40 studs) for
   `BackTurned` s; target alone (no crewmate within 14 studs) **and** outside every lamp pool and SafeLight;
   stalk timer `StalkSeconds` elapsed; target within `CommitRange`; a Surge event (`HollowService.Alert`);
   the target is seized by another Hollow. All five numbers are `{ D0, D1 }` pairs in `Config/Difficulty`
   under `Stalk`, read through `DifficultyModel` and keyed by the stop's D so that every stop tightens them:
   PROVISIONAL BackTurned {2.5, 1.0}, StalkSeconds {12, 5}, CommitRange {12, 16}, AloneRadius 14 (fixed),
   StalkBand {18, 30} (fixed). A Hollow that has committed does not stalk the same target again for
   `Persistence` + 10 s (prevents a loop of retreat and re-stalk).
3. Door-forcing: `Logic/HazardSchedule` or a new pure `Logic/Doors` picks, from the stop seed, whether this
   stop has door-forcing (PROVISIONAL 40% of stops from stop 3; never at a first-run stop 1-2). When on, a
   Hollow in Hunt whose target is inside an unlit room with a closed door goes to the door, plays `DoorForce`
   with the door shaking for `ForceSeconds` 3 (PROVISIONAL), then the door opens and it enters. A crew member
   holding the door (hold E on the door, server-validated proximity) adds 4 s once per door per Hollow. Lit
   rooms keep repelling as today.
4. Tells (client-only, from `State` and distance): the carried lantern's flame leans away from the nearest
   Hollow in Stalk/Hunt within 24 studs and its brightness flickers by up to 15%, never below the readability
   floor (`Logic/Visibility` floors stay authoritative); the pocket watch's second hand stutters (skips and
   catches up) while a Hollow in Stalk/Hunt is within 30 studs. Both stop within 1 s of the Hollow leaving
   range. A pure `Logic/Tells` module computes lean direction and stutter phase from positions and time, with
   a spec.
5. Sound before sight: in Stalk, `HollowStep` at half rate and a `Breath` cue positional at the Hollow with
   RollOff 12-24 studs; the drone's nearness already follows (`AudioController`).
6. Replication: `State` attribute values are extended with `Stalk`; `VisibilityController` treats Stalk as
   **not** a chase (no black flicker) so the stalk stays quiet.

**CHOICE.** How "faces it" is computed (root look vector is acceptable; do not add a camera remote). Whether
door-forcing lives in HollowService or BuildingService (recommend BuildingService owns the door timer and
HollowService asks it).

**Dependencies.** Prompt 1 (speeds). Prompt 3 reads the new state.

**Preserve.** Wanderer and alert behaviour, sleepers, grabs, post-grab protection, the tutorial tiers.
**Replace.** Direct Prowl -> Hunt for non-wanderers. **Remove.** Nothing.

**Edge cases.** Solo: "alone" is always true, so the alone condition at stop 1 requires "outside lamp light"
too (it does); first-run stop 1 keeps every Hollow dormant (unchanged). Touch: holding a door is a hold-E
ProximityPrompt (touch taps hold). Crew change: a target that disconnects ends the stalk. Failure recovery:
a stunned or staggered Hollow (post-grab) returns to Prowl, not Stalk, for 6 s.

**Acceptance.** `lune run check` green with specs for `Logic/Tells` and the stalk/commit rules (pure
functions over distances, facing and timers); the audit's `Grabs` target unchanged; Studio at stop 2 with a
spawned Stalker: it shadows at 18-30 studs, freezes when faced, commits when you turn your back ~2.5 s; the
lantern leans and the watch stutters; door-forcing seen once at a stop >= 3 with `station` forced to a
building-heavy archetype; console clean; screenshots of the freeze and the door. `/photo` shows all kinds
in Stalk.

**Handoff.** HANDOFF with the state diagram and the provisional table; `rbxfacts` regenerated.

### Prompt 3: Body language

**Outcome.** The Hollows move like bodies with attention, weight, anticipation and follow-through. The
Stalker looks the part. Problem: no look-at, no lean, 0.3 s windup unreadable at distance [OF, DI].

**Current state.** `Animation/HollowPoses` (pure CFrame math, gaits per kind, `pose` at 896-1030, cadence,
IK `reach`); `Controllers/HollowAnimator` (Motor6D transforms every Stepped, `onState`, bursts, trails);
`Tuning.HollowMotion` SpeedResponse 8, TwitchAngle 0.12; `Tuning.HollowContortion`; `Visual/HollowCosmetics`
(MaxParts 40, shedding); the Stalker rig is 60 visible parts (HANDOFF 10-15). The audit's `Grabs` target fails
poses whose hands or feet cannot reach. `Tuning.Hollow.WindupSeconds` 0.3 x kind windup.

**Design (FIXED).**
1. Look-at: in Stalk, Hunt and Windup the head and neck turn toward the target with a 0.25 s lag and a cap
   per kind (Stalker 70 degrees, Crawler 50, Brute 35); in Prowl the head scans slowly; in the Stalk freeze
   the head keeps tracking while the body is still.
2. Weight: the torso leans into acceleration (from the root's velocity derivative, clamped), out of
   deceleration; stride length scales with speed as well as cadence; foot plants are timed to `HollowStep`
   (the animator emits the step cue at plant, not on a timer).
3. Anticipation: during the last 0.4 s of approach before `StrikeRange` the body coils (shoulders back, head
   low) without changing `WindupSeconds`; the windup itself exaggerates the silhouette (arms wide for the
   Stalker, haunches for the Crawler, shovel raised for the Brute) so it reads at 25 studs on a phone.
4. Follow-through: a missed strike over-reaches and stumbles for `RecoverSeconds` (0.4) with a readable
   recovery pose (this is the counterplay window; do not shorten it).
5. Transitions: every state change blends over 0.2 to 0.35 s with ease-out; nothing snaps. Stalk freeze is
   sway plus breath at `BreathRate`, never a static pose.
6. The Stalker's look: a shredded coat (3 to 5 thin strips hinged at the hem, driven by velocity and wind
   from `CosmeticMotion`), pallor (skin toward `Colors.Bone`, darker eye sockets), within the existing part
   and cosmetic budgets (`MaxParts` 40 cosmetics; the audit's per-model budgets). Pallor and shredding grow
   with the run's progression value already used for contortion (30% at stop 1 to 100% at stop 10).

**CHOICE.** Implementation of look-at (two-bone neck or a head-only aim); how strips are modelled (parts or
a mesh from the Blender rig in `tools/` if one exists; no uploads without the owner).

**Dependencies.** Prompt 2 (Stalk state and step-at-plant). **Preserve.** IK reach rules, grab poses, the
crew's `CrewPoses`. **Remove.** Timer-based step audio once plant-timed steps exist.

**Edge cases.** Performance quality: look-at and lean run on every client for every Hollow; cap at 6 Hollows
with full secondary motion and simplify beyond 60 studs. Touch: nothing input-related.

**Acceptance.** `lune run check` green including the `Grabs` audit; `/photo` report lists every kind in
every state with IK shortfall 0; a Studio clip (or 4 screenshots at 0.5 scale) at a phone-sized viewport
shows the coil and windup readable at 25 studs; steps audible on plants; console clean.

**Handoff.** HANDOFF; note any HUMAN asset (mesh strips) left as primitives.

### Prompt 4: The bell, the dwell and the railing grasp

**Outcome.** Stops end when the crew is ready or when the clock says, never in dead time; the last-second
jump-on is a skill you can see, do and miss. Problem: fixed 185-240 s stops [CALC]; boarding is a volume test
with no interaction [OF].

**Current state.** `Logic/RunRules` phases and durations; `Tuning.Run` LastCallSeconds 15, `LastCallGrace`
3 s; `Difficulty.StopClock` Search {105, 75}, PerStop 4; `Difficulty.DepartureAccel` {4, 6}, `ChaseWindow`
{7, 5}; `RunDirector` Enter/Exit.Departure (429-478), `ExtendPhase`; `StationService.BeginDeparture` and
`step` (prismatic motor); `CrewService.positionTick` (boarding = `TrainService.IsInside`), `MarkLastCall`,
`ResolveDeparture`, `ClutchBoardSeconds` 2 and the Clutch Fx; `Logic/DepartureSchedule` milestones; `UI/
Hud` watch; `TrainBuilder` doors/railings (`RailingPilot` exists); `Animation/CrewPoses` (locomote, limp,
grabbed). `Upgrades.SteamWhistle` adds chase seconds.

**Design (FIXED).**
1. **Bell.** A bell rope ProximityPrompt in the crew saloon (CHOICE: position; near the route board). Enabled
   when every living, non-eliminated crew member is Aboard and the stop's elapsed share >= `BellMinShare` 0.4
   (PROVISIONAL). Pulling it (server-validated: proximity, phase Dwell, condition true) sets `departAt` to
   now + 30 s if that is sooner (so the T-30 warning fires at once and the T-10 escalation follows), publishes
   `run.station`, plays `WarnBell`, and emits `stop_resolved.bellUsed`. The bell cannot be un-rung. A player
   stepping off afterwards is subject to the normal rules. Solo: identical. Timed events already end 8 s
   before Last Call; a bell inside an event cancels the event cleanly (TimedEventDirector cleanup).
2. **Dwell.** `StopClock.Search` -> {90, 70} (PROVISIONAL; tune from the analytics median stop length with a
   30-40 min run target; the StationReach spec must still pass, since the walk term is untouched).
3. **Grasp.** During Departure (grace over, station moving), a Jump press by a player who is not Aboard and
   whose root is within `GraspReach` 3 studs (PROVISIONAL 3..4) of a door railing volume (train-local, from
   TrainBuilder's door positions) starts a grasp: the server welds/attaches the root to the railing anchor
   (the train is static, so the sliding platform no longer carries the player), sets attribute `Grasp` =
   "Hang", plays a hang pose for 0.6 s, then "Haul" for 0.5 s into the doorway, then releases the player
   Aboard (status flips through `positionTick` as today, so Clutch and `stationsDeparted` keep working). A
   Jump press out of reach, or a press while the station has moved the railing beyond reach, sets `Grasp` =
   "Miss": a 0.5 s fall-short pose, then the existing left-behind rule applies when the window closes. Press
   validation uses the skill check's tolerance (`SkillCheck.LatencyBase` + ping/2, capped at `LatencyMax`),
   judged against the server's own positions. The window numbers are unchanged (B.4 derives them).
4. Presentation: on a successful grasp the local camera gets a 0.35 s kick (no slow motion), `Clutch` plays,
   and the "MADE IT" notify stays as is. On a miss, the `Eliminated`/LeftBehind card shows the gap in studs
   ("3 studs short") so failure is understandable. New `CrewPoses` functions `hang`, `haul`, `fallShort`
   (pure).
5. Touch: the existing jump button is the grasp input; no new button. Gamepad: A.

**CHOICE.** Where the railing volumes come from (door anchors already used by `LeakArrows.CabDoorX/Z` and the
boarding prompts are a good source); whether the attach is a WeldConstraint or an AlignPosition.

**Dependencies.** Prompt 0 (events), Prompt 1 (speeds; the gap math assumes sprint 31).

**Preserve.** T-0 departure, grace, windows, Clutch, close calls, the run log stamps. **Replace.** Nothing.
**Remove.** Nothing.

**Edge cases.** A player held by a Hollow at T-0 is not Aboard, so the bell cannot be rung (correct: you
cannot leave them). Two players grasping the same railing: allow both (two anchors per door, left and right
post). A player who disconnects mid-hang is eliminated as Disconnected. Join-in-progress joiners spawn aboard
(unchanged). Village stop: no bell (the village has its own rule), grasp allowed.

**Acceptance.** `lune run check` green with specs for the bell condition and the grasp judgement (pure);
Studio solo: ring the bell at 50% dwell and see T-30 fire, depart at T-0, sprint from 60 studs, grasp, haul
in, Clutch; miss from 100 studs and read the gap on the card; `warp` to test both; console clean;
screenshots of hang and miss. Two-client check listed for the owner if only one client is available.

**Handoff.** HANDOFF with the bell and grasp numbers and the Studio steps.

### Prompt 5: First run and AGAIN

**Outcome.** A first run teaches one thing per stop for three stops and ends with one tap to go again.
Problem: tier 1 teaches five things at stop 1 and nothing hunts; the skill check waits for run 2 [OF]; after
a run the crew re-readies by hand after two waits [OF].

**Current state.** `Config/Tutorial` tiers (tier 1: stop1Cap 1, dormant, grace 25, no scripted grab; tier 2:
scripted Crawler, zone 100; tier 3: hull/leaks/stamina/vote prompts), prompts list, `ScriptedGrab`;
`Logic/Tutorial.crewTier` (least experienced); `TutorialService`, `TutorialController`; `Difficulty.Leaks`
EarlyCap 1 to stop 3; `RunDirector` Enter.RunEnd (12 s) -> Lobby -> `LobbyService.ResetReady`; `UI/RunCard`
(CLOSE, H toggles); `UI/Lobby` ready toggle and `SetReady`; runs happen in car servers of at most 4 (`Tuning.
Cars`), so after RunEnd the same players are in the same server's Lobby phase.

**Design (FIXED).**
1. Tier 1 becomes three stops of escalation: stop 1 dormant Hollows, grace 25, **no leaks on the first
   cruise** (Leaks.EarlyCap 0 for tier 1 until stop 2), prompts Move, Loot, Light, Edge, Bell; stop 2 the
   scripted Crawler ambush (moved from tier 2) with the SkillCheck prompt and the oversized zone; stop 3 one
   awake Stalker (stop1Cap-style cap of 1, no dormant) so the stalk is seen once before it matters. Tier 2
   keeps zone 100 and grace 15 without the scripted grab; tier 3 unchanged. The Hull/Vote prompts fire on run
   1's first cruise and junction (they happen anyway).
2. Readable-death rule for tier 1 at stops 1-2: a Hollow may not enter Windup on a player it has not stalked
   for at least 1.5 s (enforced in HollowService from the Prompt 2 stalk timers; wanderers and Surge are
   disabled at tier 1 stops 1-2, which `dormantStart` already does for stop 1).
3. AGAIN: the run card gets AGAIN and DEPOT buttons (gamepad A/B, touch). AGAIN sends `SetReady(true)`
   immediately (phase RunEnd or Lobby); the card stays up with a "crew ready: 2/3" line until the countdown
   starts; DEPOT closes the card. The countdown starts when every living crew member who is still present has
   pressed AGAIN, or 20 s after the first press with at least one ready (PROVISIONAL). RunEnd's 12 s stays so
   the stamps can be read. Emit `again_pressed`.
4. Deepest stop: show `stats.bestStation` on the ticket book cover and the Depot roll (Prompt 8 styles it).

**CHOICE.** How the card's ready line is drawn; whether tier 1 stop 3's single Stalker is spawned as a
wanderer-with-stalk or a sleeper.

**Dependencies.** Prompts 2 and 4. **Preserve.** `Tutorial.crewTier` (least experienced rules the crew).
**Replace.** Tier 2's scripted grab moves to tier 1 stop 2. **Remove.** Nothing.

**Edge cases.** Mixed crews: the crew rides at the lowest tier (unchanged), so a veteran with a new player
gets the gentle first stops; say so in a toast ("Riding at a new Hand's pace"). Solo: identical. A player
who leaves between runs: the ready count uses present players only. Touch: buttons large, bottom row.

**Acceptance.** `lune run check` green (Tutorial spec updated); Studio with `tutorialRuns` override at 0:
stop 1 no leak, no hunt; stop 2 the ambush lands and teaches; stop 3 one stalker; after a wipe, AGAIN starts
a new run without touching the lobby UI; console clean; screenshots of the card.

**Handoff.** HANDOFF.

### Prompt 6: Station material, edge, grade and density; the lighting lock

**Outcome.** Stations read Victorian-at-the-frontier, cold and lonely but legible, and no longer medical or
modern; the Depot Hall and the train interior have one settled warm-amber state with a reference. Problem:
hazard furniture, whitewash, limewash and cyan grades [OF]; lighting retuned repeatedly with no reference
[OF].

**Current state.** `Config/Surfaces`, `Logic/Luminance`, `Builders/Limewash` (station and train),
`Builders/StationDressing` (edge rails, tape, red strip; `SinkholeEdge` tag), `Config/Stations` palettes and
edges, `Tuning.Visibility.Grades/Rim/Beacon/Budget`, `Scenery/StationFog`, `tools/visibility` harness and
`docs/visibility/*`; `Scenery/Sky` `LOBBY` table (brightness 0, exposure -0.1, ambient 10/10/12), `Builders/
LobbyBuilder` PointLights (~438-482), `Builders/TrainInterior` lights and doors, tasks 001/011/012, `tools/
shot.ps1`, the audit's part/light budgets, LORE sections 5-8 and the period checklist.

**Design (FIXED).**
1. Surface rule in `Config/Surfaces`: station surface colours clamp to no channel above 232 and no channel
   below 18, with bone/parchment allowed on trim only; a spec enforces it over every station palette and
   dressing colour. Whitewash coping -> wet grey-brown stone (about 120,112,100) with the blue-brick margin
   kept; `Limewash.station` bands removed; `Limewash.train` lining kept only if it survives the rule (brass
   stays).
2. Edge: `StationDressing` replaces yellow-and-black posts, striped tape and the glow strip with: a red oil
   danger lamp on a timber post every 4 tiles (PointLight red, range 10, counted in the light budget), rope
   between stakes, broken ground and ember cracks (red emissive material in the ground, not a strip). The
   `SinkholeEdge` tag and `Edge.RailBack/TapeBack` logic are untouched.
3. Grades: `Tuning.Visibility.Grades` saturation 0.18 -> 0.10 (PROVISIONAL 0.08..0.14), tints shifted off
   cyan toward moon green-grey and blue-grey; Infirmary "carbolic cyan" becomes gaslit green-grey. The train
   and lobby stay warm (unchanged ramp).
4. Material language per archetype (LORE 7 gets the table): company buildings (booking hall, station house,
   hotel, infirmary, school) in brick, stone dressings, slate, cast iron, bottle green and oxblood joinery;
   yard and village in board-and-batten timber, tin, canvas, rope, oil lamps; lettering painted on boards in
   the LORE typography. Period checklist run before finishing.
5. Density pass: for each archetype, foreground (route-side clutter at 1-3 studs), midground (canopies,
   gantries, water towers at 8-20 studs) and background (one skyline landmark readable from the platform)
   are each present; budgets stay within the audit's limits; `AUDIT_SEEDS=6 lune run audit Stations`.
6. Lighting lock: new `Config/InteriorLight` owns every number for the Depot Hall and the train interior
   (ambient, exposure, per-fixture colour, brightness, range, bloom), consumed by `Sky` (LOBBY), `LobbyBuilder`
   and `TrainInterior`. Recipe (FIXED in character, PROVISIONAL in value): warm low ambient (about 26,20,14),
   exposure 0, pendants and wall lamps as the key at 2600 K amber (255,190,120) with brightness about 1.2 and
   range 20-24, brass and glass materials for glints, bloom threshold so only flames bloom, deep shadow
   between fixtures, no flat fill. Reference screenshots from the spawn, the ready position, the saloon and
   the workshop are saved under `docs/direction/reference/` with `tools/shot.ps1`, and a documented mean-
   luminance band per shot (measured from those references, not guessed) becomes the check for future
   changes. Task files 001/011/012 are marked superseded.
7. Interior doors: panelled, with brass furniture and a glazed light. CHOICE primitives within budget, or a
   Blender mesh through the train pipeline (HUMAN: owner upload).

**Dependencies.** None on gameplay prompts; can run in parallel with 1-5 on separate files (it touches
builders, surfaces, visibility tuning, Sky LOBBY, LobbyBuilder, TrainInterior; the gameplay prompts do not).

**Preserve.** Rim highlights, beacon, lantern cone, the Visibility slider and floors, the chase dim logic,
station layouts and loot. **Replace.** Whitewash, limewash, hazard furniture, cyan grades, scattered lighting
numbers. **Remove.** The white edge line (already gone) and the limewash builder's station path.

**Edge cases.** Performance quality: danger lamps count against `Budget`; use the Performance variant (no
light, emissive glass only). Readability: re-run the dim-screen harness as a regression record, but the gate
is **not** the acceptance test (it cannot pass the chase by paint; verify whether it renders Highlights at
all and say so in HANDOFF). HUMAN: a real phone at 40% brightness in Performance mode is the acceptance test
for readability; the agent lists the shots to take.

**Acceptance.** `lune run check` green with the surface spec; `lune run preview Halt out.json --hour=22
--grade=Halt` rendered with `--cam=station` and compared with the Oct 8 and Oct 13 shots; Studio screenshots
from the platform at stop 1 and inside the hall and saloon at 0.5 scale; part and light counts reported; the
LORE period checklist run. The owner judges the look; the agent reports what changed and the counts.

**Handoff.** HANDOFF; LORE updated (materials table, danger lamps, Mabel note); reference shots committed.

### Prompt 7: Sound hierarchy, stalk audio, footsteps and the ping

**Outcome.** The mix tells you what matters, where it is, and who is near you, without chat; silence is
used on purpose. Problem: 60 cues with ducks but no stated hierarchy; nothing before sight; identical
footsteps [OF].

**Current state.** `Config/Audio` (cue table), `Controllers/AudioController` (groups LastTrainOut >
Ambience > Outdoor, Cues, Steps; Warnings beside; three sidechain compressors), `Controllers/
FootstepController` and `Logic/Footsteps` (takes per surface), `ThresholdController` (walls EQ), the drone,
`Tuning.Departure.Duck*`, omens (`Hush`), `Remotes`, `NetService` rate limits. Nothing has been auditioned by
ear in several passes (HANDOFF).

**Design (FIXED).**
1. A priority table in `Config/Audio` (data, read by AudioController for duck depth and polyphony):
   1 departure warnings and the clock; 2 threat (windup swipe, slam, scream, DoorForce, stalk breath, wake);
   3 player feedback (footsteps, hit, winded, loot, deposit, UI); 4 ambience (drone, wind, rain, train run,
   station eerie); 5 lobby piano. Higher duck lower; the existing compressors are rewired to this table.
2. Silence: 0.8 s duck of ambience and steps before every Windup (from the `State` change) so the swipe
   lands; 2 s of near-silence (ambience -12 dB, no drone) after the brakes at every arrival; the Hush omen
   unchanged.
3. Stalk audio: breath and half-rate steps (from Prompt 2) at RollOff 12-24; an occasional board creak or
   pebble when a stalker steps between cover while unobserved.
4. Per-player footsteps: four boot timbres (hobnail, soft leather, clog, heel) chosen by user id, pitch
   offsets within `PitchJitter`; crewmates' steps audible to 40 studs; your own low-passed.
5. Ping: new remote `Ping` (ToServer, no payload, rate-limited 1 per 3 s in NetService), V / gamepad Y /
   touch button beside RUN: a 1.5 s glow pulse at the pinger (client Fx from a `Fx` "Ping" event), the watch
   compass flicks to them for 2 s, a soft whistle cue. Never in the lobby.
6. HUMAN audition gate: a checklist for the owner (headphones and a phone speaker): departure warnings over
   the drone, windup silence, stalk breath direction, footstep identity, ping. Cue ids may be swapped from
   the Creator Store list in HANDOFF 10-17.

**Dependencies.** Prompt 2 (Stalk state, plant-timed steps from Prompt 3). **Preserve.** Groups, ducks,
Settings' Ambience row, every existing id. **Remove.** Nothing.

**Edge cases.** Touch: the ping button must not crowd RUN/LOOK/jump; use the HUD's touch-top logic. Solo:
ping does nothing but the whistle (fine).

**Acceptance.** `lune run check` green (Footsteps spec extended for timbre choice); Studio: AudioAnalyzer or
Output confirms the duck before a windup and the arrival hush; four boot timbres heard across four test
characters (dev `give`/`npcreset` not needed; use the Studio multi-client simulator if available); ping seen
and heard; console clean.

**Handoff.** HANDOFF with the priority table and the audition checklist.

### Prompt 8: Retire Brass, the service record, errands as story, the Depot premise

**Outcome.** One reward track that is the premise: reach the Terminus, earn status. The world says what the
trips are for. Problem: brass, milestones, errands and haul overlap [OF]; the lore has no stated purpose for
the runs [OF].

**Current state.** `Logic/Economy` (brass payout, daily double, solo charter), `Tuning.Economy`, `Config/
Progression` (milestones with brass or cosmetic rewards, stats), `Config/Cosmetics` (unlock paths default/
milestone/brass/robux/gamePass/charter/npc), `Logic/Catalog`, `Services/ShopService`, `UI/Outfitter`
(BUY), `Services/ProgressionService.PayRun`, `Types.Profile.brass`, `Config/NpcQuests` (brass per errand),
`Config/NpcDialogue/Mabel`, `UI/Summary`, HUD "+BRASS BANKED" for relics, `Builders/PosterArt`, the lobby's
Line Mastery board and departure board, `UI/RunCard` stamps, LORE sections 1-4, `Logic/RunTicketModel`.

**Design (FIXED).**
1. Brass is no longer earned, shown or spent. `Economy.payout` returns XP only (base + XpPerRun unchanged);
   the daily double and solo-charter brass lines are removed; `profile.brass` stays in the type as a read-only
   legacy field (no migration needed; the game is unpublished). Relic brass becomes haul XP through the
   existing `ProgressionService` path.
2. Service record: every brass-priced cosmetic gets a stat requirement instead (`Config/Cosmetics` field
   `record = { stat, goal }`), checked by `Logic/Catalog` like milestones. Provisional mapping: Fine items
   at 10-25 stops cleared or 5 rescues; Rare at 1-3 Terminus arrivals or deepest stop 8; Legendary at 5
   Terminus arrivals. Robux and gamePass items unchanged (ids still nil). Charter stamps unchanged. The
   Outfitter shows the requirement and progress instead of a price; BUY is removed for record items.
3. Errands: `NpcQuests.brass` removed; Mabel's chain pays its cosmetic at the end and a story line per stage;
   the quest tracker copy stays.
4. Premise in the world (copy only, no new systems): lobby posters and notices (PosterArt): "THE DEPOT
   STANDS WHILE THE LINE RUNS", "RELIEF DEPARTS AT DUSK. HANDS REPORT TO THE CLERK", a Roll of the Terminus
   (the Line Mastery board becomes the Roll: names and liveries of those who reached it, per profile stats);
   the departure board names the Relief; the run card's left-behind stamp reads "ENTERED, NOT RECALLED";
   Mabel's lines rewritten to the premise (issuing the Relief's tickets, counting who comes back); a lamp-post
   plaque at every station "KEPT LIT BY THOSE WHO WENT BEFORE" (one static part). The Hollows remain
   unexplained (LORE 3 unchanged). No immortality text anywhere.
5. Names: in UI and copy, players are Hands, a run is a Relief, the lobby is Coldharbour Depot (`Config`
   strings, not identifiers; code names stay). The game's title is unchanged (assumption; flag to the owner).
6. LORE.md gets a new section 0 "Premise" with the canon above, and the Mabel note.

**CHOICE.** Exact record goals per item; poster layouts.

**Dependencies.** Prompt 0 (stats already exist; `bestStation` shown in Prompt 5). Can run in parallel with
6 and 7 on separate files.

**Preserve.** Rank/XP, milestones that grant cosmetics, charter stamps, haul and payroll, the mystery ticket.
**Replace.** Brass with the record. **Remove.** Daily double, brass lines, BUY for brass items.

**Edge cases.** A profile with brass > 0 (none real): ignored. Specs: `Economy.spec`, `Catalog.spec`,
`Ledger`/`Summary` specs updated; the Summary's lines must not show empty brass rows. Touch: Outfitter rows
with requirement text must still fit the phone layout (check at half scale).

**Acceptance.** `lune run check` green; Studio: finish a run and see XP only; the Outfitter shows requirements;
a milestone cosmetic unlocks; the Roll and posters read at the spawn and ready positions; console clean;
screenshots.

**Handoff.** HANDOFF; LORE updated; `rbxfacts` regenerated.

### Prompt 9: Release plumbing (checklist; mostly human)

**Outcome.** The game is publishable to the right audience with honest labels, tested on a phone, with
thumbnails that can be tested and analytics already counting. Problem: no phone test, no questionnaire, no
listing plan [OF, HANDOFF].

**Current state.** Blood: bite puffs are smoke-textured dark red with dark debris (`HollowAnimator.burst`),
the Hit effect is a red screen pulse, the Stalker has "bloody hands" colouring; no realistic injuries [OF].
Settings has `Hud` Show/Hide (a creator mode already) [OF]. Touch: HUD lays out around the touch controls and
the car prompt taps; last device test several sessions ago (HANDOFF). Robux ids nil.

**Design (FIXED).**
1. Blood audit: keep every blood effect unrealistic in colour and shape (the current puffs qualify); reduce
   the bite puff count by a third (owner asked for "a bit less"); no realistic wounds or pooling anywhere; a
   spec or audit check that no emitter uses a realistic blood texture is CHOICE. Expected label: Mild (jump
   scares, creepy NPCs, heavy unrealistic blood at most). Answer the content-maturity questionnaire
   honestly; HUMAN.
2. Creator mode: `Hud` Hide also hides name tags and the ping glow for the local player; document the
   setting as "Creator mode" in Settings copy.
3. Phone pass (HUMAN, with the agent's checklist): a real phone in landscape and portrait, Performance
   quality, 40% brightness: lobby, boarding, stop 1 loot, a grab and skill check, the bell, the grasp, the
   run card, the Outfitter; note every overlap or unreadable element; fix in a follow-up.
4. Store listing: "co-op survival" first; thumbnails: 2 to 5 active for personalization, one of them the
   amber lantern in the dark with the tall silhouette at the edge of the light (the owner's composition);
   HUMAN art.
5. Audience: complete the publishing requirements (ID, 2FA, Plus or the 1,000 Robux refundable fee,
   evaluation) when ready; read the evaluation progress in Creator Hub rather than planning around a
   player-count rumour.
6. Chat: nothing to build; the ping and footstep identity are the comms.
7. Ads: not before two weeks of analytics and a passed phone pass; then plan from the audit's visit-to-CCU
   arithmetic with real minutes per visit.

**Acceptance.** A HANDOFF entry listing what was done by the agent (blood count, creator mode) and what is
left to the owner with the exact steps.

---

## D. Completion standard

The professional layer is implemented when all of the following hold, with evidence in HANDOFF and the
analytics dashboard:

1. `lune run check` is green at the final commit, and `lune run report` prints the stop tables.
2. Telemetry: every event in Prompt 0 appears in the Roblox analytics funnel and custom events with the
   defined fields, from at least one real server session.
3. Ladder: the rewritten `HollowSpeed.spec` passes, and a Studio clip shows a walker caught, a sprinter
   escaping, and a dry sprinter caught, at stop 1 and stop 8.
4. Stalk: a Studio clip shows a Stalker shadowing, freezing when faced, and committing on a turned back; the
   lantern leans; the watch stutters; `player_eliminated.sawTell` is true for at least 80% of Taken
   eliminations at stops 1-3 in the first two weeks (provisional; a lower number means the tells are
   not being seen and the stalk needs to be longer or louder).
5. Departure: ten recorded departures show grasps succeeding inside 80-119 studs and misses with a readable
   gap; no boarding happens outside the window.
6. Pacing: the analytics median stop is 2.5 to 3.5 minutes and the median full run 30 to 40 minutes; the bell
   is used on a meaningful share of stops after a player's second run.
7. Look: reference screenshots for the hall and the saloon are committed with their luminance bands; no
   station surface breaks the surface rule (spec); the hazard furniture is gone; the owner signs off on a
   phone at 40% brightness.
8. Sound: the owner's audition checklist is signed; the windup hush and the arrival silence are measurable
   in Studio.
9. Meta and story: XP is the only earned number; every cosmetic has one unlock path; the Roll, posters,
   tickets and Mabel carry the premise; LORE has the premise section and the materials table.
10. Release: the maturity questionnaire is answered Mild or the reason it is not is written down; the phone
    pass has no open blocking item; thumbnails are in personalization.

What still needs observation after release, because analysis cannot settle it: whether first-run players
turn to face a stalker (funnel step first_grab with sawTell); whether crews ring the bell or wait (bell share
by run count); the quit-after-left-behind rate versus the quit-after-taken rate (which tells whether the
grasp made being left behind feel fair); session length on phones versus desktop; D1 and D7 by first-run
outcome; which thumbnail wins per segment. None of these have baselines yet, so none have targets yet.
