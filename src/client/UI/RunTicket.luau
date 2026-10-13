--!strict
--[[
	The stamped run ticket: one card for how a run ended, in the route tickets' paper style
	(UI/Ticket). It draws any Logic/RunTicketModel.Data table, so the end screen (UI/RunCard)
	and later the ticket book (brief F) share it.

	  RunTicket.build(data, z, strike?)  -> the ticket (W x H) and a play() that strikes the stamp
	                                      (with strike the stamp waits, hidden, for play())

	Top to bottom: a stub with the company line and serial, the perforation, the hero line,
	your own cause, a hairline rule, three stats (stops reached, loot, the crew's initials) and
	the stamp struck across the foot. The foot's left is left clear for the host's buttons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunTicketModel = require(ReplicatedStorage.Shared.Logic.RunTicketModel)

local Stamp = require(script.Parent.Stamp)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local RunTicket = {}

RunTicket.W, RunTicket.H = 520, 340
RunTicket.FOOT = 58 -- the strip along the bottom kept free for the host's CLOSE button

local HEAD = Font.new("rbxasset://fonts/families/Arvo.json", Enum.FontWeight.Bold)
local PAD = 28
local STUB = 44
local INK = Theme.Color.ink
local INK_SOFT = Theme.Color.inkSoft
local WIN = Color3.fromRGB(40, 110, 62)

local function label(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	color: Color3,
	z: number
): TextLabel
	local l = Ui.new("TextLabel", {
		Text = text,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = z,
		Parent = parent,
	}) :: TextLabel
	return l
end

local function fit(l: TextLabel, max: number, min: number)
	l.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.MinTextSize = min
	limit.Parent = l
end

function RunTicket.build(data: RunTicketModel.Data, z: number, strike: boolean?): (ImageLabel, () -> ())
	local W, H = RunTicket.W, RunTicket.H
	local ticket = Ui.ticket({
		Name = "RunTicket",
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Theme.Color.paper:Lerp(
			if data.won then Theme.Color.amber else Theme.Color.signalDark,
			0.08
		),
		ZIndex = z,
	})
	Ui.stroke(INK_SOFT, 1, 0.4).Parent = ticket
	-- read by the light the run ended in: the blood moon at the edges, or the Terminus lamps
	Ui.new("ImageLabel", {
		Name = "Moonlight",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.vignette,
		ImageColor3 = if data.won then Theme.Color.mahogany else Theme.Color.signalDark,
		ImageTransparency = if data.won then 0.6 else 0.55,
		ZIndex = z + 1,
		Parent = ticket,
	})
	-- a worn double border
	for _, inset in { 7, 11 } do
		local border = Ui.new("Frame", {
			Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
			Position = UDim2.fromOffset(inset, inset),
			BackgroundTransparency = 1,
			ZIndex = z + 2,
			Parent = ticket,
		})
		Ui.corner(2).Parent = border
		local outer = inset == 7
		Ui.stroke(if outer then INK else Theme.Color.tarnish, 1, if outer then 0.55 else 0.35).Parent = border
	end

	-- The stub: string hole, company line, serial; then the perforation
	local hole = Ui.new("Frame", {
		Name = "StringHole",
		Size = UDim2.fromOffset(11, 11),
		Position = UDim2.fromOffset(PAD, STUB / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 16, 16),
		BorderSizePixel = 0,
		ZIndex = z + 3,
		Parent = ticket,
	})
	Ui.corner(6).Parent = hole
	local company = label(ticket, "LAST TRAIN OUT  ·  RUN TICKET", Theme.Font.type, 14, INK_SOFT, z + 3)
	company.Position = UDim2.fromOffset(PAD + 16, 12)
	company.Size = UDim2.new(1, -2 * PAD - 140, 0, 22)
	local serial = label(ticket, data.serial, HEAD, 15, INK, z + 3)
	serial.Position = UDim2.new(1, -PAD, 0, 12)
	serial.AnchorPoint = Vector2.new(1, 0)
	serial.Size = UDim2.fromOffset(130, 22)
	serial.TextXAlignment = Enum.TextXAlignment.Right
	local perforation = Ui.new("Frame", {
		Name = "Perforation",
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.fromOffset(12, STUB),
		BackgroundTransparency = 1,
		ZIndex = z + 3,
		Parent = ticket,
	})
	Ui.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent =
		perforation
	for i = 1, 44 do
		local dot = Ui.new("Frame", {
			Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Theme.Color.paperShade,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = z + 3,
			Parent = perforation,
		})
		Ui.corner(2).Parent = dot
	end

	-- The hero line: how the run ended
	local y = STUB + 16
	local hero = label(ticket, data.hero, HEAD, 32, if data.won then WIN else Theme.Color.signalDark, z + 3)
	hero.Name = "Hero"
	hero.Position = UDim2.fromOffset(PAD, y)
	hero.Size = UDim2.new(1, -2 * PAD, 0, 40)
	fit(hero, 32, 18)
	y += 46

	-- Your own line: the cause
	local causeTitle =
		label(ticket, data.causeTitle, HEAD, 14, if data.won then INK else Theme.Color.signal, z + 3)
	causeTitle.Name = "CauseTitle"
	causeTitle.Position = UDim2.fromOffset(PAD, y)
	causeTitle.Size = UDim2.new(1, -2 * PAD, 0, 18)
	y += 20
	local causeLine = label(ticket, data.causeLine, Theme.Font.body, 17, INK_SOFT, z + 3)
	causeLine.Name = "Cause"
	causeLine.Position = UDim2.fromOffset(PAD, y)
	causeLine.Size = UDim2.new(1, -2 * PAD, 0, 44)
	causeLine.TextWrapped = true
	causeLine.TextYAlignment = Enum.TextYAlignment.Top
	y += 52

	Ui.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -2 * PAD, 0, 1),
		Position = UDim2.fromOffset(PAD, y),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = z + 3,
		Parent = ticket,
	})
	y += 10

	-- Three stats in columns; the crew's shows each initial, the lost ones struck faint
	local count = math.min(#data.stats, RunTicketModel.MaxStats)
	local colW = (W - 2 * PAD) / math.max(count, 1)
	for i = 1, count do
		local stat = data.stats[i]
		local x = PAD + (i - 1) * colW
		local name = label(ticket, stat.label, Theme.Font.type, 13, INK_SOFT, z + 3)
		name.Position = UDim2.fromOffset(x, y)
		name.Size = UDim2.fromOffset(colW - 8, 16)
		local isCrew = i == count and stat.label == "CREW" and #data.crew > 0
		if isCrew then
			local row = Ui.new("Frame", {
				Name = "Crew",
				Size = UDim2.fromOffset(colW - 8, 30),
				Position = UDim2.fromOffset(x, y + 18),
				BackgroundTransparency = 1,
				ZIndex = z + 3,
				Parent = ticket,
			})
			Ui.list(
				Enum.FillDirection.Horizontal,
				6,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Center
			).Parent =
				row
			for order, mark in data.crew do
				local chip = label(
					row,
					mark.initials,
					HEAD,
					20,
					if mark.lost then Theme.Color.paperShade else INK,
					z + 4
				)
				chip.Size = UDim2.fromOffset(32, 28)
				chip.LayoutOrder = order
				chip.TextXAlignment = Enum.TextXAlignment.Center
				if mark.lost then -- struck through, as a conductor scores off a missing passenger
					Ui.new("Frame", {
						Size = UDim2.new(1, 0, 0, 2),
						Position = UDim2.fromScale(0, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Rotation = -8,
						BackgroundColor3 = Theme.Color.signal,
						BackgroundTransparency = 0.2,
						BorderSizePixel = 0,
						ZIndex = z + 5,
						Parent = chip,
					})
				end
			end
		else
			local value = label(ticket, stat.value, HEAD, 26, INK, z + 3)
			value.Position = UDim2.fromOffset(x, y + 18)
			value.Size = UDim2.fromOffset(colW - 8, 30)
			fit(value, 26, 12)
		end
	end

	-- The stamp, struck across the foot on the right (the left of the foot is the host's)
	local stamp = Stamp.word({
		key = `runticket{data.stamp}`,
		text = data.stamp,
		color = if data.won then WIN else Theme.Color.signal,
		size = 26,
		Position = UDim2.new(1, -PAD - 110, 1, -RunTicket.FOOT / 2 - 4),
		ZIndex = z + 10,
	})
	stamp.Parent = ticket
	stamp.Visible = not strike

	local function play()
		stamp.Visible = true
		Stamp.land(stamp)
	end
	return ticket, play
end

return RunTicket
