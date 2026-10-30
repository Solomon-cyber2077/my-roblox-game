# Simulator calibration (bot playtests, `lune run playtest`)

The owner's rule (2026-10-29): the simulator replaces real playtesters, and any change that needs a player metric
gets the simulator extended until it measures that metric. This sheet lists the published numbers the bots should
follow, where each one goes in `.lune/lib/Personas.luau` / `.lune/lib/PlaytestSim.luau`, and how far to trust it.
Confidence: **high** = several agreeing sources; **medium** = one solid source or close agreement; **low** = sources
disagree or are old, use as a range.

## 1. Who plays (crew mix)
| Number | Source | Maps to | Confidence |
| --- | --- | --- | --- |
| ~80% of Roblox daily users on mobile, ~17% PC, ~3% console (2024 annual report); 74% of sessions on mobile (2025) | [PocketGamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue), [GrabOn](https://grabon.com/blog/roblox-statistics/) | crew draw in `playtest.luau`: today 4 of 8 personas are mobile (50%). Weight the draw so ~75-80% of bots are on touch | high |

## 2. Hands: touch latency and frame time
| Number | Source | Maps to | Confidence |
| --- | --- | --- | --- |
| Touch-to-screen 46-110 ms on phones (2014 lab); drag latency still ~80 ms on modern phones (2022) | [PhoneArena](https://www.phonearena.com/news/Funky-metrics-HTC-One-M8-has-the-fastest-46ms-phone-display-touch-response-time-so-far_id54887), [FIG Lab](https://www.figlab.com/research/2022/tribotouch), [Android WALT](https://android.googlesource.com/platform/external/walt/+/HEAD/docs/DragLatency.md) | `Device.latency`: Phone 0.05 is at the floor; LowPhone 0.07 and BudgetAndroid 0.08 are plausible | medium |
| A frame adds to every input: at 28 fps that is ~36 ms a frame, ~1.5 frames on average before the game sees and shows a press | engine behaviour | today `fps` is "for the report" only. Use effective latency = `latency + 1.5 / fps` in the skill check and chase reactions (LowPhone ~0.12 s, Desktop ~0.02 s) | medium |
| No published Roblox frame rates for low-end Android | none found | `fps` stays an assumption; the sim has no renderer, so report it as "assumed" (phone-report does) | low |

## 3. Eyes and thumbs: tapping targets
| Number | Source | Maps to | Confidence |
| --- | --- | --- | --- |
| One-handed thumb taps stop getting worse at ~9.2 mm (single taps) and ~9.6 mm (repeated taps); ~1 cm is the practical minimum | [Parhi, Karlson, Bederson 2006](https://www.microsoft.com/en-us/research/?p=155150), [NN/g](https://www.nngroup.com/articles/touch-target-size/) | replace the constant `ACTION_BUTTON_SHARE = 0.35` with a miss chance from the target's real size: ~3% at >= 9.6 mm, rising linearly to ~25% at 4 mm, x1.6 for a target that moves with the camera (world chips) | medium for the threshold, low for the slope |
| iPhone SE-class: 1 pt ~ 0.156 mm. World chip on a phone: 64 pt x 0.72 = 46 pt ~ 7.2 mm tall, and it moves. Action button: 64 pt ~ 10 mm, fixed | screen geometry | gives chip ~13% x 1.6 ~ 21% vs button ~3%; feeds `promptMisses` from layout, not from an assumption | medium |

## 4. Reactions
| Number | Source | Maps to | Confidence |
| --- | --- | --- | --- |
| Simple visual reaction ~317-328 ms at ages 10-12; adults ~280 ms in the same tables; on harder choice tasks 10-year-olds are up to ~1.8x slower than adults | [PMC4378532](https://pmc.ncbi.nlm.nih.gov/articles/PMC4378532/table/tbl2), [PMC3146311](https://pmc.ncbi.nlm.nih.gov/articles/PMC3146311/table/tbl0010), Hale 1990 via [Kiselev](https://pmc.ncbi.nlm.nih.gov/articles/PMC6803537) | `Persona.reaction`: a game reaction is a choice reaction, so no persona should be under ~0.30 s. Dev at 0.22 s is faster than an adult's simple reaction; Mia (11) 0.55 s and Sam (9) should sit ~1.5-1.8x an adult's | medium |

## 5. Ears: sound off
| Number | Source | Maps to | Confidence |
| --- | --- | --- | --- |
| Sources disagree: 73% play with volume >= 10% (2013 analytics) vs only 8% say they play with sound on (survey) | [TouchArcade](https://toucharcade.com/2013/11/05/73-of-mobile-gamers-play-with-the-sound-on/), [TapResearch](https://blog.tapresearch.com/how-sound-preferences-impact-player-engagement) | new `Device.soundOff` (mobile 0.3-0.6, PC 0.1). With sound off the departure whistle and bell do nothing: `lateBy` should use only the visual cues (watch, T-30 slate, T-10 "ALL ABOARD" slate, edge pulse); with sound on, the whistle catches most late readers. Today sound is not modelled at all, so warning changes cannot show up in the numbers | low (range) |

## 6. Opinions: replay, session length, quitting
| Number | Source | Maps to | Confidence |
| --- | --- | --- | --- |
| Day-1 return for similar experiences, median to 90th percentile: ~12-24% (Roblox's own example); median session ~26 min, casual players leave in under 2 min, core players ~37 min | [Roblox DevForum](https://devforum.roblox.com/t/analytics-similar-experience-benchmarks-broader-access/2210285), [GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/cn/reports/2025-roblox-report) | `wouldReplay` is 85-92% in every run, about 4x real day-1 returns: rescale it so a good build lands ~15-25%. Add a first-two-minutes bounce before stop 1 (onboarding, waiting, confusion) for casual personas. Ratings of 8.7-9.0 are high for the same reason | medium |

## 7. Checks the sim should run on itself
- **Same personas, different device:** forcing Desktop must not do worse than LowPhone on the same seeds. Today it does
  (skill-check miss 41.4% PC vs 37.8% LowPhone; grabs escaped 52% vs 61%). Either the game over-helps touch (the touch
  lead plus half the ping as extra tolerance both favour a laggy phone) or the sim counts the allowance twice. Settle
  which before trusting PC-vs-mobile numbers.
- **Forced device in the report:** with `--device=` the persona table still prints each persona's own device.
- **Assumed vs measured:** any number the sim sets itself (fps, button share) must be marked as an input in the report.

## 8. Exact, modelled and fitted (added 2026-10-29 evening)
- **Exact: touch layout.** `lune run layout` places Roblox's jump button, the thumbstick zone and the action-button
  slots by Roblox's current client scripts (Roblox-Client-Tracker datamine: PlayerModule ControlModule
  TouchJump.lua, DynamicThumbstick.lua; CoreScripts ContextActionTouch.lua) and ours by our code, on five real
  screens in millimetres, both of Roblox's control branches (`--abilities=1`). It exits 1 on a target under 9.2 mm,
  an overlap or a cramped gap, so it can gate builds. Assumed until confirmed: the top inset (58) and Android
  densities; `tools/studio/layout-dump.luau` + `lune run layout --dump=<device>.json` checks them against Studio.
  It drove the fixes: Logic/TouchCluster places RUN, LOOK, PING and the action button around the real jump button
  at 60 units in screen space; the hunted cue maps viewport to canvas; the cash-out card has a phone layout;
  whole ballot tickets tap on touch screens. 38 problems -> 0 on both branches.
- **Modelled: frame time.** `lune run framecost` reads every scene's load from `lune run audit`, fits a linear cost
  to Studio measurements (`tools/studio/perf-probe.luau`, 5+ scenes) and scales it to phones by 3DMark Wild Life
  Extreme (UL database: iPhone SE 1693, iPhone 15 2868, Helio G99 ~357; no score found for Unisoc T606 or A14).
  GPU-bound lower bound: CPU-bound work is not in a GPU score. Self-test recovers a known cost exactly.
- **Fitted: behaviour.** `lune run sim-fit --telemetry=dump.csv sim=a.json` puts live players (telemetry sink CSV)
  next to bot players per device group with a 95% margin that counts both samples and crews sharing a fate, and
  names the sim knob each real gap points at. Same-build self-tests stay inside the margin. With ~430 players a
  group it detects gaps of ~10 points or more; more players narrow it.
- **Fed back:** PlaytestSim's world-chip size now uses our UI scale per device (layout check) and the button its
  real 60 units: old chips miss 27.5 per 100 searches on a LowPhone vs 3.2 with the button.
