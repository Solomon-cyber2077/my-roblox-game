# Session prompts for docs/FINAL-DESIGN.md

There is one session per block. Run them **in order** in a fresh session each time. Paste the shared preamble, then the
block. The design file is the source of truth; these prompts only scope each session.

**Merges.** Only two were safe:
- **S8:** the Milestone 1 essentials from Prompts 6 and 7 (one small readability and audio pass).
- **S10:** the rest of Prompt 7 together with Prompt 9 (Prompt 9's creator mode hides Prompt 7's ping glow).

The other prompts are either too large to share a session or share files with the prompt next to them (Hud,
RunDirector, HollowService, Tutorial, RunCard), so they stay separate and sequential.

| Session | Prompt(s) | Milestone | Model / effort | Depends on |
|---|---|---|---|---|
| S1 | 0 Telemetry, sink, balance report | 1 | Opus 5.5 / high | none |
| S2 | 1 Speed ladder, carriers, glance | 1 | Opus 5.5 / medium | S1 |
| S3 | 2 Stalk, guard, door-forcing, tells | 1 | Opus 5.5 / high | S2 |
| S4 | 3 Body language | 1 | Opus 5.5 / high | S3 |
| S5 | 4 Bell, dwell, grasp | 1 | Opus 5.5 / high | S1, S2 |
| S6 | 5 First run and AGAIN | 1 | Opus 5.5 / high | S3, S5 |
| S7 | 10 First three minutes, routes, invites, experiments | 1 | Opus 5.5 / high | S1, S5, S6 |
| S8 | Essentials from 6 and 7 | 1 | Opus 5.5 / medium | S4 |
| G1 | Closed playtest (`2026-10-21_after-the-prompts.md`, Stage 1) | none | human | S1–S8 |
| S9 | 6, the rest (materials, edge, grades, density, lighting lock) | 2 | Opus 5.5 / high | G1 |
| S10 | 7, the rest, plus 9 (footsteps, ping, arrival silence, release plumbing) | 2 | Opus 5.5 / medium | G1, S8 |
| S11 | 8 Brass loop, Line Mastery, premise | 2 | Opus 5.5 / high | G1, S7 |

---

## Shared preamble (paste first in every session)

```
Read AGENTS.md, CLAUDE.md and HANDOFF.md, then the docs/FINAL-DESIGN.md sections named below. The design file is the
source of truth; implement only the scope named here and stop when it is done.
- First reconcile the prompt's "Audited baseline" against the current code (rbxmap find_script first, then read_lines
  on the returned range). Report any drift before editing.
- Edit files on disk only (Rojo syncs). Keep --!strict; constants in Config, pure rules in Logic with specs in tests/.
- FIXED values are not yours to change. CHOICE items are yours. PROVISIONAL values change only together with their
  calculations and checks. HUMAN items stay explicitly pending.
- Run `lune run check` until it is green. In Studio use start_stop_play, get_console_output and screen_capture (0.5
  scale) for each acceptance item; if Studio is unavailable, say so and list exact manual steps.
- Update HANDOFF.md (features completed, known bugs/regressions, next step), regenerate rbxfacts if the prompt says
  so, commit once with a clear message, do not push. Report the results honestly, including what is still pending.
```

---

## S1: Prompt 0, telemetry and the balance report
```
Sections: A.3 (Analytics), A.4 (events, sink, G1 prerequisites), B.4, Prompt 0.
Scope:
- TelemetryService (ORDER after DataService), the only caller of AnalyticsService.
- Onboarding funnel through LogOnboardingFunnelStepEvent, other funnels through LogFunnelStepEvent, Brass through
  LogEconomyEvent.
- Every event in the Prompt 0 table plus first_session_timing, cohort_assigned and invite_prompted, with frozen
  Config vocabularies and a spec keeping each event under 8,000 field combinations.
- The device field in the existing ClientReady payload (no new remote).
- The durable DataStore sink and its read-back.
- Repair .lune/report.luau: actual archetypes, clock B, bell scenarios (u over original params.dwell), the
  timer-vs-reach speed split, routes through the Terminus, and placeholders for Short and Long Line.
Acceptance: check green; `lune run report` prints valid tables; Studio Output shows deduplicated events for join,
boarding and leaving the train; the sink read-back works. Published ingestion stays pending.
```

