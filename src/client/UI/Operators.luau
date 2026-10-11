--!strict

local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Net)
local Ui = require(script.Parent.Ui)

local Operators = {}

function Operators.mount(group: CanvasGroup, container: Frame)
	local player = Players.LocalPlayer
	group.Position = UDim2.new(1, -14, 0, 46)
	local toggle = Ui.button("OPERATORS −", "Secondary", function()
		if player:GetAttribute("SettingsReady") ~= true then
			return
		end
		local current = player:GetAttribute("OperatorsPanel")
		Net.Fire("SetSetting", "OperatorsPanel", if current == "Hide" then "Show" else "Hide")
	end, {
		Size = UDim2.fromOffset(142, 28),
		Position = UDim2.new(1, -14, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 12,
		Selectable = true,
		ZIndex = 20,
		Parent = container,
	})
	toggle.ZIndex = 20
	toggle.Parent = container

	local function repaint()
		local ready = player:GetAttribute("SettingsReady") == true
		local hidden = player:GetAttribute("OperatorsPanel") == "Hide"
		group.Visible = not hidden
		toggle.Text = if hidden then "OPERATORS +" else "OPERATORS −"
		Ui.setButtonEnabled(toggle, ready)
		toggle.Selectable = ready
	end
	for _, attribute in { "OperatorsPanel", "SettingsReady" } do
		player:GetAttributeChangedSignal(attribute):Connect(repaint)
	end
	repaint()
end

return Operators
