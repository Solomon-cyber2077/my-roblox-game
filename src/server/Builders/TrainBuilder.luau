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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

local TrainBuilder = {}

local WIDTH = 13
local HALF = WIDTH / 2
local WALL_T = 0.5
local WALL_H = 9
local WINDOW_BOTTOM = 3.4
local WINDOW_TOP = 7.0
local DOOR_H = 7

local C = {
	floor = Color3.fromRGB(104, 78, 54),
	frame = Color3.fromRGB(34, 32, 32),
	wheel = Color3.fromRGB(40, 36, 36),
	glass = Color3.fromRGB(176, 196, 206),
	interior = Color3.fromRGB(142, 108, 72),
	brass = Color3.fromRGB(201, 160, 82),
	iron = Color3.fromRGB(58, 58, 62),
	warm = Color3.fromRGB(255, 206, 150),
	fire = Color3.fromRGB(255, 120, 40),
	bellows = Color3.fromRGB(30, 28, 28),
	coal = Color3.fromRGB(28, 27, 26),
	seat = Color3.fromRGB(120, 40, 36),
}

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
	routeTable: BasePart,
}

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

	local body = Color3.fromRGB(38, 74, 52)
	local trim = C.brass
	local roof = Color3.fromRGB(46, 44, 44)
	local accent = Color3.fromRGB(132, 46, 52)

	local doorBlockers: { BasePart } = {}
	local breachAnchors: { BasePart } = {}

	local function bogie(x: number)
		Kit.block(model, Vector3.new(8, 1.2, 10), at(x, -3, 0), C.frame, { material = Enum.Material.Metal })
		for _, ax in { -2.1, 2.1 } do
			for _, side in { -1, 1 } do
				local wheel = Kit.cylinder(
					model,
					0.6,
					3.2,
					at(x + ax, -3.6, side * 5.3) * Kit.angles(0, 90, 0),
					C.wheel,
					{ material = Enum.Material.Metal }
				)
				wheel:SetAttribute("WheelRadius", 1.6)
				Kit.block(
					model,
					Vector3.new(1, 0.9, 0.5),
					at(x + ax, -3.2, side * 5.75),
					C.iron,
					{ material = Enum.Material.Metal, collide = false }
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

	local function sideWall(x0: number, x1: number, z: number, doors: { number }, doorWidth: number)
		local outer = z + (if z > 0 then 1 else -1) * (WALL_T / 2 + 0.06)
		local gaps: { Span } = {}
		for _, dx in doors do
			table.insert(gaps, { dx - doorWidth / 2, dx + doorWidth / 2 })
		end
		-- lower panels
		for _, span in subtract(x0, x1, gaps) do
			local len = span[2] - span[1]
			local cx = (span[1] + span[2]) / 2
			tag(
				Kit.block(
					model,
					Vector3.new(len, WINDOW_BOTTOM, WALL_T),
					at(cx, WINDOW_BOTTOM / 2, z),
					body,
					{ material = Enum.Material.SmoothPlastic }
				),
				"Body"
			)
			tag(
				Kit.block(
					model,
					Vector3.new(len, 0.28, 0.08),
					at(cx, WINDOW_BOTTOM, outer),
					trim,
					{ material = Enum.Material.Metal, collide = false }
				),
				"Trim"
			)
			tag(
				Kit.block(
					model,
					Vector3.new(len, 0.28, 0.08),
					at(cx, 0.9, outer),
					trim,
					{ material = Enum.Material.Metal, collide = false }
				),
				"Trim"
			)
		end
		-- upper panel runs over the doors
		tag(
			Kit.block(
				model,
				Vector3.new(x1 - x0, WALL_H - WINDOW_TOP, WALL_T),
				at((x0 + x1) / 2, (WALL_H + WINDOW_TOP) / 2, z),
				body
			),
			"Body"
		)
		tag(
			Kit.block(
				model,
				Vector3.new(x1 - x0, 0.28, 0.08),
				at((x0 + x1) / 2, WINDOW_TOP, outer),
				trim,
				{ material = Enum.Material.Metal, collide = false }
			),
			"Trim"
		)
		-- window band: glass panes with posts between
		local windows: { Span } = {}
		local pitch = 5.2
		local count = math.floor((x1 - x0 - 3) / pitch)
		local start = (x0 + x1) / 2 - (count - 1) * pitch / 2
		for i = 0, count - 1 do
			local cx = start + i * pitch
			local blocked = false
			for _, gap in gaps do
				if cx + 2.2 > gap[1] and cx - 2.2 < gap[2] then
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
			end
		end
		local solid = table.clone(gaps)
		for _, w in windows do
			table.insert(solid, w)
		end
		for _, span in subtract(x0, x1, solid) do
			local len = span[2] - span[1]
			if len > 0.05 then
				tag(
					Kit.block(
						model,
						Vector3.new(len, WINDOW_TOP - WINDOW_BOTTOM, WALL_T),
						at((span[1] + span[2]) / 2, (WINDOW_TOP + WINDOW_BOTTOM) / 2, z),
						body
					),
					"Body"
				)
			end
		end
		-- doors: sliding panels (client-animated) and a collision blocker (server-toggled)
		for _, dx in doors do
			local blocker = Kit.block(
				model,
				Vector3.new(doorWidth, DOOR_H, 0.6),
				at(dx, DOOR_H / 2, z),
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
					Vector3.new(doorWidth / 2, DOOR_H, 0.25),
					at(dx + dir * doorWidth / 4, DOOR_H / 2, outer + (if z > 0 then 0.1 else -0.1)),
					accent,
					{ collide = false }
				)
				panel.Name = "DoorPanel"
				panel:SetAttribute("DoorSlide", slide)
				tag(panel, "Accent")
				local pane = Kit.block(
					model,
					Vector3.new(0.7, 2.2, 0.08),
					panel.CFrame * CFrame.new(0, 1.2, if z > 0 then 0.14 else -0.14),
					C.glass,
					{ material = Enum.Material.Glass, transparency = 0.4, collide = false }
				)
				pane.Name = "DoorPanel"
				pane:SetAttribute("DoorSlide", slide)
			end
		end
	end

	local function endWall(x: number, gangway: boolean)
		if gangway then
			for _, side in { -1, 1 } do
				tag(
					Kit.block(model, Vector3.new(WALL_T, WALL_H, 4.5), at(x, WALL_H / 2, side * 4.25), body),
					"Body"
				)
			end
			tag(
				Kit.block(
					model,
					Vector3.new(WALL_T, WALL_H - DOOR_H, 4),
					at(x, (WALL_H + DOOR_H) / 2, 0),
					body
				),
				"Body"
			)
		else
			tag(Kit.block(model, Vector3.new(WALL_T, WALL_H, WIDTH), at(x, WALL_H / 2, 0), body), "Body")
		end
	end

	local function roofOver(x0: number, x1: number)
		local len = x1 - x0 + 0.6
		local cx = (x0 + x1) / 2
		tag(
			Kit.block(
				model,
				Vector3.new(len, 0.5, 7),
				at(cx, WALL_H + 0.55, 0),
				roof,
				{ material = Enum.Material.Metal }
			),
			"Roof"
		)
		for _, side in { -1, 1 } do
			tag(
				Kit.block(
					model,
					Vector3.new(len, 0.5, 3.8),
					at(cx, WALL_H + 0.2, side * 4.9) * Kit.angles(side * -12, 0, 0),
					roof,
					{ material = Enum.Material.Metal }
				),
				"Roof"
			)
		end
	end

	local function ceilingLamps(x0: number, x1: number)
		local count = math.max(1, math.floor((x1 - x0) / 12))
		for i = 1, count do
			local x = x0 + (x1 - x0) * (i - 0.5) / count
			local lamp = Kit.neon(model, Vector3.new(1.4, 0.25, 1.4), at(x, WALL_H - 0.1, 0), C.warm)
			Kit.pointLight(lamp, C.warm, 1.1, 18, false)
		end
	end

	local function car(x0: number, x1: number, doors: { number }, frontGangway: boolean, rearGangway: boolean)
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
		bogie(x0 + 6.5)
		bogie(x1 - 6.5)
		sideWall(x0, x1, HALF - WALL_T / 2, doors, 5)
		sideWall(x0, x1, -(HALF - WALL_T / 2), {}, 5)
		endWall(x0 + WALL_T / 2, rearGangway)
		endWall(x1 - WALL_T / 2, frontGangway)
		roofOver(x0, x1)
		ceilingLamps(x0, x1)
	end

	local function gangway(x0: number, x1: number)
		local cx = (x0 + x1) / 2
		local len = x1 - x0 + 0.4
		Kit.block(
			model,
			Vector3.new(len, 1, 4.4),
			at(cx, -0.5, 0),
			C.iron,
			{ material = Enum.Material.DiamondPlate }
		)
		for _, side in { -1, 1 } do
			Kit.block(
				model,
				Vector3.new(len, DOOR_H + 0.4, 0.4),
				at(cx, (DOOR_H + 0.4) / 2, side * 2.3),
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
	car(-90, -66, { -78 }, true, true)
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
			at(-93, WALL_H + 0.55, 0),
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
		Vector3.new(0.2, 3.2, 0.2),
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
	-- stove
	Kit.cylinder(
		model,
		3,
		2.2,
		at(-69.5, 1.5, -4.4) * Kit.angles(0, 0, 90),
		C.coal,
		{ material = Enum.Material.Metal }
	)
	local stoveGlow = Kit.neon(model, Vector3.new(0.8, 0.6, 0.1), at(-69.5, 1.2, -3.25), C.fire)
	Kit.pointLight(stoveGlow, C.fire, 1.4, 10, false)
	Kit.post(model, 8, 0.6, at(-69.5, 7, -4.4), C.coal, { material = Enum.Material.Metal })
	breachAnchor("BV1", -84, 5.2, -5.6)
	breachAnchor("BV2", -72, 5.2, -5.6)
	gangway(-66, -63)

	-- Crew car -------------------------------------------------------------------------
	car(-63, -23, { -43 }, true, true)
	local tableTop = Kit.block(
		model,
		Vector3.new(6, 0.3, 4),
		at(-43, 3.0, -3.4),
		C.interior,
		{ material = Enum.Material.Wood }
	)
	for _, dx in { -2.6, 2.6 } do
		for _, dz in { -1.6, 1.6 } do
			Kit.block(
				model,
				Vector3.new(0.3, 3, 0.3),
				at(-43 + dx, 1.5, -3.4 + dz),
				C.iron,
				{ material = Enum.Material.Metal }
			)
		end
	end
	local routeTable = Kit.block(
		model,
		Vector3.new(5.6, 0.06, 3.6),
		at(-43, 3.18, -3.4),
		Color3.fromRGB(214, 200, 168),
		{ material = Enum.Material.Fabric, collide = false }
	)
	routeTable.Name = "RouteTable"
	tableTop.Name = "RouteTableTop"
	for _, x in { -57.5, -51.5, -34.5, -28.5 } do
		Kit.block(
			model,
			Vector3.new(4.6, 1.8, 2.2),
			at(x, 0.9, -5.0),
			C.seat,
			{ material = Enum.Material.Fabric }
		)
		Kit.block(
			model,
			Vector3.new(4.6, 3, 0.6),
			at(x, 3.3, -5.85),
			C.seat,
			{ material = Enum.Material.Fabric }
		)
	end
	breachAnchor("CR1", -55, 5.2, -5.6)
	breachAnchor("CR2", -31, 5.2, -5.6)
	gangway(-23, -20)

	-- Workshop car -----------------------------------------------------------------------
	car(-20, 20, { 0 }, false, true)
	Kit.block(model, Vector3.new(9, 0.4, 3), at(0, 3.0, -4.6), C.interior, { material = Enum.Material.Wood })
	for _, dx in { -4, 4 } do
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
		at(-2.8, 3.6, -4.4),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(9, 4, 0.2),
		at(0, 5.6, -6.0),
		Color3.fromRGB(92, 70, 48),
		{ material = Enum.Material.WoodPlanks, collide = false }
	)
	for i, dx in { -3.4, -2, -0.6, 0.8, 2.2, 3.6 } do
		Kit.block(
			model,
			Vector3.new(0.25, 1.4 + (i % 3) * 0.4, 0.15),
			at(dx, 5.6, -5.85),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	local workbench = Kit.block(
		model,
		Vector3.new(8, 4, 3),
		at(0, 2.5, -4.2),
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
				Vector3.new(tx1 - tx0, 7, WALL_T),
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
	sideWall(cx0, cx1, HALF - WALL_T / 2, { 58 }, 4)
	sideWall(cx0, cx1, -(HALF - WALL_T / 2), {}, 4)
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
	-- backhead: firebox, gauges, regulator
	tag(Kit.block(model, Vector3.new(0.6, WALL_H, WIDTH), at(cx1 - 0.3, WALL_H / 2, 0), body), "Body")
	local firebox = Kit.neon(model, Vector3.new(0.2, 1.6, 2), at(cx1 - 0.7, 2.2, 0), C.fire)
	firebox.Name = "Firebox"
	Kit.pointLight(firebox, C.fire, 2.2, 14, true)
	for i, dz in { -1.6, 1.6 } do
		local gauge = Kit.cylinder(
			model,
			0.25,
			1.2,
			at(cx1 - 0.7, 6.6, dz),
			C.brass,
			{ material = Enum.Material.Metal, collide = false }
		)
		Kit.cylinder(
			model,
			0.05,
			1,
			gauge.CFrame * CFrame.new(-0.15, 0, 0),
			Color3.fromRGB(236, 226, 200),
			{ collide = false }
		)
		gauge.Name = if i == 1 then "CoalGauge" else "PressureGauge"
	end
	Kit.block(
		model,
		Vector3.new(0.3, 0.3, 2.2),
		at(cx1 - 0.9, 5, 0) * Kit.angles(30, 0, 0),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	)
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
		for _, x in { 67.5, 75, 82.5 } do
			local driver = Kit.cylinder(
				model,
				0.7,
				5.6,
				at(x, -2.4, side * 5.3) * Kit.angles(0, 90, 0),
				C.wheel,
				{ material = Enum.Material.Metal }
			)
			driver:SetAttribute("WheelRadius", 2.8)
			Kit.cylinder(
				model,
				0.75,
				1.2,
				at(x, -2.4, side * 5.35) * Kit.angles(0, 90, 0),
				C.brass,
				{ material = Enum.Material.Metal, collide = false }
			)
			-- counterweight orbits the axle on the client, which is what makes the wheel read as turning
			local counterweight = Kit.block(
				model,
				Vector3.new(1.6, 0.9, 0.2),
				at(x, -2.4 - 1.6, side * 5.72),
				body,
				{ collide = false }
			)
			counterweight:SetAttribute("WheelRadius", 2.8)
			counterweight:SetAttribute("WheelPivot", at(x, -2.4, side * 5.72).Position)
			tag(counterweight, "Body")
		end
		local rod = Kit.block(
			model,
			Vector3.new(16, 0.45, 0.3),
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
	local boiler = tag(
		Kit.cylinder(model, 24, 8, at(76, 6.2, 0), body, { material = Enum.Material.SmoothPlastic }),
		"Body"
	)
	boiler.Name = "Boiler"
	for _, x in { 68, 76, 84 } do
		tag(
			Kit.cylinder(
				model,
				0.35,
				8.25,
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
	Kit.post(model, 4.6, 2.2, at(91, 12.4, 0), Color3.fromRGB(24, 24, 26), { material = Enum.Material.Metal })
	local chimneyTop = Kit.post(
		model,
		0.7,
		2.9,
		at(91, 14.9, 0),
		Color3.fromRGB(24, 24, 26),
		{ material = Enum.Material.Metal }
	)
	chimneyTop.Name = "ChimneyTop"
	tag(Kit.post(model, 2.2, 3, at(80, 10.8, 0), trim, { material = Enum.Material.Metal }), "Trim")
	tag(Kit.ball(model, 3, at(80, 11.9, 0), trim, { material = Enum.Material.Metal }), "Trim")
	tag(Kit.post(model, 1.6, 2.4, at(71, 10.5, 0), body), "Body")
	tag(Kit.ball(model, 2.4, at(71, 11.3, 0), body), "Body")
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
	-- pilot (cowcatcher)
	for i = -2, 2 do
		Kit.wedge(
			model,
			Vector3.new(1.8, 2.6, 2.4),
			at(97.2, -2.6, i * 2.3) * Kit.angles(0, 90, 0),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	-- headlamp
	Kit.block(
		model,
		Vector3.new(1.6, 2, 2),
		at(94.8, 11.2, 0),
		Color3.fromRGB(24, 24, 26),
		{ material = Enum.Material.Metal }
	)
	local headlamp = tag(
		Kit.neon(model, Vector3.new(0.2, 1.4, 1.4), at(95.7, 11.2, 0), Color3.fromRGB(255, 236, 190)),
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

	model.PrimaryPart = boiler
	Kit.setCollisionGroup(model, "Train")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model.Parent = parent

	local spawnPoints: { CFrame } = {}
	for _, x in { -14, -8, 8, 14, -56, -50, -36, -30 } do
		table.insert(spawnPoints, at(x, 3, 1.5))
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
		routeTable = routeTable,
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
