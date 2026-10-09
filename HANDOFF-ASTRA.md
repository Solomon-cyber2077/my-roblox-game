# Cosmetics pass — Astra

Branch: codex/cosmetics-astra; base c1ba556. Isolated Rojo: port 34873.

## 1. Headwear previews
- Removed grey preview dummy; grid and large hats rotate upright, without per-card frame connections.
- Adjusted cap clearances and miner dome/lamp placement for R6.
- Validation: lune run check passed (223 tests; clean audit). Studio visual fit remains pending a separate place connected to this worktree.
- No known check regressions. Manual: open Headwear, inspect all rotating cards, equip each cap and inspect front/sides/back.

Next: cosmetic detail/effect pass, then virtual developer ownership.

## 2. Cosmetic identity and motion
- Lantern glass/frame profiles, inner flames and flicker; Aurora slow spectral cycle; Founder's crown/embers. Detailed cap badges, brass bands, goggles and premium topper.
- Animated reusable trail previews and miniature lettered carriages replace swatches. Legendary train trim becomes metallic and restores its material when changed.
- One 20 Hz client effects loop, 0.5-second caches; trails emit only while moving (4-6 particles/sec per foot). No uploaded assets or renamed items.
- Validation: lune run check passed, 223 tests and clean visual audit. Separate astra.rbxl connected to port 34873; startup and Outfitter open clean. Full equipped visual review follows the dev unlock.
