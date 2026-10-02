--!strict
--[[
	Lays out and furnishes one enterable building (Config/Buildings). Pure: the same
	kind and seed always give the same plan, on the server and in tests.

	Building-local studs: x along the track, z away from it, y up from the floor, the
	origin at the footprint's centre. The front door is in the -z wall, facing the
	platform; Spine buildings also open at both ends of their corridor, Hall buildings
	at both sides of the hall, so nobody is ever cornered with one way out.

	Walls come out already split around their doors and windows, as pieces that meet
	end to end and never overlap, so no two faces fight. Furniture keeps clear of every
	doorway (DoorClearance) and of each other.
]]

local Shared = script.Parent.Parent
local Buildings = require(Shared.Config.Buildings)
local Stations = require(Shared.Config.Stations)
local Rng = require(Shared.Util.Rng)

export type Rect = { x0: number, z0: number, x1: number, z1: number }
export type DoorRef = { side: string, at: number, width: number }
export type Room = {
	id: number,
	kind: string, -- a Config/Buildings room, or "Corridor"
	rect: Rect, -- the floor inside the walls
	doorSide: string, -- N, S, E or W: the wall its main door is in
	locked: boolean,
	doors: { DoorRef },
}
export type WallPiece = {
	axis: string, -- X: runs along x at z = fixed; Z: runs along z at x = fixed
	fixed: number,
	a: number,
	b: number,
	y0: number,
	y1: number,
	thick: number,
	exterior: boolean,
}
export type Door = {
	x: number,
	z: number,
	axis: string,
	width: number,
	exterior: boolean,
	front: boolean,
	locked: boolean,
	room: number,
	outward: number, -- +1 or -1 along the wall's normal, toward the outside or the corridor
}
export type Window = { x: number, z: number, axis: string, width: number, outward: number, glass: string }
export type Item = { kind: string, x: number, z: number, rot: number, room: number, container: string? }
export type Lamp = { x: number, z: number, room: number, works: boolean }
export type Spot = { x: number, z: number, rot: number, kind: string, room: number }
export type Plan = {
	kind: string,
	width: number,
	depth: number,
	outerX: number, -- half extents of the outer wall faces
	outerZ: number,
	height: number,
	rooms: { Room },
	walls: { WallPiece },
	doors: { Door },
	windows: { Window },
	items: { Item },
	lamps: { Lamp },
	sleepers: { Spot },
	fuse: { x: number, z: number, rot: number },
	exits: { { x: number, z: number } },
}

type Opening = { at: number, width: number, y0: number, y1: number }
type Line = {
	axis: string,
	fixed: number,
	a: number,
	b: number,
	thick: number,
	exterior: boolean,
	openings: { Opening },
}

local BuildingGen = {}

local B = Buildings
local OPPOSITE = { N = "S", S = "N", E = "W", W = "E" }
local SIDES_OF = { N = { "E", "W" }, S = { "E", "W" }, E = { "N", "S" }, W = { "N", "S" } }
local FACE_ROT = { N = 0, S = 180, E = 90, W = 270 } -- an item backed onto this wall faces into the room
local TOWARD_ROT = { N = 180, S = 0, E = 270, W = 90 } -- an item facing toward this wall

local function overlaps(a: Rect, b: Rect, margin: number): boolean
	return a.x0 < b.x1 + margin and b.x0 < a.x1 + margin and a.z0 < b.z1 + margin and b.z0 < a.z1 + margin
end

local function footprint(kind: string, x: number, z: number, rot: number): Rect
	local f = B.Furniture[kind]
	local turned = rot % 180 ~= 0
	local hw = if turned then f.d / 2 else f.w / 2
	local hd = if turned then f.w / 2 else f.d / 2
	return { x0 = x - hw, z0 = z - hd, x1 = x + hw, z1 = z + hd }
end

