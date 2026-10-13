local DeathCause = require(Shared.Logic.DeathCause)

describe("DeathCause", function()
	it("names each source's death", function()
		expect(DeathCause.fromDeath("Hollow", 100, 101, false)).toBe("Taken")
		expect(DeathCause.fromDeath("Fog", 100, 101, false)).toBe("Smothered")
		expect(DeathCause.fromDeath("Fall", 100, 101, false)).toBe("Fell")
		expect(DeathCause.fromDeath("Train", 100, 101, false)).toBe("Wrecked")
	end)

	it("never blames a Hollow for a death it had no part in", function()
		expect(DeathCause.fromDeath(nil, nil, 50, false)).toBe("Other")
		expect(DeathCause.fromDeath("Mystery", 100, 101, false)).toBe("Other")
	end)

	it("lets an old wound go stale", function()
		local at = 100
		expect(DeathCause.fromDeath("Hollow", at, at + DeathCause.StaleSeconds, false)).toBe("Taken")
		expect(DeathCause.fromDeath("Hollow", at, at + DeathCause.StaleSeconds + 0.1, false)).toBe("Other")
		expect(DeathCause.fromDeath("Fog", nil, 101, false)).toBe("Other")
	end)

	it("counts a body below the fall line as fallen, whatever last hurt it", function()
		expect(DeathCause.fromDeath("Hollow", 100, 101, true)).toBe("Fell")
		expect(DeathCause.fromDeath(nil, nil, 101, true)).toBe("Fell")
	end)

	it("has its own words for every cause", function()
		local seen = {}
		for _, cause in { "LeftBehind", "Taken", "Smothered", "Fell", "Wrecked", "Disconnected", "Other" } do
			local words = DeathCause.line(cause)
			expect(words.title ~= "").toBe(true)
			expect(seen[words.line]).toBe(nil)
			seen[words.line] = true
		end
		expect(DeathCause.line("Nonsense").title).toBe(DeathCause.Lines.Other.title)
		expect(DeathCause.line(nil).title).toBe(DeathCause.Lines.Other.title)
	end)
end)
