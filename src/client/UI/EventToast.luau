--!strict
--[[
	The timed-event toast (server Events/TimedEventDirector): a slim banner on the top edge of the
	screen that counts down to the event, then names it while it runs. It used to sit across the upper
	middle, where a Hollow would stand (owner, 11-10: move it off the centre); its sentence shows only
	the first time, after that just the headline.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local EventToast = {}

local gui: ScreenGui? = nil
local plate: Frame
local title: TextLabel
local line: TextLabel
local FULL_H, SLIM_H = 52, 34 -- with the sentence, and headline only
local seen: { [string]: boolean } = {} -- sentences already shown once this session

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
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.9, 0, 0, FULL_H),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { Ui.corner() :: Instance, Ui.stroke(Theme.Color.alarmRim, 2), Ui.padding(5, 12, 5, 12) })
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(380, FULL_H)
	size.Parent = plate
	-- drawn at the HUD's scale, so on a phone it is a small strip at the top rather than a desktop-sized
	-- plate over the middle of the view (it covered RING DEPARTURE BELL, owner, stage 4 round 2)
	local scale = Instance.new("UIScale")
	scale.Parent = screen
	local camera = Workspace.CurrentCamera
	local function fit()
		local view = camera.ViewportSize
		local s = math.clamp(math.min(view.X / 1366, view.Y / 768), 0.55, 1)
		scale.Scale = s
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	title = Ui.text({
		Name = "Title",
		Font = Theme.Font.alert,
		TextSize = 22,
		Color = Theme.Color.alarm,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
	})
	title.Parent = plate
	line = Ui.text({
		Name = "Line",
		Font = Theme.Font.body,
		TextSize = 13,
		Color = Theme.Color.white,
		XAlign = Enum.TextXAlignment.Center,
		Wrapped = true,
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 16),
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
	line.Text = text
	-- the sentence the first time it appears (a countdown repeats it every second), then headline only
	local first = seen[text] ~= true or line.Visible and plate:GetAttribute("Sentence") == text
	if first then
		seen[text] = true
		plate:SetAttribute("Sentence", text)
	end
	line.Visible = first
	local height = if first then FULL_H else SLIM_H
	plate.Size = UDim2.new(0.9, 0, 0, height)
	local limit = plate:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(380, height)
	end
	(gui :: ScreenGui).Enabled = true
end

function EventToast.hide()
	if gui then
		gui.Enabled = false
		plate:SetAttribute("Sentence", nil) -- the next event shows its headline only, if seen before
	end
end

return EventToast
