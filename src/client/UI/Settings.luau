--!strict

local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Net)
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
	local modal = Modal.new(gui, "Settings", Vector2.new(620, 460))
	local open = Ui.button("SETTINGS", "Secondary", function()
		modal:open()
	end, {
		Name = "SettingsButton",
		Size = UDim2.fromOffset(120, 34),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 14,
		Selectable = true,
	})
	open.ZIndex = 20
	open.Parent = gui

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
			note = "Choose your preferred graphics mode.",
		},
		{
			key = "BrokenThingMarkers",
			title = "BROKEN THING MARKERS",
			values = { "FirstFew", "Always", "Off" },
			note = `First few runs shows markers during your first {require(
				game:GetService("ReplicatedStorage").Shared.Config.Settings
			).FirstFewRuns} runs.`,
		},
		{
			key = "OperatorsPanel",
			title = "OPERATORS PANEL",
			values = { "Show", "Hide" },
			note = "Show or hide the top-right crew panel.",
		},
	}

	local labels = { FirstFew = "First few runs" } :: { [string]: string }
	local repaint: () -> ()
	for index, choice in choices do
		local row = Ui.new("Frame", {
			Size = UDim2.new(1, -8, 0, 106),
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
			TextSize = 17,
			Color = Theme.Color.brassLight,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 22),
		})
		title.ZIndex = 33
		title.Parent = row
		local note = Ui.text({
			Text = choice.note,
			Font = Theme.Font.body,
			TextSize = 12,
			Color = Theme.Color.tarnish,
			Position = UDim2.fromOffset(14, 32),
			Size = UDim2.new(1, -28, 0, 18),
		})
		note.ZIndex = 33
		note.Parent = row
		local state = Ui.text({
			Text = "",
			Font = Theme.Font.body,
			TextSize = 13,
			Color = Theme.Color.white,
			Position = UDim2.fromOffset(14, 78),
			Size = UDim2.fromOffset(120, 20),
		})
		state.ZIndex = 34
		state.Parent = row
		local buttons: { [string]: TextButton } = {}
		for optionIndex, option in choice.values do
			local button = Ui.button(labels[option] or option, "Secondary", function()
				if player:GetAttribute("SettingsReady") ~= true then
					return
				end
				Net.Fire("SetSetting", choice.key, option)
			end, {
				Size = UDim2.fromOffset(130, 30),
				Position = UDim2.new(1, -((#choice.values - optionIndex + 1) * 138), 0, 70),
				TextSize = 12,
				Selectable = true,
			})
			button.ZIndex = 34
			button.Parent = row
			buttons[option] = button
		end
		rows[choice.key] = { value = state, buttons = buttons }
	end

	repaint = function()
		local ready = player:GetAttribute("SettingsReady") == true
		for _, choice in choices do
			local selected = current(player, choice.key)
			local row = rows[choice.key]
			row.value.Text = if ready then "SAVED CHOICE" else "LOADING..."
			for option, button in row.buttons do
				Ui.setButtonEnabled(button, ready)
				button.Selectable = ready
				button.Text = (if option == selected then "> " else "") .. (labels[option] or option)
				Ui.setButtonStyle(button, if option == selected then "Primary" else "Secondary")
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
