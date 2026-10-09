--!strict
--[[
	The run's ticket book: every resolved stop (run.log, Logic/RunLog) as a ticket stub hung from an
	inked track, in stop order, with its stamps (CLOSE CALL, GAMBLED, UNANIMOUS). B or the gamepad's
	D-pad left opens it during a run; it redraws as stops resolve. TicketBook.track draws one row of
	the track and is shared with UI/RunCard, whose cascade it plays.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunLog = require(ReplicatedStorage.Shared.Logic.RunLog)
local TicketModel = require(ReplicatedStorage.Shared.Logic.TicketModel)

local Registry = require(script.Parent.Parent.Registry)
local Modal = require(script.Parent.Modal)
local Stamp = require(script.Parent.Stamp)
local Theme = require(script.Parent.Theme)
local Ticket = require(script.Parent.Ticket)
local Ui = require(script.Parent.Ui)

local TicketBook = {}

local STUB_W, STUB_H = 200, 72 -- Ticket.stub's own size
local LINE_Y = 10 -- the track, from the row's top
local HANG = 24 -- the stub's top, from the row's top
local GAP = 10
local POP_SECONDS = 0.14

local STAMP_COLOR: { [string]: Color3 } = {
	CloseCall = Color3.fromRGB(176, 40, 34),
	Gambled = Color3.fromRGB(96, 52, 140),
	Unanimous = Color3.fromRGB(38, 58, 120),
}
local DOT_COLOR: { [string]: Color3 } = {
	Cleared = Theme.Color.ink,
	Victory = Theme.Color.brass,
	Wiped = Theme.Color.signal,
	Derailed = Theme.Color.signal,
}

-- `bare` (the run card): stubs without figures, no haul line, only the gamble's stamp, and the
-- line drawn as rails on sleepers
export type TrackOpts = { scale: number, ink: Color3, ZIndex: number, LayoutOrder: number?, bare: boolean? }

-- One row of the track: a stub per entry, left to right. Returns the row and `play(step)`, which hides
-- everything and brings each stub in `step` seconds apart, then lands its stamps; it returns the
-- seconds the cascade takes.
function TicketBook.track(entries: { any }, opts: TrackOpts): (Frame, (step: number) -> number)
	local s, z = opts.scale, opts.ZIndex
	local bare = opts.bare == true
	local stubH = if bare then Ticket.STUB_BARE_H else STUB_H
	local cellW, cellH = math.ceil(STUB_W * s) + GAP, math.ceil(stubH * s) + HANG + (if bare then 6 else 16)
	local row = Ui.new("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(cellW * #entries, cellH),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = z,
	})
	local rail = Ui.new("Frame", {
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.fromOffset(0, LINE_Y - 1),
		BackgroundColor3 = opts.ink,
		BackgroundTransparency = if bare then 1 else 0,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = row,
	})
	if bare then
		-- two rails on sleepers, inked like a timetable's route map
		for _, y in { -2, 3 } do
			Ui.new("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, y),
				BackgroundColor3 = opts.ink,
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = rail,
			})
		end
		for x = 3, cellW * #entries - 3, 9 do
			Ui.new("Frame", {
				Size = UDim2.fromOffset(2, 9),
				Position = UDim2.fromOffset(x, -3),
				BackgroundColor3 = opts.ink,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = rail,
			})
		end
	end
	local cells: { { stub: Frame, pop: UIScale, stamps: { Frame } } } = {}
	for i, entry in entries do
		local cell = Ui.new("Frame", {
			Name = `Stop{entry.stop}`,
			Size = UDim2.fromOffset(cellW, cellH),
			Position = UDim2.fromOffset((i - 1) * cellW, 0),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = row,
		})
		local dot = Ui.new("Frame", {
			Name = "Dot",
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromOffset(cellW / 2, LINE_Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = DOT_COLOR[entry.outcome] or opts.ink,
			BorderSizePixel = 0,
			ZIndex = z + 1,
			Parent = cell,
		})
		Ui.corner(6).Parent = dot
		Ui.new("Frame", {
			Name = "String",
			Size = UDim2.fromOffset(2, HANG - LINE_Y),
			Position = UDim2.fromOffset(cellW / 2 - 1, LINE_Y),
			BackgroundColor3 = opts.ink,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = cell,
		})
		local view = TicketModel.view(RunLog.option(entry), entry.stop, entry.coalBurned)
		local stub = Ticket.stub(view, { routeId = `log{entry.stop}{entry.archetype}`, bare = bare })
		stub.Position = UDim2.fromOffset(GAP / 2, HANG)
		stub.ZIndex = z + 1
		stub.Parent = cell
		Ui.new("UIScale", { Scale = s, Parent = stub })
		local haul = if bare then "" else RunLog.haulText(entry)
		if haul ~= "" then
			local line = Ui.text({
				Text = haul,
				Font = Theme.Font.type,
				TextSize = math.max(math.floor(13 * s + 0.5), 10),
				Color = opts.ink,
				Position = UDim2.fromOffset(GAP / 2, HANG + math.ceil(STUB_H * s) + 1),
				Size = UDim2.fromOffset(math.ceil(STUB_W * s), 14),
			})
			line.Name = "Haul"
			line.TextScaled = true -- a long haul shrinks to the stub's width
			Ui.new("UITextSizeConstraint", { MaxTextSize = line.TextSize, Parent = line })
			line.ZIndex = z + 1
			line.Parent = cell
		end
		local pop = Ui.new("UIScale", { Parent = cell })
		local stamps: { Frame } = {}
		local marks = RunLog.stamps(entry)
		if bare then
			marks = table.clone(marks)
			for k = #marks, 1, -1 do
				if marks[k].kind ~= "Gambled" then
					table.remove(marks, k)
				end
			end
		end
		for k, mark in marks do
			local stamp = Stamp.word({
				key = `{entry.stop}{mark.kind}`,
				text = mark.text,
				color = STAMP_COLOR[mark.kind],
				size = math.max(math.floor(13 * s + 0.5), 9),
				Position = UDim2.fromOffset(
					GAP / 2 + STUB_W * s * (0.58 + 0.08 * (k - 1)),
					HANG + stubH * s * (0.3 + 0.36 * (k - 1))
				),
				ZIndex = z + 8,
			})
			stamp.Parent = cell
			table.insert(stamps, stamp)
		end
		table.insert(cells, { stub = cell, pop = pop, stamps = stamps })
	end
	local function play(step: number): number
		for i, c in cells do
			c.stub.Visible = false
			task.delay((i - 1) * step, function()
				c.stub.Visible = true
				c.pop.Scale = 0.8
				Ui.tween(c.pop, { Scale = 1 }, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back))
				for k, stamp in c.stamps do
					stamp.Visible = false
					task.delay(POP_SECONDS + (k - 1) * 0.08, function()
						stamp.Visible = true
						Stamp.land(stamp)
					end)
				end
			end)
		end
		return #cells * step + POP_SECONDS
	end
	return row, play
