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
			part.Transparency = 1 -- the plain limbs; the dress is what shows
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
