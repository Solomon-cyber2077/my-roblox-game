--!strict
--[[
	Junction ballot: one ticket per line on offer. Shows the station, its danger,
	the coal the leg will burn against what the bunker holds, the loot hint and
	the live tally. Clicking a ticket casts (or moves) your vote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
local Ledger = require(Shared.Logic.Ledger)
local Vote = require(Shared.Logic.Vote)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local RouteVote = {}

function RouteVote.mount(gui: ScreenGui)
	local State = Registry.StateController

	local container = Ui.new("Frame", {
		Name = "RouteVote",
		Size = UDim2.fromOffset(760, 190),
		Position = UDim2.new(0.5, 0, 1, -128),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local layout = Ui.list(
		Enum.FillDirection.Horizontal,
		14,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Bottom
	)
	layout.Parent = container

	local function render()
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local phase = Session.phase()
		local route = State.Get({ "run", "route" })
		local visible = phase == "Junction" and route ~= nil and Session.isAlive()
		container.Visible = visible
		if not visible then
			return
		end
		local options = route.options or {}
		local votes = route.votes or {}
		local counts = Vote.counts(votes, #options)
		local mine = votes[Session.userKey]
		local train = State.Get({ "train" })

		for index, option in options do
			local arch = Stations.List[option.archetype]
			local selected = mine == index
			local card = Ui.ticket({
				Name = "Option",
				Size = UDim2.fromOffset(238, 172),
				LayoutOrder = index,
				BackgroundColor3 = if selected then Theme.Color.brassLight else Theme.Color.paper,
			})
			card.Parent = container
			local name = Ui.text({
				Text = string.upper(arch.name),
				Font = Theme.Font.display,
				TextSize = 21,
				Color = Theme.Color.ink,
				Position = UDim2.fromOffset(24, 10),
				Size = UDim2.new(1, -36, 0, 26),
			})
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.Parent = card
			if not arch.terminus then
				local danger = Ui.text({
					Text = `DANGER {string.rep("●", option.tier)}{string.rep("○", 3 - option.tier)}`,
					Font = Theme.Font.bodyBold,
					TextSize = 14,
					Color = if option.tier >= 3 then Theme.Color.signal else Theme.Color.inkSoft,
					Position = UDim2.fromOffset(24, 38),
					Size = UDim2.new(1, -36, 0, 18),
				})
				danger.Parent = card
			end
			local cost = Ledger.legCoalCost(train or Ledger.newTrain(), option.distanceKm)
			local short = train ~= nil and cost > train.coal
			local legLine = Ui.text({
				Text = `{option.distanceKm} KM  ·  BURNS {cost} COAL`,
				Font = Theme.Font.display,
				TextSize = 16,
				Color = if short then Theme.Color.signal else Theme.Color.ink,
				Position = UDim2.fromOffset(24, 60),
				Size = UDim2.new(1, -36, 0, 20),
			})
			legLine.Parent = card
			local hint = Ui.text({
				Text = option.hint,
				Font = Theme.Font.type,
				TextSize = 15,
				Color = Theme.Color.inkSoft,
				Position = UDim2.fromOffset(24, 84),
				Size = UDim2.new(1, -36, 0, 20),
			})
			hint.Parent = card
			if short then
				local warn = Ui.text({
					Text = "Not enough coal: the hull will suffer",
					Font = Theme.Font.body,
					TextSize = 13,
					Color = Theme.Color.signal,
					Position = UDim2.fromOffset(24, 104),
					Size = UDim2.new(1, -36, 0, 16),
				})
				warn.Parent = card
			end
			local button = Ui.button(
				if selected then "YOUR VOTE" elseif #options == 1 then "FINAL LEG" else "TAKE THIS LINE",
				if selected then "Secondary" else "Primary",
				function()
					if #options > 1 then
						Net.Fire("CastVote", index)
					end
				end,
				{ Size = UDim2.new(1, -36, 0, 34), Position = UDim2.new(0, 24, 1, -42), TextSize = 16 }
			)
			button.Parent = card
			local tally = Ui.new("TextLabel", {
				Size = UDim2.fromOffset(34, 34),
				Position = UDim2.new(1, -8, 0, -10),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Theme.Color.signal,
				Text = tostring(counts[index] or 0),
				FontFace = Theme.Font.display,
				TextSize = 18,
				TextColor3 = Theme.Color.white,
				Visible = #options > 1,
				Parent = card,
			})
			Ui.corner(17).Parent = tally
		end
	end

	State.Observe("public", { "run", "route" }, render)
	State.Observe("public", { "run", "phase" }, render)
	State.Observe("public", { "crew", Session.userKey }, render)
	State.Observe("public", { "train", "coal" }, render)
end

return RouteVote
