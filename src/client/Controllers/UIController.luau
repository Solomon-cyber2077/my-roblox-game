--!strict
--[[
	Creates the game's ScreenGui, scales it to the device, hides the core
	inventory and reset button, and mounts every UI module.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent.UI
local Hud = require(UI.Hud)
local Ledger = require(UI.Ledger)
local CarBoarding = require(UI.CarBoarding)
local Lobby = require(UI.Lobby)
local Outfitter = require(UI.Outfitter)
local Overlay = require(UI.Overlay)
local Prompts = require(UI.Prompts)
local RouteVote = require(UI.RouteVote)
local Spectate = require(UI.Spectate)
local Summary = require(UI.Summary)
local Workshop = require(UI.Workshop)

local UIController = {}

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

local function fitScale(scale: UIScale)
	local camera = Workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1366, size.Y / 768), 0.6, 1.15)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
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
	task.spawn(setCore, "ResetButtonCallback", false)

	Overlay.mount(gui)
	Hud.mount(gui)
	RouteVote.mount(gui)
	Lobby.mount(gui)
	CarBoarding.mount(gui)
	Spectate.mount(gui)
	Workshop.mount(gui)
	Outfitter.mount(gui)
	Ledger.mount(gui)
	Summary.mount(gui)
	Prompts.mount(gui)
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
	end
end

return UIController
