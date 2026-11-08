--!strict
--[[
	Client bootstrap: controllers start in two passes (Init, then Start) in the
	order below, after the state mirror is wired, so every controller can
	subscribe to state before the first snapshot arrives. A controller that errors is reported and
	skipped (Util/Safe) so the others still start.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Safe = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Safe"))
local Registry = require(script.Registry)

local ORDER = {
	"StateController",
	"ThresholdController",
	"AudioController",
	"MovementController",
	"CameraController",
	"TrainCamController",
	"CharacterAnimator",
	"PassengerController",
	"HallLife",
	"SceneryController",
	"TrainVisualsController",
	"StationVisualsController",
	"HollowAnimator",
	"BuildingVisuals",
	"AtmosphereController",
	"VisibilityController",
	"UIController",
	"PhoneDefaults",
	"GrabController",
	"InjuryController",
	"DeathCamController",
	"TutorialController",
	"LeakController",
	"HullController",
	"FxController",
	"DepartureClock",
	"PianoNotes",
	"LobbyStorm",
	"LobbyShellController",
	"FootstepController",
	"DetailController",
	"VoidCurrentController",
	"MistController",
	"LobbyIdleController",
	"CrewClothingController",
	"HealthController",
}

local controllers: { { name: string, module: any } } = {}
for _, name in ORDER do
	local module = (require :: any)(script.Controllers:FindFirstChild(name))
	Registry[name] = module
	table.insert(controllers, { name = name, module = module })
end

-- each controller on its own: one that errors on this device is reported and skipped, so the rest
-- still start and the loading screen lifts instead of waiting out its 30 s
for _, entry in controllers do
	Safe.call(`{entry.name}.Init`, entry.module.Init)
end
for _, entry in controllers do
	Safe.call(`{entry.name}.Start`, entry.module.Start)
end
game:GetService("Players").LocalPlayer:SetAttribute("ClientStarted", true) -- lifts the loading screen
