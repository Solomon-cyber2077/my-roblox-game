local fs = require("@lune/fs")

local Cosmetics = require(Shared.Config.Cosmetics)
local Luminance = require(Shared.Logic.Luminance)

local MIN = Cosmetics.LanternMinLuminance

describe("Cosmetic lanterns cannot lose the crew", function()
	it("gives every lantern a lens and a light bright enough to read at 3:1 on a dim screen", function()
		local lanterns = 0
		for _, item in Cosmetics.List do
			if item.category ~= "Lantern" then
				continue
			end
			lanterns += 1
			local look = item.look
			expect(Luminance.of(look.glass)).toBeAtLeast(MIN.Glass)
			expect(Luminance.of(look.light)).toBeAtLeast(MIN.Light)
			if look.light2 then
				-- the lens cycles between light and light2 (CosmeticMotion), so light2 is a lens colour too
				expect(Luminance.of(look.light2)).toBeAtLeast(MIN.Glass)
				expect(Luminance.of(look.light)).toBeAtLeast(MIN.Glass)
			end
			-- range and brightness stay shared: a look may only brighten (glow >= 1), never dim
			expect(look.glow == nil or look.glow >= 1).toBe(true)
		end
		expect(lanterns).toBeGreaterThan(1)
	end)

	it("keeps lantern looks visual only: no service reads them", function()
		local readers = {}
		local function scan(dir: string)
			for _, entry in fs.readDir(dir) do
				local path = `{dir}/{entry}`
				if fs.isDir(path) then
					scan(path)
				elseif string.match(entry, "%.luau$") then
					local source = fs.readFile(path)
					for _, pattern in { "look%.glass", "look%.light", "LanternMinLuminance" } do
						if string.find(source, pattern) then
							table.insert(readers, path)
						end
					end
				end
			end
		end
		scan("src/server/Services")
		scan("src/shared/Logic")
		expect(table.concat(readers, ", ")).toBe("")
	end)
end)
