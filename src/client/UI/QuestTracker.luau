--!strict
--[[
	Crew errands on the right edge of the screen: one entry per resident with an errand
	this run, from the private `quests` list (NpcService). Hidden when there are none.
	In the hall it stays up; in a run it shows for SHOW_SECONDS when an errand changes (taken,
	item found, done) and then gets out of the way of the watch and the touch buttons.
]]

local RunService = game:GetService("RunService")

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local QuestTracker = {}

type Entry = { npc: string, name: string, title: string, text: string, status: string, helper: boolean }

local SHOW_SECONDS = 6

function QuestTracker.mount(gui: ScreenGui)
	local State = Registry.StateController
	local frame = Ui.panel({
		Name = "QuestTracker",
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -14, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 0.18,
		Visible = false,
		Parent = gui,
	})
	Ui.padding(10, 12).Parent = frame
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = frame
	local count = 0
	local shownKey = ""
	local changedAt = -math.huge

	local function render(entries: { Entry }?)
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list: { Entry } = entries or {}
		count = #list
		local key = ""
		for _, entry in list do
			key ..= `{entry.npc}|{entry.title}|{entry.text}|{entry.status};`
		end
		if key ~= shownKey then
			shownKey = key
			changedAt = os.clock()
		end
		local header = Ui.text({
			Text = "CREW ERRANDS",
			Font = Theme.Font.displayMedium,
			TextSize = 13,
			Color = Theme.Color.brassLight,
			LayoutOrder = 0,
		})
		header.Parent = frame
		for i, entry in list do
			local done = entry.status == "Done"
			local failed = entry.status == "Failed"
			local title = Ui.text({
				Text = `{entry.title}{if entry.helper then "  (lending a hand)" else ""}`,
				Font = Theme.Font.bodyBold,
				TextSize = 16,
				Color = if failed then Theme.Color.textDim else Theme.Color.white,
				LayoutOrder = i * 2 - 1,
			})
			title.Parent = frame
			local line = Ui.text({
				Text = `{if done then "✓ " else ""}{entry.name}: {entry.text}`,
				TextSize = 14,
				Color = if done then Theme.Color.brassLight else Theme.Color.textDim,
				Wrapped = true,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = i * 2,
			})
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Parent = frame
		end
	end

	State.Observe("private", { "quests" }, render)
	RunService.Heartbeat:Connect(function()
		local recent = os.clock() - changedAt < SHOW_SECONDS
		frame.Visible = count > 0 and (not Session.isMember() or recent)
	end)
end

return QuestTracker
