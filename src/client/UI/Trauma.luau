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
	  death       in its grip: the tunnel shuts to black-red, holds while the elimination card is
	              up, then opens so a dead player can watch the crew (Logic/Grab.deathTunnel)
	  pinned      the Stoker pins you (Config/Grabs Lift -> Slam): thin red capillaries branch in from every
	              edge like the veins of a bloodshot eye and stay while it holds you, over a short red tint
	              (UI only; nothing is drawn in the world)
	  torn        an arm comes away (InjuryController): the view whites out for an instant, the
	              dark floods in hardest from the torn side, the colour all but goes and the world
	              swims, veins crack in from that side; it ebbs over the shock (Config/Injury Tear)

	look        the grab remake (Tuning.GrabLook, Logic/GrabLook), set by GrabController for the Stalker and
	              the Stoker: no heartbeat throb, and each Hollow its own screen. Cold (the Stalker): pale fog
	              creeping in like breath on glass, the colour going blue-grey, frost-pale cracks at a bite.
	              Heat (the Stoker): soot at the edges, ember sparks drifting up, a slow orange flare with his
	              ember light, soot-dark cracks. The hold shapes it: by the throat the dark closes top and
	              bottom like eyelids; in his ribs it squeezes in from the sides at every squeeze. Each grab's
	              variant leans it to one side and sets how fast it closes. Phones: no edge dark or fog, as
	              today; the sparks, the colour and the cracks stay. Fog and sparks scale to the setting.

	It owns its own frames, a ColorCorrection and a Blur on the camera; nothing here touches
	Lighting (AtmosphereController owns that).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Grab = require(ReplicatedStorage.Shared.Logic.Grab)
local GrabLook = require(ReplicatedStorage.Shared.Logic.GrabLook)
local TearFeedback = require(ReplicatedStorage.Shared.Logic.TearFeedback)

local Ui = require(script.Parent.Ui)

local Trauma = {}

local T = Tuning.Trauma
local TUNNEL = Color3.fromRGB(26, 3, 5) -- the tunnel's dark: oxblood, nearly black
local VEIN = Color3.fromRGB(92, 8, 12) -- dark, dried rather than bright red
local STRESS_TINT = Color3.fromRGB(255, 206, 198)
local EYE_VEIN = Color3.fromRGB(150, 16, 22) -- the bloodshot eye's capillaries: brighter and thinner
local PIN_TINT = Color3.fromRGB(255, 150, 146)
local RUSH_TINT = Color3.fromRGB(255, 244, 232)
-- the grab remake's two screens (Tuning.GrabLook)
local COLD_EDGE = Color3.fromRGB(120, 130, 142) -- fog grey, a little blue
local COLD_TINT = Color3.fromRGB(205, 220, 242)
local COLD_VEIN = Color3.fromRGB(196, 210, 226) -- frost-pale cracks
local COLD_FOG = Color3.fromRGB(176, 186, 198)
local COLD_TUNNEL = Color3.fromRGB(22, 8, 18) -- dying in the cold grip: the dark of frozen blood, not oxblood
local HEAT_EDGE = Color3.fromRGB(27, 19, 14) -- soot
local HEAT_TINT = Color3.fromRGB(255, 233, 215) -- a light warmth (owner 2026-11-22: balanced between the two earlier rounds)
local HEAT_FLARE = Color3.fromRGB(255, 207, 172)
local HEAT_VEIN = Color3.fromRGB(70, 20, 8)
local EMBER = Color3.fromRGB(244, 132, 59)
local SOOT = Color3.fromRGB(34, 26, 22)
local ASH = Color3.fromRGB(150, 144, 138)
local EDGE_SPECS = {
	{ anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), horizontal = true, rotation = 90 },
	{ anchor = Vector2.new(0, 1), pos = UDim2.fromScale(0, 1), horizontal = true, rotation = -90 },
	{ anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), horizontal = false, rotation = 0 },
	{ anchor = Vector2.new(1, 0), pos = UDim2.fromScale(1, 0), horizontal = false, rotation = 180 },
}

