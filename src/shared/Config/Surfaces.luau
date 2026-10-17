--!strict
-- Surface treatments that let hazards and obstacles read inside the lantern pool on a dim
-- screen (docs/visibility). Colour, value and a little geometry only: no light, no glow.
-- Period basis (LORE.md): 19th-century platform edges were stone or hard blue coping brick;
-- staff whitened edges with whitewash in fog before 1914 (rare, spreading in 1939); limewash
-- was the West Country's everyday paint for walls, posts and outbuildings. tests/Surfaces.spec
-- holds every pale colour here above its floor, after the worst grade's grime.

local Surfaces = {
	-- linear relative luminance floors (Logic/Luminance, Rec. 709)
	MinPale = 0.6, -- limewash, coping and train lining, after grime
	MaxMargin = 0.04, -- the blue-brick margin behind the coping stays dark

	-- the platform's edge stones: worn pale stone, fog-whitened; wider than before so their
	-- inner half clears the docked train's overhang and takes the open sky
	Coping = {
		color = { 250, 250, 244 }, -- fresh whitewash: the most a surface can give under the overhang
		width = 2.35, -- studs (was 1.55); the outer edge does not move
	},
	-- a course of blue engineering brick laid behind the coping: the dark field the pale
	-- edge reads against (repaints the old yellow strip, which no 1880s platform had)
	Margin = {
		color = { 40, 42, 52 },
		width = 0.7,
	},

	-- lime-washed bands low on what a player can walk into, brushed on by hand: each band's
	-- height and tone vary a little from object to object
	Limewash = {
		color = { 240, 238, 228 },
		share = 0.45, -- of the part's height
		min = 0.8, -- studs
		max = 1.8,
		jitter = 0.2, -- +- share of the band's height, per object
		tone = 0.04, -- +- shade, per object
		minHeight = 0.25, -- parts shorter than this are left bare
		low = 0.9, -- parts shorter than this (hatches, kerbs) are washed to 90% of their height
		-- station model kinds (their names, without the _n suffix) that get bands
		kinds = {
			"Container",
			"DecorCrates",
			"Barrels",
			"Churns",
			"Bench",
			"Lamp",
			"Planter",
			"Cart",
			"Trolley",
			"Wheelbarrow",
			"FireBuckets",
			"Timetable",
			"Sign",
			"Pump",
			"Well",
			"PillarBox",
			"PlatformEnd",
			"MineCart",
			"Stall",
			-- tree trunks by the yard, lime-washed as orchards' were
			"Pine",
			"Oak",
			"Poplar",
			"DeadTree",
		},
	},

	-- the docked train's platform side: a pale lining along the foot of the body (where the
	-- footboard meets the platform) and at the waist, and the brass polished
	Train = {
		lining = { 226, 218, 194 },
		foot = 0.4, -- studs: the lining band along the bottom of each lower panel
		waist = 0.18, -- studs: the waist line along the top of each lower panel
		thickness = 0.05,
		brassFrom = { 150, 120, 74 },
		brass = { 214, 176, 98 },
	},

	-- grime per station grade (Tuning.Visibility.Grades): mood only, a shade on the pale
	-- colours; the spec holds the dirtiest above MinPale
	Grime = {
		Default = 0.03,
		Halt = 0,
		CoalYard = 0.06,
		SignalWorks = 0.04,
		Market = 0.03,
		Viaduct = 0.02,
		Minehead = 0.05,
		Schoolhouse = 0.02,
		Infirmary = 0,
		RailwayHotel = 0.03,
		PostTown = 0.03,
		EmergencyVillage = 0.05,
		Terminus = 0.02,
	},
}

return Surfaces
