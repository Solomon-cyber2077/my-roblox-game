--!strict
--[[
	The end-of-run card, one screen, shown once per run when it ends (win or wipe): the crew's
	headshots, the route as the ticket book's track (UI/TicketBook) with the stubs and stamps landing
	in a fast cascade, total km and coal burned, and a final stamp ("TERMINUS", "DERAILED AT STOP 6").
	A 16:9 card (1056x594) inside the ScreenGui's safe insets, so clear of the Roblox topbar. It sits
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

local W, H = 1056, 594
local PAD = 32
local STUB_W = 200 -- Ticket.stub's own width (TicketBook lays the stubs out at a scale)
local GAP = 10 -- TicketBook's gap between stubs
local MAX_SCALE = 1.15 -- a short run's stubs are drawn large enough to read
local ROW_GAP = 8
local FOOT_LOWEST = 440 -- the totals line never sinks into the final stamp
local STEP = 0.11 -- seconds between stubs in the cascade
local Z = 60
local WIN = Color3.fromRGB(40, 110, 62)
local OUTCOME_TEXT: { [string]: string } = {
	Victory = "REACHED THE TERMINUS",
	Wiped = "THE CREW WAS LOST",
	Derailed = "THE TRAIN BROKE DOWN",
}

local root: TextButton
local card: Frame
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
		Position = UDim2.fromOffset(PAD, 76),
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

local function show()
	local State = Registry.StateController
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Close" and child.Name ~= "Hint" then
			child:Destroy()
		end
	end
	local log = State.Get({ "run", "log" }) or {}
	local outcome = State.Get({ "run", "outcome" })
	local tier = State.Get({ "run", "tier" }) or 1

	text({
		Text = "RUN CARD",
		Font = Theme.Font.display,
		TextSize = 34,
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(PAD, 18),
		Size = UDim2.fromOffset(300, 44),
	})
	local sub = text({
		Text = `{OUTCOME_TEXT[outcome] or ""}  ·  RUN TIER {tier}`,
		Font = Theme.Font.type,
		TextSize = 16,
		Color = Theme.Color.inkSoft,
		Position = UDim2.new(1, -PAD, 0, 26),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(560, 28),
		XAlign = Enum.TextXAlignment.Right,
	})
	sub.Name = "Outcome"
	local rule = Ui.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -2 * PAD, 0, 2),
		Position = UDim2.fromOffset(PAD, 64),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		ZIndex = Z + 2,
		Parent = card,
	})
	rule.BackgroundTransparency = 0.2
	crewRow()

	-- the stubs as large as the run allows: up to four on a row, five or six for a long run,
	-- each row centred on the card
	local plays: { (number) -> number } = {}
	local perRow = if #log <= 4 then math.max(#log, 1) elseif #log <= 10 then 5 else 6
	local scale = math.min(MAX_SCALE, ((W - 2 * PAD) / perRow - GAP) / STUB_W)
	local rows = math.max(math.ceil(#log / perRow), 1)
	local rowH = 0
	for r = 1, rows do
		local slice = table.move(log, (r - 1) * perRow + 1, math.min(r * perRow, #log), 1, {})
		local row, play = TicketBook.track(slice, { scale = scale, ink = Theme.Color.ink, ZIndex = Z + 2 })
		rowH = row.Size.Y.Offset
		row.Position =
			UDim2.fromOffset(math.floor((W - row.Size.X.Offset) / 2), 162 + (r - 1) * (rowH + ROW_GAP))
		row.Parent = card
		table.insert(plays, play)
	end
	if #log == 0 then
		text({
			Text = "The train never left the depot.",
			Font = Theme.Font.body,
			TextSize = 16,
			Color = Theme.Color.inkSoft,
			Position = UDim2.fromOffset(PAD, 190),
			Size = UDim2.fromOffset(500, 22),
		})
	end

	local totals = RunLog.totals(log)
	local foot = text({
		Text = `{totals.km} KM   ·   COAL BURNED x{math.floor(totals.coal * 10 + 0.5) / 10}   ·   {plural(
			totals.stops,
			"STOP"
		)}   ·   {plural(totals.closeCalls, "CLOSE CALL")}   ·   {totals.loot} LOOT   ·   {plural(
			totals.downs,
			"DOWN"
		)}`,
		Font = Theme.Font.type,
		TextSize = 20,
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(PAD, math.min(162 + rows * (rowH + ROW_GAP) + 18, FOOT_LOWEST)),
		Size = UDim2.new(1, -2 * PAD, 0, 28),
		XAlign = Enum.TextXAlignment.Center,
	})
	foot.TextScaled = true -- a long run shrinks to the card's width
	Ui.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = foot })
	local final = Stamp.word({
		key = `final{outcome}`,
		text = RunLog.final(outcome, RunLog.endStop(log, State.Get({ "run", "nextStop" }))),
		color = if outcome == "Victory" then WIN else Theme.Color.signal,
		size = 38,
		Position = UDim2.new(1, -PAD - 190, 0, 510),
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
		Size = UDim2.fromOffset(W, H),
		-- centred in the visible area (the root reaches 60 above it and 20 below)
		Position = UDim2.new(0.5, 0, 0.5, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Active = true,
		ZIndex = Z + 1,
		Parent = root,
	})
	Ui.stroke(Theme.Color.inkSoft, 1, 0.4).Parent = card
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
		TextSize = 13,
		Color = Theme.Color.inkSoft,
		Position = UDim2.new(0, PAD + 124, 1, -PAD - 30),
		Size = UDim2.fromOffset(280, 22),
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
