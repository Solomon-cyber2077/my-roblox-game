# Stations: design notes (fix pass part 3)

The goal: stops about three times the walkable ground, two to three times the buildings, real
interiors, a landmark you can name from the platform, and a cold, lonely dark you can still read.
Every stop has the same bones so players learn them: **platform and train (safe, lit) -> Near ->
Mid -> Far -> the village at the far edge**, with the sinkhole beyond a marked edge on three sides.

Shared rules
- **Lamp pools.** Lamps stand in pools along the routes with dark stretches between them; the
  platform and the train sit in an unbroken run of SafeLight lamps. Hollows rest in the dark gaps
  between pools, in the alleys behind buildings and in unlit back rooms.
- **The edge.** Every open side has a hazard rail (yellow-and-black posts, yellow top rail, red
  mid rail), striped hazard tape on the ground and a cold red glow strip along the lip, tagged
  `SinkholeEdge`. A gap in it means a building wall stands there instead.
- **The village** (every regular stop): a cluster of 4-6 cottages, an inn or chapel, back yards
  and a lane, at the far edge behind the last barrier. More containers and the better ones, the
  longest walk, the first ground the fog takes, and the Hollows' spawn lanes beside it.
- **Hiding places.** Alleys between buildings (one tile wide), back yards behind low walls, the
  space under raised structures (water tower legs, coal stage, headframe) and dark interiors.

References: Victorian-era rural stations combined a station building with stationmaster's
quarters, a goods shed, a water tower and a timber signal box (Kyneton, 1862; Tarago, 1884);
signal boxes were two storeys with the lever frame upstairs and the locking room below (Par,
Wainfleet, Helsby); motive-power depots grew from coal stacks and hand-coaling stages to
gravity coaling towers beside ash pits (Carnforth, Shildon coal drops); a colliery pit yard holds
the headframe, winding house and chimney, lamp room, baths, offices and workshops (Penallta);
Victorian market halls stood in an open square reached by streets (Wigan, Derby); station hotels
kept a stable and coach-house range round a rear yard (Shrivenham, Newburn). Sources are listed
at the end.

## Whistle-Stop Halt (Street)
A country halt grown into a hamlet. The lane runs from the booking hall straight up through the
hamlet to the village green, crossed by a farm track. **Landmarks:** a timber water tower on a
brick base and a cattle dock with its pens near the platform; the stationmaster's house (two
rooms down, two up) beside the booking hall; a goods shed on the far side of the cross track.
**Loot:** balanced; parcels in the booking office, tools in the goods shed, the best in the
village's cottages and the farm. **Hazards:** low; the cattle pens and hay make sight-breaking
clutter. **Lamps:** a pool at the booking hall door, one at the crossing, one on the green; the
lane between is dark. **Hiding:** behind the goods shed and in the cattle pens.

## Coaling Yard (Sidings)
A locomotive depot: sidings run the length of the yard, a concrete coaling tower straddles one
of them, the ash pits and coal stacks sit beside it. **Landmarks:** the coaling tower (tallest
thing on the line), a brick chimney over the boiler house, the engine shed. **Buildings:** boiler
house, engine shed, a coal office, the depot's bothy and a row of railwaymen's cottages in the
village. **Loot:** coal everywhere, parts in the engine shed's back room. **Hazards:** high
collapse; heaps and hoppers block sight lines. **Lamps:** one floodlight pool on the tower,
bonfires in braziers, dark between the heaps. **Hiding:** under the hoppers and between heaps.

## Signal Works (Sidings)
A signalling depot and junction. **Landmarks:** a two-storey signal box you can climb (locking
room below, lever room above, glazed on all sides), a signal gantry over the main lane, cable
drums stacked like walls. **Buildings:** the signal workshop, a stores shed, the lineman's
cottage, and a terrace in the village. **Loot:** parts-rich, tools in the workshop and stores.
**Hazards:** more Hollows; long straight sidings give long sight lines, the drums break them.
**Lamps:** cold white floodlights on the gantry and the box, the rest dark. **Hiding:** among
the drums and under the box's stair.

## Ashfall Market (Plaza)
A market town: a square with a fountain and stalls, a covered market hall on one side, shops
round it, a clock tower over the street out. **Landmarks:** the clock tower and the market hall's
long roof. **Buildings:** market hall, general store, a public house, the corn exchange office
and a back street of houses toward the village. **Loot:** relics in the stalls and shops.
**Hazards:** fog-heavy; the stalls make a maze. **Lamps:** gas lamps round the square only;
the back alleys are dark. **Hiding:** the stall rows and the alleys behind the shops.

## Viaduct Halt (Street)
A halt on a high, narrow embankment where the line crosses a valley. Long and shallow.
**Landmarks:** broken stone arches standing in the yard (the old viaduct), a chapel with a
bell-cote, a signal box. **Buildings:** chapel, a ganger's hut, the platelayers' cottages.
**Loot:** relics, tools. **Hazards:** fragile ground (fast collapse), edges close on two sides.
**Lamps:** few; the chapel's windows glow. **Hiding:** under the arches.

