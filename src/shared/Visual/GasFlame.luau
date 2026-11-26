--!strict
--[[
	A gas flame for the lamps: the station yard lamps and hanging lanterns, and the train's
	lanterns and table lamps. A flat-flame burner's flame, seen through the lamp's glass:
	  * a hot core, the lamp's own colour lifted toward white
	  * the outer flame, the lamp's own colour, softer and wider across than deep
	  * a tip, the lamp's colour deepened, that licks and gutters
	  * a faint glow filling the glass panes, so the lamp still reads as lit from far off
	Built on the server as small Neon ellipsoids (SpecialMesh spheres: no upload) under the part
	that carries the lamp's light, so code that finds a lamp by name still finds it.

	Every colour comes from the lamp's existing colour (the `FlameColor` attribute), so a lamp
	reads the same colour as before. The flame never touches a Light: brightness, colour, the
	hull's emergency tint and the phone light budget stay with the controllers that own them.

	The client moves it (GasFlame.animate) at the GraphicsQuality tier (Logic/GrabLook.tier):
	  Quality      every layer; the flame stretches, licks and sways each frame
	  Balanced     core, outer flame and halo; the flame stretches each frame, no tip or sway
	  Performance  core, outer flame and halo; shape held, only colour and halo follow the level
	The flame and its light are present on every tier: players read the yard and the train by them.
]]

local GasFlame = {}

export type Tier = string -- "Quality", "Balanced" or "Performance" (Logic/GrabLook.tier)

type Layer = { part: BasePart, mesh: SpecialMesh, size: Vector3, transparency: number }

