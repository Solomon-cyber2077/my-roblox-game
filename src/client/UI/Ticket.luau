--!strict
--[[
	A paper railway ticket, drawn from a TicketModel.View. Host-agnostic: the junction ballot
	uses the full ticket, the station board and summary can use the read-only stub.

	  Ticket.full(view, opts)  card stock with an uneven edge, a perforated stub holding the
	                           serial, a punched string hole and the countdown dial; the station
	                           type, name (one line, shrinks to fit) and two wrapped lines of
	                           description; a wax danger seal with chalk tallies on its own
	                           DANGER line; the inked track and the coal lumps; the vote button,
	                           the fold-out flap and a layer for stamps. Returns a handle.
	  Ticket.stub(view, opts)  the same ticket torn short: serial, type, name, seal, km, coal.

	A sealed mystery (view.mystery) prints "????" under a smudge of soot, and where the wax seal
	would be a small lantern flickers in a neutral lamp colour, never a danger colour. It has
	no flap: there is no dossier to unfold.

	It leans by its route id (TicketModel.tilt) so it sits the same way every redraw. Every
	button is at least 44 px and shows a brass ring under gamepad focus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TicketModel = require(ReplicatedStorage.Shared.Logic.TicketModel)

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Ticket = {}

local HEAD = Font.new("rbxasset://fonts/families/Arvo.json", Enum.FontWeight.Bold)
local HEAD_LIGHT = Font.new("rbxasset://fonts/families/Arvo.json")
local BODY = Theme.Font.type

local PAPER = Theme.Color.paper
local PAPER_SHADE = Theme.Color.paperShade
local INK = Theme.Color.ink
local INK_SOFT = Theme.Color.inkSoft
local WAX = Color3.fromRGB(146, 26, 30)
local WAX_DARK = Color3.fromRGB(92, 14, 18)
local HOLE = Color3.fromRGB(18, 16, 16)
local SOOT = Color3.fromRGB(58, 52, 48)
local LAMP = Color3.fromRGB(150, 36, 30) -- a mystery's lantern: lit by the blood moon, guttering
local LAMP_DIM = Color3.fromRGB(64, 12, 12)

local W, H = 224, 310
local PAD = 14
local STUB = 38 -- height of the stub above the perforation
local HIT = 44 -- smallest hit target
local DIAL = 32
local PUNCH_SECONDS = 0.14
local SLACK_TILT = 5
local SLACK_DROP = 12

export type Opts = {
	routeId: string,
	track: number?, -- 0..1 share of the inked line (TicketModel.track)
	buttonText: string?,
	selected: boolean?,
	onVote: (() -> ())?,
	onFlap: (() -> ())?,
	flapOpen: boolean?,
	LayoutOrder: number?,
}

export type Handle = {
	slot: Frame,
	body: Frame,
	stamps: Frame,
	button: TextButton,
	flap: TextButton,
	setSelected: (selected: boolean, text: string) -> (),
	setFlap: (open: boolean) -> (),
	setDial: (sweep: number, numeral: number?) -> (),
	punch: () -> (),
	slacken: () -> (),
}

-- A brass ring shown round whichever button the gamepad has selected.
local function focusRing(): Frame
	local ring = Ui.new("Frame", {
		Name = "Focus",
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.fromOffset(-4, -4),
		BackgroundTransparency = 1,
	})
	Ui.corner(4).Parent = ring
	Ui.stroke(Theme.Color.caution, 3, 0).Parent = ring
	return ring
end

local function circle(name: string, size: number, color: Color3, parent: Instance, z: number): Frame
	local frame = Ui.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Ui.corner(size // 2).Parent = frame
	return frame
end

local function label(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	color: Color3,
	z: number
): TextLabel
	local l = Ui.text({ Text = text, Font = font, TextSize = size, Color = color })
	l.ZIndex = z
	l.Parent = parent
	return l
end

-- Shrinks a one-line label to fit its box rather than clipping it.
local function shrink(l: TextLabel, max: number, min: number)
	l.TextScaled = true
	Ui.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min, Parent = l })
end

-- Card stock: gradient, hairline, and a ragged edge top and bottom seeded by the route.
local function stock(parent: Instance, size: UDim2, routeId: string, z: number): Frame
	local paper = Ui.new("Frame", {
		Name = "Paper",
		Size = size,
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Ui.corner(2).Parent = paper
	Ui.stroke(INK, 1, 0.5).Parent = paper
	-- lamp-lit from above: the foot of the card falls into the carriage's shadow
	Ui.new("UIGradient", {
		Rotation = 80,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(226, 218, 206)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 160, 142)),
		}),
		Parent = paper,
	})
	-- smoke, foxing and a scorched rim, then fibre grain over the whole face
	Ui.new("ImageLabel", {
		Name = "Age",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.card.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.card.slice,
		SliceScale = Theme.Slice.card,
		ZIndex = z,
		Parent = paper,
	})
	Ui.new("ImageLabel", {
		Name = "Grain",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.paperGrain,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(256, 256),
		ImageTransparency = 0.62,
		ZIndex = z,
		Parent = paper,
	})
	local nibs = 14
	for i = 1, nibs do
		for _, top in { true, false } do
			local depth = 1 + math.floor(TicketModel.hash(`{routeId}:{i}:{top}`) * 3)
			Ui.new("Frame", {
				Name = "Edge",
				Size = UDim2.new(1 / nibs, -2, 0, depth),
				Position = UDim2.new((i - 1) / nibs, 1, if top then 0 else 1, if top then -depth else 0),
				BackgroundColor3 = if top then PAPER else PAPER:Lerp(PAPER_SHADE, 0.4),
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = paper,
			})
		end
	end
	return paper