## S2: Prompt 1, the speed ladder, stamina, carriers and the glance
```
Sections: B.3 (Moment-to-moment), B.4 (speed ladder, stamina, tutorial exception), Prompt 1.
Scope:
- Walk 21, sprint 31, HollowChase {25,26}, pace ±6%.
- Kinds: Stalker chase x1.0 / lunge x1.45, Crawler chase x1.0 / lunge x1.6, Brute chase x0.98 / no lunge.
- Carriers stay at 17.85 / 13.65 with no crate SafeLight.
- Rewrite HollowSpeed.spec and Haul.spec as the prompt states, including the tutorial override as its own case.
- The glance on Q / RB / touch LOOK.
Acceptance: as in Prompt 1. Document starting gaps, line of sight and stamina for the controlled Studio chases; make
no universal catch or escape claims.
```

## S3: Prompt 2, stalk, the first-strike guard, door-forcing and tells
```
Sections: B.3 (Enemies and fairness), Prompt 2.
Scope:
- The Stalk state with server-owned Tuning.Stalk.ReferenceRadius = 30 (band 24–33, exposure 36) and the invariant
  spec 0.8 x ReferenceRadius >= max CommitRange + 4.
- The commit table, precedence, budget and targeting.
- The first-strike guard: 1.5 s exposure, no Windup/lunge/strike while it is unmet, the approach clamp at 16 studs
  and the replicated warning-coil flag.
- Door-forcing owned by BuildingService (one shared timer, one hold extension).
- Logic/Tells with specs, and stalk breath with half-rate steps.
Acceptance: Prompt 2 list, including identical server decisions at Visibility 18 and 30. /photo with every kind in
Stalk.
```

## S4: Prompt 3, body language
```
Sections: B.3 (Animation), Prompt 3.
Scope:
- Look-at with per-kind caps, lean, plant-timed HollowStep (remove the timer emission once plants own it).
- Replicated Intent with the coil pose. The guarded warning-coil flag from S3 also shows the coil.
- Kind windups after the guard, miss follow-through, transition blending rules and the breathing Stalk freeze.
- The Stalker's coat strips and pallor within the part budgets.
Acceptance: Grabs audit green, /photo IK shortfall 0, coil and windup readable at 25 studs on the phone viewport,
steps on plants. Mesh strips stay HUMAN if they are used.
```

## S5: Prompt 4, the bell, the dwell and the railing grasp
```
Sections: B.3 (Tension and pacing, Train departure), B.4 (departure closure, stop clock), Prompt 4.
Scope:
- Bell rope prompt with u = (serverNow - doorsOpenAt) / original params.dwell and both eligibility branches.
- RunDirector.ShortenStop (shortens only, idempotent, latest milestone only), with hazards and timed events handled
  as specified.
- Stop clock B: WalkReference 30, Search {80,60}, WalkMargin 1.4, PerStop 3.
- The payroll farWalk reach spec plus one Studio PathfindingService check on Minehead.
- Grasp: a window check at the estimated press time, reach from the single receipt snapshot against the static rail,
  ReplicationTolerance 0.5 + closing speed x 0.1 s capped at +1.0, Aboard credited at attachment, hang/haul/
  fallShort poses and the measured shortfall.
Acceptance: Prompt 4 list. The two-client latency matrix stays pending if unavailable.
```

## S6: Prompt 5, the first run and AGAIN
```
Sections: B.3 (Cooperation and onboarding), A.4 (stop-1 sighting, E2), Prompt 5.
Scope:
- Tier-1 stop 1: no attacks plus the scripted sighting.
  - It appears 15–17 studs from the first player off, at least 4 studs outside lamp pools, falling back to 24 if no
    point fits; it is visible for at least 3 s, then walks away.
  - It waits for off-train crew or 12 s, the tells fire, and sighting_exposure is logged. It is E2's treatment arm,
    behind a flag that S7 wires.
- Stop 2: the scripted Crawler (pursuit 24, lunge 40, guard enforced). Stop 3: the wanderer-with-stalk.
- No first-cruise leak.
- AGAIN/DEPOT on the RunCard: queued presses applied after ResetReady, the 20 s fallback, eligibility including
  eliminated members.
Acceptance: Prompt 5 list at tutorialRuns override 0.
```

