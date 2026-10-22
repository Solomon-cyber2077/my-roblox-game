# Session prompts (ready to paste)

Each `S<n>.md` is one complete prompt: the shared preamble plus that session's block. Copy the whole file into a
fresh session, or tell the agent "run S9" and it reads `prompts/S9.md` itself.
Copied from `docs/direction/2026-10-22_session-prompts.md` (that file stays the source; if it changes, update these to match).

| Session | File | Prompt(s) | Model / effort | Depends on | Status |
|---|---|---|---|---|---|
| S1 | [S1.md](S1.md) | 0 Telemetry, sink, balance report | Opus 5.5 / high | none | done |
| S2 | [S2.md](S2.md) | 1 Speed ladder, carriers, glance | Opus 5.5 / medium | S1 | done |
| S3 | [S3.md](S3.md) | 2 Stalk, guard, door-forcing, tells | Opus 5.5 / high | S2 | done |
| S4 | [S4.md](S4.md) | 3 Body language | Opus 5.5 / high | S3 | done |
| S5 | [S5.md](S5.md) | 4 Bell, dwell, grasp | Opus 5.5 / high | S1, S2 | done |
| S6 | [S6.md](S6.md) | 5 First run and AGAIN | Opus 5.5 / high | S3, S5 | done |
| S7 | [S7.md](S7.md) | 10 First three minutes, routes, invites, experiments | Opus 5.5 / high | S1, S5, S6 | done |
| S8 | [S8.md](S8.md) | Essentials from 6 and 7 | Opus 5.5 / medium | S4 | done |
| G1 | none | Closed playtest (docs/direction/2026-10-21_after-the-prompts.md, Stage 1) | human | S1–S8 | todo |
| S9 | [S9.md](S9.md) | 6, the rest (materials, edge, grades, density, lighting lock) | Opus 5.5 / high | G1 | todo |
| S10 | [S10.md](S10.md) | 7, the rest, plus 9 (footsteps, ping, arrival silence, release plumbing) | Opus 5.5 / medium | G1, S8 | todo |
| S11 | [S11.md](S11.md) | 8 Brass loop, Line Mastery, premise | Opus 5.5 / high | G1, S7 | todo |

## Void Mist (Council run 20261022-131445, branch `claude/void-mist`, worktree ../LTO-mist)
Run in order; VM4 and VM5 need only VM1; VM6 needs VM5; VM7 comes last.

| Session | File | Council prompt | Depends on | Status |
|---|---|---|---|---|
| VM1 | [VM1.md](VM1.md) | 01 Tuning and zone math | none | done |
| VM2 | [VM2.md](VM2.md) | 02 Edge wall and fall rescue | VM1 | done |
| VM3 | [VM3.md](VM3.md) | 03 Edge mist damage | VM2 | done |
| VM4 | [VM4.md](VM4.md) | 04 Client current | VM1 | done |
| VM5 | [VM5.md](VM5.md) | 05 Mist visuals and tint | VM1 | done (MicroProfiler HUMAN) |
| VM6 | [VM6.md](VM6.md) | 06 Hum and idle | VM5 | done (two-client + listening HUMAN) |
| VM7 | [VM7.md](VM7.md) | 07 Debug tools and QA | VM2-VM6 | todo |
