local Passengers = require(Shared.Config.Passengers)

local LIMBS = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

describe("Passenger clothing (Config/Passengers Wear)", function()
	it("gives every passenger a wear entry, skirts only to the skirted", function()
		for _, person in Passengers.People do
			local wear = Passengers.Wear[person.id]
			expect(wear ~= nil).toBe(true)
			local skirts, props = 0, 0
			for _, piece in wear.pieces do
				skirts += if piece.name == "Skirt" then 1 else 0
				props += if piece.prop then 1 else 0
			end
			expect(skirts).toBe(if person.look.skirt then 1 else 0)
			expect(props <= 1).toBe(true)
			expect(props == 0 or person.look.prop ~= nil).toBe(true)
		end
	end)

	it("places every piece on a body limb with a real size, turned round for the import", function()
		for _, wear in Passengers.Wear do
			for _, piece in wear.pieces do
				expect(LIMBS[piece.limb] == true).toBe(true)
				expect(#piece.offset).toBe(3)
				expect(#piece.size).toBe(3)
				for _, v in piece.size do
					expect(v > 0 and v < 4).toBe(true)
				end
				expect(piece.yaw).toBe(180)
			end
		end
	end)

	it("dresses a person in sheets only once every id is bound", function()
		for id, wear in Passengers.Wear do
			local bound = wear.shirt ~= nil and wear.pants ~= nil
			for _, piece in wear.pieces do
				bound = bound and piece.mesh ~= nil and piece.texture ~= nil
			end
			expect(Passengers.wearReady(id)).toBe(bound)
		end
		expect(Passengers.wearReady("Nobody")).toBe(false)
	end)
end)
