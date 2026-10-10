--!strict
--[[
	Dresses a freshly built primitive train in its Blender exterior (docs/train-exterior).

	The meshes are uploaded once and listed in Config/TrainShell: per car a shell, gilt trim,
	roof, door-lamp glass and name board, plus a shared kit (door leaves, bogie, wheel). Plugins
	cannot write MeshId, so the meshes are made here from their ids (AssetService) and their
	textures come from SurfaceAppearance templates synced by Rojo (src/server/TrainLooks.model.json).

	The primitives stay the train's body: anything a player stands on or walks into keeps its
	collision and is only made invisible where a mesh now covers it. Purely decorative primitives
	that a mesh replaces are moved to ServerStorage.TrainExteriorArchive (so they can be looked
	at, and cost nothing on clients). Kit pieces go on the CFrame of the primitive they stand in
	for and take over its animation attributes (DoorSlide, WheelRadius, WheelPivot), so
	TrainVisualsController animates them unchanged. Livery attributes (Body, Trim, Roof, Accent,
	Lamp) go on the meshes too, so TrainBuilder.applyLivery still repaints them.

	If any mesh fails to load the train is left as it was; headless (the Lune audit) this does
	nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.TrainShell)

local TrainShell = {}

-- parts of the primitive train that something else finds by name or attribute
local KEEP_NAMES = {
	DoorBlocker = true,
	Seat = true,
	ChimneyTop = true,
	SteamVent = true,
	Firebox = true,
	FireFlame = true,
	StoveGlow = true,
	LanternFlame = true,
	MastLamp = true,
	SignalMast = true,
}
local KEEP_ATTRIBUTES = { "BreachAnchor", "CoalTier", "CrankRadius" }
local MOVED = { "DoorSlide", "WheelRadius", "WheelPivot" }
local WALL_OUT = 6.45 -- a part wholly beyond this |z| is outside the side walls, under the skin
local WALL_FACE, WALL_IN = 6.56, 5.95 -- a side wall: outer face up to the skin, inner face clear of the lining
local UNDER = -2.3 -- a part wholly below this is bogie: its frames and bolster
local GLASS_IN = 0.13 -- door glass moves this far in, into the new leaf's glazing slit
local LAMP = Color3.fromRGB(255, 206, 150)
local TEAK = Vector3.new(0.7, 2.5, 2.5) -- a Mansell wheel's teak centre, inside its tyre

local templates: { [number]: MeshPart } = {}

local function loadTemplates(ids: { number }): boolean
	local AssetService = game:GetService("AssetService")
	local pending, failed = 0, false
	for _, id in ids do
		if not templates[id] then
			pending += 1
			task.spawn(function()
				local ok, part = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromAssetId(id), {
						CollisionFidelity = Enum.CollisionFidelity.Box,
						RenderFidelity = Enum.RenderFidelity.Automatic,
					})
				end)
				if ok and part then
					templates[id] = part
				else
					warn(`[TrainShell] mesh {id} did not load: {part}`)
					failed = true
				end
				pending -= 1
			end)
		end
	end
	while pending > 0 do
		task.wait()
	end
	return not failed
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function place(id: number, cframe: CFrame, size: { number }, parent: Instance): MeshPart
	local part = templates[id]:Clone()
	part.Size = v3(size)
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CollisionGroup = "Train"
	part.Parent = parent
	return part
end

local function look(looks: Instance, name: string?, part: MeshPart)
	local template = if name then looks:FindFirstChild(name) else nil
	if template then
		template:Clone().Parent = part
	end
end

local function kept(part: BasePart): boolean
	if KEEP_NAMES[part.Name] or string.sub(part.Name, 1, 7) == "Breach_" then
		return true
	end
	for _, attr in KEEP_ATTRIBUTES do
		if part:GetAttribute(attr) ~= nil then
			return true
		end
	end
	return false
end

-- Moves a decorative primitive out of the train, or hides one that still has a job (collision).
local function retire(part: BasePart, archive: Folder)
	if part.CanCollide then
		part.Transparency = 1
		part.CastShadow = false
		for _, child: Instance in part:GetChildren() do
			if child:IsA("SurfaceGui") or child:IsA("Decal") or child:IsA("Texture") then
				(child :: Instance).Parent = archive
			end
		end
	else
		for _, attr in MOVED do
			part:SetAttribute(attr, nil)
		end
		part.Parent = archive
	end
