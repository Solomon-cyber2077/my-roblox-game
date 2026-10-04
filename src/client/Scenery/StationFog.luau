--!strict
--[[
	The fog at a stop, drawn on the client from the front HazardSchedule computes (no network
	traffic). Not a wall but a thing with a shape and a will:

	  front     segments along the station, each one swelling and drawing back on its own
	            noise, so the edge of it bulges and folds; tall billows rise out of it here and
	            there, so its top is never flat
	  tendrils  thin wisps that crawl along the ground ahead of it, reaching furthest where
	            its fingers reach (they are harmless: the thick fog behind them is not)
	  bank      the depth of it behind the front, darker toward its heart
	  in it     tall shapes that stand in the fog and are gone when you come close; pairs of
	            eyes that open and close; cold lights drifting in it, lighting it from inside
	  before    it lies waiting in the trees along the far edge from the moment the doors
	            open, thin and low, with one figure standing among the trunks

	Its particles take the scene's light, so the fog is dark in the dark, warm round a lamp,
	red under the blood moon. The colour follows the stop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MathX = require(Shared.Util.MathX)

export type Frame = {
	station: CFrame, -- the station's own frame (x along the track, z away from it)
	length: number,
	depth: number,
	front: number, -- station-local z of the fog front (past `depth` while it waits)
	waiting: number, -- 0..1 how near the fog is to moving, while it waits in the trees
	camera: Vector3, -- the camera, in the station's frame
	archetype: string,
	now: number,
}

type Segment = {
	wall: Part,
	crawl: Part,
	wallEmitter: ParticleEmitter,
	billow: ParticleEmitter,
	crawlEmitter: ParticleEmitter,
	tall: boolean,
}

type Figure = { parts: { BasePart }, x: number, z: number, until_: number, shown: number, sway: number }
type Eyes = { left: BasePart, right: BasePart, x: number, y: number, z: number, at: number, length: number }
type Wisp = { part: Part, light: PointLight, phase: number }

local StationFog = {}

local SEGMENT = 24 -- studs of front per segment
local SEGMENTS = 17
local FIGURES = 4
local EYES = 4
local WISPS = 2
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local rgb = Color3.fromRGB

-- The fog's colour at each kind of stop: { light, dark }.
local TINTS: { [string]: { Color3 } } = {
	Halt = { rgb(150, 156, 146), rgb(92, 98, 92) },
	CoalYard = { rgb(140, 130, 118), rgb(80, 74, 68) },
	SignalWorks = { rgb(146, 146, 150), rgb(88, 88, 94) },
	Market = { rgb(156, 138, 116), rgb(92, 80, 68) },
	Viaduct = { rgb(140, 148, 160), rgb(84, 90, 102) },
	Minehead = { rgb(132, 134, 140), rgb(78, 80, 86) },
	Schoolhouse = { rgb(150, 154, 144), rgb(92, 96, 90) },
	Infirmary = { rgb(156, 160, 158), rgb(98, 104, 102) },
	RailwayHotel = { rgb(146, 150, 140), rgb(90, 94, 86) },
	PostTown = { rgb(152, 140, 124), rgb(92, 84, 74) },
}
local DEFAULT_TINT = { rgb(146, 146, 146), rgb(88, 88, 88) }

local folder: Folder
local segments: { Segment } = {}
local bank: Part
local bankEmitter: ParticleEmitter
local core: ParticleEmitter
local figures: { Figure } = {}
local eyes: { Eyes } = {}
local wisps: { Wisp } = {}
local tintShown = ""
local random = Random.new()
local active = false

local function decor(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function hidden(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Transparency = 1
	part.Size = Vector3.one
	decor(part)
	part.Parent = folder
	return part
end

local function smoke(parent: Part, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LightInfluence = 0.65
	e.Rate = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function fade(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function buildFigure(): Figure
	local parts: { BasePart } = {}
	local color = rgb(10, 9, 12)
	local function add(size: Vector3, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 1
		if shape then
			part.Shape = shape
		end
		decor(part)
		part.Parent = folder
		table.insert(parts, part)
	end
	add(Vector3.new(1.4, 5.2, 0.8)) -- body
	add(Vector3.new(1.1, 1.1, 1.1), Enum.PartType.Ball) -- head
	add(Vector3.new(0.35, 5.4, 0.35)) -- arms far too long
	add(Vector3.new(0.35, 5.6, 0.35))
	add(Vector3.new(0.4, 3.6, 0.4)) -- legs
	add(Vector3.new(0.4, 3.6, 0.4))
	return { parts = parts, x = 0, z = 0, until_ = 0, shown = 0, sway = random:NextNumber() * 10 }
end

-- Poses a figure standing at station-local (x, z), its height `h`, at opacity `alpha`.
local function poseFigure(figure: Figure, station: CFrame, now: number, alpha: number)
	local base = station * CFrame.new(figure.x, 0, figure.z) * CFrame.Angles(0, math.pi, 0)
	local sway = math.sin(now * 0.7 + figure.sway) * 0.04
	local frames = {
		base * CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, sway),
		base * CFrame.new(0.15, 9.5, -0.1) * CFrame.Angles(0.15, 0, 0.3 + sway),
		base * CFrame.new(-0.95, 5.4, 0) * CFrame.Angles(0, 0, -0.06),
		base * CFrame.new(0.95, 5.3, 0) * CFrame.Angles(0, 0, 0.08),
		base * CFrame.new(-0.4, 1.8, 0),
		base * CFrame.new(0.4, 1.8, 0),
	}
	for i, part in figure.parts do
		part.CFrame = frames[i]
		part.Transparency = 1 - alpha
	end
end

function StationFog.build(parent: Instance)
	folder = Instance.new("Folder")
	folder.Name = "StationFog"
	folder.Parent = parent
	for i = 1, SEGMENTS do
		local wall = hidden("FogWall")
		local crawl = hidden("FogCrawl")
		local tall = i % 3 == 0
		local segment: Segment = {
			wall = wall,
			crawl = crawl,
			tall = tall,
			wallEmitter = smoke(wall, {
				Name = "Wall",
				Lifetime = NumberRange.new(4.5, 7),
				Speed = NumberRange.new(1, 3),
				EmissionDirection = Enum.NormalId.Front,
				SpreadAngle = Vector2.new(40, 25),
				Acceleration = Vector3.new(0, 0.6, 0),
				Drag = 0.4,
				RotSpeed = NumberRange.new(-10, 10),
				Rotation = NumberRange.new(0, 360),
				Size = fade({ { 0, 9 }, { 0.5, 18 }, { 1, 26 } }),
				Transparency = fade({ { 0, 1 }, { 0.2, 0.5 }, { 0.6, 0.45 }, { 1, 1 } }),
			}),
			billow = smoke(wall, {
				Name = "Billow",
				Lifetime = NumberRange.new(5, 8),
				Speed = NumberRange.new(3, 6),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(18, 18),
				Drag = 0.5,
				RotSpeed = NumberRange.new(-8, 8),
				Rotation = NumberRange.new(0, 360),
				Size = fade({ { 0, 12 }, { 1, 34 } }),
				Transparency = fade({ { 0, 1 }, { 0.25, 0.55 }, { 1, 1 } }),
			}),
			crawlEmitter = smoke(crawl, {
				Name = "Crawl",
				Lifetime = NumberRange.new(6, 9),
				Speed = NumberRange.new(1.5, 3.5),
				EmissionDirection = Enum.NormalId.Front,
				SpreadAngle = Vector2.new(30, 4),
				Acceleration = Vector3.new(0, -0.15, 0),
				Drag = 0.2,
				RotSpeed = NumberRange.new(-6, 6),
				Rotation = NumberRange.new(0, 360),
				Size = fade({ { 0, 5 }, { 1, 14 } }),
				Transparency = fade({ { 0, 1 }, { 0.25, 0.72 }, { 0.7, 0.7 }, { 1, 1 } }),
			}),
		}
		table.insert(segments, segment)
	end
	bank = hidden("FogBank")
	bankEmitter = smoke(bank, {
		Name = "Bank",
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 30),
		RotSpeed = NumberRange.new(-8, 8),
		Rotation = NumberRange.new(0, 360),
		Size = fade({ { 0, 16 }, { 1, 30 } }),
		Transparency = fade({ { 0, 1 }, { 0.3, 0.5 }, { 0.7, 0.5 }, { 1, 1 } }),
	})
	core = smoke(bank, {
		Name = "Core",
		Lifetime = NumberRange.new(7, 10),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 20),
		RotSpeed = NumberRange.new(-5, 5),
		Rotation = NumberRange.new(0, 360),
		Size = fade({ { 0, 20 }, { 1, 36 } }),
		Transparency = fade({ { 0, 1 }, { 0.3, 0.35 }, { 0.7, 0.35 }, { 1, 1 } }),
	})
	for _ = 1, FIGURES do
		table.insert(figures, buildFigure())
	end
	for _ = 1, EYES do
		local function eye(): BasePart
			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * 0.22
			part.Material = Enum.Material.Neon
			part.Color = rgb(206, 220, 196)
			part.Transparency = 1
			decor(part)
			part.Parent = folder
			return part
		end
		table.insert(eyes, { left = eye(), right = eye(), x = 0, y = 0, z = 0, at = -math.huge, length = 0 })
	end
	for i = 1, WISPS do
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * 0.5
		part.Material = Enum.Material.Neon
		part.Color = rgb(176, 210, 236)
		part.Transparency = 1
		decor(part)
		part.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = rgb(160, 200, 236)
		light.Range = 16
		light.Brightness = 0
		light.Shadows = false
		light.Parent = part
		table.insert(wisps, { part = part, light = light, phase = i * 3.1 })
	end
end

local function tint(archetype: string)
	if archetype == tintShown then
		return
	end
	tintShown = archetype
	local pair = TINTS[archetype] or DEFAULT_TINT
	local light, dark = pair[1], pair[2]
	for _, segment in segments do
		segment.wallEmitter.Color = ColorSequence.new(light, dark)
		segment.billow.Color = ColorSequence.new(light:Lerp(dark, 0.3), dark)
		segment.crawlEmitter.Color = ColorSequence.new(light)
	end
	bankEmitter.Color = ColorSequence.new(light:Lerp(dark, 0.4), dark)
	core.Color = ColorSequence.new(dark, dark:Lerp(Color3.new(0, 0, 0), 0.5))
end

-- Turns every emitter off and hides everything that lives in the fog.
function StationFog.clear()
	if not active then
		return
	end
	active = false
	for _, segment in segments do
		segment.wallEmitter.Rate = 0
		segment.billow.Rate = 0
		segment.crawlEmitter.Rate = 0
		segment.wallEmitter:Clear()
		segment.billow:Clear()
		segment.crawlEmitter:Clear()
	end
	bankEmitter.Rate = 0
	core.Rate = 0
	bankEmitter:Clear()
	core:Clear()
	for _, figure in figures do
		figure.until_ = 0
		if figure.shown > 0 then
			figure.shown = 0
			for _, part in figure.parts do
				part.Transparency = 1
			end
		end
	end
	for _, pair in eyes do
		pair.at = -math.huge
		pair.length = 0
		pair.left.Transparency = 1
		pair.right.Transparency = 1
	end
	for _, wisp in wisps do
		wisp.part.Transparency = 1
		wisp.light.Brightness = 0
	end
end

function StationFog.update(f: Frame, dt: number)
	active = true
	tint(f.archetype)
	local station, now = f.station, f.now
	local half = f.length / 2 + 20
	local moving = f.front < f.depth - 0.5
	local front = math.min(f.front, f.depth + 6)
	local count = math.min(SEGMENTS, math.ceil((half * 2) / SEGMENT))

	-- the front: every segment swells and draws back on its own
	for i, segment in segments do
		if i > count then
			segment.wallEmitter.Rate = 0
			segment.billow.Rate = 0
			segment.crawlEmitter.Rate = 0
			continue
		end
		local x = -half + (i - 0.5) * (half * 2 / count)
		local swell = math.noise(x * 0.021, now * 0.06, 3.7) * 2
		local z = front + swell
		segment.wall.Size = Vector3.new(SEGMENT + 2, 22, 6)
		segment.wall.CFrame = station * CFrame.new(x, 11, z + 3) * CFrame.Angles(0, math.pi, 0)
		-- the fingers: further ahead here, barely at all there
		local reach = 3 + 11 * math.max(0, math.noise(x * 0.034 + 9.1, now * 0.08))
		segment.crawl.Size = Vector3.new(SEGMENT, 0.6, reach)
		segment.crawl.CFrame = station * CFrame.new(x, 0.9, z - reach / 2) * CFrame.Angles(0, math.pi, 0)
		if moving then
			segment.wallEmitter.Rate = 11
			segment.billow.Rate = if segment.tall then 2.2 else 0.5
			segment.crawlEmitter.Rate = 3 + 4 * reach / 14
		else
			-- waiting in the trees: low, thin, thickening as its time comes
			segment.wallEmitter.Rate = 1.5 + 5 * f.waiting
			segment.billow.Rate = 0
			segment.crawlEmitter.Rate = 1 + 2.5 * f.waiting
		end
	end

	-- the bank behind it, and its dark heart
	local deep = math.max(f.depth - front + 40, 6)
	bank.Size = Vector3.new(half * 2, 40, deep)
	bank.CFrame = station * CFrame.new(0, 14, front + deep / 2 + 2)
	bankEmitter.Rate = if moving then math.clamp(half * 2 * deep / 450, 12, 140) else 0
	core.Rate = if moving and deep > 40 then math.clamp(half * 2 * deep / 1400, 4, 40) else 0

	-- the figures stand in it, and are gone when you come close
	local figureCount = if moving then FIGURES else 1
	for i, figure in figures do
		local want = 0
		if i <= figureCount then
			if now >= figure.until_ or (moving and figure.z < front + 6) then
				-- a new place, deep enough to be half lost in the fog (or among the trees, waiting)
				figure.x = random:NextNumber(-f.length / 2 + 10, f.length / 2 - 10)
				figure.z = if moving
					then front + random:NextNumber(12, 26)
					else f.depth - random:NextNumber(1.5, 4)
				figure.until_ = now + random:NextNumber(8, 15)
				figure.shown = 0
			end
			local where = Vector3.new(figure.x, 5, figure.z)
			local near = (where - f.camera).Magnitude
			local life = math.clamp((figure.until_ - now) / 1.5, 0, 1)
			want = math.clamp((near - 34) / 30, 0, 1) * life * 0.82
			want *= 0.55 + 0.45 * math.noise(now * 0.3, i * 4.1)
		end
		figure.shown = MathX.lerp(figure.shown, want, math.min(dt * 1.5, 1))
		if figure.shown > 0.01 or want > 0 then
			poseFigure(figure, station, now, figure.shown)
		elseif figure.parts[1].Transparency < 1 then
			for _, part in figure.parts do
				part.Transparency = 1
			end
		end
	end

	-- eyes that open in the fog, look, and close
	for i, pair in eyes do
		local alpha = 0
		if moving then
			local t = now - pair.at
			if t > pair.length + random:NextNumber(0, 6) then
				pair.at = now
				pair.length = random:NextNumber(1.6, 4)
				pair.x = random:NextNumber(-f.length / 2 + 6, f.length / 2 - 6)
				pair.y = random:NextNumber(3, 8)
				pair.z = front + random:NextNumber(6, 18)
				t = 0
			end
			alpha = math.clamp(t / 0.4, 0, 1) * math.clamp((pair.length - t) / 0.3, 0, 1)
			-- they blink
			if math.sin(now * 2.3 + i * 1.7) > 0.93 then
				alpha = 0
			end
		end
		local base = station * CFrame.new(pair.x, pair.y, pair.z)
		pair.left.CFrame = base * CFrame.new(-0.22, 0, 0)
		pair.right.CFrame = base * CFrame.new(0.22, 0, 0)
		pair.left.Transparency = 1 - 0.85 * alpha
		pair.right.Transparency = 1 - 0.85 * alpha
	end

	-- cold lights drifting through it, lighting it from inside
	for _, wisp in wisps do
		if moving then
			local u = now * 0.05 + wisp.phase
			local x = math.noise(u, 1.3) * f.length * 0.45
			local z = front + 10 + (math.noise(u, 7.9) + 0.5) * 18
			local y = 4 + math.noise(u * 1.7, 4.2) * 3
			wisp.part.CFrame = station * CFrame.new(x, y, z)
			local glow = 0.5 + 0.5 * math.noise(now * 0.9, wisp.phase)
			wisp.part.Transparency = 0.35 + 0.4 * (1 - glow)
			wisp.light.Brightness = 0.6 + 0.9 * glow
		else
			wisp.part.Transparency = 1
			wisp.light.Brightness = 0
		end
	end
end

-- The part a sound of the fog can hang from (its middle segment).
function StationFog.anchor(): BasePart?
	local segment = segments[math.ceil(SEGMENTS / 2)]
	return if segment then segment.wall else nil
end

return StationFog
