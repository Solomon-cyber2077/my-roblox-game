--!strict

local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Net)
local Menu = require(script.Parent.Menu)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Settings = require(game:GetService("ReplicatedStorage").Shared.Logic.Settings)

local SettingsUi = {}

local function current(player: Player, key: string): string
	local value = player:GetAttribute(key)
	return if type(value) == "string" and Settings.valid(key, value) then value else Settings.Defaults[key]
end

function SettingsUi.mount(gui: ScreenGui)
	require(script.Parent.BrokenThingMarkers).mount(gui)
	local player = Players.LocalPlayer
	local modal = Modal.new(gui, "Settings", Vector2.new(720, 600))
	-- one entry in the MENU dropdown (UI/Menu), in the hall and in a run
	Menu.add("SETTINGS", 30, function()
		modal:open()
	end)

	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
		Parent = modal.body,
	})
	Ui.list(Enum.FillDirection.Vertical, 10).Parent = list
	Ui.padding(4, 4, 4, 4).Parent = list

	local rows: { [string]: { value: TextLabel, buttons: { [string]: TextButton } } } = {}
	local choices = {
		{
			key = "GraphicsQuality",
			title = "GRAPHICS",
			values = { "Quality", "Performance" },
			toggle = false,
			note = "Choose your preferred graphics mode.",
		},
		{
			key = "BrokenThingMarkers",
			title = "BROKEN THING MARKERS",
			-- first few runs is the default, not a choice
			values = { "Always", "Off" },
			toggle = false,
			note = `Leak marks, floor arrows and notices show during your first {require(
				game:GetService("ReplicatedStorage").Shared.Config.Settings
			).FirstFewRuns} runs. Keep them always or turn them off.`,
		},
		{
			key = "Hud",
			title = "HUD",
			values = { "Show", "Hide" },
			toggle = true,
			note = "The pocket watch, gauges, backpack and crew roster during a run.",
		},
		{
			key = "Camera",
			title = "CAMERA",
			values = { "Locked", "Free" },
			toggle = false,
			note = "Locked keeps the camera behind you at one distance. Free lets you zoom in and out.",
		},
		{
			key = "Ambience",
			title = "DRONE & AMBIENCE",
			values = { "Full", "Half", "Low", "Off" },
			toggle = false,
			buttonWidth = 116,
			note = "The drone, wind and station sounds. Warnings, footsteps and the Hollows stay at full.",
		},
	}

	local labels = {} :: { [string]: string }
	local repaint: () -> ()
	for index, choice in choices do
		local row = Ui.new("Frame", {
			Size = UDim2.new(1, -8, 0, 150),
			BackgroundColor3 = Theme.Color.leather,
			BackgroundTransparency = 0.08,
			LayoutOrder = index,
			ZIndex = 32,
			Parent = list,
		})
		Ui.corner(2).Parent = row
		local title = Ui.text({
			Text = choice.title,
			Font = Theme.Font.displayMedium,
			TextSize = 26,
			Color = Theme.Color.brassLight,
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -32, 0, 30),
		})
		title.ZIndex = 33
		title.Parent = row
		local note = Ui.text({
			Text = choice.note,
			Font = Theme.Font.body,
			TextSize = 19,
			Wrapped = true,
			Color = Theme.Color.white,
			Position = UDim2.fromOffset(16, 44),
			Size = UDim2.new(1, -32, 0, 48),
		})
		note.ZIndex = 33
		note.Parent = row
		local state = Ui.text({
			Text = "",
			Font = Theme.Font.body,
			TextSize = 18,
			Color = Theme.Color.brass,
			Position = UDim2.fromOffset(16, 104),
			Size = UDim2.fromOffset(180, 30),
		})
		state.ZIndex = 34
		state.Parent = row
		local buttons: { [string]: TextButton } = {}
		local options: { string } = if choice.toggle then { choice.values[1] } else choice.values
		local width: number = (choice :: any).buttonWidth or 170
		for optionIndex, option in options do
			local button = Ui.button(labels[option] or option, "Secondary", function()
				if player:GetAttribute("SettingsReady") ~= true then
					return
				end
				if choice.toggle then
					local on = current(player, choice.key) == choice.values[1]
					Net.Fire("SetSetting", choice.key, choice.values[if on then 2 else 1])
				else
					Net.Fire("SetSetting", choice.key, option)
				end
			end, {
				Size = UDim2.fromOffset(width, 42),
				Position = UDim2.new(1, -((#options - optionIndex + 1) * (width + 8) + 2), 0, 96),
				TextSize = 24,
				Selectable = true,
			})
			button.ZIndex = 34
			button.Parent = row
			buttons[option] = button
		end
		rows[choice.key] = { value = state, buttons = buttons }
	end
	-- the lantern's reach: one slider, after the choices (UI/LanternSlider)
	require(script.Parent.LanternSlider).mount(list, #choices + 1)

	repaint = function()
		local ready = player:GetAttribute("SettingsReady") == true
		for _, choice in choices do
			local selected = current(player, choice.key)
			local row = rows[choice.key]
			row.value.Text = if not ready
				then "LOADING..."
				elseif choice.toggle then (if selected == choice.values[1] then "ON" else "OFF")
				else "SAVED CHOICE"
			for option, button in row.buttons do
				Ui.setButtonEnabled(button, ready)
				button.Selectable = ready
				if choice.toggle then
					-- the button names what it will do
					local on = selected == choice.values[1]
					button.Text = if on then "TURN OFF" else "TURN ON"
					Ui.setButtonStyle(button, if on then "Secondary" else "Primary")
				else
					button.Text = (if option == selected then "> " else "") .. (labels[option] or option)
					Ui.setButtonStyle(button, if option == selected then "Primary" else "Secondary")
				end
			end
		end
	end
	for _, choice in choices do
		player:GetAttributeChangedSignal(choice.key):Connect(repaint)
	end
	player:GetAttributeChangedSignal("SettingsReady"):Connect(repaint)
	repaint()
	return SettingsUi
end

return SettingsUi