end

-- The first colour a car's primitives wear in each livery role (what applyLivery last set).
local function liveryColors(parts: { BasePart }): { [string]: Color3 }
	local colors = {}
	for _, part in parts do
		local role = part:GetAttribute("Livery")
		if type(role) == "string" and colors[role] == nil then
			colors[role] = part.Color
		end
	end
	return colors
end

function TrainShell.dress(model: Model, origin: CFrame): boolean
	if not Config.Enabled then
		return false
	end
	local okStorage, ServerStorage = pcall(game.GetService, game, "ServerStorage")
	local okAssets = pcall(game.GetService, game, "AssetService")
	if not (okStorage and okAssets) then
		return false -- headless
	end
	local looks = script.Parent.Parent:FindFirstChild("TrainLooks")
	if not looks then
		warn("[TrainShell] Server.TrainLooks is missing (src/server/TrainLooks.model.json)")
		return false
	end
	local ids = {}
	for _, car in Config.Cars do
		for _, piece in car.pieces do
			table.insert(ids, piece.mesh)
		end
	end
	for _, piece in Config.Kit do
		table.insert(ids, piece.mesh)
	end
	if not loadTemplates(ids) then
		return false
	end

	local archiveRoot = ServerStorage:FindFirstChild("TrainExteriorArchive")
	if not archiveRoot then
		archiveRoot = Instance.new("Folder")
		archiveRoot.Name = "TrainExteriorArchive"
		archiveRoot.Parent = ServerStorage
	end
	local archive = Instance.new("Folder")
	archive.Name = `{model.Name}{#archiveRoot:GetChildren() + 1}`
	archive.Parent = archiveRoot
	local exterior = Instance.new("Folder")
	exterior.Name = "Exterior"

	local all: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(all, part)
		end
	end

	for carName, car in Config.Cars do
		local folder = Instance.new("Folder")
		folder.Name = carName
		folder.Parent = exterior
		local mine: { BasePart } = {}
		local locals: { [BasePart]: CFrame } = {}
		for _, part in all do
			local cf = origin:ToObjectSpace(part.CFrame)
			if cf.X >= car.x0 - 0.3 and cf.X <= car.x1 + 0.3 then
				table.insert(mine, part)
				locals[part] = cf
			end
		end
		local colors = liveryColors(mine)

		for name, piece in car.pieces do
			if string.sub(name, 1, 8) == "DoorLeaf" then
				continue -- the car's own leaves go on its door panels below
			end
			local part = place(piece.mesh, origin * CFrame.new(v3(piece.center)), piece.size, folder)
			part.Name = `{carName}{name}`
			part.CastShadow = piece.shadow
			if piece.livery then
				part:SetAttribute("Livery", piece.livery)
				part.Color = colors[piece.livery] or (if piece.livery == "Lamp" then LAMP else part.Color)
			else
				part.Color = Color3.new(1, 1, 1)
			end
			if piece.livery == "Lamp" then
				part.Material = Enum.Material.Neon
			end
			if piece.color then
				part.Color = Color3.new(piece.color[1], piece.color[2], piece.color[3])
			end
			if piece.transparency then
				part.Transparency = piece.transparency
			end
			if piece.light then
				-- one light per door lamp, at the lamp (a round-1 car has one lamp: the lens itself)
				local spots: { { number } } = car.lights or { piece.center }
				for _, at in spots do
					local holder = Instance.new("Attachment")
					holder.Name = "LampLight"
					holder.Parent = part
					holder.WorldCFrame = origin * CFrame.new(v3(at))
					local light = Instance.new("PointLight")
					light.Color = LAMP
					light.Range = Config.LampLight.Range
					light.Brightness = Config.LampLight.Brightness
					light.Shadows = false
					light.Parent = holder
				end
			end
			look(looks, piece.look, part)
		end

		for _, part in mine do
			if kept(part) then
				continue
			end
			local cf = locals[part]
			local half = part.Size / 2
			local ez = math.abs(cf.RightVector.Z) * half.X
				+ math.abs(cf.UpVector.Z) * half.Y
				+ math.abs(cf.LookVector.Z) * half.Z
			local ey = math.abs(cf.RightVector.Y) * half.X
				+ math.abs(cf.UpVector.Y) * half.Y
				+ math.abs(cf.LookVector.Y) * half.Z
			local outside = math.abs(cf.Z) - ez >= WALL_OUT
			-- round 2 carves its panels into the skin, deeper than the side wall's outer face:
			-- the wall (and the window's arch decoration in it) hides, keeping its collision
			local wall = car.hideWalls == true
				and math.abs(cf.Z) + ez <= WALL_FACE
				and math.abs(cf.Z) + ez >= WALL_OUT
				and math.abs(cf.Z) - ez >= WALL_IN
			local arch = car.hideWalls == true
				and part.Material == Enum.Material.Wood
				and math.abs(math.abs(cf.Z) - 6.25) < 0.05
				and ez <= 0.16
			local under = cf.Y + ey <= UNDER
			local roof = part:GetAttribute("Livery") == "Roof"

			if part.Name == "DoorPanel" then
				if part.Material == Enum.Material.Glass then
					-- into the leaf's slit; it keeps sliding with the leaf
					local side = if cf.Z > 0 then 1 else -1
					part.CFrame = origin * (cf - Vector3.new(0, 0, side * GLASS_IN))
				else
					local slide = part:GetAttribute("DoorSlide") :: number?
					local kitName = if slide and slide < 0 then "DoorLeafL" else "DoorLeafR"
					-- a car with its own heavy leaves (Workshop, Stores) uses them on the door they were modelled on
					local own = car.pieces[kitName]
					if own and math.abs(own.center[1] - cf.X) < 2 and own.center[3] * cf.Z > 0 then
						local leaf = place(own.mesh, origin * CFrame.new(v3(own.center)), own.size, folder)
						leaf.Name = kitName
						leaf.Color = colors[own.livery or "Accent"] or part.Color
						leaf.CastShadow = own.shadow
						leaf:SetAttribute("Livery", own.livery)
						leaf:SetAttribute("DoorSlide", slide)
						look(looks, own.look, leaf)
						retire(part, archive)
						continue
					end
					local kit = Config.Kit[kitName]
					local leaf = place(
						kit.mesh,
						part.CFrame * CFrame.new(v3(kit.center) - v3(kit.anchor)),
						kit.size,
						folder
					)
					leaf.Name = kitName
					leaf.Color = part.Color
					leaf:SetAttribute("Livery", kit.livery)
					leaf:SetAttribute("DoorSlide", slide)
					look(looks, kit.look or Config.KitLook, leaf)
					retire(part, archive)
				end
			elseif part:GetAttribute("WheelRadius") ~= nil and cf.Y < 0 then
				local kit = Config.Kit.Wheel
				local wheel = place(
					kit.mesh,
					part.CFrame * CFrame.new(v3(kit.center) - v3(kit.anchor)),
					kit.size,
					folder
				)
				wheel.Name = "Wheel"
				wheel.Color = Color3.new(1, 1, 1)
				for _, attr in MOVED do
					wheel:SetAttribute(attr, part:GetAttribute(attr))
				end
				look(looks, kit.look or Config.KitLook, wheel)
				retire(part, archive)
			elseif under or (cf.Y < 0 and part.Size:FuzzyEq(TEAK, 0.01)) then
				local size = part.Size
				if math.abs(size.X - 2.4) < 0.01 and math.abs(size.Z - 9.6) < 0.01 then
					local kit = Config.Kit.Bogie
					local bogie = place(
						kit.mesh,
						part.CFrame * CFrame.new(v3(kit.center) - v3(kit.anchor)),
						kit.size,
						folder
					)
					bogie.Name = "Bogie"
					bogie.Color = Color3.new(1, 1, 1)
					look(looks, kit.look or Config.KitLook, bogie)
				end
				retire(part, archive)
			elseif outside or roof or wall or arch then
				retire(part, archive)
			end
		end
	end
	exterior.Parent = model
	return true
end

return TrainShell
