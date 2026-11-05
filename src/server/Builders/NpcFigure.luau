--!strict
--[[
	A resident of the train (Config/Npcs), dressed from the shared period kit
	(Builders/OutfitKit) at `cframe`: feet on y = 0, facing the frame's -Z. Anchored and
	still; the body and skirt collide so the crew walk round them.

	Two upgrades over the kit figure, both built on their own thread so server start never waits
	and both falling back to the kit figure if anything fails to load (or in a headless build, the
	Lune audit):

	  rig   (`def.rig`) the same blocky R6 body the crew wear (as CrewService's buildR6), in the
	        resident's own Shirt, Pants and face, with mesh pieces welded to its limbs. Its root is
	        anchored; it carries the Procedural attribute and the ResidentRig tag, so every client
	        animates it (CharacterAnimator: idle breathing, a look toward you when you are near).
	  mesh  (`def.mesh`) one sculpted mesh standing over the kit figure.

	Either way the kit figure stays, invisible, for collision and the Talk prompt.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Npcs = require(ReplicatedStorage.Shared.Config.Npcs)
local OutfitKit = require(script.Parent.OutfitKit)

export type Figure = { model: Model, body: BasePart }

local NpcFigure = {}

local RIG_TAG = "ResidentRig"

local function assets(): any?
	local ok, service = pcall(function()
		return game:GetService("AssetService")
	end)
	return if ok then service else nil
end

local function color(rgb: { number }?, fallback: Color3): Color3
	return if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else fallback
end

local function hideKit(model: Model)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") or child:IsA("Decal") then
			(child :: any).Transparency = 1
		end
	end
end

local function quiet(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

-- The R6 body in the resident's clothes, or nil if it could not be made.
local function buildRig(def: Npcs.NpcDef, spec: Npcs.Rig): Model?
	local look = def.look
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = color(look and look.skin, Color3.fromRGB(226, 178, 140))
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = color(look and look.coat, Color3.fromRGB(58, 66, 82))
		local legs = color(look and look.lower, Color3.fromRGB(46, 42, 40))
		description.LeftLegColor = legs
		description.RightLegColor = legs
		description.Shirt = spec.shirt or 0
		description.Pants = spec.pants or 0
		description.Face = spec.face or 0
		local body = Players:CreateHumanoidModelFromDescription(
			description,
			Enum.HumanoidRigType.R6,
			Enum.AssetTypeVerification.Always
		)
		description:Destroy()
		return body
	end)
	if not ok or result == nil then
		warn(`NpcFigure: {def.id} R6 body did not build: {result}`)
		return nil
	end
	local rig = result :: Model
	for _, descendant in rig:GetDescendants() do
		if descendant.Name == "Animate" and (descendant:IsA("LocalScript") or descendant:IsA("Script")) then
			descendant:Destroy()
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	return rig
end

-- Welds each mesh piece to its limb. Pieces whose mesh fails to load are left off.
local function addPieces(def: Npcs.NpcDef, rig: Model, spec: Npcs.Rig, service: any)
	for _, piece in spec.pieces do
		local limb = rig:FindFirstChild(piece.limb)
		if not (limb and limb:IsA("BasePart")) then
			continue
		end
		local loaded, mesh = pcall(function()
			return service:CreateMeshPartAsync(`rbxassetid://{piece.mesh}`)
		end)
		if not loaded or mesh == nil then
			warn(`NpcFigure: {def.id} piece {piece.name} ({piece.mesh}) did not load: {mesh}`)
			continue
		end
		local part = mesh :: MeshPart
		part.Name = piece.name
		part.TextureID = `rbxassetid://{piece.texture}`
		part.Color = Color3.new(1, 1, 1)
		part.Anchored = false
		quiet(part)
		local o = piece.offset
		part.CFrame = limb.CFrame
			* CFrame.new(o[1], o[2], o[3])
			* CFrame.Angles(0, math.rad(piece.yaw or 0), 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = part
		weld.Parent = part
		part.Parent = rig
	end
end

local function dressRig(def: Npcs.NpcDef, model: Model, cframe: CFrame, spec: Npcs.Rig): boolean
	local service = assets()
	if service == nil then
		return false
	end
	local rig = buildRig(def, spec)
	if rig == nil or model.Parent == nil then
		return false
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		rig:Destroy()
		return false
	end
	-- the crew's procedural poses assume this rig; the kit figure keeps collision and the prompt
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			quiet(part)
		end
	end
	addPieces(def, rig, spec, service)
	rig.Name = "Rig"
	rig:PivotTo(cframe * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2 + 2, 0))
	root.Anchored = true
	rig:SetAttribute("Procedural", true)
	rig:SetAttribute("Resident", def.id)
	rig.Parent = model
	CollectionService:AddTag(rig, RIG_TAG)
	hideKit(model)
	-- hideKit hid the rig too; show it again (its root stays invisible)
	for _, part in rig:GetDescendants() do
		if (part:IsA("BasePart") and part ~= root) or part:IsA("Decal") then
			(part :: any).Transparency = 0
		end
	end
	return true
end

local function dressMesh(def: Npcs.NpcDef, model: Model, cframe: CFrame)
	local spec = def.mesh
	local service = assets()
	if spec == nil or service == nil then
		return
	end
	local loaded, mesh = pcall(function()
		return service:CreateMeshPartAsync(`rbxassetid://{spec.meshId}`)
	end)
	if not loaded or mesh == nil or model.Parent == nil then
		if not loaded then
			warn(`NpcFigure: {def.id} mesh ({spec.meshId}) did not load: {mesh}`)
		end
		return
	end
	local part = mesh :: MeshPart
	part.Name = "Figure"
	part.TextureID = `rbxassetid://{spec.textureId}`
	part.Color = Color3.new(1, 1, 1)
	part.Anchored = true
	quiet(part)
	-- the mesh's box is centred on its bounds: lift it so its feet sit on the floor
	part.CFrame = cframe * CFrame.new(0, part.Size.Y / 2, 0)
	hideKit(model)
	part.Parent = model
end

local function dress(def: Npcs.NpcDef, model: Model, cframe: CFrame)
	local rig = def.rig
	if rig and dressRig(def, model, cframe, rig) then
		return
	end
	dressMesh(def, model, cframe)
end

function NpcFigure.build(def: Npcs.NpcDef, cframe: CFrame, parent: Instance): Figure
	local figure = OutfitKit.figure(parent, cframe, def.look :: Npcs.Look, { armR = 30 })
	figure.model.Name = `Npc_{def.id}`
	if def.rig or def.mesh then
		task.spawn(dress, def, figure.model, cframe)
	end
	return { model = figure.model, body = figure.body }
end

return NpcFigure
