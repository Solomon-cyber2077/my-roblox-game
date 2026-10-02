--!strict
--[[
	Screen-level feedback layered over everything else:
	  crew feed      the last few Notify messages, bottom left
	  alerts         big centre banners for phase changes and alarms
	  popups         "+8 COAL" style receipts rising from the backpack
	  vignette       edge pulses for hits and fog
	  dread          a dark vignette that closes in while a Hollow is near
	  fade           full-screen fades for boarding and teleports
]]

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Overlay = {}

local FEED_KINDS: { [string]: Color3 } = {
	Crew = Theme.Color.white,
	Info = Theme.Color.textDim,
	Warning = Theme.Color.caution,
	Alarm = Theme.Color.signal,
	Elimination = Theme.Color.signal,
	Rescue = Theme.Color.sky,
	Station = Theme.Color.brass,
	LastCall = Theme.Color.signal,
	Upgrade = Theme.Color.go,
	RunEnd = Theme.Color.brass,
}

local feed: Frame
local alertLabel: TextLabel
local alertScale: UIScale
local popups: Frame
local fadeFrame: Frame
local edges: { Frame } = {}
local shade: { Frame } = {}
local shadeShown = 0
local alertToken = 0
local feedOrder = 0

-- The dread vignette reaches further in than the pulse edges, and sits under them.
local SHADE_SPECS = {
	{ size = UDim2.fromScale(1, 0.34), pos = UDim2.fromScale(0, 0), rotation = 90 },
	{ size = UDim2.fromScale(1, 0.34), pos = UDim2.fromScale(0, 0.66), rotation = -90 },
	{ size = UDim2.fromScale(0.26, 1), pos = UDim2.fromScale(0, 0), rotation = 0 },
	{ size = UDim2.fromScale(0.26, 1), pos = UDim2.fromScale(0.74, 0), rotation = 180 },
}
local SHADE_MAX = 0.8 -- opacity at the screen's edge at full dread

function Overlay.mount(gui: ScreenGui)
	feed = Ui.new("Frame", {
		Name = "Feed",
		Size = UDim2.fromOffset(420, 200),
		Position = UDim2.new(0, 16, 1, -24),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom).Parent =
		feed

	alertLabel = Ui.text({
		Name = "Alert",
		Text = "",
		Font = Theme.Font.display,
		TextSize = 44,
		Color = Theme.Color.white,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0.5, 0, 0, 124),
		AnchorPoint = Vector2.new(0.5, 0),
		XAlign = Enum.TextXAlignment.Center,
	})
	alertLabel.TextStrokeTransparency = 0.4
	alertLabel.TextTransparency = 1
	alertLabel.TextStrokeColor3 = Theme.Color.black
	alertLabel.Parent = gui
	alertScale = Ui.new("UIScale", { Parent = alertLabel })

	popups = Ui.new("Frame", {
		Name = "Popups",
		Size = UDim2.fromOffset(300, 200),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	-- Vignette: four edge bands with gradients toward the centre.
	local specs = {
		{ size = UDim2.fromScale(1, 0.22), pos = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.22), pos = UDim2.fromScale(0, 0.78), rotation = -90 },
		{ size = UDim2.fromScale(0.16, 1), pos = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.16, 1), pos = UDim2.fromScale(0.84, 0), rotation = 180 },
	}
	for _, spec in specs do
		local edge = Ui.new("Frame", {
			Name = "Vignette",
			Size = spec.size,
			Position = spec.pos,
			BackgroundColor3 = Theme.Color.signal,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = gui,
		})
		Ui.new("UIGradient", {
			Rotation = spec.rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = edge,
		})
		table.insert(edges, edge)
	end

	for _, spec in SHADE_SPECS do
		local edge = Ui.new("Frame", {
			Name = "Dread",
			Size = spec.size,
			Position = spec.pos,
			BackgroundColor3 = Theme.Color.black,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 19,
			Parent = gui,
		})
		Ui.new("UIGradient", {
			Rotation = spec.rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = edge,
		})
		table.insert(shade, edge)
	end

	fadeFrame = Ui.new("Frame", {
		Name = "Fade",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = gui,
	})