local layer: Frame
local edges: { { frame: Frame, horizontal: boolean, side: number } } = {}
local veins: Frame
local pinned = false -- the Stoker has you pinned: every vein is the eye kind, and they stay
local gui: ScreenGui? = nil
local black: Frame -- the solo crush's cut to black
local grade: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil

local stress = 0 -- 0..1, eased toward `stressTarget`
local stressTarget = 0
local hit = 0 -- 0..1, spikes on a bite and falls away fast
local beat = 0 -- 0..1, the last heartbeat's throb
local rush = 0 -- 0..1, adrenaline after an escape
local dead = 0 -- 0..1, the tunnel shut by a death in its grip
local diedAt: number? = nil -- os.clock() of that death (its curve: Logic/Grab.deathTunnel)
local tornAt: number? = nil -- os.clock() an arm came away (its shock: Logic/TearFeedback.shock)
local flash = 0 -- 0..1, its white-out instant, gone in a fraction of a second
local pinTint = 0 -- 0..1, the red tint of being pinned, gone in under a second
local tornSide = 0 -- -1 the left arm, 1 the right (the screen edge the dark floods from)
local nextRushBeat = 0
local rng = Random.new()

-- the grab remake (nil: today's tunnel)
type Speck = { frame: Frame, pos: Vector2, vel: Vector2, age: number, life: number, fog: boolean }
local look: string? = nil
local move: string? = nil
local lean = 0
local closeSpeed = 1
local tierName = "Quality"
local lookAt = 0
local squeeze = 0 -- 0..1, the ribs' squeeze, spikes on a bite
local flarePhase = 0
local heartless = false -- the rush after a remade grab: no racing-heart throb either
local specks: { Speck } = {}
local speckLayer: Frame

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
-- A phone (the compact layout): no dark vignette there, and the veins reach a little less far in.
local function phone(): boolean
	return Tuning.GrabScreen.Enabled and gui ~= nil and (gui :: ScreenGui):GetAttribute("Compact") == true
end

local function reachScale(): number
	return if phone() then Tuning.GrabScreen.PhoneVeins else 1
end

local capillary: (Vector2, number, number, number, number, number) -> ()

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
	local length = rng:NextNumber(0.16, 0.3) * reachScale()
	if pinned then
		-- pinned: the veins turn the red of a bloodshot eye, finer and branching, and stay until it lets go
		local view = Workspace.CurrentCamera.ViewportSize
		local at = Vector2.new(pos.X.Scale * view.X, pos.Y.Scale * view.Y)
		capillary(at, inward, length * 0.8 * math.min(view.X, view.Y), rng:NextNumber(2, 4), 0, 0)
		return
	end
	for branch = 0, rng:NextInteger(1, 2) do
		local vein = Ui.new("Frame", {
			Name = "Vein",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = pos,
			Size = UDim2.new(length * (1 - 0.3 * branch), 0, 0, rng:NextInteger(2, 4)),
			Rotation = inward + (if branch == 0 then 0 else rng:NextNumber(-28, 28)),
			BackgroundColor3 = if look == "Cold" then COLD_VEIN elseif look == "Heat" then HEAT_VEIN else VEIN,
			BackgroundTransparency = if look == "Cold" then 0.35 else 0.2,
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

-- One capillary: a chain of short, thinning segments that wander inward from `p` and fork, each
-- growing in after the one before it.
function capillary(p: Vector2, angle: number, length: number, width: number, delay: number, depth: number)
	local segments = rng:NextInteger(4, 7)
	local step = length / segments
	for i = 1, segments do
		angle += rng:NextNumber(-24, 24)
		local dir = Vector2.new(math.cos(math.rad(angle)), math.sin(math.rad(angle)))
		local seg = Ui.new("Frame", {
			Name = "PinnedVein",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(p.X, p.Y),
			Size = UDim2.fromOffset(0, width),
			Rotation = angle,
			BackgroundColor3 = EYE_VEIN,
			BackgroundTransparency = math.clamp(0.1 + 0.09 * i + 0.12 * depth, 0, 0.85),
			BorderSizePixel = 0,
			ZIndex = 18,
			Parent = veins,
		})
		Ui.tween(
			seg,
			{ Size = UDim2.fromOffset(step + 1, width) },
			TweenInfo.new(0.16, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delay + i * 0.09)
		)
		p += dir * step
		if depth < 2 and i >= 2 and rng:NextNumber() < 0.42 then
			capillary(
				p,
				angle + rng:NextNumber(-55, 55),
				length * 0.45,
				math.max(width * 0.7, 1),
				delay + i * 0.09,
				depth + 1
			)
		end
		width = math.max(width * 0.84, 1)
	end
end

-- One speck of the remade grab's screen: a soft fog patch at an edge (Cold), an ember spark or a fleck of
-- soot drifting up from an edge (Heat), or (`burst`) the slam's ash thrown up from the ground.
local function spawnSpeck(fog: boolean, burst: boolean?)
	local view = Workspace.CurrentCamera.ViewportSize
	local side = rng:NextInteger(1, 4)
	if lean ~= 0 and rng:NextNumber() < 0.35 then
		side = if lean < 0 then 3 else 4
	end
	local along = rng:NextNumber(0.05, 0.95)
	local pos = if side == 1
		then Vector2.new(along * view.X, 0)
		elseif side == 2 then Vector2.new(along * view.X, view.Y)
		elseif side == 3 then Vector2.new(0, along * view.Y)
		else Vector2.new(view.X, along * view.Y)
	local inward = (Vector2.new(view.X / 2, view.Y / 2) - pos).Unit
	local size, vel, color, life
	if fog then
		size = rng:NextNumber(0.22, 0.38) * math.min(view.X, view.Y)
		vel = inward * rng:NextNumber(6, 14)
		color = COLD_FOG
		life = rng:NextNumber(3, 5)
	elseif burst then
		pos = Vector2.new(rng:NextNumber(0.1, 0.9) * view.X, view.Y)
		size = rng:NextNumber(3, 7)
		vel = Vector2.new(rng:NextNumber(-90, 90), -rng:NextNumber(160, 320))
		color = ASH
		life = rng:NextNumber(0.8, 1.4)
	else
		local ember = rng:NextNumber() < 0.5
		size = if ember then rng:NextNumber(1.75, 3.75) else rng:NextNumber(2.5, 5)
		vel = inward * rng:NextNumber(10, 30) + Vector2.new(rng:NextNumber(-12, 12), -rng:NextNumber(30, 70))
		color = if ember then EMBER else SOOT
		life = rng:NextNumber(1.4, 2.6)
	end
	local frame = Ui.new("Frame", {
		Name = if fog then "Fog" else "Speck",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 18,
		Parent = speckLayer,
	})
	Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	if fog then
		Ui.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = rng:NextNumber(0, 360),
			Parent = frame,
		})
	end
	table.insert(specks, { frame = frame, pos = pos, vel = vel, age = 0, life = life, fog = fog })
end

local stepSpecks: (number, boolean) -> ()

local function step(dt: number)
	stress += (stressTarget - stress) * math.min(dt * 3, 1)
	hit *= math.exp(-dt * 5)
	beat *= math.exp(-dt * 7)
	if rush > 0 then
		rush = math.max(rush - dt / T.AdrenalineSeconds, 0)
		-- the racing heart settles as the rush ebbs
		if os.clock() >= nextRushBeat then
			nextRushBeat = os.clock() + 0.32 + 0.6 * (1 - rush)
			if not heartless then
				Trauma.beat(0.5 * rush)
			end
		end
	end
	if diedAt then
		local since = os.clock() - diedAt
		dead = Grab.deathTunnel(since)
		if since > T.DeathHoldSeconds and dead <= 0 then
			diedAt = nil
		end
	end
	flash *= math.exp(-dt * 6)
	pinTint *= math.exp(-dt * 3.5)
	local shock = if tornAt then TearFeedback.shock(os.clock() - tornAt) else 0
	if tornAt and shock <= 0 and os.clock() - tornAt > 0.1 then
		tornAt = nil
	end

	local reach = 0.18 * stress + 0.06 * beat * stress + 0.08 * hit + 0.08 * rush * beat + 0.5 * dead
	local alpha =
		math.clamp(0.55 * stress + 0.25 * beat * stress + 0.3 * hit + 0.3 * rush * beat + dead, 0, 1)
	-- a remade grab's screen eases out with the stress, in its own colours, then today's code takes over
	if look ~= nil and stressTarget == 0 and stress < 0.01 and dead < 0.005 then
		look = nil
	end
	local lookOn = look ~= nil
	local closed = if lookOn then GrabLook.close(os.clock() - lookAt, closeSpeed) * stress else 0
	squeeze *= math.exp(-dt * 4)
	for _, edge in edges do
		if lookOn then
			local weight = 1
			if move == "Lifted" then
				-- by the throat: the dark closes top and bottom, like eyelids
				weight = if edge.horizontal then 1.9 else 0.35
			elseif move == "Pressed" then
				-- in its ribs: the sides press in, harder at each squeeze
				weight = if edge.horizontal then 0.45 else 1.3 + 1.6 * squeeze
			end
			if edge.side ~= 0 and lean ~= 0 then
				weight *= if edge.side == lean then 1.4 else 0.7
			end
			-- the Stoker's soot stays near the rim (owner 2026-11-22: "goes to close to the center")
			local lookReach = if look == "Heat" then 0.08 else 0.15
			local r = (lookReach * closed + 0.08 * hit) * weight + 0.5 * dead
			local a = math.clamp(
				(if look == "Cold" then 0.42 else 0.45) * closed * math.min(weight, 1.3) + 0.3 * hit + dead,
				0,
				1
			)
			edge.frame.BackgroundColor3 = if dead > 0.01
				then (if look == "Cold" then COLD_TUNNEL else TUNNEL)
				elseif look == "Cold" then COLD_EDGE
				else HEAT_EDGE
			edge.frame.Size = if edge.horizontal then UDim2.fromScale(1, r) else UDim2.fromScale(r, 1)
			edge.frame.BackgroundTransparency = if phone() then 1 else 1 - a
			continue
		end
		edge.frame.BackgroundColor3 = TUNNEL
		-- the torn side floods deepest; the rest closes in a little
		local flood = if edge.side ~= 0 and edge.side == tornSide then 0.42 else 0.13
		local r = reach + flood * shock + 0.07 * pinTint
		local a = math.clamp(alpha + (0.35 + flood) * shock + 0.4 * pinTint, 0, 1)
		edge.frame.Size = if edge.horizontal then UDim2.fromScale(1, r) else UDim2.fromScale(r, 1)
		edge.frame.BackgroundTransparency = if phone() then 1 else 1 - a
	end
	layer.Visible = alpha > 0.005 or shock > 0.005 or #veins:GetChildren() > 0 or #specks > 0

	stepSpecks(dt, lookOn)
	local g, b = effects()
	if lookOn then
		local tier = Tuning.GrabLook.Tiers[tierName]
		local flare = if look == "Heat" then 0.5 + 0.5 * math.sin(os.clock() * 2.1 + flarePhase) else 0
		if look == "Cold" then
			g.Saturation = math.max(-0.6 * closed + 0.28 * rush - 0.3 * hit - 0.6 * dead - 0.75 * shock, -1)
			g.Contrast = 0.08 * closed + 0.15 * hit + 0.25 * shock
			g.Brightness = -0.03 * closed + 0.18 * hit - 0.1 * dead + 0.55 * flash
			g.TintColor =
				Color3.new(1, 1, 1):Lerp(COLD_TINT, closed):Lerp(RUSH_TINT, rush):Lerp(STRESS_TINT, shock)
		else
			g.Saturation = math.max(-0.12 * closed + 0.28 * rush - 0.3 * hit - 0.6 * dead - 0.75 * shock, -1)
			g.Contrast = 0.18 * closed + 0.18 * hit + 0.25 * shock
			g.Brightness = 0.04 * flare * closed + 0.2 * hit - 0.1 * dead + 0.55 * flash
			g.TintColor = Color3.new(1, 1, 1)
				:Lerp(HEAT_TINT, closed)
				:Lerp(RUSH_TINT, rush)
				:Lerp(HEAT_FLARE, 0.2 * flare * closed)
				:Lerp(STRESS_TINT, shock)
				:Lerp(PIN_TINT, pinTint)
		end
		g.Enabled = true
		b.Size = (T.StressBlur * closed + T.HitBlur * hit) * tier.blur + T.TornBlur * (0.35 * shock + flash)
		b.Enabled = b.Size > 0.2
		return
	end
	g.Saturation = math.max(-0.45 * stress - 0.3 * hit + 0.28 * rush - 0.6 * dead - 0.75 * shock, -1)
	g.Contrast = 0.22 * stress + 0.18 * hit + 0.16 * rush + 0.25 * shock
	g.Brightness = 0.22 * hit + 0.05 * rush * beat - 0.1 * dead + 0.55 * flash - 0.06 * shock
	g.TintColor = Color3.new(1, 1, 1)
		:Lerp(STRESS_TINT, stress)
		:Lerp(RUSH_TINT, rush)
		:Lerp(STRESS_TINT, shock)
		:Lerp(PIN_TINT, pinTint)
	g.Enabled = stress > 0.01
		or hit > 0.01
		or rush > 0.01
		or dead > 0.005
		or shock > 0.01
		or flash > 0.01
		or pinTint > 0.01
	b.Size = T.StressBlur * stress + T.HitBlur * hit + T.TornBlur * (0.35 * shock + flash)
	b.Enabled = b.Size > 0.2
end

function stepSpecks(dt: number, on: boolean)
	if on then
		local tier = Tuning.GrabLook.Tiers[tierName]
		-- held at the setting's count; fog only where a vignette may be drawn (not on phones)
		local want = if look == "Cold" then (if phone() then 0 else tier.fog) else tier.specks
		if #specks < want and rng:NextNumber() < dt * want * 1.5 then
			spawnSpeck(look == "Cold")
		end
	end
	for i = #specks, 1, -1 do
		local s = specks[i]
		s.age += dt * (if on then 1 else 2.5)
		s.pos += s.vel * dt
		if not s.fog then
			s.vel += Vector2.new(0, 40 * dt) -- ash falls back, embers slow as they rise
		end
		local u = s.age / s.life
		if u >= 1 or s.frame.Parent == nil then
			s.frame:Destroy()
			table.remove(specks, i)
			continue
		end
		local fade = math.sin(math.pi * u) -- in, then out
		s.frame.Position = UDim2.fromOffset(s.pos.X, s.pos.Y)
		s.frame.BackgroundTransparency = 1 - fade * (if s.fog then 0.32 else 0.85)
	end
	speckLayer.Visible = #specks > 0
end

function Trauma.mount(screen: ScreenGui)
	gui = screen
	layer = Ui.new("Frame", {
		Name = "Trauma",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 18, -- under the struggle check and the alerts, over the world
		Parent = screen,
	})
	-- reach up under the top bar too, or the tunnel's top edge starts below it and leaves a hard line
	-- across the screen (owner 2026-11-22)
	local function fitInset()
		local inset = if screen.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
		layer.Position = UDim2.fromOffset(0, -inset.Y)
		layer.Size = UDim2.new(1, 0, 1, inset.Y)
	end
	fitInset()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fitInset)
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
	speckLayer = Ui.new("Frame", {
		Name = "Specks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 18,
		Parent = layer,
	})
	veins = Ui.new("Frame", {
		Name = "Veins",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 18,
		Parent = layer,
	})
	black = Ui.new("Frame", {
		Name = "Blackout",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 19,
		Parent = screen,
	})
	RunService.RenderStepped:Connect(step)
