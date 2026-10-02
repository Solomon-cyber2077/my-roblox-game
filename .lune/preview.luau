--[[
	Exports a stretch of the journey as JSON, for looking at it outside Roblox:

	  lune run preview <biome> <out.json> [seed] [odometer]

	Builds the train at the origin and every landscape chunk the client would have
	built with the train at `odometer` (land x) on a leg through `biome`, with that
	leg's set pieces, and writes each visible part (shape, size, frame, colour,
	material) and light.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Loader = require("./lib/Loader")
local Shim = require("./lib/Shim")

Shim.install()

local function load(node: any): any
	return Loader.requireNode(node)
end

local Shared, Client, Server = Loader.roots.Shared, Loader.roots.Client, Loader.roots.Server
local Journey = load(Shared.Logic.Journey)
local Stations = load(Shared.Config.Stations)
local Tuning = load(Shared.Config.Tuning)
local TrainBuilder = load(Server.Builders.TrainBuilder)
local World = load(Client.Scenery.World)
local Land = load(Client.Scenery.Land)
local Features = load(Client.Scenery.Features)
local Chunk = load(Client.Scenery.Chunk)

-- positional arguments, then --name=value options anywhere
local positional: { string } = {}
local options: { [string]: string } = {}
for _, arg in process.args do
	local name, value = string.match(arg, "^%-%-([%w]+)=(.*)$")
	if name then
		options[name] = value
	else
		table.insert(positional, arg)
	end
end

local biome = positional[1] or "Farmland"
local out = positional[2] or "scene.json"
local seed = tonumber(positional[3]) or 1
local odometer = tonumber(positional[4])
-- --ride=<seconds>: also build what the train passes in that many seconds at cruise
local rideSeconds = tonumber(options.ride) or 0
local rideLength = rideSeconds * Tuning.Motion.CruiseSpeed
local gallery = biome == "Gallery"
if gallery then
	biome = "Highland"
end

World.reset(seed, biome)
World.density = 1
local pieces = Journey.legPlan(seed, 1, 0, biome == "Coast")
World.pieces = pieces
if odometer == nil then
	-- stand just short of the first set piece, so it is in view
	odometer = if #pieces > 0 then pieces[1].at - 250 else 0
end
local arch = if biome == "Coast" then Stations.List.Terminus else Stations.List[Stations.Order[1]]
local sinkhole =
	Journey.sinkhole((odometer :: number) + 1900, arch.length, arch.depth, arch.id, arch.terminus == true)
World.sinkholes = { sinkhole }

local CFrame = roblox.CFrame
-- world: 1 for everything that scrolls past the train (landscape, set pieces), 0 for the train
local models: { { model: any, offset: any, world: number } } = {}

if gallery then
	-- every prop in a row along +X in the Highland biome's colours, on a strip of ground
	local Props = load(Client.Scenery.Props)
	local Biomes = load(Client.Scenery.Biomes)
	local Kit = load(Shared.Visual.Kit)
	local Rng = load(Shared.Util.Rng)
	local model = roblox.Instance.new("Model")
	local x = 0
	for i, kind in Props.kinds() do
		local r = math.min(Props.radius(kind), 40)
		x += r
		Props.build(kind, model, CFrame.new(x, -14, -60), {
			rng = Rng.new(seed * 100 + i),
			biome = Biomes.get(
				if i % 3 == 0 then "Farmland" elseif i % 3 == 1 then "Highland" else "Coalfield"
			),
			shadow = false,
		})
		x += r + 6
	end
	Kit.block(
		model,
		roblox.Vector3.new(x + 200, 0.4, 400),
		CFrame.new(x / 2, -14.2, -60),
		roblox.Color3.fromRGB(96, 110, 72),
		{}
	)
	table.insert(models, { model = model, offset = CFrame.new(), world = 1 })
	print(`gallery length {x}`)
end

local train = TrainBuilder.build(CFrame.new(), nil).model
table.insert(models, { model = train, offset = CFrame.new(), world = 0 })
for _, layer in if gallery then {} else Land.Layers do
	-- a ride needs the windows the client builds over its whole length
	local first = math.floor((odometer + layer.from) / layer.length)
	local last = math.floor((odometer + layer.to + rideLength) / layer.length)
	for k = first, last do
		local model = Chunk.begin(layer.name)
		Land.build(layer, k, model, k * layer.length)
		table.insert(
			models,
			{ model = model, offset = CFrame.new(k * layer.length - odometer, 0, 0), world = 1 }
		)
	end
end
for _, piece in pieces do
	if piece.at + piece.length > odometer - 1600 and piece.at < odometer + 4400 + rideLength then
		local model = Chunk.begin(piece.kind)
		Features.build(piece, model)
		table.insert(models, { model = model, offset = CFrame.new(piece.at - odometer, 0, 0), world = 1 })
	end
end
local hole = Chunk.begin("Sinkhole")
Features.buildSinkhole(sinkhole, hole)
table.insert(models, { model = hole, offset = CFrame.new(sinkhole.rect.x0 - odometer, 0, 0), world = 1 })

local SHAPES = { Block = "B", Cylinder = "C", Ball = "S", Wedge = "W", CornerWedge = "B" }
local FACES = {
	Front = roblox.Vector3.new(0, 0, -1),
	Back = roblox.Vector3.new(0, 0, 1),
	Top = roblox.Vector3.new(0, 1, 0),
	Bottom = roblox.Vector3.new(0, -1, 0),
	Right = roblox.Vector3.new(1, 0, 0),
	Left = roblox.Vector3.new(-1, 0, 0),
}

local function round(x: number): number
	return math.floor(x * 1000 + 0.5) / 1000
end

local function rgb(color: any): { number }
	return {
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5),
	}
