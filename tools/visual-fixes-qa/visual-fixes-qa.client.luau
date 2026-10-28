--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local function pass(name: string) print("VISUAL_FIXES_QA PASS " .. name) end
local function fail(name: string, detail: string) warn("VISUAL_FIXES_QA FAIL " .. name .. " " .. detail) end
local function waitFor(predicate: () -> any, timeout: number): any
	local started = os.clock()
	repeat local value = predicate(); if value then return value end; RunService.Heartbeat:Wait() until os.clock() - started > timeout
	return nil
end
local function assertLightAt(position: Vector3, expected: boolean, label: string): boolean
	local player = Players.LocalPlayer; local character = player.Character; local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then fail(label, "missing root"); return false end
	root.CFrame = CFrame.new(position)
	local light = waitFor(function()
		local cosmetics = character and character:FindFirstChild("Cosmetics"); local lantern = cosmetics and cosmetics:FindFirstChild("Lantern")
		local lens = lantern and lantern:FindFirstChild("Lens", true); local glow = lens and lens:FindFirstChild("Glow")
		return if glow and glow:IsA("PointLight") and glow.Enabled == expected then glow else nil
	end, 3)
	if light then pass(label); return true end
	fail(label, "lantern Enabled did not become " .. tostring(expected)); return false
end
local function volumePosition(folder: Instance, name: string): Vector3?
	local cf = folder:GetAttribute(name .. "CFrame"); return if typeof(cf) == "CFrame" then cf.Position else nil
end
local function doorSnapshot(model: Model): { [BasePart]: CFrame }
	local result: { [BasePart]: CFrame } = {}
	for _, instance in model:GetDescendants() do if instance:IsA("BasePart") and typeof(instance:GetAttribute("DoorSlide")) == "number" then result[instance] = instance.CFrame end end
	return result
end
local function testDoors(model: Model, axis: Vector3): boolean
	if next(doorSnapshot(model)) == nil then fail("display_doors", "no DoorSlide parts"); return false end
	local original = model:GetAttribute("DoorsOpen"); local success = true
	for cycle = 1, 3 do
		model:SetAttribute("DoorsOpen", false); task.wait(1.0); local closed = doorSnapshot(model)
		model:SetAttribute("DoorsOpen", true); task.wait(1.0); local open = doorSnapshot(model)
		for part, base in closed do
			local delta = open[part].Position - base.Position; local scalar = delta:Dot(axis); local perpendicular = delta - axis * scalar; local slide = part:GetAttribute("DoorSlide")
			if math.abs(scalar) < 0.02 or perpendicular.Magnitude > 0.03 or math.abs(math.abs(scalar) - math.abs(slide :: number)) > 0.08 then success = false; fail("display_doors_cycle_" .. cycle, part:GetFullName() .. " displacement is not along shared slide axis") end
		end
		model:SetAttribute("DoorsOpen", false); task.wait(1.0)
	end
	model:SetAttribute("DoorsOpen", true); if success then pass("display_doors_three_cycles") end; return success
end
task.spawn(function()
	local player = Players.LocalPlayer; local character = waitFor(function() return player.Character end, 30) :: Model?; local root = character and character:FindFirstChild("HumanoidRootPart")
	local volumes = waitFor(function() return ReplicatedStorage:FindFirstChild("TrainVolumes") end, 30); local liveTrain = waitFor(function() return Workspace:FindFirstChild("Train") end, 30)
	local hall = waitFor(function() return Workspace:FindFirstChild("DepotHall") end, 30); local display = hall and waitFor(function() return hall:FindFirstChild("DisplayTrain") end, 30)
	if not character or not root or not root:IsA("BasePart") or not volumes or not liveTrain or not display or not display:IsA("Model") then fail("boot", "required runtime objects missing"); return end
	local original = root.CFrame; local originalAnchored = root.Anchored; root.Anchored = true; task.wait(3.0) local liveCar = volumePosition(volumes, "Car"); local liveCab = volumePosition(volumes, "Cab"); local liveOrigin = liveTrain:IsA("Model") and liveTrain:GetAttribute("Origin"); local displayOrigin = display:GetAttribute("Origin")
	if not liveCar or not liveCab or typeof(liveOrigin) ~= "CFrame" or typeof(displayOrigin) ~= "CFrame" then fail("volume_setup", "missing live volume or origin attributes"); return end
	local displayCar = (displayOrigin :: CFrame) * (liveOrigin :: CFrame):ToObjectSpace(CFrame.new(liveCar)); local displayCab = (displayOrigin :: CFrame) * (liveOrigin :: CFrame):ToObjectSpace(CFrame.new(liveCab))
	assertLightAt(liveCar, false, "live_car_inside"); assertLightAt(liveCar + Vector3.new(0, 0, 30), true, "live_car_outside"); assertLightAt(liveCab, false, "live_cab_inside"); assertLightAt(liveCab + Vector3.new(0, 0, 30), true, "live_cab_outside")
	assertLightAt(displayCar.Position, false, "display_car_inside"); assertLightAt(displayCar.Position + Vector3.new(0, 0, 30), true, "display_car_outside"); assertLightAt(displayCab.Position, false, "display_cab_inside"); assertLightAt(displayCab.Position + Vector3.new(0, 0, 30), true, "display_cab_outside")
	local origin = display:GetAttribute("Origin"); local axis = if typeof(origin) == "CFrame" then (origin :: CFrame).RightVector else display:GetPivot().RightVector; testDoors(display, axis); task.wait(30); local remotes = ReplicatedStorage:FindFirstChild("Remotes"); local dev = remotes and remotes:FindFirstChild("Dev"); if dev and dev:IsA("RemoteEvent") then dev:FireServer("leak"); task.wait(2); local arrowOk = false; for _, item in Workspace:GetDescendants() do if item:IsA("BasePart") and item.Name == "LeakChevron" then local gui = item:FindFirstChildOfClass("SurfaceGui"); local hasCanvasGroup = item:FindFirstChildWhichIsA("CanvasGroup", true) ~= nil; local opaque = false; if gui then for _, child in gui:GetDescendants() do if child:IsA("Frame") and child.Parent == gui and child.BackgroundTransparency < 0.9 then opaque = true end end end; if gui and not hasCanvasGroup and not opaque then arrowOk = true end end end; if arrowOk then pass("leak_arrow_no_white_box") else fail("leak_arrow_no_white_box", "missing or opaque chevron") end else fail("leak_trigger", "Dev remote missing") end; root.CFrame = original; root.Anchored = originalAnchored
	local camera = Workspace.CurrentCamera; if camera then camera.CameraType = Enum.CameraType.Scriptable; local displayOrigin = display:GetAttribute("Origin"); local base = if typeof(displayOrigin) == "CFrame" then displayOrigin :: CFrame else display:GetPivot(); local eye = base:PointToWorldSpace(Vector3.new(-10, 8, 30)); local target = base:PointToWorldSpace(Vector3.new(-10, 4, 0)); camera.CFrame = CFrame.lookAt(eye, target) end
	print("VISUAL_FIXES_QA COMPLETE")
end)




