local StationKit = require(Shared.Config.StationKit)

describe("Station kit", function()
	it("sizes every piece in studs and keeps it cheap", function()
		for name, piece in StationKit.Pieces do
			expect(#piece.size).toBe(3)
			expect(#piece.centre).toBe(3)
			for _, v in piece.size do
				expect(v).toBeGreaterThan(0)
			end
			-- standing on its foot: the centre is half its height up
			expect(piece.centre[2]).toBeCloseTo(piece.size[2] / 2, 0.1)
			if piece.tris > 600 then
				error(`{name}: {piece.tris} triangles`)
			end
		end
	end)

	it("dresses each prop kind with one piece at most", function()
		local seen = {}
		for name, piece in StationKit.Pieces do
			for _, kind in piece.dresses do
				expect(seen[kind]).toBe(nil)
				seen[kind] = name
				expect(StationKit.ByProp[kind]).toBe(name)
			end
		end
	end)

	it("draws a picket fence tile in fewer triangles than its primitives", function()
		-- StationDressing's tile: 4 posts + 2 rails + 7 picket slots, 15% fallen, near-post
		-- slots empty: 12.2 blocks a tile measured (1559 over 128 tiles at Halt), 12 tris a block
		local picket = StationKit.Pieces.FencePicket
		expect(StationKit.ByProp.FencePicket).toBe("FencePicket")
		expect(picket.tris).toBeLessThan(12.2 * 12)
	end)
end)
