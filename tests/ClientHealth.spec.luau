local ClientHealth = require(Shared.Logic.ClientHealth)

describe("ClientHealth", function()
	it("averages a window and keeps its worst whole second", function()
		local sampler = ClientHealth.new()
		for _ = 1, 600 do
			ClientHealth.frame(sampler, 1 / 60)
		end
		for _ = 1, 20 do
			ClientHealth.frame(sampler, 0.1)
		end
		local average, lowest = ClientHealth.take(sampler, 10)
		expect(math.round(average :: number)).toBe(52)
		expect(math.round(lowest :: number)).toBe(10)
	end)

	it("reports nothing for a short window, and keeps counting it", function()
		local sampler = ClientHealth.new()
		for _ = 1, 60 do
			ClientHealth.frame(sampler, 1 / 60)
		end
		expect((ClientHealth.take(sampler, 10))).toBe(nil)
		expect(sampler.frames).toBe(60)
	end)

	it("starts clean after a take or a reset", function()
		local sampler = ClientHealth.new()
		for _ = 1, 700 do
			ClientHealth.frame(sampler, 1 / 60)
		end
		expect((ClientHealth.take(sampler, 10)) ~= nil).toBe(true)
		expect(sampler.seconds).toBe(0)
		ClientHealth.frame(sampler, 2)
		ClientHealth.reset(sampler)
		expect(sampler.lowest).toBe(nil)
	end)

	it("falls back to the average before a whole second has passed", function()
		local sampler = ClientHealth.new()
		ClientHealth.frame(sampler, 0.5)
		local average, lowest = ClientHealth.take(sampler, 0.1)
		expect(average).toBe(lowest)
	end)
end)
