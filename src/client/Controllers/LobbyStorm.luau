--!strict
--[[
	The storm outside the Depot Hall's back windows (the panes are tagged "StormWindow" by
	Builders/LobbyBuilder). Client-only and local to each player:

	  * an endless dark-fantasy night beyond the glass: black mountain peaks, rolling hills and
	    bare trees as silhouettes, a distant moon veiled by churning black cloud, all in front of
	    one wide cloud deck the lightning lights from inside (no buildings, no horizon band)
	  * heavy rain sheeting past every window and a muffled rain loop behind the wall
	  * sudden lightning every few seconds: the clouds flare, a forked bolt stands over the hills,
	    a faint cold flicker crosses the floor by the windows (the hall stays warm amber), and the
	    thunder follows a moment later
	  * at most once per session, at a random time, one strike shows one or two TallOnes (the
	    sky's own silhouette, Scenery/Heavens) standing far out on the hills. They never move or
	    come closer, and they are gone when the light goes.

	Under the Performance graphics setting the rain, the bolt and the flash lights are skipped and
	the clouds churn more thinly; the sky still flares and the thunder still rolls.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local Safe = require(ReplicatedStorage.Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local Heavens = require(script.Parent.Parent.Scenery.Heavens)

local TAG = "StormWindow"
local NEAR = 260 -- nothing runs while the camera is further than this from the windows
local FLASH_GAP = { 7, 16 } -- seconds between strikes
local THUNDER_DELAY = { 0.35, 2.4 } -- seconds from flash to thunder
local INK = Color3.fromRGB(10, 10, 14) -- the skyline, black against the cloud
local CLOUD = Color3.fromRGB(58, 62, 84) -- light enough at rest for the silhouettes to read
local CLOUD_LIT = Color3.fromRGB(168, 176, 214)
local BOLT = Color3.fromRGB(214, 222, 255)
local CHURN = Color3.fromRGB(14, 14, 20) -- the black cloud rolling in front of the deck
local MOON = Color3.fromRGB(196, 202, 210)
local TALL_REVEAL_AFTER = { 60, 480 } -- seconds into the session before the TallOnes may show
local TALL_OUT = 86 -- studs beyond the wall where they stand, behind the hills

local LobbyStorm = {}

local rng = Random.new()
local folder: Folder? = nil
local sky: BasePart? = nil
local flashLights: { SpotLight } = {}
local rainEmitters: { ParticleEmitter } = {}
local centre = Vector3.zero
local behind = Vector3.zAxis -- out through the glass, away from the hall
local across = Vector3.xAxis
local nextStrike = 0
local bolt: Model? = nil
local churn: { ParticleEmitter } = {}
local tallOnes: { SurfaceGui } = {}
local tallRevealAt = math.huge -- the session's one chance; spent once shown
local paneSides: { number } = {} -- each window's place along the wall, to stand them where one looks

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

local function ink(parent: Instance, size: Vector3, cframe: CFrame): BasePart
	return Kit.block(parent, size, cframe, INK, { material = Enum.Material.SmoothPlastic, collide = false })
end

-- A peak seen side-on: two wedges back to back, high edges meeting at the summit.
local function mountain(parent: Instance, side: number, out: number, width: number, height: number)
	for _, s in { -1, 1 } do
		local at = spot(side + s * width / 4, out, height / 2 - 4)
		Kit.wedge(
			parent,
			Vector3.new(6, height, width / 2),
			CFrame.lookAt(at, at + across * s),
			INK,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end
end

-- A rounded hill: the top arc of a wide disc standing edge-on to the hall.
local function hill(parent: Instance, side: number, out: number, diameter: number, rise: number)
	Kit.cylinder(
		parent,
		8,
		diameter,
		CFrame.lookAt(spot(side, out, rise - diameter / 2), spot(side, out, rise - diameter / 2) + across),
		INK,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
end

-- A bare tree: a leaning trunk and a crown of crooked branches.
local function tree(parent: Instance, side: number, out: number, height: number, seed: number)
	local twist = Random.new(seed * 7919)
	local foot = spot(side, out, -1)
	local trunkTop = foot + Vector3.yAxis * height * 0.55 + across * twist:NextNumber(-2, 2)
	Kit.block(
		parent,
		Vector3.new(1.3, 1.3, (trunkTop - foot).Magnitude),
		Kit.between(foot, trunkTop),
		INK,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	for k = 0, 5 do
		local angle = math.rad(-75 + k * 30 + twist:NextNumber(-10, 10))
		local reach = height * twist:NextNumber(0.3, 0.5)
		local tip = trunkTop + across * math.sin(angle) * reach + Vector3.yAxis * math.cos(angle) * reach
		Kit.block(
			parent,
			Vector3.new(0.5, 0.5, reach),
			Kit.between(trunkTop, tip),
			INK,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
		-- one crooked twig off each branch
		local twig = tip + across * twist:NextNumber(-3, 3) + Vector3.yAxis * twist:NextNumber(1, 4)
		Kit.block(
			parent,
			Vector3.new(0.3, 0.3, (twig - tip).Magnitude),
			Kit.between(tip, twig),
			INK,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end
end

-- A flat disc facing the hall (the moon and its halo).
local function disc(parent: Instance, diameter: number, cframe: CFrame, color: Color3, transparency: number)
	local made = Kit.cylinder(
		parent,
		0.2,
		diameter,
		cframe * Kit.angles(0, 90, 0),
		color,
		{ material = Enum.Material.Neon, collide = false }
	)
	made.Transparency = transparency
	made.CastShadow = false
end

-- One TallOne, drawn from the sky's own shape (Heavens.TallOneShape) on a board facing the hall.
local function tallOne(parent: Instance): SurfaceGui
	local board = Kit.block(parent, Vector3.new(1, 1, 0.2), CFrame.new(), INK, {
		collide = false,
		transparency = 1,
	})
	board.Name = "TallOne"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(420, 1000)
	gui.Enabled = false
	gui.Parent = board
	for _, spec in Heavens.TallOneShape do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = Heavens.TallOneColor
		f.Position = UDim2.fromScale(0.5 + spec.x / Heavens.TallOneAspect, spec.y)
		f.Size = UDim2.fromScale(spec.w / Heavens.TallOneAspect, spec.h)
		f.Rotation = spec.r
		if spec.round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = f
		end
		f.Parent = gui
	end
	return gui
end

-- Stand the TallOnes (one or two) somewhere new on the hills, ready for their strike.
local function placeTallOnes(count: number)
	-- out beyond one of the windows, a little wider than straight out (the hall looks through at a slant)
	local side = paneSides[rng:NextInteger(1, #paneSides)] * rng:NextNumber(1.1, 1.6)
	for i, gui in tallOnes do
		local board = gui.Parent :: BasePart
		local height = rng:NextNumber(34, 44)
		board.Size = Vector3.new(height * Heavens.TallOneAspect, height, 0.2)
		local at = spot(side + (i - 1) * rng:NextNumber(14, 26), TALL_OUT, height / 2 + 20) -- on the hill line
		board.CFrame = facing(at)
		gui.Enabled = i <= count
	end
end

local function buildSkyline(parent: Instance)
	-- the cloud deck: a dark sheet far behind the skyline that the lightning lights from inside
	-- wide and deep enough that its edges never show through the windows
	local cloud = Kit.block(parent, Vector3.new(1400, 500, 2), facing(spot(0, 110, 40)), CLOUD, {
		material = Enum.Material.Neon,
		collide = false,
	})
	cloud.Transparency = 0.05
	cloud.Name = "CloudDeck"
	sky = cloud

	-- Silhouettes stand 20 to 105 studs out (the hall's Atmosphere hazes anything further) and run
	-- 500 studs either way, so no edge shows from any window. Mountains first, far back
	for i, spec in
		{
			{ -430, 170, 48 },
			{ -300, 210, 64 },
			{ -170, 150, 46 },
			{ -60, 230, 70 },
			{ 70, 170, 52 },
			{ 190, 220, 66 },
			{ 320, 160, 50 },
			{ 440, 200, 60 },
		}
	do
		mountain(parent, spec[1], 98 + (i % 3) * 3, spec[2], spec[3])
	end
	-- rolling hills before them, on one dark ground so nothing floats
	ink(parent, Vector3.new(1100, 22, 40), facing(spot(0, 62, -9)))
	for i = -5, 5 do
		local d = 90 + (i * 37 % 5) * 14
		hill(parent, i * 95 + (i * 23 % 30), 66 + (i % 2) * 6, d, 24 + (i * 13 % 4) * 3)
	end
	-- bare trees nearer, some alone, some in clumps
	for i, spec in
		{
			{ -150, 34, 26 },
			{ -104, 22, 30 },
			{ -96, 26, 20 },
			{ -30, 48, 24 },
			{ 24, 30, 22 },
			{ 72, 20, 28 },
			{ 80, 24, 18 },
			{ 128, 40, 32 },
			{ 190, 28, 24 },
		}
	do
		tree(parent, spec[1], spec[2], spec[3], i)
	end
	-- the moon, far off and low, veiled by the churning cloud in front of it
	local moonAt = facing(spot(64, 104, 62))
	disc(parent, 30, moonAt, MOON, 0.86)
	disc(parent, 13, moonAt * CFrame.new(0, 0, -0.3), MOON, 0.08)
	-- churning black cloud: slow, huge, turning billows in two layers between the moon and the hills
	for _, layer in { { up = 92, out = 100 }, { up = 58, out = 94 } } do
		local sheet = Kit.block(
			parent,
			Vector3.new(1000, 1, 30),
			CFrame.new(spot(0, layer.out, layer.up)),
			INK,
			{ collide = false, transparency = 1 }
		)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(CHURN)
		emitter.LightEmission = 0
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 30),
			NumberSequenceKeypoint.new(1, 70),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(14, 22)
		emitter.Speed = NumberRange.new(0.5, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-7, 7)
		emitter.Acceleration = across * 1.2
		emitter.Rate = 0
		emitter.Parent = sheet
		table.insert(churn, emitter)
	end
	-- the TallOnes, built once and hidden until their one strike
	for _ = 1, 2 do
		table.insert(tallOnes, tallOne(parent))
	end
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
		-- the flash: a narrow cold spot just outside the pane, aimed down through the glass at the
		-- floor strip under the window, so the glazing bars fall there and nowhere else; its range
		-- stops at that strip, so the amber hall lamps never take the cold light
		local sill = pane.Position.Y - pane.Size.Y / 2
		local origin = pane.Position + behind * 2 + Vector3.yAxis * (pane.Size.Y / 2)
		local target = Vector3.new(pane.Position.X, sill - 3, pane.Position.Z) - behind * 4
		local lamp = Kit.block(parent, Vector3.one, CFrame.lookAt(origin, target), INK, {
			collide = false,
			transparency = 1,
		})
		lamp.CastShadow = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 45
		light.Color = BOLT
		light.Brightness = 0
		light.Range = (target - origin).Magnitude + 2
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
	for _, light in flashLights do
		light.Brightness = if lights then amount * 1.8 else 0
	end
	-- the billows catch the flash from behind
	local billow = ColorSequence.new(CHURN:Lerp(CLOUD_LIT, amount * 0.35))
	for _, emitter in churn do
		emitter.Color = billow
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
	-- the session's one glimpse of the TallOnes, if its time has come: they stand only for this flash
	local glimpse = os.clock() >= tallRevealAt
	if glimpse then
		tallRevealAt = math.huge
		placeTallOnes(rng:NextInteger(1, 2))
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
		if glimpse then
			for _, gui in tallOnes do
				gui.Enabled = false
			end
		end
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
	for _, pane in panes do
		table.insert(paneSides, (pane.Position - centre):Dot(across))
	end

	local f = Instance.new("Folder")
	f.Name = "LobbyStorm"
	buildSkyline(f)
	buildRain(f, panes)
	f.Parent = Workspace
	folder = f
	-- the cloud is already rolling when the hall is first seen
	for _, emitter in churn do
		emitter:Emit(if performance() then 10 else 24)
	end

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
	tallRevealAt = os.clock() + between(TALL_REVEAL_AFTER)
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
			-- Studio only: the player attribute DevStormGlimpse calls the glimpse on the next strike
			if RunService:IsStudio() and Players.LocalPlayer:GetAttribute("DevStormGlimpse") then
				Players.LocalPlayer:SetAttribute("DevStormGlimpse", nil)
				tallRevealAt, nextStrike = 0, os.clock() + 1.5
			end
			local lite = performance()
			local rate = if close and not lite then 320 else 0
			for _, emitter in rainEmitters do
				emitter.Rate = rate
			end
			for _, emitter in churn do
				emitter.Rate = if not close then 0 elseif lite then 0.6 else 1.6
			end
			if close and os.clock() >= nextStrike then
				nextStrike = os.clock() + between(FLASH_GAP)
				strike()
			end
		end)
	end)
end

return LobbyStorm
