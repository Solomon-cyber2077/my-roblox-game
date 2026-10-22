# Void mist: design pass (VM5), 2026-10-22

Studio captures (mist.rbxl, half size). The before and after shots are of different stops (the stop is drawn
from the run seed), from the same camera placement relative to the back edge.

| File | What |
|---|---|
| before_profile_h20.jpg | Before: the yard ends in a sheer cut; dark cliff blocks hang into the void. |
| before_standing_h20.jpg | Before: from the yard at eye height. |
| rejected_canal_h14.jpg | Rejected iteration: a flat, saturated teal sheet reads as a canal of water in daylight. |
| wip_profile_h26.jpg | Iteration at 2 a.m. (before the grey mix). |
| after_profile_h20.jpg | After, dusk: a dark blue-grey bank over the drop, the cliff ghosted under it. |
| after_profile_h14.jpg | After, day: pale billowing fog (the station's own fog is also rolling in). |
| after_standing_h20.jpg | After, eye height: the fence stays crisp; haze softens the far trees. |

References (mood only): fog that comes right up to the cliff edge, a cool desaturated palette
(budgetpixel.com/p/40756, marcchartier04.artstation.com/projects/984W3Q, math.mun.ca/~dapike/pix/2001/ftroy).

What the iterations taught (now in Scenery/EdgeMist):
- A Beam that does not face the camera spreads its width along its attachments' SecondaryAxis.
- The smoke texture's own alpha thins every textured layer, so untextured bodies give the bank its cover.
- Overlapping untextured beams band where they double up; bodies abut at one rail width.
- The preset is a hint: every layer is half-way to a pale grey, or the sea reads as water by day.

Not measured: MicroProfiler cost (570 beams; frame time stayed at the 60 fps cap with them on or off).
Lightning in the mist is LATER (the Council cut it from v1).
