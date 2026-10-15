--!strict
--[[
	Creates the game's ScreenGui, scales it to the device, hides the core
	inventory and reset button, and mounts every UI module.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent.UI
local Hud = require(UI.Hud)
local Ledger = require(UI.Ledger)
local CarBoarding = require(UI.CarBoarding)
local Dialogue = require(UI.Dialogue)
local Lobby = require(UI.Lobby)
local Modal = require(UI.Modal)
local Outfitter = require(UI.Outfitter)
local Overlay = require(UI.Overlay)
local Prompts = require(UI.Prompts)
local QuestTracker = require(UI.QuestTracker)
local RouteVote = require(UI.RouteVote)
local RunCard = require(UI.RunCard)
local Spectate = require(UI.Spectate)
local TicketBook = require(UI.TicketBook)
local Unseal = require(UI.Unseal)
local Workshop = require(UI.Workshop)
local CrewChest = require(UI.CrewChest)

local Registry = require(script.Parent.Parent.Registry)

local UIController = {}

local UNSTICK_KEY = Enum.KeyCode.K

local gui: ScreenGui

local function setCore(name: string, value: any)
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore(name, value)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

-- A phone held sideways: too short for the desktop layout's 768 rows, so the HUD is drawn larger
-- than a plain fit would (text and touch targets stay usable), modals shrink themselves to fit
-- (Modal), and the notification feed moves off the thumbstick (Overlay reads the Compact attribute).
local COMPACT_HEIGHT = 500
local COMPACT_ROWS = 540

local function fitScale(scale: UIScale)
	local camera = Workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		local compact = UserInputService.TouchEnabled and size.Y < COMPACT_HEIGHT
		local fit = if compact
			then math.min(size.X / 1000, size.Y / COMPACT_ROWS)
			else math.min(size.X / 1366, size.Y / 768)
		scale.Scale = math.clamp(fit, 0.6, 1.15)
		gui:SetAttribute("Compact", compact)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

-- K: always gives the mouse back. Frees the cursor, closes any modal and the train camera,
-- drops gamepad selection and returns a camera left Scriptable to the player.
local function unstick()
	Modal.closeAll()
	GuiService.SelectedObject = nil
	local trainCam = Registry.TrainCamController
	if trainCam then
		trainCam.Close()
	end
	local grab = Registry.GrabController
	if grab then
		grab.Unstick()
	end
	if not (grab and grab.IsHeld()) then
		local camera = Workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local cam = Registry.CameraController
		if humanoid and not (cam and cam.SpectateTarget()) then
			camera.CameraSubject = humanoid
		end
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function UIController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "LastTrainOut"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	fitScale(scale)
end

function UIController.Start()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	-- health reads off the screen's edges (Overlay.vitals), not a bar
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	task.spawn(setCore, "ResetButtonCallback", false)

	Overlay.mount(gui)
	Hud.mount(gui)
	require(script.Parent.Parent.UI.Settings).mount(gui)
	RouteVote.mount(gui)
	Unseal.mount(gui)
	Lobby.mount(gui)
	CarBoarding.mount(gui)
	Spectate.mount(gui)
	Workshop.mount(gui)
	CrewChest.mount(gui)
	Outfitter.mount(gui)
	Ledger.mount(gui)
	TicketBook.mount(gui)
	RunCard.mount(gui)
	Prompts.mount(gui)
	QuestTracker.mount(gui)
	Dialogue.mount(gui)

	UserInputService.InputBegan:Connect(function(input, processed)
		-- ignored while typing in a text box
		if input.KeyCode ~= UNSTICK_KEY or processed or UserInputService:GetFocusedTextBox() then
			return
		end
		unstick()
	end)
end

function UIController.Gui(): ScreenGui
	return gui
end

function UIController.Open(name: string)
	if name == "Workshop" then
		Workshop.open()
	elseif name == "Outfitter" then
		Outfitter.open()
	elseif name == "Ledger" then
		Ledger.open()
	elseif name == "Chest" then
		CrewChest.open()
	end
end

return UIController
