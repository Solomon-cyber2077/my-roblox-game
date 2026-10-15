--!strict
--[[
	Client-side life on the static train (and the lobby's display train):
	turning wheels and coupling rods, sliding doors, chimney smoke and cylinder
	steam that follow speed, the tender's coal heap, breach steam, and every fire
	aboard: the firebox (it roars up when coal goes in, and gutters when there is
	none), the guard's stove and the lantern over his chairs. All of it is local
	CFrame and emitter work on anchored parts the server never touches again, so
	none of it replicates.

	The place streams instances, so a car's parts can arrive after the train model does
	(and leave and come back as new instances). Parts are registered as they stream in and
	dropped as they stream out; reading the model once left whole cars' doors still for
	players whose cars streamed in late.
]]

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MathX = require(ReplicatedStorage.Shared.Util.MathX)
local Safe = require(ReplicatedStorage.Shared.Util.Safe)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Difficulty = require(ReplicatedStorage.Shared.Config.Difficulty)

local Registry = require(script.Parent.Parent.Registry)
local BrokenThingMarkers = require(script.Parent.Parent.UI.BrokenThingMarkers)
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

-- The Last Light's cab door: its glazing sills were baked into the static FittingsP mesh, so they
-- hung in the doorway when the leaves slid open. They are cut from a local copy of the mesh and
-- rebuilt as parts that slide with their leaves (assets/train has the cut mesh for a re-import).
local CAB_FITTINGS = "LocomotiveFittingsP"
local CAB_SILL_X = { -- mesh-local x spans
	{ lo = -17.6, hi = -16.5, leaf = "DoorLeafL" },
	{ lo = -15.6, hi = -14.5, leaf = "DoorLeafR" },
}
local CAB_SILL_BAND = 0.08 -- the sills are the mesh's topmost faces
local CAB_SILL_TEAK = Color3.fromRGB(104, 58, 38)

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

-- Cuts the cab door's sills out of the Last Light's FittingsP mesh and hangs them on the leaves.
-- On any failure (no EditableMesh access) the mesh is left as it was and no sills are added.
local function cutCabSills(part: MeshPart)
	if part:GetAttribute("SillsCut") then
		return
	end
	part:SetAttribute("SillsCut", true)
	local ok, err = pcall(function()
		local em = AssetService:CreateEditableMeshAsync(Content.fromUri(part.MeshId))
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, v in em:GetVertices() do
			local p = em:GetPosition(v)
			lo, hi = lo:Min(p), hi:Max(p)
		end
		local scale = part.Size / (hi - lo)
		local sills: { [string]: { lo: Vector3, hi: Vector3 } } = {}
		for _, f in em:GetFaces() do
			local fLo, fHi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, v in em:GetFaceVertices(f) do
				local p = em:GetPosition(v)
				fLo, fHi = fLo:Min(p), fHi:Max(p)
			end
			for _, span in CAB_SILL_X do
				if fLo.X > span.lo and fHi.X < span.hi and fLo.Y > hi.Y - CAB_SILL_BAND and fLo.Z > 0 then
					em:RemoveFace(f)
					local s = sills[span.leaf]
					sills[span.leaf] = if s
						then { lo = s.lo:Min(fLo), hi = s.hi:Max(fHi) }
						else { lo = fLo, hi = fHi }
				end
			end
		end
		if next(sills) == nil then
			return nil -- already cut (a re-imported mesh)
		end
		em:RemoveUnused()
		local newLo, newHi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, v in em:GetVertices() do
			local p = em:GetPosition(v)
			newLo, newHi = newLo:Min(p), newHi:Max(p)
		end
		local base = part.CFrame
		local cut = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		part:ApplyMesh(cut)
		part.Size = (newHi - newLo) * scale
		part.CFrame = base * CFrame.new((newLo + newHi) / 2 * scale)
		for leafName, box in sills do
			local leaf = part.Parent and part.Parent:FindFirstChild(leafName)
			local sill = Instance.new("Part")
			sill.Name = `{leafName}Sill`
			sill.Size = (box.hi - box.lo) * scale
			sill.CFrame = base * CFrame.new((box.lo + box.hi) / 2 * scale)
			sill.Color = CAB_SILL_TEAK
			sill.Material = Enum.Material.Wood
			sill.Anchored = true
			sill.CanCollide = false
			sill.CanQuery = false
			sill.CanTouch = false
			sill.CastShadow = false
			sill:SetAttribute("DoorSlide", if leaf then leaf:GetAttribute("DoorSlide") else nil)
			sill.Parent = part.Parent
		end
		return nil
	end)
	if not ok then
		warn(`[TrainVisuals] cab sills left in the mesh: {err}`)
	end
end

-- Picks up one part of a rig: a wheel, rod, door leaf, coal lump, chimney, vent or fire.
local function register(rig: Rig, part: Instance)
	if not part:IsA("BasePart") then
		return
	end
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
	if part.Name == "DoorBlocker" then
		rig.doorLamps = nil -- a doorway arrived: the Last Call lamps are found again
	end
	if part.Name == CAB_FITTINGS and part:IsA("MeshPart") then
		task.spawn(cutCabSills, part)
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
			light:SetAttribute("BaseColor", light.Color)
			table.insert(rig.glows, light)
		end
	end
end

local function without<T>(list: { T }, gone: (T) -> boolean)
	for i = #list, 1, -1 do
		if gone(list[i]) then
			table.remove(list, i)
		end
	end
end

-- Drops a part that streamed out (it comes back as a new instance and is registered again).
local function unregister(rig: Rig, part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	without(rig.spins, function(spin: Spin)
		return spin.part == part
	end)
	without(rig.rods, function(rod: Rod)
		return rod.part == part
	end)
	without(rig.doors, function(door: Door)
		return door.part == part
	end)
	without(rig.heap, function(lump: BasePart)
		return lump == part
	end)
	without(rig.vents, function(emitter: ParticleEmitter)
		return emitter.Parent == part
	end)
	without(rig.flames, function(emitter: ParticleEmitter)
		return emitter.Parent == part
	end)
	without(rig.glows, function(light: PointLight)
		return light.Parent == part
	end)
	if rig.smoke and rig.smoke.Parent == part then
		rig.smoke = nil
	end
	if rig.firebox and rig.firebox.Parent == part then
		rig.firebox = nil
	end
	if part.Name == "DoorBlocker" then
		rig.doorLamps = nil
	end
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
		register(rig, part)
	end
	model.DescendantAdded:Connect(function(part)
		register(rig, part)
	end)
	model.DescendantRemoving:Connect(function(part)
		unregister(rig, part)
	end)
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
			local light = doorway:FindFirstChild("LastCallLamp") :: PointLight? or Instance.new("PointLight")
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

-- A leak's steam and hiss, by how bad it has got (LeakSeverity, from TrainService). Always on,
-- whatever the settings say: the leak is a thing in the world.
-- With Broken Things Markers off there is no arrow or HUD alert, so the leak itself is louder,
-- its hiss carries into the next cars and its steam is thick enough to see through doorways.
local function shapeLeak(part: BasePart, emitter: ParticleEmitter)
	local leaks = Difficulty.Leaks
	local severity = (part:GetAttribute("LeakSeverity") :: number?) or 1
	local off = not BrokenThingMarkers.visible()
	emitter.Rate = (if off then leaks.SteamRateOff else leaks.SteamRate) * severity
	emitter.Lifetime = if off then NumberRange.new(1, 1.9) else NumberRange.new(0.6, 1.1)
	emitter.Size = if off
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6.5) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4) })
	local sound = Registry.AudioController and Registry.AudioController.LoopSound(`breach_{part.Name}`)
	if sound then
		sound.RollOffMaxDistance = if off then leaks.HissRangeOff else leaks.HissRange
		sound.Volume = (0.45 + 0.25 * severity) * (if off then Difficulty.Hull.MarkersOffBoost else 1)
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
				shapeLeak(part, steam)
			elseif active and emitter then
				shapeLeak(part, emitter)
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
				part:GetAttributeChangedSignal("LeakSeverity"):Connect(function()
					updateBreaches(rig)
				end)
			end
		end
		-- the markers setting changes how loud and thick the leaks are
		for _, attribute in { "BrokenThingMarkers", "RunsStarted", "SettingsReady" } do
			Players.LocalPlayer:GetAttributeChangedSignal(attribute):Connect(function()
				updateBreaches(rig)
			end)
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