end

local function clearEye(fade: number)
	pinned = false
	for _, seg in veins:GetChildren() do
		if fade > 0 then
			Ui.tween(seg :: Frame, { BackgroundTransparency = 1 }, TweenInfo.new(fade))
			task.delay(fade + 0.05, function()
				seg:Destroy()
			end)
		else
			seg:Destroy()
		end
	end
end

-- The Stoker pinned you: the grab's veins turn red, dense and eye-shaped and stay; a short red tint.
function Trauma.pinned()
	pinned = true
	for k = 1, 26 do
		crack((k - 1) % 4 + 1)
	end
	pinTint = 1
	hit = math.max(hit, 0.6)
end

-- The solo crush lands: black at once (the crunch is the only thing left).
function Trauma.blackout()
	black.BackgroundTransparency = 0
	task.delay(T.DeathHoldSeconds, function()
		Ui.tween(black, { BackgroundTransparency = 1 }, TweenInfo.new(1.2))
	end)
end

-- The grab remake's screen for this hold (GrabController, Logic/GrabLook): `kind` "Cold" or "Heat" (nil:
-- today's tunnel), the hold's camera move, this grab's variant and the effects setting.
function Trauma.look(kind: string?, holdMove: string?, variant: GrabLook.Variant?, tier: string)
	if kind ~= look then
		lookAt = os.clock()
	end
	look = kind
	move = holdMove
	lean = if variant then variant.lean else 0
	closeSpeed = if variant then variant.speed else 1
	tierName = tier
	flarePhase = rng:NextNumber(0, math.pi * 2)
	if kind then
		heartless = true
	end
