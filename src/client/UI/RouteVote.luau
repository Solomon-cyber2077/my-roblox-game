--!strict
--[[
	Junction ballot: one paper ticket per line on offer (UI/Ticket, figures from
	Logic/TicketModel) across the top of the screen, clear of the crew: the station, its
	danger seal, the track, the coal and a stamp for every crew vote (UI/Stamp). A dial on
	each sweeps the vote timer; at lock-in the winner is punched and the rest go slack.
	Clicking a ticket's button casts (or moves) your vote; its flap unfolds the ticket by a
	line or two (the leg's length and coal), one ticket at a time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Ledger = require(Shared.Logic.Ledger)
local TicketModel = require(Shared.Logic.TicketModel)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local RouteBoard = require(script.Parent.RouteBoard)
local Session = require(script.Parent.Parent.Session)
local Stamp = require(script.Parent.Stamp)
local Theme = require(script.Parent.Theme)
local Ticket = require(script.Parent.Ticket)
local Ui = require(script.Parent.Ui)

local RouteVote = {}

local LAND_DEBOUNCE = 0.3 -- a voter's stamp slams down at most this often
local LINGER_SECONDS = 1.6 -- the ballot stays up this long after lock-in for the punch

function RouteVote.mount(gui: ScreenGui)
	local State = Registry.StateController

	local container = Ui.new("Frame", {
		Name = "RouteVote",
		Size = UDim2.fromOffset(720, 290),
		Position = UDim2.new(0.5, 0, 0, 10), -- along the top, clear of the crew on screen
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	-- the tickets sit in a row of their own, so the tie note under them stays out of the layout
	local ticketRow = Ui.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 250),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local layout = Ui.list(
		Enum.FillDirection.Horizontal,
		14,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Top
	)
	layout.Parent = ticketRow

	local openIndex: number? = nil -- the one ticket unfolded
	local render: () -> ()
	-- Near the saloon's route board the tickets hang on it instead of the screen (UI/RouteBoard)
	local board = RouteBoard.new(function()
		render()
	end)
	local function castVote(index: number)
		local route = State.Get({ "run", "route" })
		if route and #(route.options or {}) > 1 then
			Net.Fire("CastVote", index)
		end
	end

	-- The tickets ---------------------------------------------------------------------------------
	-- Built once per ballot (and again if the bunker changes the coal figures); votes, the flap
	-- and the dial update them in place so a stamp only slams down when it is new.
	-- a line of typescript on a strip of soot-iron, so it reads over any scenery
	local tieNote = Ui.text({
		Name = "TieNote",
		Text = "",
		Font = Theme.Font.type,
		TextSize = 14,
		Color = Theme.Color.brassLight,
		Size = UDim2.fromOffset(0, 26),
		Position = UDim2.new(0.5, 0, 0, 258), -- under an unfolded ticket
		XAlign = Enum.TextXAlignment.Center,
	})
	tieNote.AnchorPoint = Vector2.new(0.5, 0)
	tieNote.AutomaticSize = Enum.AutomaticSize.X
	tieNote.BackgroundColor3 = Theme.Color.leather -- a telegraph strip pasted on oxblood
	tieNote.BackgroundTransparency = 0.08
	Ui.padding(0, 12, 0, 12).Parent = tieNote
	Ui.stroke(Theme.Color.brass, 1, 0.25).Parent = tieNote
	tieNote.Parent = container
	local tickets: { Ticket.Handle } = {}
	local builtKey: string? = nil
	type Placed = { index: number, mark: Frame, landedAt: number }
	local placed: { [string]: Placed } = {}
	local punchedKey: string? = nil
	local lingerUntil = 0

	local function clearTickets()
		for _, handle in tickets do
			handle.slot:Destroy()
		end
		table.clear(tickets)
		table.clear(placed)
		builtKey = nil
		punchedKey = nil
	end

	local function ballotKey(route: any, coal: number?): string
		local parts = { tostring(State.Get({ "run", "nextStop" })), tostring(coal) }
		for _, option in route.options or {} do
			table.insert(parts, `{option.archetype}:{option.distanceKm}:{option.tier}`)
		end
		return table.concat(parts, "|")
	end

	-- Moves, lands and lifts stamps to match the votes; only a new or moved stamp animates,
	-- and never twice inside LAND_DEBOUNCE for the same voter.
	local function updateStamps(votes: { [string]: number })
		local crew = Session.crew() or {}
		local keep: { [string]: boolean } = {}
		for index, handle in tickets do
			local pile = TicketModel.pile(votes, index, Session.userKey)
			local slots = #pile
			for order, key in pile do
				keep[key] = true
				local mine = key == Session.userKey
				local spread = handle.stamps.Size.X.Offset
				local x = if slots == 1
					then spread / 2
					else 22 + (order - 1) * ((spread - 44) / math.max(slots - 1, 1))
				local position = UDim2.fromOffset(x, 25 + (TicketModel.hash(key) - 0.5) * 8)
				local entry: Placed? = placed[key]
				if entry and entry.index ~= index then
					entry.mark:Destroy()
					entry = nil
				end
				if entry == nil then
					local member = crew[key]
					local mark = Stamp.new({
						key = key,
						name = if member then member.name else nil,
						mine = mine,
						Position = position,
						ZIndex = 6 + order * 3,
					})
					mark.Parent = handle.stamps
					local now = os.clock()
					local last = placed[key]
					if last == nil or now - last.landedAt > LAND_DEBOUNCE then
						Stamp.land(mark)
						if Registry.AudioController then
							Registry.AudioController.Play("TicketStamp")
						end
					end
					placed[key] = { index = index, mark = mark, landedAt = now }
				else
					entry.mark.Position = position
				end
			end
		end
		for key, entry in placed do
			if not keep[key] then
				entry.mark:Destroy()
				placed[key] = nil
			end
		end
	end

	function render()
		local phase = Session.phase()
		local route = State.Get({ "run", "route" })
		local chosen = if route then route.chosen else nil
		if chosen ~= nil and builtKey ~= nil and punchedKey ~= builtKey and lingerUntil < os.clock() then
			-- the vote just closed (the phase leaves Junction with it): hold up for the punch
			lingerUntil = os.clock() + LINGER_SECONDS
			task.delay(LINGER_SECONDS + 0.05, render)
		end
		local lingering = chosen ~= nil and builtKey ~= nil and os.clock() < lingerUntil
		local visible = route ~= nil and Session.isAlive() and (phase == "Junction" or lingering)
		container.Visible = visible
		if not visible then
			board.update({ active = false, tickets = {}, options = {}, votes = {}, vote = castVote })
			for _, handle in tickets do
				handle.slot.Parent = ticketRow
			end
			openIndex = nil
			if route == nil or phase ~= "Junction" then
				clearTickets()
			end
			return
		end
		local options = route.options or {}
		local votes = route.votes or {}
		local mine = votes[Session.userKey]
		local train = State.Get({ "train" })
		local key = ballotKey(route, if train then train.coal else nil)
		if key ~= builtKey and chosen == nil then
			clearTickets()
			builtKey = key
			local stop = State.Get({ "run", "nextStop" }) or 1
			for index, option in options do
				local cost = Ledger.legCoalCost(train or Ledger.newTrain(), option.distanceKm)
				local view = TicketModel.view(
					option,
					(stop - 1) * #options + index,
					cost,
					if train then train.coal else nil
				)
				local handle = Ticket.full(view, {
					routeId = `{State.Get({ "run", "seed" })}:{stop}:{index}:{option.archetype}`,
					LayoutOrder = index,
					onVote = function()
						castVote(index)
					end,
					onFlap = function()
						openIndex = if openIndex == index then nil else index
						render()
					end,
				})
				handle.slot.Parent = ticketRow
				tickets[index] = handle
			end
		end
		-- one copy of each ticket: on the board when near it, else on the screen
		board.update({
			active = true,
			tickets = tickets,
			options = options,
			votes = votes,
			chosen = chosen,
			mine = mine,
			train = train,
			vote = castVote,
		})
		local onBoard = board.engaged()
		for index, handle in tickets do
			local host: Instance = if onBoard then board.host(index) or ticketRow else ticketRow
			if handle.slot.Parent ~= host then
				handle.slot.Parent = host
			end
		end
		container.Visible = not onBoard
		for index, handle in tickets do
			local selected = mine == index
			handle.setSelected(
				selected,
				if selected then "YOUR VOTE" elseif #options == 1 then "FINAL LEG" else "TAKE THIS LINE"
			)
			handle.setFlap(openIndex == index)
		end
		updateStamps(votes)
		tieNote.Text = if chosen then "" else TicketModel.tieNote(votes, options) or ""
		tieNote.Visible = tieNote.Text ~= ""

		-- Lock-in: the winner is punched, the rest go slack
		if chosen ~= nil and punchedKey ~= builtKey and tickets[chosen] then
			punchedKey = builtKey
			for index, handle in tickets do
				if index == chosen then
					handle.punch()
				else
					handle.slacken()
				end
			end
			if Registry.AudioController then
				Registry.AudioController.Play("TicketPunch")
			end
		end
	end

	State.Observe("public", { "run", "route" }, render)
	State.Observe("public", { "run", "phase" }, render)
	State.Observe("public", { "crew", Session.userKey }, render)
	State.Observe("public", { "train", "coal" }, render)

	-- The dials sweep from the vote's start to its end (run.phaseStartedAt -> phaseEndsAt)
	RunService.RenderStepped:Connect(function()
		if not (container.Visible or board.engaged()) or #tickets == 0 or Session.phase() ~= "Junction" then
			return
		end
		local sweep, numeral = TicketModel.dial(
			Session.now(),
			State.Get({ "run", "phaseStartedAt" }),
			State.Get({ "run", "phaseEndsAt" })
		)
		for _, handle in tickets do
			handle.setDial(sweep, numeral)
		end
	end)
end

return RouteVote
