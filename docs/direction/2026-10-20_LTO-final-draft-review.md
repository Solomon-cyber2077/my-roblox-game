# Last Train Out: Fable review of the final draft

Reviewer: Fable (Claude Code). Subject: *Last Train Out - Final Design and Implementation Draft.md* (2026-10-20).
Repository checked at `8983e54` on `claude/last-train-out`. Labels follow the draft: [OF] repository fact,
[CALC] arithmetic, [SF] official source, [DI] design inference.

## 1. Verdict

I accept the draft's structure, scope and nearly all of its numbers. I recomputed every figure in B.4 and they
hold. Four issues should change **before Prompt 1 or Prompt 2 starts**. Two of them correct mechanisms that I
proposed in the previous round, and I concede both. There are six smaller clarifications. No other changes.

## 2. Numbers verified (no change needed)

| Claim | Recomputed | Status |
|---|---|---|
| D0 chase 23.50–26.50 (Brute 23.03–25.97) | 25×{0.94,1.06}; ×0.98 | ✔ |
| D0 walk margin 2.03–5.50 | 23.03−21, 26.50−21 | ✔ |
| D1 chase 24.44–27.56; Brute 23.9512–27.0088 | 26×p; ×0.98 | ✔ |
| D1 sprint margin ≥3.44 (Brute 3.9912) | 31−27.56; 31−27.0088 | ✔ |
| D1 lunge Stalker 35.438–39.962, Crawler 39.104–44.096 | ×1.45, ×1.6 | ✔ |
| Full sprint 5.5556 s; gain 19.1111 studs | 100/18; 3.44×5.5556 | ✔ |
| Net gain with one lunge 12.2900 / 10.0163 | 19.111−1.892−4.929; −7.203 | ✔ |
| Carriers 17.85 / 13.65 | 21×0.85; 21×0.65 | ✔ |
| Departure closure D0 100.01 at 7 s, peak 110.49 at 5.556 s | 172.22+25.78−98; 172.22−61.73 | ✔ |
| Departure closure D1 80 at 5 s | 155−75 | ✔ |
| Stop clock B: 187 s mean doors-open, 47.57 / 33.85 / 40.09 / 41.21 min | Same model as `debate-response` table B | ✔ (my model; the review should re-run it after Prompt 4) |
| Scripted Crawler override replaces `ChaseScale 0.55` | `HollowService.speeds` applies ChaseScale only when `hollow.scripted` [OF] | ✔ normal tier-1 stops are unaffected |
| Service-record stat keys | `stationsDeparted`, `bestStation`, `rescues`, `clutchBoards`, `victories` all exist in `Config/Progression` [OF] | ✔ Prompt 8 can name them (`trail_steam` = `rescues ≥5`, `trail_brass` = `clutchBoards ≥5`) |

## 3. Changes required before implementation

### 3.1 The readability radius `r` is a player setting, so it must not drive server AI [OF, CALC]

`Tuning.Visibility`: `RadiusMin 18`, `RadiusMax 30`, `Default 30`. Each client writes the value to the player
attribute `Visibility` from a Settings slider. The draft sizes the stalk band, tells, breath and `tellSeconds`
from that per-player value. That causes three problems:

- **The band falls inside CommitRange.** At r = 18 the shadow band is [14.4, 19.8]. D1 CommitRange is 16, so a
  Stalker that takes the inner part of its own band commits to Hunt immediately. The prompt does not state this
  as a rule, and the spec would not catch it.
- **The setting changes difficulty.** An accessibility and brightness slider would change where Hollows stand,
  when they can commit and how much warning a player is credited with. A client-written attribute would steer
  server AI.
- **The telemetry has no fixed meaning.** `tellSeconds` "within 1.2r" would measure a different radius for each
  player, so cohorts cannot be compared.

**Fix (FIXED):** server AI and telemetry use one constant, `Tuning.Stalk.ReferenceRadius = 30`, which is
`Visibility.Default`, the value most players run. That gives a band of [24, 33], a tell/exposure radius of 36,
lantern lean within 30 and breath from 15 to 30. Facing (40 studs) and AwarenessRange (37.5) still contain the
band. Add a spec invariant: `0.8 × ReferenceRadius ≥ CommitRange(D1) + 4` (24 ≥ 20 ✔). Client-only
presentation tells may scale with the local slider, because that changes nothing on the server. Players who
lowered the slider on bright screens are covered by the existing phone check (B.7), which must include a Stalker
at 24–33 studs at slider 18.

### 3.2 The grasp's position rewind is wrong for this architecture (I concede; I proposed it) [OF, CALC]

- The train never moves (AGENTS, World motion); only the station slides. "Interpolate train/rail positions from
  history" therefore does nothing, because the rail anchor is static.
- Characters are client-owned (`CrewService.luau:205`, `SetNetworkOwner(player)`). The client's position and its
  Jump input reach the server over the same path at about the same time, so the server's replicated position at
  receipt is already close to the position at the press. Rewinding the player by the one-way latency counts the
  latency twice.
- How much it matters: the player's world speed on the departing platform is `v_run − a·t`. At D0, t = 1 s, that
  is 27 studs/s, so a 0.2 s double rewind misplaces the player by about 5.4 studs. Late in the window, while
  winded, it is about 2 studs. Against a 3-stud reach, the error decides the outcome.

