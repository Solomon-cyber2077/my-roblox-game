--!strict
--[[
	Part factory used by every procedural builder. No meshes or uploaded assets:
	everything in the world is assembled from engine primitives, materials and
	lights, which is what lets the whole game live in source control.

	Parts are created anchored, smooth-surfaced, untouchable (CanTouch off) and,
	when non-collidable, invisible to raycasts and prompts (CanQuery off).
]]

local Kit = {}

local RAD = math.rad

export type Options = {
	material: Enum.Material?,
	collide: boolean?,
	shadow: boolean?,
	transparency: number?,
	reflectance: number?,
	name: string?,
}

function Kit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Kit.shade(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

function Kit.make(
	className: "Part" | "WedgePart" | "CornerWedgePart" | "Seat",
	parent: Instance?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: Options?
): BasePart
	local opts: Options = options or {}
	local part = Instance.new(className) :: BasePart
	part.Name = opts.name or "Part"
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.Transparency = opts.transparency or 0
	part.Reflectance = opts.reflectance or 0
	part.Anchored = true
	part.CanTouch = false
	local collide = if opts.collide == nil then true else opts.collide
	part.CanCollide = collide
	part.CanQuery = collide
	part.CastShadow = if opts.shadow == nil then true else opts.shadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Kit.block(
	parent: Instance?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: Options?
): BasePart
	return Kit.make("Part", parent, size, cframe, color, options)
end

function Kit.wedge(
	parent: Instance?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: Options?
): BasePart
	return Kit.make("WedgePart", parent, size, cframe, color, options)
end

--[[
	A seat cushion players can sit on. The sitter faces the frame's -Z. CanTouch is off
	(as for every Kit part), so nobody sits by walking into it: the game seats them through
	a prompt (TrainService).
]]
function Kit.seat(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: Options?): Seat
	local seat = Kit.make("Seat", parent, size, cframe, color, options) :: Seat
	seat.Name = "Seat"
	return seat
end

-- Cylinder whose axis runs along the given frame's X axis.
function Kit.cylinder(
	parent: Instance?,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	options: Options?
): BasePart
	local part =
		Kit.make("Part", parent, Vector3.new(length, diameter, diameter), cframe, color, options) :: Part
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Upright cylinder centred on `position` in the given frame.
function Kit.post(
	parent: Instance?,
	height: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	options: Options?
): BasePart
	return Kit.cylinder(parent, height, diameter, cframe * CFrame.Angles(0, 0, RAD(90)), color, options)
end

function Kit.ball(
	parent: Instance?,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	options: Options?
): BasePart
	local part = Kit.make("Part", parent, Vector3.one * diameter, cframe, color, options) :: Part
	part.Shape = Enum.PartType.Ball
	return part
end

function Kit.neon(
	parent: Instance?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?
): BasePart
	local part = Kit.make(
		"Part",
		parent,
		size,
		cframe,
		color,
		{ material = Enum.Material.Neon, collide = false, shadow = false }
	) :: Part
	if shape then
		part.Shape = shape
	end
	return part
end

function Kit.pointLight(
	parent: Instance,
	color: Color3,
	brightness: number,
	range: number,
	shadows: boolean?
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

function Kit.spotLight(
	parent: Instance,
	color: Color3,
	brightness: number,
	range: number,
	angle: number,
	face: Enum.NormalId
): SpotLight
	local light = Instance.new("SpotLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Face = face
	light.Shadows = true
	light.Parent = parent
	return light
end

function Kit.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Kit.weld(part: BasePart, to: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	return weld
end

-- Welds every BasePart under `container` to `base`, then unanchors all but `base`.
function Kit.weldAll(container: Instance, base: BasePart)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= base then
			Kit.weld(descendant, base)
			descendant.Anchored = false
		end
	end
end

function Kit.setCollisionGroup(container: Instance, group: string)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
	if container:IsA("BasePart") then
		container.CollisionGroup = group
	end
end

-- A deterministic shade jitter for tiles and planks: factor in [1 - spread, 1 + spread].
function Kit.jitter(color: Color3, spread: number, roll: number): Color3
	return Kit.shade(color, 1 - spread + 2 * spread * roll)
end

function Kit.angles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(RAD(x), RAD(y), RAD(z))
end

--[[
	The frame for a member running from a to b: at the midpoint, looking from a to
	b, its X axis level. CFrame.lookAt has no unique answer for a member that runs
	straight up or down; this one keeps X along world X there, so square and flat
	members stay aligned with their neighbours.
]]
function Kit.between(a: Vector3, b: Vector3): CFrame
	local mid = (a + b) / 2
	local direction = b - a
	local horizontal = math.sqrt(direction.X * direction.X + direction.Z * direction.Z)
	if horizontal < 1e-6 * direction.Magnitude then
		return CFrame.new(mid) * CFrame.Angles(if direction.Y > 0 then math.pi / 2 else -math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(mid, b)
end

return table.freeze(Kit)
