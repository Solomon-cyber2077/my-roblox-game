--!strict
--[[
	A phone's or tablet's first visit starts in Performance (Logic/Settings.autoGraphics). The choice is saved like any
	other setting, so it happens once and the player can change it back in Settings.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Logic.Settings)
local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Overlay = require(script.Parent.Parent.UI.Overlay)

local TOAST_DELAY = 3 -- clears the loading screen's fade
local TOAST_SECONDS = 5

local PhoneDefaults = {}

local player = Players.LocalPlayer

local function apply()
	if player:GetAttribute("SettingsReady") ~= true then
		return false
	end
	local value = Settings.autoGraphics(
		Registry.StateController.KnownDevice(),
		player:GetAttribute("GraphicsChosen") == true
	)
	if value then
		Net.Fire("SetSetting", "GraphicsQuality", value)
		task.delay(
			TOAST_DELAY,
			Overlay.alert,
			"Performance mode on for smoother play. Change in Settings.",
			nil,
			TOAST_SECONDS
		)
	end
	return true
end

function PhoneDefaults.Init() end

function PhoneDefaults.Start()
	-- apply waits for the device to be known: on its own thread, so the rest of the client starts
	task.spawn(function()
		if apply() then
			return
		end
		local connection: RBXScriptConnection
		connection = player:GetAttributeChangedSignal("SettingsReady"):Connect(function()
			if player:GetAttribute("SettingsReady") == true and connection.Connected then
				connection:Disconnect()
				apply()
			end
		end)
	end)
end

return PhoneDefaults
