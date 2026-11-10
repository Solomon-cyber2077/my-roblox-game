local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Signage = require(Shared.Config.Signage)

describe("Sign meshes (Builders/SignArt, Config/Signage)", function()
	it("turns every uploaded sign round so its front looks out of the wall", function()
		-- the uploads face +Z; unturned, only the back shows and the wall reads blank (Studio, 2026-11-10)
		local source = fs.readFile("src/server/Builders/SignArt.luau")
		expect(string.find(source, "local TURN = CFrame.Angles(0, math.pi, 0)", 1, true) ~= nil).toBe(true)
		expect(string.find(source, "sign.Size.Z / 2)) * TURN", 1, true) ~= nil).toBe(true)
	end)

	it("gives every sign a mesh id and a look that SignLooks carries", function()
		local looks: { [string]: boolean } = {}
		for _, child in serde.decode("json", fs.readFile("src/server/SignLooks.model.json")).children do
			looks[child.name] = child.className == "SurfaceAppearance"
		end
		for name, spec in Signage.Signs do
			expect(spec.mesh > 0).toBe(true)
			expect(looks[spec.look] == true).toBe(true)
			expect(type(name)).toBe("string")
		end
	end)
end)
