--!strict
--[[
	The landscape's prop library, built from primitives through Visual/Kit.

	Every builder takes a parent, a ground-level pivot (y = the ground top) and a
	context with the chunk's Rng, the biome and whether the prop may cast a
	shadow. Parts are non-colliding decor; Chunk.finish welds them to the
	chunk root. Rotor parts carry a Jointed attribute so Chunk leaves their
	Motor6D alone, and lights that should flicker carry a Flicker attribute
	(their base brightness).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Kit = require(Shared.Visual.Kit)
local Rng = require(Shared.Util.Rng)

local Biomes = require(script.Parent.Biomes)

-- lights: false keeps fires dark (set pieces ration their PointLights).
-- far: built for the mid field, where windows, doors and chimneys are too small to read.
export type Ctx = { rng: Rng.Rng, biome: Biomes.Def, shadow: boolean, lights: boolean?, far: boolean? }

local Props = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"

local WINDOW = rgb(255, 188, 112)
local DARK_WINDOW = rgb(30, 28, 30)
local HOLLOW = rgb(18, 16, 20)
local HOLLOW_EYE = rgb(190, 236, 255)

-- Helpers ---------------------------------------------------------------------------------

local function block(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	return Kit.block(
		parent,
		size,
		cf,
		color,
		{ material = material, collide = false, shadow = shadow == true }
	)
end

local function wedge(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	return Kit.wedge(
		parent,
		size,
		cf,
		color,
		{ material = material, collide = false, shadow = shadow == true }
	)
end

local function post(
	parent: Instance,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	return Kit.post(
		parent,
		height,
		diameter,
		cf,
		color,
		{ material = material, collide = false, shadow = shadow == true }
	)
end

local function ball(
	parent: Instance,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	return Kit.ball(
		parent,
		diameter,
		cf,
		color,
		{ material = material, collide = false, shadow = shadow == true }
	)
end

local function jitter(ctx: Ctx, color: Color3, spread: number): Color3
	return Kit.jitter(color, spread, ctx.rng:next())
end

local function pickColor(ctx: Ctx, list: { Color3 }): Color3
	return jitter(ctx, ctx.rng:pick(list), 0.08)
end

-- A pitched roof along local X over a w x d footprint, eaves at height y.
local function gable(
	parent: Instance,
	w: number,
	d: number,
	rise: number,
	at: CFrame,
	color: Color3,
	shadow: boolean
)
	wedge(parent, Vector3.new(w, rise, d / 2), at * CFrame.new(0, rise / 2, -d / 4), color, M.Slate, shadow)
	wedge(
		parent,
		Vector3.new(w, rise, d / 2),
		at * CFrame.new(0, rise / 2, d / 4) * Kit.angles(0, 180, 0),
		color,
		M.Slate,
		shadow
	)
end

local function windowRow(parent: Instance, ctx: Ctx, w: number, d: number, y: number, at: CFrame, lit: number)
	if ctx.far then
		return
	end
	local count = math.max(1, math.floor(w / 7))
	for i = 1, count do
		local x = -w / 2 + (i - 0.5) * w / count
		local color = if ctx.rng:chance(lit) then WINDOW else DARK_WINDOW
		local pane =
			block(parent, Vector3.new(1.6, 2, 0.2), at * CFrame.new(x, y, -d / 2 - 0.05), color, M.Neon)
		if color == DARK_WINDOW then
			pane.Material = M.Glass
		end
	end
end

-- Effects -------------------------------------------------------------------------------------

local function emitterPart(parent: Instance, size: Vector3, cf: CFrame): BasePart
	return Kit.block(parent, size, cf, Color3.new(), { collide = false, shadow = false, transparency = 1 })
end

function Props.smoke(parent: Instance, cf: CFrame, scale: number, color: Color3?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE
	emitter.Color = ColorSequence.new(color or rgb(46, 42, 40), rgb(96, 90, 86))
	emitter.Rate = 3 + scale
	emitter.Lifetime = NumberRange.new(7, 11)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2 * scale),
		NumberSequenceKeypoint.new(1, 10 * scale),
	})
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Parent = emitterPart(parent, Vector3.new(scale, 0.4, scale), cf)
	return emitter
end

-- Flames, rising sparks, a smoke column and (optionally) a flickering orange light.
function Props.fire(parent: Instance, cf: CFrame, size: number, light: boolean)
	local holder = emitterPart(parent, Vector3.new(size, 0.4, size), cf)
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = FIRE
	flames.Color = ColorSequence.new(rgb(255, 200, 110), rgb(220, 70, 30))
	flames.LightEmission = 1
	flames.Rate = 12 + size * 3
	flames.Lifetime = NumberRange.new(0.6, 1.2)
	flames.Speed = NumberRange.new(3, 7)
	flames.SpreadAngle = Vector2.new(15, 15)
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	flames.Acceleration = Vector3.new(0, 5, 0)
	flames.Parent = holder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKS
	sparks.Color = ColorSequence.new(rgb(255, 170, 80))
	sparks.LightEmission = 1
	sparks.Rate = 6
	sparks.Lifetime = NumberRange.new(2, 4)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = holder
	Props.smoke(parent, cf * CFrame.new(0, size * 0.8, 0), size * 0.6, rgb(30, 26, 24))
	if light then
		local glow = Kit.pointLight(holder, rgb(255, 130, 60), 2.2, 18 + size * 3, false)
		glow:SetAttribute("Flicker", glow.Brightness)
	end
end

-- A Hollow standing still, facing along the frame's -Z, with glowing eyes.
function Props.hollow(parent: Instance, cf: CFrame, scale: number)
	local s = scale
	local lean = cf * Kit.angles(-8, 0, 0)
	for _, x in { -0.45, 0.45 } do
		block(
			parent,
			Vector3.new(0.45, 4.2, 0.45) * s,
			cf * CFrame.new(x * s, 2.1 * s, 0),
			HOLLOW,
			M.Fabric,
			true
		)
	end
	block(parent, Vector3.new(1.5, 3.2, 0.8) * s, lean * CFrame.new(0, 5.7 * s, 0), HOLLOW, M.Fabric, true)
	for _, x in { -1.05, 1.05 } do
		block(
			parent,
			Vector3.new(0.38, 4.8, 0.38) * s,
			lean * CFrame.new(x * s, 4.6 * s, -0.2 * s) * Kit.angles(6, 0, x * 4),
			HOLLOW,
			M.Fabric,
			true
		)
	end
	local head = lean * CFrame.new(0, 7.9 * s, -0.35 * s) * Kit.angles(-12, 0, 0)
	block(parent, Vector3.new(0.9, 1.2, 0.95) * s, head, HOLLOW, M.Fabric, true)
	for _, x in { -0.22, 0.22 } do
		Kit.neon(
			parent,
			Vector3.new(0.2, 0.12, 0.06) * s,
			head * CFrame.new(x * s, 0.12 * s, -0.5 * s),
			HOLLOW_EYE
		)
	end
end

-- Trees and plants -------------------------------------------------------------------------------

function Props.tree(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	local h = ctx.rng:range(16, 30) * (scale or 1)
	local trunkH = h * 0.5
	post(
		parent,
		trunkH,
		h * 0.07,
		cf * CFrame.new(0, trunkH / 2, 0),
		jitter(ctx, ctx.biome.trunk, 0.1),
		M.Wood,
		ctx.shadow
	)
	local crown = h * 0.55
	local color = pickColor(ctx, ctx.biome.foliage)
	ball(parent, crown, cf * CFrame.new(0, trunkH + crown * 0.3, 0), color, M.Grass, ctx.shadow)
	ball(
		parent,
		crown * 0.75,
		cf * CFrame.new(crown * 0.35, trunkH + crown * 0.05, crown * 0.2),
		Kit.shade(color, 0.9),
		M.Grass,
		ctx.shadow
	)
	if ctx.rng:chance(0.6) then
		ball(
			parent,
			crown * 0.7,
			cf * CFrame.new(-crown * 0.3, trunkH + crown * 0.15, -crown * 0.25),
			Kit.shade(color, 1.08),
			M.Grass,
			ctx.shadow
		)
	end
end

local function pineTiers(parent: Instance, cf: CFrame, ctx: Ctx, h: number, snowy: boolean)
	local trunkH = h * 0.3
	post(
		parent,
		trunkH,
		h * 0.06,
		cf * CFrame.new(0, trunkH / 2, 0),
		jitter(ctx, ctx.biome.trunk, 0.1),
		M.Wood,
		ctx.shadow
	)
	local color = pickColor(ctx, ctx.biome.foliage)
	local tiers = 3
	for i = 1, tiers do
		local u = (i - 1) / tiers
		local diameter = h * (0.5 - u * 0.36)
		local tierH = h * 0.3
		local y = trunkH * 0.8 + u * h * 0.62 + tierH / 2
		local tierColor = if snowy and i == tiers then rgb(226, 232, 238) else Kit.shade(color, 1 + u * 0.1)
		post(
			parent,
			tierH,
			diameter,
			cf * CFrame.new(0, y, 0) * Kit.angles(0, i * 37, 0),
			tierColor,
			if snowy and i == tiers then M.Snow else M.Grass,
			ctx.shadow
		)
	end
	if snowy then
		post(parent, 0.6, h * 0.46, cf * CFrame.new(0, trunkH * 0.8 + h * 0.3, 0), rgb(232, 236, 242), M.Snow)
	end
end

function Props.pine(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	pineTiers(parent, cf, ctx, ctx.rng:range(22, 40) * (scale or 1), false)
end

function Props.snowPine(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	pineTiers(parent, cf, ctx, ctx.rng:range(20, 36) * (scale or 1), true)
end

function Props.deadTree(parent: Instance, cf: CFrame, ctx: Ctx)
	local h = ctx.rng:range(12, 24)
	local color = jitter(ctx, rgb(46, 38, 32), 0.1)
	local trunk = cf * Kit.angles(0, 0, ctx.rng:range(-6, 6))
	block(
		parent,
		Vector3.new(h * 0.06, h, h * 0.06),
		trunk * CFrame.new(0, h / 2, 0),
		color,
		M.Wood,
		ctx.shadow
	)
	for i = 1, ctx.rng:int(2, 3) do
		local len = h * ctx.rng:range(0.3, 0.5)
		local side = if i % 2 == 0 then 1 else -1
		block(
			parent,
			Vector3.new(h * 0.035, len, h * 0.035),
			trunk
				* CFrame.new(0, h * (0.5 + i * 0.12), 0)
				* Kit.angles(0, ctx.rng:range(0, 360), side * ctx.rng:range(30, 55))
				* CFrame.new(0, len / 2, 0),
			color,
			M.Wood,
			ctx.shadow
		)
	end
end

function Props.bush(parent: Instance, cf: CFrame, ctx: Ctx)
	local size = ctx.rng:range(5, 10)
	local color = pickColor(ctx, ctx.biome.foliage)
	ball(parent, size, cf * CFrame.new(0, size * 0.2, 0), color, M.Grass)
	ball(parent, size * 0.7, cf * CFrame.new(size * 0.45, size * 0.1, 0), Kit.shade(color, 0.92), M.Grass)
end

function Props.boulder(parent: Instance, cf: CFrame, ctx: Ctx)
	local size = ctx.rng:range(5, 16)
	local color = jitter(ctx, ctx.biome.rock, 0.12)
	block(
		parent,
		Vector3.new(size, size * 0.7, size * 0.85),
		cf
			* CFrame.new(0, size * 0.2, 0)
			* Kit.angles(ctx.rng:range(-20, 20), ctx.rng:range(0, 90), ctx.rng:range(-20, 20)),
		color,
		M.Rock,
		ctx.shadow
	)
	if ctx.rng:chance(0.5) then
		block(
			parent,
			Vector3.new(size, size, size) * 0.5,
			cf
				* CFrame.new(size * 0.6, 0, size * 0.3)
				* Kit.angles(ctx.rng:range(0, 40), ctx.rng:range(0, 90), 0),
			Kit.shade(color, 0.9),
			M.Rock
		)
	end
end

function Props.reeds(parent: Instance, cf: CFrame, ctx: Ctx)
	for _ = 1, 5 do
		local h = ctx.rng:range(3, 6)
		block(
			parent,
			Vector3.new(0.3, h, 0.3),
			cf
				* CFrame.new(ctx.rng:range(-2.5, 2.5), h / 2, ctx.rng:range(-2.5, 2.5))
				* Kit.angles(ctx.rng:range(-10, 10), 0, ctx.rng:range(-10, 10)),
			jitter(ctx, rgb(150, 146, 90), 0.15),
			M.Grass
		)
	end
end

function Props.dune(parent: Instance, cf: CFrame, ctx: Ctx)
	local size = ctx.rng:range(28, 60)
	local color = jitter(ctx, ctx.biome.hill, 0.06)
	ball(parent, size, cf * CFrame.new(0, -size * 0.36, 0), color, M.Sand)
	ball(
		parent,
		size * 0.7,
		cf * CFrame.new(size * 0.5, -size * 0.28, size * 0.2),
		Kit.shade(color, 1.04),
		M.Sand
	)
	Props.reeds(parent, cf * CFrame.new(-size * 0.2, size * 0.1, 0), ctx)
end

function Props.rockWall(parent: Instance, cf: CFrame, ctx: Ctx)
	local color = jitter(ctx, ctx.biome.rock, 0.1)
	for i = 1, 3 do
		local h = ctx.rng:range(18, 46)
		block(
			parent,
			Vector3.new(ctx.rng:range(14, 26), h, ctx.rng:range(10, 18)),
			cf
				* CFrame.new((i - 2) * 14, h / 2 - 3, ctx.rng:range(-4, 4))
				* Kit.angles(ctx.rng:range(-8, 8), ctx.rng:range(-25, 25), ctx.rng:range(-8, 8)),
			Kit.shade(color, 0.9 + i * 0.05),
			M.Slate,
			ctx.shadow
		)
	end
	if ctx.biome.snowcap then
		block(
			parent,
			Vector3.new(34, 1.2, 16),
			cf * CFrame.new(0, 38, 0) * Kit.angles(0, 0, 4),
			rgb(232, 236, 242),
			M.Snow
		)
	end
end

-- Farm ---------------------------------------------------------------------------------------------

function Props.haystack(parent: Instance, cf: CFrame, ctx: Ctx)
	local color = jitter(ctx, rgb(196, 166, 92), 0.08)
	if ctx.rng:chance(0.5) then
		post(parent, 4, 5.5, cf * CFrame.new(0, 2.75, 0) * Kit.angles(90, 0, 0), color, M.Fabric)
		post(
			parent,
			4,
			5.5,
			cf * CFrame.new(4.4, 2.75, 1) * Kit.angles(90, 20, 0),
			Kit.shade(color, 0.94),
			M.Fabric
		)
	else
		ball(parent, 9, cf * CFrame.new(0, 1.5, 0), color, M.Fabric, ctx.shadow)
		post(parent, 3, 6, cf * CFrame.new(0, 1.5, 0), Kit.shade(color, 0.9), M.Fabric)
	end
end

function Props.fence(parent: Instance, cf: CFrame, ctx: Ctx)
	local length = ctx.rng:range(24, 48)
	local color = jitter(ctx, rgb(98, 80, 62), 0.1)
	local posts = math.floor(length / 6) + 1
	for i = 0, posts - 1 do
		block(
			parent,
			Vector3.new(0.5, 4, 0.5),
			cf * CFrame.new(-length / 2 + i * length / (posts - 1), 2, 0),
			color,
			M.Wood
		)
	end
	for _, y in { 1.6, 3.2 } do
		block(parent, Vector3.new(length, 0.35, 0.25), cf * CFrame.new(0, y, 0), color, M.Wood)
	end
end

function Props.scarecrow(parent: Instance, cf: CFrame, ctx: Ctx)
	local wood = jitter(ctx, rgb(92, 72, 52), 0.1)
	block(parent, Vector3.new(0.5, 8, 0.5), cf * CFrame.new(0, 4, 0), wood, M.Wood)
	block(parent, Vector3.new(6, 0.5, 0.5), cf * CFrame.new(0, 6, 0), wood, M.Wood)
	block(parent, Vector3.new(2.2, 2.6, 1), cf * CFrame.new(0, 5.6, 0), rgb(110, 84, 60), M.Fabric)
	ball(parent, 1.6, cf * CFrame.new(0, 7.9, 0), rgb(196, 166, 92), M.Fabric)
	post(parent, 0.3, 2.6, cf * CFrame.new(0, 8.6, 0), rgb(54, 42, 34), M.Fabric)
end

function Props.farmhouse(parent: Instance, cf: CFrame, ctx: Ctx)
	local w, d, h = ctx.rng:range(16, 24), ctx.rng:range(12, 16), ctx.rng:range(9, 12)
	local walls =
		jitter(ctx, ctx.rng:pick({ rgb(214, 202, 178), rgb(170, 128, 96), rgb(196, 180, 150) }), 0.05)
	block(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), walls, M.Plaster, ctx.shadow)
	gable(
		parent,
		w + 1.5,
		d + 1.5,
		d * 0.45,
		cf * CFrame.new(0, h, 0),
		jitter(ctx, rgb(70, 52, 46), 0.1),
		ctx.shadow
	)
	block(
		parent,
		Vector3.new(2, 6, 2),
		cf * CFrame.new(w * 0.3, h + d * 0.35, 0),
		rgb(120, 70, 56),
		M.Brick,
		ctx.shadow
	)
	windowRow(parent, ctx, w, d, h * 0.55, cf, 0.6)
	block(
		parent,
		Vector3.new(2.6, 5, 0.3),
		cf * CFrame.new(-w * 0.3, 2.5, -d / 2 - 0.1),
		rgb(70, 50, 38),
		M.Wood
	)
end

function Props.barn(parent: Instance, cf: CFrame, ctx: Ctx)
	local w, d, h = ctx.rng:range(22, 30), ctx.rng:range(16, 20), ctx.rng:range(11, 14)
	local walls = jitter(ctx, rgb(134, 52, 42), 0.08)
	block(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), walls, M.WoodPlanks, ctx.shadow)
	gable(
		parent,
		w + 1,
		d + 2,
		d * 0.6,
		cf * CFrame.new(0, h, 0),
		jitter(ctx, rgb(60, 56, 54), 0.1),
		ctx.shadow
	)
	block(
		parent,
		Vector3.new(8, 10, 0.4),
		cf * CFrame.new(0, 5, -d / 2 - 0.15),
		Kit.shade(walls, 0.7),
		M.WoodPlanks
	)
	for _, r in { 45, -45 } do
		block(
			parent,
			Vector3.new(0.4, 13, 0.2),
			cf * CFrame.new(0, 5, -d / 2 - 0.4) * Kit.angles(0, 0, r),
			rgb(220, 210, 190),
			M.Wood
		)
	end
end

-- Returns the rotor's Motor6D. The client turns it through Motor6D.Transform.
function Props.windmill(parent: Instance, cf: CFrame, ctx: Ctx): Motor6D
	local h = ctx.rng:range(22, 30)
	local body = jitter(ctx, rgb(208, 196, 172), 0.06)
	post(parent, h, 9, cf * CFrame.new(0, h / 2, 0), body, M.Plaster, ctx.shadow)
	post(parent, 0.8, 9.8, cf * CFrame.new(0, h * 0.35, 0), Kit.shade(body, 0.8), M.Wood)
	local cap = ball(parent, 9.4, cf * CFrame.new(0, h, 0), rgb(70, 56, 48), M.WoodPlanks, ctx.shadow)
	windowRow(parent, ctx, 4, 9, h * 0.6, cf, 0.7)
	local axle = cf * CFrame.new(0, h + 1, -5.2)
	local rotor = Kit.model("Rotor", parent)
	local hub = Kit.cylinder(
		rotor,
		1.2,
		1.6,
		axle * Kit.angles(0, 90, 0),
		rgb(60, 50, 44),
		{ collide = false, shadow = false }
	)
	hub:SetAttribute("Jointed", true)
	local sail = jitter(ctx, rgb(226, 214, 190), 0.05)
	for i = 0, 3 do
		local arm = axle * Kit.angles(0, 0, i * 90 + 15) * CFrame.new(0, 7.5, -0.4)
		local blade = Kit.block(rotor, Vector3.new(2.6, 13, 0.25), arm * CFrame.new(1, 0, 0), sail, {
			material = M.Fabric,
			collide = false,
			shadow = ctx.shadow,
		})
		local spar = Kit.block(rotor, Vector3.new(0.4, 14, 0.4), arm, rgb(70, 56, 46), {
			material = M.Wood,
			collide = false,
			shadow = false,
		})
		for _, part in { blade, spar } do
			part:SetAttribute("Jointed", true)
			Kit.weld(part, hub)
			part.Anchored = false
		end
	end
	hub.Anchored = false
	local motor = Instance.new("Motor6D")
	motor.Name = "RotorMotor"
	motor.Part0 = cap
	motor.Part1 = hub
	motor.C0 = cap.CFrame:ToObjectSpace(hub.CFrame)
	motor.C1 = CFrame.identity
	motor.Parent = cap
	return motor
end

-- Railway ----------------------------------------------------------------------------------------------

function Props.siding(parent: Instance, cf: CFrame, ctx: Ctx)
	local length = ctx.rng:range(60, 120)
	block(
		parent,
		Vector3.new(length, 1, 9),
		cf * CFrame.new(0, 0.3, 0),
		jitter(ctx, rgb(86, 80, 74), 0.06),
		M.Pebble
	)
	for _, z in { -2.6, 2.6 } do
		block(parent, Vector3.new(length, 0.5, 0.45), cf * CFrame.new(0, 1.05, z), rgb(110, 92, 80), M.Metal)
	end
	if ctx.rng:chance(0.55) then
		Props.wagon(parent, cf * CFrame.new(ctx.rng:range(-length / 3, length / 3), 1.3, 0), ctx)
	end
end

function Props.wagon(parent: Instance, cf: CFrame, ctx: Ctx)
	local body = jitter(ctx, ctx.rng:pick({ rgb(92, 60, 44), rgb(70, 70, 74), rgb(110, 84, 58) }), 0.08)
	block(parent, Vector3.new(16, 1, 7), cf * CFrame.new(0, 1.5, 0), rgb(34, 32, 32), M.Metal)
	block(parent, Vector3.new(16, 5, 8), cf * CFrame.new(0, 4.5, 0), body, M.WoodPlanks, ctx.shadow)
	if ctx.rng:chance(0.6) then
		block(parent, Vector3.new(15, 1, 7), cf * CFrame.new(0, 6.6, 0), rgb(28, 27, 26), M.Slate)
	end
	for _, x in { -5, 5 } do
		Kit.cylinder(parent, 7, 2.6, cf * CFrame.new(x, 1, 0) * Kit.angles(0, 90, 0), rgb(40, 36, 36), {
			material = M.Metal,
			collide = false,
			shadow = false,
		})
	end
end

function Props.sleeperStack(parent: Instance, cf: CFrame, ctx: Ctx)
	local wood = jitter(ctx, rgb(70, 54, 40), 0.1)
	for layer = 0, 2 do
		block(
			parent,
			Vector3.new(9, 0.8, 4.2),
			cf * CFrame.new(0, 0.4 + layer * 0.8, 0) * Kit.angles(0, layer * 90, 0),
			Kit.shade(wood, 1 - layer * 0.05),
			M.Wood
		)
	end
end

function Props.signalBox(parent: Instance, cf: CFrame, ctx: Ctx)
	local brick = jitter(ctx, rgb(132, 72, 56), 0.06)
	block(parent, Vector3.new(14, 8, 10), cf * CFrame.new(0, 4, 0), brick, M.Brick, ctx.shadow)
	block(
		parent,
		Vector3.new(14, 6, 10),
		cf * CFrame.new(0, 11, 0),
		rgb(214, 204, 180),
		M.WoodPlanks,
		ctx.shadow
	)
	block(parent, Vector3.new(12.6, 3.6, 10.2), cf * CFrame.new(0, 11.4, 0), WINDOW, M.Neon)
	gable(parent, 15, 11.5, 3.4, cf * CFrame.new(0, 14, 0), rgb(56, 50, 48), ctx.shadow)
	block(
		parent,
		Vector3.new(3, 0.4, 8),
		cf * CFrame.new(8.6, 4, 0) * Kit.angles(-40, 0, 0),
		rgb(60, 50, 44),
		M.Wood
	)
end

function Props.waterTower(parent: Instance, cf: CFrame, ctx: Ctx)
	local iron = rgb(48, 46, 46)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			block(parent, Vector3.new(0.8, 16, 0.8), cf * CFrame.new(x, 8, z), iron, M.Metal, ctx.shadow)
		end
	end
	post(
		parent,
		8,
		11,
		cf * CFrame.new(0, 20, 0),
		jitter(ctx, rgb(96, 70, 54), 0.08),
		M.WoodPlanks,
		ctx.shadow
	)
	post(parent, 1.4, 12, cf * CFrame.new(0, 24.7, 0), iron, M.Metal)
	block(parent, Vector3.new(0.8, 0.8, 8), cf * CFrame.new(0, 17, -8) * Kit.angles(20, 0, 0), iron, M.Metal)
end

function Props.semaphore(parent: Instance, cf: CFrame, ctx: Ctx)
	local iron = rgb(40, 40, 44)
	post(parent, 18, 0.6, cf * CFrame.new(0, 9, 0), iron, M.Metal, ctx.shadow)
	local arm = cf * CFrame.new(0, 16, -0.5) * Kit.angles(0, 0, if ctx.rng:chance(0.5) then 0 else 40)
	block(parent, Vector3.new(5, 0.9, 0.2), arm * CFrame.new(2.5, 0, 0), rgb(176, 40, 36), M.SmoothPlastic)
	block(
		parent,
		Vector3.new(0.5, 0.92, 0.22),
		arm * CFrame.new(4, 0, 0),
		rgb(236, 230, 220),
		M.SmoothPlastic
	)
	Kit.neon(
		parent,
		Vector3.new(0.5, 0.5, 0.2),
		cf * CFrame.new(0, 14.8, -0.6),
		if ctx.rng:chance(0.5) then rgb(255, 70, 50) else rgb(120, 255, 160)
	)
	block(parent, Vector3.new(1, 0.2, 1.4), cf * CFrame.new(0, 17.9, 0), iron, M.Metal)
end

function Props.shed(parent: Instance, cf: CFrame, ctx: Ctx)
	local w, d, h = ctx.rng:range(8, 14), ctx.rng:range(7, 10), ctx.rng:range(6, 8)
	local walls = jitter(ctx, ctx.rng:pick({ rgb(90, 70, 54), rgb(84, 86, 80), rgb(110, 92, 70) }), 0.08)
	block(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), walls, M.WoodPlanks, ctx.shadow)
	wedge(
		parent,
		Vector3.new(w + 1, 2.4, d + 1),
		cf * CFrame.new(0, h + 1.2, 0),
		rgb(64, 58, 56),
		M.CorrodedMetal,
		ctx.shadow
	)
	block(
		parent,
		Vector3.new(2.4, 4.6, 0.25),
		cf * CFrame.new(0, 2.3, -d / 2 - 0.1),
		Kit.shade(walls, 0.7),
		M.Wood
	)
end

-- Coalfield ----------------------------------------------------------------------------------------------

function Props.slagHeap(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	local size = ctx.rng:range(30, 70) * (scale or 1)
	local color = jitter(ctx, rgb(36, 34, 33), 0.12)
	ball(parent, size, cf * CFrame.new(0, -size * 0.3, 0), color, M.Slate, ctx.shadow)
	ball(
		parent,
		size * 0.6,
		cf * CFrame.new(size * 0.45, -size * 0.2, size * 0.1),
		Kit.shade(color, 1.1),
		M.Slate
	)
	if ctx.rng:chance(0.3) then
		Props.smoke(parent, cf * CFrame.new(0, size * 0.2, 0), 1.5, rgb(70, 64, 60))
	end
end

function Props.chimney(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	local h = ctx.rng:range(40, 70) * (scale or 1)
	local brick = jitter(ctx, rgb(116, 64, 50), 0.08)
	post(parent, h, 6 * (scale or 1), cf * CFrame.new(0, h / 2, 0), brick, M.Brick, ctx.shadow)
	post(parent, 2, 7.2 * (scale or 1), cf * CFrame.new(0, h - 1, 0), Kit.shade(brick, 0.6), M.Brick)
	block(
		parent,
		Vector3.new(16, 10, 14) * (scale or 1),
		cf * CFrame.new(0, 5 * (scale or 1), 0),
		Kit.shade(brick, 0.9),
		M.Brick,
		ctx.shadow
	)
	Props.smoke(parent, cf * CFrame.new(0, h + 1, 0), 3 * (scale or 1), rgb(36, 32, 30))
end

function Props.headframe(parent: Instance, cf: CFrame, ctx: Ctx)
	local iron = jitter(ctx, rgb(60, 50, 44), 0.08)
	for _, z in { -3, 3 } do
		block(parent, Vector3.new(0.9, 30, 0.9), cf * CFrame.new(-4, 15, z), iron, M.Metal, ctx.shadow)
		block(
			parent,
			Vector3.new(0.9, 34, 0.9),
			cf * CFrame.new(5, 15, z) * Kit.angles(0, 0, 18),
			iron,
			M.Metal,
			ctx.shadow
		)
		for y = 6, 24, 9 do
			block(
				parent,
				Vector3.new(8, 0.5, 0.5),
				cf * CFrame.new(0, y, z) * Kit.angles(0, 0, 30),
				iron,
				M.Metal
			)
		end
	end
	Kit.cylinder(parent, 0.8, 9, cf * CFrame.new(-4, 31, 0) * Kit.angles(0, 90, 0), rgb(40, 36, 34), {
		material = M.Metal,
		collide = false,
		shadow = ctx.shadow,
	})
	block(
		parent,
		Vector3.new(14, 10, 12),
		cf * CFrame.new(16, 5, 0),
		jitter(ctx, rgb(110, 66, 52), 0.06),
		M.Brick,
		ctx.shadow
	)
	gable(parent, 14.5, 12.5, 4, cf * CFrame.new(16, 10, 0), rgb(50, 46, 44), ctx.shadow)
end

function Props.terrace(parent: Instance, cf: CFrame, ctx: Ctx)
	local count = ctx.rng:int(3, 6)
	local w, d, h = count * 9, 10, 10
	local brick = jitter(ctx, rgb(118, 70, 56), 0.06)
	block(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), brick, M.Brick, ctx.shadow)
	gable(parent, w + 0.6, d + 1.2, 4, cf * CFrame.new(0, h, 0), rgb(54, 52, 56), ctx.shadow)
	for i = 1, count do
		block(
			parent,
			Vector3.new(1.4, 3.2, 3),
			cf * CFrame.new(-w / 2 + (i - 0.5) * 9, h + 3.6, 0),
			Kit.shade(brick, 0.8),
			M.Brick
		)
	end
	windowRow(parent, ctx, w, d, 3, cf, 0.35)
	windowRow(parent, ctx, w, d, 7, cf, 0.25)
end

-- Town ----------------------------------------------------------------------------------------------

function Props.house(parent: Instance, cf: CFrame, ctx: Ctx, burning: boolean?)
	local w, d, h = ctx.rng:range(12, 18), ctx.rng:range(10, 13), ctx.rng:range(10, 15)
	local charred = burning == true or ctx.rng:chance(0.3)
	local walls =
		jitter(ctx, ctx.rng:pick({ rgb(178, 160, 136), rgb(140, 92, 72), rgb(122, 114, 104) }), 0.06)
	if charred then
		walls = Kit.shade(walls, 0.45)
	end
	block(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), walls, M.Brick, ctx.shadow)
	if charred and ctx.rng:chance(0.5) then
		-- the roof has fallen in: a few scorched rafters
		for i = -1, 1 do
			block(
				parent,
				Vector3.new(0.6, 0.6, d + 1),
				cf * CFrame.new(i * w * 0.3, h + 0.6, 0) * Kit.angles(ctx.rng:range(-20, 20), 0, 0),
				rgb(30, 26, 24),
				M.Wood
			)
		end
	else
		gable(
			parent,
			w + 1,
			d + 1.2,
			d * 0.5,
			cf * CFrame.new(0, h, 0),
			Kit.shade(rgb(64, 54, 52), if charred then 0.6 else 1),
			ctx.shadow
		)
	end
	block(
		parent,
		Vector3.new(1.6, 5, 1.6),
		cf * CFrame.new(w * 0.3, h + 3, d * 0.15),
		Kit.shade(walls, 0.8),
		M.Brick,
		ctx.shadow
	)
	windowRow(parent, ctx, w, d, h * 0.3, cf, if charred then 0 else 0.4)
	windowRow(parent, ctx, w, d, h * 0.7, cf, if charred then 0 else 0.3)
	if burning then
		Props.fire(
			parent,
			cf * CFrame.new(ctx.rng:range(-w / 4, w / 4), h * 0.8, 0),
			ctx.rng:range(5, 8),
			ctx.lights ~= false
		)
	end
end

function Props.ruinFire(parent: Instance, cf: CFrame, ctx: Ctx)
	local walls = Kit.shade(jitter(ctx, rgb(140, 120, 100), 0.08), 0.5)
	local w = ctx.rng:range(12, 18)
	block(
		parent,
		Vector3.new(w, ctx.rng:range(6, 10), 1),
		cf * CFrame.new(0, 4, -5),
		walls,
		M.Brick,
		ctx.shadow
	)
	block(
		parent,
		Vector3.new(1, ctx.rng:range(4, 8), 10),
		cf * CFrame.new(-w / 2, 3, 0),
		walls,
		M.Brick,
		ctx.shadow
	)
	block(
		parent,
		Vector3.new(w * 0.6, 3, 1),
		cf * CFrame.new(w * 0.2, 1.5, 5) * Kit.angles(0, 0, 6),
		walls,
		M.Brick
	)
	block(
		parent,
		Vector3.new(w * 0.8, 1.5, 8),
		cf * CFrame.new(0, 0.5, 0) * Kit.angles(4, 20, 0),
		rgb(26, 22, 20),
		M.Slate
	)
	Props.fire(parent, cf * CFrame.new(0, 1.5, 0), ctx.rng:range(5, 9), ctx.lights ~= false)
end

function Props.church(parent: Instance, cf: CFrame, ctx: Ctx, burning: boolean?)
	local stone = jitter(ctx, rgb(150, 142, 130), 0.06)
	if burning then
		stone = Kit.shade(stone, 0.55)
	end
	block(parent, Vector3.new(30, 16, 14), cf * CFrame.new(0, 8, 0), stone, M.Limestone, ctx.shadow)
	gable(parent, 31, 15, 9, cf * CFrame.new(0, 16, 0), rgb(56, 52, 54), ctx.shadow)
	block(parent, Vector3.new(9, 30, 9), cf * CFrame.new(-18, 15, 0), stone, M.Limestone, ctx.shadow)
	-- spire: two crossed slim gables
	for _, yaw in { 0, 90 } do
		local base = cf * CFrame.new(-18, 30, 0) * Kit.angles(0, yaw, 0)
		wedge(
			parent,
			Vector3.new(1, 22, 4.5),
			base * CFrame.new(0, 11, -2.25),
			rgb(60, 58, 62),
			M.Slate,
			ctx.shadow
		)
		wedge(
			parent,
			Vector3.new(1, 22, 4.5),
			base * CFrame.new(0, 11, 2.25) * Kit.angles(0, 180, 0),
			rgb(60, 58, 62),
			M.Slate,
			ctx.shadow
		)
	end
	for i = 1, 4 do
		local pane = block(
			parent,
			Vector3.new(2, 6, 0.2),
			cf * CFrame.new(-10 + i * 5, 9, -7.1),
			if burning then rgb(255, 140, 70) else rgb(120, 90, 160),
			M.Neon
		)
		pane.Transparency = 0.1
	end
	if burning then
		Props.fire(parent, cf * CFrame.new(4, 17, 0), 9, ctx.lights ~= false)
	end
end

-- Coast -------------------------------------------------------------------------------------------------

function Props.lighthouse(parent: Instance, cf: CFrame, ctx: Ctx)
	local white = rgb(232, 228, 220)
	local red = rgb(170, 46, 42)
	block(parent, Vector3.new(14, 4, 14), cf * CFrame.new(0, 1, 0), jitter(ctx, ctx.biome.rock, 0.06), M.Rock)
	for i = 0, 3 do
		post(
			parent,
			9,
			8 - i * 0.6,
			cf * CFrame.new(0, 7.5 + i * 9, 0),
			if i % 2 == 0 then white else red,
			M.Concrete,
			ctx.shadow
		)
	end
	post(parent, 0.8, 9, cf * CFrame.new(0, 39.5, 0), rgb(40, 40, 44), M.Metal)
	local lamp = Kit.neon(
		parent,
		Vector3.new(4, 4, 4),
		cf * CFrame.new(0, 42, 0),
		rgb(255, 236, 180),
		Enum.PartType.Ball
	)
	Kit.pointLight(lamp, rgb(255, 230, 170), 3, 60, false)
	post(parent, 2, 5, cf * CFrame.new(0, 45, 0), red, M.Metal)
end

-- Clumps for the mid field ------------------------------------------------------------------------------

-- Seen from the mid field only, so no trunks: a crown per tree is all that reads at that range.
function Props.grove(parent: Instance, cf: CFrame, ctx: Ctx, pines: boolean)
	local count = ctx.rng:int(3, 5)
	local snowy = ctx.biome.snowcap and ctx.biome.groundMaterial == M.Snow
	for _ = 1, count do
		local at = cf * CFrame.new(ctx.rng:range(-40, 40), 0, ctx.rng:range(-30, 30))
		local h = ctx.rng:range(26, 44)
		local color = pickColor(ctx, ctx.biome.foliage)
		if pines then
			post(
				parent,
				h,
				h * 0.36,
				at * CFrame.new(0, h * 0.5, 0),
				if snowy then Kit.shade(color, 1.4) else color,
				M.Grass
			)
		else
			ball(parent, h * 0.6, at * CFrame.new(0, h * 0.45, 0), color, M.Grass)
		end
	end
end

-- Dispatch ------------------------------------------------------------------------------------------------

type Builder = (Instance, CFrame, Ctx) -> ()

local BY_KIND: { [string]: Builder } = {
	Tree = Props.tree,
	Pine = Props.pine,
	SnowPine = Props.snowPine,
	DeadTree = Props.deadTree,
	Bush = Props.bush,
	Boulder = Props.boulder,
	Reeds = Props.reeds,
	Dune = Props.dune,
	RockWall = Props.rockWall,
	Haystack = Props.haystack,
	Fence = Props.fence,
	Scarecrow = Props.scarecrow,
	Farmhouse = Props.farmhouse,
	Barn = Props.barn,
	Windmill = function(parent, cf, ctx)
		Props.windmill(parent, cf, ctx)
	end,
	Siding = Props.siding,
	Wagon = Props.wagon,
	SleeperStack = Props.sleeperStack,
	SignalBox = Props.signalBox,
	WaterTower = Props.waterTower,
	Shed = Props.shed,
	SlagHeap = Props.slagHeap,
	Chimney = Props.chimney,
	Headframe = Props.headframe,
	Terrace = Props.terrace,
	House = Props.house,
	RuinFire = Props.ruinFire,
	Church = Props.church,
	Lighthouse = Props.lighthouse,
	Grove = function(parent, cf, ctx)
		Props.grove(parent, cf, ctx, false)
	end,
	PineGrove = function(parent, cf, ctx)
		Props.grove(parent, cf, ctx, true)
	end,
}

-- Kinds that face the track (buildings), so they get a yaw of 0 or 180 rather than a random one.
local FACING: { [string]: boolean } = {
	Farmhouse = true,
	Barn = true,
	SignalBox = true,
	Shed = true,
	Terrace = true,
	House = true,
	Church = true,
	Siding = true,
	Fence = true,
	Wagon = true,
	Headframe = true,
	RockWall = true,
}

-- Footprint radius used to keep props off reserved ground.
local RADIUS: { [string]: number } = {
	Siding = 60,
	Terrace = 30,
	Church = 26,
	Barn = 18,
	Farmhouse = 14,
	Headframe = 22,
	SlagHeap = 30,
	Chimney = 10,
	Windmill = 10,
	Grove = 45,
	PineGrove = 45,
	Dune = 30,
	RockWall = 26,
}

function Props.build(kind: string, parent: Instance, cf: CFrame, ctx: Ctx)
	local builder = BY_KIND[kind]
	if builder then
		builder(parent, cf, ctx)
	end
end

function Props.faces(kind: string): boolean
	return FACING[kind] == true
end

function Props.radius(kind: string): number
	return RADIUS[kind] or 8
end

-- Tall kinds cast shadows when they stand near the track.
function Props.tall(kind: string): boolean
	return kind ~= "Bush"
		and kind ~= "Reeds"
		and kind ~= "Haystack"
		and kind ~= "Fence"
		and kind ~= "Dune"
		and kind ~= "SleeperStack"
		and kind ~= "Boulder"
end

return Props