end

function Overlay.feed(kind: string, text: string)
	feedOrder += 1
	local color = FEED_KINDS[kind] or Theme.Color.white
	local row = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.35,
		LayoutOrder = feedOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = feed,
	})
	row.Size = UDim2.fromOffset(0, 24)
	Ui.corner(4).Parent = row
	Ui.padding(3, 10, 3, 12).Parent = row
	Ui.new("Frame", {
		Size = UDim2.new(0, 3, 1, 4),
		Position = UDim2.fromOffset(-9, -2),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = row,
	})
	local label =
		Ui.text({ Text = text, TextSize = 15, Color = color, AutoX = true, Size = UDim2.fromScale(0, 1) })
	label.Parent = row
	local items = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	if #items > 6 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(7, function()
		if row.Parent then
			Ui.tween(row, { BackgroundTransparency = 1 }, TweenInfo.new(0.6))
			Ui.tween(label, { TextTransparency = 1 }, TweenInfo.new(0.6))
			task.wait(0.65)
			row:Destroy()
		end
	end)
end

function Overlay.alert(text: string, color: Color3?, seconds: number?)
	alertToken += 1
	local token = alertToken
	alertLabel.Text = text
	alertLabel.TextColor3 = color or Theme.Color.white
	alertLabel.TextTransparency = 0
	alertLabel.TextStrokeTransparency = 0.4
	alertScale.Scale = 1.25
	Ui.tween(alertScale, { Scale = 1 }, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	task.delay(seconds or 2.4, function()
		if token == alertToken then
			Ui.tween(alertLabel, { TextTransparency = 1, TextStrokeTransparency = 1 }, TweenInfo.new(0.5))
		end
	end)
end

function Overlay.popup(text: string, color: Color3?)
	local label = Ui.text({
		Text = text,
		Font = Theme.Font.display,
		TextSize = 24,
		Color = color or Theme.Color.brassLight,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	label.TextStrokeTransparency = 0.5
	label.Parent = popups
	Ui.tween(
		label,
		{ Position = UDim2.new(0, 0, 1, -120) },
		TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	)
	task.delay(1.0, function()
		Ui.tween(label, { TextTransparency = 1, TextStrokeTransparency = 1 }, TweenInfo.new(0.6))
		task.wait(0.65)
		label:Destroy()
	end)
end

function Overlay.pulse(color: Color3, strength: number, seconds: number)
	for _, edge in edges do
		edge.BackgroundColor3 = color
		edge.BackgroundTransparency = 1 - strength
		Ui.tween(
			edge,
			{ BackgroundTransparency = 1 },
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		)
	end
end

-- Dread from 0 to 1: the edges of the screen darken as a Hollow closes in.
function Overlay.dread(level: number)
	local alpha = math.floor(level * SHADE_MAX * 100 + 0.5) / 100
	if alpha == shadeShown then
		return
	end
	shadeShown = alpha
	for _, edge in shade do
		edge.BackgroundTransparency = 1 - alpha
	end
end

function Overlay.fade(toBlack: boolean, seconds: number?)
	Ui.tween(
		fadeFrame,
		{ BackgroundTransparency = if toBlack then 0 else 1 },
		TweenInfo.new(seconds or 0.5, Enum.EasingStyle.Quad)
	)
end

-- Fades out, waits, and fades back in; used around teleports.
function Overlay.blink(hold: number?)
	task.spawn(function()
		Overlay.fade(true, 0.35)
		task.wait(0.35 + (hold or 0.6))
		Overlay.fade(false, 0.6)
	end)
end

function Overlay.localName(): string
	return Players.LocalPlayer.DisplayName
end

return Overlay
