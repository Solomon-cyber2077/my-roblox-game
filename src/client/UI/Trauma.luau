--!strict
--[[
	What a grab does to your nerves, drawn on the screen (GrabController drives it):

	  stress      while it has you: the view tunnels in from the edges in a near-black
	              oxblood that throbs with every heartbeat, the colour drains and hardens, and
	              the world goes a little soft
	  hit         each bite, squeeze or yank: the view blurs and whites out for an instant, dark
	              veins crack in from the screen's edges and fade (no splashes of blood)
	  adrenaline  after you tear free: everything snaps sharp and over-bright, your heart races
	              and slowly settles and you gasp for breath, for Tuning.Trauma.AdrenalineSeconds
	  death       in its grip: the tunnel shuts to black-red
	  torn        an arm comes away (InjuryController): the view whites out for an instant, the
	              dark floods in hardest from the torn side, the colour all but goes and the world
	              swims, veins crack in from that side; it ebbs over the shock (Config/Injury Tear)

	It owns its own frames, a ColorCorrection and a Blur on the camera; nothing here touches
	Lighting (AtmosphereController owns that).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local TearFeedback = require(ReplicatedStorage.Shared.Logic.TearFeedback)

local Ui = require(script.Parent.Ui)

local Trauma = {}

local T = Tuning.Trauma
local TUNNEL = Color3.fromRGB(26, 3, 5) -- the tunnel's dark: oxblood, nearly black
local VEIN = Color3.fromRGB(92, 8, 12) -- dark, dried rather than bright red
local STRESS_TINT = Color3.fromRGB(255, 206, 198)
local RUSH_TINT = Color3.fromRGB(255, 244, 232)
local EDGE_SPECS = {
	{ anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), horizontal = true, rotation = 90 },
	{ anchor = Vector2.new(0, 1), pos = UDim2.fromScale(0, 1), horizontal = true, rotation = -90 },
	{ anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), horizontal = false, rotation = 0 },
	{ anchor = Vector2.new(1, 0), pos = UDim2.fromScale(1, 0), horizontal = false, rotation = 180 },
}

local layer: Frame
local edges: { { frame: Frame, horizontal: boolean, side: number } } = {}
local veins: Frame
local grade: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil

local stress = 0 -- 0..1, eased toward `stressTarget`
local stressTarget = 0
local hit = 0 -- 0..1, spikes on a bite and falls away fast
local beat = 0 -- 0..1, the last heartbeat's throb
local rush = 0 -- 0..1, adrenaline after an escape
local dead = 0 -- 0..1, the tunnel shutting at a death in its grip
local tornAt: number? = nil -- os.clock() an arm came away (its shock: Logic/TearFeedback.shock)
local flash = 0 -- 0..1, its white-out instant, gone in a fraction of a second
local tornSide = 0 -- -1 the left arm, 1 the right (the screen edge the dark floods from)
local nextRushBeat = 0
local rng = Random.new()

local function effects(): (ColorCorrectionEffect, BlurEffect)
	local camera = Workspace.CurrentCamera
	if grade == nil or (grade :: ColorCorrectionEffect).Parent ~= camera then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "Trauma"
		g.Enabled = false
		g.Parent = camera
		grade = g
	end
	if blur == nil or (blur :: BlurEffect).Parent ~= camera then
		local b = Instance.new("BlurEffect")
		b.Name = "TraumaBlur"
		b.Size = 0
		b.Enabled = false
		b.Parent = camera
		blur = b
	end
	return grade :: ColorCorrectionEffect, blur :: BlurEffect
end

