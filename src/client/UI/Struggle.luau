--!strict
--[[
	The struggle check, shown while a Hollow has you. No plate: a few marks float low over the
	view so the grab itself stays on screen.

	  the grip's name, typed in bone over the scene (a check's verdict flashes in its place)
	  the skill-check bar: a thin dark track; a marker crosses it once, left to right. Press
	  while it is over the amber zone; the bright sliver in the zone's middle is a great hit
	  a hairline above the bar: the grab's clock running down, in red
	  a hairline below it: how close you are to tearing free, red to green
	  the key to press for your input device, a small chip that punches down (touch players
	  tap it), and a crewmate's name when one is pulling you free
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
local keyLabel: TextLabel
local keyScale: UIScale
local rootScale: UIScale
local fill: Frame
local helpers: TextLabel
local onPress: (() -> ())? = nil
local verdictUntil = 0

local WIDTH = 320
local BAR_Y, BAR_W, BAR_H = 30, WIDTH, 10
local KEY_Y = 62 -- the key chip's centre
local TRACK = Color3.fromRGB(10, 6, 6)
local ZONE = Color3.fromRGB(186, 132, 58) -- amber: a good press
local GREAT = Color3.fromRGB(255, 238, 196) -- its bright middle: a great one
local MARK = Color3.fromRGB(255, 250, 240)
local INK = Color3.fromRGB(40, 4, 6) -- the dark round the type, so it reads on anything
local BONE = Color3.fromRGB(238, 226, 204)
local FONT = Theme.Font.type -- typewritten, like the line's own notices
local KEY_FONT = Theme.Font.sign

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

local function line(name: string, y: number, color: Color3, parent: Instance): Frame
	local frame = Ui.new("Frame", {
		Name = name,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromOffset(0, y),
		ZIndex = 21,
		Parent = parent,
	})
	return frame
end

function Struggle.mount(gui: ScreenGui, press: () -> ())
	onPress = press
	root = Ui.new("Frame", {
		Name = "Struggle",
		Size = UDim2.fromOffset(WIDTH, 96),
		Position = UDim2.fromScale(0.5, 0.76),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	Ui.phoneScale(root, gui, 0.85) -- the grab's skill check: smaller on a phone, still easy to read
	rootScale = Ui.new("UIScale", { Parent = root })

	title = Ui.text({
		Text = "",
		Font = FONT,
		TextSize = 20,
		Color = BONE,
		Size = UDim2.new(1, 0, 0, 22),
		XAlign = Enum.TextXAlignment.Center,
	})
	title.TextStrokeColor3 = INK
	title.TextStrokeTransparency = 0.25
	title.ZIndex = 21
	title.Parent = root
	verdict = Ui.text({
		Text = "",
		Font = KEY_FONT,
		TextSize = 22,
		Color = BONE,
		Size = UDim2.new(1, 0, 0, 22),
		XAlign = Enum.TextXAlignment.Center,
	})
	verdict.TextStrokeColor3 = INK
	verdict.TextStrokeTransparency = 0.2
	verdict.ZIndex = 25
	verdict.Parent = root

	-- the grab's clock, the bar, and the escape meter, stacked tight
	rule = line("Rule", BAR_Y - 5, Theme.Color.signal, root)
	bar = Ui.new("Frame", {
		Name = "Bar",
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		Position = UDim2.fromOffset(0, BAR_Y),
		BackgroundColor3 = TRACK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = root,
	})
	Ui.corner(5).Parent = bar
	Ui.stroke(INK, 1, 0.3).Parent = bar
	zoneFrame = Ui.new("Frame", {
		Name = "Zone",
		BackgroundColor3 = ZONE,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Visible = false,
		ZIndex = 22,
		Parent = bar,
	})
	Ui.corner(3).Parent = zoneFrame
	greatFrame = Ui.new("Frame", {
		Name = "Great",
		BackgroundColor3 = GREAT,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Visible = false,
		ZIndex = 23,
		Parent = bar,
	})
	needle = Ui.new("Frame", {
		Name = "Marker",
		Size = UDim2.new(0, 3, 1, 10),
		Position = UDim2.fromOffset(0, -5),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = MARK,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 24,
		Parent = bar,
	})
	Ui.stroke(Theme.Color.signal, 1, 0).Parent = needle
	local meter = line("Meter", BAR_Y + BAR_H + 3, TRACK, root)
	meter.BackgroundTransparency = 0.5
	fill = Ui.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.signal,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 22,
		Parent = meter,
	})

	-- the key to press, and the button touch players tap
	local keycap = Ui.new("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(84, 24),
		Position = UDim2.fromOffset(WIDTH / 2, KEY_Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = TRACK,
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 22,
		Parent = root,
	})
	Ui.corner(4).Parent = keycap
	Ui.stroke(ZONE, 1, 0.1).Parent = keycap
	keyScale = Ui.new("UIScale", { Parent = keycap })
	keyLabel = Ui.text({
		Text = "SPACE",
		Font = KEY_FONT,
		TextSize = 16,
		Color = GREAT,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	keyLabel.ZIndex = 23
	keyLabel.Parent = keycap
	-- on the press, not the release (Activated waits for the finger to lift: a whole tap late)
	keycap.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			local handler = onPress
			if handler then
				handler()
			end
		end
	end)
	helpers = Ui.text({
		Text = "",
		Font = FONT,
		TextSize = 13,
		Color = Theme.Color.go,
		Position = UDim2.fromOffset(0, KEY_Y + 14),
		Size = UDim2.new(1, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Center,
	})
	helpers.TextStrokeColor3 = INK
	helpers.TextStrokeTransparency = 0.3
	helpers.ZIndex = 21
	helpers.Parent = root
end

-- `crewmates`: another living crewmate is in the run, so the check says they can pull you free.
function Struggle.show(name: string, _kind: string, crewmates: boolean)
	title.Text = name
	title.TextTransparency = 0
	keyLabel.Text = keyText()
	helpers.Text = if crewmates then "your crew can pull you free" else ""
	helpers.TextColor3 = BONE
	rule.Size = UDim2.new(1, 0, 0, 2)
	verdict.Text = ""
	Struggle.clearCheck()
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Color.signal
	root.Visible = true
	rootScale.Scale = 1.25
	Ui.tween(rootScale, { Scale = 1 }, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
end

function Struggle.hide()
	root.Visible = false
end

-- How far the victim has fought free: 0 held fast, 1 free. `now` drives the key chip's breathing.
function Struggle.set(fraction: number, now: number)
	local f = math.clamp(fraction, 0, 1)
	fill.Size = UDim2.fromScale(f, 1)
	fill.BackgroundColor3 = Theme.Color.signal:Lerp(Theme.Color.go, f)
	keyLabel.TextTransparency = 0.25 * (0.5 + 0.5 * math.sin(now * 9))
	if os.clock() > verdictUntil and verdict.Text ~= "" then
		verdict.Text = ""
		title.TextTransparency = 0
	end
end

-- The grab's clock: the share of it left, 1 at the snatch, 0 at the finish.
function Struggle.clock(left: number)
	rule.Size = UDim2.new(math.clamp(left, 0, 1), 0, 0, 2)
end

-- Shows a check's zone on the bar: `start` and `width` in degrees (0 the left end, 360 the
-- right), with the `great` degrees in its middle drawn as the bright sliver.
function Struggle.zone(start: number, width: number, great: number)
	local px = BAR_W / 360
	zoneFrame.Position = UDim2.fromOffset(start * px, 0)
	zoneFrame.Size = UDim2.new(0, width * px, 1, 0)
	greatFrame.Position = UDim2.fromOffset((start + (width - great) / 2) * px, 0)
	greatFrame.Size = UDim2.new(0, math.max(great * px, 2), 1, 0)
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

-- A check's verdict flashes where the grip's name was.
function Struggle.result(result: string)
	verdictUntil = os.clock() + 0.6
	verdict.Text = string.upper(result)
	title.TextTransparency = 1
	verdict.TextColor3 = if result == "Great"
		then Theme.Color.go
		elseif result == "Good" then GREAT
		else Theme.Color.signal
	rootScale.Scale = if result == "Miss" then 1.08 else 1.04
	Ui.tween(rootScale, { Scale = 1 }, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
end

-- The input device changed: show its key.
function Struggle.refreshKey()
	keyLabel.Text = keyText()
end

-- One press: the key chip punches down and springs back.
function Struggle.punch()
	keyScale.Scale = 0.84
	Ui.tween(keyScale, { Scale = 1 }, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
end

-- A crewmate is tearing at it.
function Struggle.helped(name: string)
	helpers.Text = `{name} is pulling you free!`
	helpers.TextColor3 = Theme.Color.go
end

return Struggle
