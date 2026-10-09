--!strict
--[[
	What a resident says when you talk to them (NpcService, the Dialogue remote): the
	train's modal window titled with their name, their trade in the caption and the line
	typed onto a ticket-stock card. CLOSE, the backdrop or gamepad B closes it.
]]

local Net = require(script.Parent.Parent.Net)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Dialogue = {}

type Said = { npc: string, name: string, role: string, text: string }

function Dialogue.mount(gui: ScreenGui)
	local modal = Modal.new(gui, "Resident", Vector2.new(640, 236))

	local role = Ui.text({
		Name = "Role",
		Font = Theme.Font.displayMedium,
		TextSize = 15,
		Color = Theme.Color.brassLight,
		Size = UDim2.new(1, 0, 0, 20),
	})
	role.ZIndex = 33
	role.Parent = modal.body

	local card = Ui.ticket({
		Name = "Card",
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 28),
		ZIndex = 32,
		Parent = modal.body,
	})
	local text = Ui.text({
		Name = "Line",
		Font = Theme.Font.type,
		TextSize = 19,
		Color = Theme.Color.ink,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -52, 1, -28),
		Position = UDim2.fromOffset(32, 14),
	})
	text.ZIndex = 33
	text.Parent = card

	Net.On("Dialogue", function(said: Said)
		if type(said) ~= "table" then
			return
		end
		modal.title.Text = string.upper(said.name)
		role.Text = string.upper(said.role)
		text.Text = `"{said.text}"`
		modal:open()
	end)
end

return Dialogue
