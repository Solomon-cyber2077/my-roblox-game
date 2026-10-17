--[[
	Exports real stations, their grades and the sky as the client draws it, for the
	dim-screen render harness (tools/visibility, Blender headless):

	  lune run visibility <out.json> [seed]

	For each harness stop (an early, a mid and a late grade) it builds the station the
	server builds (LayoutGen + StationBuilder, docked at the platform edge) and writes every
	visible part (shape, size, frame, colour, material, collision), the kit meshes
	Builders/StationKit would dress it in (the Blender kit's pieces, by name), every light,
	and the sky (Scenery/Sky: compose, chase, floor) at that stop's hour, calm and chased,
	for each floor radius the harness sweeps. Every number the renderer lights with comes
	from here: Tuning, Config/Cosmetics, Scenery/Sky and UI/Overlay's dread vignette.
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
local Tuning = load(Shared.Config.Tuning)
local Stations = load(Shared.Config.Stations)
local Cosmetics = load(Shared.Config.Cosmetics)
local KitConfig = load(Shared.Config.StationKit)
local Journey = load(Shared.Logic.Journey)
local LayoutGen = load(Shared.Logic.LayoutGen)
local Sky = load(Client.Scenery.Sky)
local Biomes = load(Client.Scenery.Biomes)
local StationKit = load(Server.Builders.StationKit)
local StationBuilder = load(Server.Builders.StationBuilder)
local TrainBuilder = load(Server.Builders.TrainBuilder)
local SkyExport = require("./lib/SkyExport")

local out = process.args[1] or "visibility.json"
local seed = tonumber(process.args[2]) or 424242
local CFrame = roblox.CFrame

-- early, mid and late: three grade families (cold cyan, olive-grey, damp green-grey)
local STOPS = {
	{ id = "Halt", stop = 1, label = "early" },
	{ id = "Market", stop = 4, label = "mid" },
	{ id = "Minehead", stop = 8, label = "late" },
}
-- floor radii the harness sweeps for the slider's range (the default included)
local RADII = { 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 34, 38 }

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

local function frame(cf: any): ({ number }, { number })
	local p, r, u, b = cf.Position, cf.RightVector, cf.UpVector, -cf.LookVector
	return { round(p.X), round(p.Y), round(p.Z) }, {
		round(r.X),
		round(r.Y),
		round(r.Z),
		round(u.X),
		round(u.Y),
		round(u.Z),
		round(b.X),
		round(b.Y),
		round(b.Z),
	}
end

-- Builders/StationKit.dress, recorded: headless there are no mesh templates, so the
-- renderer places the Blender kit's piece over the same primitives the game hides.
local dressed: { any } = {}
StationKit.dress = function(kind: string, piece: any, at: any, length: number?): any
	local name = KitConfig.ByProp[kind]
	local def = name and KitConfig.Pieces[name]
	if not def or not def.meshId then
		return nil
	end
	for _, part in piece:GetDescendants() do
		if part:IsA("BasePart") and part.Material ~= roblox.Enum.Material.Neon then
			if part:FindFirstChildWhichIsA("Light") == nil then
				part.Transparency = 1
			end
		end
	end
	local scale = if def.stretch and length then length / def.size[1] else 1
	-- the kit's .blend keeps each piece's origin at its foot centre, so its foot frame is enough
	local p, r = frame(at)
	table.insert(dressed, {
		piece = name,
		kind = kind,
		scale = scale,
		p = p,
		r = r,
		m = def.material,
	})
	return nil
end

local SHAPES = { Block = "B", Cylinder = "C", Ball = "S", Wedge = "W", CornerWedge = "B" }
local FACES = {
	Front = roblox.Vector3.new(0, 0, -1),
	Back = roblox.Vector3.new(0, 0, 1),
	Top = roblox.Vector3.new(0, 1, 0),
	Bottom = roblox.Vector3.new(0, -1, 0),
	Right = roblox.Vector3.new(1, 0, 0),
	Left = roblox.Vector3.new(-1, 0, 0),
}
local COPING = { 226, 226, 218 } -- StationBuilder's whitewashed platform coping

-- the top-level model a part belongs to under the station (Slab_3, a building, a prop kind),
-- keyed uniquely; VisibilityController rims the listed prop kinds and every building
local Buildings = load(Shared.Config.Buildings)
local RIM_KINDS: { [string]: boolean } = {}
for _, kind in Tuning.Visibility.Rim.Kinds do
	RIM_KINDS[kind] = true
end

local function export(model: any, prefix: string): ({ any }, { any }, { [string]: any })
	local parts, lights, groups = {}, {}, {}
	local keys: { [any]: string } = {}
	for i, child in model:GetChildren() do
		local key = `{prefix}{child.Name}#{i}`
		keys[child] = key
		groups[key] = {
			name = child.Name,
			pivot = nil, -- filled in below: the centre of its parts (headless has no GetPivot)
			rim = child:IsA("Model") and (RIM_KINDS[child.Name] or Buildings.Defs[child.Name] ~= nil) or nil,
		}
	end
	local function group(part: any): string
		local node = part
		while node.Parent and node.Parent ~= model do
			node = node.Parent
		end
		return keys[node] or prefix
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local p, r = frame(d.CFrame)
			local c = rgb(d.Color)
			local g = group(d)
			local edge = string.match(g, "Slab_") ~= nil
				and c[1] == COPING[1]
				and c[2] == COPING[2]
				and c[3] == COPING[3]
				and math.abs(d.Size.Y - 0.3) < 0.01
			table.insert(parts, {
				s = if d:IsA("WedgePart") then "W" elseif d:IsA("Part") then SHAPES[d.Shape.Name] else "B",
				z = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				p = p,
				r = r,
				c = c,
				m = d.Material.Name,
				t = round(d.Transparency),
				col = d.CanCollide,
				g = g,
				edge = edge or nil,
			})
		elseif d:IsA("Light") and d.Parent and d.Parent:IsA("BasePart") and d.Enabled then
			local cf = d.Parent.CFrame
			local light: { [string]: any } = {
				p = frame(cf),
				c = rgb(d.Color),
				b = d.Brightness,
				r = d.Range,
			}
			if d:IsA("SpotLight") or d:IsA("SurfaceLight") then
				local axis = cf:VectorToWorldSpace(FACES[d.Face.Name])
				light.d = { round(axis.X), round(axis.Y), round(axis.Z) }
				light.a = d.Angle
			end
			table.insert(lights, light)
		end
	end
	-- a group's pivot: the centre of its parts' positions (a built model's PrimaryPart sits
	-- near it; rims pick the nearest few, so the approximation only reorders near-ties)
	local sums: { [string]: { number } } = {}
	for _, part in parts do
		local sum = sums[part.g] or { 0, 0, 0, 0 }
		sum[1] += part.p[1]
		sum[2] += part.p[2]
		sum[3] += part.p[3]
		sum[4] += 1
		sums[part.g] = sum
	end
	for key, sum in sums do
		if groups[key] then
			groups[key].pivot = { round(sum[1] / sum[4]), round(sum[2] / sum[4]), round(sum[3] / sum[4]) }
		end
	end
	return parts, lights, groups
end

local function skyFor(id: string, hour: number, chase: number, dread: number, radius: number): any
	local def = Biomes.get(Journey.biomeFor(id))
	local g = Tuning.Visibility.Grades[id] or Tuning.Visibility.Grades.Default
	local state = Sky.compose({
		grade = {
			tint = roblox.Color3.fromRGB(g.tint[1], g.tint[2], g.tint[3]),
			saturation = g.saturation,
			weight = 1, -- out on the platform, past GradeRamp
		},
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
		omen = nil,
		now = 1000,
	})
	local drawn = Sky.finish(state, 0, 0, false)
	drawn = Sky.chase(drawn, chase, 0)
	drawn = Sky.floor(drawn, radius)
	return SkyExport.state(drawn, roblox.Vector3.zero, 38)
end

-- UI/Overlay's dread vignette, read from its source so the harness cannot drift from it
local overlay = fs.readFile("src/client/UI/Overlay.luau")
local function constant(name: string): number
	return tonumber(string.match(overlay, `local {name} = ([%d%.]+)`)) :: number
end
local function color(name: string): { number }
	local r, g, b = string.match(overlay, `local {name} = Color3.fromRGB%((%d+), (%d+), (%d+)%)`)
	return { tonumber(r) :: number, tonumber(g) :: number, tonumber(b) :: number }
end
local atmosphere = fs.readFile("src/client/Controllers/AtmosphereController.luau")
local near, far = string.match(atmosphere, "local DREAD_NEAR, DREAD_FAR = (%d+), (%d+)")

local lanterns = {}
for _, item in Cosmetics.List do
	if item.category == "Lantern" then
		table.insert(lanterns, {
			id = item.id,
			light = item.look.light,
			light2 = item.look.light2,
			glass = item.look.glass,
			glow = math.max(item.look.glow or 1, 1),
		})
	end
end

local stations = {}
local edgeZ = Tuning.World.PlatformEdgeZ
for _, spec in STOPS do
	table.clear(dressed)
	local plan = LayoutGen.generate(spec.id, seed, 1)
	local model = StationBuilder.build(plan, CFrame.new(0, 0, edgeZ), Stations.List[spec.id].name).model
	local parts, lights, groups = export(model, "")
	-- the docked train beside the platform edge, as the audit and the preview place it
	local trainParts, trainLights, trainGroups = export(TrainBuilder.build(CFrame.new(), nil).model, "Train/")
	table.move(trainParts, 1, #trainParts, #parts + 1, parts)
	table.move(trainLights, 1, #trainLights, #lights + 1, lights)
	for key, value in trainGroups do
		groups[key] = value
	end
	local hour = Journey.hour(Journey.skyProgress(spec.stop, 1, 0.5), Tuning.Run.StationCount)
	local skies = {}
	for _, radius in RADII do
		skies[tostring(radius)] = {
			calm = skyFor(spec.id, hour, 0, 0, radius),
			chase = skyFor(spec.id, hour, 1, 1, radius),
		}
	end
	table.insert(stations, {
		id = spec.id,
		label = spec.label,
		stop = spec.stop,
		hour = hour,
		length = plan.length,
		depth = plan.depth,
		parts = parts,
		groups = groups,
		meshes = table.clone(dressed),
		lights = lights,
		skies = skies,
	})
	print(
		`{spec.label} {spec.id}: {#parts} parts, {#dressed} kit meshes, {#lights} lights, hour {round(hour)}`
	)
end

local V = Tuning.Visibility
fs.writeFile(
	out,
	serde.encode("json", {
		seed = seed,
		edgeZ = edgeZ,
		radii = RADII,
		visibility = {
			radius = V.Radius,
			radiusMin = V.RadiusMin,
			radiusMax = V.RadiusMax,
			chase = V.Chase,
			rim = V.Rim,
			grades = V.Grades,
			budget = V.Budget,
		},
		lantern = Tuning.CarriedLantern,
		lanterns = lanterns,
		movement = { walk = Tuning.Crew.WalkSpeed, sprint = Tuning.Crew.SprintSpeed },
		camera = { zoom = Tuning.Camera.StartZoom, fov = 70 },
		dread = {
			near = tonumber(near),
			far = tonumber(far),
			shadeMax = constant("SHADE_MAX"),
			shadeColor = color("SHADE_COLOR"),
			shadeTint = color("SHADE_TINT"),
			desaturate = constant("SHADE_DESATURATE"),
			chaseShare = V.Chase.Vignette,
		},
		stations = stations,
	})
)
print(`-> {out}`)
