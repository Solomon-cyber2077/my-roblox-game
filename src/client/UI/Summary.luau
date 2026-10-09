--!strict
-- End-of-run receipt: outcome, run tier, payout lines in ledger type, XP, rank-ups and milestones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)

local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Summary = {}

local modal: Modal.Modal
local WIDTH, MIN_HEIGHT, MAX_HEIGHT = 520, 300, 600
local CONTENT_WIDTH = WIDTH - 32 - 44 -- the modal body's inset, then the receipt's margins
local CHROME = 64 + 12 + 20 + 8 -- header and body insets, the receipt's margins, a little air

local TITLES: { [string]: { text: string, color: Color3, line: string } } = {
	Victory = {
		text = "END OF THE LINE",
		color = Theme.Color.goInk,
		line = "The train reached the Terminus.",
	},
	Wiped = { text = "NO ONE MADE IT", color = Theme.Color.signal, line = "The whole crew was lost." },
	Derailed = {
		text = "BROKEN DOWN",
		color = Theme.Color.signalDark,
		line = "The train failed on the line.",
	},
}

function Summary.mount(gui: ScreenGui)
	modal = Modal.new(gui, "Run receipt", Vector2.new(WIDTH, MAX_HEIGHT))
end

-- One ledger row: label and dotted leader on the left (clipped), the amount set flush right.
local function ledgerRow(
	parent: Instance,
	order: number,
	text: string,
	amount: string,
	color: Color3,
	z: number
)
	local row = Ui.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = z,
		Parent = parent,
	})
	local lead = Ui.new("Frame", {
		Size = UDim2.new(1, -78, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = row,
	})
	local left = Ui.text({
		Text = `{text} {string.rep(". ", 40)}`,
		Font = Theme.Font.type,
		TextSize = 16,
		Color = color,
		Size = UDim2.fromScale(4, 1),
	})
	left.ZIndex = z
	left.Parent = lead
	local right = Ui.text({
		Text = amount,
		Font = Theme.Font.type,
		TextSize = 16,
		Color = color,
		Size = UDim2.new(0, 74, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
	})
	right.ZIndex = z
	right.Parent = row
end

--[[
	A railway company's receipt: a header band, the outcome struck with a rubber stamp, ledger
	lines with dotted leaders, a double totals rule, the brass/XP strip on an iron plate, and a
	tear-off foot. Lost runs are lit by the blood moon; the Terminus by a warm lamp.
]]
function Summary.show(data: { [string]: any })
	local body = modal.body
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	local title = TITLES[data.outcome] or TITLES.Wiped
	local won = data.outcome == "Victory"
	local ink = if won then Theme.Color.goInk else Theme.Color.signalDark
	local receipt = Ui.ticket({
		Size = UDim2.fromScale(1, 1),
		ZIndex = 32,
		BackgroundColor3 = Theme.Color.paper:Lerp(
			if won then Theme.Color.amber else Theme.Color.signalDark,
			0.16
		),
		Parent = body,
	})
	-- the lamp it is read by: moon red creeping in from the corners, or a warm pool
	Ui.new("ImageLabel", {
		Name = "Moonlight",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.vignette,
		ImageColor3 = if won then Theme.Color.mahogany else Theme.Color.signalDark,
		ImageTransparency = if won then 0.55 else 0.25,
		ZIndex = 32,
		Parent = receipt,
	})
	local content = Ui.new("Frame", {
		Size = UDim2.new(1, -44, 1, -20),
		Position = UDim2.fromOffset(30, 10),
		BackgroundTransparency = 1,
		ZIndex = 33,
		Parent = receipt,
	})
	local layout = Ui.list(Enum.FillDirection.Vertical, 6)
	layout.Parent = content

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function rule(thickness: number?)
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, thickness or 1),
			BackgroundColor3 = Theme.Color.ink,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
			ZIndex = 34,
			Parent = content,
		})
	end
	local function line(text: string, font: Font, size: number, color: Color3)
		local label = Ui.text({
			Text = text,
			Font = font,
			TextSize = size,
			Color = color,
			LayoutOrder = nextOrder(),
			Wrapped = true,
		})
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.ZIndex = 34
		label.Parent = content
	end

	-- header band: the company's name engraved on a dark plate
	local band = Ui.new("Frame", {
		Name = "Band",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = if won then Theme.Color.lacquer else Theme.Color.leather,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		ZIndex = 34,
		Parent = content,
	})
	Ui.stroke(Theme.Color.brass, 1, 0.3).Parent = band
	local company = Ui.text({
		Text = "LAST TRAIN OUT RAILWAY CO.  ·  CREW RECEIPT",
		Font = Theme.Font.displayMedium,
		TextSize = 13,
		Color = Theme.Color.brassLight,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
	})
	company.ZIndex = 35
	company.Parent = band
	local tier = Ui.text({
		Text = `TIER {data.tier or 1}`,
		Font = Theme.Font.display,
		TextSize = 13,
		Color = Theme.Color.white,
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
	})
	tier.ZIndex = 35
	tier.Parent = band

	-- the outcome, struck with a rubber stamp: a ruled box, ink bled, paper showing through
	local stampRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		ZIndex = 34,
		Parent = content,
	})
	local stamp = Ui.new("Frame", {
		Name = "Stamp",
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = if won then -2 else -5,
		BackgroundTransparency = 1,
		ZIndex = 35,
		Parent = stampRow,
	})
	Ui.new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = stamp,
	})
	Ui.stroke(ink, 3, 0.08).Parent = stamp
	Ui.corner(4).Parent = stamp
	local struck = Ui.text({
		Text = title.text,
		Font = Theme.Font.type,
		TextSize = 34,
		Color = ink,
		AutoX = true,
		Size = UDim2.fromScale(0, 1),
	})
	struck.ZIndex = 36
	struck.TextTransparency = 0.06
	struck.Parent = stamp
	Ui.new("ImageLabel", { -- where the rubber missed: paper-coloured knock-outs over the ink
		Name = "Grunge",
		Size = UDim2.new(1, 28, 1, 8),
		Position = UDim2.fromOffset(-14, -4),
		BackgroundTransparency = 1,
		Image = Theme.Image.grunge,
		ImageColor3 = receipt.BackgroundColor3,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(120, 120),
		ImageTransparency = 0.15,
		ZIndex = 37,
		Parent = stamp,
	})
	line(title.line, Theme.Font.hand, 18, Theme.Color.inkSoft)
	rule()
	ledgerRow(content, nextOrder(), "Stations cleared", tostring(data.stations or 0), Theme.Color.ink, 34)
	for _, entry in data.lines or {} do
		ledgerRow(
			content,
			nextOrder(),
			tostring(entry.label),
			Format.signed(entry.amount),
			if entry.amount < 0 then Theme.Color.signalDark else Theme.Color.ink,
			34
		)
	end
	rule(2)
	rule(1)

	-- the brass/XP strip: an iron plate riveted to the slip
	local strip = Ui.panel({
		Name = "Strip",
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = nextOrder(),
		ZIndex = 34,
		SliceScale = 0.18,
		Parent = content,
	})
	local brass = Ui.text({
		Text = `BRASS  <font size="30">{Format.thousands(data.brass or 0)}</font>`,
		Rich = true,
		Font = Theme.Font.display,
		TextSize = 15,
		Color = Theme.Color.brassLight,
		Size = UDim2.new(0.6, -14, 1, 0),
		Position = UDim2.fromOffset(14, 0),
	})
	brass.ZIndex = 35
	brass.Parent = strip
	local xp = Ui.text({
		Text = `XP  <font size="22">{Format.thousands(data.xp or 0)}</font>`,
		Rich = true,
		Font = Theme.Font.displayMedium,
		TextSize = 13,
		Color = Theme.Color.white,
		Size = UDim2.new(0.4, -14, 1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		XAlign = Enum.TextXAlignment.Right,
	})
	xp.ZIndex = 35
	xp.Parent = strip

	if data.rankAfter and data.rankBefore and data.rankAfter > data.rankBefore then
		line(`PROMOTED TO CREW RANK {data.rankAfter}`, Theme.Font.display, 18, Theme.Color.goInk)
	end
	if data.unlockedTier then
		line(`RUN TIER {data.unlockedTier} UNLOCKED`, Theme.Font.display, 18, Theme.Color.goInk)
	end
	for _, name in data.milestones or {} do
		line(`LINE MASTERY: {string.upper(name)}`, Theme.Font.display, 16, Theme.Color.goInk)
	end
	if data.saved == false then
		line(
			"Progress is not saved in this session (DataStores unavailable).",
			Theme.Font.bodyBold,
			13,
			Theme.Color.signalDark
		)
	end
	-- tear-off foot
	line("RETAIN THIS RECEIPT  ·  NOT TRANSFERABLE", Theme.Font.type, 11, Theme.Color.inkSoft)

	-- the receipt is as long as what is printed on it
	local function fit()
		local scale = content.AbsoluteSize.X / CONTENT_WIDTH
		if scale <= 0 then
			return
		end
		local height = math.ceil(layout.AbsoluteContentSize.Y / scale) + CHROME
		modal.frame.Size = UDim2.fromOffset(WIDTH, math.clamp(height, MIN_HEIGHT, MAX_HEIGHT))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	modal:open()
	fit()
end

return Summary
