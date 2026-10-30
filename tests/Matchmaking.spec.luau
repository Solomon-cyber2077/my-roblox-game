local Matchmaking = require(Shared.Logic.Matchmaking)

describe("Matchmaking", function()
	it("sends a full crew at once", function()
		local crews = Matchmaking.form(
			{ { size = 2, deadline = 99 }, { size = 1, deadline = 99 }, { size = 1, deadline = 99 } },
			0,
			4
		)
		expect(#crews).toBe(1)
		expect(#crews[1]).toBe(3)
	end)

	it("holds a part crew until its earliest deadline, then sends it as it is", function()
		local entries = { { size = 1, deadline = 20 }, { size = 1, deadline = 25 } }
		expect(#Matchmaking.form(entries, 10, 4)).toBe(0)
		local crews = Matchmaking.form(entries, 20, 4)
		expect(#crews).toBe(1)
		expect(#crews[1]).toBe(2)
	end)

	it("never sends one player alone and never splits a party", function()
		expect(#Matchmaking.form({ { size = 1, deadline = 0 } }, 100, 4)).toBe(0)
		-- a party of 3 cannot join a crew that already has 2: each leaves as its own crew, unsplit
		local crews = Matchmaking.form({ { size = 2, deadline = 0 }, { size = 3, deadline = 0 } }, 1, 4)
		expect(#crews).toBe(2)
		expect(crews[1][1]).toBe(1)
		expect(#crews[1]).toBe(1)
		expect(crews[2][1]).toBe(2)
		expect(#crews[2]).toBe(1)
	end)

	it("forms several crews from a long queue, oldest first", function()
		local entries = {}
		for _ = 1, 9 do
			table.insert(entries, { size = 1, deadline = 0 })
		end
		local crews = Matchmaking.form(entries, 1, 4)
		expect(#crews).toBe(2)
		expect(crews[1][1]).toBe(1)
		expect(#crews[1] + #crews[2]).toBe(8)
	end)
end)
