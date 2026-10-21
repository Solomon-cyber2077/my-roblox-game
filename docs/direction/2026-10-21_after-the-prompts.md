# After the prompts: playtest, launch, scale

This is a reference for after the implementation prompts. It follows A.4 and D of `docs/FINAL-DESIGN.md`; where the two differ,
the draft wins. The order is:

1. Milestone 1 (Prompts 0–5, 10, plus readability and sound essentials)
2. **Stage 1: G1 playtest**
3. Milestone 2 (the rest of Prompts 6–7, then 8–9)
4. **Stage 2: soft launch and G2**
5. **Stage 3: scale**

| Stage | Outcome it decides |
|---|---|
| 1 | Passes G1 |
| 2 | Sustains 100+ average CCU |
| 3 | Sustains 1,000+ average CCU |

No success probability is given for any stage. The draft (D.3) states that none is established, and the
investment assessment plans for zero revenue until it is measured.

---

## Stage 1: G1 closed playtest

**Question:** do strangers get into the game fast, understand the danger, and want to keep going?

### Before you start
- [ ] Milestone 1 is done. Each prompt's HANDOFF entry shows `lune run check` green and a Studio playtest.
- [ ] The first-session timings were measured in Studio from a fresh profile, on desktop and the phone preset
      (Prompt 10).
- [ ] The game is published to a private or friends-only place that testers can join. Robux product ids are not
      needed yet.
- [ ] One real phone (mid-range Android, Performance, landscape) has completed a full first session.
- [ ] Every event is written to a durable sink (a DataStore keyed by session and player) and has been read back
      after the server closed. `print` output does not survive the server.
- [ ] A written recording policy: record only testers 13 and over, with written guardian consent under 18;
      observe younger testers through telemetry and the debrief only.

### Recruiting
- 8–12 people who have **never** played LTO. At least half play on a **phone**, and a mix of ages and experience
  is better.
- Good sources: a small Discord, your TikTok audience, or Roblox playtesting communities. Friends who have seen
  you build it do not count for G1; use them for bug hunting before G1.

### Running a session
- Ask each tester to record their screen and voice, and to talk out loud about what they see and think.
- **Do not help.** Ask nothing during play. If they are stuck, note when and where.
- Each session lasts until they quit or finish one run. No time pressure.
- Afterwards ask four short questions: *What was the game about? Did anything scare you, and when? What was
  confusing? Would you play again tomorrow?* Also ask the sighting question: *Did you see anything at the first
  stop?*

### What to record per tester (spreadsheet)
| Column | Source |
|---|---|
| Device | Ask |
| Join → control (s) | `first_session_timing` |
| Join → run start (s) | `first_session_timing` |
| Join → stop 1 doors open (s) | `first_session_timing` |
| Join → first Hollow in line of sight (s) | `first_session_timing` |
| Sighting line-of-sight seconds; did they mention it unprompted? | `sighting_exposure` plus the recording |
| Reached stop 2 unaided? | Telemetry plus the recording |
| Where they got stuck or confused (timestamp + what) | Recording |
| Quit point and stated reason | Recording plus question |
| "Would play again tomorrow?" | Question |

### Pass criteria (all must hold)
- Median join → stop 1 ≤ **120 s**
- ≥ **75%** see a Hollow by **180 s**
- ≥ **9 of 12** (or the same share) reach stop 2 unaided

### If it fails
- Fix the **largest** gap first, which is usually the first 10 minutes, then re-test with **new** people. Repeat
  testers have learned the game.
- Do not start Milestone 2 until G1 passes, or until its failures are fixed and re-tested.

---

## Stage 2: soft launch and G2 (toward 100+ average CCU)

**Question:** do players who find LTO organically on Roblox's Home page click, stay and come back?

### Before going public (mostly owner/account tasks; see draft Prompt 9 and D.2)
- [ ] Milestone 2 done (materials and lighting lock, the rest of the audio, Brass and Line Mastery, release
      plumbing).
- [ ] **Real phone pass:** landscape and portrait, Performance quality, 40% brightness. Check the lobby, boarding,
      stop-1 loot, a grab and skill check, the bell, the grasp, the RunCard and the Outfitter. No blocking issues
      remain.
