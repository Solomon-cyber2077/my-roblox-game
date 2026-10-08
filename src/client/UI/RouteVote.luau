--!strict
--[[
	Junction ballot: one paper ticket per line on offer (UI/Ticket, figures from
	Logic/TicketModel) across the top of the screen, clear of the crew: the station, its
	danger seal, the track, the coal and a stamp for every crew vote (UI/Stamp). A dial on
	each sweeps the vote timer; at lock-in the winner is punched and the rest go slack.
	Clicking a ticket's button casts (or moves) your vote; its flap lays the station's
	dossier on the table in the middle of the screen: the leg, the haul, the dangers, what
	stands in the yard and the clerk's note. Gamepad B, the backdrop or CLOSE puts it away.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
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

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

local BOX_EMPTY = Color3.fromRGB(32, 32, 36)
local BOX_RIM = Color3.fromRGB(74, 74, 82)
local LAND_DEBOUNCE = 0.3 -- a voter's stamp slams down at most this often
local LINGER_SECONDS = 1.6 -- the ballot stays up this long after lock-in for the punch
local BLUE_INK = Color3.fromRGB(38, 58, 120)

local LAYOUT_TEXT = {
	Street = "A lane to the far edge, a cross street, lots either side",
	Plaza = "An open square at its heart, lanes in and out",
	Yard = "A forecourt by the platform, buildings all round it",
	Sidings = "Tracks the length of the yard, heaps between them",
}

-- "ToolChest" -> "TOOL CHEST"
local function words(id: string): string
	return string.upper((string.gsub(id, "(%l)(%u)", "%1 %2")))
end

local function plural(word: string, count: number): string
	if count == 1 then
		return word
	end
	local last = string.sub(word, -1)
	if last == "S" or last == "X" or last == "H" then
		return word .. "ES"
	end
	return word .. "S"
end

-- A row of `of` little boxes, the first `filled` of them lit in `color`.
local function boxes(
	filled: number,
	of: number,
	color: Color3,
	w: number,
	h: number,
	gap: number,
	empty: Color3?,
	rim: Color3?
): Frame
	local row = Ui.new("Frame", {
		Name = "Boxes",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(of * w + (of - 1) * gap, h),
	})
	for i = 1, of do
		local lit = i <= filled
		local box = Ui.new("Frame", {
			Size = UDim2.fromOffset(w, h),
			Position = UDim2.fromOffset((i - 1) * (w + gap), 0),
			BackgroundColor3 = if lit then color else empty or BOX_EMPTY,
			BorderSizePixel = 0,
			Parent = row,
		})
		Ui.corner(1).Parent = box
		Ui.stroke(if lit then color else rim or BOX_RIM, 1, if lit then 0.55 else 0.2).Parent = box
	end
	return row
end

function RouteVote.mount(gui: ScreenGui)
	local State = Registry.StateController

	local container = Ui.new("Frame", {
		Name = "RouteVote",
		Size = UDim2.fromOffset(720, 346),
		Position = UDim2.new(0.5, 0, 0, 10), -- along the top, clear of the crew on screen
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	-- the tickets sit in a row of their own, so the tie note under them stays out of the layout
	local ticketRow = Ui.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 310),
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

	-- The dossier ---------------------------------------------------------------------------------
	local backdrop = Ui.new("TextButton", {
		Name = "DossierBackdrop",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	})
	local dossier: Frame? = nil
	local openIndex: number? = nil
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

	local function closeDossier()
		if dossier then
			dossier:Destroy()
			dossier = nil
		end
		openIndex = nil
		backdrop.Visible = false
		ContextActionService:UnbindAction("LTO_CloseDossier")
	end
	backdrop.Activated:Connect(function()
		closeDossier()
		render()
	end)

	local function buildDossier(index: number, option: any, cost: number, short: boolean, train: any)
		local arch = Stations.List[option.archetype]
		-- the sheet, laid a little crooked, and its shadow on the table under it
		local holder = Ui.new("Frame", {
			Name = "Dossier",
			Size = UDim2.fromOffset(460, 420),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -1.2,
			BackgroundTransparency = 1,
			ZIndex = 41,
			Parent = gui,
		})
		local shadow = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(7, 9),
			BackgroundColor3 = Theme.Color.black,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = holder,
		})
		Ui.corner(2).Parent = shadow
		local paper = Ui.new("Frame", {
			Name = "Sheet",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.paper,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = holder,
		})
		Ui.corner(2).Parent = paper
		Ui.stroke(Theme.Color.paperShade, 1, 0).Parent = paper
		-- the age the sheet has gathered towards its foot
		local age = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.paperShade,
			BorderSizePixel = 0,
			Parent = paper,
		})
		Ui.corner(2).Parent = age
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.7, 0.85),
				NumberSequenceKeypoint.new(1, 0.45),
			}),
			Parent = age,
		})
		-- a brass paper clip over the top edge
		for i, inset in { 0, 4 } do
			local loop = Ui.new("Frame", {
				Size = UDim2.fromOffset(14 - inset * 2, 42 - inset * 3),
				Position = UDim2.fromOffset(236 + inset, -12 + inset),
				Rotation = -6,
				BackgroundTransparency = 1,
				ZIndex = 4 + i,
				Parent = paper,
			})
			Ui.corner(7).Parent = loop
			Ui.stroke(Theme.Color.brass, 2, 0).Parent = loop
		end

		local function label(
			text: string,
			x: number,
			y: number,
			w: number,
			props: { [string]: any }?
		): TextLabel
			local p: { [string]: any } = props or {}
			local l = Ui.text({
				Text = text,
				Font = p.Font or Theme.Font.type,
				TextSize = p.TextSize or 12,
				Color = p.Color or Theme.Color.inkSoft,
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w, p.Height or (p.TextSize or 12) + 4),
				XAlign = p.XAlign,
				Wrapped = p.Wrapped,
			})
			l.ZIndex = 3
			l.Parent = paper
			return l
		end
		local function rule(y: number, thick: number, x: number?, w: number?)
			Ui.new("Frame", {
				Size = UDim2.fromOffset(w or 404, thick),
				Position = UDim2.fromOffset(x or 28, y),
				BackgroundColor3 = Theme.Color.ink,
				BackgroundTransparency = if thick > 1 then 0 else 0.55,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = paper,
			})
		end

		-- heading
		label("STATION DOSSIER", 28, 22, 200)
		label(`LINE {string.char(64 + index)}`, 232, 22, 200, { XAlign = Enum.TextXAlignment.Right })
		local title = label(
			string.upper(arch.name),
			28,
			38,
			290,
			{ Font = HEAVY, TextSize = 26, Color = Theme.Color.ink }
		)
		title.TextScaled = true
		Ui.new("UITextSizeConstraint", { MaxTextSize = 26, Parent = title })
		rule(76, 2)
		rule(81, 1)
		-- the danger stamp, struck a little crooked
		local stamp = Ui.new("TextLabel", {
			Size = UDim2.fromOffset(118, 34),
			Position = UDim2.fromOffset(326, 36),
			Rotation = 7,
			BackgroundTransparency = 1,
			Text = if arch.terminus then "TERMINUS" else `DANGER {string.rep("I", option.tier)}`,
			FontFace = HEAVY,
			TextSize = 18,
			TextColor3 = Theme.Color.signal,
			TextTransparency = 0.12,
			ZIndex = 6,
			Parent = paper,
		})
		Ui.corner(3).Parent = stamp
		Ui.stroke(Theme.Color.signal, 2.5, 0.2).Parent = stamp

		-- left column: the leg
		local y = 94
		label("THE LEG", 28, y, 180, { Font = BOLD, TextSize = 12, Color = Theme.Color.ink })
		y += 20
		local bunker = if train then math.floor(train.coal) else nil
		local legRows = {
			{ "DISTANCE", `{option.distanceKm} KM` },
			{
				"COAL BURN",
				if bunker then `{cost} OF {bunker} IN THE BUNKER` else `{cost} COAL`,
			},
			{
				"TIME AT THE STOP",
				if arch.dwellMultiplier > 1.02
					then "LONGER THAN USUAL"
					elseif arch.dwellMultiplier < 0.98 then "SHORTER THAN USUAL"
					else "THE USUAL",
			},
			{ "LAID OUT AS", if arch.layout then words(arch.layout.style) else "SCATTERED" },
			{ "UNDERFOOT", words(arch.ground) },
		}
		for i, row in legRows do
			label(row[1], 28, y, 190, { TextSize = 11 })
			label(row[2], 28, y + 13, 190, {
				Font = Theme.Font.display,
				TextSize = 16,
				Color = if i == 2 and short then Theme.Color.signal else Theme.Color.ink,
			})
			y += 31
		end
		if arch.layout then
			label(
				LAYOUT_TEXT[arch.layout.style] or "",
				28,
				y - 2,
				190,
				{ TextSize = 10, Height = 26, Wrapped = true }
			)
		end

		-- right column: the haul and the dangers, five boxes each (three is ordinary)
		local function level(m: number): number
			return math.clamp(math.floor(m * 2.5 + 0.5), 1, 5)
		end
		local ry = 94
		local function meterRow(name: string, m: number, color: Color3)
			label(name, 244, ry, 90, { TextSize = 11 })
			local row = boxes(level(m), 5, color, 18, 8, 3, Theme.Color.paperShade, Theme.Color.inkSoft)
			row.Position = UDim2.fromOffset(342, ry + 4)
			row.Parent = paper
			ry += 18
		end
		label("THE HAUL", 244, ry, 180, { Font = BOLD, TextSize = 12, Color = Theme.Color.ink })
		ry += 20
		meterRow("COAL", arch.loot.coal, Theme.Color.ink)
		meterRow("PARTS", arch.loot.parts, Theme.Color.ink)
		meterRow("RELICS", arch.loot.relic, Theme.Color.ink)
		meterRow("TOOLS", arch.loot.tools, Theme.Color.ink)
		ry += 10
		label("THE DANGERS", 244, ry, 180, { Font = BOLD, TextSize = 12, Color = Theme.Color.signalDark })
		ry += 20
		meterRow("COLLAPSE", arch.hazard.collapse, Theme.Color.signal)
		meterRow("FOG", arch.hazard.fog, Theme.Color.signal)
		meterRow("HOLLOWS", arch.hazard.hollows, Theme.Color.signal)

		-- what stands in the yard
		rule(300, 1)
		local found = {}
		local kinds = {}
		for kind in arch.containers do
			table.insert(kinds, kind)
		end
		table.sort(kinds)
		for _, kind in kinds do
			local count = arch.containers[kind]
			table.insert(found, `{count} {plural(words(kind), count)}`)
		end
		if arch.looseItems > 0 then
			table.insert(found, `{arch.looseItems} LOOSE`)
		end
		label("ON THE GROUND", 28, 308, 200, { TextSize = 11 })
		label(table.concat(found, "  ·  "), 28, 322, 200, {
			Font = Theme.Font.display,
			TextSize = 13,
			Color = Theme.Color.ink,
			Height = 36,
			Wrapped = true,
		})
		local inside = {}
		local landmarks: { Stations.LandmarkRule } = arch.landmarks or {}
		for _, landmark in landmarks do
			table.insert(inside, words(landmark.kind))
		end
		label("TO SEARCH INSIDE", 244, 308, 190, { TextSize = 11 })
		label(if #inside > 0 then table.concat(inside, "  ·  ") else "NOTHING WITH A DOOR", 244, 322, 190, {
			Font = Theme.Font.display,
			TextSize = 13,
			Color = Theme.Color.ink,
			Height = 36,
			Wrapped = true,
		})

		-- the clerk's note in blue ink, and the foot of the sheet
		local note = label(`Clerk's note: {option.hint}.`, 28, 362, 290, { TextSize = 14, Color = BLUE_INK })
		note.Rotation = -1.5
		if short then
			label(
				"Not enough coal: the hull will suffer",
				28,
				380,
				290,
				{ TextSize = 11, Color = Theme.Color.signal }
			)
		end
		label("FILED AT THE JUNCTION  ·  LAST TRAIN OUT", 28, 398, 300, { TextSize = 9 })
		local close = Ui.button("CLOSE", "Primary", function()
			closeDossier()
			render()
		end, {
			Size = UDim2.fromOffset(92, 30),
			Position = UDim2.new(1, -28, 1, -16),
			AnchorPoint = Vector2.new(1, 1),
			TextSize = 14,
		})
		close.BackgroundColor3 = Theme.Color.ink
		close.TextColor3 = Theme.Color.white
		close.FontFace = HEAVY
		close.ZIndex = 3
		close.Parent = paper
		return holder
	end

	local function openDossier(index: number)
		openIndex = index
		backdrop.Visible = true
		ContextActionService:BindActionAtPriority("LTO_CloseDossier", function(_, inputState)
			if inputState == Enum.UserInputState.Begin and openIndex then
				closeDossier()
				render()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, 3000, Enum.KeyCode.ButtonB)
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
		Color = Theme.Color.paper,
		Size = UDim2.fromOffset(0, 26),
		Position = UDim2.new(0.5, 0, 0, 318),
		XAlign = Enum.TextXAlignment.Center,
	})
	tieNote.AnchorPoint = Vector2.new(0.5, 0)
	tieNote.AutomaticSize = Enum.AutomaticSize.X
	tieNote.BackgroundColor3 = Theme.Color.steel
	tieNote.BackgroundTransparency = 0.15
	Ui.padding(0, 12, 0, 12).Parent = tieNote
	Ui.stroke(Theme.Color.steelLine, 1, 0.3).Parent = tieNote
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
		if dossier then
			dossier:Destroy()
			dossier = nil
		end
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
			if openIndex then
				closeDossier()
			end
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
			local shortest, longest = math.huge, 0
			for _, option in options do
				shortest = math.min(shortest, option.distanceKm)
				longest = math.max(longest, option.distanceKm)
			end
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
					track = TicketModel.track(option.distanceKm, shortest, longest),
					LayoutOrder = index,
					onVote = function()
						castVote(index)
					end,
					onFlap = function()
						if openIndex == index then
							closeDossier()
						else
							openDossier(index)
						end
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

		-- a sealed mystery has no dossier (Ticket hides its flap)
		if openIndex and options[openIndex] and not options[openIndex].mystery then
			local option = options[openIndex]
			local cost = Ledger.legCoalCost(train or Ledger.newTrain(), option.distanceKm)
			dossier = buildDossier(openIndex, option, cost, train ~= nil and cost > train.coal, train)
		elseif openIndex then
			closeDossier()
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