-- A dark vein crack that reaches in from a random point on the screen's edge and fades.
-- One vein cracking in from a screen edge (1 top, 2 bottom, 3 left, 4 right; random if nil).
local function crack(from: number?)
	local side = from or rng:NextInteger(1, 4)
	local along = rng:NextNumber(0.1, 0.9)
	local pos = if side == 1
		then UDim2.fromScale(along, 0)
		elseif side == 2 then UDim2.fromScale(along, 1)
		elseif side == 3 then UDim2.fromScale(0, along)
		else UDim2.fromScale(1, along)
	-- pointing into the screen, splayed a little either way
	local inward = ({ 90, -90, 0, 180 })[side] + rng:NextNumber(-35, 35)
	local length = rng:NextNumber(0.16, 0.3)
	for branch = 0, rng:NextInteger(1, 2) do
		local vein = Ui.new("Frame", {
			Name = "Vein",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = pos,
			Size = UDim2.new(length * (1 - 0.3 * branch), 0, 0, rng:NextInteger(2, 4)),
			Rotation = inward + (if branch == 0 then 0 else rng:NextNumber(-28, 28)),
			BackgroundColor3 = VEIN,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = veins,
		})
		Ui.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.6, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = vein,
		})
		Ui.tween(
			vein,
			{ BackgroundTransparency = 1 },
			TweenInfo.new(T.VeinSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		)
		task.delay(T.VeinSeconds + 0.1, function()
			vein:Destroy()
		end)
	end
end

local function step(dt: number)
	stress += (stressTarget - stress) * math.min(dt * 3, 1)
	hit *= math.exp(-dt * 5)
	beat *= math.exp(-dt * 7)
	if rush > 0 then
		rush = math.max(rush - dt / T.AdrenalineSeconds, 0)
		-- the racing heart settles as the rush ebbs
		if os.clock() >= nextRushBeat then
			nextRushBeat = os.clock() + 0.32 + 0.6 * (1 - rush)
			Trauma.beat(0.5 * rush)
		end
	end
	if dead > 0 then
		dead = math.min(dead + dt / 1.2, 1)
	end
	flash *= math.exp(-dt * 6)
	local shock = if tornAt then TearFeedback.shock(os.clock() - tornAt) else 0
	if tornAt and shock <= 0 and os.clock() - tornAt > 0.1 then
		tornAt = nil
	end

	local reach = 0.18 * stress + 0.06 * beat * stress + 0.08 * hit + 0.08 * rush * beat + 0.5 * dead
	local alpha =
		math.clamp(0.55 * stress + 0.25 * beat * stress + 0.3 * hit + 0.3 * rush * beat + dead, 0, 1)
	for _, edge in edges do
		-- the torn side floods deepest; the rest closes in a little
		local flood = if edge.side ~= 0 and edge.side == tornSide then 0.42 else 0.13
		local r = reach + flood * shock
		local a = math.clamp(alpha + (0.35 + flood) * shock, 0, 1)
		edge.frame.Size = if edge.horizontal then UDim2.fromScale(1, r) else UDim2.fromScale(r, 1)
		edge.frame.BackgroundTransparency = 1 - a
	end
	layer.Visible = alpha > 0.005 or shock > 0.005 or #veins:GetChildren() > 0

	local g, b = effects()
	g.Saturation = math.max(-0.45 * stress - 0.3 * hit + 0.28 * rush - 0.6 * dead - 0.75 * shock, -1)
	g.Contrast = 0.22 * stress + 0.18 * hit + 0.16 * rush + 0.25 * shock
	g.Brightness = 0.22 * hit + 0.05 * rush * beat - 0.1 * dead + 0.55 * flash - 0.06 * shock
	g.TintColor = Color3.new(1, 1, 1):Lerp(STRESS_TINT, stress):Lerp(RUSH_TINT, rush):Lerp(STRESS_TINT, shock)
	g.Enabled = stress > 0.01 or hit > 0.01 or rush > 0.01 or dead > 0 or shock > 0.01 or flash > 0.01
	b.Size = T.StressBlur * stress + T.HitBlur * hit + T.TornBlur * (0.35 * shock + flash)
	b.Enabled = b.Size > 0.2
end

function Trauma.mount(gui: ScreenGui)
	layer = Ui.new("Frame", {
		Name = "Trauma",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 18, -- under the struggle check and the alerts, over the world
		Parent = gui,
	})
	for _, spec in EDGE_SPECS do
		local frame = Ui.new("Frame", {
			Name = "Tunnel",
			AnchorPoint = spec.anchor,
			Position = spec.pos,
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = TUNNEL,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 18,
			Parent = layer,
		})
		Ui.new("UIGradient", {
			Rotation = spec.rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = frame,
		})
		local side = if spec.horizontal then 0 elseif spec.anchor.X > 0.5 then 1 else -1
		table.insert(edges, { frame = frame, horizontal = spec.horizontal, side = side })
	end
	veins = Ui.new("Frame", {
		Name = "Veins",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 18,
		Parent = layer,
	})
	RunService.RenderStepped:Connect(step)
end

-- It has you: the stress rises and holds until `release`.
function Trauma.seize()
	stressTarget = 1
	rush = 0
	dead = 0
	Trauma.hit(1)
end

-- A bite landed: `strength` 0..1.
function Trauma.hit(strength: number)
	hit = math.max(hit, math.clamp(strength, 0, 1))
	for _ = 1, if strength > 0.8 then 3 else 2 do
		crack()
	end
end

-- One heartbeat's throb: the tunnel pulses in time with it.
function Trauma.beat(strength: number)
	beat = math.max(beat, math.clamp(strength, 0, 1))
end

-- An arm came away: `side` -1 the left, 1 the right (its shock: Logic/TearFeedback.shock).
function Trauma.torn(side: number)
	tornSide = if side < 0 then -1 else 1
	tornAt = os.clock()
	flash = 1
	hit = 1
	local from = if tornSide < 0 then 3 else 4
	for _ = 1, 4 do
		crack(from)
	end
	crack()
	crack()
end

-- The hold ended. `alive`: you tore free (the adrenaline rush) rather than died in its grip.
function Trauma.release(alive: boolean)
	stressTarget = 0
	if alive then
		rush = 1
		nextRushBeat = 0
	end
end

-- You died in its grip: the tunnel shuts.
function Trauma.died()
	stressTarget = 0
	rush = 0
	dead = math.max(dead, 0.01)
end

-- A new body: the screen clears at once.
function Trauma.clear()
	stress, stressTarget, hit, beat, rush, dead, flash = 0, 0, 0, 0, 0, 0, 0
	tornAt = nil
	for _, vein in veins:GetChildren() do
		vein:Destroy()
	end
end

-- 0..1 how strongly the rush is on you now (for the breath sound).
function Trauma.rush(): number
	return rush
end

return Trauma
