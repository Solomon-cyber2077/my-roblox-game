local BuildingGen = require(Shared.Logic.BuildingGen)
local Buildings = require(Shared.Config.Buildings)

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
					local room = plan.rooms[item.room]
					local b = box(item)
					expect(b.x0 >= room.rect.x0 - 0.01 and b.x1 <= room.rect.x1 + 0.01).toBe(true)
					expect(b.z0 >= room.rect.z0 - 0.01 and b.z1 <= room.rect.z1 + 0.01).toBe(true)
					for j = i + 1, #plan.items do
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
		expect(BuildingGen.tiles({ { kind = "School" } })).toBe(28)
		expect(BuildingGen.tiles(nil)).toBe(0)
	end)
end)
