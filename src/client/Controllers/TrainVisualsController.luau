--!strict
--[[
	Client-side life on the static train (and the lobby's display train):
	turning wheels and coupling rods, sliding doors, chimney smoke and cylinder
	steam that follow speed, the tender's coal heap, breach steam, and every fire
	aboard: the firebox (it roars up when coal goes in, and gutters when there is
	none), the guard's stove and the lantern over his chairs. All of it is local
	CFrame and emitter work on anchored parts the server never touches again, so
	none of it replicates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MathX = require(ReplicatedStorage.Shared.Util.MathX)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local ChalkSlate = require(script.Parent.Parent.UI.ChalkSlate)

type Spin = { part: BasePart, base: CFrame, radius: number, pivot: Vector3? }
type Rod = { part: BasePart, base: CFrame, radius: number, phase: number }
type Door = { part: BasePart, base: CFrame, slide: number }

type Rig = {
	model: Model,
	spins: { Spin },
	rods: { Rod },
	doors: { Door },
	heap: { BasePart },
	smoke: ParticleEmitter?,
	vents: { ParticleEmitter },
	firebox: PointLight?,
	flames: { ParticleEmitter },
	glows: { PointLight }, -- the stove and the lantern: they flicker on their own
	flare: number, -- 0..1 the fire roaring after a shovel of coal
	lastFill: number,
	breaches: { [BasePart]: ParticleEmitter },
	doorOpen: number,
	live: boolean,
	doorLamps: { PointLight }?, -- at the platform-side doors, made at the first Last Call grace
}

local TrainVisualsController = {}

local rigs: { Rig } = {}
local angle = 0
local lastPuff = 0

local SMOKE = ColorSequence.new(Color3.fromRGB(70, 66, 64), Color3.fromRGB(150, 144, 138))
local STARVING_SMOKE = ColorSequence.new(Color3.fromRGB(176, 172, 168), Color3.fromRGB(214, 210, 206))

local function smokeEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = SMOKE
	emitter.Rate = 8
	emitter.Lifetime = NumberRange.new(2.4, 3.6)
	emitter.Speed = NumberRange.new(8, 12)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Parent = parent
	return emitter
end

local function steamEmitter(parent: BasePart, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(236, 236, 236))
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = parent
	return emitter
end

local function rigFor(model: Model, live: boolean): Rig
	local rig: Rig = {
		model = model,
		spins = {},
		rods = {},
		doors = {},
		heap = {},
		smoke = nil,
		vents = {},
		firebox = nil,
		flames = {},
		glows = {},
		flare = 0,
		lastFill = -1,
		breaches = {},
		doorOpen = 0,
		live = live,
		doorLamps = nil,
	}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local radius = part:GetAttribute("WheelRadius")
			local crank = part:GetAttribute("CrankRadius")
			local slide = part:GetAttribute("DoorSlide")
			if type(radius) == "number" then
				local pivot = part:GetAttribute("WheelPivot")
				table.insert(rig.spins, {
					part = part,
					base = part.CFrame,
					radius = radius,
					pivot = if typeof(pivot) == "Vector3" then pivot else nil,
				})
			elseif type(crank) == "number" then
				table.insert(rig.rods, {
					part = part,
					base = part.CFrame,
					radius = crank,
					phase = math.rad((part:GetAttribute("CrankPhase") :: number?) or 0),
				})
			elseif type(slide) == "number" then
				table.insert(rig.doors, { part = part, base = part.CFrame, slide = slide })
			end
			if part:GetAttribute("CoalTier") then
				table.insert(rig.heap, part)
			end
			if part.Name == "ChimneyTop" then
				rig.smoke = smokeEmitter(part)
			elseif part.Name == "SteamVent" then
				table.insert(rig.vents, steamEmitter(part, 0))
			elseif part.Name == "Firebox" then
				rig.firebox = part:FindFirstChildOfClass("PointLight")
			elseif part.Name == "FireFlame" then
				for _, emitter in part:GetChildren() do
					if emitter:IsA("ParticleEmitter") then
						table.insert(rig.flames, emitter)
					end
				end
			elseif part.Name == "StoveGlow" or part.Name == "LanternFlame" then
				local light = part:FindFirstChildOfClass("PointLight")
				if light then
					light:SetAttribute("Base", light.Brightness)
					table.insert(rig.glows, light)
				end
			end
		end
	end
	return rig
end

local LAMP = Color3.fromRGB(255, 196, 120)

-- The Last Call grace: a lantern glow pulses at every platform-side door (DepartureClock.InGrace).
local function updateDoorLamps(rig: Rig, t: number)
	local grace = Registry.DepartureClock ~= nil and Registry.DepartureClock.InGrace()
	local lamps = rig.doorLamps
	if lamps == nil then
		if not grace then
			return
		end
		-- found now, not in rigFor: with streaming the doors may not have been there yet
		local made: { PointLight } = {}
		for _, doorway in rig.model:GetDescendants() do
			if not (doorway:IsA("BasePart") and doorway.Name == "DoorBlocker" and doorway.Position.Z > 0) then
				continue
			end
			local light = Instance.new("PointLight")
			light.Name = "LastCallLamp"
			light.Color = LAMP
			light.Range = Tuning.LastCallGrace.LanternRange
			light.Shadows = false
			light.Enabled = false
			light.Parent = doorway
			table.insert(made, light)
		end
		rig.doorLamps = made
		lamps = made
	end
	local pulse = 0.5 + 0.5 * math.sin(t * Tuning.LastCallGrace.PulseRate * 2 * math.pi)
	for _, light in lamps :: { PointLight } do
		light.Enabled = grace
		light.Brightness = Tuning.LastCallGrace.LanternBrightness * pulse
	end
end

local function updateBreaches(rig: Rig)
	for _, part in rig.model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("BreachAnchor") then
			local active = part:GetAttribute("Breach") == true
			local emitter: ParticleEmitter? = rig.breaches[part]
			if active and emitter == nil then
				local steam = steamEmitter(part, 40)
				steam.EmissionDirection = Enum.NormalId.Front
				steam.Speed = NumberRange.new(10, 16)
				rig.breaches[part] = steam
				if Registry.AudioController then
					Registry.AudioController.Loop(`breach_{part.Name}`, "SteamLeak", part)
				end
			elseif not active and emitter then
				emitter:Destroy()
				rig.breaches[part] = nil
				if Registry.AudioController then
					Registry.AudioController.StopLoop(`breach_{part.Name}`)
				end
			end
		end
	end
end

local function track(model: Model, live: boolean)
	local rig = rigFor(model, live)
	table.insert(rigs, rig)
	if live then
		model:GetAttributeChangedSignal("CoalFill"):Connect(function()
			local fill: number = (model:GetAttribute("CoalFill") :: number?) or 0
			-- coal going in: the fire roars up and throws sparks
			if rig.lastFill >= 0 and fill > rig.lastFill + 0.005 then
				rig.flare = 1
				for _, emitter in rig.flames do
					emitter:Emit(if emitter.Name == "Sparks" then 26 else 10)
				end
			end
			rig.lastFill = fill
			for _, lump in rig.heap do
				lump.Transparency = if (lump:GetAttribute("CoalTier") :: number) <= fill + 0.001 then 0 else 1
			end
		end)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("BreachAnchor") then
				part:GetAttributeChangedSignal("Breach"):Connect(function()
					updateBreaches(rig)
				end)
			end
		end
	end
end

-- The live train's chimney top, where cues from the locomotive come from (DepartureClock).
function TrainVisualsController.Chimney(): BasePart?
	for _, rig in rigs do
		if rig.live and rig.smoke then
			return rig.smoke.Parent :: BasePart
		end
	end
	return nil
end

-- A puff of smoke from the live train's chimney.
function TrainVisualsController.Puff(count: number)
	for _, rig in rigs do
		if rig.live and rig.smoke then
			rig.smoke:Emit(count)
		end
	end
end

function TrainVisualsController.Init() end

function TrainVisualsController.Start()
	task.spawn(function()
		local train = Workspace:WaitForChild("Train", 60) :: Model?
		if train then
			track(train, true)
			ChalkSlate.hang(train)
		end
	end)
	task.spawn(function()
		local hall = Workspace:WaitForChild("DepotHall", 60)
		local display = hall and hall:WaitForChild("DisplayTrain", 30) :: Model?
		if display then
			track(display, false)
		end
	end)

	local spinParts: { BasePart } = {}
	local spinFrames: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt: number)
		local speed = if Registry.SceneryController then Registry.SceneryController.Speed() else 0
		angle += speed / 2.8 * dt
		table.clear(spinParts)
		table.clear(spinFrames)
		for _, rig in rigs do
			local rigSpeed = if rig.live then speed else 0
			local theta = if rig.live then angle else 0
			if rig.live then
				for _, spin in rig.spins do
					local a = theta * 2.8 / spin.radius
					table.insert(spinParts, spin.part)
					if spin.pivot then
						local pivot = CFrame.new(spin.pivot)
						table.insert(
							spinFrames,
							pivot * CFrame.Angles(0, 0, -a) * pivot:Inverse() * spin.base
						)
					else
						-- about world Z through its own centre, the same way round as the spokes and rods
						local at = spin.base.Position
						table.insert(spinFrames, CFrame.Angles(0, 0, -a) * (spin.base - at) + at)
					end
				end
				for _, rod in rig.rods do
					local a = theta + rod.phase
					local offset = Vector3.new(
						rod.radius * math.cos(a) - rod.radius * math.cos(rod.phase),
						-rod.radius * math.sin(a) + rod.radius * math.sin(rod.phase),
						0
					)
					table.insert(spinParts, rod.part)
					table.insert(spinFrames, rod.base + offset)
				end
			end
			local doorsOpen = rig.model:GetAttribute("DoorsOpen") == true
			rig.doorOpen = MathX.approach(rig.doorOpen, if doorsOpen then 1 else 0, dt * 1.6)
			for _, door in rig.doors do
				table.insert(spinParts, door.part)
				table.insert(
					spinFrames,
					door.base * CFrame.new(door.slide * MathX.smoothstep(0, 1, rig.doorOpen), 0, 0)
				)
			end
			-- A starving engine (no coal) shows it: thin pale smoke and a dying, sputtering fire.
			local starving = rig.live and Registry.StateController.Get({ "train", "starving" }) == true
			if rig.smoke then
				rig.smoke.Rate = if starving then 1.5 + rigSpeed * 0.04 else 6 + rigSpeed * 0.3
				rig.smoke.Acceleration = Vector3.new(-rigSpeed * 0.9, 3, 0)
				rig.smoke.Color = if starving then STARVING_SMOKE else SMOKE
			end
			local t = os.clock()
			if rig.live then
				updateDoorLamps(rig, t)
			end
			rig.flare = math.max(rig.flare - dt * 0.6, 0)
			if rig.firebox then
				rig.firebox.Brightness = if starving
					then math.max(0.15 + math.noise(t * 11) * 0.9, 0.05)
					else 1.8 + math.noise(t * 6) * 0.8 + 2.4 * rig.flare
			end
			for _, emitter in rig.flames do
				local base = if emitter.Name == "Sparks" then 4 else 18
				emitter.Rate = if starving then base * 0.15 else base * (1 + 1.5 * rig.flare)
			end
			for i, light in rig.glows do
				local base = (light:GetAttribute("Base") :: number?) or 1
				light.Brightness = base * (0.82 + 0.3 * math.noise(t * 4.5, i * 7.1))
			end
		end
		if #spinParts > 0 then
			Workspace:BulkMoveTo(spinParts, spinFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- cylinder puffs twice per wheel turn
		if speed > 4 and angle - lastPuff > math.pi then
			lastPuff = angle
			for _, rig in rigs do
				if rig.live then
					for _, vent in rig.vents do
						vent:Emit(6)
					end
				end
			end
		end
	end)
end

return TrainVisualsController
