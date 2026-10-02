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
local TrainBuilder = load(Server.Builders.TrainBuilder)
local World = load(Client.Scenery.World)
local Land = load(Client.Scenery.Land)
local Features = load(Client.Scenery.Features)
local Chunk = load(Client.Scenery.Chunk)

local biome = process.args[1] or "Farmland"
local out = process.args[2] or "scene.json"
local seed = tonumber(process.args[3]) or 1
local odometer = tonumber(process.args[4])
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
local models: { { model: any, offset: any } } = {}

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
	table.insert(models, { model = model, offset = CFrame.new() })
	print(`gallery length {x}`)
end

local train = TrainBuilder.build(CFrame.new(), nil).model
table.insert(models, { model = train, offset = CFrame.new() })
for _, layer in if gallery then {} else Land.Layers do
	local first = math.floor((odometer + layer.from) / layer.length)
	local last = math.floor((odometer + layer.to) / layer.length)
	for k = first, last do
		local model = Chunk.begin(layer.name)
		Land.build(layer, k, model, k * layer.length)
		table.insert(models, { model = model, offset = CFrame.new(k * layer.length - odometer, 0, 0) })
	end
end
for _, piece in pieces do
	if piece.at + piece.length > odometer - 1600 and piece.at < odometer + 4400 then
		local model = Chunk.begin(piece.kind)
		Features.build(piece, model)
		table.insert(models, { model = model, offset = CFrame.new(piece.at - odometer, 0, 0) })
	end
end
local hole = Chunk.begin("Sinkhole")
Features.buildSinkhole(sinkhole, hole)
table.insert(models, { model = hole, offset = CFrame.new(sinkhole.rect.x0 - odometer, 0, 0) })

local SHAPES = { Block = "B", Cylinder = "C", Ball = "S", Wedge = "W", CornerWedge = "B" }

local function round(x: number): number
	return math.floor(x * 1000 + 0.5) / 1000
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
				c = {
					math.floor(d.Color.R * 255 + 0.5),
					math.floor(d.Color.G * 255 + 0.5),
					math.floor(d.Color.B * 255 + 0.5),
				},
				m = d.Material.Name,
				t = round(d.Transparency),
				f = round(d.Reflectance),
			})
		elseif (d:IsA("PointLight") or d:IsA("SpotLight")) and d.Parent and d.Parent:IsA("BasePart") then
			local p = (entry.offset * d.Parent.CFrame).Position
			table.insert(lights, {
				p = { round(p.X), round(p.Y), round(p.Z) },
				c = {
					math.floor(d.Color.R * 255 + 0.5),
					math.floor(d.Color.G * 255 + 0.5),
					math.floor(d.Color.B * 255 + 0.5),
				},
				b = d.Brightness,
				r = d.Range,
			})
		end
	end
end

fs.writeFile(
	out,
	serde.encode("json", { biome = biome, seed = seed, odometer = odometer, parts = parts, lights = lights })
)
print(`{#parts} parts, {#lights} lights -> {out} (odometer {odometer})`)
