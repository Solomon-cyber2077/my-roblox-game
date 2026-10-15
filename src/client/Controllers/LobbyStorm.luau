--!strict
--[[
	The storm outside the Depot Hall's back windows (the panes are tagged "StormWindow" by
	Builders/LobbyBuilder). Client-only and local to each player:

	  * a black skyline beyond the glass: a Gothic church with a needle spire, a ruined chapel's
	    lancet gable, gabled houses with chimney stacks, bare trees on a hill, against a sky of
	    low bruised cloud
	  * rain sheeting past every window and a muffled rain loop behind the wall
	  * lightning every few seconds: the clouds flare, a forked bolt stands over the roofs, the
	    hall flickers white through the glass, and the thunder follows a moment later

	Under the Performance graphics setting the rain particles, the bolt and the flash lights are
	skipped; the skyline still flares and the thunder still rolls.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local Safe = require(ReplicatedStorage.Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)

local TAG = "StormWindow"
local NEAR = 260 -- nothing runs while the camera is further than this from the windows
local FLASH_GAP = { 7, 16 } -- seconds between strikes
local THUNDER_DELAY = { 0.35, 2.4 } -- seconds from flash to thunder
local INK = Color3.fromRGB(10, 10, 14) -- the skyline, black against the cloud
local CLOUD = Color3.fromRGB(40, 44, 62)
local HORIZON = Color3.fromRGB(70, 66, 88) -- a bruised band low down, so the skyline stands out
local CLOUD_LIT = Color3.fromRGB(168, 176, 214)
local BOLT = Color3.fromRGB(214, 222, 255)

local LobbyStorm = {}

local rng = Random.new()
local folder: Folder? = nil
local sky: BasePart? = nil
local horizon: BasePart? = nil
local flashLights: { PointLight } = {}
local rainEmitters: { ParticleEmitter } = {}
local centre = Vector3.zero
local behind = Vector3.zAxis -- out through the glass, away from the hall
local across = Vector3.xAxis
local nextStrike = 0
local bolt: Model? = nil

local function performance(): boolean
	return Players.LocalPlayer:GetAttribute("GraphicsQuality") == "Performance"
end

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- A point out in the storm: `side` studs along the wall, `out` studs beyond it, `up` above the floor.
local function spot(side: number, out: number, up: number): Vector3
	return centre + across * side + behind * out + Vector3.yAxis * up
end

local function facing(position: Vector3): CFrame
	return CFrame.lookAt(position, position - behind)
end

local function buildSkyline(parent: Instance)
	-- the cloud deck: a dark sheet far behind the skyline that the lightning lights from inside
	local cloud = Kit.block(parent, Vector3.new(600, 200, 2), facing(spot(0, 110, 80)), CLOUD, {
		material = Enum.Material.Neon,
		collide = false,
	})
	cloud.Transparency = 0.05
	cloud.Name = "CloudDeck"
	sky = cloud
	local band = Kit.block(parent, Vector3.new(600, 36, 2), facing(spot(0, 106, 22)), HORIZON, {
		material = Enum.Material.Neon,
		collide = false,
	})
	band.Transparency = 0.25
	horizon = band
end

local function buildRain(parent: Instance, panes: { BasePart })
	for _, pane in panes do
		local sheet = Kit.block(
			parent,
			Vector3.new(pane.Size.X + 6, 1, 8),
			CFrame.new(pane.Position + behind * 5 + Vector3.yAxis * 14),
			INK,
			{ collide = false, transparency = 1 }
		)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(176, 186, 210))
		emitter.Size = NumberSequence.new(0.22)
		emitter.Squash = NumberSequence.new(5)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Transparency = NumberSequence.new(0.3)
		emitter.LightEmission = 0.35
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Speed = NumberRange.new(70, 85)
		emitter.Acceleration = across * 14 -- wind-driven, slanting along the glass
		emitter.Lifetime = NumberRange.new(0.32, 0.4)
		emitter.Rate = 0
		emitter.Parent = sheet
		table.insert(rainEmitters, emitter)
		-- the flash: a cold light just outside the pane that throws the glazing bars across the floor
		local lamp =
			Kit.block(parent, Vector3.one, CFrame.new(pane.Position + behind * 6 + Vector3.yAxis * 6), INK, {
				collide = false,
				transparency = 1,
			})
		local light = Instance.new("PointLight")
		light.Color = BOLT
		light.Brightness = 0
		light.Range = 60
		light.Shadows = true
		light.Parent = lamp
		table.insert(flashLights, light)
	end
end

-- A forked bolt from the cloud to the skyline, drawn in a few jagged neon lengths.
local function drawBolt(parent: Instance): Model
	local model = Kit.model("Bolt")
	local x = rng:NextNumber(-160, 160)
	local out = rng:NextNumber(80, 104)
	local point = spot(x, out, 150)
	local ground = 20
	local function length(a: Vector3, b: Vector3, width: number)
		local part = Kit.block(model, Vector3.new(width, width, (b - a).Magnitude), Kit.between(a, b), BOLT, {
			material = Enum.Material.Neon,
			collide = false,
		})
		part.CastShadow = false
	end
	local steps = 7
	local drop = (150 - ground) / steps
	for k = 1, steps do
		local nextPoint = point + Vector3.yAxis * -drop + across * rng:NextNumber(-12, 12)
		length(point, nextPoint, 1.4)
		if k == 3 or k == 5 then
			local fork = nextPoint + Vector3.yAxis * -drop * 1.4 + across * rng:NextNumber(-26, 26)
			length(nextPoint, fork, 0.8)
		end
		point = nextPoint
	end
	model.Parent = parent
	return model
