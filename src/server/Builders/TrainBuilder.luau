--!strict
--[[
	Builds the train from primitives around an origin CFrame:
	x runs along the track (+X is the locomotive's front), y = 0 is floor level,
	z = 0 is the track centreline, +Z faces the station platform.

	Consist (back to front):
	  Brake van   x -96..-66  rear platform, signal mast, stove
	  Crew car    x -63..-23  route table, benches
	  Workshop    x -20..20   workbench (upgrades)
	  Tender      x  23..49   coal bunker whose heap tracks the coal level
	  Locomotive  x  52..96   cab x 52..64, boiler, smokebox, driving wheels

	Parts that take the livery carry a Livery attribute (Body, Trim, Roof, Accent, Lamp).
	Parts the client animates carry WheelRadius, CrankRadius or DoorSlide attributes.

	Inside, the carriages are lined with parts that never take the livery: a mahogany
	wainscot with a raised field under every window, deep green lincrusta upper walls,
	mahogany window and door frames, curtains and brass luggage racks. The ceiling is
	open down the middle into the clerestory, so its amber lights show from inside,
	with gasoliers hanging from the clerestory roof on long rods whose lights cast shadows.

	Outside, the varnished body is panelled by gilt beading, and the carriages ride on
	bogies with Mansell wheels (teak centres in iron tyres) on leaf springs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

local TrainInterior = require(script.Parent.TrainInterior)

local TrainBuilder = {}

local WIDTH = 13
local HALF = WIDTH / 2
local WALL_T = 0.5
local WALL_H = 9
local WINDOW_BOTTOM = 3.4
local WINDOW_TOP = 7.0
local DOOR_H = 7 -- gangway doors (and the cab's)
local SIDE_DOOR_W = 5.6 -- the carriages' sliding double doors
local SIDE_DOOR_H = 7.5
local WALL_IN = HALF - WALL_T -- inner face of the side walls
local LINE_T = 0.12 -- lining thickness
local LINE_IN = WALL_IN - LINE_T -- inner face of the side linings
local CEIL_BOTTOM = WALL_H - 0.12 -- underside of the ceiling lining
local FRAME_W = 0.22 -- door frame (architrave) width
local RAIL_EDGE = LINE_IN - 0.3 -- end-wall chair rails stop where the side walls' rails begin
local RUNNER_W = 2.8 -- the aisle's carpet runner
local OPEN = 1.9 -- half-width of the ceiling's opening into the clerestory
local MONITOR_T = 0.3 -- the clerestory's wall thickness
local CLERESTORY_LOW = 10.2 -- the clerestory lights' sill and head
local CLERESTORY_HIGH = 10.8
local MONITOR_TOP = 11.1 -- top of the clerestory's walls (underside of its capping)

local C = {
	floor = Color3.fromRGB(104, 78, 54),
	frame = Color3.fromRGB(34, 32, 32),
	wheel = Color3.fromRGB(40, 36, 36),
	driver = Color3.fromRGB(132, 34, 28), -- 1800s red driving wheels
	russia = Color3.fromRGB(74, 88, 98), -- planished "Russia iron" boiler jacket
	sash = Color3.fromRGB(58, 34, 22), -- dark varnished window sashes
	frameWood = Color3.fromRGB(64, 38, 24), -- window and door architraves inside
	clerestory = Color3.fromRGB(214, 168, 96), -- amber clerestory lights
	glass = Color3.fromRGB(176, 196, 206),
	interior = Color3.fromRGB(142, 108, 72),
	brass = Color3.fromRGB(150, 120, 74), -- aged, not polished
	iron = Color3.fromRGB(58, 58, 62),
	warm = Color3.fromRGB(255, 206, 150),
	interiorWarm = Color3.fromRGB(255, 190, 120),
	fire = Color3.fromRGB(255, 120, 40),
	bellows = Color3.fromRGB(30, 28, 28),
	coal = Color3.fromRGB(28, 27, 26),
	seat = Color3.fromRGB(120, 40, 36),
	wainscot = Color3.fromRGB(74, 46, 30),
	rail = Color3.fromRGB(96, 64, 40),
	lincrusta = Color3.fromRGB(46, 70, 62), -- embossed wall covering above the wainscot
	ceiling = Color3.fromRGB(78, 90, 84), -- lamp-smoked green-grey
	field = Color3.fromRGB(92, 56, 34), -- the wainscot's raised panels, a shade lighter
	rib = Color3.fromRGB(88, 60, 38),
	curtain = Color3.fromRGB(104, 30, 32),
	carpet = Color3.fromRGB(92, 24, 30),
	carpetEdge = Color3.fromRGB(150, 116, 58),
	teak = Color3.fromRGB(78, 52, 32), -- Mansell wheel centres
	globe = Color3.fromRGB(255, 226, 176),
	interiorGlobe = Color3.fromRGB(255, 214, 150),
}

-- How a carriage is lined inside: curtains in the passenger cars, the runner from the workshop back.
type Lining = { curtains: boolean, carpet: boolean, bareSide: number? } -- bareSide: a wall left without a rack

export type Built = {
	model: Model,
	carVolume: { cframe: CFrame, size: Vector3 },
	cabVolume: { cframe: CFrame, size: Vector3 },
	spawnPoints: { CFrame },
	breachAnchors: { BasePart },
	doorBlockers: { BasePart },
	workbench: BasePart,
	mast: BasePart,
	mastLamp: BasePart,
	seats: { Seat },
	cabins: { Cabin },
}

-- A carriage with a side door: its floor (centre at floor level, size across the inner walls) and door.
export type Cabin = { floor: CFrame, size: Vector3, door: CFrame }

type Span = { number }

-- [a, b] minus every gap, as a list of {from, to} spans.
local function subtract(a: number, b: number, gaps: { Span }): { Span }
	local spans: { Span } = { { a, b } }
	for _, gap in gaps do
		local nextSpans: { Span } = {}
		for _, span in spans do
			if gap[2] <= span[1] or gap[1] >= span[2] then
				table.insert(nextSpans, span)
			else
				if gap[1] > span[1] then
					table.insert(nextSpans, { span[1], gap[1] })
				end
				if gap[2] < span[2] then
					table.insert(nextSpans, { gap[2], span[2] })
				end
			end
		end
		spans = nextSpans
	end
	return spans
end

local function tag(part: BasePart, role: string): BasePart
	part:SetAttribute("Livery", role)
	return part
end

function TrainBuilder.build(origin: CFrame, parent: Instance?): Built
	local model = Kit.model("Train")
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- varnished mahogany lined in gilt, a tarred roof and deep green doors (the default livery repaints these)
	local body = Color3.fromRGB(60, 33, 28)
	local trim = C.brass
	local roof = Color3.fromRGB(34, 33, 34)
	local accent = Color3.fromRGB(38, 70, 58) -- deep green doors, light enough to find from the platform
	-- painted and varnished: smooth with a faint sheen (wood grain at this scale reads as noise)
	local varnish = { material = Enum.Material.SmoothPlastic, reflectance = 0.04 }

	local doorBlockers: { BasePart } = {}
	local breachAnchors: { BasePart } = {}
	local cabins: { Cabin } = {}

	--[[
		A carriage bogie: a bolster across the middle, a deep side frame outside the wheels
		each side (it hides the journals) and Mansell wheels (teak centres in an iron tyre).
		Only the tyre spins (WheelRadius); the centre is round. The bogie sits below the
		platform edge, so it is kept to its silhouette: no axle boxes, hub bosses or springs,
		no shadows and no collision.
	]]
	local function bogie(x: number)
		local metal = { material = Enum.Material.Metal, collide = false, shadow = false }
		Kit.block(model, Vector3.new(2.4, 1.2, 9.6), at(x, -3, 0), C.frame, metal)
		for _, side in { -1, 1 } do
			Kit.block(model, Vector3.new(7.2, 0.9, 0.3), at(x, -3.3, side * 6.15), C.frame, metal)
		end
		for _, ax in { -2.1, 2.1 } do
			for _, side in { -1, 1 } do
				local wheel = Kit.cylinder(
					model,
					0.6,
					3.2,
					at(x + ax, -3.6, side * 5.3) * Kit.angles(0, 90, 0),
					C.wheel,
					metal
				)
				wheel:SetAttribute("WheelRadius", 1.6)
				Kit.cylinder(
					model,
					0.7,
					2.5,
					at(x + ax, -3.6, side * 5.3) * Kit.angles(0, 90, 0),
					C.teak,
					{ material = Enum.Material.Wood, collide = false, shadow = false }
				)
			end
		end
	end

	local function buffers(x: number, dir: number)
		for _, side in { -1, 1 } do
			Kit.cylinder(
				model,
				1.2,
				0.8,
				at(x + dir * 0.6, -1.4, side * 3.6),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
			Kit.cylinder(
				model,
				0.2,
				1.3,
				at(x + dir * 1.25, -1.4, side * 3.6),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
		end
	end

	local function trimPart(
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material,
		shadow: boolean?
	): BasePart
		return Kit.block(
			model,
			size,
			cframe,
			color,
			{ material = material, collide = false, shadow = shadow == true }
		)
	end

	-- A thin member between two points in train space (brackets, braces).
	local function strut(a: Vector3, b: Vector3, thickness: number, color: Color3)
		Kit.block(
			model,
			Vector3.new(thickness, thickness, (b - a).Magnitude),
			origin * Kit.between(a, b),
			color,
			{ material = Enum.Material.Metal, collide = false, shadow = false }
		)
	end

	--[[
		An 1800s window bay: two tall round-topped sashes either side of a centre mullion,
		with a sash bar under the top lights. The rounded corners are spandrels: a square
		turned 45 degrees on each top corner, its upper half buried in the wall above (and
		the outer ones' far halves in the piers), so three parts round off all four corners.
		They sit inside the wall's thickness, clear of its faces and the glass; the bar sits
		on the outer face.
	]]
	local function sashes(cx: number, z: number, sign: number)
		local band = WINDOW_TOP - WINDOW_BOTTOM
		local wood = { material = Enum.Material.Wood, collide = false, shadow = false }
		tag(
			Kit.block(
				model,
				Vector3.new(0.4, band, 0.3),
				at(cx, (WINDOW_TOP + WINDOW_BOTTOM) / 2, z),
				body,
				{ material = Enum.Material.Wood, collide = false }
			),
			"Body"
		)
		-- the inner pair meets over the mullion (0.4 wide + two 0.7 legs); the outer ones meet the piers
		for _, spec in { { cx, 0.9 }, { cx - 1.8, 0.7 }, { cx + 1.8, 0.7 } } do
			local half = spec[2]
			tag(
				Kit.block(
					model,
					Vector3.new(half * math.sqrt(2), half * math.sqrt(2), 0.26), -- a hair inside the mullion's faces
					at(spec[1], WINDOW_TOP, z) * Kit.angles(0, 0, 45),
					body,
					wood
				),
				"Body"
			)
		end
		Kit.block(
			model,
			Vector3.new(3.6, 0.12, 0.06),
			at(cx, WINDOW_TOP - 1.2, sign * (HALF + 0.03)),
			C.sash,
			wood
		)
	end

	--[[
		A side wall between the end walls (which own the corners), from x0 + endT0 to
		x1 - endT1. Linings sit on its inner face in their own thickness band, frames
		and curtains in front of them, so no two visible faces ever share a plane.
	]]
	local function sideWall(
		x0: number,
		x1: number,
		sign: number,
		doors: { number },
		doorWidth: number,
		lining: Lining?,
		endT0: number,
		endT1: number,
		doorHeight: number,
		packed: boolean
	)
		local z = sign * (HALF - WALL_T / 2)
		local outer = sign * (HALF + 0.04)
		local xa, xb = x0 + endT0, x1 - endT1
		local gaps: { Span } = {}
		for _, dx in doors do
			table.insert(gaps, { dx - doorWidth / 2, dx + doorWidth / 2 })
		end
		-- doors taller than the window band cut into the upper panel up to their head
		local headTop = if #doors > 0 then math.max(WINDOW_TOP, doorHeight) else WINDOW_TOP
		-- lower panels and their brass bands
		for _, span in subtract(xa, xb, gaps) do
			local len = span[2] - span[1]
			local cx = (span[1] + span[2]) / 2
			tag(
				Kit.block(
					model,
					Vector3.new(len, WINDOW_BOTTOM, WALL_T),
					at(cx, WINDOW_BOTTOM / 2, z),
					body,
					varnish
				),
				"Body"
			)
		end
		for _, span in subtract(x0, x1, gaps) do
			local len = span[2] - span[1]
			local cx = (span[1] + span[2]) / 2
			for _, y in { WINDOW_BOTTOM, 0.9 } do
				tag(
					Kit.block(
						model,
						Vector3.new(len, 0.28, 0.08),
						at(cx, y, outer),
						trim,
						{ material = Enum.Material.Metal, collide = false }
					),
					"Trim"
				)
			end
		end
		-- upper panel runs over the doors (beside them up to their head when they stand taller)
		tag(
			Kit.block(
				model,
				Vector3.new(xb - xa, WALL_H - headTop, WALL_T),
				at((xa + xb) / 2, (WALL_H + headTop) / 2, z),
				body,
				varnish
			),
			"Body"
		)
		if headTop > WINDOW_TOP then
			for _, span in subtract(xa, xb, gaps) do
				tag(
					Kit.block(
						model,
						Vector3.new(span[2] - span[1], headTop - WINDOW_TOP, WALL_T),
						at((span[1] + span[2]) / 2, (headTop + WINDOW_TOP) / 2, z),
						body,
						varnish
					),
					"Body"
				)
			end
		end
		for _, span in subtract(x0, x1, if headTop > WINDOW_TOP then gaps else {}) do
			tag(
				Kit.block(
					model,
					Vector3.new(span[2] - span[1], 0.28, 0.08),
					at((span[1] + span[2]) / 2, WINDOW_TOP, outer),
					trim,
					{ material = Enum.Material.Metal, collide = false }
				),
				"Trim"
			)
		end
		-- window band: glass panes with piers between
		local windows: { Span } = {}
		local pitch = 5.2
		local centres: { number } = {}
		if packed then
			-- as many windows as fit in each run of wall between the ends and the doors, centred in it
			local clear: { Span } = {}
			for _, gap in gaps do
				table.insert(clear, { gap[1] - 1.15, gap[2] + 1.15 })
			end
			for _, span in subtract(x0 + 1.2, x1 - 1.2, clear) do
				local len = span[2] - span[1]
				if len >= 3.6 then
					local n = math.floor((len - 3.6) / pitch) + 1
					local first = (span[1] + span[2]) / 2 - (n - 1) * pitch / 2
					for i = 0, n - 1 do
						table.insert(centres, first + i * pitch)
					end
				end
			end
		else
			local count = math.floor((x1 - x0 - 3) / pitch)
			local start = (x0 + x1) / 2 - (count - 1) * pitch / 2
			for i = 0, count - 1 do
				table.insert(centres, start + i * pitch)
			end
		end
		for _, cx in centres do
			local blocked = false
			for _, gap in gaps do
				if cx + 2.95 > gap[1] and cx - 2.95 < gap[2] then
					blocked = true
				end
			end
			if not blocked then
				table.insert(windows, { cx - 1.8, cx + 1.8 })
				Kit.block(
					model,
					Vector3.new(3.6, WINDOW_TOP - WINDOW_BOTTOM, 0.15),
					at(cx, (WINDOW_TOP + WINDOW_BOTTOM) / 2, z),
					C.glass,
					{
						material = Enum.Material.Glass,
						transparency = 0.55,
						shadow = false,
					}
				)
				sashes(cx, z, sign)
			end
		end
		-- gilt beading divides the lower body into a panel under each window
		local beads: { [number]: boolean } = {}
		for _, w in windows do
			for _, bx in { w[1] - 0.8, w[2] + 0.8 } do
				local key = math.floor(bx * 10 + 0.5)
				local clearOfDoors = true
				for _, gap in gaps do
					if bx > gap[1] - 0.3 and bx < gap[2] + 0.3 then
						clearOfDoors = false
					end
				end
				-- neighbours 5.2 apart share a pier: one bead at its middle
				if clearOfDoors and not beads[key] and not beads[key - 1] and not beads[key + 1] then
					beads[key] = true
					tag(
						Kit.block(
							model,
							Vector3.new(0.14, WINDOW_BOTTOM - 0.9 - 0.28, 0.06),
							at(bx, (WINDOW_BOTTOM + 0.9) / 2, sign * (HALF + 0.03)),
							trim,
							{ material = Enum.Material.Metal, collide = false, shadow = false }
						),
						"Trim"
					)
				end
			end
		end
		local solid = table.clone(gaps)
		for _, w in windows do
			table.insert(solid, w)
		end
		for _, span in subtract(xa, xb, solid) do
			local len = span[2] - span[1]
			if len > 0.05 then
				tag(
					Kit.block(
						model,
						Vector3.new(len, WINDOW_TOP - WINDOW_BOTTOM, WALL_T),
						at((span[1] + span[2]) / 2, (WINDOW_TOP + WINDOW_BOTTOM) / 2, z),
						body,
						varnish
					),
					"Body"
				)
			end
		end
		-- doors: sliding panels (client-animated) and a collision blocker (server-toggled)
		for _, dx in doors do
			local blocker = Kit.block(
				model,
				Vector3.new(doorWidth, doorHeight, 0.6),
				at(dx, doorHeight / 2, z),
				Color3.new(),
				{ transparency = 1, shadow = false }
			)
			blocker.Name = "DoorBlocker"
			blocker.CanQuery = false
			table.insert(doorBlockers, blocker)
			for _, dir in { -1, 1 } do
				local slide = dir * (doorWidth / 2 + 0.05)
				local panel = Kit.block(
					model,
					Vector3.new(doorWidth / 2, doorHeight, 0.25),
					at(dx + dir * doorWidth / 4, doorHeight / 2, sign * (HALF + 0.24)),
					accent,
					{ collide = false, material = Enum.Material.WoodPlanks }
				)
				panel.Name = "DoorPanel"
				panel:SetAttribute("DoorSlide", slide)
				tag(panel, "Accent")
				local pane = Kit.block(
					model,
					Vector3.new(0.7, 2.2, 0.08),
					panel.CFrame * CFrame.new(0, 1.2, sign * 0.14),
					C.glass,
					{ material = Enum.Material.Glass, transparency = 0.4, collide = false }
				)
				pane.Name = "DoorPanel"
				pane:SetAttribute("DoorSlide", slide)
			end
		end

		if lining == nil then
			return
		end
		local zLining = sign * (WALL_IN - LINE_T / 2)
		local function inward(depth: number): number
			return sign * (LINE_IN - depth / 2)
		end
		-- the lining stops short of each door so the brass door frame can close it off
		local liningGaps: { Span } = {}
		for _, gap in gaps do
			table.insert(liningGaps, { gap[1] - FRAME_W, gap[2] + FRAME_W })
		end
		-- wainscot, chair rail and skirting below the windows
		for _, span in subtract(xa, xb, liningGaps) do
			local len = span[2] - span[1]
			local cx = (span[1] + span[2]) / 2
			if len > 0.05 then
				trimPart(
					Vector3.new(len, WINDOW_BOTTOM, LINE_T),
					at(cx, WINDOW_BOTTOM / 2, zLining),
					C.wainscot,
					Enum.Material.Wood
				)
				trimPart(
					Vector3.new(len, 0.25, 0.3),
					at(cx, WINDOW_BOTTOM - 0.18, inward(0.3)),
					C.rail,
					Enum.Material.Wood
				)
				trimPart(Vector3.new(len, 0.24, 0.18), at(cx, 0.12, inward(0.18)), C.rail, Enum.Material.Wood)
			end
		end
		-- lincrusta upper wall over the windows and doors (beside a tall door's head), and on the piers between windows
		local liningTop = if headTop > WINDOW_TOP then doorHeight + 0.22 else WINDOW_TOP
		trimPart(
			Vector3.new(xb - xa, CEIL_BOTTOM - liningTop, LINE_T),
			at((xa + xb) / 2, (CEIL_BOTTOM + liningTop) / 2, zLining),
			C.lincrusta,
			Enum.Material.Fabric
		)
		if liningTop > WINDOW_TOP then
			for _, span in subtract(xa, xb, liningGaps) do
				if span[2] - span[1] > 0.05 then
					trimPart(
						Vector3.new(span[2] - span[1], liningTop - WINDOW_TOP, LINE_T),
						at((span[1] + span[2]) / 2, (liningTop + WINDOW_TOP) / 2, zLining),
						C.lincrusta,
						Enum.Material.Fabric
					)
				end
			end
		end
		local liningSolid = table.clone(liningGaps)
		for _, w in windows do
			table.insert(liningSolid, w)
		end
		for _, span in subtract(xa, xb, liningSolid) do
			local len = span[2] - span[1]
			if len > 0.05 then
				trimPart(
					Vector3.new(len, WINDOW_TOP - WINDOW_BOTTOM, LINE_T),
					at((span[1] + span[2]) / 2, (WINDOW_TOP + WINDOW_BOTTOM) / 2, zLining),
					C.lincrusta,
					Enum.Material.Fabric
				)
			end
		end
		-- a raised field on the wainscot under each window, between skirting and chair rail
		for _, w in windows do
			trimPart(
				Vector3.new(3.2, 2.3, 0.06),
				at((w[1] + w[2]) / 2, 1.72, inward(0.06)),
				C.field,
				Enum.Material.Wood
			)
		end
		-- mahogany window frames, and curtains tied back on either side under a valance
		local band = WINDOW_TOP - WINDOW_BOTTOM
		local mid = (WINDOW_TOP + WINDOW_BOTTOM) / 2
		for _, w in windows do
			local cx = (w[1] + w[2]) / 2
			trimPart(
				Vector3.new(4.0, 0.22, 0.4),
				at(cx, WINDOW_BOTTOM + 0.11, inward(0.4)),
				C.frameWood,
				Enum.Material.Wood
			)
			-- the head (in curtained cars the valance comes down over it instead)
			if not lining.curtains then
				trimPart(
					Vector3.new(4.0, 0.22, 0.25),
					at(cx, WINDOW_TOP - 0.11, inward(0.25)),
					C.frameWood,
					Enum.Material.Wood
				)
			end
			for _, dx in { -1.85, 1.85 } do
				trimPart(
					Vector3.new(0.2, band - 0.44, 0.25),
					at(cx + dx, mid, inward(0.25)),
					C.frameWood,
					Enum.Material.Wood
				)
			end
			if lining.curtains then
				for _, dx in { -2.3, 2.3 } do
					trimPart(
						Vector3.new(0.55, band - 0.3, 0.22),
						at(cx + dx, mid + 0.05, inward(0.22)),
						C.curtain,
						Enum.Material.Fabric
					)
				end
				trimPart(
					Vector3.new(5.2, 0.72, 0.3),
					at(cx, WINDOW_TOP + 0.14, inward(0.3)),
					C.curtain,
					Enum.Material.Fabric
				)
			end
		end
		-- mahogany door frames: posts and a head that close off the lining around each door
		for _, dx in doors do
			for _, side in { -1, 1 } do
				trimPart(
					Vector3.new(FRAME_W, doorHeight, 0.42),
					at(dx + side * (doorWidth / 2 + FRAME_W / 2), doorHeight / 2, sign * (WALL_IN - 0.21)),
					C.frameWood,
					Enum.Material.Wood
				)
			end
			trimPart(
				Vector3.new(doorWidth + 2 * FRAME_W, 0.24, 0.42),
				at(dx, doorHeight + 0.1, sign * (WALL_IN - 0.21)),
				C.frameWood,
				Enum.Material.Wood
			)
		end
	end

	--[[
		An end wall spanning the full width (it owns the corners). `inward` (+1 for the
		rear wall of a car, -1 for the front) lines its inside face; with a gangway the
		lining frames the connecting door.
	]]
	local function endWall(x: number, gangway: boolean, inward: number?)
		if gangway then
			for _, side in { -1, 1 } do
				tag(
					Kit.block(
						model,
						Vector3.new(WALL_T, WALL_H, HALF - 2),
						at(x, WALL_H / 2, side * (HALF + 2) / 2),
						body,
						varnish
					),
					"Body"
				)
			end
			tag(
				Kit.block(
					model,
					Vector3.new(WALL_T, WALL_H - DOOR_H, 4),
					at(x, (WALL_H + DOOR_H) / 2, 0),
					body,
					varnish
				),
				"Body"
			)
		else
			tag(
				Kit.block(model, Vector3.new(WALL_T, WALL_H, WIDTH), at(x, WALL_H / 2, 0), body, varnish),
				"Body"
			)
		end
		if inward == nil then
			return
		end
		local face = x + inward * (WALL_T / 2 + LINE_T / 2)
		local function out(depth: number): number
			return x + inward * (WALL_T / 2 + LINE_T + depth / 2)
		end
		-- z spans of lining: beside the gangway door, or the whole wall between the side linings
		local spans: { Span } = if gangway
			then { { -LINE_IN, -(2 + FRAME_W) }, { 2 + FRAME_W, LINE_IN } }
			else { { -LINE_IN, LINE_IN } }
		for _, span in spans do
			local width = span[2] - span[1]
			local cz = (span[1] + span[2]) / 2
			trimPart(
				Vector3.new(LINE_T, WINDOW_BOTTOM, width),
				at(face, WINDOW_BOTTOM / 2, cz),
				C.wainscot,
				Enum.Material.Wood
			)
			trimPart(
				Vector3.new(LINE_T, CEIL_BOTTOM - WINDOW_BOTTOM, width),
				at(face, (CEIL_BOTTOM + WINDOW_BOTTOM) / 2, cz),
				C.lincrusta,
				Enum.Material.Fabric
			)
			-- chair rail, stopping where the side walls' own rails take over
			local r0, r1 = math.max(span[1], -RAIL_EDGE), math.min(span[2], RAIL_EDGE)
			if r1 - r0 > 0.05 then
				trimPart(
					Vector3.new(0.3, 0.25, r1 - r0),
					at(out(0.3), WINDOW_BOTTOM - 0.18, (r0 + r1) / 2),
					C.rail,
					Enum.Material.Wood
				)
			end
		end
		if gangway then
			trimPart(
				Vector3.new(LINE_T, CEIL_BOTTOM - DOOR_H - 0.22, 4 + 2 * FRAME_W),
				at(face, (CEIL_BOTTOM + DOOR_H + 0.22) / 2, 0),
				C.lincrusta,
				Enum.Material.Fabric
			)
			for _, side in { -1, 1 } do
				trimPart(
					Vector3.new(0.42, DOOR_H, FRAME_W),
					at(x + inward * (WALL_T / 2 + 0.21), DOOR_H / 2, side * (2 + FRAME_W / 2)),
					C.frameWood,
					Enum.Material.Wood
				)
			end
			trimPart(
				Vector3.new(0.42, 0.22, 4 + 2 * FRAME_W),
				at(x + inward * (WALL_T / 2 + 0.21), DOOR_H + 0.11, 0),
				C.frameWood,
				Enum.Material.Wood
			)
		end
	end

	local openings: { Span } = {} -- every ceiling opening's x span (all |z| < OPEN)

	-- Where a car's clerestory stands over its roof: the monitor's outer ends, and the opening
	-- under it (inside the monitor's end walls) that the ceiling leaves open.
	local function monitorSpan(x0: number, x1: number): (number, number, number, number)
		local cx = (x0 + x1) / 2
		local half = (x1 - x0 + 0.6 - 4.6) / 2
		return cx - half, cx + half, cx - half + MONITOR_T, cx + half - MONITOR_T
	end

	--[[
		The roof: a tarred deck either side of the clerestory, and the clerestory itself, a
		hollow monitor down the middle with a strip of amber lights each side between glazing
		bars, its end walls and a capping. The deck stops at the monitor's inner face, so the
		inside of the car looks up into it.
	]]
	local function roofOver(x0: number, x1: number)
		local len = x1 - x0 + 0.6
		local cx = (x0 + x1) / 2
		local ma, mb = monitorSpan(x0, x1)
		local metal = { material = Enum.Material.Metal }
		for _, side in { -1, 1 } do
			tag(
				Kit.block(
					model,
					Vector3.new(len, 0.5, 3.5 - OPEN),
					at(cx, WALL_H + 0.55, side * (3.5 + OPEN) / 2),
					roof,
					metal
				),
				"Roof"
			)
		end
		-- the deck under the monitor's ends, between the side decks
		for _, span in { { cx - len / 2, ma + MONITOR_T }, { mb - MONITOR_T, cx + len / 2 } } do
			tag(
				Kit.block(
					model,
					Vector3.new(span[2] - span[1], 0.5, 2 * OPEN),
					at((span[1] + span[2]) / 2, WALL_H + 0.55, 0),
					roof,
					metal
				),
				"Roof"
			)
		end
		for _, side in { -1, 1 } do
			tag(
				Kit.block(
					model,
					Vector3.new(len, 0.5, 3.8),
					at(cx, WALL_H + 0.2, side * 4.9) * Kit.angles(side * -12, 0, 0),
					roof,
					metal
				),
				"Roof"
			)
		end
		-- the monitor: side walls below and above the lights, glazing bars between, end walls, capping
		local base = WALL_H + 0.8
		local monitor = mb - ma
		local wallZ = OPEN + MONITOR_T / 2
		for _, side in { -1, 1 } do
			for _, band in { { base, CLERESTORY_LOW }, { CLERESTORY_HIGH, MONITOR_TOP } } do
				tag(
					Kit.block(
						model,
						Vector3.new(monitor - 2 * MONITOR_T, band[2] - band[1], MONITOR_T),
						at(cx, (band[1] + band[2]) / 2, side * wallZ),
						body,
						varnish
					),
					"Body"
				)
			end
			local lights = CLERESTORY_HIGH - CLERESTORY_LOW
			Kit.block(
				model,
				Vector3.new(monitor - 2 * MONITOR_T, lights, 0.1),
				at(cx, (CLERESTORY_LOW + CLERESTORY_HIGH) / 2, side * wallZ),
				C.clerestory,
				{ material = Enum.Material.Glass, collide = false, shadow = false }
			)
			-- glazing bars about 4.8 apart, evenly spread between the end walls
			local b0, b1 = ma + MONITOR_T + 0.1, mb - MONITOR_T - 0.1
			local gaps = math.max(1, math.floor((b1 - b0) / 4.8 + 0.5))
			for i = 0, gaps do
				local x = b0 + (b1 - b0) * i / gaps
				Kit.block(
					model,
					Vector3.new(0.2, lights, MONITOR_T),
					at(x, (CLERESTORY_LOW + CLERESTORY_HIGH) / 2, side * wallZ),
					C.sash,
					{ material = Enum.Material.Wood, collide = false, shadow = false }
				)
			end
		end
		for _, x in { ma + MONITOR_T / 2, mb - MONITOR_T / 2 } do
			tag(
				Kit.block(
					model,
					Vector3.new(MONITOR_T, MONITOR_TOP - base, 2 * (OPEN + MONITOR_T)),
					at(x, (MONITOR_TOP + base) / 2, 0),
					body,
					varnish
				),
				"Body"
			)
		end
		tag(
			Kit.block(model, Vector3.new(monitor + 1.2, 0.3, 5.4), at(cx, MONITOR_TOP + 0.15, 0), roof, metal),
			"Roof"
		)
	end

	--[[
		The ceiling: plaster on wooden carlines and a cornice each side, open down the middle
		into the clerestory, whose inside is plastered too and edged with a cove at the
		opening. Gasoliers hang on long rods from the clerestory roof; their lights cast shadows.
	]]
	local function ceiling(x0: number, x1: number)
		local xa, xb = x0 + WALL_T, x1 - WALL_T
		local len = xb - xa
		local cx = (xa + xb) / 2
		local _, _, oa, ob = monitorSpan(x0, x1)
		table.insert(openings, { oa, ob })
		local open = ob - oa
		local plaster = Enum.Material.Plaster
		for _, side in { -1, 1 } do
			trimPart(
				Vector3.new(len, 0.12, WALL_IN - OPEN),
				at(cx, CEIL_BOTTOM + 0.06, side * (WALL_IN + OPEN) / 2),
				C.ceiling,
				plaster
			)
			trimPart(
				Vector3.new(len, 0.32, 0.32),
				at(cx, CEIL_BOTTOM - 0.16, side * (LINE_IN - 0.16)),
				C.rib,
				Enum.Material.Wood
			)
			-- the clerestory's plastered sides below and above its lights, and the cove at the opening
			trimPart(
				Vector3.new(open, CLERESTORY_LOW - CEIL_BOTTOM, 0.1),
				at(cx, (CLERESTORY_LOW + CEIL_BOTTOM) / 2, side * (OPEN - 0.05)),
				C.ceiling,
				plaster
			)
			trimPart(
				Vector3.new(open, MONITOR_TOP - CLERESTORY_HIGH, 0.1),
				at(cx, (MONITOR_TOP + CLERESTORY_HIGH) / 2, side * (OPEN - 0.05)),
				C.ceiling,
				plaster
			)
			trimPart(
				Vector3.new(open, 0.18, 0.2),
				at(cx, CEIL_BOTTOM - 0.09, side * (OPEN + 0.1)),
				C.rib,
				Enum.Material.Wood
			)
		end
		-- plaster across the middle beyond the opening, the clerestory's end linings and its roof
		for _, span in { { xa, oa }, { ob, xb } } do
			trimPart(
				Vector3.new(span[2] - span[1], 0.12, 2 * OPEN),
				at((span[1] + span[2]) / 2, CEIL_BOTTOM + 0.06, 0),
				C.ceiling,
				plaster
			)
		end
		for _, x in { oa + 0.05, ob - 0.05 } do
			trimPart(
				Vector3.new(0.1, MONITOR_TOP - 0.1 - CEIL_BOTTOM, 2 * OPEN - 0.2),
				at(x, (MONITOR_TOP - 0.1 + CEIL_BOTTOM) / 2, 0),
				C.ceiling,
				plaster
			)
		end
		trimPart(
			Vector3.new(open - 0.2, 0.1, 2 * OPEN - 0.2),
			at(cx, MONITOR_TOP - 0.05, 0),
			C.ceiling,
			plaster
		)
		local count = math.max(1, math.floor((x1 - x0) / 12))
		local lamps: { number } = {}
		for i = 1, count do
			table.insert(lamps, x0 + (x1 - x0) * (i - 0.5) / count)
		end
		for x = xa + 2, xb - 2, 4 do
			local clear = true
			for _, lx in lamps do
				if math.abs(lx - x) < 1.3 then
					clear = false
				end
			end
			if clear then
				trimPart(
					Vector3.new(0.3, 0.2, 2 * (LINE_IN - 0.4)),
					at(x, CEIL_BOTTOM - 0.1, 0),
					C.rib,
					Enum.Material.Wood
				)
			end
		end
		local brass = { material = Enum.Material.Metal, collide = false, shadow = false }
		local roofIn = MONITOR_TOP - 0.1 -- underside of the clerestory roof lining
		for _, x in lamps do
			-- a rose on the clerestory roof, a long rod, a gallery and the globe
			Kit.cylinder(model, 0.12, 0.9, at(x, roofIn - 0.06, 0) * Kit.angles(0, 0, 90), C.brass, brass)
			local rodTop, rodBottom = roofIn - 0.12, CEIL_BOTTOM - 0.62
			Kit.cylinder(
				model,
				rodTop - rodBottom,
				0.12,
				at(x, (rodTop + rodBottom) / 2, 0) * Kit.angles(0, 0, 90),
				C.brass,
				brass
			)
			Kit.cylinder(model, 0.2, 0.8, at(x, CEIL_BOTTOM - 0.72, 0) * Kit.angles(0, 0, 90), C.brass, brass)
			local globe = Kit.neon(
				model,
				Vector3.new(1.1, 1.1, 1.1),
				at(x, CEIL_BOTTOM - 1.2, 0),
				C.interiorGlobe,
				Enum.PartType.Ball
			)
			globe.Transparency = 0.1
			Kit.pointLight(globe, C.interiorWarm, 1.15, 18, true)
		end
	end

	-- Brass luggage racks above the windows on both sides, on brackets from the wall.
	local function racks(x0: number, x1: number, bareSide: number?)
		local len = x1 - x0 - 2.4
		local cx = (x0 + x1) / 2
		for _, side in { -1, 1 } do
			if side == bareSide then
				continue
			end
			for _, depth in { 0.5, 1.45 } do
				trimPart(
					Vector3.new(len, 0.12, 0.12),
					at(cx, 7.75, side * (LINE_IN - depth)),
					C.brass,
					Enum.Material.Metal,
					true
				)
			end
			local net = trimPart(
				Vector3.new(len, 0.06, 0.83),
				at(cx, 7.75, side * (LINE_IN - 0.975)),
				C.bellows,
				Enum.Material.Fabric,
				true
			)
			net.Transparency = 0.35
			for x = x0 + 2, x1 - 2, 6 do
				strut(
					Vector3.new(x, 8.3, side * (LINE_IN - 0.06)),
					Vector3.new(x, 7.81, side * (LINE_IN - 1.45)),
					0.1,
					C.brass
				)
			end
		end
	end

	local function car(
		x0: number,
		x1: number,
		doors: { number },
		frontGangway: boolean,
		rearGangway: boolean,
		lining: Lining
	)
		local len = x1 - x0
		local cx = (x0 + x1) / 2
		Kit.block(
			model,
			Vector3.new(len, 1, WIDTH),
			at(cx, -0.5, 0),
			C.floor,
			{ material = Enum.Material.WoodPlanks }
		)
		Kit.block(
			model,
			Vector3.new(len - 1, 1.4, WIDTH - 2.4),
			at(cx, -1.7, 0),
			C.frame,
			{ material = Enum.Material.Metal }
		)
		-- bogies nearer the ends of a short car, so the two stay clear of each other
		local inset = if len >= 24 then 6.5 else 4.5
		bogie(x0 + inset)
		bogie(x1 - inset)
		-- queen-post truss rods under the floor, as on wooden cars of the 1800s
		if len >= 34 then
			for _, side in { -1, 1 } do
				local zr = side * 3.6
				local a, b = x0 + 11, x0 + 15
				local c, d = x1 - 15, x1 - 11
				strut(Vector3.new(a, -2.3, zr), Vector3.new(b, -3.5, zr), 0.16, C.iron)
				strut(Vector3.new(b, -3.5, zr), Vector3.new(c, -3.5, zr), 0.16, C.iron)
				strut(Vector3.new(c, -3.5, zr), Vector3.new(d, -2.3, zr), 0.16, C.iron)
				for _, x in { b, c } do
					strut(Vector3.new(x, -2.4, zr), Vector3.new(x, -3.6, zr), 0.24, C.iron)
				end
			end
		end
		sideWall(x0, x1, 1, doors, SIDE_DOOR_W, lining, WALL_T, WALL_T, SIDE_DOOR_H, true)
		if #doors > 0 then
			table.insert(cabins, {
				floor = at(cx, 0, 0),
				size = Vector3.new(len - 2 * WALL_T, 0, 2 * WALL_IN),
				door = at(doors[1], SIDE_DOOR_H / 2, HALF),
			})
		end
		sideWall(x0, x1, -1, {}, SIDE_DOOR_W, lining, WALL_T, WALL_T, SIDE_DOOR_H, true)
		endWall(x0 + WALL_T / 2, rearGangway, 1)
		endWall(x1 - WALL_T / 2, frontGangway, -1)
		roofOver(x0, x1)
		ceiling(x0, x1)
		racks(x0, x1, lining.bareSide)
		if lining.carpet then
			-- a red runner down the aisle, its gilt borders woven a hair proud of the pile. It is
			-- cut at each car's end, a step short of the door: bare boards at the thresholds and
			-- nothing on the gangways' diamond plate, as a carriage's own carpet would be.
			local runLen = len - 2 * WALL_T - 1.2
			trimPart(Vector3.new(runLen, 0.06, RUNNER_W), at(cx, 0.03, 0), C.carpet, Enum.Material.Fabric)
			for _, side in { -1, 1 } do
				trimPart(
					Vector3.new(runLen - 0.3, 0.065, 0.14),
					at(cx, 0.0325, side * (RUNNER_W / 2 - 0.22)),
					C.carpetEdge,
					Enum.Material.Fabric
				)
			end
		end
	end

	-- The covered gangway between two cars, flush with their ends.
	local function gangway(x0: number, x1: number)
		local cx = (x0 + x1) / 2
		local len = x1 - x0
		Kit.block(
			model,
			Vector3.new(len, 1, 4.4),
			at(cx, -0.52, 0),
			C.iron,
			{ material = Enum.Material.DiamondPlate }
		)
		for _, side in { -1, 1 } do
			Kit.block(
				model,
				Vector3.new(len, DOOR_H + 0.2, 0.4),
				at(cx, (DOOR_H + 0.2) / 2, side * 2.3),
				C.bellows,
				{ material = Enum.Material.Fabric }
			)
		end
		Kit.block(
			model,
			Vector3.new(len, 0.4, 5),
			at(cx, DOOR_H + 0.4, 0),
			C.bellows,
			{ material = Enum.Material.Fabric }
		)
	end

	local function breachAnchor(name: string, x: number, y: number, z: number)
		local part = Kit.block(
			model,
			Vector3.new(1.2, 1.2, 0.4),
			at(x, y, z),
			Color3.new(),
			{ transparency = 1, collide = false, shadow = false }
		)
		part.Name = `Breach_{name}`
		part:SetAttribute("BreachAnchor", name)
		table.insert(breachAnchors, part)
	end

	-- Brake van ------------------------------------------------------------------------
	car(-90, -66, { -78 }, true, true, { curtains = true, carpet = true })
	Kit.block(
		model,
		Vector3.new(6, 1, WIDTH),
		at(-93, -0.5, 0),
		C.floor,
		{ material = Enum.Material.WoodPlanks }
	)
	Kit.block(
		model,
		Vector3.new(6, 1.4, WIDTH - 2.4),
		at(-93, -1.7, 0),
		C.frame,
		{ material = Enum.Material.Metal }
	)
	tag(
		Kit.block(
			model,
			Vector3.new(7, 0.5, WIDTH + 0.8),
			at(-93, WALL_H + 0.61, 0),
			roof,
			{ material = Enum.Material.Metal }
		),
		"Roof"
	)
	for _, z in { -HALF + 0.3, HALF - 0.3 } do
		Kit.post(model, WALL_H, 0.35, at(-95.7, WALL_H / 2, z), C.iron, { material = Enum.Material.Metal })
	end
	-- railings on the far side and the tail; the platform side stays open for late boarders
	Kit.block(
		model,
		Vector3.new(0.2, 0.2, WIDTH - 0.6),
		at(-95.8, 3.2, 0),
		C.brass,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(0.16, 3.2, 0.16),
		at(-95.8, 1.6, 0),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(6, 0.2, 0.2),
		at(-93, 3.2, -HALF + 0.3),
		C.brass,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(0.4, 3.4, WIDTH),
		at(-96.1, 1.7, 0),
		C.iron,
		{ transparency = 1, shadow = false }
	)
	Kit.block(
		model,
		Vector3.new(6, 3.4, 0.4),
		at(-93, 1.7, -HALF - 0.1),
		C.iron,
		{ transparency = 1, shadow = false }
	)
	for _, z in { -5.6, 5.6 } do
		local marker =
			Kit.neon(model, Vector3.new(0.3, 0.8, 0.8), at(-96.2, 5.5, z), Color3.fromRGB(255, 50, 40))
		Kit.pointLight(marker, Color3.fromRGB(255, 60, 40), 0.8, 8, false)
	end
	-- signal mast: fire a flare here to bring the eliminated back
	Kit.post(model, 15, 0.5, at(-94, 7.5, -4.6), C.iron, { material = Enum.Material.Metal })
	Kit.block(
		model,
		Vector3.new(0.3, 0.3, 2.4),
		at(-94, 13.5, -4.6),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	local mastLamp = Kit.neon(
		model,
		Vector3.new(1.1, 1.1, 1.1),
		at(-94, 15.3, -4.6),
		Color3.fromRGB(120, 30, 26),
		Enum.PartType.Ball
	)
	mastLamp.Name = "MastLamp"
	mastLamp.Material = Enum.Material.Glass
	local mast = Kit.block(
		model,
		Vector3.new(2.4, 5, 2.4),
		at(-94, 2.5, -4.6),
		Color3.new(),
		{ transparency = 1, collide = false, shadow = false }
	)
	mast.Name = "SignalMast"
	breachAnchor("BV1", -84, 5.2, -5.6)
	breachAnchor("BV2", -72, 5.2, -5.6)
	gangway(-66, -63)

	-- Crew saloon, two cars: doors either side of the gangway between them ---------------
	car(-63, -44.5, { -49.75 }, true, true, { curtains = true, carpet = true })
	gangway(-44.5, -41.5)
	car(-41.5, -23, { -36.25 }, true, true, { curtains = true, carpet = true })
	breachAnchor("CR1", -55, 5.2, -5.6)
	breachAnchor("CR2", -31, 5.2, -5.6)
	gangway(-23, -20)

	-- Workshop, two cars: the bench in the first, stores in the second -----------------
	car(-20, -1.5, { -6.25 }, true, true, { curtains = false, carpet = true, bareSide = -1 })
	gangway(-1.5, 1.5)
	car(1.5, 20, { 6.25 }, false, true, { curtains = false, carpet = false })
	local BX = -6.8 -- the workbench's middle
	Kit.block(model, Vector3.new(9, 0.4, 3), at(BX, 3.0, -4.6), C.interior, { material = Enum.Material.Wood })
	for _, dx in { BX - 4, BX + 4 } do
		Kit.block(
			model,
			Vector3.new(0.4, 3, 2.6),
			at(dx, 1.5, -4.6),
			C.iron,
			{ material = Enum.Material.Metal }
		)
	end
	Kit.block(
		model,
		Vector3.new(1.2, 0.8, 0.8),
		at(BX - 2.8, 3.6, -4.4),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(9, 4, 0.2),
		at(BX, 5.6, -5.72),
		Color3.fromRGB(92, 70, 48),
		{ material = Enum.Material.WoodPlanks, collide = false }
	)
	for i, dx in { -3.4, -2, -0.6, 0.8, 2.2, 3.6 } do
		Kit.block(
			model,
			Vector3.new(0.25, 1.4 + (i % 3) * 0.4, 0.15),
			at(BX + dx, 5.6, -5.57),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	local workbench = Kit.block(
		model,
		Vector3.new(8, 4, 3),
		at(BX, 2.5, -4.2),
		Color3.new(),
		{ transparency = 1, collide = false, shadow = false }
	)
	workbench.Name = "Workbench"
	for _, x in { 13.5, 16.5 } do
		Kit.block(
			model,
			Vector3.new(2.6, 2.4, 2.6),
			at(x, 1.2, -4.4),
			Color3.fromRGB(124, 92, 60),
			{ material = Enum.Material.WoodPlanks }
		)
	end
	breachAnchor("WS1", -12, 5.2, -5.6)
	breachAnchor("WS2", 12, 5.2, -5.6)
	buffers(20, 1)

	-- Tender ----------------------------------------------------------------------------
	local tx0, tx1 = 23, 49
	local tcx = (tx0 + tx1) / 2
	Kit.block(
		model,
		Vector3.new(tx1 - tx0, 1, WIDTH),
		at(tcx, -0.5, 0),
		C.frame,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(tx1 - tx0 - 1, 1.4, WIDTH - 2.4),
		at(tcx, -1.7, 0),
		C.frame,
		{ material = Enum.Material.Metal }
	)
	bogie(tx0 + 6)
	bogie(tx1 - 6)
	for _, side in { -1, 1 } do
		tag(
			Kit.block(
				model,
				Vector3.new(tx1 - tx0 - 2 * WALL_T, 7, WALL_T),
				at(tcx, 3.5, side * (HALF - WALL_T / 2)),
				body
			),
			"Body"
		)
		tag(
			Kit.block(
				model,
				Vector3.new(tx1 - tx0, 0.28, 0.08),
				at(tcx, 5.6, side * (HALF + 0.06)),
				trim,
				{ material = Enum.Material.Metal, collide = false }
			),
			"Trim"
		)
		tag(
			Kit.block(
				model,
				Vector3.new(tx1 - tx0, 0.28, 0.08),
				at(tcx, 1.4, side * (HALF + 0.06)),
				trim,
				{ material = Enum.Material.Metal, collide = false }
			),
			"Trim"
		)
	end
	for _, x in { tx0 + WALL_T / 2, tx1 - WALL_T / 2 } do
		tag(Kit.block(model, Vector3.new(WALL_T, 7, WIDTH), at(x, 3.5, 0), body), "Body")
	end
	-- flared coal boards along the top, leaning out as on an 1800s tender
	for _, side in { -1, 1 } do
		tag(
			Kit.block(
				model,
				Vector3.new(tx1 - tx0 - 4, 1.2, 0.2),
				at(tcx, 7.5, side * (HALF + 0.05)) * Kit.angles(side * 20, 0, 0),
				body,
				varnish
			),
			"Body"
		)
	end
	Kit.block(
		model,
		Vector3.new(tx1 - tx0 - 1, 1, WIDTH - 1),
		at(tcx, 5.5, 0),
		C.coal,
		{ material = Enum.Material.Slate }
	)
	-- coal heap: tiers appear as the bunker fills (client reads CoalFill on the model)
	local heapRng = Random.new(31)
	for tier = 1, 16 do
		local fx = tx0 + 2.5 + heapRng:NextNumber() * (tx1 - tx0 - 5)
		local fz = (heapRng:NextNumber() - 0.5) * 8
		local size = 3 + heapRng:NextNumber() * 2.5
		local lump = Kit.ball(
			model,
			size,
			at(fx, 6.4 + tier * 0.12, fz),
			Kit.shade(C.coal, 0.9 + heapRng:NextNumber() * 0.3),
			{ material = Enum.Material.Slate, collide = false }
		)
		lump:SetAttribute("CoalTier", tier / 16)
	end
	Kit.cylinder(
		model,
		0.6,
		2.4,
		at(tx0 + 3, 7.1, -4) * Kit.angles(0, 0, 90),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	buffers(tx0, -1)
	buffers(tx1, 1)

	-- Locomotive -----------------------------------------------------------------------
	-- cab
	local cx0, cx1 = 52, 64
	Kit.block(
		model,
		Vector3.new(cx1 - cx0, 1, WIDTH),
		at((cx0 + cx1) / 2, -0.5, 0),
		C.floor,
		{ material = Enum.Material.WoodPlanks }
	)
	sideWall(cx0, cx1, 1, { 58 }, 4, nil, WALL_T, 0.6, DOOR_H, false)
	sideWall(cx0, cx1, -1, {}, 4, nil, WALL_T, 0.6, DOOR_H, false)
	endWall(cx0 + WALL_T / 2, false)
	tag(
		Kit.block(
			model,
			Vector3.new(cx1 - cx0 + 1.6, 0.5, WIDTH + 1),
			at((cx0 + cx1) / 2, WALL_H + 0.55, 0),
			roof,
			{ material = Enum.Material.Metal }
		),
		"Roof"
	)
	-- 1800s cab: a raised, overhanging roof cap with a little ventilator
	tag(
		Kit.block(
			model,
			Vector3.new(cx1 - cx0 + 1.2, 0.4, 8),
			at((cx0 + cx1) / 2, WALL_H + 0.95, 0),
			roof,
			{ material = Enum.Material.Metal }
		),
		"Roof"
	)
	tag(
		Kit.block(model, Vector3.new(3, 0.7, 2.4), at((cx0 + cx1) / 2, WALL_H + 1.4, 0), body, varnish),
		"Body"
	)
	-- backhead: firebox, gauges, regulator
	tag(Kit.block(model, Vector3.new(0.6, WALL_H, WIDTH), at(cx1 - 0.3, WALL_H / 2, 0), body), "Body")
	-- the furnace and the gauges on this wall are furnished by TrainInterior
	breachAnchor("CAB", 58, 5.2, -5.6)

	-- running gear and frame
	Kit.block(model, Vector3.new(30, 2.6, 6), at(79, 0.6, 0), C.frame, { material = Enum.Material.Metal })
	Kit.block(
		model,
		Vector3.new(32, 1.2, WIDTH - 2),
		at(80, -1.6, 0),
		C.frame,
		{ material = Enum.Material.Metal }
	)
	for _, side in { -1, 1 } do
		Kit.block(
			model,
			Vector3.new(26, 0.3, 2),
			at(78, 1.9, side * 5.3),
			C.iron,
			{ material = Enum.Material.DiamondPlate }
		)
		Kit.block(
			model,
			Vector3.new(26, 0.15, 0.15),
			at(78, 6.5, side * 4.4),
			C.brass,
			{ material = Enum.Material.Metal, collide = false }
		)
		-- a 4-4-0: two big driving wheels, red spokes on an iron disc round a brass hub
		for _, x in { 70.5, 79.5 } do
			local driver = Kit.cylinder(
				model,
				0.7,
				5.6,
				at(x, -2.4, side * 5.3) * Kit.angles(0, 90, 0),
				C.wheel,
				{ material = Enum.Material.Metal }
			)
			driver:SetAttribute("WheelRadius", 2.8)
			local hubPivot = at(x, -2.4, side * 5.6).Position
			for i = 0, 3 do
				-- each spoke in its own plane so the crossings never z-fight
				local spoke = Kit.block(
					model,
					Vector3.new(5.2, 0.32, 0.08),
					at(x, -2.4, side * (5.7 + i * 0.01)) * CFrame.Angles(0, 0, math.rad(i * 45)),
					C.driver,
					{ material = Enum.Material.Metal, collide = false, shadow = false }
				)
				spoke:SetAttribute("WheelRadius", 2.8)
				spoke:SetAttribute("WheelPivot", hubPivot)
			end
			Kit.cylinder(
				model,
				0.5,
				1.3,
				at(x, -2.4, side * 5.6) * Kit.angles(0, 90, 0),
				C.brass,
				{ material = Enum.Material.Metal, collide = false }
			)
			-- counterweight orbits the axle on the client, which is what makes the wheel read as turning
			local counterweight = Kit.block(
				model,
				Vector3.new(1.6, 0.9, 0.2),
				at(x, -2.4 - 1.6, side * 5.72),
				C.driver,
				{ collide = false }
			)
			counterweight:SetAttribute("WheelRadius", 2.8)
			counterweight:SetAttribute("WheelPivot", at(x, -2.4, side * 5.72).Position)
			-- brass-beaded splasher over the top of the wheel
			Kit.block(
				model,
				Vector3.new(6.2, 0.25, 0.9),
				at(x, 0.75, side * 5.3),
				C.brass,
				{ material = Enum.Material.Metal, collide = false }
			)
		end
		local rod = Kit.block(
			model,
			Vector3.new(10.2, 0.45, 0.3),
			at(75, -2.4 + 1.1, side * 5.95),
			Color3.fromRGB(176, 180, 186),
			{ material = Enum.Material.Metal, collide = false }
		)
		rod:SetAttribute("CrankRadius", 1.1)
		rod:SetAttribute("CrankPhase", if side > 0 then 0 else 90)
		Kit.cylinder(
			model,
			4,
			2,
			at(91.5, 0.2, side * 4.2),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	bogie(90)

	-- boiler, smokebox, domes, chimney
	-- blue-grey Russia iron jacket under brass bands, as on an 1800s American engine
	local boiler = Kit.cylinder(model, 24, 8, at(76, 6.2, 0), C.russia, { material = Enum.Material.Metal })
	boiler.Name = "Boiler"
	for _, x in { 68, 76, 84 } do
		tag(
			Kit.cylinder(
				model,
				0.2,
				8.2,
				at(x, 6.2, 0),
				trim,
				{ material = Enum.Material.Metal, collide = false }
			),
			"Trim"
		)
	end
	Kit.cylinder(
		model,
		6,
		8.5,
		at(91, 6.2, 0),
		Color3.fromRGB(24, 24, 26),
		{ material = Enum.Material.Metal }
	)
	Kit.cylinder(
		model,
		0.5,
		7.6,
		at(94.2, 6.2, 0),
		Color3.fromRGB(30, 30, 32),
		{ material = Enum.Material.Metal }
	)
	Kit.cylinder(
		model,
		0.4,
		1.2,
		at(94.5, 6.2, 0),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	)
	-- 1800s balloon stack: a narrow neck flaring into a wide crown
	local soot = Color3.fromRGB(24, 24, 26)
	Kit.post(model, 3.4, 1.8, at(91, 11.8, 0), soot, { material = Enum.Material.Metal })
	Kit.post(model, 0.8, 2.6, at(91, 13.7, 0), soot, { material = Enum.Material.Metal })
	Kit.post(model, 0.8, 3.4, at(91, 14.3, 0), soot, { material = Enum.Material.Metal })
	local chimneyTop = Kit.post(model, 1.2, 4.2, at(91, 15.1, 0), soot, { material = Enum.Material.Metal })
	chimneyTop.Name = "ChimneyTop"
	Kit.post(model, 0.3, 4.4, at(91, 15.6, 0), C.brass, { material = Enum.Material.Metal, collide = false })
	-- brass bell between the domes
	Kit.post(model, 1.4, 0.4, at(75.5, 10.8, 0), C.iron, { material = Enum.Material.Metal })
	Kit.block(
		model,
		Vector3.new(0.2, 1.6, 1.8),
		at(75.5, 12.1, 0),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	Kit.ball(model, 1.4, at(75.5, 11.7, 0), C.brass, { material = Enum.Material.Metal, collide = false }).Name =
		"Bell"
	tag(Kit.post(model, 2.2, 3, at(80, 10.8, 0), trim, { material = Enum.Material.Metal }), "Trim")
	tag(Kit.ball(model, 3, at(80, 11.9, 0), trim, { material = Enum.Material.Metal }), "Trim")
	tag(Kit.post(model, 1.6, 2.4, at(71, 10.5, 0), trim, { material = Enum.Material.Metal }), "Trim")
	tag(Kit.ball(model, 2.4, at(71, 11.3, 0), trim, { material = Enum.Material.Metal }), "Trim")
	Kit.post(
		model,
		1.4,
		0.4,
		at(64.8, 11.2, 1.2),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	).Name =
		"Whistle"
	tag(Kit.block(model, Vector3.new(1, 2.2, 12), at(95.6, -0.2, 0), accent), "Accent")
	for _, side in { -1, 1 } do
		Kit.cylinder(
			model,
			1.4,
			0.9,
			at(96.6, -0.2, side * 4),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	-- pilot (cowcatcher): a V of red wooden slats down to a bottom rail
	local pilotRed = { material = Enum.Material.Wood, collide = false, shadow = false }
	for i = -4, 4 do
		local z = i * 1.25
		local front = 99.4 - math.abs(z) * 0.4
		Kit.block(
			model,
			Vector3.new(
				0.25,
				0.25,
				(Vector3.new(front, -4.6, z * 1.04) - Vector3.new(96.2, -1.3, z)).Magnitude
			),
			origin * Kit.between(Vector3.new(96.2, -1.3, z), Vector3.new(front, -4.6, z * 1.04)),
			C.driver,
			pilotRed
		)
	end
	for _, side in { -1, 1 } do
		strut(Vector3.new(99.4, -4.6, 0), Vector3.new(99.4 - 5 * 0.4, -4.6, side * 5.2), 0.3, C.iron)
	end
	-- headlamp: a big 1800s oil-lamp box on a bracket, brass-trimmed under a peaked hood
	tag(
		Kit.block(
			model,
			Vector3.new(2.6, 2.8, 2.8),
			at(94.3, 11.6, 0),
			accent,
			{ material = Enum.Material.Metal }
		),
		"Accent"
	)
	Kit.block(
		model,
		Vector3.new(2.9, 0.3, 3.1),
		at(94.3, 10.15, 0),
		C.brass,
		{ material = Enum.Material.Metal }
	)
	for _, side in { -1, 1 } do
		Kit.wedge(
			model,
			Vector3.new(3.1, 0.9, 1.6),
			at(94.3, 13.5, side * 0.8) * Kit.angles(0, if side > 0 then 180 else 0, 0),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	local headlamp = tag(
		Kit.neon(model, Vector3.new(0.2, 1.9, 1.9), at(95.7, 11.6, 0), Color3.fromRGB(255, 236, 190)),
		"Lamp"
	)
	headlamp.Name = "Headlamp"
	local beam = Kit.spotLight(headlamp, Color3.fromRGB(255, 226, 170), 4, 90, 40, Enum.NormalId.Right)
	beam.Name = "Beam"
	-- cylinder steam vents, driven by the client
	for _, side in { -1, 1 } do
		local vent = Kit.block(
			model,
			Vector3.new(0.4, 0.4, 0.4),
			at(92, -1.4, side * 5.2),
			Color3.new(),
			{ transparency = 1, collide = false, shadow = false }
		)
		vent.Name = "SteamVent"
	end

	-- Couplings between the tender and the cab
	buffers(52, -1)

	-- Inside: seats, lamps, the furnace, the stove and every sign (TrainInterior) ---------------
	local furnished = TrainInterior.furnish(model, origin, {
		lineIn = LINE_IN,
		ceiling = CEIL_BOTTOM,
		doorTop = DOOR_H,
		sideDoorTop = SIDE_DOOR_H,
		ceilingAt = function(x: number, z: number): number
			if math.abs(z) < OPEN then
				for _, span in openings do
					if x > span[1] and x < span[2] then
						return MONITOR_TOP - 0.1
					end
				end
			end
			return CEIL_BOTTOM
		end,
	})

	model.PrimaryPart = boiler
	Kit.setCollisionGroup(model, "Train")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model.Parent = parent

	local spawnPoints: { CFrame } = {}
	-- down the middle of the aisle, clear of the seats
	for _, x in { -14, -8, 8, 14, -56, -50, -36, -30 } do
		table.insert(spawnPoints, at(x, 3, 0))
	end

	return {
		model = model,
		carVolume = { cframe = at(-38, 4.5, 0), size = Vector3.new(116, 11, WIDTH) },
		cabVolume = { cframe = at(58, 4.5, 0), size = Vector3.new(12, 11, WIDTH) },
		spawnPoints = spawnPoints,
		breachAnchors = breachAnchors,
		doorBlockers = doorBlockers,
		workbench = workbench,
		mast = mast,
		mastLamp = mastLamp,
		seats = furnished.seats,
		cabins = cabins,
	}
end

-- Recolours every part tagged with a Livery role.
function TrainBuilder.applyLivery(model: Model, look: { [string]: any })
	local colors = {
		Body = Kit.rgb(look.body),
		Trim = Kit.rgb(look.trim),
		Roof = Kit.rgb(look.roof),
		Accent = Kit.rgb(look.accent),
		Lamp = Kit.rgb(look.lamp),
	}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Livery")
			if type(role) == "string" and colors[role] then
				part.Color = colors[role]
			end
		end
	end
end

return TrainBuilder
