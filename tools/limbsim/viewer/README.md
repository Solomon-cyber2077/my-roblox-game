# Limb-sim viewer

Replays the limb-loss sim traces (`../traces/`, written by lib/LimbSim on the HP) on a top-down station map, with
the event list, crew state and the all-sessions results from `../summary.json`. Plain HTML/JS, no build, no installs.

- Open: desktop launcher **LTO Limb Sim**, or `python3 serve.py` (serves `tools/limbsim/` on a free 127.0.0.1 port,
  opens the default browser, exits after 15 minutes with no open page). `Open file…` loads any trace JSON by hand.
- Keys: Space play/pause, ←/→ 1s (Shift 5s), Home/End. URL: `?trace=<id>&t=<seconds>`.
- Check: `python3 check.py` validates every listed trace and runs the page's self-test in headless Firefox
  (`--no-browser` for the format part only).
- Real traces are listed by `../traces/index.json`; when there are none, `sample/` (hand-made, `sample/index.json`) is shown.

## Trace format (as the real traces are written)
```
index.json  [{ file, id, title }]
trace       { meta, map, frames, events, summary }
meta        { seed, station, crew: [{ id, name, persona, device, rttMs }] }
map         { cols, rows, tile, length, train: { x0, x1, z }, blocked: [cell], buildings: [[x0, z0, x1, z1]] }
            cell = row * cols + col, columns from x = -length/2, rows from z = 0 (inferred from the data, see below)
frames      [{ t, p: { "<crew id>": [x, z, state, armsLost, items] }, h: [[x, z]] }]   (h may be {} when empty)
            state: Aboard | Afield | Looting | Held | Dead; armsLost: "" | "L" | "R" | "LR"; items: carried count
events      [{ t, type, who?, by?, ...}]  types seen: hollow grab checkMiss escape board rescueOpen rescueJoin
            beat{beat,result} tear{arm} drop{items} returnStart{deadline} healStart heal death{text} outcome{text}
summary     { died, rescued, returned, text }
```
Unknown event types still show, with their fields. Events may arrive out of time order; the viewer sorts them.
The `blocked` cell order is inferred: row-major put the fewest player positions inside blocked cells. If HP's
writer says otherwise, change `cellRect` in `core.js`.
