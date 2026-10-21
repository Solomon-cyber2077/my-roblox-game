# Is Last Train Out worth finishing? A second assessment

This responds to an outside assessment of LTO's prospects (hook, comparables, remaining hours, cash, revenue
scenarios). Part 1 checks its claims against the repository. Part 2 is my own long-form assessment. Like the
original, it uses no audience data: there is none yet. Studio was not running, so nothing here is a live
observation either.

---

## Part 1: Checking the outside assessment

### Claims that hold up (verified in source)

| Claim | Where it comes from | Verdict |
|---|---|---|
| Walk 30, sprint 31 studs/s | `Config/Tuning.luau:138-139` | Correct |
| Hollow chase about 22-26 before kind | HANDOFF 2026-10-18 (envelope 20.3-30.3 after kind, difficulty and pace) | Correct |
| A full run is about 53 minutes | `2026-10-20_LTO-professional-layer.md:21`, a calculation, not a measurement | Correct, and labelled honestly as a calculation |
| Wraith Mist is 149 Robux with `productId = nil` | `Config/Cosmetics.luau:247-252` | Correct |
| Stalking, early departure and progression changes are proposals | The direction docs, HANDOFF "design only, no game code changed" | Correct |
| Revenue table (70% share × $0.0038) | 10,000 → $26.60; 1M → $2,660; $750 → 282k Robux; $1,000/month → 376k Robux | Arithmetic checks out |
| Hours and weeks | 100-200 h + 25% = 125-250 h; ÷20 = 6-13 weeks; ÷40 = 3-7 weeks | Arithmetic checks out |

### Where it is incomplete or misleading

**1. The sprint problem is real, but already diagnosed and cheap to fix.** The assessment presents "sprint is a
3.3% bonus" as a discovery. The 2026-10-20 professional-layer brief found the same thing, explained why (walk
was raised to 30 on 10-18 so that loot carriers, at 0.85 and 0.65 of walk, stay near Hollow speed), and
decided the fix: walk 21, sprint 31, chase 24-26, lunge 1.45× for 0.55 s, carriers slower than every Hollow and
protected by the duo's lantern instead (B.4). That is Prompt 1. It is a handful of constants, a spec update and
a feel pass, not a redesign. It belongs in "known, scoped, unbuilt", not in "biggest concrete problems".

**2. The 30-40 minute target is already the project's own target.** The professional-layer telemetry table sets
"30-40 min; no quit spike at one stop" as the run-length goal. The assessment agrees with the plan rather than
correcting it. Credit to it for making that agreement explicit, but it is not new information.

**3. A `nil` product id is by design, not unfinished work.** AGENTS.md: "Robux product ids are bound after
publishing; `nil` means not for sale." Binding them is a ten-minute launch-checklist step once the place is
public. It does not belong next to phone readability as a risk.

**4. The cash budget has nothing to spend on.** $250-$1,500 of cash, excluding labour and ads, is hard to fill.
Roblox charges nothing for hosting, the project rule forbids bought or uploaded assets (except the approved
train and station meshes, already done), and sounds come from Roblox's free licensed library. The realistic
cash list is a cheap Android test phone if you do not have one (about $80-$150), a few hundred Robux for testing
your own products and private servers, and, optionally, a small ad test after G2. Call it **$0-$300**.

**5. The revenue model counts only one income stream.** It models Robux purchases at 70%. Roblox also pays
creators for engagement (time spent by eligible players, through its creator reward programme), and private
servers earn alongside products. For a game whose monetization rule (M1) is cosmetics only, engagement pay may
be a meaningful share of income. The table understates the upside slightly; it does not change the conclusion.

**6. It never connects players to money.** The table jumps straight to "100,000 Robux a month" without saying
how many players that needs. That missing bridge is what makes the numbers feel abstract. Part 2 gives one,
with its assumptions stated.

**7. Halloween is already out of reach.** Today is 2026-10-21. Ten days is not enough for 125-250 hours of work,
and launching half-finished into the busiest horror week on Roblox, against seasonal updates from games with
established audiences, is the worst of both. The assessment's "readiness over October 31" is right; I would go
further and say plainly that Halloween 2026 is off the table.

**8. One budget cap is the wrong shape.** "Fund a limited completion pass" commits all 125-250 hours at once.
The project already has a gate (G1, the closed playtest) that tells you cheaply whether the remaining hours are
worth spending. The money should follow the gates.

### Verdict on the outside assessment

It is careful, honest about what it cannot know, and its arithmetic is right. Its headline (worth finishing,
on a capped budget, plan for zero revenue) is sound. Its weaknesses are that it re-discovers known problems as
if they were new, inflates the cash cost, models only one income stream, and treats the remaining work as one
block rather than as stages with exits.

---

## Part 2: My own assessment

### The short answer

**Finish Milestone 1 and run the G1 playtest. Decide everything else after that.** LTO has a real hook,
unusually solid engineering underneath it, and two known design problems (pace and the speed ladder) that are
already solved on paper. What it does not have is any evidence that strangers want to play it, and the only way
to get that evidence is to put the first ten minutes in front of them. That costs roughly a third of the
remaining work. Spend that third, look at the result, then decide whether to spend the rest.

### What the game has going for it

**A hook that films well.** "Loot a haunted station, drag your crewmate out of a monster's grip, and make the
last train before it leaves without you" is one sentence, and every clause is a moment you can show in a
ten-second clip. Roblox discovery runs on thumbnails and short videos; a game whose best moments are visible at
a glance has an advantage most games never get.

**A distinct emotional centre.** The closest comparable, Dead Rails, proved there is a large audience for train
survival on Roblox, but its tone is action: guns, hordes, a long ride west. LTO's centre is different: a small
lantern pool, something tall at its edge, and the choice between grabbing one more crate or running for the
door. DOORS proved that audience exists too. LTO sits between them. Position it as **co-op horror** first and a
train game second; "train survival" alone puts it next to a far bigger game in a comparison it loses.

