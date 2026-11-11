--!strict
--[[
	One of the Depot's passive people (Config/Passengers): a walking R6 body dressed in the shared
	period kit (Builders/OutfitKit), the same dress the hall's standing residents wear.

	The kit figure is built on R6 proportions (torso 2x2x1 at y = 3, arms at x = +-1.5, legs two
	studs tall), so it is built over the rig at rest and every piece is welded to the limb it
	belongs to: hat, hair and face to the Head, sleeves, hands and what they hold to the arms,
	trousers and boots to the legs, coat, skirt and tails to the Torso. The plain R6 limbs are
	hidden; the kit pieces are massless and never collide, while the rig's own root and torso give
	the person their space. The rig carries Procedural and the ResidentRig tag, so every client
	walks, seats and turns it like the crew (Controllers/CharacterAnimator).

	Once a person's clothing is uploaded (Passengers.Wear, Passengers.wearReady) they wear it as
	Mabel does: shirt and pants sheets on the rig's own limbs and mesh pieces (skirt, bag) welded to
	them. The kit then keeps only what is on the head and what the hands hold; its box coat, sleeves,
	trousers, boots and skirt are left off.

	Returns nil if the R6 body cannot be made (no AssetService in a headless build).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Passengers = require(ReplicatedStorage.Shared.Config.Passengers)
local OutfitKit = require(script.Parent.OutfitKit)

local PassengerFigure = {}

local RIG_TAG = "ResidentRig"
local TAG = "Passenger"

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The R6 limb a kit piece at `p` (figure space: feet at y = 0, facing -Z, +X the right hand)
-- belongs to.
local function limbFor(p: Vector3, size: Vector3, name: string, skirt: boolean): string
	if p.Y >= 4.2 then -- above the collar (its centre is at 4.05)
		return "Head"
	elseif math.abs(p.X) >= 1.2 and p.Y >= 1.2 then
		return if p.X > 0 then "Right Arm" else "Left Arm"
	elseif
		p.Y < 2
		and math.abs(p.X) <= 1
		and size.X <= 1.16
		and size.Z <= 1.2
		and name ~= "Skirt"
		and (not skirt or p.Y < 0.5) -- under a skirt only the boots step
	then
		return if p.X > 0 then "Right Leg" else "Left Leg"
	end
	return "Torso"
end

local function body(look: any): Model?
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = rgb(look.skin)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = rgb(look.coat)
		description.LeftLegColor = rgb(look.lower)
		description.RightLegColor = rgb(look.lower)
		local made = Players:CreateHumanoidModelFromDescription(
			description,
			Enum.HumanoidRigType.R6,
			Enum.AssetTypeVerification.Always
		)
		description:Destroy()
		return made
	end)
	if not ok or result == nil then
		warn(`PassengerFigure: R6 body did not build: {result}`)
		return nil
	end
	return result :: Model
end

-- Whether a kit piece stays on a person in sheets: the head's pieces and the props (OutfitKit marks
-- them), unless a wear piece replaces the prop; the box clothing on the body and limbs goes.
local function keepOverSheets(limb: string, prop: boolean, propReplaced: boolean): boolean
	if limb == "Head" then
		return true
	end
	return prop and not propReplaced
end