## Minehead (Yard)
A colliery village. A pit yard by the platform: the headframe over the shaft, the winding house
and its chimney, the lamp room and baths; the miners' rows up the hill. **Landmarks:** headframe,
chimney, a tunnel mouth (the drift) at the far edge. **Buildings:** lamp room and baths, winding
house, pit office, two terraces of miners' cottages, a chapel in the village. **Loot:** coal and
parts. **Hazards:** the most Hollows; the drift breathes them out. **Lamps:** a ring of pit-yard
lamps round the headframe, the rows dark. **Hiding:** behind the spoil heaps and in the drift.

## Ashgrove (Yard)
A school village. **Landmarks:** the board school with its bell tower, a water tower, the
churchyard. **Buildings:** school (two storeys), the schoolmaster's house, a chapel, a shop and
cottages. **Loot:** balanced, relics in the library and staff room. **Hazards:** sleepers in the
classrooms. **Lamps:** the playground lamp and the chapel; the lanes dark. **Hiding:** the
cloakrooms and the churchyard wall.

## Brannoc Infirmary (Yard)
A cottage hospital outside a small town. **Landmarks:** the hospital's boiler chimney, a
mortuary, a walled garden. **Buildings:** the hospital (two storeys, wards upstairs), the
doctor's house, the mortuary, a laundry, cottages. **Loot:** tools and tonics, the locked
dispensary. **Hazards:** fog. **Lamps:** cold white lamps at the hospital door and the gate.
**Hiding:** the laundry yard and the garden walls.

## Gallowmere Junction (Plaza)
A junction town round its railway hotel. **Landmarks:** the hotel's front (three storeys of
windows), a bandstand in the square, a signal gantry where the lines part. **Buildings:** hotel
(guest rooms upstairs, coal cellar), the stable and coach-house range round its back yard, a
public house, shops. **Loot:** relics and coal. **Hazards:** more Hollows. **Lamps:** the hotel
porch, the bandstand; the stable yard dark. **Hiding:** the stable stalls, the coach house.

## Wickham Cross (Street)
A post town on a crossroads. **Landmarks:** a clock tower at the crossing, the sorting office.
**Buildings:** sorting office (strongroom), general store, a bank-like counting house, a public
house, terraces down both streets. **Loot:** relics in the strongroom. **Hazards:** fog and more
Hollows. **Lamps:** the crossing and the sorting office door. **Hiding:** the yards behind the
terraces.

## Emergency Village (breakdowns)
Not a station: a hamlet beside the line where the broken train stops (no platform buildings, a
rough cinder bank instead). The crew has a timed window to find the repair parts the train needs
in cottages, a smithy and a farm. It yields repair parts only. Its threat follows the run's curve
and the tutorial tier. **Lamps:** the train's lights and one lamp at the lane's end; nothing
else. **Edge:** marked like a station's.

## Shared kit and budgets
Station pieces are built from primitives through `Visual/Kit`, `StructureKit` and
`StationDressing`; the Blender kit (lamp post, fence and rail pieces, crate, sign, wall and roof
modules) is exported as FBX with a config of mesh ids that falls back to primitives while the ids
are empty. Budgets per station are in HANDOFF.md.

## Sources
- Kyneton station, goods shed and water tower (Victorian Heritage Database): https://vhd.heritagecouncil.vic.gov.au/places/635/download-report
- Tarago Railway Precinct (NSW heritage): https://apps.environment.nsw.gov.au/dpcheritageapp/ViewHeritageItemDetails.aspx?ID=4806298
- Par signal box (Historic England): https://HistoricEngland.org.uk/listing/the-list/list-entry/1413731
- Wainfleet signal box (Historic England): https://HistoricEngland.org.uk/listing/the-list/list-entry/1414000
- Coaling tower: https://en.wikipedia.org/wiki/Coaling_tower ; Motive power depot: https://en.wikipedia.org/wiki/Motive_power_depot
- Carnforth coaling plant (Historic England): https://historicengland.org.uk/listing/the-list/list-entry/1078213
- Colliery pit yard (Staffordshire Past Track): https://www.staffspasttrack.org.uk/exhibit/coal/colliery%20overview/pityard.htm
- Penallta lamp room: https://britishlistedbuildings.co.uk/300013583-penallta-colliery-lamp-room-gelligaer
- Wigan Old Market Hall: https://www.wiganlocalhistory.org/articles/the-old-market-hall-1877-1978
- Shrivenham stable and coach house: https://www.shrivenhamheritagesociety.co.uk/listing.asp?listID=592
- Newburn station hotel: https://sitelines.newcastle.gov.uk/index.php/SMR/16285