function BuildingGen.generate(kind: string, seed: number): Plan
	local def = B.Defs[kind]
	assert(def, `unknown building {kind}`)
	local rng = Rng.new(Rng.derive(seed, "building", kind))
	local tile = 12
	local width, depth = def.size[1] * tile, def.size[2] * tile
	local T, P = B.Wall, B.Partition
	local ox, oz = width / 2 - B.Inset, depth / 2 - B.Inset
	local ix, iz = ox - T, oz - T
	local H = def.height

	local lines: { Line } = {}
	local rooms: { Room } = {}
	local doors: { Door } = {}
	local windows: { Window } = {}
	local exits: { { x: number, z: number } } = {}

	local function line(axis: string, fixed: number, a: number, b: number, thick: number, exterior: boolean)
		table.insert(
			lines,
			{ axis = axis, fixed = fixed, a = a, b = b, thick = thick, exterior = exterior, openings = {} }
		)
	end

	local function cut(axis: string, fixed: number, at: number, w: number, y0: number, y1: number): Line?
		for _, l in lines do
			if
				l.axis == axis
				and math.abs(l.fixed - fixed) < 0.01
				and at - w / 2 >= l.a - 0.01
				and at + w / 2 <= l.b + 0.01
			then
				table.insert(l.openings, { at = at, width = w, y0 = y0, y1 = y1 })
				return l
			end
		end
		return nil
	end

	local function room(roomKind: string, rect: Rect, doorSide: string): Room
		local r: Room =
			{ id = #rooms + 1, kind = roomKind, rect = rect, doorSide = doorSide, locked = false, doors = {} }
		table.insert(rooms, r)
		return r
	end

	-- A door through the wall on `side` of room `a` (into room `b`, or outside when nil).
	local function door(a: Room, side: string, at: number, w: number, b: Room?, front: boolean?): Door?
		local r = a.rect
		local axis = if side == "N" or side == "S" then "X" else "Z"
		local fixed: number
		local outward: number
		if side == "N" then
			fixed, outward = r.z1 + (if b then P / 2 else T / 2), 1
		elseif side == "S" then
			fixed, outward = r.z0 - (if b then P / 2 else T / 2), -1
		elseif side == "E" then
			fixed, outward = r.x1 + (if b then P / 2 else T / 2), 1
		else
			fixed, outward = r.x0 - (if b then P / 2 else T / 2), -1
		end
		if cut(axis, fixed, at, w, 0, B.DoorHeight) == nil then
			return nil
		end
		local x = if axis == "X" then at else fixed
		local z = if axis == "X" then fixed else at
		local d: Door = {
			x = x,
			z = z,
			axis = axis,
			width = w,
			exterior = b == nil,
			front = front == true,
			locked = false,
			room = a.id,
			outward = outward,
		}
		table.insert(doors, d)
		table.insert(a.doors, { side = side, at = at, width = w })
		if b then
			table.insert(b.doors, { side = OPPOSITE[side], at = at, width = w })
		else
			local reach = T / 2 + 4
			if axis == "X" then
				table.insert(exits, { x = x, z = z + outward * reach })
			else
				table.insert(exits, { x = x + outward * reach, z = z })
			end
		end
		return d
	end

	-- Splits [x0, x1] into rooms separated by partitions P thick.
	local function split(x0: number, x1: number, minW: number, maxW: number): { { number } }
		local out: { { number } } = {}
		local cursor = x0
		while x1 - cursor > maxW + P + minW do
			local w = rng:range(minW, maxW)
			table.insert(out, { cursor, cursor + w })
			cursor += w + P
		end
		local rest = x1 - cursor
		if rest > maxW * 1.3 then
			local half = (rest - P) / 2
			table.insert(out, { cursor, cursor + half })
			table.insert(out, { cursor + half + P, x1 })
		else
			table.insert(out, { cursor, x1 })
		end
		return out
	end

	local function partitions(segments: { { number } }, z0: number, z1: number)
		for i = 1, #segments - 1 do
			line("Z", segments[i][2] + P / 2, z0, z1, P, false)
		end
	end

	-- exterior walls: front and back run the full width, the sides fit between them
	line("X", -oz + T / 2, -ox, ox, T, true)
	line("X", oz - T / 2, -ox, ox, T, true)
	line("Z", -ox + T / 2, -iz, iz, T, true)
	line("Z", ox - T / 2, -iz, iz, T, true)

	local queue = table.clone(def.rooms)
	local cursor = 0
	local function nextKind(): string
		cursor += 1
		return queue[(cursor - 1) % #queue + 1]
	end

	local frontRoom: Room
	if def.layout == "Spine" then
		local free = 2 * iz - B.CorridorWidth - 2 * P
		local frontDepth = math.floor(free * 0.45)
		local w1 = -iz + frontDepth + P / 2
		local cz0 = w1 + P / 2
		local cz1 = cz0 + B.CorridorWidth
		local w2 = cz1 + P / 2
		line("X", w1, -ix, ix, P, false)
		line("X", w2, -ix, ix, P, false)

		local corridor = room("Corridor", { x0 = -ix, z0 = cz0, x1 = ix, z1 = cz1 }, "S")
		local fw = math.min(18, 2 * ix * 0.3)
		local left = split(-ix, -fw / 2 - P, 12, 22)
		local right = split(fw / 2 + P, ix, 12, 22)
		local front: { { number } } = {}
		for _, s in left do
			table.insert(front, s)
		end
		table.insert(front, { -fw / 2, fw / 2 })
		for _, s in right do
			table.insert(front, s)
		end
		partitions(front, -iz, w1 - P / 2)
		local back = split(-ix, ix, 14, 24)
		partitions(back, w2 + P / 2, iz)

		local slots: { { seg: { number }, row: string } } = {}
		for _, seg in front do
			if seg[1] == -fw / 2 then
				frontRoom = room(def.front, { x0 = seg[1], z0 = -iz, x1 = seg[2], z1 = w1 - P / 2 }, "S")
				door(frontRoom, "S", 0, B.FrontDoorWidth, nil, true)
				door(frontRoom, "N", 0, B.CorridorWidth, corridor)
			else
				table.insert(slots, { seg = seg, row = "front" })
			end
		end
		for _, seg in back do
			table.insert(slots, { seg = seg, row = "back" })
		end
		rng:shuffle(slots)
		for _, slot in slots do
			local seg = slot.seg
			local mid = (seg[1] + seg[2]) / 2
			local r: Room
			if slot.row == "front" then
				r = room(nextKind(), { x0 = seg[1], z0 = -iz, x1 = seg[2], z1 = w1 - P / 2 }, "N")
				door(r, "N", mid, B.DoorWidth, corridor)
			else
				r = room(nextKind(), { x0 = seg[1], z0 = w2 + P / 2, x1 = seg[2], z1 = iz }, "S")
				door(r, "S", mid, B.DoorWidth, corridor)
			end
		end
		-- the corridor runs out at both ends
		door(corridor, "W", (cz0 + cz1) / 2, B.DoorWidth, nil)
		door(corridor, "E", (cz0 + cz1) / 2, B.DoorWidth, nil)
	elseif def.layout == "Hall" then
		local strip = math.min(12, 2 * iz * 0.32)
		local wz = iz - strip - P / 2
		line("X", wz, -ix, ix, P, false)
		frontRoom = room(def.front, { x0 = -ix, z0 = -iz, x1 = ix, z1 = wz - P / 2 }, "S")
		door(frontRoom, "S", 0, B.FrontDoorWidth, nil, true)
		local hz = (-iz + wz - P / 2) / 2
		door(frontRoom, "W", hz, B.DoorWidth, nil)
		door(frontRoom, "E", hz, B.DoorWidth, nil)
		local segments = split(-ix, ix, 10, 16)
		partitions(segments, wz + P / 2, iz)
		for _, seg in segments do
			local r = room(nextKind(), { x0 = seg[1], z0 = wz + P / 2, x1 = seg[2], z1 = iz }, "S")
			door(r, "S", (seg[1] + seg[2]) / 2, B.DoorWidth, frontRoom)
		end
	else
		-- Row: the front room in the middle, the others either side, all opening into each other
		local fw = 2 * ix * 0.42
		local segments =
			{ { -ix, -fw / 2 - P / 2 }, { -fw / 2 + P / 2, fw / 2 - P / 2 }, { fw / 2 + P / 2, ix } }
		partitions(segments, -iz, iz)
		local leftRoom =
			room(nextKind(), { x0 = segments[1][1], z0 = -iz, x1 = segments[1][2], z1 = iz }, "E")
		frontRoom = room(def.front, { x0 = segments[2][1], z0 = -iz, x1 = segments[2][2], z1 = iz }, "S")
		local rightRoom =
			room(nextKind(), { x0 = segments[3][1], z0 = -iz, x1 = segments[3][2], z1 = iz }, "W")
		door(frontRoom, "S", 0, B.FrontDoorWidth, nil, true)
		door(frontRoom, "N", 0, B.DoorWidth, nil)
		door(leftRoom, "E", 0, B.DoorWidth, frontRoom)
		door(rightRoom, "W", 0, B.DoorWidth, frontRoom)
	end

	-- locks: a room's own door, never the way in or a corridor's exit
	for _, r in rooms do
		local roomDef = B.Rooms[r.kind]
		if roomDef and roomDef.locked and r ~= frontRoom and rng:chance(roomDef.locked) then
			for _, d in doors do
				if d.room == r.id and not d.exterior then
					d.locked = true
					r.locked = true
					break
				end
			end
		end
	end

	-- windows along each room's exterior walls
	for _, r in rooms do
		if r.kind ~= "Corridor" then
			local rect = r.rect
			local sides: { { side: string, axis: string, fixed: number, a: number, b: number, outward: number } } =
				{}
			if rect.z0 <= -iz + 0.01 then
				table.insert(
					sides,
					{ side = "S", axis = "X", fixed = -oz + T / 2, a = rect.x0, b = rect.x1, outward = -1 }
				)
			end
			if rect.z1 >= iz - 0.01 then
				table.insert(
					sides,
					{ side = "N", axis = "X", fixed = oz - T / 2, a = rect.x0, b = rect.x1, outward = 1 }
				)
			end
			if rect.x0 <= -ix + 0.01 then
				table.insert(
					sides,
					{ side = "W", axis = "Z", fixed = -ox + T / 2, a = rect.z0, b = rect.z1, outward = -1 }
				)
			end
			if rect.x1 >= ix - 0.01 then
				table.insert(
					sides,
					{ side = "E", axis = "Z", fixed = ox - T / 2, a = rect.z0, b = rect.z1, outward = 1 }
				)
			end
			for _, s in sides do
				local length = s.b - s.a
				local count = math.floor(length / B.WindowEvery)
				for i = 1, count do
					local at = s.a + length * (i - 0.5) / count
					local blocked = false
					for _, d in r.doors do
						if
							d.side == s.side
							and math.abs(d.at - at) < d.width / 2 + B.WindowWidth / 2 + 1.2
						then
							blocked = true
						end
					end
					if not blocked and cut(s.axis, s.fixed, at, B.WindowWidth, B.WindowSill, B.WindowTop) then
						local roll = rng:next()
						table.insert(windows, {
							x = if s.axis == "X" then at else s.fixed,
							z = if s.axis == "X" then s.fixed else at,
							axis = s.axis,
							width = B.WindowWidth,
							outward = s.outward,
							glass = if roll < 0.35 then "Boarded" elseif roll < 0.6 then "Broken" else "Glass",
						})
					end
				end
			end
		end
	end

	-- walls, split around their openings
	local walls: { WallPiece } = {}
	for _, l in lines do
		table.sort(l.openings, function(p, q)
			return p.at < q.at
		end)
		local function piece(a: number, b: number, y0: number, y1: number)
			if b - a > 0.05 and y1 - y0 > 0.05 then
				table.insert(walls, {
					axis = l.axis,
					fixed = l.fixed,
					a = a,
					b = b,
					y0 = y0,
					y1 = y1,
					thick = l.thick,
					exterior = l.exterior,
				})
			end
		end
		local at = l.a
		for _, o in l.openings do
			local a, b = o.at - o.width / 2, o.at + o.width / 2
			piece(at, a, 0, H)
			piece(a, b, 0, o.y0)
			piece(a, b, o.y1, H)
			at = b
		end
		piece(at, l.b, 0, H)
	end

	-- furniture, containers, lamps and sleepers -----------------------------------------
	local items: { Item } = {}
	local lamps: { Lamp } = {}
	local sleepers: { Spot } = {}
	local fuse = { x = 0, z = 0, rot = 180 }

	for _, r in rooms do
		local rect = r.rect
		local occupied: { Rect } = {}
		for _, d in r.doors do
			local w = d.width / 2 + 1
			local c = B.DoorClearance
			if d.side == "S" then
				table.insert(occupied, { x0 = d.at - w, z0 = rect.z0, x1 = d.at + w, z1 = rect.z0 + c })
			elseif d.side == "N" then
				table.insert(occupied, { x0 = d.at - w, z0 = rect.z1 - c, x1 = d.at + w, z1 = rect.z1 })
			elseif d.side == "W" then
				table.insert(occupied, { x0 = rect.x0, z0 = d.at - w, x1 = rect.x0 + c, z1 = d.at + w })
			else
				table.insert(occupied, { x0 = rect.x1 - c, z0 = d.at - w, x1 = rect.x1, z1 = d.at + w })
			end
		end
		local function fits(box: Rect): boolean
			if
				box.x0 < rect.x0 + 0.1
				or box.x1 > rect.x1 - 0.1
				or box.z0 < rect.z0 + 0.1
				or box.z1 > rect.z1 - 0.1
			then
				return false
			end
			for _, other in occupied do
				if overlaps(box, other, 0.4) then
					return false
				end
			end
			return true
		end
		local function put(itemKind: string, x: number, z: number, rot: number, container: string?): boolean
			local box = footprint(itemKind, x, z, rot)
			if not fits(box) then
				return false
			end
			table.insert(occupied, box)
			table.insert(
				items,
				{ kind = itemKind, x = x, z = z, rot = rot, room = r.id, container = container }
			)
			return true
		end

		if r == frontRoom then
			-- the fuse box, on the front wall beside the door
			local front = r.doors[1]
			local side = if rng:chance(0.5) then 1 else -1
			local x = front.at + side * (front.width / 2 + 2.2)
			fuse = { x = x, z = rect.z0 + 0.35, rot = 180 }
			table.insert(occupied, { x0 = x - 1.2, z0 = rect.z0, x1 = x + 1.2, z1 = rect.z0 + 2 })
		end

		local placements: { Buildings.Placement } = if r.kind == "Corridor"
			then (def.corridor or {})
			else B.Rooms[r.kind].place
		local far = OPPOSITE[r.doorSide]
		for _, placement in placements do
			local f = B.Furniture[placement.item]
			local gap = placement.gap or 1
			local placed: { number } = {}
			local function wants(): string?
				if placement.container == nil then
					return nil
				end
				if placement.share == nil or rng:chance(placement.share) then
					return placement.container
				end
				return nil
			end
			local limit = placement.count or math.huge

			if placement.pattern == "wall" then
				local sides: { string }
				local which = placement.wall or "any"
				if which == "far" then
					sides = { far }
				elseif which == "near" then
					sides = { r.doorSide }
				elseif which == "sides" then
					sides = SIDES_OF[r.doorSide]
				elseif which == "long" then
					sides = if rect.x1 - rect.x0 >= rect.z1 - rect.z0 then { "N", "S" } else { "E", "W" }
				else
					sides = { far, SIDES_OF[r.doorSide][1], SIDES_OF[r.doorSide][2], r.doorSide }
				end
				for _, side in sides do
					if #placed >= limit then
						break
					end
					local along = if side == "N" or side == "S" then rect.x1 - rect.x0 else rect.z1 - rect.z0
					local mid = if side == "N" or side == "S"
						then (rect.x0 + rect.x1) / 2
						else (rect.z0 + rect.z1) / 2
					local n = math.floor((along - 1 + gap) / (f.w + gap))
					n = math.min(n, limit - #placed)
					local run = n * (f.w + gap) - gap
					for i = 1, n do
						local at = mid - run / 2 + f.w / 2 + (i - 1) * (f.w + gap)
						local x, z
						if side == "N" then
							x, z = at, rect.z1 - f.d / 2 - 0.15
						elseif side == "S" then
							x, z = at, rect.z0 + f.d / 2 + 0.15
						elseif side == "E" then
							x, z = rect.x1 - f.d / 2 - 0.15, at
						else
							x, z = rect.x0 + f.d / 2 + 0.15, at
						end
						if put(placement.item, x, z, FACE_ROT[side], nil) then
							table.insert(placed, #items)
						end
					end
				end
			elseif placement.pattern == "grid" then
				local rot = TOWARD_ROT[far]
				local box = { x0 = rect.x0 + 2, z0 = rect.z0 + 2, x1 = rect.x1 - 2, z1 = rect.z1 - 2 }
				-- leave the far wall clear for a desk, an altar, a board
				if far == "N" then
					box.z1 -= 6
				elseif far == "S" then
					box.z0 += 6
				elseif far == "E" then
					box.x1 -= 6
				else
					box.x0 += 6
				end
				local turned = rot % 180 ~= 0
				local cw = (if turned then f.d else f.w) + gap
				local cd = (if turned then f.w else f.d) + gap
				local cols = math.floor((box.x1 - box.x0 + gap) / cw)
				local rows = math.floor((box.z1 - box.z0 + gap) / cd)
				local x0 = (box.x0 + box.x1) / 2 - (cols * cw - gap) / 2 + (cw - gap) / 2
				local z0 = (box.z0 + box.z1) / 2 - (rows * cd - gap) / 2 + (cd - gap) / 2
				for c = 0, cols - 1 do
					for k = 0, rows - 1 do
						if #placed < limit and put(placement.item, x0 + c * cw, z0 + k * cd, rot, nil) then
							table.insert(placed, #items)
						end
					end
				end
			elseif placement.pattern == "center" then
				local rot = if rect.x1 - rect.x0 >= rect.z1 - rect.z0 then 0 else 90
				if put(placement.item, (rect.x0 + rect.x1) / 2, (rect.z0 + rect.z1) / 2, rot, nil) then
					table.insert(placed, #items)
				end
			elseif placement.pattern == "corner" then
				local corners = {
					{ side = "N", x = rect.x0 + f.w / 2 + 0.3, z = rect.z1 - f.d / 2 - 0.15 },
					{ side = "N", x = rect.x1 - f.w / 2 - 0.3, z = rect.z1 - f.d / 2 - 0.15 },
					{ side = "S", x = rect.x0 + f.w / 2 + 0.3, z = rect.z0 + f.d / 2 + 0.15 },
					{ side = "S", x = rect.x1 - f.w / 2 - 0.3, z = rect.z0 + f.d / 2 + 0.15 },
				}
				rng:shuffle(corners)
				for _, corner in corners do
					if
						#placed == 0 and put(placement.item, corner.x, corner.z, FACE_ROT[corner.side], nil)
					then
						table.insert(placed, #items)
					end
				end
			end

			-- which of them can be searched (at least one, when any are meant to be)
			if placement.container then
				local any = false
				for _, index in placed do
					local container = wants()
					items[index].container = container
					any = any or container ~= nil
				end
				if not any and #placed > 0 then
					items[placed[#placed]].container = placement.container
				end
			end
		end

		-- the lamp, and maybe something asleep in the dark
		local roomDef = B.Rooms[r.kind]
		if r.kind == "Corridor" then
			local length = rect.x1 - rect.x0
			local n = math.max(1, math.floor(length / 16))
			for i = 1, n do
				table.insert(lamps, {
					x = rect.x0 + length * (i - 0.5) / n,
					z = (rect.z0 + rect.z1) / 2,
					room = r.id,
					works = rng:chance(0.35),
				})
			end
		else
			table.insert(lamps, {
				x = (rect.x0 + rect.x1) / 2,
				z = (rect.z0 + rect.z1) / 2,
				room = r.id,
				works = rng:chance(roomDef.lamp),
			})
		end
		if roomDef and rng:chance(roomDef.sleeper) then
			for _ = 1, 12 do
				local x = rng:range(rect.x0 + 2, rect.x1 - 2)
				local z = rng:range(rect.z0 + 2, rect.z1 - 2)
				local box = { x0 = x - 1.5, z0 = z - 1.5, x1 = x + 1.5, z1 = z + 1.5 }
				if fits(box) then
					table.insert(occupied, box)
					local d = r.doors[1]
					local dx, dz = 0, 0
					if d then
						if d.side == "N" or d.side == "S" then
							dx, dz = d.at - x, (if d.side == "N" then rect.z1 else rect.z0) - z
						else
							dx, dz = (if d.side == "E" then rect.x1 else rect.x0) - x, d.at - z
						end
					end
					-- rot turns -Z (an item's front) toward the door
					local rot = math.deg(math.atan2(-dx, -dz))
					local sleeperKind = roomDef.sleeperKind
						or (if rng:chance(0.25) then "Crawler" else "Stalker")
					table.insert(sleepers, { x = x, z = z, rot = rot, kind = sleeperKind, room = r.id })
					break
				end
			end
		end
	end

	return {
		kind = kind,
		width = width,
		depth = depth,
		outerX = ox,
		outerZ = oz,
		height = H,
		rooms = rooms,
		walls = walls,
		doors = doors,
		windows = windows,
		items = items,
		lamps = lamps,
		sleepers = sleepers,
		fuse = fuse,
		exits = exits,
	}
end

-- The room containing a building-local point, if any.
function BuildingGen.roomAt(plan: Plan, x: number, z: number): Room?
	for _, r in plan.rooms do
		local rect = r.rect
		if x >= rect.x0 and x <= rect.x1 and z >= rect.z0 and z <= rect.z1 then
			return r
		end
	end
	return nil
end

-- Building tiles an archetype's landmarks cover (bigger stops last longer and hold more).
function BuildingGen.tiles(landmarks: { Stations.LandmarkRule }?): number
	if landmarks == nil then
		return 0
	end
	local total = 0
	for _, landmark in landmarks do
		local def = B.Defs[landmark.kind]
		if def then
			total += def.size[1] * def.size[2]
		end
	end
	return total
end

return table.freeze(BuildingGen)
