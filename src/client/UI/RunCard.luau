--!strict
--[[
	The end-of-run card, one screen, shown once per run when it ends (win or wipe): the crew's
	headshots, the route as the ticket book's track (UI/TicketBook) with the stubs and stamps landing
	in a fast cascade (bare stubs on a rail line: number, name, seal, the gamble's stamp), one line of
	totals and a final stamp ("TERMINUS", "DERAILED AT STOP 6"). Aged card stock in a worn double
	border with brass corner fittings, a leather title banner and punched holes, sized to what it
	holds (at most 1056 wide) inside the ScreenGui's safe insets, clear of the Roblox topbar. It sits
	above the run receipt (UI/Summary) and closes with CLOSE, the backdrop or gamepad B. H hides the
	CLOSE button and its hint, for a clean screenshot.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunLog = require(ReplicatedStorage.Shared.Logic.RunLog)

local Registry = require(script.Parent.Parent.Registry)
local Stamp = require(script.Parent.Stamp)
local Theme = require(script.Parent.Theme)
local TicketBook = require(script.Parent.TicketBook)
local Ui = require(script.Parent.Ui)

local RunCard = {}

local MAX_W, MIN_W = 1056, 720
local PAD = 32
local STUB_W = 200 -- Ticket.stub's own width (TicketBook lays the stubs out at a scale)
local GAP = 10 -- TicketBook's gap between stubs
local MAX_SCALE = 0.8 -- the stubs stay small notes on the line, however short the run
local ROW_GAP = 6
local BANNER_INSET = 14
local TRACK_TOP = 150
local STEP = 0.11 -- seconds between stubs in the cascade
local Z = 60
local WIN = Color3.fromRGB(40, 110, 62)
local OUTCOME_TEXT: { [string]: string } = {
	Victory = "REACHED THE TERMINUS",
	Wiped = "THE CREW WAS LOST",
	Derailed = "THE TRAIN BROKE DOWN",
}

local KEEP = { Close = true, Hint = true, Dress = true, Grain = true, Perforation = true }

local root: TextButton
local card: ImageLabel
local closeButton: TextButton
local hint: TextLabel
local shownFor: string? = nil

local function plural(n: number, word: string): string
	return `{n} {word}{if n == 1 then "" else "S"}`
end

local function hide()
	if root.Visible then
		root.Visible = false
		ContextActionService:UnbindAction("LTO_RunCard")
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
	end
end

local function text(props: { [string]: any }): TextLabel
	local l = Ui.text(props :: any)
	l.ZIndex = Z + 3
	l.Parent = card
	return l
end

local function crewRow(): Frame
	local row = Ui.new("Frame", {
		Name = "Crew",
		Size = UDim2.new(1, -2 * PAD, 0, 70),
		Position = UDim2.fromOffset(PAD, 72),
		BackgroundTransparency = 1,
		ZIndex = Z + 2,
		Parent = card,
	})
	Ui.list(Enum.FillDirection.Horizontal, 18).Parent = row
	local crew = Registry.StateController.Get({ "crew" }) or {}
	local keys: { string } = {}
	for key in crew do
		table.insert(keys, key)
	end
	table.sort(keys)
	for i, key in keys do
		local slot = Ui.new("Frame", {
			Size = UDim2.fromOffset(110, 70),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = Z + 2,
			Parent = row,
		})
		local mark = Stamp.new({ key = key, name = crew[key].name, mine = true, ZIndex = Z + 3 })
		mark.Position = UDim2.fromOffset(55, 22)
		mark.Parent = slot
		local name = Ui.text({
			Text = crew[key].name,
			Font = Theme.Font.bodyBold,
			TextSize = 13,
			Color = if crew[key].status == "Eliminated" then Theme.Color.inkSoft else Theme.Color.ink,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, 18),
			XAlign = Enum.TextXAlignment.Center,
		})
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = Z + 3
		name.Parent = slot
	end
	return row
end

-- The leather title banner: brass-ruled, riveted at its ends, the outcome on the right.
local function banner(outcome: string?, tier: number)
	local band = Ui.new("Frame", {
		Name = "Banner",
		Size = UDim2.new(1, -2 * BANNER_INSET, 0, 48),
		Position = UDim2.fromOffset(BANNER_INSET, BANNER_INSET),
		BackgroundColor3 = Theme.Color.leather,
		BorderSizePixel = 0,
		ZIndex = Z + 3,
		Parent = card,
	})
	Ui.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 130, 124)),
		Parent = band,
	})
	for _, y in { 0, 1 } do
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.fromScale(0, y),
			AnchorPoint = Vector2.new(0, y),
			BackgroundColor3 = Theme.Color.brass,
			BorderSizePixel = 0,
			ZIndex = Z + 4,
			Parent = band,
		})
	end
	for _, x in { 0, 1 } do
		for _, y in { 0, 1 } do
			Ui.new("ImageLabel", {
				Size = UDim2.fromOffset(9, 9),
				Position = UDim2.new(x, if x > 0 then -6 else 6, y, if y > 0 then -8 else 8),
				AnchorPoint = Vector2.new(x, y),
				BackgroundTransparency = 1,
				Image = Theme.Image.rivet,
				ZIndex = Z + 5,
				Parent = band,
			})
		end
	end
	local caption = Ui.text({
		Text = "LAST TRAIN OUT  ·  CREW COPY",
		Font = Theme.Font.displayMedium,
		TextSize = 11,
		Color = Theme.Color.brass,
		Position = UDim2.fromOffset(22, 4),
		Size = UDim2.fromOffset(260, 13),
	})
	caption.ZIndex = Z + 5
	caption.Parent = band
	local title = Ui.text({
		Text = "RUN CARD",
		Font = Theme.Font.display,
		TextSize = 26,
		Color = Theme.Color.bone,
		Position = UDim2.fromOffset(22, 15),
		Size = UDim2.fromOffset(260, 30),
	})
	title.ZIndex = Z + 5
	title.Parent = band
	local sub = Ui.text({
		Text = `{OUTCOME_TEXT[outcome :: any] or ""}  ·  RUN TIER {tier}`,
		Font = Theme.Font.type,
		TextSize = 15,
		Color = Theme.Color.boneDim,
		Position = UDim2.new(1, -22, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(420, 22),
		XAlign = Enum.TextXAlignment.Right,
	})
	sub.Name = "Outcome"
	sub.ZIndex = Z + 5
	sub.Parent = band
end

local function show()
	local State = Registry.StateController
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") and not KEEP[child.Name] then
			child:Destroy()
		end
	end
	local log = State.Get({ "run", "log" }) or {}
	local outcome = State.Get({ "run", "outcome" })
	local tier = State.Get({ "run", "tier" }) or 1
	-- read by the light the run ended in: the blood moon staining the edges, or the Terminus lamps
	local won = outcome == "Victory"
	card.BackgroundColor3 =
		Theme.Color.paper:Lerp(if won then Theme.Color.amber else Theme.Color.signalDark, 0.08)
	Ui.new("ImageLabel", {
		Name = "Moonlight",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.vignette,
		ImageColor3 = if won then Theme.Color.mahogany else Theme.Color.signalDark,
		ImageTransparency = if won then 0.55 else 0.5,
		ZIndex = Z + 1,
		Parent = card,
	})
	banner(outcome, tier)
	crewRow()

	-- the stubs as small notes on the line: up to five on a row, six for a long run, each row centred
	local plays: { (number) -> number } = {}
	local perRow = if #log <= 5 then math.max(#log, 1) elseif #log <= 10 then 5 else 6
	local scale = math.min(MAX_SCALE, ((MAX_W - 2 * PAD) / perRow - GAP) / STUB_W)
	local rows = math.max(math.ceil(#log / perRow), 1)
	local rowH, widest = 0, 0
	local trackRows: { Frame } = {}
	for r = 1, rows do
		local slice = table.move(log, (r - 1) * perRow + 1, math.min(r * perRow, #log), 1, {})
		local row, play =
			TicketBook.track(slice, { scale = scale, ink = Theme.Color.ink, ZIndex = Z + 2, bare = true })
		rowH = row.Size.Y.Offset
		widest = math.max(widest, row.Size.X.Offset)
		row.Parent = card
		table.insert(trackRows, row)
		table.insert(plays, play)
	end
	local w = math.clamp(widest + 2 * PAD, MIN_W, MAX_W)
	for r, row in trackRows do
		row.Position =
			UDim2.fromOffset(math.floor((w - row.Size.X.Offset) / 2), TRACK_TOP + (r - 1) * (rowH + ROW_GAP))
	end
	local y = TRACK_TOP + rows * (rowH + ROW_GAP)
	if #log == 0 then
		text({
			Text = "The train never left the depot.",
			Font = Theme.Font.body,
			TextSize = 16,
			Color = Theme.Color.inkSoft,
			Position = UDim2.fromOffset(PAD, TRACK_TOP + 6),
			Size = UDim2.fromOffset(500, 22),
		})
		y = TRACK_TOP + 34
	end

	-- one line of totals over a hairline rule
	local totals = RunLog.totals(log)
	Ui.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -2 * PAD, 0, 1),
		Position = UDim2.fromOffset(PAD, y),
		BackgroundColor3 = Theme.Color.ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = Z + 2,
		Parent = card,
	})
	text({
		Text = `{totals.km} KM   ·   {plural(totals.stops, "STOP")}   ·   {totals.loot} LOOT`,
		Font = Theme.Font.type,
		TextSize = 17,
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(PAD, y + 6),
		Size = UDim2.new(1, -2 * PAD, 0, 22),
		XAlign = Enum.TextXAlignment.Center,
	}).Name =
		"Totals"
	card.Size = UDim2.fromOffset(w, y + 6 + 22 + 14 + 38 + PAD)

	-- the final stamp, struck across the foot of the card beside CLOSE
	local final = Stamp.word({
		key = `final{outcome}`,
		text = RunLog.final(outcome, RunLog.endStop(log, State.Get({ "run", "nextStop" }))),
		color = if outcome == "Victory" then WIN else Theme.Color.signal,
		size = 30,
		Position = UDim2.new(1, -PAD - 150, 1, -PAD - 22),
		ZIndex = Z + 10,
	})
	final.Parent = card

	root.Visible = true
	GuiService.SelectedObject = closeButton
	ContextActionService:BindActionAtPriority("LTO_RunCard", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.H then
			closeButton.Visible = not closeButton.Visible
			hint.Visible = closeButton.Visible
		else
			hide()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3100, Enum.KeyCode.ButtonB, Enum.KeyCode.H)

	-- the cascade: the rows one after another, then the final stamp
	final.Visible = false
	local at = 0.25
	for _, play in plays do
		task.delay(at, function()
			play(STEP)
		end)
		at += math.min(perRow, #log) * STEP
	end
	task.delay(at + 0.35, function()
		final.Visible = true
		Stamp.land(final)
		if Registry.AudioController then
			Registry.AudioController.Play("TicketPunch")
		end
	end)
	-- hide the rows until their turn
	for _, child in card:GetChildren() do
		if child.Name == "Track" then
			for _, cell in child:GetChildren() do
				if cell:IsA("Frame") and cell.Name ~= "Line" then
					cell.Visible = false
				end
			end
		end
	end
end

function RunCard.mount(gui: ScreenGui)
	root = Ui.new("TextButton", {
		Name = "RunCard",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = Z,
		Parent = gui,
	})
	root.Activated:Connect(hide)
	card = Ui.ticket({
		Name = "Card",
		Size = UDim2.fromOffset(MIN_W, 400), -- show() fits it to the run
		-- centred in the visible area (the root reaches 60 above it and 20 below)
		Position = UDim2.new(0.5, 0, 0.5, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Active = true,
		ZIndex = Z + 1,
		Parent = root,
	})
	Ui.stroke(Theme.Color.inkSoft, 1, 0.4).Parent = card
	-- the wear that stays: a double border, brass corner fittings, punched holes, a ring stain
	local dress = Ui.new("Frame", {
		Name = "Dress",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Z + 2,
		Parent = card,
	})
	for _, inset in { 7, 11 } do
		local border = Ui.new("Frame", {
			Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
			Position = UDim2.fromOffset(inset, inset),
			BackgroundTransparency = 1,
			ZIndex = Z + 2,
			Parent = dress,
		})
		Ui.corner(2).Parent = border
		local outer = inset == 7
		Ui.stroke(if outer then Theme.Color.ink else Theme.Color.tarnish, 1, if outer then 0.55 else 0.35).Parent =
			border
	end
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local at =
			UDim2.new(corner.X, if corner.X > 0 then -3 else 3, corner.Y, if corner.Y > 0 then -3 else 3)
		for _, long in { true, false } do
			local arm = Ui.new("Frame", {
				Size = if long then UDim2.fromOffset(26, 5) else UDim2.fromOffset(5, 26),
				Position = at,
				AnchorPoint = corner,
				BackgroundColor3 = Theme.Color.brass,
				BorderSizePixel = 0,
				ZIndex = Z + 6,
				Parent = dress,
			})
			Ui.stroke(Theme.Color.tarnish, 1, 0.2).Parent = arm
		end
		Ui.new("ImageLabel", {
			Size = UDim2.fromOffset(9, 9),
			Position = at + UDim2.fromOffset(if corner.X > 0 then -8 else 8, if corner.Y > 0 then -8 else 8),
			AnchorPoint = corner,
			BackgroundTransparency = 1,
			Image = Theme.Image.rivet,
			ZIndex = Z + 7,
			Parent = dress,
		})
	end
	for _, dy in { -16, 16 } do
		Ui.new("ImageLabel", {
			Name = "Punch",
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(1, -24, 0.5, dy),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.Image.punch,
			ImageColor3 = Theme.Color.steel,
			ZIndex = Z + 3,
			Parent = dress,
		})
	end
	local ring = Ui.new("Frame", {
		Name = "Ring",
		Size = UDim2.fromOffset(96, 96),
		Position = UDim2.new(1, -150, 0, 58),
		BackgroundTransparency = 1,
		ZIndex = Z + 2,
		Parent = dress,
	})
	Ui.corner(48).Parent = ring
	Ui.stroke(Theme.Color.paperShade, 4, 0.78).Parent = ring
	closeButton = Ui.button("CLOSE", "Secondary", hide, {
		Name = "Close",
		Size = UDim2.fromOffset(110, 38),
		Position = UDim2.new(0, PAD, 1, -PAD - 38),
		TextSize = 17,
	})
	closeButton.ZIndex = Z + 4
	closeButton.Parent = card
	hint = Ui.text({
		Name = "Hint",
		Text = "H: hide the button for a screenshot",
		Font = Theme.Font.body,
		TextSize = 12,
		Color = Theme.Color.inkSoft,
		Position = UDim2.new(0, PAD + 122, 1, -PAD - 30),
		Size = UDim2.fromOffset(230, 22),
	})
	hint.ZIndex = Z + 4
	hint.Parent = card

	-- the receipt opens under the card a moment later and grabs gamepad selection; take it back
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local selected = GuiService.SelectedObject
		if root.Visible and closeButton.Visible and selected and not selected:IsDescendantOf(root) then
			GuiService.SelectedObject = closeButton
		end
	end)

	local State = Registry.StateController
	State.Observe("public", { "run", "phase" }, function(phase)
		if phase == "RunEnd" then
			local runId = State.Get({ "run", "runId" })
			if shownFor ~= runId then
				shownFor = runId
				-- the last stop's entry lands in the same flush as the phase; let it settle
				task.delay(0.3, show)
			end
		elseif phase ~= "Lobby" then
			hide()
		end
	end)
end

-- Studio check: draw the card for whatever run.log holds now.
function RunCard.show()
	show()
end

return RunCard
