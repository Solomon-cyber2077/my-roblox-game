--[[
	The visual audit: builds every model the game makes, headless, and checks it.

	  lune run audit            every target
	  lune run audit Station    targets whose name contains "Station"

	The real builders run under Lune's Roblox library (Instances, CFrames, enums)
	with a small shim for the few engine globals they touch (lib/Shim). Each
	target is checked for:

	  * builder errors
	  * z-fighting: visible faces of two parts in the same plane, facing the same
	    way and overlapping, which flicker in game (see lib/Faces)
	  * clashes: separate objects (props, set pieces) sunk into one another, a
	    tree through a wall, a cart in a fence (see lib/Clash)
	  * budgets: parts, lights, shadow-casting lights, particle emitters and the
	    particles they keep alive (rate times mean lifetime)

	The scenery is audited per biome as the window the train sees at one moment:
	every landscape layer, three set pieces and a station sinkhole together, so
	clashes between layers and set pieces are caught as well.

	Exits with code 1 on any error, z-fight or budget overrun.
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local stdio = require("@lune/stdio")

local Clash = require("./lib/Clash")
local Faces = require("./lib/Faces")
local Loader = require("./lib/Loader")
local Shim = require("./lib/Shim")

Shim.install()
local Rng = Loader.requireNode(Loader.roots.Shared.Util.Rng)

local Instance = roblox.Instance
local CFrame = roblox.CFrame

local function load(node: any): any
	return Loader.requireNode(node)
end

local Shared, Client, Server = Loader.roots.Shared, Loader.roots.Client, Loader.roots.Server
local Journey = load(Shared.Logic.Journey)
local LayoutGen = load(Shared.Logic.LayoutGen)
local Stations = load(Shared.Config.Stations)
local Items = load(Shared.Config.Items)
local Cosmetics = load(Shared.Config.Cosmetics)
local Tuning = load(Shared.Config.Tuning)
local ItemModel = load(Shared.Visual.ItemModel)
local CosmeticModels = load(Shared.Visual.CosmeticModels)
local TrainBuilder = load(Server.Builders.TrainBuilder)
local LobbyBuilder = load(Server.Builders.LobbyBuilder)
local StationBuilder = load(Server.Builders.StationBuilder)
local HollowBuilder = load(Server.Builders.HollowBuilder)
local World = load(Client.Scenery.World)
local Land = load(Client.Scenery.Land)
local Features = load(Client.Scenery.Features)
local Chunk = load(Client.Scenery.Chunk)
local Props = load(Client.Scenery.Props)
local Biomes = load(Client.Scenery.Biomes)
local Bands = load(Client.Scenery.Bands)
local Kit = load(Shared.Visual.Kit)

--[[
	Clash groups. Every Props builder is wrapped so the parts one outermost call
	adds under its parent become one group: one tree, one house (with its fire).
	Parts nobody claims belong to their item's group (a set piece) or, in the
	landscape layers, to the ground, which is not checked.
]]
local groupOf: { [any]: number } = {}
local lastGroup = 0
local function newGroup(): number
	lastGroup += 1
	return lastGroup
end
local building = 0
for name, fn in Props :: any do
	if type(fn) ~= "function" then
		continue
	end
	(Props :: any)[name] = function(parent: any, ...: any): ...any
		if building > 0 or typeof(parent) ~= "Instance" then
			building += 1
			local results = table.pack(fn(parent, ...))
			building -= 1
			return table.unpack(results, 1, results.n)
		end
		local before = #parent:GetChildren()
		building += 1
		local results = table.pack(fn(parent, ...))
		building -= 1
		local group = newGroup()
		local children = parent:GetChildren()
		for i = before + 1, #children do
			local child = children[i]
			if child:IsA("BasePart") then
				groupOf[child] = group
			end
			for _, d in child:GetDescendants() do
				if d:IsA("BasePart") then
					groupOf[d] = group
				end
			end
		end
		return table.unpack(results, 1, results.n)
	end
end

-- Limits -------------------------------------------------------------------------------------------

local GAP = 0.01 -- planes closer than this are coplanar
local MIN_AREA = 0.02 -- square studs of overlap that count as a z-fight
local MIN_WIDTH = 0.01 -- and how wide it must be (thinner is single-precision rounding along a shared edge)
local CLASH_DEPTH = 0.2 -- separate objects may touch, or sink this far into each other, no further
local SHOW = tonumber(process.env.AUDIT_SHOW) or 12 -- z-fights printed per target
local VERBOSE = process.env.AUDIT_VERBOSE ~= nil -- also print each shown fight's face polygons

type Budget = { parts: number?, lights: number?, shadows: number?, emitters: number?, particles: number? }
--[[
	context: built only so the window's edges look the way they will once the
	game builds the neighbouring chunks. Its parts bury and fight like any other,
	but a fight between two context parts is not reported (it belongs to the
	window one chunk along), and they do not count toward budgets.
]]
type Item = {
	instance: any,
	offset: any?,
	skip: { [any]: boolean }?,
	budget: Budget?,
	label: string?,
	layer: string?,
	context: boolean?,
	problems: { string }?, -- found while building (a prop outgrowing its footprint)
	note: string?, -- printed under the target's line
	group: number?, -- clash group for parts no prop claimed (a set piece's own masonry)
}
type Target = { name: string, budget: Budget?, build: () -> { Item } }

-- Positions jointed parts (Motor6D, Weld) the way the engine would at rest.
local function solveJoints(model: any)
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			table.insert(joints, d)
		end
	end
	for _ = 1, #joints do
		local moved = false
		for _, joint in joints do
			local p0, p1 = joint.Part0, joint.Part1
			if p0 and p1 then
				local want = p0.CFrame * joint.C0 * joint.C1:Inverse()
				if (want.Position - p1.CFrame.Position).Magnitude > 1e-4 then
					p1.CFrame = want
					moved = true
				end
			end
		end
		if not moved then
			break
		end
	end
end

-- Targets ---------------------------------------------------------------------------------------------

local targets: { Target } = {}

table.insert(targets, {
	name = "GrabLifecycle",
	build = function()
		local run = require("./lib/HollowLifecycle")
		return { { instance = Instance.new("Folder"), note = run() } }
	end,
})

table.insert(targets, {
	name = "TrainCamera",
	build = function()
		local framing = load(Client.Camera.TrainFraming)
		local sky = load(Client.Scenery.Sky)
		local problems: { string } = {}
		local shots = 0
		for _, aspect in { 16 / 9, 4 / 3, 1, 9 / 16 } do
			for hour = 18.3, 29.8, 0.1 do
				local moon = sky.moon(hour)
				local center = roblox.Vector3.new(0, 6, 0)
				local eye, focus, fov = framing.moon(center, moon.direction, moon.size, aspect)
				local look = (focus - eye).Unit
				local right = look:Cross(roblox.Vector3.yAxis).Unit
				local up = right:Cross(look).Unit
				local tangent = math.tan(math.rad(fov / 2))
				local function visible(offset: any): boolean
					local depth = offset:Dot(look)
					return depth > 0
						and math.abs(offset:Dot(up)) < depth * tangent
						and math.abs(offset:Dot(right)) < depth * tangent * aspect
				end
				local good = visible(moon.direction)
				for _, x in { -105, 105 } do
					for _, y in { -6, 10 } do
						for _, z in { -8, 8 } do
							good = good and visible(center + roblox.Vector3.new(x, y, z) - eye)
						end
					end
				end
				local moonAngle = math.deg(math.acos(math.clamp(look:Dot(moon.direction), -1, 1)))
				good = good and moonAngle + moon.size / 2 < fov / 2
				if not good then
					table.insert(problems, `train or moon cropped at {hour}, aspect {aspect}`)
				end
				shots += 1
			end
		end
		return {
			{
				instance = Instance.new("Folder"),
				problems = problems,
				note = `train and moon framed in {shots} night/aspect combinations`,
			},
		}
	end,
})

table.insert(targets, {
	name = "StationFog",
	budget = { parts = 72, lights = 2, shadows = 0, emitters = 53, particles = 5000 },
	build = function()
		local fog = load(Client.Scenery.StationFog)
		local root = Instance.new("Folder")
		local clears = 0
		roblox.implementMethod("ParticleEmitter", "Clear", function()
			clears += 1
		end)
		fog.build(root)
		local function pose(now: number, front: number)
			fog.update({
				station = CFrame.new(),
				length = 360,
				depth = 180,
				front = front,
				waiting = 1,
				camera = roblox.Vector3.zero,
				archetype = "Halt",
				now = now,
			}, 1 / 60)
		end
		pose(100, 100)
		fog.clear()
		local problems: { string } = {}
		local emitters = 0
		for _, item in root:GetDescendants() do
			if item:IsA("ParticleEmitter") then
				emitters += 1
				if item.Rate ~= 0 then
					table.insert(problems, "emitter remains active after departure")
				end
			elseif item:IsA("BasePart") and item.Transparency ~= 1 then
				table.insert(problems, "fog figure remains visible after departure")
			elseif item:IsA("PointLight") and item.Brightness ~= 0 then
				table.insert(problems, "fog light remains lit after departure")
			end
		end
		if clears ~= emitters then
			table.insert(problems, "live particles not cleared on departure")
		end
		fog.clear()
		if clears ~= emitters then
			table.insert(problems, "idle fog is repeatedly clearing particles")
		end
		pose(200, 60)
		return {
			{
				instance = root,
				problems = problems,
				note = `fog resumes after clearing all {emitters} emitters`,
			},
		}
	end,
})

table.insert(targets, {
	name = "Train",
	budget = { parts = 2000, lights = 34, shadows = 10, emitters = 4 },
	build = function()
		return { { instance = TrainBuilder.build(CFrame.new(), nil).model } }
	end,
})

table.insert(targets, {
	name = "Lobby",
	budget = { parts = 3200, lights = 48, shadows = 16, emitters = 12 },
	build = function()
		local folder = Instance.new("Folder")
		local built = LobbyBuilder.build(CFrame.new(), folder)
		-- the display train is the Train target's business
		local skip: { [any]: boolean } = {}
		for _, d in built.displayTrain:GetDescendants() do
			skip[d] = true
		end
		return { { instance = built.model, skip = skip } }
	end,
})

local archetypes = {}
for id in Stations.List do
	table.insert(archetypes, id)
end
table.sort(archetypes)
for _, id in archetypes do
	table.insert(targets, {
		name = `Station/{id}`,
		budget = { parts = 4200, lights = 40, shadows = 12, emitters = 60 },
		build = function()
			local plan = LayoutGen.generate(id, 424242, 1)
			local edge = Tuning.World.PlatformEdgeZ
			return {
				{
					instance = StationBuilder.build(plan, CFrame.new(0, 0, edge), Stations.List[id].name).model,
				},
			}
		end,
	})
end

for _, kind in HollowBuilder.Kinds do
	table.insert(targets, {
		name = `Hollow/{kind}`,
		budget = { parts = 130, lights = 1, shadows = 0, emitters = 3 },
		build = function()
			local model = HollowBuilder.build(CFrame.new(0, 5, 0), kind)
			solveJoints(model)
			return { { instance = model } }
		end,
	})
end

--[[
	The Hollows' bodies in motion (Animation/HollowPoses): every grab must put the Hollow's
	hands on its victim through the whole hold, and the Crawler's spider walk must reach
	every foothold at every speed. A limb sent further than it can stretch is a problem.
]]
table.insert(targets, {
	name = "Grabs",
	build = function()
		local HollowPoses = load(Client.Animation.HollowPoses)
		local Grabs = load(Shared.Config.Grabs)
		local problems: { string } = {}
		local worst = 0
		local posed = 0
		local function input(state: string, extra: { [string]: any }): any
			local base = {
				state = state,
				elapsed = 0.2,
				speed = 0,
				phase = 0,
				now = 100,
				seed = 7,
				emerge = "Rise",
				stunned = false,
				windup = 0.3,
				grab = nil,
				grabTime = 0,
			}
			for key, value in extra do
				base[key] = value
			end
			return base
		end
		for _, kind in HollowBuilder.Kinds do
			local rig = HollowPoses.rigOf(HollowBuilder.build(CFrame.new(), kind))
			for _, def in Grabs.Kinds[kind] do
				for t = 0.1, 4, 0.15 do
					HollowPoses.pose(rig, input("Grab", { grab = def.id, grabTime = t, now = 100 + t }))
					posed += 1
					local short = HollowPoses.shortfall()
					worst = math.max(worst, short)
					if short > 0.3 then
						table.insert(
							problems,
							string.format(
								"%s %s: a hand falls %.2f studs short %.1fs in",
								kind,
								def.id,
								short,
								t
							)
						)
						break
					end
				end
			end
			if kind == "Crawler" then
				for _, state in
					{ "Prowl", "Hunt", "Windup", "Recover", "Dormant", "Emerge", "Repelled", "Reel" }
				do
					for speed = 0, 30, 3 do
						for phase = 0, 6.2, 0.4 do
							HollowPoses.pose(
								rig,
								input(state, { speed = speed, phase = phase, elapsed = phase / 6.2 * 1.5 })
							)
							posed += 1
							local short = HollowPoses.shortfall()
							worst = math.max(worst, short)
							if short > 0.3 then
								table.insert(
									problems,
									string.format(
										"Crawler %s at %d studs/s: a limb falls %.2f studs short",
										state,
										speed,
										short
									)
								)
								break
							end
						end
					end
				end
			end
		end
		return {
			{
				instance = Instance.new("Folder"),
				problems = problems,
				note = string.format(
					"grabs and gaits: posed %d times, the furthest reach %.2f studs short",
					posed,
					worst
				),
			},
		}
	end,
})

table.insert(targets, {
	name = "Items",
	build = function()
		local list: { Item } = {}
		local ids = {}
		for id in Items do
			table.insert(ids, id)
		end
		table.sort(ids)
		for i, id in ids do
			table.insert(list, { instance = ItemModel.build(id, CFrame.new(i * 12, 0, 0), 1.25), label = id })
		end
		return list
	end,
})

table.insert(targets, {
	name = "Cosmetics",
	build = function()
		local list: { Item } = {}
		for i, def in Cosmetics.List do
			local frame = CFrame.new(i * 12, 0, 0)
			local model = if def.category == "Lantern"
				then CosmeticModels.lantern(def.look, frame)
				elseif def.category == "Headwear" then CosmeticModels.headwear(def.look, frame)
				else nil
			if model then
				solveJoints(model)
				table.insert(list, { instance = model, label = def.id })
			end
		end
		return list
	end,
})

--[[
	Every landscape prop on its own, in every biome's colours and with three seeds,
	each standing on a patch of near ground as it would in the game. Props are
	spaced so they never meet one another.
]]
local PROP_SPACING = 320

-- How far a model reaches from `origin` in plan view (ignoring invisible parts and `skip`).
local function reach(model: any, origin: any, skip: any): number
	local r = 0
	local function point(p: any)
		local dx, dz = p.X - origin.X, p.Z - origin.Z
		r = math.max(r, math.sqrt(dx * dx + dz * dz))
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= skip and d.Transparency < 0.98 then
			local cf, size = d.CFrame, d.Size
			local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
			local shape = if d:IsA("Part") then d.Shape.Name else "Block"
			if shape == "Ball" then
				local p = cf.Position
				local dx, dz = p.X - origin.X, p.Z - origin.Z
				r = math.max(r, math.sqrt(dx * dx + dz * dz) + math.min(hx, hy, hz))
			elseif shape == "Cylinder" then
				local radius = math.min(hy, hz)
				for _, sx in { -1, 1 } do
					for i = 0, 15 do
						local a = i / 16 * math.pi * 2
						point(cf * roblox.Vector3.new(sx * hx, math.cos(a) * radius, math.sin(a) * radius))
					end
				end
			else
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							point(cf * roblox.Vector3.new(sx * hx, sy * hy, sz * hz))
						end
					end
				end
			end
		end
	end
	return r
end

table.insert(targets, {
	name = "Props",
	budget = { shadows = 0 },
	build = function()
		local list: { Item } = {}
		local biomes = Biomes.ids()
		local seeds = tonumber(process.env.AUDIT_PROP_SEEDS) or 8
		for k, kind in Props.kinds() do
			for s = 1, seeds do
				local biome = Biomes.get(biomes[(k + s) % #biomes + 1])
				local model = Instance.new("Model")
				model.Name = kind
				local at = CFrame.new(k * PROP_SPACING, 0, s * PROP_SPACING)
				local ground = Kit.block(
					model,
					roblox.Vector3.new(PROP_SPACING - 20, Bands.NearThickness, PROP_SPACING - 20),
					at * CFrame.new(0, Bands.Ground - Bands.NearThickness / 2, 0),
					roblox.Color3.new(0.3, 0.3, 0.3),
					{ collide = false, shadow = false }
				)
				-- each seed at its own yaw, so orientation-dependent clashes show up
				local yaw = CFrame.Angles(0, math.rad((s - 1) * 37 % 360), 0)
				Props.build(kind, model, at * CFrame.new(0, Bands.Ground, 0) * yaw, {
					rng = Rng.new(9000 + k * 10 + s),
					biome = biome,
					shadow = false,
				})
				solveJoints(model)
				-- the packer keeps props Props.radius apart: each must fit inside its own
				local problems: { string } = {}
				local footprint = reach(model, at.Position, ground)
				if footprint > Props.radius(kind) + 0.25 then
					table.insert(
						problems,
						string.format(
							"%s seed %d reaches %.1f studs, past its radius %g",
							kind,
							s,
							footprint,
							Props.radius(kind)
						)
					)
				end
				if process.env.AUDIT_FOOTPRINTS then
					print(
						string.format(
							"    footprint %-12s seed %d  %6.1f  (radius %g)",
							kind,
							s,
							footprint,
							Props.radius(kind)
						)
					)
				end
				table.insert(list, { instance = model, label = `{kind} seed {s}`, problems = problems })
			end
		end
		return list
	end,
})

--[[
	The sky objects (Scenery/Heavens) are BillboardGuis, not parts: built once, then posed
	every frame. This target builds the rig headless and runs the client's per-frame sky
	(Scenery/Sky compose, approach and finish, then Heavens.update) through a whole night in
	every biome, with every omen at several moments, lightning, a tunnel, a station's fog,
	dread and the Depot Hall. A runtime error, a NaN or an out-of-range value shows up here
	instead of in Studio, and the rig's frames are held to a budget.
]]
local SKY_FRAMES = 400

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

table.insert(targets, {
	name = "Sky",
	build = function()
		local Sky = load(Client.Scenery.Sky)
		local Heavens = load(Client.Scenery.Heavens)
		local Omens = load(Shared.Logic.Omens)
		local folder = Instance.new("Folder")
		local rig = Heavens.build(folder)
		local problems: { string } = {}
		local frames = 0
		for _, d in rig.anchor:GetDescendants() do
			if d:IsA("GuiObject") then
				frames += 1
			end
		end
		if frames > SKY_FRAMES then
			table.insert(problems, `the sky objects hold {frames} frames, past {SKY_FRAMES}`)
		end
		local function check(label: string, state: any)
			for _, key in { "brightness", "exposure", "density", "haze", "cover", "cloudDensity", "stars" } do
				if not finite(state[key]) then
					table.insert(problems, `{label}: {key} is {state[key]}`)
				end
			end
			for _, key in { "ambient", "outdoor", "shift", "air", "decay", "clouds", "tint", "glowColor" } do
				local c = state[key]
				if not (c.R >= 0 and c.R <= 1 and c.G >= 0 and c.G <= 1 and c.B >= 0 and c.B <= 1) then
					table.insert(problems, `{label}: {key} out of range`)
				end
			end
			local moon = state.moon
			if
				not (
					moon.visible >= 0
					and moon.visible <= 1
					and finite(moon.size)
					and finite(moon.brightness)
				)
			then
				table.insert(problems, `{label}: the moon is off ({moon.visible}, {moon.size})`)
			end
		end
		local kinds: { string | false } = { false }
		local durations: { [string]: number } = {}
		for _, spec in Tuning.Sky.Omens do
			table.insert(kinds, spec.kind)
			durations[spec.kind] = spec.duration
		end
		local current = nil
		local step = 0
		for _, id in Biomes.ids() do
			local def = Biomes.get(id)
			for hour = 18.3, 30.5, 0.61 do
				for _, kind in kinds do
					for _, progress in { 0.05, 0.3, 0.5, 0.9 } do
						step += 1
						local duration = if kind then durations[kind] else 1
						local now = 5000 + progress * duration
						local omen = if kind
							then {
								kind = kind,
								start = 5000,
								duration = duration,
								progress = progress,
								seed = step,
							}
							else nil
						local strike = Omens.omenStrike(omen, now) or Omens.strike(step, now, def.storm)
						if strike == nil and step % 3 == 0 then
							strike = {
								start = now,
								seed = step,
								pulses = { { at = 0, width = 0.1, peak = 1 } },
								distance = 3000,
								azimuth = step,
								red = kind == "Bleed",
							}
						end
						local lobby = step % 23 == 0
						local target = Sky.compose({
							hour = hour,
							a = def,
							b = Biomes.get(Biomes.ids()[step % #Biomes.ids() + 1]),
							w = (step % 5) / 4,
							lobby = lobby,
							fog = (step % 4) / 3,
							alarm = if step % 7 == 0 then 0.5 else nil,
							dread = (step % 6) / 5,
							eliminated = step % 11 == 0,
							flare = if step % 13 == 0 then 0.7 else 0,
							omen = omen,
							now = now,
						})
						current = Sky.approach(current, target, 1 / 60)
						local tunnel = if step % 9 == 0 then 1 else 0
						local drawn = Sky.finish(
							current,
							tunnel,
							Omens.flash(strike, now),
							strike ~= nil and strike.red
						)
						local label =
							`{id} at {string.format("%.1f", hour)}{if kind then ` during {kind}` else ""}`
						check(label, drawn)
						Heavens.update(rig, drawn, {
							now = now,
							focus = roblox.Vector3.new(step, 10, -step),
							omen = omen,
							strike = strike,
							drift = 1 + (step % 3),
						})
					end
				end
			end
			if #problems > 12 then
				break
			end
		end
		return {
			{
				instance = folder,
				problems = problems,
				note = `sky: {frames} frames (budget {SKY_FRAMES}), posed {step} times without a fault`,
			},
		}
	end,
})

-- Every set piece combination (kind, style for gorges, side for sided pieces).
local combos: { { kind: string, style: number, side: number } } = {}
for _, def in Tuning.Journey.Pieces do
	local styles = if def.kind == "Gorge" then { 1, 2 } else { 1 }
	local sides = if def.sided then { 1, -1 } else { 0 }
	for _, style in styles do
		for _, side in sides do
			table.insert(combos, { kind = def.kind, style = style, side = side })
		end
	end
end

local BIOMES = { "Corridor", "Farmland", "Coalfield", "BurningTown", "Highland", "Mountain", "Coast" }
local SCENE_STARTS = { -440, 260, 960 }
local SINK_AT = 1900
--[[
	Scenery budgets at full density (the highest graphics quality; lower levels
	thin the near and mid props down to half). Every scenery part rides on a chunk
	root that moves each frame, so the window's part count is the cost that
	matters. They are all non-colliding, non-queryable, untouchable decor in a
	handful of shapes and materials, which the engine draws in batches; the sweep
	peaks near 5700 in the pine and farm country. Chunk builds are time-sliced in
	SceneryController so a rich chunk never costs a frame. Lights never cast
	shadows out there.
]]
local LAND_BUDGET = 6000 -- parts in the landscape window
local SCENE_BUDGET: Budget = { parts = 7000, lights = 64, shadows = 0, emitters = 240, particles = 8000 }
local PIECE_BUDGET: Budget = { parts = 600, lights = 10, shadows = 0, emitters = 45 }
local SINK_BUDGET: Budget = { parts = 120, lights = 3, shadows = 0, emitters = 4 }

-- AUDIT_SEEDS=n sweeps n world seeds per biome (each with its own set pieces) instead of one.
local SEEDS = tonumber(process.env.AUDIT_SEEDS) or 1
local scenes: { { seed: number, b: number, biome: string } } = {}
for seed = 1, SEEDS do
	for b, biome in BIOMES do
		table.insert(scenes, { seed = seed, b = b, biome = biome })
	end
end
for _, scene in scenes do
	local seed, b, biome = scene.seed, scene.b, scene.biome
	table.insert(targets, {
		name = if seed == 1 then `Scenery/{biome}` else `Scenery/{biome}#{seed}`,
		budget = SCENE_BUDGET,
		build = function()
			World.reset(1000 * seed + b, biome)
			World.density = 1
			local pieces = {}
			for i, start in SCENE_STARTS do
				local combo = combos[((b - 1 + (seed - 1) * 5) * #SCENE_STARTS + i - 1) % #combos + 1]
				local kind, side = combo.kind, combo.side
				if biome == "Coast" then
					-- as Journey.legPlan plans the coast: sided pieces inland, no lake
					kind = if kind == "Lake" then "Crossing" else kind
					side = if Journey.def(kind).sided then -1 else 0
				end
				local def = Journey.def(kind)
				table.insert(pieces, {
					kind = kind,
					leg = 1,
					index = i,
					at = start,
					length = math.floor((def.length[1] + def.length[2]) / 2),
					side = side,
					style = combo.style,
					seed = 7000 + seed * 1000 + b * 10 + i,
				})
			end
			World.pieces = pieces
			local arch = if biome == "Coast"
				then Stations.List.Terminus
				else Stations.List[Stations.Order[(b - 1) % #Stations.Order + 1]]
			local sinkhole =
				Journey.sinkhole(SINK_AT, arch.length, arch.depth, arch.id, arch.terminus == true)
			World.sinkholes = { sinkhole }

			local list: { Item } = {}
			for _, layer in Land.Layers do
				-- the keys SceneryController builds at odometer 0, and one more at each end
				local first, last = math.floor(layer.from / layer.length), math.floor(layer.to / layer.length)
				for k = first - 1, last + 1 do
					local model = Chunk.begin(layer.name)
					Land.build(layer, k, model, k * layer.length)
					table.insert(list, {
						instance = model,
						offset = CFrame.new(k * layer.length, 0, 0),
						label = "Land",
						layer = layer.name,
						context = k < first or k > last,
					})
				end
			end
			for _, piece in pieces do
				local model = Chunk.begin(piece.kind)
				Features.build(piece, model)
				table.insert(list, {
					instance = model,
					offset = CFrame.new(piece.at, 0, 0),
					budget = PIECE_BUDGET,
					group = newGroup(),
					label = `{piece.kind} style {piece.style} side {piece.side}`,
				})
			end
			local model = Chunk.begin("Sinkhole")
			Features.buildSinkhole(sinkhole, model)
			table.insert(list, {
				instance = model,
				offset = CFrame.new(sinkhole.rect.x0, 0, 0),
				budget = SINK_BUDGET,
				group = newGroup(),
				label = `sinkhole {arch.id}`,
			})
			return list
		end,
	})
end

-- Checking -------------------------------------------------------------------------------------------

type Stats = { parts: number, lights: number, shadows: number, emitters: number, particles: number }

local function newStats(): Stats
	return { parts = 0, lights = 0, shadows = 0, emitters = 0, particles = 0 }
end

local function tally(
	item: Item,
	stats: Stats,
	faces: { Faces.Face }?,
	solids: { Faces.Solid }?,
	bodies: { Clash.Body }?
)
	local list = item.instance:GetDescendants()
	table.insert(list, item.instance)
	for _, d in list do
		if item.skip and item.skip[d] then
			continue
		end
		if d:IsA("BasePart") then
			stats.parts += 1
			if faces and d.Transparency < 0.98 then
				for _, f in Faces.of(d, item.offset) do
					table.insert(faces, f)
				end
			end
			if solids and d.Transparency < 0.05 then
				local solid = Faces.solid(d, item.offset)
				if solid then
					table.insert(solids, solid)
				end
			end
			-- ground inside a set piece (a hill, a cliff) is ground: things stand in it
			local group = if d:GetAttribute("Earth") then nil else groupOf[d] or item.group
			local blend: string? = nil
			if group == nil and item.label == "Land" and d:IsA("Part") and d.Shape.Name == "Ball" then
				-- a mound or hill rising out of the ground: props stand clear of it
				group, blend = newGroup(), "mound"
			elseif item.layer == "Horizon" and group then
				-- the peaks of a mountain range run into one another by design
				blend = "mound"
			end
			if
				bodies
				and group
				and d.Transparency < 0.98
				and not Clash.isDecal(d, item.offset, Bands.Ground)
			then
				local body = Clash.body(d, item.offset, group, blend)
				if body then
					table.insert(bodies, body)
				end
			end
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			stats.lights += 1
			if d.Shadows then
				stats.shadows += 1
			end
		elseif d:IsA("ParticleEmitter") then
			stats.emitters += 1
			stats.particles += d.Rate * (d.Lifetime.Min + d.Lifetime.Max) / 2
		end
	end
end

local function over(stats: Stats, budget: Budget?): { string }
	local problems: { string } = {}
	if budget then
		for _, key in { "parts", "lights", "shadows", "emitters", "particles" } do
			local limit = (budget :: any)[key]
			local value = (stats :: any)[key]
			if limit ~= nil and value > limit then
				table.insert(problems, `{key} {math.floor(value + 0.5)} > {limit}`)
			end
		end
	end
	return problems
end

local function describe(part: any, offset: any?): string
	local cf = if offset then offset * part.CFrame else part.CFrame
	local p, s = cf.Position, part.Size
	local where = part.Parent and part.Parent.Name or "?"
	return string.format(
		"%s/%s %s %.2gx%.2gx%.2g at (%.1f, %.2f, %.1f)",
		where,
		part.Name,
		part.Material.Name,
		s.X,
		s.Y,
		s.Z,
		p.X,
		p.Y,
		p.Z
	)
end

-- "+Y at -14.00" for an axis-aligned face, its normal and plane offset otherwise.
local function facing(face: Faces.Face): string
	for _, axis in { { "X", face.nx }, { "Y", face.ny }, { "Z", face.nz } } do
		local n = axis[2] :: number
		if math.abs(math.abs(n) - 1) < 1e-6 then
			return string.format("%s%s at %.2f", if n > 0 then "+" else "-", axis[1] :: string, face.d * n)
		end
	end
	return string.format("normal (%.2f, %.2f, %.2f) at %.2f", face.nx, face.ny, face.nz, face.d)
end

local filter = process.args[1]
local failures = 0
local offsets: { [any]: any } = {}

for _, target in targets do
	if filter and not string.find(string.lower(target.name), string.lower(filter), 1, true) then
		continue
	end
	local ok, built = pcall(target.build)
	if not ok then
		failures += 1
		print(stdio.color("red") .. `{target.name}: build failed: {built}` .. stdio.color("reset"))
		continue
	end
	local faces: { Faces.Face } = {}
	local solids: { Faces.Solid } = {}
	local total = newStats()
	local land = newStats()
	local layers: { [string]: Stats } = {}
	local layerOrder: { string } = {}
	local contextParts: { [any]: boolean } = {}
	local bodies: { Clash.Body } = {}
	local problems: { string } = {}
	for _, item in built :: { Item } do
		local stats = newStats()
		local before = #faces
		local beforeBodies = #bodies
		tally(item, stats, faces, solids, bodies)
		for i = before + 1, #faces do
			offsets[faces[i].part] = item.offset
			if item.context then
				contextParts[faces[i].part] = true
			end
		end
		for i = beforeBodies + 1, #bodies do
			offsets[bodies[i].part] = item.offset
			if item.context then
				contextParts[bodies[i].part] = true
			end
		end
		if item.context then
			continue
		end
		for key, value in stats :: any do
			(total :: any)[key] += value
		end
		if item.label == "Land" then
			for key, value in stats :: any do
				(land :: any)[key] += value
			end
			local name = item.layer or "?"
			if layers[name] == nil then
				layers[name] = newStats()
				table.insert(layerOrder, name)
			end
			for key, value in stats :: any do
				(layers[name] :: any)[key] += value
			end
		elseif #layerOrder > 0 and item.label then
			-- set pieces and sinkholes, one entry each, after the landscape layers
			local name = item.label :: string
			layers[name] = stats
			table.insert(layerOrder, name)
		end
		for _, problem in over(stats, item.budget) do
			table.insert(problems, `{item.label or "item"}: {problem}`)
		end
		for _, problem in item.problems or {} do
			table.insert(problems, problem)
		end
	end
	for _, problem in over(total, target.budget) do
		table.insert(problems, problem)
	end
	if land.parts > 0 and land.parts > LAND_BUDGET then
		table.insert(problems, `landscape window parts {land.parts} > {LAND_BUDGET}`)
	end
	local index = Faces.index(solids)
	local fights: { Faces.Fight } = {}
	for _, fight in Faces.fights(faces, GAP, MIN_AREA, MIN_WIDTH) do
		local outside = contextParts[fight.a.part] and contextParts[fight.b.part]
		if not outside and not Faces.buried(fight, index) then
			table.insert(fights, fight)
		end
	end
	table.sort(fights, function(a, b)
		return a.area > b.area
	end)
	local clashes: { Clash.Hit } = {}
	for _, hit in Clash.find(bodies, CLASH_DEPTH) do
		if not (contextParts[hit.a.part] and contextParts[hit.b.part]) then
			table.insert(clashes, hit)
		end
	end
	table.sort(clashes, function(a, b)
		return a.depth > b.depth
	end)

	local clean = #fights == 0 and #clashes == 0 and #problems == 0
	local color = if clean then "green" else "red"
	local landNote = if land.parts > 0 then string.format("  (landscape window %d)", land.parts) else ""
	print(
		stdio.color(color)
			.. string.format(
				"%-22s %5d parts %4d lights (%d shadow) %4d emitters (%5d particles) %4d z-fights %3d clashes%s",
				target.name,
				total.parts,
				total.lights,
				total.shadows,
				total.emitters,
				total.particles,
				#fights,
				#clashes,
				landNote
			)
			.. stdio.color("reset")
	)
	if #layerOrder > 0 then
		local counts: { string } = {}
		for _, name in layerOrder do
			local layer = layers[name]
			local extra = if layer.emitters > 0
				then string.format(" (%d emitters, %d particles)", layer.emitters, layer.particles)
				else ""
			table.insert(counts, `{name} {layer.parts}{extra}`)
		end
		print(`    window: {table.concat(counts, ", ")}`)
	end
	for _, item in built :: { Item } do
		if item.note then
			print(`    {item.note}`)
		end
	end
	for _, problem in problems do
		print(`    over budget: {problem}`)
	end
	for i = 1, math.min(#fights, SHOW) do
		local fight = fights[i]
		print(
			string.format(
				"    z-fight %.2f sq studs, %s:  %s  |  %s",
				fight.area,
				facing(fight.a),
				describe(fight.a.part, offsets[fight.a.part]),
				describe(fight.b.part, offsets[fight.b.part])
			)
		)
	end
	if VERBOSE then
		for i = 1, math.min(#fights, SHOW) do
			local fight = fights[i]
			for _, face in { fight.a, fight.b } do
				local points: { string } = {}
				for _, p in face.points do
					table.insert(points, string.format("(%.3f, %.3f, %.3f)", p[1], p[2], p[3]))
				end
				local shape = if face.part:IsA("Part") then face.part.Shape.Name else face.part.ClassName
				print(`      #{i} {shape}: {table.concat(points, " ")}`)
			end
		end
	end
	if #fights > SHOW then
		print(`    ... and {#fights - SHOW} more`)
	end
	for i = 1, math.min(#clashes, SHOW) do
		local hit = clashes[i]
		print(
			string.format(
				"    clash %.2f studs deep:  %s  |  %s",
				hit.depth,
				describe(hit.a.part, offsets[hit.a.part]),
				describe(hit.b.part, offsets[hit.b.part])
			)
		)
	end
	if #clashes > SHOW then
		print(`    ... and {#clashes - SHOW} more clashes`)
	end
	if not clean then
		failures += 1
	end
end

if failures > 0 then
	print(stdio.color("red") .. `{failures} target(s) failed the audit` .. stdio.color("reset"))
	process.exit(1)
end
print(stdio.color("green") .. "Audit clean." .. stdio.color("reset"))
