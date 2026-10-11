--!strict

local Players = game:GetService("Players")

local Operators = {}

-- The crew panel sits in the top-right corner; the Settings menu turns it off and on.
function Operators.mount(group: CanvasGroup, _container: Frame)
	local player = Players.LocalPlayer
	group.Position = UDim2.new(1, -8, 0, 8)
	local function repaint()
		group.Visible = player:GetAttribute("OperatorsPanel") ~= "Hide"
	end
	player:GetAttributeChangedSignal("OperatorsPanel"):Connect(repaint)
	repaint()
end

return Operators