**Fix (FIXED):**
- **Window test:** `t_press = receipt − clamp(L, 0, 0.2)` must lie inside the live window. Keep the existing
  0.2 s cap and the 0.2 s resolution buffer.
- **Reach test:** use the root position as replicated at receipt, against the static rail anchor in world space.
  Allow `GraspReach 3 + ReplicationTolerance 0.5` (PROVISIONAL) for Roblox's incoming physics interpolation.
  Do not rewind the player and do not search a sample interval.
- **Position history:** drop the 5-sample, 10 Hz buffer. It is not needed. `positionTick` keeps no history
  today [OF].
- **Telemetry:** `gapStuds` and `shortfallStuds` use the same receipt position.

### 3.3 First-strike guard: what the Hollow does while the guard is unmet is unspecified [DI, CALC]

Exposure accrues only in Stalk or coil, and coil (Intent) starts within LungeRange 16. A direct or immediate
Hunt that starts from distance therefore accrues nothing until it is within 16 studs. If the Hollow keeps its
chase speed during the 1.5 s coil, a D1 Crawler (27.56) closes about 9.8 studs on a walking player (21). The
guard then expires with the Hollow already in contact, and the tell becomes a delay rather than a read.

**Fix (FIXED):**
- While a target's guard is unmet, the Hollow may not enter Windup or lunge.
- Its approach is clamped so that distance does not fall below LungeRange (16). It matches the target's speed
  and holds the coil pose.
- Once exposure reaches 1.5 s, normal Hunt resumes.
- Add a spec for each case: an immediate commit from 30 studs, from inside CommitRange (if the target is already
  within 16, the Hollow holds position with the coil visible), and the scripted Crawler.

### 3.4 The haul return leg is missing from the reach checks [OF, DI]

The draft says StationReach uses the actual walk speed of 21. The strongbox comes home at 13.65 (solo) or 17.85
(duo), with no sprint. The dwell is the stop's only clock. Nothing in Prompt 1 or Prompt 4 checks that a solo
carrier can bring the strongbox from its spawn to the doors inside the legal dwell at D1 at the deepest stop.
I have not computed this, because spawn placement depends on layout seeds. That is exactly why it needs a spec.

**Fix (FIXED):**
- `tests/StationReach.spec` (or `Haul.spec`) asserts, for every archetype at D1 and stop 10:
  `walkOut(21) + carryBack(13.65) ≤ dwell − LastCallSeconds`.
- If it fails, move the spawn closer or raise the allowance, then re-run the route model.

## 4. Clarifications (small, no design change)

1. **The onboarding funnel API [SF, verify at implementation].** AnalyticsService has a one-time
   `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)`, separate from the recurring
   `LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, customFields)`. Route the main
   sequence (joined → first_board → first_off_train → survived_stop1 → reached_stop3) to the onboarding call and
   the replay funnel and subfunnels to the recurring one. `TelemetryService.Funnel` should hide that split.
2. **The bell's `u` denominator.** Define `u = (now − doorsOpenAt) / params.dwell`, where `params.dwell` is the
   original doors-open seconds and not the Dwell phase length (`dwell − 15`). The two definitions give different
   eligibility times. Prompt 0's report must use the same definition.
3. **Departure closure with stamina already spent.** The B.4 figures assume full stamina at t = 0. A player who
   sprints through the 3 s grace starts with about 46 stamina. Ignoring regen, closure is then **D0: about
   69.5 studs at window end, peak about 75.6 at 5.25 s; D1: about 50.5 at window end, peak about 60.2 at
   2.98 s** [CALC]. The 40–80 stud grasp setups in B.7 must state stamina at t = 0. An 80-stud D1 setup is only
   reachable from full stamina.
4. **Danger lamps and the shadow band.** The draft does not say whether the red edge lamps count as "lamp pools"
   that exclude shadow points. Decision: they do not. They are not SafeLights, and a Stalker in red danger light
   is the intended silhouette. Station platform lamps still exclude shadow points.
5. **Danger-lamp count.** "Every 4 tiles" on long sinkhole edges has no cap against the station budget (96
   lights, 64 lit). Add a per-stop cap. When the cap is reached, the extra lamps use emissive glass without a
   PointLight, the same rule as Performance.
6. **Door-forcing wording.** "stop ≥3, never tier-1 stops 1–2" is redundant. Write "stop ≥3 on every tier".

## 5. Positions I am not reopening

The speed ladder, stop clock B, bell branches (40% all / 60% half), grasp timings, carrier penalties, no crate
SafeLight, stop-1-only dormancy, the Brass retirement and the record table, the telemetry table and buckets, the
canon, the names, the audit budgets and the evidence gates all stand as written.

## 6. Requested from the other reviewer

Confirm or counter 3.1 to 3.4. If 3.1 to 3.4 are accepted, the draft is final with these edits:

- **Prompt 1:** add the 3.4 reach spec.
- **Prompt 2:** apply 3.1 and the 3.3 guard behaviour.
- **Prompt 4:** apply 3.2 and the §4.2 `u` definition.
- **Prompt 0:** apply §4.1.
- **Prompt 6:** apply §4.4–4.5.
- **B.7:** apply §4.3.

Prompt 0 can start immediately, because none of these issues block it.
