local Passengers = require(Shared.Config.Passengers)
local Outfits = require(Shared.Config.Outfits)

describe("Hall staff clothing (Config/Passengers Wear, Outfits Lobby)", function()
	it("dresses every counter hand, a skirt only on the skirted, and leaves the Guard on the kit", function()
		for id, who in Outfits.Lobby do
			local wear = Passengers.Wear[id]
			if id == "Guard" then
				expect(wear == nil).toBe(true)
				continue
			end
			expect(wear ~= nil).toBe(true)
			local skirts = 0
			for _, piece in wear.pieces do
				skirts += if piece.name == "Skirt" then 1 else 0
			end
			expect(skirts).toBe(if who.look.skirt then 1 else 0)
		end
	end)

	it("keeps them in the kit until their sheets are bound", function()
		for id in Outfits.Lobby do
			local wear = Passengers.Wear[id]
			local bound = wear ~= nil and wear.shirt ~= nil and wear.pants ~= nil
			if wear then
				for _, piece in wear.pieces do
					bound = bound and piece.mesh ~= nil and piece.texture ~= nil
				end
			end
			expect(Passengers.wearReady(id)).toBe(bound)
		end
	end)

	it("gives a phone mesh only to pieces that stay on under Performance (never a bag)", function()
		for _, wear in Passengers.Wear do
			for _, piece in wear.pieces do
				if piece.phone ~= nil then
					expect(piece.prop == true).toBe(false)
					expect(piece.mesh ~= nil).toBe(true)
				end
			end
		end
	end)
end)
