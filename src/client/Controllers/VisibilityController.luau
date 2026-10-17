--!strict
--[[
	Keeps the crew able to see where they are going (Tuning.Visibility, Logic/Visibility):

	  * every crew lantern's one PointLight reaches the readability floor's radius, whatever
	    its cosmetic (the look changes colour, flicker and glow only; CosmeticMotion flickers
	    its brightness, never its range)
	  * the local player's own forward cone: one SpotLight ahead of them, in their lantern's
	    colour, so the way ahead reads further than the pool round their feet. It is local:
	    every other client sees only that player's one lantern light

	The lobby keeps its own lamp-lit look: no cone there.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Safe = require(Shared.Util.Safe)
local Tuning = require(Shared.Config.Tuning)
local Visibility = require(Shared.Logic.Visibility)

local VisibilityController = {}

local LAMP = Tuning.CarriedLantern
local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])
local LOBBY_RADIUS = 420 -- the same test as AtmosphereController's
local SCAN_SECONDS = 0.5 -- how often the crew's lanterns are looked up again
local WARM = Color3.fromRGB(255, 196, 128)

local cone: SpotLight? = nil
local lanterns: { PointLight } = {}
local lanternColor = WARM

local function performance(): boolean
	return Players.LocalPlayer:GetAttribute("GraphicsQuality") == "Performance"
end

-- The readability floor's reach right now.
function VisibilityController.Radius(): number
	return Visibility.radius(nil)
end

local function lanternLight(character: Model): PointLight?
	local cosmetics = character:FindFirstChild("Cosmetics")
	local lantern = cosmetics and cosmetics:FindFirstChild("Lantern")
	local lens = lantern and lantern:FindFirstChild("Lens", true)
	local glow = lens and lens:FindFirstChild("Glow")
	return if glow and glow:IsA("PointLight") then glow else nil
end

local function scan()
	table.clear(lanterns)
	for _, player in Players:GetPlayers() do
		local light = player.Character and lanternLight(player.Character)
		if light then
			table.insert(lanterns, light)
			if player == Players.LocalPlayer then
				lanternColor = light.Color
			end
		end
	end
end

local function coneFor(root: BasePart): SpotLight
	local existing = cone
	if existing and existing.Parent and existing.Parent.Parent == root then
		return existing
	end
	if existing then
		local holder = existing.Parent
		existing:Destroy()
		if holder then
			holder:Destroy()
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "LanternCone"
	attachment.Position = Vector3.new(0, LAMP.ConeHeight, -0.8)
	attachment.Parent = root
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = LAMP.ConeAngle
	light.Parent = attachment
	cone = light
	return light
end

function VisibilityController.Init() end

function VisibilityController.Start()
	local nextScan = 0
	local function frame()
		local clock = os.clock()
		if clock >= nextScan then
			nextScan = clock + SCAN_SECONDS
			scan()
		end
		local radius = VisibilityController.Radius()
		for _, light in lanterns do
			if light.Parent then
				light.Range = radius
			end
		end

		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inLobby = root == nil or (root.Position - LOBBY).Magnitude < LOBBY_RADIUS
		if root and not inLobby then
			local light = coneFor(root)
			light.Enabled = true
			light.Color = lanternColor
			light.Brightness = LAMP.ConeBrightness
			light.Range = math.max(LAMP.ConeRange, radius)
			light.Shadows = not performance()
		elseif cone then
			cone.Enabled = false
		end
	end
	RunService.RenderStepped:Connect(function()
		Safe.call("Visibility", frame)
	end)
end

return VisibilityController