end

local parts = {}
local lights = {}
for _, entry in models do
	for _, d in entry.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local cf = entry.offset * d.CFrame
			local p, r, u, b = cf.Position, cf.RightVector, cf.UpVector, -cf.LookVector
			local shape = if d:IsA("WedgePart")
				then "W"
				elseif d:IsA("Part") then SHAPES[d.Shape.Name]
				else "B"
			table.insert(parts, {
				s = shape,
				z = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				p = { round(p.X), round(p.Y), round(p.Z) },
				r = {
					round(r.X),
					round(r.Y),
					round(r.Z),
					round(u.X),
					round(u.Y),
					round(u.Z),
					round(b.X),
					round(b.Y),
					round(b.Z),
				},
				c = rgb(d.Color),
				m = d.Material.Name,
				t = round(d.Transparency),
				f = round(d.Reflectance),
				k = entry.world,
			})
		elseif d:IsA("Light") and d.Parent and d.Parent:IsA("BasePart") then
			local cf = entry.offset * d.Parent.CFrame
			local p = cf.Position
			local light: { [string]: any } = {
				p = { round(p.X), round(p.Y), round(p.Z) },
				c = rgb(d.Color),
				b = d.Brightness,
				r = d.Range,
				k = entry.world,
			}
			if d:IsA("SpotLight") or d:IsA("SurfaceLight") then
				-- a cone out of one face of its part
				local axis = cf:VectorToWorldSpace(FACES[d.Face.Name])
				light.d = { round(axis.X), round(axis.Y), round(axis.Z) }
				light.a = d.Angle
			end
			table.insert(lights, light)
		end
	end
end

--[[
	The sky, as AtmosphereController would draw it on this leg: Scenery/Sky composes the
	state for the hour, Scenery/Heavens poses the moon, glows, figures and bolts.

	  --hour=26               time of day (Logic/Journey hours; past 24 is after midnight)
	  --hours=20.6:22.4       with --ride: sweep the hour over the ride (a time-lapse)
	  --dread=0.6             a Hollow this close (0..1)
	  --omen=Blink@0.35       a still: force an omen, this far through it
	  --omen=Blink@3,Eye@12   a ride: force omens starting this many seconds in
	  --flash=0.8             lightning on a still
	  --fps=30                with --ride: a sky frame per 1/fps (moon, omens, storms move)
	  --at=<seconds>          server time the ride starts at (the seeded storms and omens)
]]
local Sky = load(Client.Scenery.Sky)
local Heavens = load(Client.Scenery.Heavens)
local Biomes = load(Client.Scenery.Biomes)
local Omens = load(Shared.Logic.Omens)
local SkyExport = require("./lib/SkyExport")

local hour = tonumber(options.hour) or 26
local sweep: { number }? = nil
if options.hours then
	local from, to = string.match(options.hours, "^([%d%.]+):([%d%.]+)$")
	if from and to then
		sweep = { tonumber(from) :: number, tonumber(to) :: number }
		hour = (sweep :: { number })[1]
	end
