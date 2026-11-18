--!strict
--[[
	Picks how a hall tile surface looks under Config/LobbyTiles. Pure: Builders/LobbyBuilder applies it.
]]

local Config = require(script.Parent.Parent.Config.LobbyTiles)

export type Pick = {
	material: string, -- an Enum.Material name
	variant: string?, -- a MaterialVariant name, or nil for the plain material
	color: { number }, -- 0-255
}

local LobbyTiles = {}

-- The look that actually applies: "painted" only once every map is uploaded, else today's.
function LobbyTiles.look(config: typeof(Config)?): Config.Look
	local c = config or Config
	if c.Look == "painted" then
		for _, v in c.Variants :: { [string]: Config.Variant } do
			if not v.uploaded then
				return "today"
			end
		end
		if c.Path.image == nil then
			return "today"
		end
	end
	return c.Look
end

-- The old colour over the map's mean, so the tinted map averages the old colour.
function LobbyTiles.tint(color: { number }, mean: { number }): { number }
	local out = {}
	for i = 1, 3 do
		out[i] = math.clamp(math.floor(color[i] * 255 / math.max(mean[i], 1) + 0.5), 0, 255)
	end
	return out
end

-- How the surface `key` ("quarry" or "dado"), built in `material` and `color`, should look.
function LobbyTiles.pick(key: string, material: string, color: { number }, config: typeof(Config)?): Pick
	local c = config or Config
	local v = (c.Variants :: any)[key] :: Config.Variant?
	local look = LobbyTiles.look(c)
	if not v or look == "today" then
		return { material = material, color = color }
	elseif look == "builtin" then
		return { material = v.builtin, color = color }
	end
	return { material = v.base, variant = v.name, color = LobbyTiles.tint(color, v.mean) }
end

return LobbyTiles
