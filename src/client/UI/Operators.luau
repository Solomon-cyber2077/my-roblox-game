--!strict

local Operators = {}

-- The crew panel sits in the top-right corner (with the rest of the HUD). Hud hides it on a
-- solo run, where it would only list you.
function Operators.mount(group: CanvasGroup, _container: Frame)
	group.Position = UDim2.new(1, -8, 0, 8)
	group.Visible = true
end

return Operators
