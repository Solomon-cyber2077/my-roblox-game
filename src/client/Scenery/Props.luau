--!strict
--[[
	The landscape's prop library, built from primitives through Visual/Kit.

	Every builder takes a parent, a ground-level pivot (y = the ground top, the
	building's front facing the frame's -Z) and a context: the chunk's Rng, the
	biome, whether the prop may cast a shadow, whether its fires may light, and
	whether it stands in the mid field (`far`), where windows, doors and
	chimneys are too small to read and are skipped.

	Parts are non-colliding decor; Chunk.finish welds them to the chunk root.
	Rotor parts carry a Jointed attribute so Chunk leaves their Motor6D alone;
	lights that should flicker carry a Flicker attribute (their base brightness).
	Parts that touch or cross are sized so no two visible faces share a plane
	(lune run audit checks every prop).
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

local WINDOW = rgb(255, 184, 104)
local DARK_WINDOW = rgb(24, 24, 28)
local HOLLOW = rgb(16, 14, 18)
local HOLLOW_EYE = rgb(190, 236, 255)
local IRON = rgb(40, 40, 44)

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

-- A thin member from a to b in the frame `at`.
local function member(
	parent: Instance,
	at: CFrame,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
)
	block(
		parent,
		Vector3.new(thickness, thickness, (b - a).Magnitude),
		at * Kit.between(a, b),
		color,
		material or M.Metal
	)
end

local function jitter(ctx: Ctx, color: Color3, spread: number): Color3
	return Kit.jitter(color, spread, ctx.rng:next())
end

local function pickColor(ctx: Ctx, list: { Color3 }): Color3
	return jitter(ctx, ctx.rng:pick(list), 0.08)
end

-- A pitched roof along local X over a w x d footprint, eaves at the frame.
--[[
	A spire: two thin gables crossed at right angles, four wedges that read as a
	cone from every side (pines, crags, mountain peaks). `thickness` is each
	gable's width (a third of the base by default). The second gable stands a
	twentieth of a stud higher, so the two never share a base or an apex, and each
	gable's back half is a touch shorter, so its end faces never share a plane.
]]
function Props.spire(
	parent: Instance,
	cf: CFrame,
	height: number,
	base: number,
	color: Color3,
	material: Enum.Material,
	shadow: boolean?,
	thickness: number?
)
	local thin = thickness or base * 0.3
	for i = 0, 1 do
		local at = cf * CFrame.new(0, i * 0.05, 0) * Kit.angles(0, i * 90, 0)
		wedge(
			parent,
			Vector3.new(thin, height, base / 2),
			at * CFrame.new(0, height / 2, -base / 4),
			color,
			material,
			shadow
		)
		wedge(
			parent,
			Vector3.new(thin * 0.97, height, base / 2),
			at * CFrame.new(0, height / 2, base / 4) * Kit.angles(0, 180, 0),
			Kit.shade(color, 0.86),
			material,
			shadow
		)
	end
end

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

-- A row of windows on the front face (local -Z). Lit ones glow; the rest are dark glass.
local function windowRow(parent: Instance, ctx: Ctx, w: number, d: number, y: number, at: CFrame, lit: number)
	if ctx.far then
		return
	end
	local count = math.max(1, math.floor(w / 7))
	for i = 1, count do
		local x = -w / 2 + (i - 0.5) * w / count
		local glow = ctx.rng:chance(lit)
		local pane = block(
			parent,
			Vector3.new(1.6, 2, 0.2),
			at * CFrame.new(x, y, -d / 2 - 0.05),
			if glow then WINDOW else DARK_WINDOW,
			M.Neon
		)
		if not glow then
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
	emitter.Rate = 2 + scale * 0.6 -- big columns grow by size, not by count (overdraw)
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

-- Flames, a smoke column, rising sparks (unless `sparks` is false: too small to see from
-- afar) and optionally a flickering orange light.
function Props.fire(parent: Instance, cf: CFrame, size: number, light: boolean, sparks: boolean?)
	local holder = emitterPart(parent, Vector3.new(size, 0.4, size), cf)
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = FIRE
	flames.Color = ColorSequence.new(rgb(255, 200, 110), rgb(220, 70, 30))
	flames.LightEmission = 1
	flames.Rate = 10 + size * 2
	flames.Lifetime = NumberRange.new(0.6, 1.2)
	flames.Speed = NumberRange.new(3, 7)
	flames.SpreadAngle = Vector2.new(15, 15)
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	flames.Acceleration = Vector3.new(0, 5, 0)
	flames.Parent = holder
	if sparks ~= false then
		local rising = Instance.new("ParticleEmitter")
		rising.Texture = SPARKS
		rising.Color = ColorSequence.new(rgb(255, 170, 80))
		rising.LightEmission = 1
		rising.Rate = 6
		rising.Lifetime = NumberRange.new(2, 4)
		rising.Speed = NumberRange.new(6, 14)
		rising.SpreadAngle = Vector2.new(30, 30)
		rising.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		rising.Parent = holder
	end
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

-- A broadleaf tree: trunk, two limbs and a crown of overlapping clumps in the biome's leaf colours.
function Props.tree(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	local h = ctx.rng:range(16, 30) * (scale or 1)
	local trunkH = h * 0.48
	local bark = jitter(ctx, ctx.biome.trunk, 0.1)
	if ctx.far then
		-- from the mid field a trunk and one crown are all that read
		post(parent, trunkH + 0.3, h * 0.075, cf * CFrame.new(0, trunkH / 2 - 0.15, 0), bark, M.Wood)
		ball(
			parent,
			h * 0.62,
			cf * CFrame.new(0, trunkH + h * 0.2, 0),
			pickColor(ctx, ctx.biome.foliage),
			M.LeafyGrass
		)
		return
	end
	post(parent, trunkH, h * 0.075, cf * CFrame.new(0, trunkH / 2, 0), bark, M.Wood, ctx.shadow)
	for _, side in { -1, 1 } do
		block(
			parent,
			Vector3.new(h * 0.04, h * 0.3, h * 0.04),
			cf
				* CFrame.new(side * h * 0.06, trunkH * 0.85, 0)
				* Kit.angles(0, ctx.rng:range(0, 360), side * 38)
				* CFrame.new(0, h * 0.13, 0),
			bark,
			M.Wood
		)
	end
	local crown = h * 0.5
	local color = pickColor(ctx, ctx.biome.foliage)
	local clumps = ctx.rng:int(3, 5)
	for i = 1, clumps do
		local a = (i / clumps) * math.pi * 2 + ctx.rng:range(0, 1)
		local spread = if i == 1 then 0 else crown * 0.36
		ball(
			parent,
			crown * (if i == 1 then 1 else ctx.rng:range(0.62, 0.8)),
			cf
				* CFrame.new(
					math.cos(a) * spread,
					trunkH + crown * (if i == 1 then 0.32 else ctx.rng:range(0.05, 0.42)),
					math.sin(a) * spread
				),
			Kit.shade(color, ctx.rng:range(0.86, 1.1)),
			M.LeafyGrass,
			ctx.shadow
		)
	end
end

-- A tall narrow poplar.
function Props.poplar(parent: Instance, cf: CFrame, ctx: Ctx)
	local h = ctx.rng:range(26, 38)
	post(
		parent,
		h * 0.3,
		h * 0.05,
		cf * CFrame.new(0, h * 0.15, 0),
		jitter(ctx, ctx.biome.trunk, 0.1),
		M.Wood,
		ctx.shadow
	)
	local color = pickColor(ctx, ctx.biome.foliage)
	for i = 0, 3 do
		local d = h * (0.26 - i * 0.04)
		ball(
			parent,
			d,
			cf * CFrame.new(0, h * (0.32 + i * 0.17), 0),
			Kit.shade(color, 0.94 + i * 0.04),
			M.LeafyGrass,
			ctx.shadow
		)
	end
end

-- A birch: pale trunk with dark bands, light crown.
function Props.birch(parent: Instance, cf: CFrame, ctx: Ctx)
	local h = ctx.rng:range(14, 22)
	local trunk = cf * Kit.angles(0, 0, ctx.rng:range(-5, 5))
	post(
		parent,
		h * 0.7,
		h * 0.05,
		trunk * CFrame.new(0, h * 0.35, 0),
		rgb(214, 210, 198),
		M.SmoothPlastic,
		ctx.shadow
	)
	for i = 1, 3 do
		block(
			parent,
			Vector3.new(h * 0.056, 0.25, h * 0.056),
			trunk * CFrame.new(0, h * (0.15 + i * 0.15), 0),
			rgb(36, 34, 32),
			M.SmoothPlastic
		)
	end
	local color = Kit.shade(pickColor(ctx, ctx.biome.foliage), 1.15)
	ball(parent, h * 0.42, trunk * CFrame.new(0, h * 0.78, 0), color, M.LeafyGrass, ctx.shadow)
	ball(
		parent,
		h * 0.3,
		trunk * CFrame.new(h * 0.12, h * 0.62, h * 0.06),
		Kit.shade(color, 0.92),
		M.LeafyGrass,
		ctx.shadow
	)
end

-- A conifer: a trunk under two spires, the upper one narrower and turned half a step.
local function conifer(parent: Instance, cf: CFrame, ctx: Ctx, h: number, snowy: boolean)
	if ctx.far then
		-- from the mid field: one spire, its feet in the ground
		Props.spire(
			parent,
			cf * CFrame.new(0, -0.3, 0) * Kit.angles(0, ctx.rng:range(0, 90), 0),
			h,
			h * 0.45,
			if snowy
				then Kit.shade(pickColor(ctx, ctx.biome.foliage), 1.35)
				else pickColor(ctx, ctx.biome.foliage),
			M.Grass
		)
		return
	end
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
	local yaw = ctx.rng:range(0, 90)
	Props.spire(
		parent,
		cf * CFrame.new(0, h * 0.24, 0) * Kit.angles(0, yaw, 0),
		h * 0.6,
		h * 0.52,
		color,
		M.Grass,
		ctx.shadow
	)
	Props.spire(
		parent,
		cf * CFrame.new(0, h * 0.5, 0) * Kit.angles(0, yaw + 45, 0),
		h * 0.5,
		h * 0.34,
		if snowy then rgb(222, 228, 236) else Kit.shade(color, 1.1),
		if snowy then M.Snow else M.Grass,
		ctx.shadow
	)
end

function Props.pine(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	conifer(parent, cf, ctx, ctx.rng:range(22, 40) * (scale or 1), false)
end

function Props.snowPine(parent: Instance, cf: CFrame, ctx: Ctx, scale: number?)
	conifer(parent, cf, ctx, ctx.rng:range(20, 36) * (scale or 1), true)
end

--[[
	A copse: four to seven trees in a knot, crowns touching, trunks never closer
	than seven studs. In a biome with conifers among its foliage a third of them
	are pines.
]]
function Props.copse(parent: Instance, cf: CFrame, ctx: Ctx)
	local count = if ctx.far then ctx.rng:int(3, 4) else ctx.rng:int(3, 5)
	local spots: { { number } } = {}
	for _ = 1, count * 4 do
		if #spots >= count then
			break
		end
		local a = ctx.rng:range(0, math.pi * 2)
		local r = ctx.rng:range(0, 14)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local clear = true
		for _, spot in spots do
			if (spot[1] - x) ^ 2 + (spot[2] - z) ^ 2 < 49 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(spots, { x, z })
			local at = cf * CFrame.new(x, 0, z)
			if ctx.biome.snowcap and ctx.rng:chance(0.35) then
				Props.pine(parent, at, ctx, ctx.rng:range(0.7, 0.9))
			else
				Props.tree(parent, at, ctx, ctx.rng:range(0.7, 1))
			end
		end
	end
end

-- A gnarled dead tree: a leaning trunk, crooked limbs and twigs.
function Props.deadTree(parent: Instance, cf: CFrame, ctx: Ctx)
	local h = ctx.rng:range(12, 26)
	local color = jitter(ctx, rgb(44, 36, 30), 0.1)
	local trunk = cf * Kit.angles(ctx.rng:range(-4, 4), 0, ctx.rng:range(-7, 7))
	block(
		parent,
		Vector3.new(h * 0.07, h, h * 0.07),
		trunk * CFrame.new(0, h / 2, 0),
		color,
		M.Wood,
		ctx.shadow
	)
	for i = 1, ctx.rng:int(3, 4) do
		local len = h * ctx.rng:range(0.28, 0.48)
		local side = if i % 2 == 0 then 1 else -1
		local limb = trunk
			* CFrame.new(0, h * (0.45 + i * 0.12), 0)
			* Kit.angles(0, ctx.rng:range(0, 360), side * ctx.rng:range(30, 60))
		block(
			parent,
			Vector3.new(h * 0.04, len, h * 0.04),
			limb * CFrame.new(0, len / 2, 0),
			color,
			M.Wood,
			ctx.shadow
		)
		block(
			parent,
			Vector3.new(h * 0.022, len * 0.5, h * 0.022),
			limb * CFrame.new(0, len * 0.8, 0) * Kit.angles(0, 0, -side * 35) * CFrame.new(0, len * 0.25, 0),
			color,
			M.Wood
		)
	end
end

function Props.bush(parent: Instance, cf: CFrame, ctx: Ctx)
	local size = ctx.rng:range(5, 10)
	local color = pickColor(ctx, ctx.biome.foliage)
	ball(parent, size, cf * CFrame.new(0, size * 0.2, 0), color, M.LeafyGrass)
	ball(
		parent,
		size * 0.7,
		cf * CFrame.new(size * 0.45, size * 0.1, size * 0.1),
		Kit.shade(color, 0.92),
		M.LeafyGrass
	)
	if ctx.rng:chance(0.5) then
		ball(
			parent,
			size * 0.6,
			cf * CFrame.new(-size * 0.4, size * 0.05, -size * 0.15),
			Kit.shade(color, 1.06),
			M.LeafyGrass
		)
	end
end

-- A clump of tall grass blades for verges.
function Props.grass(parent: Instance, cf: CFrame, ctx: Ctx)
	local color = jitter(ctx, ctx.biome.tufts, 0.12)
	-- each blade runs 0.8 below the base, so even on an embankment's slope no edge lifts clear
	for i = 1, 3 do
		local h = ctx.rng:range(1.6, 3.2) + 0.8
		wedge(
			parent,
			Vector3.new(0.18 + i * 0.02, h, 0.9),
			cf
				* CFrame.new(ctx.rng:range(-0.6, 0.6), h / 2 - 0.8, ctx.rng:range(-0.6, 0.6))
				* Kit.angles(ctx.rng:range(-12, 12), i * 60, 0),
			Kit.shade(color, 0.9 + i * 0.05),
			M.Grass
		)
	end
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
				* CFrame.new(size * 0.62, 0, size * 0.3)
				* Kit.angles(ctx.rng:range(0, 40), ctx.rng:range(0, 90), 7),
			Kit.shade(color, 0.9),
			M.Rock
		)
	end
end

function Props.reeds(parent: Instance, cf: CFrame, ctx: Ctx)
	for i = 1, 5 do
		local h = ctx.rng:range(3, 6)
		block(
			parent,
			Vector3.new(0.3 + i * 0.01, h, 0.3 + i * 0.01),
			cf
				* CFrame.new(ctx.rng:range(-2.5, 2.5), h / 2, ctx.rng:range(-2.5, 2.5))
				* Kit.angles(ctx.rng:range(-10, 10), i * 17, ctx.rng:range(-10, 10)),
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

-- A rock outcrop: three crags, rock gables leaning a little, sunk deep enough that no
-- edge lifts clear of the ground; snow on the tallest where the biome has it.
function Props.rockWall(parent: Instance, cf: CFrame, ctx: Ctx)
	local color = jitter(ctx, ctx.biome.rock, 0.1)
	local tallest, tallestAt, tallestD, tallestL = 0, cf, 0, 0
	for i = 1, 3 do
		local h = ctx.rng:range(18, 44)
		local d = h * ctx.rng:range(0.9, 1.3)
		local length = ctx.rng:range(10, 18)
		local at = cf
			* CFrame.new((i - 2) * 13, -2.5, ctx.rng:range(-4, 4))
			* Kit.angles(ctx.rng:range(-3, 3), ctx.rng:range(-30, 30), ctx.rng:range(-3, 3))
		local tone = Kit.shade(color, 0.9 + i * 0.05)
		wedge(
			parent,
			Vector3.new(length, h, d / 2),
			at * CFrame.new(0, h / 2, -d / 4),
			tone,
			M.Slate,
			ctx.shadow
		)
		wedge(
			parent,
			Vector3.new(length * 0.97, h, d / 2),
			at * CFrame.new(0, h / 2, d / 4) * Kit.angles(0, 180, 0),
			Kit.shade(tone, 0.85),
			M.Slate,
			ctx.shadow
		)
		if h > tallest then
			tallest, tallestAt, tallestD, tallestL = h, at, d, length
		end
	end
	if ctx.biome.snowcap then
		-- a scaled copy of the tallest crag's top, a touch wider and deeper so it sits proud
		local h = tallest * 0.3
		local d = tallestD * 0.3 * 1.04
		local top = tallestAt * CFrame.new(0, tallest - h, 0)
		local snow = rgb(232, 236, 242)
		wedge(
			parent,
			Vector3.new(tallestL * 1.04, h, d / 2),
			top * CFrame.new(0, h / 2, -d / 4),
			snow,
			M.Snow
		)
		wedge(
			parent,
			Vector3.new(tallestL * 0.97 * 1.04, h, d / 2),
			top * CFrame.new(0, h / 2, d / 4) * Kit.angles(0, 180, 0),
			Kit.shade(snow, 0.92),
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
			4.2,
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

function Props.fence(parent: Instance, cf: CFrame, ctx: Ctx, length: number?)
	local len = length or ctx.rng:range(24, 48)
	local color = jitter(ctx, rgb(98, 80, 62), 0.1)
	local posts = math.floor(len / 6) + 1
	local broken = ctx.rng:int(1, posts)
	for i = 0, posts - 1 do
		local lean = if i == broken then 14 else 0
		block(
			parent,
			Vector3.new(0.5, 4, 0.5),
			cf * CFrame.new(-len / 2 + i * len / (posts - 1), 2, 0) * Kit.angles(lean, 0, 0),
			color,
			M.Wood
		)
	end
	for _, y in { 1.6, 3.2 } do
		block(parent, Vector3.new(len, 0.35, 0.25), cf * CFrame.new(0, y, 0), color, M.Wood)
	end
end

function Props.scarecrow(parent: Instance, cf: CFrame, ctx: Ctx)
	local wood = jitter(ctx, rgb(92, 72, 52), 0.1)
	block(parent, Vector3.new(0.5, 8, 0.5), cf * CFrame.new(0, 4, 0), wood, M.Wood)
	block(parent, Vector3.new(6, 0.46, 0.46), cf * CFrame.new(0, 6, 0), wood, M.Wood)
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
	windowRow(parent, ctx, w, d, h * 0.55, cf, 0.55)
	if not ctx.far then
		block(
			parent,
			Vector3.new(2, 6, 2),
			cf * CFrame.new(w * 0.3, h + d * 0.35, 0),
			rgb(120, 70, 56),
			M.Brick,
			ctx.shadow
		)
		block(
			parent,
			Vector3.new(2.6, 5, 0.3),
			cf * CFrame.new(-w * 0.3, 2.5, -d / 2 - 0.1),
			rgb(70, 50, 38),
			M.Wood
		)
	end
end

function Props.barn(parent: Instance, cf: CFrame, ctx: Ctx)
	local w, d, h = ctx.rng:range(22, 30), ctx.rng:range(16, 20), ctx.rng:range(11, 14)
	local walls = jitter(ctx, rgb(124, 48, 40), 0.08)
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
	if not ctx.far then
		block(
			parent,
			Vector3.new(8, 10, 0.4),
			cf * CFrame.new(0, 5, -d / 2 - 0.15),
			Kit.shade(walls, 0.7),
			M.WoodPlanks
		)
		-- the X brace: the second bar sits a touch proud of the first
		block(
			parent,
			Vector3.new(0.4, 13, 0.2),
			cf * CFrame.new(0, 5, -d / 2 - 0.45) * Kit.angles(0, 0, 45),
			rgb(220, 210, 190),
			M.Wood
		)
		block(
			parent,
			Vector3.new(0.4, 13, 0.2),
			cf * CFrame.new(0, 5, -d / 2 - 0.52) * Kit.angles(0, 0, -45),
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
		local arm = axle * Kit.angles(0, 0, i * 90 + 15) * CFrame.new(0, 7.5, -0.42)
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
		for _, p in { blade, spar } do
			p:SetAttribute("Jointed", true)
			Kit.weld(p, hub)
			p.Anchored = false
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

-- A two-wheeled farm cart, left where it stopped.
function Props.cart(parent: Instance, cf: CFrame, ctx: Ctx)
	local wood = jitter(ctx, rgb(104, 78, 54), 0.1)
	local tilt = cf * Kit.angles(ctx.rng:range(-4, 4), 0, ctx.rng:range(-8, 8))
	block(parent, Vector3.new(8, 0.5, 4.6), tilt * CFrame.new(0, 2.6, 0), wood, M.WoodPlanks, ctx.shadow)
	for _, z in { -2.2, 2.2 } do
		block(
			parent,
			Vector3.new(8, 1.4, 0.25),
			tilt * CFrame.new(0, 3.5, z),
			Kit.shade(wood, 0.9),
			M.WoodPlanks
		)
	end
	for _, z in { -2.65, 2.65 } do
		Kit.cylinder(
			parent,
			0.4,
			4.4,
			tilt * CFrame.new(0.5, 2.2, z) * Kit.angles(0, 90, 0),
			rgb(70, 54, 40),
			{ material = M.Wood, collide = false, shadow = false }
		)
	end
	member(
		parent,
		tilt,
		Vector3.new(-4, 2.6, -0.9),
		Vector3.new(-9, 0.4, -0.9),
		0.3,
		Kit.shade(wood, 0.8),
		M.Wood
	)
	member(
		parent,
		tilt,
		Vector3.new(-4, 2.6, 0.9),
		Vector3.new(-9, 0.4, 0.9),
		0.34,
		Kit.shade(wood, 0.8),
		M.Wood
	)
end

-- A lantern on a post in an empty field: a pale flickering light that someone left burning.
function Props.lanternPost(parent: Instance, cf: CFrame, ctx: Ctx)
	-- a leaning post; the arm runs out of it and the lantern hangs from the arm's end
	local pole = cf * Kit.angles(0, 0, ctx.rng:range(-5, 5)) * CFrame.new(0, 3.3, 0)
	block(parent, Vector3.new(0.4, 7, 0.4), pole, rgb(58, 46, 36), M.Wood)
	block(parent, Vector3.new(1.3, 0.3, 0.3), pole * CFrame.new(0.55, 3.3, 0), rgb(58, 46, 36), M.Wood)
	local lamp =
		Kit.neon(parent, Vector3.new(0.7, 0.9, 0.7), pole * CFrame.new(1, 2.75, 0), rgb(255, 200, 130))
	if ctx.lights ~= false then
		local light = Kit.pointLight(lamp, rgb(255, 190, 120), 1.1, 20, false)
		light:SetAttribute("Flicker", light.Brightness)
	end
end

-- A lone grave by the line: a wooden cross and a mound.
function Props.grave(parent: Instance, cf: CFrame, ctx: Ctx)
	local wood = jitter(ctx, rgb(86, 68, 52), 0.1)
	local lean = cf * Kit.angles(ctx.rng:range(-8, 8), 0, ctx.rng:range(-8, 8))
	block(parent, Vector3.new(0.4, 4, 0.4), lean * CFrame.new(0, 2, 0), wood, M.Wood)
	block(parent, Vector3.new(2.2, 0.36, 0.36), lean * CFrame.new(0, 2.9, 0), wood, M.Wood)
	ball(parent, 4, cf * CFrame.new(0, -1.3, 1.6), jitter(ctx, ctx.biome.patches[1], 0.05), M.Mud)
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
		-- axles a touch wider than the frame so the wheel faces stand proud of it
		Kit.cylinder(parent, 7.4, 2.6, cf * CFrame.new(x, 1, 0) * Kit.angles(0, 90, 0), rgb(40, 36, 36), {
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
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			block(parent, Vector3.new(0.8, 16, 0.8), cf * CFrame.new(x, 8, z), IRON, M.Metal, ctx.shadow)
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
	post(parent, 1.4, 12, cf * CFrame.new(0, 24.7, 0), IRON, M.Metal)
	block(parent, Vector3.new(0.8, 0.8, 8), cf * CFrame.new(0, 17, -8) * Kit.angles(20, 0, 0), IRON, M.Metal)
end

function Props.semaphore(parent: Instance, cf: CFrame, ctx: Ctx)
	post(parent, 18, 0.6, cf * CFrame.new(0, 9, 0), IRON, M.Metal, ctx.shadow)
	local arm = cf * CFrame.new(0, 16, -0.5) * Kit.angles(0, 0, if ctx.rng:chance(0.5) then 0 else 40)
	block(parent, Vector3.new(5, 0.9, 0.2), arm * CFrame.new(2.5, 0, 0), rgb(176, 40, 36), M.SmoothPlastic)
	block(parent, Vector3.new(0.5, 1.0, 0.26), arm * CFrame.new(4, 0, 0), rgb(236, 230, 220), M.SmoothPlastic)
	Kit.neon(
		parent,
		Vector3.new(0.5, 0.5, 0.2),
		cf * CFrame.new(0, 14.8, -0.6),
		if ctx.rng:chance(0.5) then rgb(255, 70, 50) else rgb(120, 255, 160)
	)
	-- the cap sits over the post's top so their faces never meet
	block(parent, Vector3.new(1, 0.2, 1.4), cf * CFrame.new(0, 18.05, 0), IRON, M.Metal)
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
	if not ctx.far then
		block(
			parent,
			Vector3.new(2.4, 4.6, 0.25),
			cf * CFrame.new(0, 2.3, -d / 2 - 0.1),
			Kit.shade(walls, 0.7),
			M.Wood
		)
	end
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
	local s = scale or 1
	local h = ctx.rng:range(40, 70) * s
	local brick = jitter(ctx, rgb(116, 64, 50), 0.08)
	post(parent, h, 6 * s, cf * CFrame.new(0, h / 2, 0), brick, M.Brick, ctx.shadow)
	-- the band stops short of the top so its cap never meets the stack's
	post(parent, 2, 7.2 * s, cf * CFrame.new(0, h - 1.2, 0), Kit.shade(brick, 0.6), M.Brick)
	block(
		parent,
		Vector3.new(16, 10, 14) * s,
		cf * CFrame.new(0, 5 * s, 0),
		Kit.shade(brick, 0.9),
		M.Brick,
		ctx.shadow
	)
	Props.smoke(parent, cf * CFrame.new(0, h + 1, 0), 3 * s, rgb(36, 32, 30))
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
	if not ctx.far then
		for i = 1, count, 2 do
			block(
				parent,
				Vector3.new(1.4, 3.2, 3),
				cf * CFrame.new(-w / 2 + (i - 0.5) * 9, h + 3.6, 0),
				Kit.shade(brick, 0.8),
				M.Brick
			)
		end
	end
	windowRow(parent, ctx, w, d, 6, cf, 0.3)
end

-- Power lines: a lattice pylon. Returns where its cables hang, in the frame's space.
function Props.pylon(parent: Instance, cf: CFrame, ctx: Ctx): { Vector3 }
	local steel = jitter(ctx, rgb(70, 74, 78), 0.05)
	local h = 64
	local base, top = 9, 2.4
	-- every member a slightly different gauge, so legs and braces never share a face
	local leg = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			leg += 1
			member(
				parent,
				cf,
				Vector3.new(sx * base, 0, sz * base),
				Vector3.new(sx * top, h, sz * top),
				0.86 + leg * 0.03,
				steel
			)
		end
	end
	for i, y in { 14, 30, 44 } do
		local w = base + (top - base) * y / h
		for j, sz in { -1, 1 } do
			member(
				parent,
				cf,
				Vector3.new(-w, y, sz * w),
				Vector3.new(w, y - 9, sz * w),
				0.46 + i * 0.04 + j * 0.02,
				steel
			)
		end
	end
	local arms: { Vector3 } = {}
	for i, y in { 46, 54, 62 } do
		local span = 15 - i * 2
		block(parent, Vector3.new(0.7, 0.7, 2 * span), cf * CFrame.new(0, y, 0), steel, M.Metal, ctx.shadow)
		for _, sz in { -1, 1 } do
			table.insert(arms, Vector3.new(0, y - 2.4, sz * (span - 0.6)))
			block(
				parent,
				Vector3.new(0.4, 2.4, 0.4),
				cf * CFrame.new(0, y - 1.2, sz * (span - 0.6)),
				rgb(150, 160, 170),
				M.Glass
			)
		end
	end
	return arms
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
	if not ctx.far then
		block(
			parent,
			Vector3.new(1.6, 5, 1.6),
			cf * CFrame.new(w * 0.3, h + 3, d * 0.15),
			Kit.shade(walls, 0.8),
			M.Brick,
			ctx.shadow
		)
	end
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
	-- the standing walls' feet sit a little into the ground whatever their height
	local back, side = ctx.rng:range(6, 10), ctx.rng:range(4, 8)
	block(parent, Vector3.new(w, back, 1), cf * CFrame.new(0, back / 2 - 0.3, -5), walls, M.Brick, ctx.shadow)
	block(
		parent,
		Vector3.new(1, side, 10),
		cf * CFrame.new(-w / 2, side / 2 - 0.3, 0),
		walls,
		M.Brick,
		ctx.shadow
	)
	-- a toppled stretch and the rubble, tilted, sunk deep enough that no corner lifts clear
	block(
		parent,
		Vector3.new(w * 0.6, 3, 1),
		cf * CFrame.new(w * 0.2, 0.8, 5) * Kit.angles(0, 0, 6),
		walls,
		M.Brick
	)
	block(
		parent,
		Vector3.new(w * 0.8, 1.5, 8),
		cf * CFrame.new(0, 0.3, 0) * Kit.angles(4, 20, 0),
		rgb(26, 22, 20),
		M.Slate
	)
	if ctx.far and ctx.rng:chance(0.5) then
		-- out in the mid field half the ruins only smoulder
		Props.smoke(parent, cf * CFrame.new(0, 3, 0), ctx.rng:range(3, 5), rgb(40, 34, 32))
	else
		Props.fire(parent, cf * CFrame.new(0, 1.5, 0), ctx.rng:range(5, 9), ctx.lights ~= false, not ctx.far)
	end
end

function Props.church(parent: Instance, cf: CFrame, ctx: Ctx, burning: boolean?)
	local stone = jitter(ctx, rgb(150, 142, 130), 0.06)
	if burning then
		stone = Kit.shade(stone, 0.55)
	end
	block(parent, Vector3.new(30, 16, 14), cf * CFrame.new(0, 8, 0), stone, M.Limestone, ctx.shadow)
	gable(parent, 31, 15, 9, cf * CFrame.new(0, 16, 0), rgb(56, 52, 54), ctx.shadow)
	block(parent, Vector3.new(9, 30, 9), cf * CFrame.new(-18, 15, 0), stone, M.Limestone, ctx.shadow)
	-- spire: two crossed slim gables, one a hair wider so their faces never meet
	for _, yaw in { 0, 90 } do
		local base = cf * CFrame.new(-18, 30, 0) * Kit.angles(0, yaw, 0)
		local width = if yaw == 0 then 1 else 1.06
		wedge(
			parent,
			Vector3.new(width, 22, 4.5),
			base * CFrame.new(0, 11, -2.25),
			rgb(60, 58, 62),
			M.Slate,
			ctx.shadow
		)
		wedge(
			parent,
			Vector3.new(width, 22, 4.5),
			base * CFrame.new(0, 11, 2.25) * Kit.angles(0, 180, 0),
			rgb(60, 58, 62),
			M.Slate,
			ctx.shadow
		)
	end
	if not ctx.far then
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
	end
	if burning then
		Props.fire(parent, cf * CFrame.new(4, 17, 0), 9, ctx.lights ~= false)
	end
end

-- Coast -------------------------------------------------------------------------------------------------

function Props.lighthouse(parent: Instance, cf: CFrame, ctx: Ctx)
	local white = rgb(232, 228, 220)
	local red = rgb(170, 46, 42)
	block(
		parent,
		Vector3.new(14, 4, 14),
		cf * CFrame.new(0, 1.4, 0),
		jitter(ctx, ctx.biome.rock, 0.06),
		M.Rock
	)
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
	post(parent, 0.8, 9, cf * CFrame.new(0, 39.5, 0), IRON, M.Metal)
	local lamp = Kit.neon(
		parent,
		Vector3.new(4, 4, 4),
		cf * CFrame.new(0, 42, 0),
		rgb(255, 236, 180),
		Enum.PartType.Ball
	)
	if ctx.lights ~= false then
		Kit.pointLight(lamp, rgb(255, 230, 170), 3, 60, false)
	end
	post(parent, 2, 5, cf * CFrame.new(0, 45, 0), red, M.Metal)
end

-- Mid-field clumps --------------------------------------------------------------------------------------

-- A clump of trees seen from afar: crowns only, trunks are invisible at that range.
--[[
	`count` values in lo..hi, each from its own slice of the range so no two are
	ever within a fifth of a slice of each other, in shuffled order. Trees that
	crowd together take their heights from here: overlapping trunks of one height
	would share the plane of their tops.
]]
local function heights(rng: Rng.Rng, count: number, lo: number, hi: number): { number }
	local step = (hi - lo) / count
	local values: { number } = {}
	for i = 1, count do
		table.insert(values, lo + (i - 0.9 + 0.8 * rng:next()) * step)
	end
	for i = count, 2, -1 do
		local j = rng:int(1, i)
		values[i], values[j] = values[j], values[i]
	end
	return values
end

function Props.grove(parent: Instance, cf: CFrame, ctx: Ctx, pines: boolean)
	local count = ctx.rng:int(3, 5)
	local snowy = ctx.biome.snowcap and ctx.biome.groundMaterial == M.Snow
	local sizes = heights(ctx.rng, count, 26, 44)
	for i = 1, count do
		local at = cf * CFrame.new(ctx.rng:range(-40, 40), 0, ctx.rng:range(-30, 30))
		local h = sizes[i]
		local color = pickColor(ctx, ctx.biome.foliage)
		if pines then
			-- (sunk a little, so both gables' feet are in the ground)
			Props.spire(
				parent,
				at * CFrame.new(0, -0.3, 0) * Kit.angles(0, ctx.rng:range(0, 90), 0),
				h,
				h * 0.42,
				if snowy then Kit.shade(color, 1.4) else color,
				M.Grass
			)
		else
			ball(parent, h * 0.6, at * CFrame.new(0, h * 0.45, 0), color, M.LeafyGrass)
		end
	end
end

-- The edge of a wood: a dense line of crowns along the frame's X.
function Props.forestBelt(parent: Instance, cf: CFrame, ctx: Ctx, pines: boolean)
	local count = ctx.rng:int(7, 11)
	local length = ctx.rng:range(140, 260)
	local snowy = ctx.biome.snowcap and ctx.biome.groundMaterial == M.Snow
	local sizes = heights(ctx.rng, count, 34, 54)
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count + ctx.rng:range(-6, 6)
		local at = cf * CFrame.new(x, 0, ctx.rng:range(-10, 10))
		local h = sizes[i]
		local color = pickColor(ctx, ctx.biome.foliage)
		if pines then
			Props.spire(
				parent,
				at * CFrame.new(0, -0.3, 0) * Kit.angles(0, ctx.rng:range(0, 90), 0),
				h,
				h * 0.4,
				if snowy and i % 3 == 0 then Kit.shade(color, 1.45) else color,
				M.Grass
			)
		else
			ball(parent, h * 0.62, at * CFrame.new(0, h * 0.42, 0), color, M.LeafyGrass)
		end
	end
end

-- Dispatch ------------------------------------------------------------------------------------------------

type Builder = (Instance, CFrame, Ctx) -> ()

local BY_KIND: { [string]: Builder } = {
	Tree = function(parent, cf, ctx)
		Props.tree(parent, cf, ctx)
	end,
	Poplar = Props.poplar,
	Birch = Props.birch,
	Pine = function(parent, cf, ctx)
		Props.pine(parent, cf, ctx)
	end,
	SnowPine = function(parent, cf, ctx)
		Props.snowPine(parent, cf, ctx)
	end,
	DeadTree = Props.deadTree,
	Copse = Props.copse,
	Bush = Props.bush,
	Grass = Props.grass,
	Boulder = Props.boulder,
	Reeds = Props.reeds,
	Dune = Props.dune,
	RockWall = Props.rockWall,
	Haystack = Props.haystack,
	Fence = function(parent, cf, ctx)
		Props.fence(parent, cf, ctx)
	end,
	Scarecrow = Props.scarecrow,
	Farmhouse = Props.farmhouse,
	Barn = Props.barn,
	Windmill = function(parent, cf, ctx)
		Props.windmill(parent, cf, ctx)
	end,
	Cart = Props.cart,
	LanternPost = Props.lanternPost,
	Grave = Props.grave,
	LoneHollow = function(parent, cf, ctx)
		Props.hollow(parent, cf, ctx.rng:range(0.95, 1.15))
	end,
	Siding = Props.siding,
	Wagon = Props.wagon,
	SleeperStack = Props.sleeperStack,
	SignalBox = Props.signalBox,
	WaterTower = Props.waterTower,
	Shed = Props.shed,
	SlagHeap = function(parent, cf, ctx)
		Props.slagHeap(parent, cf, ctx)
	end,
	Chimney = function(parent, cf, ctx)
		Props.chimney(parent, cf, ctx)
	end,
	Headframe = Props.headframe,
	Terrace = Props.terrace,
	House = function(parent, cf, ctx)
		Props.house(parent, cf, ctx)
	end,
	RuinFire = Props.ruinFire,
	Church = function(parent, cf, ctx)
		Props.church(parent, cf, ctx)
	end,
	Lighthouse = Props.lighthouse,
	Grove = function(parent, cf, ctx)
		Props.grove(parent, cf, ctx, false)
	end,
	PineGrove = function(parent, cf, ctx)
		Props.grove(parent, cf, ctx, true)
	end,
	ForestBelt = function(parent, cf, ctx)
		Props.forestBelt(parent, cf, ctx, false)
	end,
	PineBelt = function(parent, cf, ctx)
		Props.forestBelt(parent, cf, ctx, true)
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
	LoneHollow = true,
	ForestBelt = true,
	PineBelt = true,
}

--[[
	Footprint radius: how far a prop reaches from its origin in plan view, a tenth
	over the largest measured (lune run audit checks every kind against it). The
	packer keeps props this far apart and off reserved ground, so they never meet.
]]
local RADIUS: { [string]: number } = {
	Siding = 60,
	Terrace = 30,
	Church = 26,
	Barn = 21,
	Farmhouse = 16,
	Headframe = 26,
	SlagHeap = 57,
	Chimney = 12,
	Windmill = 17,
	Grove = 66,
	PineGrove = 58,
	ForestBelt = 140,
	PineBelt = 140,
	Dune = 56,
	RockWall = 39,
	Tree = 12,
	Copse = 25,
	Poplar = 6,
	Birch = 7.5,
	Pine = 12,
	SnowPine = 10.5,
	DeadTree = 11,
	Bush = 9,
	Grass = 2,
	Boulder = 18,
	Cart = 10,
	LanternPost = 3,
	Grave = 4,
	LoneHollow = 3,
	House = 12.5,
	RuinFire = 12,
	Haystack = 8.5,
	Fence = 26,
	Scarecrow = 3.5,
	Wagon = 10,
	WaterTower = 13,
	SignalBox = 12,
	Shed = 9.5,
	SleeperStack = 5.5,
	Reeds = 4.5,
	Lighthouse = 11,
}

function Props.build(kind: string, parent: Instance, cf: CFrame, ctx: Ctx)
	local builder = BY_KIND[kind]
	if builder then
		builder(parent, cf, ctx)
	end
end

function Props.kinds(): { string }
	local kinds: { string } = {}
	for kind in BY_KIND do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	return kinds
end

function Props.faces(kind: string): boolean
	return FACING[kind] == true
end

function Props.radius(kind: string): number
	return RADIUS[kind] or 8
end

-- Kinds that carry a light of their own (when their context allows one).
local LIT: { [string]: boolean } = { RuinFire = true, LanternPost = true }

function Props.lit(kind: string): boolean
	return LIT[kind] == true
end

-- Tall kinds cast shadows when they stand near the track.
local LOW: { [string]: boolean } = {
	Bush = true,
	Grass = true,
	Reeds = true,
	Haystack = true,
	Fence = true,
	Dune = true,
	SleeperStack = true,
	Boulder = true,
	Grave = true,
	Cart = true,
}

function Props.tall(kind: string): boolean
	return LOW[kind] ~= true
end

return Props