export type Flame = {
	holder: BasePart,
	core: Layer,
	outer: Layer,
	tip: Layer,
	halo: Layer,
	glass: BasePart?,
	glassColor: Color3?,
	color: Color3,
	seed: number,
	tier: Tier?,
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SOOT = Color3.fromRGB(26, 20, 14)

-- layer shapes as fractions of the flame's height: size (across, up, deep), centre above the burner
type Shape = { size: Vector3, y: number, transparency: number, lift: number }
local SHAPE: { [string]: Shape } = {
	-- a lamp flame is a slim teardrop, widest low down: a white core at the foot, the body over it,
	-- and a narrow tip that carries the taper up to a point
	FlameCore = { size = Vector3.new(0.2, 0.3, 0.15), y = 0.17, transparency = 0, lift = 0.6 },
	FlameOuter = { size = Vector3.new(0.26, 0.7, 0.19), y = 0.36, transparency = 0.32, lift = 0 },
	FlameTip = { size = Vector3.new(0.12, 0.5, 0.09), y = 0.68, transparency = 0.5, lift = -0.25 },
}

local function layerColor(color: Color3, lift: number): Color3
	return if lift >= 0 then color:Lerp(WHITE, lift) else color:Lerp(BLACK, -lift)
end

local function ellipsoid(
	holder: BasePart,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number,
	meshType: Enum.MeshType?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType or Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = holder
	return part
end

export type Options = {
	-- the glow in the glass: a faint Neon fill the shape of the panes (`round`: an upright
	-- cylinder), so the lamp still reads as lit from far off
	halo: Vector3?,
	haloAt: CFrame?,
	round: boolean?,
	-- the lamp's glass, which soots over as the flame gutters
	glass: BasePart?,
	-- a lamp inside a shade, where a tight part budget matters more than the glow: its core and
	-- halo are tagged Detail, so Performance keeps the outer flame and the light
	-- (Controllers/DetailController)
	lean: boolean?,
}

--[[
	Builds a flame under `holder` (the part that carries, or will carry, the lamp's light).
	`burner` is the burner's tip (the flame's foot), upright; `height` in studs; `color` the lamp's
	existing colour.
]]
function GasFlame.build(holder: BasePart, burner: CFrame, height: number, color: Color3, options: Options?)
	local o: Options = options or {}
	holder:SetAttribute("GasFlame", true)
	holder:SetAttribute("FlameColor", color)
	for name, shape in SHAPE do
		local part = ellipsoid(
			holder,
			name,
			shape.size * height,
			burner * CFrame.new(0, shape.y * height, 0),
			layerColor(color, shape.lift),
			shape.transparency
		)
		-- the tip is a Quality touch; a lean lamp keeps only its outer flame under Performance
		if name == "FlameTip" or (o.lean and name == "FlameCore") then
			part:AddTag("Detail")
		end
	end
	if o.halo then
		local part = ellipsoid(
			holder,
			"FlameHalo",
			o.halo,
			o.haloAt or burner * CFrame.new(0, height * 0.45, 0),
			color,
			0.9,
			if o.round then Enum.MeshType.Cylinder else Enum.MeshType.Brick
		)
		if o.lean then
			part:AddTag("Detail")
		end
	end
	if o.glass then
		local link = Instance.new("ObjectValue")
		link.Name = "FlameGlass"
		link.Value = o.glass
		link.Parent = holder
	end
end

local function layer(holder: BasePart, name: string): Layer?
	local part = holder:FindFirstChild(name)
	local mesh = part and part:FindFirstChildOfClass("SpecialMesh")
	if part and part:IsA("BasePart") and mesh then
		return { part = part, mesh = mesh, size = part.Size, transparency = part.Transparency }
	end
	return nil
end

-- The flame under a lamp's holder, or nil when it has none (or it has not streamed in yet).
function GasFlame.find(holder: Instance, seed: number): Flame?
	if not holder:IsA("BasePart") or holder:GetAttribute("GasFlame") ~= true then
		return nil
	end
	local core, outer, tip =
		layer(holder, "FlameCore"), layer(holder, "FlameOuter"), layer(holder, "FlameTip")
	if not (core and outer and tip) then
		return nil
	end
	local halo = layer(holder, "FlameHalo")
		or { part = outer.part, mesh = outer.mesh, size = outer.size, transparency = outer.transparency }
	local link = holder:FindFirstChild("FlameGlass")
	local glass = if link
			and link:IsA("ObjectValue")
			and link.Value
			and link.Value:IsA("BasePart")
		then link.Value
		else nil
	local color = holder:GetAttribute("FlameColor")
	return {
		holder = holder,
		core = core,
		outer = outer,
		tip = tip,
		halo = halo,
		glass = glass,
		glassColor = if glass then glass.Color else nil,
		color = if typeof(color) == "Color3" then color else outer.part.Color,
		seed = seed,
		tier = nil,
	}
end

-- Stretches a layer to `sy` of its height (and `sx` across) with its foot held on the burner.
-- `dy` moves its foot (the tip rides the top of the outer flame).
local function stretch(l: Layer, sx: number, sy: number, dx: number, dy: number?)
	l.mesh.Scale = Vector3.new(sx, sy, 1)
	l.mesh.Offset = Vector3.new(dx, (sy - 1) * l.size.Y / 2 + (dy or 0), 0)
end

local function show(f: Flame, tier: Tier)
	f.tier = tier
	local extra = tier == "Quality"
	f.tip.part.Transparency = if extra then f.tip.transparency else 1
	if tier == "Performance" then
		stretch(f.core, 1, 1, 0)
		stretch(f.outer, 1, 1, 0)
	end
end

--[[
	Moves one flame. `level` is the lamp's brightness against its usual (1 burns steady, toward 0
	gutters or dies); `now` a clock in seconds; `tint` an override colour (a failing hull's
	emergency red) or nil for the lamp's own.
]]
function GasFlame.animate(f: Flame, level: number, now: number, tier: Tier, tint: Color3?)
	if f.tier ~= tier then
		show(f, tier)
	end
	local lit = math.clamp(level, 0, 1.25)
	local color = tint or f.color
	-- the outer flame deepens toward its tip colour as it starves, never a new hue
	f.outer.part.Color = color:Lerp(BLACK, (1 - math.min(lit, 1)) * 0.35)
	f.core.part.Color = layerColor(color, SHAPE.FlameCore.lift * math.min(lit, 1))
	f.core.part.Transparency = if lit < 0.08 then 1 else 0
	f.outer.part.Transparency = if lit < 0.04 then 1 else f.outer.transparency
	if f.halo.part ~= f.outer.part then
		f.halo.part.Color = color
		f.halo.part.Transparency = f.halo.transparency
			+ (1 - f.halo.transparency) * (1 - math.min(lit, 1)) * 0.8
	end
	if f.glass and f.glassColor then
		f.glass.Color = f.glassColor:Lerp(SOOT, (1 - math.min(lit, 1)) * 0.5)
	end
	if tier == "Performance" then
		return
	end
	local flick = math.noise(now * 9.3, f.seed)
	local height = (0.7 + 0.3 * lit) * (1 + 0.07 * flick)
	local sway = if tier == "Quality" then math.noise(now * 1.4, f.seed + 5.7) * f.outer.size.X * 0.12 else 0
	stretch(f.outer, 1 + 0.05 * flick, height, sway * 0.5)
	stretch(f.core, 1, 0.85 + 0.15 * lit, 0)
	if tier == "Quality" then
		local lick = math.noise(now * 13.1, f.seed + 2.3)
		local rise = (height - 1) * f.outer.size.Y -- the outer flame's top moved this far
		stretch(f.tip, 1, math.max(height * (1 + 0.35 * lick), 0.05), sway, rise)
		f.tip.part.Transparency = f.tip.transparency + (1 - f.tip.transparency) * math.clamp(1.1 - lit, 0, 1)
	end
end

return GasFlame