end

local function setFlash(amount: number, lights: boolean)
	local cloud = sky
	if cloud then
		cloud.Color = CLOUD:Lerp(CLOUD_LIT, amount)
	end
	local band = horizon
	if band then
		band.Color = HORIZON:Lerp(CLOUD_LIT, amount)
	end
	for _, light in flashLights do
		light.Brightness = if lights then amount * 6 else 0
	end
end

local function strike()
	local f = folder
	if f == nil then
		return
	end
	local lite = performance()
	if not lite then
		bolt = drawBolt(f)
	end
	-- two or three flickers, the last the brightest, then a slow fade
	task.spawn(function()
		local flickers = rng:NextInteger(2, 3)
		for k = 1, flickers do
			setFlash(if k == flickers then 1 else 0.55, not lite)
			task.wait(rng:NextNumber(0.05, 0.09))
			setFlash(0.12, not lite)
			task.wait(rng:NextNumber(0.06, 0.14))
		end
		setFlash(1, not lite)
		task.wait(0.08)
		local b = bolt
		if b then
			b:Destroy()
			bolt = nil
		end
		local fade = 0.5
		local t0 = os.clock()
		while os.clock() - t0 < fade do
			setFlash(1 - (os.clock() - t0) / fade, not lite)
			task.wait()
		end
		setFlash(0, false)
	end)
	local near = rng:NextNumber() < 0.4
	task.delay(between(THUNDER_DELAY), function()
		local audio = Registry.AudioController
		if audio then
			audio.Play(if near then "LobbyThunder" else "LobbyThunderFar", spot(0, 30, 20))
		end
	end)
end

local function build(panes: { BasePart })
	local first = panes[1]
	-- "behind" is the side of the panes away from the hall's middle
	local sum = Vector3.zero
	for _, pane in panes do
		sum += pane.Position
	end
	centre = sum / #panes
	centre = Vector3.new(centre.X, first.Position.Y - 15.3, centre.Z) -- the hall floor
	local hall = Workspace:FindFirstChild("DepotHall")
	local hallCentre = if hall and hall:IsA("Model") then hall:GetPivot().Position else centre - Vector3.zAxis
	local outward = centre - hallCentre
	behind = if math.abs(outward.Z) >= math.abs(outward.X)
		then Vector3.new(0, 0, math.sign(outward.Z))
		else Vector3.new(math.sign(outward.X), 0, 0)
	across = Vector3.new(behind.Z, 0, -behind.X) -- up x behind

	local f = Instance.new("Folder")
	f.Name = "LobbyStorm"
	buildSkyline(f)
	buildRain(f, panes)
	f.Parent = Workspace
	folder = f

	local anchor =
		Kit.block(f, Vector3.one, CFrame.new(spot(0, 6, 12)), INK, { collide = false, transparency = 1 })
	anchor.Name = "RainVoice"
	local audio = Registry.AudioController
	if audio then
		audio.Loop("LobbyRain", "LobbyRain", anchor)
		local loop = audio.LoopSound("LobbyRain")
		if loop then
			-- heard through brick and glass: the hiss taken off the top
			local muffle = Instance.new("EqualizerSoundEffect")
			muffle.HighGain = -14
			muffle.MidGain = -4
			muffle.LowGain = 2
			muffle.Parent = loop
		end
	end
	nextStrike = os.clock() + between({ 3, 6 })
end

function LobbyStorm.Init() end

-- A strike now (the dev console and checks use it).
function LobbyStorm.Strike()
	strike()
end

function LobbyStorm.Start()
	task.spawn(function()
		-- the hall is built by the server at boot; its panes replicate with it
		local panes: { BasePart } = {}
		local deadline = os.clock() + 60
		while #panes < 4 and os.clock() < deadline do
			panes = {}
			for _, pane in CollectionService:GetTagged(TAG) do
				if pane:IsA("BasePart") then
					table.insert(panes, pane)
				end
			end
			task.wait(0.5)
		end
		if #panes == 0 then
			return
		end
		Safe.call("LobbyStorm.build", build, panes)
	end)

	RunService.Heartbeat:Connect(function()
		if folder == nil then
			return
		end
		Safe.call("LobbyStorm", function()
			local camera = Workspace.CurrentCamera
			local close = camera ~= nil and (camera.CFrame.Position - centre).Magnitude < NEAR
			local rate = if close and not performance() then 220 else 0
			for _, emitter in rainEmitters do
				emitter.Rate = rate
			end
			if close and os.clock() >= nextStrike then
				nextStrike = os.clock() + between(FLASH_GAP)
				strike()
			end
		end)
	end)
end

return LobbyStorm
