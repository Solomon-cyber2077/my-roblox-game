--!strict
--[[
	Client bootstrap: controllers start in two passes (Init, then Start) in the
	order below, after the state mirror is wired, so every controller can
	subscribe to state before the first snapshot arrives.
]]

local Registry = require(script.Registry)

local ORDER = {
	"StateController",
	"AudioController",
	"MovementController",
	"CameraController",
	"SceneryController",
	"TrainVisualsController",
	"StationVisualsController",
	"HollowAnimator",
	"BuildingVisuals",
	"AtmosphereController",
	"UIController",
	"FxController",
}

local controllers: { { name: string, module: any } } = {}
for _, name in ORDER do
	local module = (require :: any)(script.Controllers:FindFirstChild(name))
	Registry[name] = module
	table.insert(controllers, { name = name, module = module })
end

for _, entry in controllers do
	entry.module.Init()
end
for _, entry in controllers do
	entry.module.Start()
end
