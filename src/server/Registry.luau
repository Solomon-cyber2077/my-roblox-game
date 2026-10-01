--!strict
--[[
	Service registry. The bootstrap fills it before any Init runs, so services
	can call each other at runtime (Registry.CrewService.IsAlive(...)) without
	require cycles between modules that legitimately depend on each other.
]]

local Registry: { [string]: any } = {}

return Registry