-- Welds each wear piece to its limb; a piece whose mesh does not load is left off.
local function addPieces(rig: Model, wear: Passengers.Wear)
	local ok, service = pcall(game.GetService, game, "AssetService")
	if not ok then
		return
	end
	for _, piece in wear.pieces do
		local limb = rig:FindFirstChild(piece.limb)
		if not (limb and limb:IsA("BasePart")) then
			continue
		end
		local function place(id: number): MeshPart?
			local loaded, mesh = pcall(function(): any
				return (service :: AssetService):CreateMeshPartAsync(Content.fromAssetId(id))
			end)
			if not loaded or mesh == nil then
				warn(`PassengerFigure: piece {piece.name} ({id}) did not load: {mesh}`)
				return nil
			end
			local part = mesh :: MeshPart
			part.Name = piece.name
			part.TextureID = `rbxassetid://{piece.texture}`
			part.Color = Color3.new(1, 1, 1)
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = false
			part.Size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
			local o = piece.offset
			part.CFrame = (limb :: BasePart).CFrame
				* CFrame.new(o[1], o[2], o[3])
				* CFrame.Angles(0, math.rad(piece.yaw), 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb :: BasePart
			weld.Part1 = part
			weld.Parent = part
			part.Parent = rig
			return part
		end
		local part = place(piece.mesh :: number)
		if part == nil then
			continue
		end
		if piece.prop then
			part:AddTag("Detail") -- a bag: the Performance setting leaves it off; sheets and skirt stay
		elseif piece.phone then
			-- the lighter phone mesh in its place under Performance (Controllers/DetailController)
			local phone = place(piece.phone)
			if phone then
				phone.Name = `{piece.name}Phone`
				part:AddTag("Detail")
				phone:AddTag("DetailFallback")
			end
		end
	end
end

function PassengerFigure.build(person: Passengers.Person, cframe: CFrame, parent: Instance): Model?
	local rig = body(person.look)
	if rig == nil then
		return nil
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		rig:Destroy()
		return nil
	end
	-- no Animate script (every client plays the body), and the kit draws the face
	for _, d in rig:GetDescendants() do
		local animate = d.Name == "Animate" and (d:IsA("LocalScript") or d:IsA("Script"))
		if animate or d:IsA("Decal") then
			d:Destroy()
		end
	end
	rig.Name = `Passenger_{person.id}`
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.WalkSpeed = Passengers.Walk.speed

	-- stand the soles on the floor at `cframe`, as Builders/NpcFigure does for the residents
	rig:PivotTo(cframe * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2 + 2, 0))
	local sole = math.huge
	for _, name in { "Left Leg", "Right Leg" } do
		local leg = rig:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			sole = math.min(sole, cframe:PointToObjectSpace(leg.Position).Y - leg.Size.Y / 2)
		end
	end
	if sole < math.huge then
		rig:PivotTo(rig:GetPivot() + cframe.UpVector * -sole)
	end

	-- the dress, built over the rig at rest and welded piece by piece to its limb
	local holder = Instance.new("Folder")
	local kit = OutfitKit.figure(holder, cframe, person.look, {})
	local dress = Instance.new("Folder")
	dress.Name = "Dress"
	local skirt = person.look.skirt ~= nil
	local wear = if Passengers.wearReady(person.id) then Passengers.Wear[person.id] else nil
	local propReplaced = false
	if wear then
		for _, piece in wear.pieces do
			propReplaced = propReplaced or piece.prop == true
		end
	end
	-- a Roblox head sits lower than the kit's ball head (centre 4.5 against 4.72), so what is kept on the
	-- head (hat, bonnet) is moved down onto it rather than riding above it
	local rigHead = rig:FindFirstChild("Head")
	local fit = if wear
			and wear.face
			and rigHead
			and rigHead:IsA("BasePart")
		then rigHead.CFrame * kit.head.CFrame:Inverse()
		else nil
	for _, piece in kit.model:GetDescendants() do
		if not piece:IsA("BasePart") then
			continue
		end
		local chosen = piece:GetAttribute("Limb") -- set by the kit for pieces held or hung off-limb
		local limb = rig:FindFirstChild(
			if type(chosen) == "string"
				then chosen
				else limbFor(cframe:PointToObjectSpace(piece.Position), piece.Size, piece.Name, skirt)
		)
		if not (limb and limb:IsA("BasePart")) then
			continue
		end
		if wear and not keepOverSheets(limb.Name, piece:GetAttribute("Prop") == true, propReplaced) then
			continue
		end
		if wear and wear.face and piece:GetAttribute("Face") then
			continue -- the Roblox head and its painted face take the kit face's place
		end
		if wear and wear.head and limb.Name == "Head" then
			continue -- the sculpted hair, whiskers and hat take the kit's head pieces' place
		end
		if fit and limb.Name == "Head" then
			piece.CFrame = fit * piece.CFrame
		end
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = piece
		weld.Parent = piece
		piece.Parent = dress
	end
	holder:Destroy()
	dress.Parent = rig
	for _, part in rig:GetChildren() do
		if part:IsA("BasePart") then
			-- the plain limbs; the dress is what shows (in sheets, everything but the kit's head)
			part.Transparency = if wear
					and (part.Name ~= "Head" or wear.face ~= nil)
					and part.Name ~= "HumanoidRootPart"
				then 0
				else 1
		end
	end
	if wear then
		-- the sheets are plain image uploads, so they go on as templates rather than catalogue items
		local shirt = Instance.new("Shirt")
		shirt.ShirtTemplate = `rbxassetid://{wear.shirt}`
		shirt.Parent = rig
		local pants = Instance.new("Pants")
		pants.PantsTemplate = `rbxassetid://{wear.pants}`
		pants.Parent = rig
		addPieces(rig, wear)
		local head = rig:FindFirstChild("Head")
		if wear.face and head then
			local face = head:FindFirstChildOfClass("Decal") or Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Texture = `rbxassetid://{wear.face}`
			face.Parent = head
		end
	end

	rig:SetAttribute("Procedural", true)
	rig:SetAttribute("Passenger", person.id)
	rig.Parent = parent
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(rig, RIG_TAG)
	CollectionService:AddTag(rig, TAG)
	return rig
end

return PassengerFigure
