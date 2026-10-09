--!strict
--[[
	Crew errands on the right edge of the screen: one entry per resident with an errand
	this run, from the private `quests` list (NpcService). Hidden when there are none.
]]

local Registry = require(script.Parent.Parent.Registry)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local QuestTracker = {}

type Entry = { npc: string, name: string, title: string, text: string, status: string, helper: boolean }

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

	local function render(entries: { Entry }?)
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list: { Entry } = entries or {}
		frame.Visible = #list > 0
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
end

return QuestTracker
