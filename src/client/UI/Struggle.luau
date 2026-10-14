--!strict
--[[
	The struggle plate, shown while a Hollow has you: what it is doing to you, the skill-check
	ring (a needle sweeps it once; press when it is in the zone, the bright head of the zone
	is a great hit), the key to press for your input device (a keycap that punches down; touch
	players tap it), and how close you are to tearing free. The meter runs red to green as
	the hold weakens; the red rule along the top is the grab's clock running down.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Struggle = {}

local root: Frame
local rule: Frame
local ring: Frame
local needle: Frame
local verdict: TextLabel
local segments: { Frame } = {}
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

local RING = 50 -- the ring's radius, px
local TRACK = 7 -- its thickness
local RING_X, RING_Y = 112, 142 -- its centre on the plate
local KEY_X = 318 -- the keycap's centre
local SEG_STEP = 3 -- degrees per zone segment
local SEG_W = 6
local SEGMENTS = math.ceil(340 / SEG_STEP)

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

	-- the skill-check ring: a dark track, the zone (great zone brighter) and the needle
	ring = Ui.new("Frame", {
		Name = "Ring",
		Size = UDim2.fromOffset(RING * 2, RING * 2),
		Position = UDim2.fromOffset(RING_X, RING_Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = plate,
	})
	Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ring })
	Ui.stroke(Theme.Color.black, TRACK, 0.25).Parent = ring
	for i = 1, SEGMENTS do
		local spoke = Ui.new("Frame", {
			Name = "Zone",
			Size = UDim2.fromOffset(SEG_W, RING * 2 + TRACK),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 22,
			Parent = ring,
		})
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, TRACK + 2),
			BackgroundColor3 = Theme.Color.white,
			BorderSizePixel = 0,
			ZIndex = 22,
			Parent = spoke,
		})
		segments[i] = spoke
	end
	needle = Ui.new("Frame", {
		Name = "Needle",
		Size = UDim2.fromOffset(4, RING * 2 + TRACK + 6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 24,
		Parent = ring,
	})
	Ui.new("Frame", {
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Theme.Color.signal,
		BorderSizePixel = 0,
		ZIndex = 24,
		Parent = needle,
	})
	verdict = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 18,
		Color = Theme.Color.white,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	verdict.ZIndex = 25
	verdict.Parent = ring

	-- the key to press, and the button touch players tap
	local keycap = Ui.new("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(176, 52),
		Position = UDim2.fromOffset(KEY_X, RING_Y - 18),
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
		Text = "WHEN THE NEEDLE HITS THE ZONE",
		Font = Theme.Font.bodyBold,
		TextSize = 13,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(KEY_X - 110, RING_Y + 14),
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

-- Shows a check's zone: `start` and `width` in degrees clockwise from the top, the leading
-- `great` degrees brighter.
function Struggle.zone(start: number, width: number, great: number)
	for i, spoke in segments do
		local at = (i - 1) * SEG_STEP
		spoke.Visible = at <= width
		if at <= width then
			spoke.Rotation = start + math.min(at, width)
			local bar = spoke:FindFirstChildOfClass("Frame") :: Frame
			bar.BackgroundColor3 = if at <= great then Theme.Color.go else Theme.Color.white
		end
	end
end

-- Points the needle (degrees clockwise from the top); nil hides it.
function Struggle.needle(angle: number?)
	needle.Visible = angle ~= nil
	if angle then
		needle.Rotation = angle
	end
end

function Struggle.clearCheck()
	for _, spoke in segments do
		spoke.Visible = false
	end
	needle.Visible = false
end

-- A check's verdict flashes in the ring.
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
