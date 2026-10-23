--!strict
--[[
	Keeps the crew able to see where they are going (Tuning.Visibility, Logic/Visibility):

	  * every crew lantern's one PointLight reaches the readability floor's radius, whatever
	    its cosmetic (the look changes colour, flicker and glow only; CosmeticMotion flickers
	    its brightness, never its range)
	  * the local player's own forward cone: one SpotLight ahead of them, in their lantern's
	    colour, so the way ahead reads further than the pool round their feet. It is local:
	    every other client sees only that player's one lantern light
	  * a cold moonlit rim on the nearest obstacles and tall structures of the docked station
	    (Visibility.Rim): a fixed pool of Highlights whose Adornee moves to whatever is nearest,
	    so silhouettes read in the dark without a light of their own

	  * the chase (Visibility.Chase, Logic/Visibility.chaseStep), the game's only chase effect.
	    Read from the Hollows' replicated State (no monster script involved): a Hollow on the
	    hunt whose nearest crew member is you, within Detect, or a grab on you. A black flicker,
	    then AtmosphereController dims the sky (Sky.chase) and all but drops the dread
	    vignette; the station's lamps dim but reach further (building lamps through LightScale,
	    which BuildingVisuals reads); the lanterns keep the floor and reach further too.
	    Escaped, the relief, then the night settles back

	Budget (Visibility.Budget): one light per player, one shadow (your cone, Quality only), a
	fixed Highlight pool; under Performance no shadows, a shorter cone, half the rims, crewmates'
	far lanterns off.

	The lobby keeps its own lamp-lit look: no cone there.

	A stalking Hollow's tells (Logic/Tells, fixed r = 30, never this slider): within r the cone
	leans away from it and the lantern gutters by at most 15% of its brightness (its reach, and so
	the floor, never moves); within 1.2r the pocket watch stutters (UI/Hud reads Tells()). They
	clear within a second of leaving range.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local MathX = require(Shared.Util.MathX)
local Safe = require(Shared.Util.Safe)
local Tuning = require(Shared.Config.Tuning)
local Tells = require(Shared.Logic.Tells)
local Visibility = require(Shared.Logic.Visibility)

local Session = require(script.Parent.Parent.Session)

local VisibilityController = {}

local LAMP = Tuning.CarriedLantern
local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])
local LOBBY_RADIUS = 420 -- the same test as AtmosphereController's
local SCAN_SECONDS = 0.5 -- how often the crew's lanterns are looked up again
local WARM = Color3.fromRGB(255, 196, 128)

local BUDGET = Tuning.Visibility.Budget
local RIM = Tuning.Visibility.Rim
local RIM_KINDS: { [string]: boolean } = {}
for _, kind in RIM.Kinds do
	RIM_KINDS[kind] = true
end

local CHASE = Tuning.Visibility.Chase
local HUNTING = { Hunt = true, Windup = true, Grab = true, Recover = true }
local LAMP_TAG = "LTO_BuildingLamp"

type StationLight = { light: Light, brightness: number, range: number, building: boolean }

local chase = Visibility.chaseStart()
local look: Visibility.ChaseLook = Visibility.chaseLook(chase, 0)
local blackout: Frame
local lightStation: Model? = nil
local stationLights: { StationLight } = {}
local lightDim = 0
local cone: SpotLight? = nil
local rims: { Highlight } = {}
local rimStation: Model? = nil
local rimTargets: { Model } = {}
local lanterns: { PointLight } = {}
local ownLantern: PointLight? = nil
local lanternColor = WARM

local function performance(): boolean
	return Players.LocalPlayer:GetAttribute("GraphicsQuality") == "Performance"
end

--[[
	The readability floor's reach right now: the one value a Settings "Visibility" slider moves.
	It sets the player attribute Tuning.Visibility.Setting (studs, clamped RadiusMin..RadiusMax by
	Logic/Visibility.radius); the lanterns' reach, the cone's least reach and the sky's ambient
	floors all follow it.
]]
function VisibilityController.Radius(): number
	return Visibility.radius(Players.LocalPlayer:GetAttribute(Tuning.Visibility.Setting))
end

-- For the slider: sets the floor's reach (nil restores the default).
function VisibilityController.SetRadius(studs: number?)
	Players.LocalPlayer:SetAttribute(
		Tuning.Visibility.Setting,
		if studs == nil then nil else Visibility.radius(studs)
	)
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
	ownLantern = nil
	for _, player in Players:GetPlayers() do
		local light = player.Character and lanternLight(player.Character)
		if light then
			table.insert(lanterns, light)
			if player == Players.LocalPlayer then
				ownLantern = light
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

-- The docked station's rim targets: its listed props and its buildings.
local function rimTargetsOf(station: Model): { Model }
	local found: { Model } = {}
	for _, child in station:GetChildren() do
		if child:IsA("Model") and (RIM_KINDS[child.Name] or Buildings.Defs[child.Name] ~= nil) then
			table.insert(found, child)
		end
	end
	return found
