--!strict
--[[
	Builds one enterable building from its LayoutGen entry: walls split around their
	doors and windows, the ceiling and roof, the front door under a painted name board,
	windows glazed, broken or boarded, ceiling lamps (most of them dead), the fuse box,
	locked doors and every piece of furniture that is not a container (StationBuilder
	builds those, so the search prompts hang from them). A building with an upper floor
	gets its slab, the stairwell ramp, a lean-to roof over the front and a pitched roof
	over the upper storey; moonlight comes in through some of the broken windows.

	The frame is the building's origin on the floor; local -Z faces the platform.
	Returns a handle BuildingService uses at run time: the lamps, the glass that lights
	up with the power, the fuse box and the locked doors.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local Kit = require(Shared.Visual.Kit)
local BuildingGen = require(Shared.Logic.BuildingGen)

local FurnitureKit = require(script.Parent.FurnitureKit)

export type Lamp = { light: PointLight, bulb: BasePart, works: boolean }
export type Lock = { leaf: BasePart, door: BuildingGen.Door, open: CFrame }
export type Handle = {
	lamps: { Lamp },
	glass: { BasePart },
	fuse: BasePart,
	locks: { Lock },
}

local BuildingBuilder = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local LAMP = rgb(255, 214, 160)
local DEAD = rgb(70, 66, 60)
local PLASTER = rgb(190, 180, 160)
local CEILING = rgb(150, 142, 128)
local GLASS = rgb(140, 160, 170)
local MOON = rgb(150, 172, 215)

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else M.Concrete
end

-- Builds the shell and furniture into `parent` at `frame`. Not welded (StationBuilder welds).
function BuildingBuilder.build(
	plan: BuildingGen.Plan,
	parent: Model,
	frame: CFrame,
	accent: Color3,
	seed: number
): Handle
	local def = Buildings.Defs[plan.kind]
	local rng = Random.new(seed % 2147483647)
	local wallColor = Kit.rgb(def.wall)
	local trim = Kit.rgb(def.trim)
	local wallMaterial = material(def.wallMaterial)
	local H = plan.height
	local ox, oz = plan.outerX, plan.outerZ

	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	local function block(
		size: Vector3,
		cf: CFrame,
		color: Color3,
		mat: Enum.Material?,
		collide: boolean?
	): BasePart
		return Kit.block(parent, size, cf, color, { material = mat or M.SmoothPlastic, collide = collide })
	end

	-- walls ------------------------------------------------------------------------------------
	for _, piece in plan.walls do
		local length = piece.b - piece.a
		local mid = (piece.a + piece.b) / 2
		local height = piece.y1 - piece.y0
		local y = (piece.y0 + piece.y1) / 2
		local color = if piece.exterior then wallColor else PLASTER
		local mat = if piece.exterior then wallMaterial else M.Plaster
		if piece.axis == "X" then
			block(Vector3.new(length, height, piece.thick), at(mid, y, piece.fixed), color, mat)
		else
			block(Vector3.new(piece.thick, height, length), at(piece.fixed, y, mid), color, mat)
		end
	end

	-- ceiling, roof and chimneys -------------------------------------------------------------
	local roofColor = Kit.rgb(def.roof)
	local roofMaterial = material(def.roofMaterial)
	local upper = plan.upper
	-- the pitched roof spans [z0, z1] from its eaves at `top`
	local top, z0, z1 = H + 1, -oz, oz
	if upper then
		-- the ground floor's ceiling over the front, the upper floor's slab over the back
		local edge = upper.south + Buildings.Wall / 2
		block(
			Vector3.new(2 * ox + 1, 1, edge + oz + 0.5),
			at(0, H + 0.5, (edge - oz - 0.5) / 2),
			CEILING,
			M.Plaster
		)
		local slab = upper.slab
		local floor = block(
			Vector3.new(slab.x1 - slab.x0, 1, slab.z1 - slab.z0),
			at((slab.x0 + slab.x1) / 2, H + 0.5, (slab.z0 + slab.z1) / 2),
			Kit.rgb(def.floor),
			material(def.floorMaterial)
		)
		floor.Name = "UpperFloor"
		local back = upper.south - Buildings.Wall / 2
		block(
			Vector3.new(2 * ox + 1, 1, oz + 0.5 - back + 0.5),
			at(0, upper.top + 0.5, (oz + 0.5 + back - 0.5) / 2),
			CEILING,
			M.Plaster
		)
		-- a lean-to over the front, up against the upper storey
		local leanDepth = back + oz + 1.2
		local leanRise = math.min(6, leanDepth * 0.3)
		Kit.wedge(
			parent,
			Vector3.new(2 * ox + 2, leanRise, leanDepth),
			at(0, H + 1 + leanRise / 2, (back - oz - 1.2) / 2),
			roofColor,
			{ material = roofMaterial }
		)
		top, z0, z1 = upper.top + 1, back, oz
	else
		block(Vector3.new(2 * ox + 1, 1, 2 * oz + 1), at(0, H + 0.5, 0), CEILING, M.Plaster)
	end
	if def.roofStyle == "Pitched" then
		local half = (z1 - z0) / 2
		local ridge = (z0 + z1) / 2
		local rise = math.min(12, half * 0.45)
		local depth = half + 1.2
		Kit.wedge(
			parent,
			Vector3.new(2 * ox + 2, rise, depth),
			at(0, top + rise / 2, ridge - depth / 2),
			roofColor,
			{ material = roofMaterial }
		)
		Kit.wedge(
			parent,
			Vector3.new(2 * ox + 2, rise, depth),
			at(0, top + rise / 2, ridge + depth / 2) * Kit.angles(0, 180, 0),
			roofColor,
			{ material = roofMaterial }
		)
		for _, x in { -ox * 0.55, ox * 0.6 } do
			if rng:NextNumber() < 0.8 then
				block(
					Vector3.new(2.4, rise + 3, 2.4),
					at(x, top + (rise + 3) / 2, ridge + half * 0.3),
					Kit.shade(wallColor, 0.85),
					wallMaterial
				)
				Kit.post(
					parent,
					1.4,
					1,
					at(x, top + rise + 3.7, ridge + half * 0.3),
					rgb(150, 80, 60),
					{ material = M.Brick }
				)
			end
		end
	else
		for _, side in { -1, 1 } do
			block(Vector3.new(2 * ox + 1, 1.6, 0.8), at(0, top + 0.8, side * (oz + 0.1)), trim, wallMaterial)
			block(
				Vector3.new(0.8, 1.6, 2 * oz - 0.6),
				at(side * (ox + 0.1), top + 0.8, 0),
				trim,
				wallMaterial
			)
		end
		block(Vector3.new(3, 2.6, 2.4), at(ox * 0.4, top + 1.3, oz * 0.4), rgb(110, 110, 112), M.Metal) -- a water tank
	end

	-- the name over the front door
	local sign = block(
		Vector3.new(math.min(2 * ox - 4, 26), 2.6, 0.3),
		at(0, Buildings.DoorHeight + 1.9, -oz - 0.15),
		Kit.shade(trim, 0.5),
		M.Wood,
		false
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1000, 100)
	gui.LightInfluence = 0.6
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
	label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
	label.Text = string.upper(def.name)
	label.TextColor3 = rgb(236, 220, 180)
	label.TextScaled = true
	label.Parent = gui

	-- doors ------------------------------------------------------------------------------------
	local locks: { Lock } = {}
	for _, door in plan.doors do
		local along = if door.axis == "X" then CFrame.identity else Kit.angles(0, 90, 0)
		local base = at(door.x, door.y, door.z) * along -- local X runs along the wall, Z through it
		local w = door.width
		if door.exterior then
			-- a frame proud of the outside face, and the leaves hung open against the wall
			local out = door.outward * (Buildings.Wall / 2 + 0.15)
			for _, side in { -1, 1 } do
				block(
					Vector3.new(0.5, Buildings.DoorHeight, 0.3),
					base * CFrame.new(side * (w / 2 + 0.25), Buildings.DoorHeight / 2, out),
					trim,
					M.Wood,
					false
				)
			end
			block(
				Vector3.new(w + 1.0, 0.6, 0.3),
				base * CFrame.new(0, Buildings.DoorHeight + 0.3, out),
				trim,
				M.Wood,
				false
			)
			local leaves: { number } = if door.front
				then { -1, 1 }
				else { (if rng:NextNumber() < 0.5 then -1 else 1) }
			local leafWidth = if door.front then w / 2 - 0.1 else w - 0.2
			for _, side in leaves do
				local hinge = base * CFrame.new(side * w / 2, 0, door.outward * (Buildings.Wall / 2 + 0.2))
				local swing = hinge * Kit.angles(0, side * door.outward * (60 + rng:NextNumber() * 20), 0)
				block(
					Vector3.new(leafWidth, Buildings.DoorHeight - 0.3, 0.25),
					swing
						* CFrame.new(
							-side * leafWidth / 2,
							(Buildings.DoorHeight - 0.3) / 2,
							door.outward * 0.15
						),
					Kit.shade(trim, 0.7),
					M.Wood,
					false
				)
			end
		elseif door.locked then
			-- shut, chained and padlocked
			local leaf = block(
				Vector3.new(w - 0.2, Buildings.DoorHeight - 0.2, 0.4),
				base * CFrame.new(0, (Buildings.DoorHeight - 0.2) / 2, 0),
				rgb(86, 60, 42),
				M.WoodPlanks,
				true
			)
			leaf.Name = "LockedDoor"
			for _, face in { -1, 1 } do
				local chain = block(
					Vector3.new(w * 0.7, 0.18, 0.12),
					base * CFrame.new(0, 4.2, face * 0.28) * Kit.angles(0, 0, face * 8),
					rgb(60, 58, 56),
					M.Metal,
					false
				)
				local padlock = block(
					Vector3.new(0.5, 0.6, 0.2),
					base * CFrame.new(0.1, 3.9, face * 0.36),
					rgb(150, 120, 60),
					M.Metal,
					false
				)
				chain.Parent = leaf
				padlock.Parent = leaf
			end
			local hinge = base * CFrame.new(-w / 2 + 0.1, 0, 0)
			local open = hinge
				* Kit.angles(0, -100, 0)
				* CFrame.new(w / 2 - 0.1, (Buildings.DoorHeight - 0.2) / 2, 0)
			table.insert(locks, { leaf = leaf, door = door, open = frame:ToObjectSpace(open) })
		end
	end

	-- windows ----------------------------------------------------------------------------------
	local glass: { BasePart } = {}
	for _, window in plan.windows do
		local sill, head = window.y0, window.y1
		local along = if window.axis == "X" then CFrame.identity else Kit.angles(0, 90, 0)
		local base = at(window.x, 0, window.z) * along
		local out = window.outward * (Buildings.Wall / 2 + 0.12)
		local w = window.width
		block(
			Vector3.new(w + 0.8, 0.35, 0.25),
			base * CFrame.new(0, sill - 0.17, out),
			trim,
			M.Concrete,
			false
		)
		block(
			Vector3.new(w + 0.8, 0.45, 0.25),
			base * CFrame.new(0, head + 0.22, out),
			trim,
			M.Concrete,
			false
		)
		if window.glass == "Glass" then
			local pane = block(
				Vector3.new(w, head - sill, 0.15),
				base * CFrame.new(0, (sill + head) / 2, 0),
				GLASS,
				M.Glass,
				false
			)
			pane.Transparency = 0.55
			table.insert(glass, pane)
			block(
				Vector3.new(0.15, head - sill, 0.25),
				base * CFrame.new(0, (sill + head) / 2, 0),
				Kit.shade(trim, 0.6),
				M.Wood,
				false
			)
		elseif window.glass == "Boarded" then
			for i = 0, 2 do
				block(
					Vector3.new(w + 1, 0.7, 0.18),
					base
						* CFrame.new(
							0,
							sill + 0.9 + i * 1.5,
							window.outward * (Buildings.Wall / 2 + 0.3 + i * 0.05)
						)
						* Kit.angles(0, 0, (rng:NextNumber() - 0.5) * 18),
					rgb(102, 80, 58),
					M.WoodPlanks,
					false
				)
			end
		else
			Kit.wedge(
				parent,
				Vector3.new(0.12, 1.2, 0.8),
				base * CFrame.new(-w / 2 + 0.5, sill + 0.6, 0) * Kit.angles(0, 90, 0),
				GLASS,
				{ material = M.Glass, collide = false, transparency = 0.5 }
			)
		end
	end

	-- lamps --------------------------------------------------------------------------------------
	local lamps: { Lamp } = {}
	for _, lamp in plan.lamps do
		if lamp.kind == "Moon" then
			-- no fixture: only the night coming in through the broken pane
			local glow =
				block(Vector3.new(0.2, 0.2, 0.2), at(lamp.x, lamp.y, lamp.z), MOON, M.SmoothPlastic, false)
			glow.Transparency = 1
			glow.CastShadow = false
			glow.Name = "Moonlight"
			Kit.pointLight(glow, MOON, 0.45, 18, false)
			continue
		elseif lamp.kind ~= "Ceiling" then
			continue -- the lantern is furniture
		end
		local ceiling = lamp.y
		Kit.post(
			parent,
			1.6,
			0.12,
			at(lamp.x, ceiling - 0.8, lamp.z),
			rgb(30, 30, 30),
			{ material = M.Metal, collide = false }
		)
		Kit.post(
			parent,
			0.5,
			1.6,
			at(lamp.x, ceiling - 1.85, lamp.z),
			rgb(48, 70, 58),
			{ material = M.Metal, collide = false }
		)
		local bulb =
			Kit.ball(parent, 0.6, at(lamp.x, ceiling - 2.25, lamp.z), if lamp.works then LAMP else DEAD, {
				material = if lamp.works then M.Neon else M.SmoothPlastic,
				collide = false,
				shadow = false,
			})
		bulb.Name = "Bulb"
		local light = Kit.pointLight(bulb, LAMP, 0.8, 22, false)
		light.Enabled = lamp.works
		light:SetAttribute("Base", 0.8)
		light:SetAttribute("Flicker", lamp.works)
		CollectionService:AddTag(light, "LTO_BuildingLamp")
		table.insert(lamps, { light = light, bulb = bulb, works = lamp.works })
	end

	-- the fuse box, by the front door
	local fuse = block(
		Vector3.new(2, 2.6, 0.6),
		at(plan.fuse.x, 5, plan.fuse.z - 0.05),
		rgb(70, 84, 76),
		M.Metal,
		true
	)
	fuse.Name = "FuseBox"
	block(
		Vector3.new(0.3, 1.0, 0.35),
		at(plan.fuse.x + 0.5, 5.2, plan.fuse.z + 0.37),
		rgb(140, 36, 30),
		M.Metal,
		false
	)
	block(
		Vector3.new(1.2, 0.5, 0.05),
		at(plan.fuse.x - 0.2, 5.75, plan.fuse.z + 0.275),
		rgb(220, 180, 40),
		M.SmoothPlastic,
		false
	)
	block(
		Vector3.new(0.3, H - 6.3, 0.3),
		at(plan.fuse.x - 0.6, 6.3 + (H - 6.3) / 2, plan.fuse.z - 0.2),
		rgb(40, 40, 40),
		M.Metal,
		false
	)

	-- the stairwell's ramp: one solid wedge, nothing to get caught under ------------------------
	for _, stair in plan.stairs do
		Kit.wedge(
			parent,
			Vector3.new(stair.z1 - stair.z0, stair.rise, stair.x1 - stair.x0),
			at((stair.x0 + stair.x1) / 2, stair.rise / 2, (stair.z0 + stair.z1) / 2) * Kit.angles(0, 90, 0),
			Kit.rgb(def.floor),
			{ material = material(def.floorMaterial) }
		)
	end

	-- rugs and the furniture that is only there to be looked at -------------------------------
	local rooms = table.clone(plan.rooms)
	if upper then
		for _, room in upper.rooms do
			table.insert(rooms, room)
		end
	end
	for _, room in rooms do
		local roomDef = Buildings.Rooms[room.kind]
		if roomDef and roomDef.rug then
			local r = room.rect
			local w, d = (r.x1 - r.x0) - 6, (r.z1 - r.z0) - 6
			if w > 3 and d > 3 then
				block(
					Vector3.new(w, 0.06, d),
					at((r.x0 + r.x1) / 2, room.y + 0.03, (r.z0 + r.z1) / 2),
					Kit.rgb(roomDef.rug),
					M.Fabric,
					false
				)
			end
		end
	end
	for _, item in plan.items do
		if item.container == nil and item.kind ~= "Stairs" then
			FurnitureKit.build(item.kind, {
				parent = parent,
				frame = at(item.x, item.y, item.z) * Kit.angles(0, item.rot, 0),
				rng = rng,
				accent = accent,
			})
		end
	end

	return { lamps = lamps, glass = glass, fuse = fuse, locks = locks }
end

return BuildingBuilder
