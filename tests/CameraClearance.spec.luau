local CameraClearance = require(Shared.Logic.CameraClearance)

local function query(overrides: { [string]: any })
	local q = {
		desired = 11,
		minDistance = 2,
		hitDistance = nil,
		overlap = false,
		sweepBlocked = false,
		previous = nil,
		maxOut = 1,
	}
	for key, value in overrides do
		q[key] = value
	end
	return CameraClearance.resolve(q :: any)
end

describe("CameraClearance", function()
	it("holds every near-plane corner in the probe, portrait and landscape", function()
		for _, aspect in { 0.46, 1, 2.17 } do
			local near = 0.5
			local halfW, halfH = CameraClearance.nearPlane(70, aspect, near)
			local radius = CameraClearance.probeRadius(70, aspect, near, 0)
			assert(halfW and halfH and radius, "valid inputs")
			local corner = math.sqrt(halfW * halfW + halfH * halfH + near * near)
			expect(radius >= corner - 1e-9).toBe(true)
			expect(CameraClearance.probeRadius(70, aspect, near, 0.6)).toBe(radius + 0.6)
		end
		local _, narrow = CameraClearance.nearPlane(40, 1, 0.5)
		local _, wide = CameraClearance.nearPlane(90, 1, 0.5)
		expect((wide :: number) > (narrow :: number)).toBe(true)
	end)

	it("rejects invalid camera inputs", function()
		expect(CameraClearance.probeRadius(0, 1, 0.5, 0.6)).toBe(nil)
		expect(CameraClearance.probeRadius(180, 1, 0.5, 0.6)).toBe(nil)
		expect(CameraClearance.probeRadius(70, 0, 0.5, 0.6)).toBe(nil)
		expect(CameraClearance.probeRadius(70, 1, 0, 0.6)).toBe(nil)
		expect(CameraClearance.probeRadius(0 / 0, 1, 0.5, 0.6)).toBe(nil)
		expect(CameraClearance.probeRadius(70, 1, 0.5, -1)).toBe(nil)
	end)

	it("keeps the desired distance when clear", function()
		local result = query({})
		expect(result.ok).toBe(true)
		expect((result :: any).distance).toBe(11)
	end)

	it("pulls in at once to a hit", function()
		local result = query({ hitDistance = 4.5, previous = 11 })
		expect(result.ok).toBe(true)
		expect((result :: any).distance).toBe(4.5)
	end)

	it("never forces the minimum through a thin obstacle close by", function()
		local result = query({ hitDistance = 0.3 })
		expect(result.ok).toBe(false)
		expect((result :: any).reason).toBe("blocked")
		expect(query({ hitDistance = 0 }).ok).toBe(false)
	end)

	it("eases back out no faster than maxOut", function()
		local result = query({ previous = 4, maxOut = 0.25 })
		expect((result :: any).distance).toBe(4.25)
		local capped = query({ previous = 4, maxOut = 0.25, hitDistance = 4.1 })
		expect((capped :: any).distance).toBe(4.1)
	end)

	it("is unavailable on an initial overlap or a blocked sweep", function()
		expect((query({ overlap = true }) :: any).reason).toBe("overlap")
		expect((query({ sweepBlocked = true }) :: any).reason).toBe("sweep")
	end)

	it("rejects zero-length spans and invalid numbers", function()
		expect((query({ desired = 0 }) :: any).reason).toBe("invalid")
		expect((query({ desired = 1 }) :: any).reason).toBe("too-close")
		expect((query({ desired = 0 / 0 }) :: any).reason).toBe("invalid")
		expect((query({ desired = math.huge }) :: any).reason).toBe("invalid")
		expect((query({ hitDistance = -1 }) :: any).reason).toBe("invalid")
		expect((query({ maxOut = -1 }) :: any).reason).toBe("invalid")
	end)
end)