end

-- The wax seal holding the danger number, its chalk tallies beside it.
local function seal(parent: Instance, s: TicketModel.Seal, x: number, y: number, size: number, z: number)
	-- poured wax (a Blender render: sheen, ragged rim, the company wheel pressed in), turned so
	-- no two seals on the board sit alike
	Ui.new("ImageLabel", {
		Name = "Wax",
		Size = UDim2.fromOffset(math.floor(size * 1.7), math.floor(size * 1.7)),
		Position = UDim2.fromOffset(x + size / 2, y + size / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = math.floor(TicketModel.hash(`{s.number}:{s.strokes}:wax`) * 360),
		BackgroundTransparency = 1,
		Image = Theme.Image.wax,
		ZIndex = z,
		Parent = parent,
	})
	local disc = circle("Seal", size, WAX, parent, z + 1)
	disc.Position = UDim2.fromOffset(x + size / 2, y + size / 2)
	disc.BackgroundTransparency = 1 -- the render is the seal; the disc only carries the number
	local n = label(disc, tostring(s.number), HEAD, math.floor(size * 0.55), Theme.Color.white, z + 2)
	n.Size = UDim2.fromScale(1, 1)
	n.TextXAlignment = Enum.TextXAlignment.Center
	Ui.stroke(WAX_DARK, 1.5, 0).Parent = n -- pressed into the wax, not printed on it
	for i = 1, s.strokes do
		Ui.new("Frame", {
			Name = "Tally",
			Size = UDim2.fromOffset(3, math.floor(size * 0.6)),
			Position = UDim2.fromOffset(x + size + 8 + (i - 1) * 8, y + size / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -6 + i * 4,
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = parent,
		})
	end
end

-- Soot rubbed over a mystery's name: a few thin smears seeded by the route, kept to the name's line
-- so the description below stays readable.
local function smudge(parent: Instance, routeId: string, y: number, height: number, z: number): Frame
	local cover = Ui.new("Frame", {
		Name = "Smudge",
		Size = UDim2.new(1, -PAD, 0, height),
		Position = UDim2.fromOffset(PAD // 2, y),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	for i = 1, 3 do
		local h = TicketModel.hash(`{routeId}:smudge:{i}`)
		local smear = Ui.new("Frame", {
			Name = "Smear",
			Size = UDim2.new(0.45 + h * 0.4, 0, 0, 8 + math.floor(h * 6)),
			Position = UDim2.fromScale(0.05 + (1 - h) * 0.3, 0.25 * i),
			AnchorPoint = Vector2.new(0, 0.5),
			Rotation = -1.5 + h * 3,
			BackgroundColor3 = SOOT,
			BackgroundTransparency = 0.3 + h * 0.2,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = cover,
		})
		Ui.corner(8).Parent = smear
	end
	return cover
end

-- A mystery's lantern in place of the seal: a neutral glow that flickers.
local function lantern(parent: Instance, x: number, y: number, size: number, z: number)
	local halo = circle("LanternHalo", size + 10, LAMP, parent, z)
	halo.Position = UDim2.fromOffset(x + size / 2, y + size / 2)
	halo.BackgroundTransparency = 0.75
	local glass = circle("Lantern", size - 8, LAMP, parent, z + 1)
	glass.Position = halo.Position
	Ui.stroke(INK, 2, 0.1).Parent = glass
	local q = label(glass, "?", HEAD, math.floor(size * 0.5), Theme.Color.white, z + 2)
	q.Size = UDim2.fromScale(1, 1)
	q.TextXAlignment = Enum.TextXAlignment.Center
	local flicker = TweenInfo.new(0.23, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut, -1, true)
	Ui.tween(glass, { BackgroundColor3 = LAMP_DIM }, flicker)
	Ui.tween(
		halo,
		{ BackgroundTransparency = 0.95 },
		TweenInfo.new(0.37, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut, -1, true)
	)
end

-- A row of coal lumps in groups of five, then the "x12" label.
local function coalRow(
	parent: Instance,
	coal: TicketModel.Coal,
	x: number,
	y: number,
	color: Color3,
	z: number
): number
	local cx = x
	for _, count in coal.groups do
		for _ = 1, count do
			Ui.new("Frame", {
				Name = "Lump",
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.fromOffset(cx, y + 5),
				Rotation = 45,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = parent,
			})
			cx += 8
		end
		cx += 5
	end
	local text = if coal.more then `+ {coal.label}` else coal.label
	local l = label(parent, text, HEAD, 12, color, z)
	l.Position = UDim2.fromOffset(cx + 2, y)
	l.Size = UDim2.fromOffset(56, 16)
	return cx + 60
end

function Ticket.full(view: TicketModel.View, opts: Opts): Handle
	local tilt = TicketModel.tilt(opts.routeId)
	local slot = Ui.new("Frame", {
		Name = "Ticket",
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	local body = Ui.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = tilt,
		BackgroundTransparency = 1,
		Parent = slot,
	})
	-- its shadow on the table
	local shadow = Ui.new("Frame", {
		Name = "Shadow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(4, 6),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = body,
	})
	Ui.corner(2).Parent = shadow
	local paper = stock(body, UDim2.fromScale(1, 1), opts.routeId, 2)
	local selectedRim = Ui.stroke(Theme.Color.ember, 3, 1) -- your pick glows like a lamp wick
	selectedRim.Name = "Selected"
	selectedRim.Parent = paper

	-- The stub: string hole, serial, dial; then the perforation
	local hole = circle("StringHole", 9, HOLE, paper, 4)
	hole.Position = UDim2.fromOffset(PAD + 2, STUB / 2)
	local serial = label(paper, view.serial, HEAD, 15, INK, 4)
	serial.Position = UDim2.fromOffset(PAD + 14, 8)
	serial.Size = UDim2.fromOffset(100, 22)
	local dial = circle("Dial", DIAL, PAPER, paper, 4)
	dial.Position = UDim2.new(1, -PAD - DIAL / 2, 0, STUB / 2)
	Ui.stroke(INK, 2, 0).Parent = dial
	for i = 0, 11 do
		local mark = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Rotation = i * 30,
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = dial,
		})
		Ui.new("Frame", {
			Size = UDim2.fromOffset(if i % 3 == 0 then 2 else 1, 4),
			Position = UDim2.new(0.5, 0, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = INK_SOFT,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = mark,
		})
	end
	local spindle = Ui.new("Frame", {
		Name = "Hand",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = dial,
	})
	Ui.new("Frame", {
		Size = UDim2.new(0, 2, 0.5, -3),
		Position = UDim2.new(0.5, 0, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.signal,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = spindle,
	})
	local numeral = label(dial, "", HEAD, 14, Theme.Color.signal, 7)
	numeral.Size = UDim2.fromScale(1, 1)
	numeral.TextXAlignment = Enum.TextXAlignment.Center
	numeral.BackgroundColor3 = PAPER
	numeral.Visible = false
	local perforation = Ui.new("Frame", {
		Name = "Perforation",
		Size = UDim2.new(1, -16, 0, 4),
		Position = UDim2.fromOffset(8, STUB),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = paper,
	})
	Ui.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent =
		perforation
	for i = 1, 22 do
		local dot = Ui.new("Frame", {
			Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = PAPER_SHADE,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 4,
			Parent = perforation,
		})
		Ui.corner(2).Parent = dot
	end

	-- What the line is
	local y = STUB + 10
	local kind = label(paper, view.kind, BODY, 11, INK_SOFT, 4)
	kind.Position = UDim2.fromOffset(PAD, y)
	kind.Size = UDim2.new(1, -PAD * 2, 0, 14)
	shrink(kind, 11, 8)
	y += 15
	local name = label(paper, view.name, HEAD, 18, INK, 4)
	name.Position = UDim2.fromOffset(PAD, y)
	name.Size = UDim2.new(1, -PAD * 2, 0, 22)
	shrink(name, 18, 9)
	y += 24
	local description = label(paper, view.description, BODY, 12, INK, 4)
	description.Position = UDim2.fromOffset(PAD, y)
	description.Size = UDim2.new(1, -PAD * 2, 0, 30)
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	shrink(description, 12, 7)
	y += 32
	local hint = label(paper, view.hint, BODY, 10, INK_SOFT, 4)
	hint.Position = UDim2.fromOffset(PAD, y)
	hint.Size = UDim2.new(1, -PAD * 2, 0, 14)
	shrink(hint, 10, 7)
	y += 18

	if view.mystery then
		smudge(paper, opts.routeId, name.Position.Y.Offset, name.Size.Y.Offset, 5)
	end

	-- DANGER on its own line, then the seal
	local dangerTitle = label(
		paper,
		if view.terminus then "THE END OF THE LINE" elseif view.mystery then "DANGER  UNKNOWN" else "DANGER",
		HEAD,
		11,
		INK_SOFT,
		4
	)
	dangerTitle.Position = UDim2.fromOffset(PAD, y)
	dangerTitle.Size = UDim2.fromOffset(150, 14)
	y += 16
	if view.seal then
		seal(paper, view.seal, PAD, y, 32, 4)
	elseif view.mystery then
		lantern(paper, PAD, y, 32, 4)
	end
	-- the stamps pile up to the right of the seal
	local stamps = Ui.new("Frame", {
		Name = "Stamps",
		Size = UDim2.fromOffset(W - 100 - PAD, 50),
		Position = UDim2.fromOffset(96, y - 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = paper,
	})
	y += 50

	-- The inked track, sleepers across it, scaled shortest to longest offered
	local trackWidth = math.floor((W - PAD * 2 - 58) * math.clamp(opts.track or 1, 0, 1))
	local track = Ui.new("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(trackWidth, 10),
		Position = UDim2.fromOffset(PAD, y + 3),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = paper,
	})
	for _, rail in { 2, 7 } do
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromOffset(0, rail),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = track,
		})
	end
	for sx = 2, trackWidth - 2, 7 do
		Ui.new("Frame", {
			Size = UDim2.fromOffset(2, 10),
			Position = UDim2.fromOffset(sx, 0),
			BackgroundColor3 = INK_SOFT,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = track,
		})
	end
	local km = label(paper, `{view.distanceKm} KM`, HEAD, 12, INK, 4)
	km.Position = UDim2.fromOffset(PAD + trackWidth + 6, y)
	km.Size = UDim2.fromOffset(56, 16)
	y += 20

	-- Coal: lumps in fives, the cost, and what the bunker holds after
	local coalColor = if view.short then Theme.Color.signal else INK
	if view.coal then
		coalRow(paper, view.coal, PAD, y, coalColor, 4)
	end
	y += 17
	if view.after ~= nil then
		local after = label(
			paper,
			if view.short then "NOT ENOUGH COAL: THE HULL WILL SUFFER" else `after this line: {view.after}`,
			BODY,
			10,
			if view.short then Theme.Color.signal else INK_SOFT,
			4
		)
		after.Position = UDim2.fromOffset(PAD, y)
		after.Size = UDim2.new(1, -PAD * 2, 0, 13)
		shrink(after, 10, 7)
	end

	-- The vote button and the fold-out flap that lays out the dossier
	local button = Ui.button(opts.buttonText or "TAKE THIS LINE", "Secondary", opts.onVote, {
		Name = "Vote",
		Size = UDim2.new(1, -PAD * 2 - HIT - 6, 0, HIT),
		Position = UDim2.new(0, PAD, 1, -HIT - 10),
		TextSize = 14,
	})
	button.FontFace = HEAD
	button.ZIndex = 5
	button.SelectionImageObject = focusRing()
	button.Parent = paper
	local flap = Ui.new("TextButton", {
		Name = "Flap",
		Size = UDim2.fromOffset(HIT, HIT),
		Position = UDim2.new(1, -PAD, 1, -HIT - 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Color.leather,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 5,
		Parent = paper,
	})
	flap.SelectionImageObject = focusRing()
	Ui.corner(2).Parent = flap
	local flapRim = Ui.stroke(Theme.Color.brass, 1, 0.5)
	flapRim.Parent = flap
	-- the dog-ear folded down in its corner
	local fold = Ui.new("Frame", {
		Name = "Fold",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = flap,
	})
	Ui.stroke(INK_SOFT, 1, 0.5).Parent = fold
	flap.ClipsDescendants = true
	local chevron = Ui.new("Frame", {
		Size = UDim2.fromOffset(14, 9),
		Position = UDim2.fromScale(0.5, 0.55),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = flap,
	})
	for _, arm in { { 4, 45 }, { 10, -45 } } do
		Ui.new("Frame", {
			Size = UDim2.fromOffset(8, 2),
			Position = UDim2.fromOffset(arm[1], 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = arm[2],
			BackgroundColor3 = Theme.Color.brassLight,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = chevron,
		})
	end
	flap.MouseEnter:Connect(function()
		Ui.tween(flapRim, { Transparency = 0 })
	end)
	flap.MouseLeave:Connect(function()
		Ui.tween(flapRim, { Transparency = 0.5 })
	end)
	if opts.onFlap then
		flap.Activated:Connect(opts.onFlap)
	end
	flap.Visible = not view.mystery

	local punched: Frame? = nil
	local handle: Handle = {
		slot = slot,
		body = body,
		stamps = stamps,
		button = button,
		flap = flap,
		setSelected = function(selected: boolean, text: string)
			selectedRim.Transparency = if selected then 0 else 1
			button.Text = text
			Ui.setButtonStyle(button, if selected then "Primary" else "Secondary")
		end,
		setFlap = function(open: boolean)
			chevron.Rotation = if open then 180 else 0
			flap.BackgroundColor3 = if open then Theme.Color.signalDark else Theme.Color.leather
		end,
		setDial = function(sweep: number, n: number?)
			spindle.Rotation = sweep * 360
			numeral.Visible = n ~= nil
			numeral.Text = if n then tostring(n) else ""
		end,
		punch = function()
			if punched then
				return
			end
			local p = circle("Punch", 1, HOLE, paper, 8)
			p.Position = UDim2.fromOffset(PAD + 98, STUB / 2)
			Ui.tween(
				p,
				{ Size = UDim2.fromOffset(15, 15) },
				TweenInfo.new(PUNCH_SECONDS, Enum.EasingStyle.Back)
			)
			punched = p
		end,
		slacken = function()
			local info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			Ui.tween(body, {
				Rotation = tilt + (if tilt < 0 then -SLACK_TILT else SLACK_TILT),
				Position = UDim2.new(0.5, 0, 0.5, SLACK_DROP),
			}, info)
			local dim = Ui.new("Frame", {
				Name = "Slack",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Color.black,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 20,
				Parent = paper,
			})
			Ui.tween(dim, { BackgroundTransparency = 0.55 }, info)
		end,
	}
	handle.setSelected(opts.selected == true, opts.buttonText or "TAKE THIS LINE")
	handle.setFlap(opts.flapOpen == true)
	return handle
end

-- The compact read-only stub: no buttons, no dial.
function Ticket.stub(view: TicketModel.View, opts: { routeId: string, LayoutOrder: number? }): Frame
	local sw, sh = 200, 72
	local slot = Ui.new("Frame", {
		Name = "TicketStub",
		Size = UDim2.fromOffset(sw, sh),
		BackgroundTransparency = 1,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	local paper = stock(slot, UDim2.fromScale(1, 1), opts.routeId, 2)
	paper.Rotation = TicketModel.tilt(opts.routeId)
	local hole = circle("StringHole", 7, HOLE, paper, 4)
	hole.Position = UDim2.fromOffset(10, sh / 2)
	local serial = label(paper, view.serial, HEAD_LIGHT, 11, INK_SOFT, 4)
	serial.Position = UDim2.fromOffset(20, 6)
	serial.Size = UDim2.fromOffset(60, 14)
	local kind = label(paper, view.kind, BODY, 10, INK_SOFT, 4)
	kind.Position = UDim2.fromOffset(78, 6)
	kind.Size = UDim2.new(1, -86, 0, 14)
	shrink(kind, 10, 7)
	local name = label(paper, view.name, HEAD, 15, INK, 4)
	name.Position = UDim2.fromOffset(20, 22)
	name.Size = UDim2.new(1, if view.seal then -64 else -28, 0, 20)
	shrink(name, 15, 8)
	local foot = `{view.distanceKm} KM`
	if view.coal then
		foot ..= `  ·  COAL {view.coal.label}`
	end
	local legs = label(paper, foot, BODY, 10, INK, 4)
	legs.Position = UDim2.fromOffset(20, 46)
	legs.Size = UDim2.new(1, -64, 0, 14)
	shrink(legs, 10, 7)
	if view.seal then
		local disc = circle("Seal", 28, WAX, paper, 4)
		disc.Position = UDim2.new(1, -24, 0.5, 0)
		Ui.stroke(WAX_DARK, 2, 0.2).Parent = disc
		local n = label(disc, tostring(view.seal.number), HEAD, 15, PAPER, 5)
		n.Size = UDim2.fromScale(1, 1)
		n.TextXAlignment = Enum.TextXAlignment.Center
	end
	return slot
end

return Ticket
