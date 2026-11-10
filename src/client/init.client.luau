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
-- the first load (stage 5: hall playable within 15 s on a mid-range phone): any controller taking
-- longer than SLOW to get going is printed, so a probe run shows where the time goes
local SLOW = 0.05
local function timed(label: string, fn: any)
	local t0 = os.clock()
	Safe.call(label, fn)
	local spent = os.clock() - t0
	if spent >= SLOW then
		print(string.format("[FirstLoad] %s %.0f ms", label, spent * 1000))
	end
end
local began = os.clock()
for _, entry in controllers do
	timed(`{entry.name}.Init`, entry.module.Init)
end
for _, entry in controllers do
	timed(`{entry.name}.Start`, entry.module.Start)
end
print(string.format("[FirstLoad] all controllers %.0f ms", (os.clock() - began) * 1000))
local player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local state = Registry.StateController
player:SetAttribute("ClientStarted", true)

-- Startup alone does not mean the server has built and spawned us into the hall.
local function playable(): boolean
	if not game:IsLoaded() or not state.IsReady() then
		return false
	end
	local character = player.Character
	local camera = workspace.CurrentCamera
	if not character or character:GetAttribute("SpawnReady") ~= true or not camera then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	if root.Anchored or camera.CameraSubject ~= humanoid then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local floor = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), params)
	return floor ~= nil
end

while not playable() do
	task.wait(0.1)
end
-- Let the ready world and camera reach a rendered frame before removing the cover.
RunService.RenderStepped:Wait()
RunService.RenderStepped:Wait()
player:SetAttribute("ClientPlayable", true)
