--!strict
-- Line Mastery: lifetime stats and milestone progress, read from the private profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Progression = require(Shared.Config.Progression)
local Milestones = require(Shared.Logic.Milestones)
local Rank = require(Shared.Logic.Rank)
local Format = require(Shared.Util.Format)

local Registry = require(script.Parent.Parent.Registry)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Ledger = {}

local modal: Modal.Modal

local STAT_LABELS = {
	{ key = "runs", label = "Runs" },
	{ key = "victories", label = "Terminus arrivals" },
	{ key = "stationsDeparted", label = "Stations departed" },
	{ key = "bestStation", label = "Best run (stations)" },
	{ key = "coalDelivered", label = "Coal delivered" },
	{ key = "partsDelivered", label = "Parts delivered" },
	{ key = "relicsBanked", label = "Relics banked" },
	{ key = "rescues", label = "Rescues" },
	{ key = "clutchBoards", label = "Last-second boardings" },
}

function Ledger.mount(gui: ScreenGui)
	local State = Registry.StateController
	modal = Modal.new(gui, "Line Mastery", Vector2.new(820, 540))

	local stats = Ui.new("Frame", {
		Size = UDim2.fromScale(0.36, 1),
		BackgroundColor3 = Theme.Color.paper,
		ZIndex = 32,
		Parent = modal.body,
	})
	Ui.corner().Parent = stats
	Ui.padding(14, 16).Parent = stats
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = stats

	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.fromScale(0.62, 1),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
		Parent = modal.body,
	})
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = list

	local function render()
		for _, child in stats:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local profile = State.GetPrivate({ "profile" }) or {}
		local values = profile.stats or {}
		local rank = Rank.fromXp(profile.xp or 0)
		local head = Ui.text({
			Text = `CREW RANK {rank}`,
			Font = Theme.Font.display,
			TextSize = 26,
			Color = Theme.Color.ink,
			LayoutOrder = 0,
		})
		head.ZIndex = 33
		head.Parent = stats
		for i, entry in STAT_LABELS do
			local line = Ui.text({
				Text = `{entry.label} {string.rep(".", 30 - #entry.label)} {Format.thousands(
					values[entry.key] or 0
				)}`,
				Font = Theme.Font.type,
				TextSize = 15,
				Color = Theme.Color.ink,
				LayoutOrder = i,
			})
			line.ZIndex = 33
			line.Parent = stats
		end

		for i, milestone in Progression.Milestones do
			local claimed = (profile.milestones or {})[milestone.id] == true
			local value, goal = Milestones.progress(values, rank, milestone.id)
			local row = Ui.new("Frame", {
				Size = UDim2.new(1, -8, 0, 64),
				BackgroundColor3 = if claimed then Theme.Color.steelLight else Theme.Color.steel,
				BackgroundTransparency = 0.15,
				LayoutOrder = i,
				ZIndex = 32,
				Parent = list,
			})
			Ui.corner().Parent = row
			local name = Ui.text({
				Text = string.upper(milestone.name),
				Font = Theme.Font.display,
				TextSize = 17,
				Color = if claimed then Theme.Color.go else Theme.Color.white,
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -150, 0, 20),
			})
			name.ZIndex = 33
			name.Parent = row
			local desc = Ui.text({
				Text = milestone.description,
				TextSize = 14,
				Color = Theme.Color.textDim,
				Position = UDim2.fromOffset(12, 26),
				Size = UDim2.new(1, -150, 0, 16),
			})
			desc.ZIndex = 33
			desc.Parent = row
			local meter, setMeter = Ui.meter({
				Size = UDim2.new(1, -160, 0, 6),
				Position = UDim2.fromOffset(12, 48),
				FillColor = if claimed then Theme.Color.go else Theme.Color.brass,
			})
			meter.ZIndex = 33
			meter.Parent = row
			setMeter(value / goal, nil, true)
			local rewardText = if milestone.reward.cosmetic
				then (Cosmetics.ById[milestone.reward.cosmetic] or {} :: any).name or "Cosmetic"
				else `{milestone.reward.brass} Brass`
			local reward = Ui.text({
				Text = if claimed
					then "CLAIMED"
					else `{Format.thousands(value)}/{Format.thousands(goal)}  ·  {rewardText}`,
				Font = Theme.Font.bodyBold,
				TextSize = 13,
				Color = if claimed then Theme.Color.go else Theme.Color.brassLight,
				Position = UDim2.new(1, -12, 0, 8),
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.fromOffset(140, 48),
				XAlign = Enum.TextXAlignment.Right,
				Wrapped = true,
			})
			reward.ZIndex = 33
			reward.Parent = row
		end
	end

	modal.onOpen = render
	State.Observe("private", { "profile" }, function()
		if modal:isOpen() then
			render()
		end
	end)
end

function Ledger.open()
	modal:open()
end

return Ledger
