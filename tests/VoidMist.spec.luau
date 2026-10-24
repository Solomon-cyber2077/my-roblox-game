local Tuning = require(Shared.Config.Tuning)
local VoidMist = require(Shared.Logic.VoidMist)

local V = Tuning.VoidMist

-- A rail at (10, 20), 8 wide, facing the train at the given yaw (degrees; 0 faces -Z).
local function rail(yaw: number)
	local a = math.rad(yaw)
	return VoidMist.zone(10, 20, -math.sin(a), -math.cos(a), 8)
end

-- The point `back` studs from the rail toward the train and `along` studs along it.
local function at(zone, back: number, along: number): (number, number)
	return zone.x - zone.ox * back + -zone.oz * along, zone.z - zone.oz * back + zone.ox * along
end

describe("Void mist zones", function()
	it("reads depth 1 at the rail, 0.5 midway and 0 at the inner face at any rail yaw", function()
		for _, yaw in { 0, 45, 90, 180, 233 } do
			local zone = rail(yaw)
			for _, case in { { 0, 1 }, { V.BufferDepth / 2, 0.5 }, { V.BufferDepth, 0 } } do
				local x, z = at(zone, case[1], 1.5)
				expect(VoidMist.isInside(zone, x, z)).toBe(true)
				expect(VoidMist.depth01(zone, x, z)).toBeCloseTo(case[2])
			end
		end
	end)

	it("faces outward away from the train", function()
		local zone = rail(0)
		expect(zone.ox).toBeCloseTo(0)
		expect(zone.oz).toBeCloseTo(1)
	end)

	it("leaves out points past the rail, behind the strip and beyond its ends", function()
		for _, yaw in { 0, 90, 200 } do
			local zone = rail(yaw)
			for _, p in { { -0.5, 0 }, { V.BufferDepth + 0.5, 0 }, { 2, 4.5 }, { 2, -4.5 } } do
				local x, z = at(zone, p[1], p[2])
				expect(VoidMist.isInside(zone, x, z)).toBe(false)
			end
			local x, z = at(zone, V.BufferDepth + 3, 4 + 4)
			expect(VoidMist.distanceTo(zone, x, z)).toBeCloseTo(5)
			expect(VoidMist.distanceTo(zone, at(zone, 2, 0))).toBe(0)
		end
	end)

	it("fades proximity from 1 at the zone to 0 at the range", function()
		expect(VoidMist.proximity(0)).toBe(1)
		expect(VoidMist.proximity(V.ProximityRange / 2)).toBeCloseTo(0.5)
		expect(VoidMist.proximity(V.ProximityRange * 2)).toBe(0)
	end)
end)

describe("Void mist current", function()
	it("caps outward speed from CurrentMaxOut at the inner face to 0 at the rail", function()
		expect(VoidMist.outwardCap(0)).toBe(V.CurrentMaxOut)
		expect(VoidMist.outwardCap(1)).toBe(0)
		expect(VoidMist.outwardCap(0.5)).toBeCloseTo(V.CurrentMaxOut / 2)
	end)

	it("takes away only the excess outward speed, never sideways or inward motion", function()
		for _, yaw in { 0, 45, 90, 180 } do
			local zone = rail(yaw)
			local sx, sz = -zone.oz, zone.ox -- along the rail
			-- 20 out + 5 sideways, cap 6: 6 out + 5 sideways
			local vx, vz = VoidMist.clampOutward(zone.ox * 20 + sx * 5, zone.oz * 20 + sz * 5, zone, 6)
			expect(vx * zone.ox + vz * zone.oz).toBeCloseTo(6)
			expect(vx * sx + vz * sz).toBeCloseTo(5)
			-- inward and slow outward motion pass untouched
			local ix, iz = VoidMist.clampOutward(-zone.ox * 16, -zone.oz * 16, zone, 0)
			expect(ix).toBeCloseTo(-zone.ox * 16)
			expect(iz).toBeCloseTo(-zone.oz * 16)
			local ox, oz = VoidMist.clampOutward(zone.ox * 3, zone.oz * 3, zone, 6)
			expect(ox).toBeCloseTo(zone.ox * 3)
			expect(oz).toBeCloseTo(zone.oz * 3)
		end
	end)
end)

describe("Void mist presets", function()
	it("falls back to the default preset", function()
		expect((VoidMist.preset("Slate"))).toBe("Slate")
		expect((VoidMist.preset("Nope"))).toBe(V.DefaultPreset)
		expect((VoidMist.preset(nil))).toBe(V.DefaultPreset)
		local _, teal = VoidMist.preset("Teal")
		expect(teal.mist[1]).toBe(58)
	end)
end)