- [ ] **Network check for the grasp:** two clients at 0/50/100/200 ms delay. Confirm or adjust
      `ReplicationLagSeconds`.
- [ ] **Owner audition:** headphones and phone speaker.
- [ ] **Maturity questionnaire** answered honestly for the whole game; record the label you get.
- [ ] **Account:** age/ID verification and two-step verification done.
- [ ] **Robux products** created and their ids bound (`Config/Cosmetics`). **Private servers** enabled at a low
      price.
- [ ] **An icon and 2–5 thumbnails**, built from the three clip moments: the Stalker at the edge of the light, the grasp
      near-miss and the crewmate pry. One of them is the amber lantern with the tall silhouette.
- [ ] Store listing that leads with "co-op survival". Plain description, no lore dump.
- [ ] **Published-server telemetry check:** the events actually arrive in Creator Analytics, not just in Studio
      Output.
- [ ] Experiments E1 (Short vs Long Line default) and E2 (sighting vs none) switched **on**.

### Launch actions
- Publish publicly. Post your clips (TikTok and similar) the same week to bring in the first traffic.
- Do **not** run paid ads yet. Ads wait for the phone pass, verified analytics and the evidence gates below.

### What to watch in Creator Analytics (Discovery and Retention)
| Signal | Most important? | What it tells you |
|---|---|---|
| Play-through rate | Yes | Thumbnail and title appeal |
| First-play bounce (<60 s, 61–180 s) | Yes | The first three minutes |
| Playtime per user | Yes | Whether sessions hold |
| Play days per user (D1, D2–7, D8–28) | Yes | Whether players come back |
| Intentional co-play days | Next tier | Friends and invites |
| Qualified plays, spend days (Robux) | Next tier | Depth and monetization |

### G2 rule (diagnose, don't freeze)
A signal **below the benchmark median** triggers a diagnosis. A fix jumps ahead of new content only when all of
these hold:
1. There is enough data, with counts and uncertainty stated.
2. The comparison group is suitable.
3. Telemetry or a playtest shows **which funnel step** is failing and a plausible cause.

Benchmarks are comparisons only and do not affect ranking.

### Evidence gates before tuning from quit curves
- ≥ **300** unique first-run players per device group and ≥ **150** completed crew runs. State counts and
  intervals.
- Experiments: read them as directional until about **2,830 per arm** (D1 return, E1) and **1,480 per arm**
  (E2), adjusted by the measured crew design effect.

### Decisions this stage makes
- Short or Long Line as the new-player default (E1).
- Sighting kept or removed (E2).
- Brass kept or simplified: compare Brass spending with D2–7 return; it is provisional.
- Which icon and thumbnail stay (play-through rate, not taste).

### If it stalls
After the experiments reach a directional read, give public play eight weeks (provisional), then record one of:
**iterate** (one funnel step clearly fails and the cause is known), **relaunch** (players stay but too few click:
rework icon, thumbnails, title and clips) or **stop** (players bounce and no single step explains it; keep the
codebase).

---

## Stage 3: scale (toward 1,000+ average CCU)

**Question:** once the funnel is healthy, can the game grow and keep players over weeks?

### Only start when
- The G2 signals are at or near benchmark, with enough data behind them.
- D8–28 play days are stable or rising, so players are still returning after the first week.

### Actions
- **Content cadence:** roughly one new behaviour or event every two months (proposed, depends on your capacity).
  First candidates: the Rider (Cruise threat), new stop archetypes, omens. Each one **replaces or extends** a
  layer; it never adds a fourth reward system.
- **Thumbnail rotation:** keep testing new clip moments and keep whichever plays through best.
- **Paid ads (Sponsored):** only after the phone pass, verified analytics and the Stage 2 evidence gates. Size the
  spend with `average CCU ≈ daily visits × mean visit minutes / 1,440`, using **measured** visit minutes.
- **Co-op growth:** watch intentional co-play days. If they are low, improve invites, party flow and
  private-server value before adding content.
- **Audience segments:** compare phone vs desktop and first vs returning players. Fix the weakest segment
  before the strongest one.

### Signs it's working
- Impressions on Home grow week over week without paid traffic.
- D8–28 play days stay flat or climb after updates.
- CCU holds between content drops instead of spiking and fading.