**Co-op that is mechanical, not just social.** The grab, the struggle and the crewmate pry mean another player
is the solution to a problem, not just company. That is the kind of design that makes people invite friends,
and invites are the cheapest growth there is.

**Engineering most solo Roblox projects never reach.** Server-authoritative state, deterministic generation,
strict typing, about 400 unit tests, and an automated visual audit. This matters commercially: it is what makes
fast iteration after launch possible, and post-launch iteration is where Roblox games are actually made.

### What is holding it back

**The run is too long for the platform.** About 53 minutes by calculation, against Roblox sessions that are
usually much shorter. A first-time player who has to give an hour to see an ending mostly will not. The 30-40
minute target is right, and I would also make sure a player who leaves at minute 15 has already had a complete,
satisfying arc (a stop, a scare, a narrow departure), because many will.

**The threat ladder is inverted today.** With walk at 30 and Hollows at 22-26, an unburdened player is never
really chased. Fear in a chase game comes from the gap closing; right now it opens. Until Prompt 1 lands, the
game's central tension is missing from the moment-to-moment play, and no amount of lighting or sound fixes that.

**It has never been played by a stranger.** Every assessment so far, including this one, is read from source.
The last several HANDOFF entries record no running Studio instance and no real phone. The most expensive
problems in a game like this (unclear goals, unreadable threats on a dim phone screen, a grasp that feels
unfair at 150 ms ping) are invisible in source.

**Discovery is unsecured.** No audience, no publisher, no featuring. The first traffic will come from your own
clips. That is workable, but it means the thumbnails and the first three minutes carry the whole launch.

**The check gate is not fully green.** The last full audit recorded Selene unable to fetch the Roblox API dump,
so `lune run check` did not complete end to end. Small, but it should be green before Milestone 1 is called
done.

### What it will cost, staged

My estimates largely agree with the outside assessment's total. The difference is how the hours are spent: in
stages, with an exit after each.

| Stage | Work | Hours (judgment) | Cash | Exit question |
|---|---|---:|---:|---|
| A. Milestone 1 | Telemetry, speed ladder, stalk state and tells, bell and dwell, first run and AGAIN, readability and sound essentials | 50-90 | $0-$150 (test phone) | Is the first ten minutes ready for strangers? |
| B. G1 playtest | Recruit 8-12, run sessions, review recordings, fix the largest gap, re-test once | 15-30 | $0 | Do strangers get in, get scared and want more? |
| C. Milestone 2 | Materials and lighting lock, rest of audio, progression changes, release plumbing | 35-70 | $0 | Is it ready to be public? |
| D. Launch prep | Real phone pass, network check, thumbnails and icon, store page, product ids, telemetry on a live server | 20-40 | $0-$150 (test Robux) | Can it survive strangers at scale? |
| **Total** | | **120-230** | **$0-$300** | |

At 20 hours a week, Stage A plus B is about four to six weeks. That is the only commitment I would make today.

**If G1 fails badly** (most testers lost before stop 2, nobody scared, nobody wants another run) after one round
of fixes, stop adding features. Either rethink the first ten minutes from scratch or shelve the game and keep
the codebase; its networking, state, generation and testing layers are reusable for the next project.

### What it might earn

Nobody can forecast this honestly without players. What can be done is to show what each outcome would require,
so you can recognise it if it happens.

Average CCU (concurrent players) is the number Roblox developers use as a shorthand. To turn it into money:

- **Visits.** Average CCU ≈ daily visits × average visit minutes ÷ 1,440. At 20-minute visits, 100 average CCU
  is about 7,200 visits a day.
- **Spending.** Cosmetic-only games earn little per player. As an illustrative assumption (not a benchmark),
  say players spend an average of 0.5-2 Robux per visit across everyone, most spending nothing.
- **Cash.** 70% creator share, then $0.0038 per earned Robux.

| Average CCU | Visits per month (20-min visits) | Robux spent at 0.5-2 per visit | Approximate cash per month |
|---:|---:|---:|---:|
| 20 | ~43,000 | 22k-86k | $57-$230 |
| 100 | ~216,000 | 108k-432k | $290-$1,150 |
| 1,000 | ~2,160,000 | 1.1M-4.3M | $2,900-$11,500 |

Add engagement pay and private servers on top; both are hard to estimate before launch. Also note that DevEx
has a minimum (30,000 earned Robux) before any cash can be withdrawn.

Read this table with the odds in mind. Most Roblox games never hold 20 average CCU. Reaching 100 is a real
achievement; 1,000 is rare. **Plan for zero revenue**, as the outside assessment says, and treat anything above
it as upside.

### Why finish it anyway

Because the downside is small and the upside is not only money.

- **The cost is mostly your time,** and $0-$300 of cash. There is no server bill, no asset licensing, no
  contractor.
- **A finished, published co-op horror game is a portfolio piece** that most hobbyist developers never produce.
  Roblox studios hire on exactly that evidence.
- **The codebase is a platform.** If LTO underperforms, the second game built on its state replication,
  generation, testing and audit layers starts months ahead.
- **The first real data will teach you more than another planning document.** The direction folder already
  holds four careful design reviews. The next useful input is a stranger's screen recording.

### What I would do this week

1. Get `lune run check` green end to end.
2. Run Prompt 0 (telemetry, with a durable sink you can read after a server closes).
3. Run Prompt 1 (the speed ladder), then play it in Studio until a Hollow on the hunt actually feels like it is
   closing in.
4. Start recruiting G1 testers who have never seen the game, with a clear consent rule for anyone under 18.

Everything else waits for G1.
