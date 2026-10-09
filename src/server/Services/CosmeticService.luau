--!strict
--[[
	Puts equipped cosmetics on characters and chooses the train's livery.

	Livery rule: in a private server the owner's livery wins while they ride;
	otherwise the highest-ranked crew member wearing a non-default livery picks it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local CosmeticModels = require(Shared.Visual.CosmeticModels)

local DataService = require(script.Parent.DataService)
local Registry = require(script.Parent.Parent.Registry)

local CosmeticService = {}

local function equipped(player: Player, category: string): Cosmetics.CosmeticDef
	local profile = DataService.GetProfile(player)
	local id = if profile then profile.equipped[category] else nil
	return Cosmetics.ById[id or ""] or Cosmetics.ById[Cosmetics.Defaults[category]]
end

local function attach(model: Model, to: BasePart)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = to
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
		end
	end
end

function CosmeticService.Init() end

function CosmeticService.Start()
	DataService.ProfileChanged:Connect(function(player)
		if not Registry.CrewService.IsMember(player) then
			CosmeticService.RefreshLivery()
		end
	end)
end

function CosmeticService.Apply(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local old = character:FindFirstChild("Cosmetics")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	folder.Parent = character

	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	local hip = lower or character:FindFirstChild("Torso") :: BasePart?
	if hip then
		-- at the belt: an R6 torso is one block, so its belt sits lower on it
		local belt = if lower then -0.15 else -0.75
		local lantern = CosmeticModels.lantern(
			equipped(player, "Lantern").look,
			hip.CFrame * CFrame.new(hip.Size.X / 2 + 0.4, belt, 0.05)
		)
		attach(lantern, hip)
		lantern.Parent = folder
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	local hat = equipped(player, "Headwear")
	local coversHair = hat.look.style ~= "None" and hat.look.style ~= "Goggles"
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hair then
			for _, part in accessory:GetDescendants() do
				if part:IsA("BasePart") then
					local original = part:GetAttribute("CosmeticHairTransparency")
					if typeof(original) ~= "number" then
						original = part.Transparency
						part:SetAttribute("CosmeticHairTransparency", original)
					end
					part.Transparency = if coversHair then 1 else original :: number
				end
			end
		end
	end
	if head and hat.look.style ~= "None" then
		for _, accessory in character:GetChildren() do
			if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hat then
				accessory:Destroy()
			end
		end
		local model =
			CosmeticModels.headwear(hat.look, head.CFrame * CFrame.new(0, head.Size.Y / 2 - 0.05, 0))
		if model then
			attach(model, head)
			model.Parent = folder
		end
	end

	local trail = equipped(player, "Trail")
	for _, footName in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local foot = character:FindFirstChild(footName) :: BasePart?
		if foot then
			local existing = foot:FindFirstChild("TrailAttachment")
			if existing then
				existing:Destroy()
			end
			local emitter = CosmeticModels.trail(trail.look)
			if emitter then
				local attachment = Instance.new("Attachment")
				attachment.Name = "TrailAttachment"
				attachment.Position = Vector3.new(0, -foot.Size.Y / 2, 0)
				attachment.Parent = foot
				emitter.Parent = attachment
			end
		end
	end
end

function CosmeticService.ChooseLivery(): Cosmetics.CosmeticDef
	local riders = Registry.CrewService.MemberPlayers()
	if #riders == 0 then
		riders = Players:GetPlayers()
	end
	if game.PrivateServerOwnerId ~= 0 then
		for _, player in riders do
			if player.UserId == game.PrivateServerOwnerId then
				return equipped(player, "Livery")
			end
		end
	end
	local best: Cosmetics.CosmeticDef? = nil
	local bestRank = -1
	for _, player in riders do
		local def = equipped(player, "Livery")
		if not def.default then
			local rank = DataService.Rank(player)
			if rank > bestRank then
				best, bestRank = def, rank
			end
		end
	end
	return best or Cosmetics.ById[Cosmetics.Defaults.Livery]
end

function CosmeticService.RefreshLivery()
	Registry.TrainService.ApplyLivery(CosmeticService.ChooseLivery().look)
end

return CosmeticService
