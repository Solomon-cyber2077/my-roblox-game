--!strict
--[[
	Server bootstrap. Services start in two passes so every dependency exists
	before anything runs:
	  Init   build instances and wire references; must not yield on players
	  Start  connect events and begin loops
	The order below is the dependency order.
]]

local Registry = require(script.Registry)

local ORDER = {
	"WorldService",
	"NetService",
	"StateService",
	"DataService",
	"LobbyService",
	"TrainService",
	"StationService",
	"InventoryService",
	"LootService",
	"HollowService",
	"HazardDirector",
	"CrewService",
	"RouteService",
	"CosmeticService",
	"ProgressionService",
	"ShopService",
	"RunDirector",
	"DevService",
}

local services: { { name: string, module: any } } = {}
for _, name in ORDER do
	local module = (require :: any)(script.Services:FindFirstChild(name))
	Registry[name] = module
	table.insert(services, { name = name, module = module })
end

for _, entry in services do
	local started = os.clock()
	entry.module.Init()
	local elapsed = os.clock() - started
	if elapsed > 0.25 then
		print(`[Server] {entry.name}.Init took {string.format("%.2f", elapsed)}s`)
	end
end

for _, entry in services do
	entry.module.Start()
end

print("[Server] Last Train Out is running.")
