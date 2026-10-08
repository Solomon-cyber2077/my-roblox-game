--!strict
--[[
	The player's side of the boarding cars (CarService): which door prompt shows
	(Board outside, Get out inside while the exit is open), hold-to-board on keyboard
	and gamepad but a tap on touch, the green glow round each car's floor, the
	countdown for the car you are in, and the black screen while it leaves. In a
	car's reserved server the teleport screen stays up until you are on the train.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local CarBoarding = require(Shared.Logic.CarBoarding)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local CarBoardingUi = {}

local GLOW = Color3.fromRGB(96, 214, 150) -- signal-lamp green, not neon
local STRIP = 0.35 -- glow strip width
local CORNER = 1.4 -- corner square size

type CarState = { occupants: { string }, startedAt: number?, departing: boolean }

-- The index and state of the car the local player is in, if any.
function CarBoardingUi.MyCar(): (number?, CarState?)
	local cars = Registry.StateController.Get({ "lobby", "cars" }) or {}
	for index, car in cars do
		if table.find(car.occupants, Session.userKey) then
			return index, car
		end
	end
	return nil, nil
end

local function rules(car: CarState): CarBoarding.Car
	return { count = #car.occupants, startedAt = car.startedAt, departing = car.departing }
end

-- Green strips round the edges of a car's floor with a brighter square in each corner.
local function glow(zone: BasePart, folder: Instance): { BasePart }
	local parts: { BasePart } = {}
	-- inset off the wall linings
	local sx, sz = zone.Size.X - 0.6, zone.Size.Z - 0.6
	local function strip(size: Vector3, x: number, z: number)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = GLOW
		part.Transparency = 0.6
		part.Size = size
		part.CFrame = zone.CFrame * CFrame.new(x, 0.09 + size.Y / 2, z)
		part.Parent = folder
		table.insert(parts, part)
	end
	strip(Vector3.new(sx - 2 * CORNER, 0.05, STRIP), 0, sz / 2 - STRIP / 2)
	strip(Vector3.new(sx - 2 * CORNER, 0.05, STRIP), 0, -sz / 2 + STRIP / 2)
	strip(Vector3.new(STRIP, 0.05, sz - 2 * CORNER), sx / 2 - STRIP / 2, 0)
	strip(Vector3.new(STRIP, 0.05, sz - 2 * CORNER), -sx / 2 + STRIP / 2, 0)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			strip(Vector3.new(CORNER, 0.07, CORNER), cx * (sx - CORNER) / 2, cz * (sz - CORNER) / 2)
		end
	end
	return parts
end

function CarBoardingUi.mount(gui: ScreenGui)
	local State = Registry.StateController
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- Countdown panel, where the hall's departure panel sits ------------------------------------
	local panel = Ui.new("Frame", {
		Name = "CarBoarding",
		Size = UDim2.fromOffset(460, 132),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local function outlined(label: TextLabel): TextLabel
		Ui.new("UIStroke", {
			Color = Theme.Color.black,
			Thickness = 2,
			Transparency = 0.15,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
		label.Parent = panel
		return label
	end
	local count = outlined(Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 64,
		Color = GLOW,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 66),
		XAlign = Enum.TextXAlignment.Center,
	}))
	local headline = outlined(Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 24,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 26),
		XAlign = Enum.TextXAlignment.Center,
	}))
	local hint = outlined(Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 16,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 20),
		XAlign = Enum.TextXAlignment.Center,
	}))

	-- Black screen: its own top layer, over the top bar too ----------------------------------------
	local blackGui = Ui.new("ScreenGui", {
		Name = "CarBlackout",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		Parent = gui.Parent,
	})
	local black = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = blackGui,
	})
	local teleportGui = blackGui:Clone()
	teleportGui:FindFirstChildOfClass("Frame").BackgroundTransparency = 0
	pcall(TeleportService.SetTeleportGui, TeleportService, teleportGui)

	local blackedOut = false
	local function blackout(on: boolean)
		if on ~= blackedOut then
			blackedOut = on
			Ui.tween(
				black,
				{ BackgroundTransparency = if on then 0 else 1 },
				TweenInfo.new(if on then 0.6 else 1.2)
			)
		end
	end

	-- In a car's reserved server, keep the teleport screen until we are on the train.
	local arrival = TeleportService:GetArrivingTeleportGui()
	if arrival then
		black.BackgroundTransparency = 0
		blackedOut = true
		task.spawn(function()
			local deadline = os.clock() + Tuning.Cars.ArrivalWaitSeconds + 15
			while not Session.isMember() and os.clock() < deadline do
				task.wait(0.2)
			end
			task.wait(1)
			blackout(false)
		end)
	end

	-- Door prompts and floor glow -----------------------------------------------------------------
	local prompts: { ProximityPrompt } = {}
	local glows: { [number]: { BasePart } } = {}
	task.spawn(function()
		local hall = Workspace:WaitForChild("DepotHall", 60)
		local doors = hall and hall:WaitForChild("CarDoors", 30)
		if doors == nil then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "CarGlow"
		folder.Parent = Workspace
		local function add(child: Instance)
			local index = child:GetAttribute("Car")
			if type(index) ~= "number" then
				return
			end
			if child.Name == "CarZone" and child:IsA("BasePart") then
				glows[index] = glow(child, folder)
			end
			local p = child:FindFirstChildOfClass("ProximityPrompt")
				or child:WaitForChild("ProximityPrompt", 10)
			if p and p:IsA("ProximityPrompt") then
				if touchOnly then
					p.HoldDuration = 0 -- touch players tap the chip
				end
				table.insert(prompts, p)
			end
		end
		doors.ChildAdded:Connect(add)
		for _, child in doors:GetChildren() do
			task.spawn(add, child)
		end
	end)

	-- Boarding and getting out move the body through the wall; bring the camera round behind it.
	local function cameraBehind()
		task.wait(0.25)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		if root and camera then
			local eye = root.CFrame * Vector3.new(0, 2, Tuning.Cars.CameraZoom - 0.5)
			camera.CFrame = CFrame.lookAt(eye, root.Position + Vector3.new(0, 1.5, 0))
		end
	end

	local wasDeparting = false
	local lastCar: number? = nil
	local zoomBefore = Players.LocalPlayer.CameraMaxZoomDistance
	RunService.RenderStepped:Connect(function()
		local now = Session.now()
		local member = Session.isMember()
		local mine, car = CarBoardingUi.MyCar()
		if mine ~= lastCar then
			-- a car is narrower than the default zoom: keep the camera off its far wall while aboard
			local player = Players.LocalPlayer
			if lastCar == nil then
				zoomBefore = player.CameraMaxZoomDistance
				player.CameraMaxZoomDistance = math.min(zoomBefore, Tuning.Cars.CameraZoom)
			elseif mine == nil then
				player.CameraMaxZoomDistance = zoomBefore
			end
			lastCar = mine
			if not member then
				task.spawn(cameraBehind)
			end
		end
		local cars = State.Get({ "lobby", "cars" }) or {}

		for _, p in prompts do
			local index = p:GetAttribute("Car")
			local state = cars[index]
			if p:GetAttribute("Action") == "CarBoard" then
				p.Enabled = not member and mine == nil and state ~= nil and CarBoarding.canEnter(rules(state))
			else
				p.Enabled = mine == index and car ~= nil and CarBoarding.canExit(rules(car), now)
			end
		end

		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
		for index, parts in glows do
			local state = cars[index]
			local counting = state ~= nil and state.startedAt ~= nil
			local full = state ~= nil and not CarBoarding.canEnter(rules(state))
			local transparency = if full then 0.85 elseif counting then 0.35 + 0.3 * pulse else 0.6
			for _, part in parts do
				part.Transparency = transparency
			end
		end

		local departing = car ~= nil and car.departing
		if departing then
			wasDeparting = true
			blackout(true)
		elseif wasDeparting then
			wasDeparting = false
			task.delay(if member then 1 else 0, blackout, false)
		end

		panel.Visible = car ~= nil and not member
		if car == nil then
			return
		end
		local r = rules(car)
		local remaining = CarBoarding.remaining(r, now)
		local exitLeft = CarBoarding.exitRemaining(r, now)
		local seats = `{#car.occupants}/{Tuning.Cars.MaxPlayers} ABOARD`
		if car.departing then
			count.Text = "0"
			headline.Text = "ALL ABOARD"
			hint.Text = "Departing..."
		elseif remaining == nil then
			count.Text = ""
			headline.Text = `CAR {mine}  ·  {seats}`
			hint.Text = `Waiting for {Tuning.Cars.MinPlayers - #car.occupants} more to start the countdown`
		else
			count.Text = tostring(math.ceil(remaining))
			headline.Text = `DEPARTING  ·  {seats}`
			hint.Text = if exitLeft > 0
				then `Doors lock in {math.ceil(exitLeft)}s  ·  hold E at the door to get out`
				else "Doors locked"
		end
		if remaining == nil and not car.departing then
			hint.Text ..= "  ·  hold E at the door to get out"
		end
		if touchOnly then
			hint.Text = (string.gsub(hint.Text, "hold E", "tap"))
		end
	end)
end

return CarBoardingUi
