--!strict
--[[
	The struggle plate, shown while a Hollow has you: what it is doing to you, the key to
	mash (a keycap that punches down with every press; touch players tap it), and how
	close you are to tearing free. The meter runs red to green as the hold weakens.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Struggle = {}

local root: Frame
local title: TextLabel
local subtitle: TextLabel
local keyLabel: TextLabel
local keyScale: UIScale
local plateScale: UIScale
local hint: TextLabel
local fill: Frame
local helpers: TextLabel
local onPress: (() -> ())? = nil

local KIND_TEXT: { [string]: string } = {
	Stalker = "A STALKER HAS YOU",
	Crawler = "THE CRAWLER HAS YOU",
	Brute = "A BRUTE HAS YOU",
}

local function keyText(): string
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "A"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "TAP"
	end
	return "SPACE"
end

function Struggle.mount(gui: ScreenGui, press: () -> ())
	onPress = press
	root = Ui.new("Frame", {
		Name = "Struggle",
		Size = UDim2.fromOffset(460, 168),
		Position = UDim2.fromScale(0.5, 0.7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	plateScale = Ui.new("UIScale", { Parent = root })
	local plate = Ui.panel({
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.06,
		ZIndex = 20,
		Parent = root,
	})
	local rule = Ui.new("Frame", {
		Name = "Rule",
		BackgroundColor3 = Theme.Color.signal,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 0, 3),
		Position = UDim2.fromOffset(12, 10),
		ZIndex = 21,
		Parent = plate,
	})
	Ui.corner(2).Parent = rule
	title = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 26,
		Color = Theme.Color.signal,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.new(1, -36, 0, 30),
		XAlign = Enum.TextXAlignment.Center,
	})
	title.ZIndex = 21
	title.Parent = plate
	subtitle = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 14,
		Color = Theme.Color.textDim,
		Position = UDim2.fromOffset(18, 48),
		Size = UDim2.new(1, -36, 0, 18),
		XAlign = Enum.TextXAlignment.Center,
	})
	subtitle.ZIndex = 21
	subtitle.Parent = plate

	local keycap = Ui.new("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(150, 44),
		Position = UDim2.new(0.5, -82, 0, 74),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.paper,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 22,
		Parent = plate,
	})
	Ui.corner(7).Parent = keycap
	Ui.stroke(Theme.Color.paperShade, 2, 0).Parent = keycap
	keyScale = Ui.new("UIScale", { Parent = keycap })
	keyLabel = Ui.text({
		Text = "SPACE",
		Font = Theme.Font.display,
		TextSize = 24,
		Color = Theme.Color.ink,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	keyLabel.ZIndex = 23
	keyLabel.Parent = keycap
	keycap.Activated:Connect(function()
		local handler = onPress
		if handler then
			handler()
		end
	end)
	hint = Ui.text({
		Text = "MASH TO BREAK FREE",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.white,
		Position = UDim2.new(0.5, 6, 0, 74),
		Size = UDim2.fromOffset(200, 44),
	})
	hint.ZIndex = 22
	hint.Parent = plate

	local meter = Ui.new("Frame", {
		Name = "Meter",
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -36, 0, 12),
		Position = UDim2.new(0, 18, 1, -34),
		ZIndex = 21,
		Parent = plate,
	})
	Ui.corner(4).Parent = meter
	fill = Ui.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.signal,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 22,
		Parent = meter,
	})
	Ui.corner(4).Parent = fill
	helpers = Ui.text({
		Text = "",
		Font = Theme.Font.body,
		TextSize = 12,
		Color = Theme.Color.textDim,
		Position = UDim2.new(0, 18, 1, -19),
		Size = UDim2.new(1, -36, 0, 14),
		XAlign = Enum.TextXAlignment.Center,
	})
	helpers.ZIndex = 21
	helpers.Parent = plate
end

function Struggle.show(name: string, kind: string)
	title.Text = name
	subtitle.Text = KIND_TEXT[kind] or "IT HAS YOU"
	keyLabel.Text = keyText()
	helpers.Text = "Your crew can pull you free"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Color.signal
	root.Visible = true
	plateScale.Scale = 1.35
	Ui.tween(plateScale, { Scale = 1 }, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
end

function Struggle.hide()
	root.Visible = false
end

-- How far the victim has fought free: 0 held fast, 1 free. `now` drives the hint's blink.
function Struggle.set(fraction: number, now: number)
	local f = math.clamp(fraction, 0, 1)
	fill.Size = UDim2.fromScale(f, 1)
	fill.BackgroundColor3 = Theme.Color.signal:Lerp(Theme.Color.go, f)
	hint.TextTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(now * 9))
end

-- One press: the keycap punches down and springs back.
function Struggle.punch()
	keyScale.Scale = 0.86
	Ui.tween(keyScale, { Scale = 1 }, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
end

-- A crewmate is tearing at it.
function Struggle.helped(name: string)
	helpers.Text = `{name} is pulling you free!`
end

return Struggle