## S7: Prompt 10, the first three minutes, routes, invites and experiments
```
Sections: A.4 (all), Prompt 10.
Scope:
- First visit: the START board and Cars CountdownSeconds 20; the tier-1 first leg planned so its cruise is 25 s or
  less (Journey plans the shorter leg, with no scenery speed-up).
- Routes {Short=5, Long=10}, with Short stop k reading Long index m(k) = {1,2,4,6,8} for every difficulty input.
  The sky keys are unchanged. Verify that Omens and timed events read run.stopCount.
- longVictories, the SHORT LINE ticket stamp, and the route policy (a crew with a new player has a fixed length,
  otherwise the vote offers Short or Long).
- INVITE through SocialService.
- Logic/Experiments: crew-randomized at run start, with each player's exposed arm stored and logged. Wire E1 and E2.
- Plain-verb UI.
- The report prints both routes' durations and Brass per run.
Acceptance: Prompt 10 list. Measure the four first-session timings from a fresh profile on desktop and the phone
preset and report them against the A.4 targets.
```

## S8: Milestone 1 essentials from Prompts 6 and 7
```
Sections: C intro (Milestone 1 essentials), Prompt 6 (readability parts only), Prompt 7 (priority table, ducks,
Intent hush only).
Scope:
- The local readability check (sinkhole edge, nearest obstacle, Stalker at 15, 24 and 33 studs; chase dim,
  Performance and the phone preset). Fixes are limited to local light, rim and value steps; keep the current edge
  furniture.
- The Config/Audio priority table: departure warnings above threat above player feedback above ambience above the
  lobby piano, rewiring the existing compressors.
- The 0.4 s Intent hush (from replicated Intent, never from Windup).
Do NOT do materials, grades, density, the lighting lock, footsteps, ping or arrival silence (Milestone 2).
Acceptance: check green; readability screenshots per case; Output or AudioAnalyzer confirms the hush and the warning
priority. The owner audition stays pending.
```

---

**Stop here for Gate G1.** Use `docs/direction/2026-10-21_after-the-prompts.md` Stage 1 and the G1 prerequisites in
FINAL-DESIGN A.4. Start S9–S11 only after G1 passes, or after its failures are fixed and re-tested.

---

## S9: Prompt 6, the rest (station look and the lighting lock)
```
Sections: B.3 (Art direction), Prompt 6 (everything S8 did not do).
Scope:
- The surface rule (channels 18–232); remove whitewash coping and the station limewash.
- Red oil danger lamps with DangerLampMaxLit 8, rope, stakes and ember cracks. They are not SafeLights or stalk
  pools.
- Grades off cyan (saturation 0.10, PROVISIONAL).
- Material language per archetype and the density pass within the audit budgets
  (AUDIT_SEEDS=6 lune run audit Stations).
- Config/InteriorLight lighting lock with locked reference shots and luminance bands.
- Interior doors.
Acceptance: Prompt 6 list. The owner judges the look; the real-phone check stays HUMAN.
```

## S10: Prompt 7, the rest, plus Prompt 9 (merged)
```
Sections: Prompt 7 (everything S8 did not do), Prompt 9.
Scope:
- Crew-slot boot timbres (stable slot, not a userId hash), the 2 s arrival near-silence and board-creak steps.
- The Ping remote (rate-limited 1 per 3 s), glow, watch compass and whistle.
- Prompt 9: blood audit with bite puffs reduced by one third; Creator mode (Hud Hide also hides name tags and the
  ping glow); the phone-pass checklist and the release HUMAN list in HANDOFF.
Acceptance: Prompt 7 and Prompt 9 lists. The owner audition, the maturity questionnaire and the phone pass stay
HUMAN and pending.
```

## S11: Prompt 8, one Brass loop, Line Mastery and the premise
```
Sections: A.4 (reward budget, Brass provisional), B.3 (Progression, Narrative), Prompt 8.
Scope:
- Brass stays earned and spendable, on ordinary cosmetics only.
- The five status items become Line Mastery milestones (Logic/Milestones), with the AND condition for livery_royal
  (longVictories >= 1 AND stationsDeparted >= 50).
- Remove Rank conditions on Brass items. Keep the daily first-run bonus. No new tracker: three reward layers only.
- Mabel's errands as story; posters, the Roll, plaques and LORE section 0 Premise.
- Plain UI verbs, with the diegetic names kept in flavour copy.
Acceptance: Prompt 8 list, including a check that a Short Line run earns the cheapest Brass item within two runs
(from the report).
```
