local Config = require(Shared.Config.LobbyTiles)
local LobbyTiles = require(Shared.Logic.LobbyTiles)

local function with(look: string, uploaded: boolean, image: string?)
	local c = table.clone(Config) :: any
	c.Look = look
	c.Variants = {}
	for k, v in Config.Variants do
		local copy = table.clone(v) :: any
		copy.uploaded = uploaded
		c.Variants[k] = copy
	end
	c.Path = table.clone(Config.Path) :: any
	c.Path.image = image
	return c
end

local QUARRY = { 84, 38, 34 }

describe("Hall tiles (Logic/LobbyTiles)", function()
	it("keeps today's hall until every map is uploaded", function()
		expect(LobbyTiles.look(with("painted", false, nil))).toBe("today")
		expect(LobbyTiles.look(with("painted", true, nil))).toBe("today")
		local pick = LobbyTiles.pick("quarry", "CeramicTiles", QUARRY, with("painted", false, nil))
		expect(pick.material).toBe("CeramicTiles")
		expect(pick.variant).toBe(nil)
		expect(pick.color[1]).toBe(84)
	end)

	it("ships with the built-in look, which needs no upload", function()
		expect(LobbyTiles.look()).toBe("builtin")
		expect(LobbyTiles.pick("quarry", "CeramicTiles", QUARRY).material).toBe("Slate")
		expect(LobbyTiles.pick("dado", "CeramicTiles", QUARRY).material).toBe("Brick")
	end)

	it("lays the painted variant on its tile base, tinted back to the old average", function()
		local c = with("painted", true, "rbxassetid://1")
		local pick = LobbyTiles.pick("quarry", "CeramicTiles", QUARRY, c)
		expect(pick.material).toBe("CeramicTiles")
		expect(pick.variant).toBe("LobbyQuarry")
		local mean = Config.Variants.quarry.mean
		for i = 1, 3 do
			expect(pick.color[i] * mean[i] / 255).toBeCloseTo(QUARRY[i], 0.6)
			expect(pick.color[i]).toBeBetween(1, 254)
		end
	end)

	it("swaps to a built-in material for the no-upload fallback", function()
		local c = with("builtin", false, nil)
		expect(LobbyTiles.pick("quarry", "CeramicTiles", QUARRY, c).material).toBe("Slate")
		expect(LobbyTiles.pick("dado", "CeramicTiles", QUARRY, c).material).toBe("Brick")
		expect(LobbyTiles.pick("dado", "CeramicTiles", QUARRY, c).variant).toBe(nil)
	end)

	it("leaves an unknown surface alone", function()
		local pick = LobbyTiles.pick("nope", "Slate", QUARRY, with("builtin", true, "x"))
		expect(pick.material).toBe("Slate")
	end)
end)
