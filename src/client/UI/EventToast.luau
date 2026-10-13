--!strict
--[[
	The timed-event toast (server Events/TimedEventDirector): a plate at the top of the
	screen that counts down to the event, then names it while it runs.
]]

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local EventToast = {}

local gui: ScreenGui? = nil
local plate: Frame
local title: TextLabel
local line: TextLabel

local function build()
	local screen = Ui.new("ScreenGui", {
		Name = "LTO_EventToast",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	plate = Ui.new("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.new(0.9, 0, 0, 74),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { Ui.corner() :: Instance, Ui.stroke(Theme.Color.signal, 2), Ui.padding(8, 14, 8, 14) })
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(420, 74)
	size.Parent = plate
	title = Ui.text({
		Name = "Title",
		Font = Theme.Font.display,
		TextSize = 30,
		Color = Theme.Color.signal,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
	})
	title.Parent = plate
	line = Ui.text({
		Name = "Line",
		Font = Theme.Font.body,
		TextSize = 15,
		Color = Theme.Color.white,
		XAlign = Enum.TextXAlignment.Center,
		Wrapped = true,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
	})
	line.Parent = plate
	gui = screen
end

-- Shows the toast: `headline` in the big type, `text` under it.
function EventToast.show(headline: string, text: string)
	if gui == nil then
		build()
	end
	title.Text = headline
	line.Text = text;
	(gui :: ScreenGui).Enabled = true
end

function EventToast.hide()
	if gui then
		gui.Enabled = false
	end
end

return EventToast