end

local modal: Modal.Modal

local function render()
	local body = modal.body
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	local log = Registry.StateController.Get({ "run", "log" }) or {}
	if #log == 0 then
		local empty = Ui.text({
			Text = "No stops yet. Every stop the train leaves gets a stub here.",
			Font = Theme.Font.body,
			TextSize = 16,
			Color = Theme.Color.textDim,
			Size = UDim2.fromScale(1, 1),
			XAlign = Enum.TextXAlignment.Center,
		})
		empty.ZIndex = 33
		empty.Parent = body
		return
	end
	local scroll = Ui.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.brass,
		ZIndex = 33,
		Parent = body,
	})
	local row = TicketBook.track(log, { scale = 1, ink = Theme.Color.paperShade, ZIndex = 33 })
	row.Position = UDim2.fromOffset(0, 24)
	row.Parent = scroll
	local totals = RunLog.totals(log)
	local foot = Ui.text({
		Text = `{totals.km} KM  ·  COAL BURNED x{math.floor(totals.coal * 10 + 0.5) / 10}  ·  {totals.stops} STOP{if totals.stops
				== 1
			then ""
			else "S"}  ·  {totals.loot} LOOT  ·  {totals.downs} DOWN{if totals.downs == 1 then "" else "S"}`,
		Font = Theme.Font.type,
		TextSize = 16,
		Color = Theme.Color.paper,
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 22),
	})
	foot.ZIndex = 33
	foot.Parent = body
	scroll.Size = UDim2.new(1, 0, 1, -28)
	scroll.CanvasPosition = Vector2.new(math.huge, 0) -- the latest stop in view
end

local function inRun(): boolean
	local phase = Registry.StateController.Get({ "run", "phase" })
	return phase ~= nil and phase ~= "Lobby" and phase ~= "Countdown"
end

function TicketBook.mount(gui: ScreenGui)
	modal = Modal.new(gui, "Ticket book", Vector2.new(980, 330))
	modal.onOpen = render
	Registry.StateController.Observe("public", { "run", "log" }, function()
		if modal:isOpen() then
			render()
		end
	end)
	ContextActionService:BindAction("LTO_TicketBook", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if modal:isOpen() then
			modal:close()
		elseif inRun() then
			modal:open()
		else
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B, Enum.KeyCode.DPadLeft)
end

function TicketBook.open()
	modal:open()
end

return TicketBook
