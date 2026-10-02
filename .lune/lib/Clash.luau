--[[
	Interpenetration between separate objects, for the audit.

	Inside one object (a house, a tree, a bridge) parts overlap by design. Two
	separate objects should not: a tree trunk through a cottage wall or a cart
	sunk into a fence reads as a glitch. Each solid carries the group of the
	object it belongs to, and solids of different groups that sink into each other
	deeper than a tolerance are reported.

	Blocks and wedges are exact convex solids, cylinders 12-sided prisms (within 4%
	of the round), balls spheres. Solid against solid uses the separating axis
	test, whose least overlap is the depth. A sphere is measured against the
	solid's box (exact for a block) and then its own face planes, which rule out
	a wedge's empty half and a cylinder's corners.

	Not checked: bodies of the same blend against each other (crowns of
	neighbouring trees mingle, so do the domes of neighbouring hills) and flat
	decals lying on the ground (scorch marks, a pond's water, a muddy shore),
	which things stand in by design.
]]

local Clash = {}

type Vec = { number }
type Plane = { n: Vec, d: number }

export type Body = {
	part: any,
	group: number,
	blend: string?, -- "foliage", "mound": bodies of one blend may overlap one another
	ball: boolean,
	center: Vec,
	radius: number,
	axes: { Vec }, -- the part's own X, Y and Z
	half: Vec, -- its half size along them
	vertices: { Vec },
	planes: { Plane }, -- outward face planes
	normals: { Vec }, -- distinct face directions, for the separating axis test
	edges: { Vec }, -- distinct edge directions
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	minZ: number,
	maxZ: number,
}

export type Hit = { a: Body, b: Body, depth: number }

local FOLIAGE: { [string]: boolean } = { LeafyGrass = true, Grass = true }
local SIDES = 12

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function unit(v: Vec): Vec?
	local m = math.sqrt(dot(v, v))
	if m < 1e-9 then
		return nil
	end
	return { v[1] / m, v[2] / m, v[3] / m }
end

--[[
	A flat plate lying on the ground: level, at most `thin` thick, its underside
	within a stud of `groundY`.
]]
function Clash.isDecal(part: any, offset: any?, groundY: number): boolean
	local cf = if offset then offset * part.CFrame else part.CFrame
	if math.abs(cf.UpVector.Y) < 0.99 or part.Size.Y > 0.35 then
		return false
	end
	local bottom = cf.Position.Y - part.Size.Y / 2
	return bottom > groundY - 1 and bottom < groundY + 1
end

function Clash.body(part: any, offset: any?, group: number, blend: string?): Body?
	local shape = if part:IsA("Part") then part.Shape.Name elseif part:IsA("WedgePart") then "Wedge" else nil
	if shape == nil then
		return nil
	end
	local cf = if offset then offset * part.CFrame else part.CFrame
	local p = cf.Position
	local size = part.Size
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ax: Vec, ay: Vec, az: Vec = { r.X, r.Y, r.Z }, { u.X, u.Y, u.Z }, { -l.X, -l.Y, -l.Z }
	local center: Vec = { p.X, p.Y, p.Z }
	-- part space to world space
	local function world(x: number, y: number, z: number): Vec
		return {
			center[1] + ax[1] * x + ay[1] * y + az[1] * z,
			center[2] + ax[2] * x + ay[2] * y + az[2] * z,
			center[3] + ax[3] * x + ay[3] * y + az[3] * z,
		}
	end
	local function direction(x: number, y: number, z: number): Vec
		return unit({
			ax[1] * x + ay[1] * y + az[1] * z,
			ax[2] * x + ay[2] * y + az[2] * z,
			ax[3] * x + ay[3] * y + az[3] * z,
		}) :: Vec
	end
	local body: Body = {
		part = part,
		group = group,
		blend = blend or (if FOLIAGE[part.Material.Name] then "foliage" else nil),
		ball = shape == "Ball",
		center = center,
		radius = math.min(hx, hy, hz),
		axes = { ax, ay, az },
		half = { hx, hy, hz },
		vertices = {},
		planes = {},
		normals = {},
		edges = {},
		minX = math.huge,
		maxX = -math.huge,
		minY = math.huge,
		maxY = -math.huge,
		minZ = math.huge,
		maxZ = -math.huge,
	}
	-- a face through `point` with outward normal along part-space (x, y, z)
	local function face(x: number, y: number, z: number, point: Vec)
		local n = direction(x, y, z)
		table.insert(body.planes, { n = n, d = dot(n, point) })
	end
	if body.ball then
		local radius = body.radius
		body.minX, body.maxX = p.X - radius, p.X + radius
		body.minY, body.maxY = p.Y - radius, p.Y + radius
		body.minZ, body.maxZ = p.Z - radius, p.Z + radius
		return body
	elseif shape == "Block" or shape == "CornerWedge" then
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					table.insert(body.vertices, world(sx * hx, sy * hy, sz * hz))
				end
			end
			face(sx, 0, 0, world(sx * hx, 0, 0))
			face(0, sx, 0, world(0, sx * hy, 0))
			face(0, 0, sx, world(0, 0, sx * hz))
		end
		body.normals = { ax, ay, az }
		body.edges = { ax, ay, az }
	elseif shape == "Wedge" then
		-- full height at +Z, the slope running down to the front edge at -Z
		for _, sx in { -1, 1 } do
			table.insert(body.vertices, world(sx * hx, -hy, -hz))
			table.insert(body.vertices, world(sx * hx, -hy, hz))
			table.insert(body.vertices, world(sx * hx, hy, hz))
			face(sx, 0, 0, world(sx * hx, 0, 0))
		end
		face(0, -1, 0, world(0, -hy, 0))
		face(0, 0, 1, world(0, 0, hz))
		face(0, hz, -hy, world(0, 0, 0))
		local slope = direction(0, hz, -hy)
		body.normals = { ax, ay, az, slope }
		body.edges = { ax, ay, az, direction(0, hy, hz) }
	elseif shape == "Cylinder" then
		-- axis along X; vertices on the round, so the prism sits just inside it
		local radius = math.min(hy, hz)
		for i = 0, SIDES - 1 do
			local a = i / SIDES * math.pi * 2
			for _, sx in { -1, 1 } do
				table.insert(body.vertices, world(sx * hx, math.cos(a) * radius, math.sin(a) * radius))
			end
			local m = (i + 0.5) / SIDES * math.pi * 2
			local inset = radius * math.cos(math.pi / SIDES)
			face(0, math.cos(m), math.sin(m), world(0, math.cos(m) * inset, math.sin(m) * inset))
			if i < SIDES / 2 then
				table.insert(body.normals, direction(0, math.cos(m), math.sin(m)))
				table.insert(body.edges, direction(0, -math.sin(m), math.cos(m)))
			end
		end
		face(1, 0, 0, world(hx, 0, 0))
		face(-1, 0, 0, world(-hx, 0, 0))
		table.insert(body.normals, ax)
		table.insert(body.edges, ax)
	else
		return nil
	end
	for _, v in body.vertices do
		body.minX, body.maxX = math.min(body.minX, v[1]), math.max(body.maxX, v[1])
		body.minY, body.maxY = math.min(body.minY, v[2]), math.max(body.maxY, v[2])
		body.minZ, body.maxZ = math.min(body.minZ, v[3]), math.max(body.maxZ, v[3])
	end
	return body
end

local function project(body: Body, axis: Vec): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, v in body.vertices do
		local x = dot(v, axis)
		lo, hi = math.min(lo, x), math.max(hi, x)
	end
	return lo, hi
end

-- How deep two convex solids sink into each other (0 when apart): the least overlap over the separating axes.
local function solidSolid(a: Body, b: Body): number
	local axes: { Vec } = {}
	for _, n in a.normals do
		table.insert(axes, n)
	end
	for _, n in b.normals do
		table.insert(axes, n)
	end
	for _, ea in a.edges do
		for _, eb in b.edges do
			local c = unit(cross(ea, eb))
			if c then
				table.insert(axes, c)
			end
		end
	end
	local depth = math.huge
	for _, axis in axes do
		local loA, hiA = project(a, axis)
		local loB, hiB = project(b, axis)
		local overlap = math.min(hiA, hiB) - math.max(loA, loB)
		if overlap <= 0 then
			return 0
		end
		depth = math.min(depth, overlap)
	end
	return depth
end

local function ballSolid(ball: Body, solid: Body): number
	-- against the solid's box: the nearest point of the box to the ball's centre
	local d = {
		ball.center[1] - solid.center[1],
		ball.center[2] - solid.center[2],
		ball.center[3] - solid.center[3],
	}
	local sq, inside, nearest = 0, true, math.huge
	for i = 1, 3 do
		local x, h = dot(d, solid.axes[i]), solid.half[i]
		if x > h then
			sq += (x - h) * (x - h)
			inside = false
		elseif x < -h then
			sq += (x + h) * (x + h)
			inside = false
		else
			nearest = math.min(nearest, h - math.abs(x))
		end
	end
	local depth = if inside then ball.radius + nearest else ball.radius - math.sqrt(sq)
	if depth <= 0 then
		return 0
	end
	-- a wedge's slope or a cylinder's round can still keep the ball clear
	for _, plane in solid.planes do
		if dot(plane.n, ball.center) - plane.d > ball.radius then
			return 0
		end
	end
	return depth
end

local function ballBall(a: Body, b: Body): number
	local dx, dy, dz = a.center[1] - b.center[1], a.center[2] - b.center[2], a.center[3] - b.center[3]
	return math.max(0, a.radius + b.radius - math.sqrt(dx * dx + dy * dy + dz * dz))
end

function Clash.depth(a: Body, b: Body): number
	if a.ball and b.ball then
		return ballBall(a, b)
	elseif a.ball then
		return ballSolid(a, b)
	elseif b.ball then
		return ballSolid(b, a)
	end
	return solidSolid(a, b)
end

-- Every pair of bodies from different groups sinking into each other deeper than `tolerance`.
function Clash.find(bodies: { Body }, tolerance: number): { Hit }
	table.sort(bodies, function(p, q)
		return p.minX < q.minX
	end)
	local hits: { Hit } = {}
	for i, a in bodies do
		local j = i + 1
		while j <= #bodies and bodies[j].minX < a.maxX do
			local b = bodies[j]
			if
				a.group ~= b.group
				and not (a.blend ~= nil and a.blend == b.blend)
				and a.minY < b.maxY
				and b.minY < a.maxY
				and a.minZ < b.maxZ
				and b.minZ < a.maxZ
			then
				local depth = Clash.depth(a, b)
				if depth > tolerance then
					table.insert(hits, { a = a, b = b, depth = depth })
				end
			end
			j += 1
		end
	end
	return hits
end

return Clash
