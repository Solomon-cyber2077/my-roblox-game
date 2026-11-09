--!strict
--[[
	The Depot hall lived in (owner 11-06, the life pass: "the game felt sterile"): the wear and the
	clutter a busy terminus gathers, in hall space (Builders/LobbyBuilder: +X along the platform,
	+Z from the track to the back wall, y = 0 the platform).

	  grime        soot and boot-black round the lamp standards' feet and along the back wall; soot
	               and rain runs down the brick from the board and the cornice, damp stains, chipped
	               dado tiles (what a Hand sees first, from the spawn ring)
	  a puddle     under a leak in the glazing, fed by a slow drip
	  luggage      a porter's barrow with two trunks and a hatbox, mail sacks and parcels against
	               the back wall, crates and cases either side of the board, milk churns at the
	               platform's end
	  litter       dropped tickets and a newspaper

	Flat wear lies a hair over the flags, each kind at its own height, so no two faces share a
	plane (lune run audit). The barrow, trunks, sacks and churns collide: they take up room, and
	the audit's Passengers/Hall target proves none of them sits on a passenger's walk. Small
	pieces are tagged Detail, so the Performance setting leaves them out.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HallProps = require(ReplicatedStorage.Shared.Config.HallProps)
local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local PosterArt = require(script.Parent.PosterArt)

local HallWear = {}

export type Placed = { key: string, cframe: CFrame, scale: number }

-- Where the last build stood each Blender prop (Config/HallProps), for `lune run preview Hall`.
HallWear.placed = {} :: { Placed }

local function assets(): any?
	local ok, service = pcall(function()
		return game:GetService("AssetService")
	end)
	return if ok then service else nil
end

-- Swaps a cluster's part-built props for its Blender meshes once every one has an id and loads:
-- the colliding parts stay on, invisible, as the props' room; the rest go. Anything missing or
-- failing keeps the parts (and in a headless build there is no AssetService at all).
local function dress(cluster: Model, list: { Placed })
	cluster:SetAttribute("Meshed", true) -- these parts give way to meshes (and the preview drops them)
	for _, item in list do
		table.insert(HallWear.placed, item)
	end
	for _, item in list do
		if HallProps[item.key] == nil then
			return
		end
	end
	local service = assets()
	if service == nil then
		return
	end
	task.spawn(function()
		local meshes: { MeshPart } = {}
		for _, item in list do
			local asset = HallProps[item.key]
			local ok, made = pcall(function()
				return service:CreateMeshPartAsync(`rbxassetid://{asset.mesh}`)
			end)
			if not ok or made == nil then
				warn(`HallWear: {item.key} mesh did not load: {made}`)
				for _, m in meshes do
					m:Destroy()
				end
				return
			end
			local mesh = made :: MeshPart
			mesh.Name = item.key
			mesh.TextureID = `rbxassetid://{asset.texture}`
			mesh.Color = Color3.new(1, 1, 1)
			mesh.Size *= item.scale
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CFrame = item.cframe * CFrame.new(0, mesh.Size.Y / 2, 0)
			if item.key == "puddle" then
				-- standing water: dark glass that holds the lamps
				mesh.Material = Enum.Material.Glass
				mesh.Reflectance = 0.12
				mesh.Transparency = 0.65
			end
			table.insert(meshes, mesh)
		end
		for _, part in cluster:GetDescendants() do
			if part:IsA("BasePart") then
				if part.CanCollide then
					part.Transparency = 1
				else
					part:Destroy()
				end
			end
		end
		for _, mesh in meshes do
			mesh.Parent = cluster
		end
	end)
end

local M = Enum.Material
local GRIME = Color3.fromRGB(36, 33, 30)
local WATER = Color3.fromRGB(12, 14, 18)
local PAPER = Color3.fromRGB(206, 192, 158)
local LEATHER = Color3.fromRGB(70, 40, 26)
local CANVAS = Color3.fromRGB(150, 134, 102)
local IRON = Color3.fromRGB(46, 44, 42)
local WOOD = Color3.fromRGB(96, 62, 38)
local BRASS = Color3.fromRGB(176, 140, 76)
local TIN = Color3.fromRGB(150, 152, 150)

-- the lamp standards' feet (LobbyBuilder's rows at z -15 and z 43)
local POSTS_X = { -101, -79, -57, -35, -13, 9, 31, 53, 75 }

function HallWear.build(model: Model, origin: CFrame)
	table.clear(HallWear.placed)
	local root = Kit.model("Wear", model)
	local folder = root
	-- the parts built after this go into their own model, so its meshes can replace them together
	local function cluster(name: string): Model
		folder = Kit.model(name, root)
		return folder
	end
	local function at(x: number, y: number, z: number, yaw: number?): CFrame
		return origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local function flat(
		size: Vector3,
		cf: CFrame,
		color: Color3,
		transparency: number,
		material: Enum.Material?
	): BasePart
		local part = Kit.block(
			folder,
			size,
			cf,
			color,
			{ material = material or M.SmoothPlastic, collide = false, shadow = false }
		)
		part.Transparency = transparency
		part.CanQuery = false
		part.CanTouch = false
		return part
	end
	local function solid(
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material,
		detail: boolean?
	): BasePart
		local part =
			Kit.block(folder, size, cf, color, { material = material, collide = not detail, shadow = true })
		if detail then
			part:AddTag("Detail")
		end
		return part
	end
	local function disc(
		d: number,
		thick: number,
		cf: CFrame,
		color: Color3,
		material: Enum.Material,
		collide: boolean
	)
		return Kit.cylinder(folder, thick, d, cf * CFrame.Angles(0, 0, math.rad(90)), color, {
			material = material,
			collide = collide,
			shadow = collide,
		})
	end

	-- grime, y 0.005-0.009: round the lamp standards' feet
	for _, z in { -15, 43 } do
		for _, x in POSTS_X do
			local ring = disc(3.2, 0.004, at(x, 0.007, z), GRIME, M.SmoothPlastic, false)
			ring.Transparency = 0.6
			ring.CanQuery = false
		end
	end

	-- the puddle, on the pale flags past the tile walk: a small dark pool with a thin ragged edge, glass so it holds the lamps' highlights.
	-- Part-built, overlapping shards at their own heights (y 0.008-0.026) until its mesh is uploaded.
	do
		local pool = cluster("Puddle")
		for i, shard in
			{
				{ -84, 33.0, 2.2, 1.3, 14 },
				{ -83.3, 33.6, 1.5, 0.9, -28 },
				{ -84.9, 32.5, 1.2, 0.8, 52 },
				{ -82.9, 32.4, 0.9, 0.55, 8 },
				{ -85.2, 33.6, 0.8, 0.5, -60 },
				{ -84.2, 34.1, 0.7, 0.35, 33 },
			}
		do
			local water = flat(
				Vector3.new(shard[3], 0.004, shard[4]),
				at(shard[1], 0.006 + i * 0.003, shard[2], shard[5]),
				WATER,
				0.1,
				M.Glass
			)
			water.Reflectance = 0.5
		end
		dress(pool, { { key = "puddle", cframe = at(-84, 0, 33, 14), scale = 1 } })
		folder = root
	end
	local leak = flat(Vector3.new(0.2, 0.2, 0.2), at(-84, 24, 33), WATER, 1)
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "Drip"
	drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drip.Color = ColorSequence.new(Color3.fromRGB(190, 200, 214))
	drip.LightInfluence = 1
	drip.Rate = 1.3
	drip.Lifetime = NumberRange.new(1.25, 1.25)
	drip.Speed = NumberRange.new(0, 0)
	drip.Acceleration = Vector3.new(0, -30, 0) -- falls the 24 studs in about 1.25 s
	drip.Size = NumberSequence.new(0.09)
	drip.Transparency = NumberSequence.new(0.35)
	drip.Parent = leak
	leak:AddTag("Detail")
	-- where it lands: a fleck thrown up from the water now and then
	local landing = flat(Vector3.new(0.2, 0.2, 0.2), at(-84, 0.05, 33), WATER, 1)
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	splash.Color = ColorSequence.new(Color3.fromRGB(200, 210, 222))
	splash.LightInfluence = 1
	splash.Rate = 1.3
	splash.Lifetime = NumberRange.new(0.18, 0.3)
	splash.Speed = NumberRange.new(2, 3.5)
	splash.SpreadAngle = Vector2.new(35, 35)
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Acceleration = Vector3.new(0, -30, 0)
	splash.Size = NumberSequence.new(0.06)
	splash.Transparency = NumberSequence.new(0.3)
	splash.Parent = landing
	landing:AddTag("Detail")

	-- the back wall, what a Hand sees from the spawn ring (BACK_Z = 72 its brick face, the green dado
	-- y 1.2-5.2 standing 0.17 proud of it, the departure board x -21..21 from y 9.5)
	local BACK = 72
	local SOOT = Color3.fromRGB(30, 24, 20)
	local DAMP = Color3.fromRGB(52, 34, 28)
	local MORTAR = Color3.fromRGB(112, 108, 98)
	local function onWall(w: number, h: number, x: number, y: number, depth: number, color: Color3, t: number)
		flat(Vector3.new(w, h, 0.01), at(x, y, BACK - depth), color, t)
	end
	-- soot and rain run down from under the board's frame and the cornice, fading as they go
	for i, run in
		{
			{ -19, 1.4, 9.4 },
			{ -12.5, 0.9, 7.8 },
			{ -6, 1.6, 9.0 },
			{ 3.5, 1.1, 8.2 },
			{ 11, 1.8, 9.3 },
			{ 17.5, 0.8, 7.6 },
			{ -31, 1.2, 11.5 },
			{ -26, 2.2, 12.5 },
			{ 23.5, 1.5, 12 },
		}
	do
		local x, w, top = run[1], run[2], run[3]
		local length = top - 5.2
		-- the head of the run is darkest, its tail lighter (three lengths, each a hair nearer)
		for k = 0, 2 do
			local h = length * (1 - k * 0.3)
			onWall(
				w * (1 - k * 0.2),
				h,
				x + (k - 1) * 0.08,
				top - h / 2,
				0.03 + k * 0.012 + i * 0.0005,
				SOOT,
				0.8 - k * 0.1
			)
		end
	end
	-- damp: broad stains where the gutter overflows behind the wall
	for i, blot in { { -29, 7.6, 6.5, 4.2 }, { 24.8, 7.2, 5.2, 3.6 }, { -16, 31, 9, 5 }, { 14, 30, 8, 4.5 } } do
		onWall(blot[3], blot[4], blot[1], blot[2], 0.08 + i * 0.012, DAMP, 0.55)
		onWall(blot[3] * 0.6, blot[4] * 0.55, blot[1] + 0.4, blot[2] - 0.3, 0.07 + i * 0.012, DAMP, 0.45)
	end
	-- chipped dado tiles, the grey mortar showing (0.01 proud of the tiles' face)
	for _, chip in
		{
			{ -33.2, 4.4 },
			{ -24.6, 2.1 },
			{ -9.4, 4.7 },
			{ 7.8, 3.3 },
			{ 16.2, 4.6 },
			{ 21.9, 1.8 },
			{ -15.7, 1.5 },
		}
	do
		onWall(0.62, 0.62, chip[1], chip[2], 0.18, MORTAR, 0)
	end
	-- boot-dirt kicked up the foot of the dado, darkest at the bottom (just proud of the chips)
	for _, run in { { -112, 28 }, { 44, 112 } } do
		local w = run[2] - run[1]
		onWall(w, 0.7, (run[1] + run[2]) / 2, 1.55, 0.19, GRIME, 0.45)
		onWall(w, 0.9, (run[1] + run[2]) / 2, 2.35, 0.2, GRIME, 0.72)
	end
	-- bills pasted straight onto the brick either side of the board, unframed and askew, a newer
	-- sheet half over an older one (PosterArt draws them: torn corners, damp, soot at the foot)
	for i, bill in
		{
			{ -29.6, 9.4, -4, "fog", 0.16 },
			{ -27.4, 8.6, 3, "coal", 0.2 },
			{ 25.2, 9.6, 5, "moon", 0.16 },
			{ 23.6, 8.4, -2, "coast", 0.2 },
		} :: { { any } }
	do
		local sheet = flat(
			Vector3.new(4.6, 5.9, 0.01),
			at(bill[1], bill[2], BACK - bill[5] - i * 0.002) * CFrame.Angles(0, 0, math.rad(bill[3])),
			PosterArt.paper(bill[4]),
			0
		)
		sheet.Name = "Bill"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0.7
		gui.Parent = sheet
		PosterArt.draw(gui, bill[4])
	end
	-- spills on the flags in front of the board, where the crowd waits (y 0.011-0.02)
	for i, spill in { { -9, 58.5, 2.6 }, { 6.5, 61, 1.8 }, { 15, 56.8, 2.2 }, { -17, 61.5, 1.5 } } do
		local stain =
			disc(spill[3], 0.004, at(spill[1], 0.011 + i * 0.002, spill[2]), GRIME, M.SmoothPlastic, false)
		stain.Transparency = 0.55
		stain.CanQuery = false
	end
	-- dirt banked where the flags meet the slate border along the back wall
	flat(Vector3.new(214, 0.004, 0.9), at(0, 0.004, 68.4), GRIME, 0.5)

	-- luggage and crates against the back wall either side of the board (clear of the booth, x 28-44)
	do
		solid(Vector3.new(2.6, 1.8, 1.8), at(-30.5, 0.9, 67.6, 6), Color3.fromRGB(104, 80, 54), M.WoodPlanks)
		solid(Vector3.new(2.0, 1.4, 1.5), at(-30.2, 2.5, 67.7, -9), Color3.fromRGB(96, 72, 48), M.WoodPlanks)
		solid(Vector3.new(2.4, 1.2, 1.6), at(-27.4, 0.6, 67.9, 18), LEATHER, M.Leather)
		solid(Vector3.new(0.14, 1.26, 1.68), at(-27.4, 0.6, 67.9, 18), BRASS, M.Metal, true)
		solid(Vector3.new(1.3, 0.9, 0.7), at(-33.4, 0.45, 67.3, -14), CANVAS, M.Fabric)
		solid(Vector3.new(2.2, 1.6, 1.6), at(23.2, 0.8, 67.8, -5), Color3.fromRGB(110, 86, 58), M.WoodPlanks)
		solid(Vector3.new(1.6, 1.0, 1.2), at(23.4, 2.1, 67.6, 12), Color3.fromRGB(150, 118, 78), M.Cardboard)
		solid(
			Vector3.new(1.62, 0.06, 0.08),
			at(23.4, 2.62, 67.6, 12),
			Color3.fromRGB(120, 30, 26),
			M.Fabric,
			true
		)
		flat(Vector3.new(0.5, 0.3, 0.02), at(23.2, 1.0, 66.99), PAPER, 0):AddTag("Detail") -- a shipping label
	end

	-- a porter's barrow at the tea-room end: iron frame, two wheels, two trunks and a hatbox
	do
		local x, z, yaw = -103.5, 34, 8
		local frame = at(x, 0, z, yaw)
		local barrow = cluster("Barrow")
		solid(Vector3.new(4.4, 0.3, 2.2), frame * CFrame.new(0, 0.95, 0), WOOD, M.WoodPlanks)
		for _, side in { -1, 1 } do
			solid(
				Vector3.new(4.8, 0.18, 0.18),
				frame * CFrame.new(-0.2, 1.1, side * 1.05),
				IRON,
				M.Metal,
				true
			)
			-- a wheel, its axle across the barrow
			Kit.cylinder(
				folder,
				0.22,
				1.5,
				frame * CFrame.new(1.4, 0.75, side * 1.2) * CFrame.Angles(0, math.rad(90), 0),
				IRON,
				{
					material = M.Metal,
					collide = false,
					shadow = true,
				}
			):AddTag("Detail")
			solid(
				Vector3.new(0.18, 0.9, 0.18),
				frame * CFrame.new(-1.9, 0.45, side * 0.9),
				IRON,
				M.Metal,
				true
			)
		end
		solid(
			Vector3.new(2.2, 1.3, 1.9),
			frame * CFrame.new(-0.9, 1.75, 0) * CFrame.Angles(0, math.rad(4), 0),
			LEATHER,
			M.Leather
		)
		solid(
			Vector3.new(0.12, 1.32, 1.94),
			frame * CFrame.new(-0.4, 1.75, 0) * CFrame.Angles(0, math.rad(4), 0),
			BRASS,
			M.Metal,
			true
		)
		solid(
			Vector3.new(1.8, 0.9, 1.5),
			frame * CFrame.new(1.05, 1.55, 0.1) * CFrame.Angles(0, math.rad(-6), 0),
			CANVAS,
			M.Fabric
		)
		disc(1.0, 0.7, frame * CFrame.new(1.0, 2.35, 0.1), Color3.fromRGB(110, 48, 44), M.Fabric, false):AddTag(
			"Detail"
		) -- the hatbox
		dress(barrow, {
			{ key = "barrow", cframe = frame, scale = 1 },
			{
				key = "trunk",
				cframe = frame * CFrame.new(-0.9, 1.06, 0) * CFrame.Angles(0, math.rad(4), 0),
				scale = 1,
			},
			{
				key = "trunk",
				cframe = frame * CFrame.new(1.05, 1.06, 0.1) * CFrame.Angles(0, math.rad(-96), 0),
				scale = 0.75,
			},
			{ key = "hatbox", cframe = frame * CFrame.new(1.0, 2.0, 0.1), scale = 1 },
		})
	end

	-- mail sacks and parcels against the back wall, clear of the back door
	do
		-- canvas mail bags lying on their sides, round-bellied, their necks tied off
		local sacks = cluster("MailSacks")
		local bags: { Placed } = {}
		for i, sack in { { 58, 67.4, 0 }, { 59.9, 67.7, 14 }, { 58.9, 66.2, -10 } } do
			table.insert(
				bags,
				{ key = "sack", cframe = at(sack[1], 0, sack[2], sack[3]), scale = 1.05 - i * 0.05 }
			)
			local d = 1.25 - i * 0.08
			local bag = Kit.cylinder(folder, 1.7, d, at(sack[1], d / 2, sack[2], sack[3]), CANVAS, {
				material = M.Fabric,
				collide = true,
				shadow = true,
			})
			bag.Name = "MailSack"
			Kit.cylinder(
				folder,
				0.4,
				d * 0.45,
				at(sack[1], d / 2, sack[2], sack[3]) * CFrame.new(1.02, 0, 0),
				CANVAS,
				{
					material = M.Fabric,
					collide = false,
					shadow = false,
				}
			)
				:AddTag("Detail")
			Kit.cylinder(
				folder,
				0.08,
				d * 0.5,
				at(sack[1], d / 2, sack[2], sack[3]) * CFrame.new(0.86, 0, 0),
				Color3.fromRGB(92, 70, 44),
				{
					material = M.Fabric,
					collide = false,
					shadow = false,
				}
			):AddTag("Detail")
		end
		dress(sacks, bags)
		folder = root
		solid(Vector3.new(1.4, 0.9, 1.0), at(62.4, 0.45, 67.8, -4), Color3.fromRGB(150, 118, 78), M.Cardboard)
		solid(
			Vector3.new(1.0, 0.7, 0.8),
			at(62.3, 1.25, 67.8, 10),
			Color3.fromRGB(162, 130, 90),
			M.Cardboard,
			true
		)
		solid(
			Vector3.new(1.42, 0.06, 0.08),
			at(62.4, 0.92, 67.8, -4),
			Color3.fromRGB(120, 30, 26),
			M.Fabric,
			true
		) -- string
	end

	-- milk churns at the platform's end
	for i, churn in { { 104.5, 2.2 }, { 105.8, 3.4 }, { 103.6, 3.9 } } do
		local can = cluster(`Churn{i}`)
		dress(can, { { key = "churn", cframe = at(churn[1], 0, churn[2], i * 47), scale = 1 } })
		disc(1.3, 2.2, at(churn[1], 1.1, churn[2]), TIN, M.Metal, true)
		disc(0.9, 0.35, at(churn[1], 2.37, churn[2]), TIN, M.Metal, false):AddTag("Detail")
		disc(1.36, 0.12, at(churn[1], 1.6, churn[2]), Color3.fromRGB(120, 122, 120), M.Metal, false):AddTag(
			"Detail"
		)
	end

	folder = root

	-- in the spawn ring's sightline: luggage piled at the foot of the lamp standard right of the board walk,
	-- clear of the spawn ring and the passengers' corridor (z 47.5)
	do
		local pile = cluster("Pile")
		solid(Vector3.new(2.2, 1.25, 1.3), at(8.6, 0.625, 40.6, -12), LEATHER, M.Leather)
		solid(Vector3.new(0.14, 1.29, 1.36), at(8.6, 0.625, 40.6, -12), BRASS, M.Metal, true)
		solid(Vector3.new(1.6, 0.9, 1.1), at(8.9, 1.7, 40.5, 9), CANVAS, M.Fabric)
		disc(1.0, 0.7, at(10.4, 0.35, 41.8), Color3.fromRGB(110, 48, 44), M.Fabric, true)
		-- an umbrella leant against the case
		Kit.cylinder(pile, 2.2, 0.08, at(7.2, 1.0, 41.2) * CFrame.Angles(0, 0, math.rad(78)), IRON, {
			material = M.Metal,
			collide = false,
			shadow = true,
		}):AddTag("Detail")
		Kit.cylinder(
			pile,
			1.3,
			0.34,
			at(7.35, 0.75, 41.2) * CFrame.Angles(0, 0, math.rad(78)),
			Color3.fromRGB(26, 24, 26),
			{
				material = M.Fabric,
				collide = false,
				shadow = true,
			}
		):AddTag("Detail")
		solid(Vector3.new(1.5, 0.7, 1.0), at(8.7, 2.5, 40.4, -20), LEATHER, M.Leather) -- a valise on top
		-- a pale travelling coat thrown over the pile, a hat left on top: it catches the lamp
		local coat = Color3.fromRGB(142, 128, 104)
		flat(
			Vector3.new(1.7, 0.08, 1.3),
			at(8.8, 2.9, 40.4, -20) * CFrame.Angles(0, 0, math.rad(6)),
			coat,
			0,
			M.Fabric
		)
		flat(
			Vector3.new(1.5, 1.9, 0.08),
			at(8.9, 2.0, 39.62, -20) * CFrame.Angles(math.rad(-8), 0, 0),
			coat,
			0,
			M.Fabric
		)
		flat(
			Vector3.new(0.42, 1.6, 0.08),
			at(7.85, 2.2, 39.9, -20) * CFrame.Angles(math.rad(-6), 0, math.rad(-14)),
			coat,
			0,
			M.Fabric
		) -- a sleeve
		flat(
			Vector3.new(1.55, 0.22, 0.32),
			at(8.85, 2.98, 39.75, -20),
			Color3.fromRGB(96, 74, 56),
			0,
			M.Fabric
		) -- the collar
		disc(1.05, 0.06, at(9.3, 2.98, 40.6), Color3.fromRGB(28, 24, 22), M.Fabric, false) -- a bowler: brim
		disc(0.72, 0.42, at(9.3, 3.22, 40.6), Color3.fromRGB(28, 24, 22), M.Fabric, false) -- and crown
		dress(pile, {
			{ key = "trunk", cframe = at(8.6, 0, 40.6, -12), scale = 1 },
			{ key = "trunk", cframe = at(8.9, 1.25, 40.5, 99), scale = 0.7 },
			{ key = "trunk", cframe = at(8.7, 2.15, 40.4, -20), scale = 0.55 },
			{ key = "hatbox", cframe = at(10.4, 0, 41.8), scale = 1 },
			{ key = "coat", cframe = at(8.8, 1.3, 40.1, -20), scale = 1 },
		})
		folder = root
	end
	-- a coat left over the back of the bench at (30, 52), a hat on the seat beside it
	do
		local coat = Color3.fromRGB(44, 40, 46)
		flat(
			Vector3.new(1.3, 1.5, 0.1),
			at(33.3, 2.55, 50.75, 0) * CFrame.Angles(math.rad(-12), 0, 0),
			coat,
			0,
			M.Fabric
		)
		flat(
			Vector3.new(1.2, 1.1, 0.1),
			at(33.3, 2.9, 50.35, 0) * CFrame.Angles(math.rad(18), 0, 0),
			coat,
			0,
			M.Fabric
		)
		flat(Vector3.new(1.32, 0.22, 0.5), at(33.3, 3.38, 50.55), Color3.fromRGB(70, 50, 40), 0, M.Fabric) -- the collar
		disc(1.0, 0.06, at(33.4, 1.9, 52.6), Color3.fromRGB(22, 20, 22), M.Fabric, false):AddTag("Detail") -- brim
		disc(0.7, 0.5, at(33.4, 2.17, 52.6), Color3.fromRGB(22, 20, 22), M.Fabric, false):AddTag("Detail") -- crown
	end

	-- litter: dropped tickets and a newspaper (y 0.02-0.04)
	for i, ticket in
		{
			{ -12, 6, 20 },
			{ 9, -3, -35 },
			{ 15, 13, 60 },
			{ -7, 40, 5 },
			{ 4, 50, -70 },
			{ -31, 12, 110 },
			{ 33, 54, 15 },
			{ 47, 24, -25 },
		}
	do
		flat(Vector3.new(0.55, 0.02, 0.3), at(ticket[1], 0.02 + i * 0.002, ticket[2], ticket[3]), PAPER, 0):AddTag(
			"Detail"
		)
	end
	flat(Vector3.new(1.5, 0.03, 1.05), at(-26.5, 0.035, 11.6, 23), Color3.fromRGB(196, 190, 176), 0):AddTag(
		"Detail"
	)
	flat(Vector3.new(0.7, 0.03, 1.0), at(-25.6, 0.05, 12.2, 51), Color3.fromRGB(188, 182, 168), 0):AddTag(
		"Detail"
	)
end

return HallWear
