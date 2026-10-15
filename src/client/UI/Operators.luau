--!strict

local Operators = {}

-- The crew panel sits in the top-right corner and is always shown (with the rest of the HUD).
function Operators.mount(group: CanvasGroup, _container: Frame)
	group.Position = UDim2.new(1, -8, 0, 8)
	group.Visible = true
end

return Operators
