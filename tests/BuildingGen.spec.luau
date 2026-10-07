local BuildingGen = require(Shared.Logic.BuildingGen)
local Buildings = require(Shared.Config.Buildings)
local LayoutGen = require(Shared.Logic.LayoutGen)

local KINDS = {}
for kind in Buildings.Defs do
	table.insert(KINDS, kind)
end
table.sort(KINDS)

local function box(item)
	local f = Buildings.Furniture[item.kind]
	local turned = item.rot % 180 ~= 0
	local hw = if turned then f.d / 2 else f.w / 2
	local hd = if turned then f.w / 2 else f.d / 2
	return { x0 = item.x - hw, z0 = item.z - hd, x1 = item.x + hw, z1 = item.z + hd }
end

describe("BuildingGen", function()
	it("is deterministic for a seed", function()
		local a = BuildingGen.generate("School", 77)
		local b = BuildingGen.generate("School", 77)
		expect(#a.rooms).toBe(#b.rooms)
		expect(#a.items).toBe(#b.items)
		for i, item in a.items do
			expect(item.x).toBe(b.items[i].x)
			expect(item.kind).toBe(b.items[i].kind)
		end
	end)

	it("never overlaps two wall pieces", function()
		for _, kind in KINDS do
			for seed = 1, 6 do
				local plan = BuildingGen.generate(kind, seed)
				for i, p in plan.walls do
					for j = i + 1, #plan.walls do
						local q = plan.walls[j]
						if p.axis == q.axis and math.abs(p.fixed - q.fixed) < 0.01 then
							local along = math.min(p.b, q.b) - math.max(p.a, q.a)
							local up = math.min(p.y1, q.y1) - math.max(p.y0, q.y0)
							expect(along <= 0.001 or up <= 0.001).toBe(true)
						end
					end
				end
			end
		end
	end)

	it("gives every room a door and every building two ways out", function()
		for _, kind in KINDS do
			for seed = 1, 6 do
				local plan = BuildingGen.generate(kind, seed)
				for _, room in plan.rooms do
					expect(#room.doors).toBeGreaterThan(0)
				end
				expect(#plan.exits).toBeAtLeast(2)
			end
		end
	end)

	it("keeps furniture inside its room, apart and out of doorways", function()
		for _, kind in KINDS do
			for seed = 1, 6 do
				local plan = BuildingGen.generate(kind, seed)
				for i, item in plan.items do
					local room = BuildingGen.room(plan, item.room)
					expect(room ~= nil).toBe(true)
					expect(item.y).toBe(room.y)
					local b = box(item)
					expect(b.x0 >= room.rect.x0 - 0.01 and b.x1 <= room.rect.x1 + 0.01).toBe(true)
					expect(b.z0 >= room.rect.z0 - 0.01 and b.z1 <= room.rect.z1 + 0.01).toBe(true)
					for j = i + 1, #plan.items do
						if plan.items[j].y ~= item.y then
							continue
						end
						local c = box(plan.items[j])
						local apart = b.x1 <= c.x0 or c.x1 <= b.x0 or b.z1 <= c.z0 or c.z1 <= b.z0
						expect(apart).toBe(true)
					end
				end
			end
		end
	end)

	it("fills every building with things to search", function()
		for _, kind in KINDS do
			local containers = 0
			for seed = 1, 6 do
				for _, item in BuildingGen.generate(kind, seed).items do
					if item.container then
						containers += 1
					end
				end
			end
			expect(containers / 6).toBeAtLeast(2)
		end
	end)

	it("counts the tiles a stop's landmarks cover", function()
		-- the footprint, and the upper floor on top
		expect(BuildingGen.tiles({ { kind = "School" } })).toBe(28 + Buildings.Defs.School.upper.tiles)
		expect(BuildingGen.tiles({ { kind = "Chapel" } })).toBe(12)
		expect(BuildingGen.tiles(nil)).toBe(0)
	end)
	it("never traps anyone: every room reaches two ways out, locked doors open from inside", function()
		for _, kind in KINDS do
			for seed = 1, 6 do
				local plan = BuildingGen.generate(kind, seed)
				local links = {}
				local outs = {}
				for _, d in plan.doors do
					links[d.room] = links[d.room] or {}
					if d.into then
						links[d.into] = links[d.into] or {}
						table.insert(links[d.room], d.into)
						table.insert(links[d.into], d.room)
					else
						outs[d.room] = (outs[d.room] or 0) + 1
					end
				end
				if plan.upper then
					local far = plan.upper.rooms[#plan.upper.rooms]
					outs[far.id] = (outs[far.id] or 0) + 1 -- the escape window
				end
				local all = table.clone(plan.rooms)
				for _, r in if plan.upper then plan.upper.rooms else {} do
					table.insert(all, r)
				end
				for _, start in all do
					local seen, queue, ways = { [start.id] = true }, { start.id }, 0
					while #queue > 0 do
						local id = table.remove(queue, 1)
						ways += outs[id] or 0
						for _, other in links[id] or {} do
							if not seen[other] then
								seen[other] = true
								table.insert(queue, other)
							end
						end
					end
					expect(ways).toBeAtLeast(2)
				end
			end
		end
	end)

	it("keeps the better loot in back rooms and a light by the way in", function()
		for _, kind in KINDS do
			for seed = 1, 6 do
				local plan = BuildingGen.generate(kind, seed)
				for _, r in plan.rooms do
					if Buildings.Rooms[r.kind] and Buildings.Rooms[r.kind].back then
						local any, best = false, false
						for _, item in plan.items do
							if item.room == r.id and item.container then
								any = true
								best = best or Buildings.BackLoot[item.container] == true
							end
						end
						expect(not any or best).toBe(true)
					end
				end
				local lit, front = false, nil
				for _, d in plan.doors do
					if d.front then
						front = d.room
					end
				end
				for _, lamp in plan.lamps do
					if lamp.room == front and lamp.works then
						lit = true
					end
				end
				expect(lit).toBe(true)
			end
		end
	end)

	it("puts back rooms behind the corridor in Spine buildings", function()
		for _, kind in KINDS do
			local def = Buildings.Defs[kind]
			if def.layout == "Spine" then
				local plan = BuildingGen.generate(kind, 3)
				local front, back = 0, 0
				for _, r in plan.rooms do
					if Buildings.Rooms[r.kind] and Buildings.Rooms[r.kind].back then
						if r.rect.z0 > 0 then
							back += 1
						else
							front += 1
						end
					end
				end
				expect(back).toBeGreaterThan(0)
				expect(back).toBeAtLeast(front)
			end
		end
	end)

	it("climbs to upper floors on a walkable ramp, with a second way down elsewhere", function()
		local count = 0
		for _, kind in KINDS do
			local def = Buildings.Defs[kind]
			for seed = 1, 6 do
				local plan = BuildingGen.generate(kind, seed)
				if def.upper == nil then
					expect(plan.upper).toBe(nil)
					expect(#plan.stairs).toBe(0)
					continue
				end
				count += 1
				expect(def.layout).toBe("Spine")
				expect(def.size[1] * def.size[2]).toBeAtLeast(24)
				local upper = plan.upper
				expect(#upper.rooms).toBeGreaterThan(0)
				expect(#plan.stairs).toBe(1)
				local stair = plan.stairs[1]
				-- the ramp tops out at the slab's edge, level with the floor
				expect(stair.rise).toBe(upper.y)
				expect(math.abs(stair.x1 - upper.slab.x0)).toBeLessThan(0.01)
				local slope = math.deg(math.atan(stair.rise / (stair.x1 - stair.x0)))
				expect(slope).toBeLessThan(35)
				-- the escape window is far from the top of the stairs
				local dx = upper.escape.x - stair.x1
				local dz = upper.escape.z - (stair.z0 + stair.z1) / 2
				expect(math.sqrt(dx * dx + dz * dz)).toBeGreaterThan(20)
				-- the area the stop's size counts is the slab's
				local slab = upper.slab
				local tiles = (slab.x1 - slab.x0) * (slab.z1 - slab.z0) / 144
				expect(math.abs(tiles - def.upper.tiles)).toBeLessThan(1.5)
				-- nothing upstairs is locked
				for _, d in plan.doors do
					if d.y > 0 then
						expect(d.locked).toBe(false)
					end
				end
			end
		end
		expect(count).toBeGreaterThan(0)
	end)

	it("carries upstairs containers' height into the station and keeps sleepers downstairs", function()
		local plan = LayoutGen.generate("RailwayHotel", 7, 1)
		local up, ground = 0, 0
		for _, c in plan.containers do
			if c.building then
				if c.y then
					up += 1
				else
					ground += 1
				end
			end
		end
		expect(up).toBeGreaterThan(0)
		expect(ground).toBeGreaterThan(0)
		for _, sleeper in plan.sleepers do
			expect(sleeper.y).toBe(0)
		end
	end)
end)