end

local function dockedStation(): Model?
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 8) == "Station_" then
			return child
		end
	end
	return nil
end

local function updateRims(around: Vector3, active: boolean)
	local station = if active then dockedStation() else nil
	if station ~= rimStation then
		rimStation = station
		rimTargets = if station then rimTargetsOf(station) else {}
	end
	local candidates: { { model: Model, distance: number } } = {}
	for _, model in rimTargets do
		if model.Parent then
			local pivot = model:GetPivot().Position
			local distance = (pivot - around).Magnitude
			if distance <= RIM.Range then
				table.insert(candidates, { model = model, distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local max = if performance() then RIM.MaxPerformance else RIM.Max
	for i, highlight in rims do
		local pick = if i <= max then candidates[i] else nil
		local adornee = if pick then pick.model else nil
		-- only touch what changed: a new Adornee rebuilds the outline
		if highlight.Adornee ~= adornee then
			highlight.Adornee = adornee
		end
		highlight.Enabled = adornee ~= nil
	end
end

-- Whether a Hollow is chasing the local player right now.
local function chased(root: BasePart): boolean
	local character = root.Parent
	if
		character
		and character:GetAttribute("GrabAt") ~= nil
		and character:GetAttribute("GrabOutcome") == nil
	then
		return true
	end
	local folder = Workspace:FindFirstChild("Hollows")
	if folder == nil then
		return false
	end
	for _, hollow in folder:GetChildren() do
		local state = hollow:GetAttribute("State")
		local body = if typeof(state) == "string" and HUNTING[state]
			then hollow:FindFirstChild("HumanoidRootPart") :: BasePart?
			else nil
		if body then
			local mine = (body.Position - root.Position).Magnitude
			if mine <= CHASE.Detect then
				-- its prey is whoever is nearest it: me, unless a crewmate is closer
				local nearest = true
				for _, player in Players:GetPlayers() do
					local other = player.Character
					local otherRoot = other and other:FindFirstChild("HumanoidRootPart") :: BasePart?
					if
						player ~= Players.LocalPlayer
						and otherRoot
						and (body.Position - otherRoot.Position).Magnitude < mine
					then
						nearest = false
						break
					end
				end
				if nearest then
					return true
				end
			end
		end
	end
	return false
end

-- The docked station's own lights dim and reach further as the chase's dark comes in.
local function updateStationLights(station: Model?, dim: number)
	if station ~= lightStation then
		lightStation = station
		table.clear(stationLights)
		lightDim = 0
		if station then
			for _, descendant in station:GetDescendants() do
				if descendant:IsA("Light") then
					table.insert(stationLights, {
						light = descendant,
						brightness = descendant.Brightness,
						range = (descendant :: any).Range, -- every kind of Light has one
						building = descendant:HasTag(LAMP_TAG),
					})
				end
			end
		end
	end
	if math.abs(dim - lightDim) < 0.01 then
		return
	end
	lightDim = dim
	local brightness = MathX.lerp(1, CHASE.LightBrightness, dim)
	local range = MathX.lerp(1, CHASE.LightRange, dim)
	for _, entry in stationLights do
		local light = entry.light :: any
		if light.Parent then
			if not entry.building then -- BuildingVisuals sets those, through LightScale
				light.Brightness = entry.brightness * brightness
			end
			light.Range = entry.range * range
		end
	end
end

-- The tells now, eased (Logic/Tells): lean strength and direction, flicker, the watch's stutter.
local tell = { strength = 0, leanX = 0, leanZ = 0, flicker = 0, stutter = 0 }
local lastTellAt = os.clock()

local function stalkers(): { Tells.Source }
	local sources: { Tells.Source } = {}
	local folder = Workspace:FindFirstChild("Hollows")
	if folder then
		for _, hollow in folder:GetChildren() do
			local state = hollow:GetAttribute("State")
			local body = hollow:FindFirstChild("HumanoidRootPart") :: BasePart?
			if body and (state == "Stalk" or state == "Hunt") then
				local position = body.Position
				table.insert(sources, {
					x = position.X,
					z = position.Z,
					state = state :: string,
					coil = hollow:GetAttribute("WarningCoil") == true,
				})
			end
		end
	end
	return sources
end

local function updateTells(root: BasePart?, clock: number)
	local dt = math.clamp(clock - lastTellAt, 0, 0.25)
	lastTellAt = clock
	local now = if root
		then Tells.compute(root.Position.X, root.Position.Z, stalkers(), clock)
		else Tells.compute(0, 0, {}, clock)
	tell.strength = Tells.fade(tell.strength, now.strength, dt)
	tell.flicker = Tells.fade(tell.flicker, now.flicker, dt)
	tell.stutter = Tells.fade(tell.stutter, if now.stutter then 1 else 0, dt)
	if now.strength > 0 then
		tell.leanX, tell.leanZ = now.leanX, now.leanZ
	end
	if ownLantern then
		ownLantern:SetAttribute("TellDim", if tell.flicker > 0.001 then tell.flicker else nil)
	end
	local holder = cone and cone.Parent
	if holder and holder:IsA("Attachment") and root then
		-- the beam swings away from the stalker, never more than LeanDegrees
		local away = root.CFrame:VectorToObjectSpace(Vector3.new(tell.leanX, 0, tell.leanZ))
		local yaw = -math.rad(Tuning.Stalk.LeanDegrees) * tell.strength * math.clamp(away.X, -1, 1)
		holder.CFrame = CFrame.new(holder.Position) * CFrame.Angles(0, yaw, 0)
	end
end

-- The stalk tells now: `stutter` true while the pocket watch should stutter.
function VisibilityController.Tells(): { stutter: boolean, strength: number }
	return { stutter = tell.stutter > 0.05, strength = tell.strength }
end

-- What the chase shows now: dim, relief and the flicker's black (Logic/Visibility).
function VisibilityController.Chase(): Visibility.ChaseLook
	return look
end

-- The share of their brightness the station's lamps keep right now.
function VisibilityController.LightScale(): number
	return MathX.lerp(1, CHASE.LightBrightness, look.dim)
end

function VisibilityController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChaseFlicker"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	blackout = Instance.new("Frame")
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BackgroundTransparency = 1
	blackout.BorderSizePixel = 0
	blackout.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local folder = Instance.new("Folder")
	folder.Name = "Rims"
	folder.Parent = Workspace
	local color = Color3.fromRGB(RIM.Color[1], RIM.Color[2], RIM.Color[3])
	for i = 1, RIM.Max do
		local highlight = Instance.new("Highlight")
		highlight.Name = `Rim{i}`
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.OutlineColor = color
		highlight.OutlineTransparency = RIM.Outline
		highlight.FillColor = color
		highlight.FillTransparency = RIM.Fill
		highlight.Enabled = false
		highlight.Parent = folder
		table.insert(rims, highlight)
	end
end

function VisibilityController.Start()
	local nextScan = 0
	local nextRim = 0
	local function frame()
		local clock = os.clock()
		if clock >= nextScan then
			nextScan = clock + SCAN_SECONDS
			scan()
			-- the edge's red danger lamps keep their glass under Performance but lose their light
			local lightsOn = not performance()
			for _, glass in CollectionService:GetTagged("DangerLamp") do
				local light = glass:FindFirstChild("DangerLight")
				if light and light:IsA("Light") then
					light.Enabled = lightsOn
				end
			end
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inLobby = root == nil or (root.Position - LOBBY).Magnitude < LOBBY_RADIUS

		-- the chase
		local hunted = root ~= nil and not inLobby and Session.isRunActive() and chased(root :: BasePart)
		chase = Visibility.chaseStep(chase, hunted, clock)
		look = Visibility.chaseLook(chase, clock)
		blackout.BackgroundTransparency = 1 - look.black
		updateStationLights(if inLobby then nil else dockedStation(), look.dim)
		updateTells(if inLobby then nil else root, clock)

		-- the lanterns hold the floor, and reach a little further in the chase's dark
		local radius = VisibilityController.Radius()
		local reach = radius * MathX.lerp(1, CHASE.LightRange, look.dim)
		local simple = performance()
		local eye = Workspace.CurrentCamera.CFrame.Position
		for _, light in lanterns do
			if light:GetAttribute("PayrollAttached") then
				light.Enabled = false
				continue
			end
			local lens = light.Parent
			if lens and lens:IsA("BasePart") then
				light.Range = reach
				light.Shadows = false
				-- Performance: a crewmate's lantern far off is one dynamic light too many
				light.Enabled = not simple
					or light == ownLantern
					or (lens.Position - eye).Magnitude <= BUDGET.LanternCull
			end
		end
		if root and not inLobby and not root.Parent:GetAttribute("PayrollCarriers") then
			local light = coneFor(root)
			light.Enabled = true
			light.Color = lanternColor
			light.Brightness = LAMP.ConeBrightness
			light.Range = math.max(if simple then BUDGET.ConeRangePerformance else LAMP.ConeRange, radius)
			light.Shadows = not simple and BUDGET.Shadows > 0
		elseif cone then
			cone.Enabled = false
		end
		if clock >= nextRim then
			nextRim = clock + RIM.Every
			updateRims(if root then root.Position else Workspace.CurrentCamera.CFrame.Position, not inLobby)
		end
	end
	RunService.RenderStepped:Connect(function()
		Safe.call("Visibility", frame)
	end)
end

return VisibilityController