end

-- The ribs squeeze (a bite in the Stalker's embrace): the sides press in.
function Trauma.squeeze()
	squeeze = 1
end

-- The slam: ash thrown up from the ground.
function Trauma.puff()
	local tier = Tuning.GrabLook.Tiers[tierName]
	for _ = 1, math.max(math.floor(tier.specks * 0.6), 4) do
		spawnSpeck(false, true)
	end
end

-- It has you: the stress rises and holds until `release`.
function Trauma.seize()
	stressTarget = 1
	heartless = false
	rush = 0
	dead = 0
	diedAt = nil
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
	clearEye(0.6)
	if alive then
		rush = 1
		nextRushBeat = 0
	end
end

-- You died in its grip: the tunnel shuts, then opens again (a dead player stays dead and watches).
function Trauma.died()
	stressTarget = 0
	clearEye(1.2)
	rush = 0
	if diedAt == nil then
		diedAt = os.clock()
	end
end

-- A new body: the screen clears at once.
function Trauma.clear()
	stress, stressTarget, hit, beat, rush, dead, flash = 0, 0, 0, 0, 0, 0, 0
	tornAt = nil
	diedAt = nil
	for _, vein in veins:GetChildren() do
		vein:Destroy()
	end
	pinTint = 0
	look = nil
	heartless = false
	for _, s in specks do
		s.frame:Destroy()
	end
	table.clear(specks)
	clearEye(0)
	black.BackgroundTransparency = 1
end

-- 0..1 how strongly the rush is on you now (for the breath sound).
function Trauma.rush(): number
	return rush
end

return Trauma
