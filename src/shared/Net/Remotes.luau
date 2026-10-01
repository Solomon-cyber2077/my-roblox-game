--!strict
--[[
	The networking contract. Every RemoteEvent the game uses is declared here,
	once, with its direction, argument checks and per-player rate limit.
	NetService (server) builds the instances from this table; NetClient
	(client) looks them up by the same names.

	Argument kinds:
	  boolean   true or false
	  slot      integer 1..12
	  option    integer 1..3
	  id        string of 1..48 letters, digits or underscores
]]

export type ArgKind = string -- "boolean" | "slot" | "option" | "id"

export type RemoteDef = {
	direction: "ToServer" | "ToClient",
	args: { ArgKind },
	rate: number, -- tokens refilled per second
	burst: number, -- bucket size
}

local Remotes: { [string]: RemoteDef } = {
	-- Client to server intents
	ClientReady = { direction = "ToServer", args = {}, rate = 1, burst = 2 },
	SetReady = { direction = "ToServer", args = { "boolean" }, rate = 4, burst = 4 },
	CastVote = { direction = "ToServer", args = { "option" }, rate = 4, burst = 4 },
	UseItem = { direction = "ToServer", args = { "slot" }, rate = 6, burst = 6 },
	DropItem = { direction = "ToServer", args = { "slot" }, rate = 6, burst = 6 },
	BuyUpgrade = { direction = "ToServer", args = { "id" }, rate = 3, burst = 3 },
	HullPatch = { direction = "ToServer", args = {}, rate = 2, burst = 2 },
	ShopPurchase = { direction = "ToServer", args = { "id" }, rate = 2, burst = 3 },
	ShopEquip = { direction = "ToServer", args = { "id" }, rate = 4, burst = 4 },
	JoinInProgress = { direction = "ToServer", args = {}, rate = 1, burst = 1 },

	-- Server to client
	Snapshot = { direction = "ToClient", args = {}, rate = 0, burst = 0 },
	Patch = { direction = "ToClient", args = {}, rate = 0, burst = 0 },
	Fx = { direction = "ToClient", args = {}, rate = 0, burst = 0 },
	Notify = { direction = "ToClient", args = {}, rate = 0, burst = 0 },
}

local function isInteger(value: any, lo: number, hi: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= lo and value <= hi
end

local Checks: { [ArgKind]: (any) -> boolean } = {
	boolean = function(value)
		return type(value) == "boolean"
	end,
	slot = function(value)
		return isInteger(value, 1, 12)
	end,
	option = function(value)
		return isInteger(value, 1, 3)
	end,
	id = function(value)
		return type(value) == "string"
			and #value >= 1
			and #value <= 48
			and string.match(value, "^[%w_]+$") ~= nil
	end,
}

-- True when the received arguments match the declared kinds exactly.
local function validate(def: RemoteDef, ...: any): boolean
	if select("#", ...) > #def.args then
		return false
	end
	for i, kind in def.args do
		if not Checks[kind]((select(i, ...))) then
			return false
		end
	end
	return true
end

for _, def in Remotes do
	table.freeze(def.args)
	table.freeze(def)
end

return table.freeze({
	List = table.freeze(Remotes),
	validate = validate,
	FolderName = "Remotes",
})
