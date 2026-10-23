--!strict
--[[
	The struggle plate, shown while a Hollow has you: what it is doing to you, the skill-check
	bar (a marker crosses it once, left to right; press while it is over the grey zone, and the
	small white block in the zone's middle is a great hit), the key to press for your input
	device (a keycap that punches down; touch players tap it), and how close you are to tearing
	free. The meter runs red to green as
	the hold weakens; the red rule along the top is the grab's clock running down.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Struggle = {}

local root: Frame
local rule: Frame
local bar: Frame
local needle: Frame
local verdict: TextLabel
local zoneFrame: Frame
local greatFrame: Frame
local title: TextLabel
local subtitle: TextLabel
local keyLabel: TextLabel
local keyScale: UIScale
local plateScale: UIScale
local hint: TextLabel
local fill: Frame
local helpers: TextLabel
local onPress: (() -> ())? = nil
local verdictUntil = 0

local BAR_X, BAR_Y = 24, 82 -- the bar's top left on the plate
local BAR_W, BAR_H = 412, 24
local KEY_X, KEY_Y = 230, 146 -- the keycap's centre
local GREY = Color3.fromRGB(128, 122, 114) -- the zone: a good press
local WHITE = Color3.fromRGB(246, 242, 232) -- its middle: a great one

local BRASS_RIM = Color3.fromRGB(112, 84, 38)

local KIND_TEXT: { [string]: string } = {
	Stalker = "A STALKER HAS YOU",
	Crawler = "THE CRAWLER HAS YOU",
	Brute = "A BRUTE HAS YOU",
}

-- The key for the input device the player last used.
local function keyText(): string
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad", 1, true) then
		return "A"
	elseif last == Enum.UserInputType.Touch then
		return "TAP"
	end
	return "SPACE"
end

function Struggle.mount(gui: ScreenGui, press: () -> ())
	onPress = press
	root = Ui.new("Frame", {
		Name = "Struggle",
		Size = UDim2.fromOffset(460, 236),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	Ui.phoneScale(root, gui, 0.8) -- the grab's skill check: smaller on a phone, still easy to read
	plateScale = Ui.new("UIScale", { Parent = root })
	local plate = Ui.panel({
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.06,
		ZIndex = 20,
		Parent = root,
	})
	rule = Ui.new("Frame", {
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

	-- the skill-check bar: a dark track, the grey zone with its white block, and the marker
	bar = Ui.new("Frame", {
		Name = "Bar",
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		Position = UDim2.fromOffset(BAR_X, BAR_Y),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = plate,
	})
	Ui.corner(3).Parent = bar
	Ui.stroke(BRASS_RIM, 1, 0.2).Parent = bar
	zoneFrame = Ui.new("Frame", {
		Name = "Zone",
		BackgroundColor3 = GREY,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		Visible = false,
		ZIndex = 22,
		Parent = bar,
	})
	greatFrame = Ui.new("Frame", {
		Name = "Great",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		Visible = false,
		ZIndex = 23,
		Parent = bar,
	})
	needle = Ui.new("Frame", {
		Name = "Marker",
		Size = UDim2.new(0, 4, 1, 10),
		Position = UDim2.fromOffset(0, -5),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.signal,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 24,
		Parent = bar,
	})
	verdict = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 18,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(BAR_X, BAR_Y + BAR_H + 2),
		Size = UDim2.fromOffset(BAR_W, 22),
		XAlign = Enum.TextXAlignment.Center,
	})
	verdict.TextStrokeTransparency = 0.4
	verdict.ZIndex = 25
	verdict.Parent = plate

	-- the key to press, and the button touch players tap
	local keycap = Ui.new("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(176, 44),
		Position = UDim2.fromOffset(KEY_X, KEY_Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.brass, -- an enamel keycap, as on the prompts
		AutoButtonColor = false,
		Text = "",
		ZIndex = 22,
		Parent = plate,
	})
	Ui.corner(5).Parent = keycap
	Ui.stroke(Theme.Color.brassLight, 2, 0.1).Parent = keycap
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
		Text = "WHEN THE MARKER IS ON THE WHITE",
		Font = Theme.Font.bodyBold,
		TextSize = 13,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(KEY_X - 110, KEY_Y + 26),
		Size = UDim2.fromOffset(220, 18),
		XAlign = Enum.TextXAlignment.Center,
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

-- `crewmates`: another living crewmate is in the run, so the plate says they can pull you free.
function Struggle.show(name: string, kind: string, crewmates: boolean)
	title.Text = name
	subtitle.Text = KIND_TEXT[kind] or "IT HAS YOU"
	keyLabel.Text = keyText()
	helpers.Text = if crewmates then "Your crew can pull you free" else ""
	rule.Size = UDim2.new(1, -24, 0, 3)
	verdict.Text = ""
	Struggle.clearCheck()
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
	if os.clock() > verdictUntil then
		verdict.Text = ""
	end
end

-- The grab's clock: the share of it left, 1 at the snatch, 0 at the finish.
function Struggle.clock(left: number)
	rule.Size = UDim2.new(math.clamp(left, 0, 1), -24, 0, 3)
end

-- Shows a check's zone on the bar: `start` and `width` in degrees (0 the left end, 360 the
-- right), with the `great` degrees in its middle drawn as the white block.
function Struggle.zone(start: number, width: number, great: number)
	local px = BAR_W / 360
	zoneFrame.Position = UDim2.fromOffset(start * px, 3)
	zoneFrame.Size = UDim2.new(0, width * px, 1, -6)
	greatFrame.Position = UDim2.fromOffset((start + (width - great) / 2) * px, 3)
	greatFrame.Size = UDim2.new(0, math.max(great * px, 2), 1, -6)
	zoneFrame.Visible = true
	greatFrame.Visible = true
end

-- Puts the marker at `angle` degrees along the bar (0 left, 360 right); nil hides it.
function Struggle.needle(angle: number?)
	needle.Visible = angle ~= nil
	if angle then
		needle.Position = UDim2.fromOffset(math.clamp(angle, 0, 360) / 360 * BAR_W, -5)
	end
end

function Struggle.clearCheck()
	zoneFrame.Visible = false
	greatFrame.Visible = false
	needle.Visible = false
end

-- A check's verdict flashes under the bar.
function Struggle.result(result: string)
	verdictUntil = os.clock() + 0.6
	verdict.Text = string.upper(result)
	verdict.TextColor3 = if result == "Great"
		then Theme.Color.go
		elseif result == "Good" then Theme.Color.brassLight
		else Theme.Color.signal
	if result == "Miss" then
		plateScale.Scale = 1.06
		Ui.tween(
			plateScale,
			{ Scale = 1 },
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		)
	end
end

-- The input device changed: show its key.
function Struggle.refreshKey()
	keyLabel.Text = keyText()
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