-- Studio only: Dev `sound hiss` puts a leak's steam and hiss at DevSoundAt for DEV_HISS_SECONDS,
-- shaped like a real one (shapeLeak, so it follows Broken Things Markers) (DevService).
local DEV_HISS_SECONDS = 30
local function devHiss()
	local line = (ReplicatedStorage:GetAttribute("DevSound") :: string?) or ""
	local audio = Registry.AudioController
	if string.match(line, "^(%a+)@") ~= "hiss" or audio == nil then
		return
	end
	local old = Workspace:FindFirstChild("DevLeak")
	if old then
		audio.StopLoop("breach_DevLeak") -- a newer one replaces it (same loop key)
		old:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = "DevLeak"
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = (ReplicatedStorage:GetAttribute("DevSoundAt") :: Vector3?) or Vector3.zero
	part:SetAttribute("LeakSeverity", 1)
	part.Parent = Workspace
	local steam = steamEmitter(part, 40)
	audio.Loop(`breach_{part.Name}`, "SteamLeak", part)
	local ends = os.clock() + DEV_HISS_SECONDS
	while os.clock() < ends and part.Parent do
		shapeLeak(part, steam)
		task.wait(0.5)
	end
	if part.Parent then
		audio.StopLoop(`breach_{part.Name}`)
		part:Destroy()
	end
end

function TrainVisualsController.Init() end

function TrainVisualsController.Start()
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("DevSound"):Connect(function()
			Safe.call("TrainVisualsController.devHiss", devHiss)
		end)
	end
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
			-- a failing hull flickers the lamps, then turns them to emergency red (HullController)
			local hull = Registry.HullController
			local tint = if hull then hull.LightTint() else nil
			for i, light in rig.glows do
				local base = (light:GetAttribute("Base") :: number?) or 1
				local scale = if hull then hull.LightScale(t, i) else 1
				light.Brightness = base * (0.82 + 0.3 * math.noise(t * 4.5, i * 7.1)) * scale
				light.Color = tint or (light:GetAttribute("BaseColor") :: Color3?) or light.Color
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
