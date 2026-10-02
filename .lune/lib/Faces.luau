--[[
	Face geometry for the audit's z-fighting check.

	Two parts flicker ("z-fight") where a face of one lies in the same plane as a
	face of the other, both face the same way, both are visible, and they overlap.
	Faces that touch back to back (opposite normals) are hidden from each other and
	never flicker, so only same-facing pairs are reported.

	Supported shapes: Part blocks (six rectangles), Part cylinders (two end caps;
	the curved side cannot be coplanar with anything flat) and WedgeParts (back,
	bottom, slope and two triangular sides). Balls and corner wedges are skipped.
]]

local roblox = require("@lune/roblox")

local Vector3new = roblox.Vector3.new

local Faces = {}

export type Face = {
	part: any,
	nx: number,
	ny: number,
	nz: number,
	d: number, -- plane offset: n . p
	points: { { number } }, -- convex polygon, world space
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

export type Fight = { a: Face, b: Face, area: number, width: number, gap: number }

local CAP_SIDES = 12

local function cross(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number
): (number, number, number)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function normalize(x: number, y: number, z: number): (number, number, number)
	local m = math.sqrt(x * x + y * y + z * z)
	if m < 1e-9 then
		return 0, 0, 0
	end
	return x / m, y / m, z / m
end

--[[
	Builds a face from its world points and its outward normal. The normal comes
	from the part's rotation, not from the points: positions are single precision,
	so far from the origin a normal taken across two points a fraction of a stud
	apart (a cylinder cap's rim) can be off by a quarter of a degree.
]]
local function face(part: any, points: { { number } }, nx: number, ny: number, nz: number): Face?
	nx, ny, nz = normalize(nx, ny, nz)
	if nx == 0 and ny == 0 and nz == 0 then
		return nil
	end
	local fx, fy, fz = 0, 0, 0
	for _, p in points do
		fx += p[1]
		fy += p[2]
		fz += p[3]
	end
	fx, fy, fz = fx / #points, fy / #points, fz / #points
	local result: Face = {
		part = part,
		nx = nx,
		ny = ny,
		nz = nz,
		d = nx * fx + ny * fy + nz * fz,
		points = points,
		minX = math.huge,
		minY = math.huge,
		minZ = math.huge,
		maxX = -math.huge,
		maxY = -math.huge,
		maxZ = -math.huge,
	}
	for _, p in points do
		result.minX = math.min(result.minX, p[1])
		result.minY = math.min(result.minY, p[2])
		result.minZ = math.min(result.minZ, p[3])
		result.maxX = math.max(result.maxX, p[1])
		result.maxY = math.max(result.maxY, p[2])
		result.maxZ = math.max(result.maxZ, p[3])
	end
	return result
end

-- Every flat face of `part`, in world space (shifted by `offset` when given).
function Faces.of(part: any, offset: any?): { Face }
	local cf = if offset then offset * part.CFrame else part.CFrame
	local size = part.Size
	local pos = cf.Position
	local px, py, pz = pos.X, pos.Y, pos.Z
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local rx, ry, rz = r.X, r.Y, r.Z
	local ux, uy, uz = u.X, u.Y, u.Z
	local bx, by, bz = -l.X, -l.Y, -l.Z -- local +Z
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local function P(x: number, y: number, z: number): { number }
		return {
			px + rx * x + ux * y + bx * z,
			py + ry * x + uy * y + by * z,
			pz + rz * x + uz * y + bz * z,
		}
	end
	-- outward normals in part space, turned into world space with the part's axes
	local faces: { Face } = {}
	local function add(points: { { number } }, lx: number, ly: number, lz: number)
		local f = face(
			part,
			points,
			rx * lx + ux * ly + bx * lz,
			ry * lx + uy * ly + by * lz,
			rz * lx + uz * ly + bz * lz
		)
		if f then
			table.insert(faces, f)
		end
	end
	if part.ClassName == "Part" then
		local shape = part.Shape.Name
		if shape == "Block" then
			for _, s in { -1, 1 } do
				add(
					{ P(s * hx, -hy, -hz), P(s * hx, hy, -hz), P(s * hx, hy, hz), P(s * hx, -hy, hz) },
					s,
					0,
					0
				)
				add(
					{ P(-hx, s * hy, -hz), P(hx, s * hy, -hz), P(hx, s * hy, hz), P(-hx, s * hy, hz) },
					0,
					s,
					0
				)
				add(
					{ P(-hx, -hy, s * hz), P(hx, -hy, s * hz), P(hx, hy, s * hz), P(-hx, hy, s * hz) },
					0,
					0,
					s
				)
			end
		elseif shape == "Cylinder" then
			local radius = math.min(hy, hz)
			for _, s in { -1, 1 } do
				local cap: { { number } } = {}
				for i = 0, CAP_SIDES - 1 do
					local a = i / CAP_SIDES * math.pi * 2
					table.insert(cap, P(s * hx, math.cos(a) * radius, math.sin(a) * radius))
				end
				add(cap, s, 0, 0)
			end
		end
	elseif part.ClassName == "WedgePart" then
		-- full height at +Z, sloping down to the front edge at -Z
		add({ P(-hx, -hy, hz), P(hx, -hy, hz), P(hx, hy, hz), P(-hx, hy, hz) }, 0, 0, 1)
		add({ P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, -hy, hz), P(-hx, -hy, hz) }, 0, -1, 0)
		add({ P(-hx, hy, hz), P(hx, hy, hz), P(hx, -hy, -hz), P(-hx, -hy, -hz) }, 0, hz, -hy)
		for _, s in { -1, 1 } do
			add({ P(s * hx, -hy, -hz), P(s * hx, -hy, hz), P(s * hx, hy, hz) }, s, 0, 0)
		end
	end
	return faces
end

-- Polygon clipping in the shared plane ------------------------------------------------------

local function project(
	f: Face,
	ux: number,
	uy: number,
	uz: number,
	vx: number,
	vy: number,
	vz: number
): { { number } }
	local out: { { number } } = {}
	for _, p in f.points do
		table.insert(out, { p[1] * ux + p[2] * uy + p[3] * uz, p[1] * vx + p[2] * vy + p[3] * vz })
	end
	-- counter-clockwise
	local area = 0
	for i = 1, #out do
		local a, b = out[i], out[i % #out + 1]
		area += a[1] * b[2] - b[1] * a[2]
	end
	if area < 0 then
		local reversed: { { number } } = {}
		for i = #out, 1, -1 do
			table.insert(reversed, out[i])
		end
		return reversed
	end
	return out
end

local function area(poly: { { number } }): number
	local sum = 0
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		sum += a[1] * b[2] - b[1] * a[2]
	end
	return math.abs(sum) / 2
end

-- Sutherland-Hodgman: `subject` clipped by the convex, counter-clockwise `clip`.
local function clipPolygon(subject: { { number } }, clip: { { number } }): { { number } }
	local output = subject
	for i = 1, #clip do
		if #output == 0 then
			break
		end
		local a, b = clip[i], clip[i % #clip + 1]
		local ex, ey = b[1] - a[1], b[2] - a[2]
		local function inside(p: { number }): boolean
			return ex * (p[2] - a[2]) - ey * (p[1] - a[1]) >= -1e-9
		end
		local function intersect(p: { number }, q: { number }): { number }
			local dx, dy = q[1] - p[1], q[2] - p[2]
			local denom = ex * dy - ey * dx
			if math.abs(denom) < 1e-12 then
				return p
			end
			local t = (ey * (p[1] - a[1]) - ex * (p[2] - a[2])) / denom
			return { p[1] + dx * t, p[2] + dy * t }
		end
		local input = output
		output = {}
		for j = 1, #input do
			local p, q = input[j], input[j % #input + 1]
			local pin, qin = inside(p), inside(q)
			if pin then
				table.insert(output, p)
				if not qin then
					table.insert(output, intersect(p, q))
				end
			elseif qin then
				table.insert(output, intersect(p, q))
			end
		end
	end
	return output
end

--[[
	The overlap of two coplanar faces: its area, its mean width (area over its
	longest extent) and the greatest distance between the two planes across it. Faces that only meet along an edge still produce a sliver,
	since part positions are single precision: at 5000 studs from the origin a
	shared edge can be off by a few thousandths of a stud. The width tells such a
	sliver from a real overlap.
]]
function Faces.overlap(a: Face, b: Face): (number, number, number)
	local nx, ny, nz = a.nx, a.ny, a.nz
	local ux, uy, uz
	if math.abs(nx) < 0.9 then
		ux, uy, uz = normalize(cross(nx, ny, nz, 1, 0, 0))
	else
		ux, uy, uz = normalize(cross(nx, ny, nz, 0, 1, 0))
	end
	local vx, vy, vz = cross(nx, ny, nz, ux, uy, uz)
	local pa = project(a, ux, uy, uz, vx, vy, vz)
	local pb = project(b, ux, uy, uz, vx, vy, vz)
	local clipped = clipPolygon(pa, pb)
	if #clipped < 3 then
		return 0, 0, math.huge
	end
	-- how far apart the two planes are across the overlap (their normals may differ a hair)
	local separation = 0
	for _, q in clipped do
		local x = ux * q[1] + vx * q[2] + nx * a.d
		local y = uy * q[1] + vy * q[2] + ny * a.d
		local z = uz * q[1] + vz * q[2] + nz * a.d
		separation = math.max(separation, math.abs(b.nx * x + b.ny * y + b.nz * z - b.d))
	end
	local span = 0
	for i = 1, #clipped do
		for j = i + 1, #clipped do
			local du, dv = clipped[i][1] - clipped[j][1], clipped[i][2] - clipped[j][2]
			span = math.max(span, math.sqrt(du * du + dv * dv))
		end
	end
	local size = area(clipped)
	return size, if span > 0 then size / span else 0, separation
end

--[[
	Same-facing coplanar overlaps between faces of different parts.
	gapLimit: plane offsets closer than this count as coplanar.
	minArea, minWidth: smaller or thinner overlaps (edge contact, rounding) are
	ignored.
]]
function Faces.fights(faces: { Face }, gapLimit: number, minArea: number, minWidth: number): { Fight }
	local groups: { [string]: { Face } } = {}
	for _, f in faces do
		local key =
			`{math.floor(f.nx * 1000 + 0.5)},{math.floor(f.ny * 1000 + 0.5)},{math.floor(f.nz * 1000 + 0.5)}`
		local group = groups[key]
		if group == nil then
			group = {}
			groups[key] = group
		end
		table.insert(group, f)
	end
	local fights: { Fight } = {}
	for _, group in groups do
		table.sort(group, function(p, q)
			return p.d < q.d
		end)
		for i = 1, #group do
			local a = group[i]
			local j = i + 1
			while j <= #group and group[j].d - a.d < gapLimit do
				local b = group[j]
				if
					a.part ~= b.part
					and a.minX < b.maxX + 1e-3
					and b.minX < a.maxX + 1e-3
					and a.minY < b.maxY + 1e-3
					and b.minY < a.maxY + 1e-3
					and a.minZ < b.maxZ + 1e-3
					and b.minZ < a.maxZ + 1e-3
				then
					local size, width, separation = Faces.overlap(a, b)
					if size > minArea and width > minWidth and separation < gapLimit then
						table.insert(fights, { a = a, b = b, area = size, width = width, gap = b.d - a.d })
					end
				end
				j += 1
			end
		end
	end
	return fights
end

-- Occlusion --------------------------------------------------------------------------------------

--[[
	A coplanar pair only flickers where players can see it. A face pressed against
	another solid (a ridge's base on the ground slab, a leg's top inside a seat) is
	hidden, so fights are re-checked by sampling points just in front of the
	overlap: if every sample sits inside some other opaque solid, the overlap is
	buried and harmless.
]]

export type Solid = {
	part: any,
	inverse: any, -- world to part space
	shape: string, -- Block, Wedge, Cylinder or Ball
	hx: number,
	hy: number,
	hz: number,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	minY: number,
	maxY: number,
}

export type Index = { cells: { [string]: { Solid } }, big: { Solid } }

local CELL = 64
local MAX_CELLS = 64
local TOLERANCE = 1e-4

function Faces.solid(part: any, offset: any?): Solid?
	local shape
	if part.ClassName == "WedgePart" then
		shape = "Wedge"
	elseif part.ClassName == "Part" then
		shape = part.Shape.Name
		if shape ~= "Block" and shape ~= "Cylinder" and shape ~= "Ball" then
			return nil
		end
	else
		return nil
	end
	local cf = if offset then offset * part.CFrame else part.CFrame
	local size = part.Size
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local solid: Solid = {
		part = part,
		inverse = cf:Inverse(),
		shape = shape,
		hx = hx,
		hy = hy,
		hz = hz,
		minX = math.huge,
		minY = math.huge,
		minZ = math.huge,
		maxX = -math.huge,
		maxY = -math.huge,
		maxZ = -math.huge,
	}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = cf * Vector3new(sx * hx, sy * hy, sz * hz)
				solid.minX = math.min(solid.minX, corner.X)
				solid.minY = math.min(solid.minY, corner.Y)
				solid.minZ = math.min(solid.minZ, corner.Z)
				solid.maxX = math.max(solid.maxX, corner.X)
				solid.maxY = math.max(solid.maxY, corner.Y)
				solid.maxZ = math.max(solid.maxZ, corner.Z)
			end
		end
	end
	return solid
end

-- Grid cell of a coordinate. Adding 0 turns -0 into 0, so "-0,0" and "0,0" are one key.
local function cellOf(v: number): number
	return math.floor(v / CELL) + 0
end

function Faces.index(solids: { Solid }): Index
	local index: Index = { cells = {}, big = {} }
	for _, solid in solids do
		local x0, x1 = cellOf(solid.minX), cellOf(solid.maxX)
		local z0, z1 = cellOf(solid.minZ), cellOf(solid.maxZ)
		if (x1 - x0 + 1) * (z1 - z0 + 1) > MAX_CELLS then
			table.insert(index.big, solid)
		else
			for cx = x0, x1 do
				for cz = z0, z1 do
					local key = `{cx},{cz}`
					local cell = index.cells[key]
					if cell == nil then
						cell = {}
						index.cells[key] = cell
					end
					table.insert(cell, solid)
				end
			end
		end
	end
	return index
end

local function inside(solid: Solid, x: number, y: number, z: number): boolean
	if
		x < solid.minX
		or x > solid.maxX
		or y < solid.minY
		or y > solid.maxY
		or z < solid.minZ
		or z > solid.maxZ
	then
		return false
	end
	local p = solid.inverse * Vector3new(x, y, z)
	local lx, ly, lz = p.X, p.Y, p.Z
	local hx, hy, hz = solid.hx + TOLERANCE, solid.hy + TOLERANCE, solid.hz + TOLERANCE
	if solid.shape == "Ball" then
		local r = math.min(solid.hx, solid.hy, solid.hz) + TOLERANCE
		return lx * lx + ly * ly + lz * lz <= r * r
	end
	if math.abs(lx) > hx or math.abs(ly) > hy or math.abs(lz) > hz then
		return false
	end
	if solid.shape == "Cylinder" then
		local r = math.min(solid.hy, solid.hz) + TOLERANCE
		return ly * ly + lz * lz <= r * r
	elseif solid.shape == "Wedge" then
		-- below the slope from the top back edge to the bottom front edge
		return ly / solid.hy - lz / solid.hz <= 1e-3
	end
	return true
end

local function covered(index: Index, x: number, y: number, z: number, a: any, b: any): boolean
	local cell = index.cells[`{cellOf(x)},{cellOf(z)}`]
	for _, list in { cell or {}, index.big } do
		for _, solid in list do
			if solid.part ~= a and solid.part ~= b and inside(solid, x, y, z) then
				return true
			end
		end
	end
	return false
end

-- True when the overlap of a coplanar pair is buried inside other opaque solids.
function Faces.buried(fight: Fight, index: Index): boolean
	local a, b = fight.a, fight.b
	local nx, ny, nz = a.nx, a.ny, a.nz
	local ux, uy, uz
	if math.abs(nx) < 0.9 then
		ux, uy, uz = normalize(cross(nx, ny, nz, 1, 0, 0))
	else
		ux, uy, uz = normalize(cross(nx, ny, nz, 0, 1, 0))
	end
	local vx, vy, vz = cross(nx, ny, nz, ux, uy, uz)
	local clipped = clipPolygon(project(a, ux, uy, uz, vx, vy, vz), project(b, ux, uy, uz, vx, vy, vz))
	if #clipped < 3 then
		return true
	end
	local cu, cv = 0, 0
	for _, p in clipped do
		cu += p[1]
		cv += p[2]
	end
	cu, cv = cu / #clipped, cv / #clipped
	local samples: { { number } } = { { cu, cv } }
	for _, p in clipped do
		table.insert(samples, { cu + (p[1] - cu) * 0.8, cv + (p[2] - cv) * 0.8 })
	end
	local d = a.d + 0.03
	for _, sample in samples do
		local x = ux * sample[1] + vx * sample[2] + nx * d
		local y = uy * sample[1] + vy * sample[2] + ny * d
		local z = uz * sample[1] + vz * sample[2] + nz * d
		if not covered(index, x, y, z, a.part, b.part) then
			return false
		end
	end
	return true
end

return Faces