end
local dread = tonumber(options.dread) or 0
local fps = tonumber(options.fps) or 0
local startAt = tonumber(options.at) or 1000
local forced: { { kind: string, at: number } } = {}
for entry in string.gmatch(options.omen or "", "[^,]+") do
	local kind, at = string.match(entry, "^(%a+)@?([%d%.]*)$")
	if kind then
		table.insert(forced, { kind = kind, at = tonumber(at) or -1 })
	end
end
local def = Biomes.get(biome)
local rig = Heavens.build(roblox.Instance.new("Folder"))

local function durationOf(kind: string): number
	for _, spec in Tuning.Sky.Omens do
		if spec.kind == kind then
			return spec.duration
		end
	end
	return 6
end

-- A forced omen under way at `now`: on a still, `at` is how far through it; on a ride,
-- the second it starts.
local function forcedOmen(now: number, still: boolean): any
	for i, entry in forced do
		local duration = durationOf(entry.kind)
		local start = if still
			then now - (if entry.at >= 0 then entry.at else 0.5) * duration
			else startAt + (if entry.at >= 0 then entry.at else 2)
		if now >= start and now < start + duration then
			return {
				kind = entry.kind,
				start = start,
				duration = duration,
				progress = (now - start) / duration,
				seed = seed * 31 + i,
			}
		end
		if still then
			break
		end
	end
	return nil
end

local current = nil
local function skyAt(now: number, still: boolean, dt: number?): ({ [string]: any }, { any })
	local dark = Sky.darkness(hour)
	local omen = forcedOmen(now, still) or (if #forced > 0 then nil else Omens.at(seed, now, dark))
	local storm = math.max(def.storm, Tuning.Sky.DryLightning * dark)
	local strike = Omens.omenStrike(omen, now) or Omens.strike(seed, now, storm)
	local flash = Omens.flash(strike, now)
	if still and options.flash then
		flash = tonumber(options.flash) or 0
		strike = strike
			or {
				start = now,
				seed = seed,
				pulses = {},
				distance = 2600,
				azimuth = math.rad(230),
				red = omen ~= nil and omen.kind == "Bleed",
			}
	end
	local target = Sky.compose({
		hour = hour,
		a = def,
		b = def,
		w = 0,
		lobby = false,
		fog = 0,
		alarm = nil,
		dread = dread,
		eliminated = false,
		flare = 0,
		omen = omen,
		now = now,
	})
	-- a ride eases from frame to frame as the game does; a still is the settled look
	current = if dt then Sky.approach(current, target, dt) else target
	local drawn = Sky.finish(current, 0, flash, strike ~= nil and strike.red)
	local speed = if rideSeconds > 0 then Tuning.Motion.CruiseSpeed else 0
	local wind = Sky.wind(speed, now)
	Heavens.update(rig, drawn, {
		now = now,
		focus = roblox.Vector3.zero,
		omen = omen,
		strike = strike,
		drift = 1 + 2 * speed / Tuning.Motion.CruiseSpeed,
	})
	return SkyExport.state(drawn, wind, 38), SkyExport.heavens(rig)
end

local sky, heavens = skyAt(startAt, true)
local frames = nil
if fps > 0 and rideSeconds > 0 then
	frames = {}
	current = nil
	for f = 0, math.floor(rideSeconds * fps) do
		local t = f / fps
		if sweep then
			hour = sweep[1] + (sweep[2] - sweep[1]) * t / rideSeconds
		end
		local frameSky, frameHeavens = skyAt(startAt + t, false, 1 / fps)
		table.insert(frames, { t = t, sky = frameSky, heavens = frameHeavens })
	end
end

local ride = if rideSeconds > 0 then { speed = Tuning.Motion.CruiseSpeed, seconds = rideSeconds } else nil
fs.writeFile(
	out,
	serde.encode("json", {
		biome = biome,
		seed = seed,
		odometer = odometer,
		hour = hour,
		parts = parts,
		lights = lights,
		ride = ride,
		sky = sky,
		heavens = heavens,
		frames = frames,
	})
)
print(
	`{#parts} parts, {#lights} lights, {#heavens} sky objects{if frames then `, {#frames} sky frames` else ""} -> {out} (odometer {odometer}, hour {hour})`
)
