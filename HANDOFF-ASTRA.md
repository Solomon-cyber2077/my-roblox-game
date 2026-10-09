# Cosmetics pass — Astra

Branch: codex/cosmetics-astra; base c1ba556. Isolated Rojo: port 34873.

## 1. Headwear previews
- Removed grey preview dummy; grid and large hats rotate upright, without per-card frame connections.
- Adjusted cap clearances and miner dome/lamp placement for R6.
- Validation: lune run check passed (223 tests; clean audit). Studio checked floating previews and worn conductor/miner/topper back views; hair hides under covered hats and restores for Bare Head. Topper camera framing corrected.
- No known check regressions. Manual: open Headwear, inspect all rotating cards, equip each cap and inspect front/sides/back.

All three requested items implemented.

## 2. Cosmetic identity and motion
- Lantern glass/frame profiles, inner flames and flicker; Aurora slow spectral cycle; Founder's crown/embers. Detailed cap badges, brass bands, goggles and premium topper.
- Animated reusable trail previews and miniature lettered carriages replace swatches. Legendary train trim becomes metallic and restores its material when changed.
- One 20 Hz client effects loop, 0.5-second caches; trails emit only while moving (4-6 particles/sec per foot). No uploaded assets or renamed items.
- Validation: lune run check passed, 223 tests and clean visual audit. Separate astra.rbxl connected to port 34873; startup and Outfitter open clean. All four tabs inspected in Studio; trail motion and lettered carriage previews visible; Terminus Gold equip updated the lobby train at zero Brass.

## 3. Virtual developer unlock
- Single switch: src/shared/Config/Cosmetics.luau, DevUnlock.Enabled (true). UserId 11744048795 in live servers, and all Studio test users. Set false and restart to disable.
- Every catalog item is virtually usable, including Brass, Robux and Today items. Equip uses DevCosmetic_<category> player attributes; no profile ownership/equipment writes or purchase prompts. Other live players retain ordinary rules.
- Validation: lune run check passed (228 tests; strict types, lint, formatting and clean visual audit). Separate Studio startup/Outfitter worked without script errors; all lantern cards showed owned at 0 Brass.
- Final Studio check: requested other window connected to port 34873; no script errors after restart/equips. Cap/miner/topper checked from behind, Bare Head restored hair. Full all-angle/avatar-size coverage and four-player mobile profiling remain manual QA.
- No item names or rarities changed. No known automated-check regressions. HANDOFF.md and Claude's UI scripts untouched.
