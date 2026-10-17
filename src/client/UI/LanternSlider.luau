--!strict
--[[
	Settings' one slider: how far my lantern reads (the readability floor, Logic/Visibility).
	A duplex lamp's wick winder laid flat (docs/visibility/slider_mockup.png, Blender): a
	pierced brass gallery is the track, a knurled thumbwheel the thumb, and a flame engraved
	in the plate grows from "Dread" to "Clear" with a notch at "Steady", the default. No studs
	or numbers on screen. All native GuiObjects, no assets.

	Dragging applies at once on this client (VisibilityController.SetRadius) and shows a
	local-only ring on the ground at the floor's reach, fading after release; the release
	saves it (SetSetting, clamped on the server, Logic/Settings). Visual only: nothing that
	detects, aggroes, damages or loots reads it (tests/LanternSlider.spec.luau).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Settings = require(game:GetService("ReplicatedStorage").Shared.Logic.Settings)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.Settings)
local Tuning = require(game:GetService("ReplicatedStorage").Shared.Config.Tuning)

local LanternSlider = {}

local KEY = Tuning.Visibility.Setting
local RANGE = Config.Ranges[KEY]
local DEFAULT = Tuning.Visibility.Default
local FLAMES = 9
local RING_FADE = 1.6 -- seconds the preview ring takes to fade after release

local function share(studs: number): number
	return math.clamp((studs - RANGE.min) / math.max(RANGE.max - RANGE.min, 1), 0, 1)
end

local function studsAt(t: number): number
	return math.round(RANGE.min + math.clamp(t, 0, 1) * (RANGE.max - RANGE.min))
end

local function current(player: Player): number
	return tonumber(Settings.read({ [KEY] = player:GetAttribute(KEY) })[KEY]) or DEFAULT
end

local function apply(studs: number?)
	local visibility = Registry.VisibilityController
	if visibility then
		visibility.SetRadius(studs)
	end
end

-- the preview: a flat ring round your feet at the floor's reach, on this client only
local ring: CylinderHandleAdornment? = nil
local ringToken = 0
local function showRing(studs: number, fade: boolean)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local adorn = ring
	if adorn == nil or adorn.Parent == nil then
		local made = Instance.new("CylinderHandleAdornment")
		made.Name = "LanternReach"
		made.Height = 0.08
		made.AlwaysOnTop = false
		made.ZIndex = 0
		made.Color3 = Theme.Color.amber
		made.Parent = Workspace.CurrentCamera
		ring = made
		adorn = made
	end
	local a = adorn :: CylinderHandleAdornment
	a.Adornee = root
	a.CFrame = CFrame.new(0, -2.9, 0) * CFrame.Angles(math.rad(90), 0, 0)
	a.Radius = studs
	a.InnerRadius = math.max(studs - 0.35, 0)
	ringToken += 1
	if not fade then
		a.Transparency = 0.35
		return
	end
	local token = ringToken
	task.spawn(function()
		local started = os.clock()
		while token == ringToken and a.Parent do
			local t = (os.clock() - started) / RING_FADE
			a.Transparency = 0.35 + 0.65 * math.clamp(t, 0, 1)
			if t >= 1 then
				a.Adornee = nil :: any
				break
			end
			task.wait()
		end
	end)
end

function LanternSlider.mount(list: Instance, order: number): () -> ()
	local player = Players.LocalPlayer
	local row = Ui.new("Frame", {
		Name = "LanternRow",
		Size = UDim2.new(1, -8, 0, 176),
		BackgroundColor3 = Theme.Color.leather,
		BackgroundTransparency = 0.08,
		LayoutOrder = order,
		ZIndex = 32,
		Parent = list,
	})
	Ui.corner(2).Parent = row
	local title = Ui.text({
		Text = "LANTERN",
		Font = Theme.Font.displayMedium,
		TextSize = 26,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 30),
	})
	title.ZIndex = 33
	title.Parent = row
	local note = Ui.text({
		Text = "How far your lantern reads in the dark.",
		Font = Theme.Font.body,
		TextSize = 19,
		Wrapped = true,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 0, 26),
	})
	note.ZIndex = 33
	note.Parent = row

	-- the gallery plate, its slot and piercings
	local plate = Ui.new("Frame", {
		Name = "Gallery",
		Size = UDim2.new(1, -64, 0, 58),
		Position = UDim2.fromOffset(32, 78),
		BackgroundColor3 = Theme.Color.brass,
		ZIndex = 33,
		Active = true,
		Parent = row,
	})
	Ui.corner(8).Parent = plate
	Ui.stroke(Theme.Color.inkDeep, 2, 0.2).Parent = plate
	Ui.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Color.brassLight),
			ColorSequenceKeypoint.new(0.45, Theme.Color.brass),
			ColorSequenceKeypoint.new(1, Theme.Color.tarnish),
		}),
		Parent = plate,
	})
	local slot = Ui.new("Frame", {
		Name = "Slot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -36, 0, 8),
		Position = UDim2.new(0.5, 0, 0, 34),
		BackgroundColor3 = Theme.Color.inkDeep,
		ZIndex = 34,
		Parent = plate,
	})
	Ui.corner(4).Parent = slot
	for i = 0, 14 do
		local hole = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(4, 4),
			Position = UDim2.new(i / 14, 0, 0, 14),
			BackgroundColor3 = Theme.Color.inkDeep,
			ZIndex = 34,
			Parent = slot,
		})
		Ui.corner(2).Parent = hole
	end
	-- the engraved flame along the top, lit up to the wick's height
	local flames: { Frame } = {}
	for i = 1, FLAMES do
		local t = (i - 1) / (FLAMES - 1)
		local flame = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(4 + math.floor(t * 4), 6 + math.floor(t * 12)),
			Position = UDim2.new(t, 0, 0, -6),
			BackgroundColor3 = Theme.Color.tarnish,
			ZIndex = 34,
			Parent = slot,
		})
		Ui.corner(4).Parent = flame
		Ui.new("UIGradient", {
			Rotation = -90,
			Transparency = NumberSequence.new(0, 0.5),
			Parent = flame,
		})
		table.insert(flames, flame)
	end
	-- notches at the two ends and at Steady
	local steadyAt = share(DEFAULT)
	for _, at in { 0, steadyAt, 1 } do
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(2, if at == steadyAt then 14 else 9),
			Position = UDim2.new(at, 0, 1, 2),
			BackgroundColor3 = Theme.Color.inkDeep,
			ZIndex = 34,
			Parent = slot,
		})
	end
	-- hand-lettered ends and the default
	local function label(text: string, at: number, align: Enum.TextXAlignment)
		local l = Ui.text({
			Text = text,
			Font = Theme.Font.hand,
			TextSize = 22,
			Color = Theme.Color.brassLight,
			XAlign = align,
			AnchorPoint = Vector2.new(
				if align == Enum.TextXAlignment.Left
					then 0
					elseif align == Enum.TextXAlignment.Right then 1
					else 0.5,
				0
			),
			Position = UDim2.new(at, if at == 0 then 18 elseif at == 1 then -18 else 0, 0, 140),
			Size = UDim2.fromOffset(110, 26),
		})
		l.ZIndex = 33
		l.Parent = row
	end
	-- the plate spans the row less 32 px each side; labels sit under its slot ends
	label("Dread", 0, Enum.TextXAlignment.Left)
	label("Clear", 1, Enum.TextXAlignment.Right)
	if steadyAt > 0.12 and steadyAt < 0.88 then
		local steady = Ui.text({
			Text = "Steady",
			Font = Theme.Font.hand,
			TextSize = 22,
			Color = Theme.Color.brassLight,
			XAlign = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(steadyAt, 0, 1, 20),
			Size = UDim2.fromOffset(110, 26),
		})
		steady.ZIndex = 33
		steady.Parent = slot
	else
		-- Steady shares an end: name it on that end's label instead
		for _, child in row:GetChildren() do
			if child:IsA("TextLabel") and child.Text == (if steadyAt <= 0.12 then "Dread" else "Clear") then
				child.Text = if steadyAt <= 0.12 then "Dread · Steady" else "Steady · Clear"
				child.Size = UDim2.fromOffset(180, 26)
			end
		end
	end

	-- the winder: a knurled brass thumbwheel
	local knob = Ui.new("TextButton", {
		Name = "Winder",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromScale(steadyAt, 0.5),
		BackgroundColor3 = Theme.Color.brass,
		ZIndex = 36,
		Selectable = true,
		Parent = slot,
	})
	Ui.corner(20).Parent = knob
	Ui.stroke(Theme.Color.inkDeep, 2, 0).Parent = knob
	Ui.new("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new(Theme.Color.brassLight, Theme.Color.tarnish),
		Parent = knob,
	})
	for k = 0, 11 do
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(2, 40),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = k * 15,
			BackgroundColor3 = Theme.Color.tarnish,
			BackgroundTransparency = 0.25,
			ZIndex = 36,
			Parent = knob,
		})
	end
	local cap = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Color.tarnish,
		ZIndex = 37,
		Parent = knob,
	})
	Ui.corner(9).Parent = cap
	Ui.stroke(Theme.Color.inkDeep, 1, 0.3).Parent = cap

	local shown = current(player)
	local dragging = false
	local function show(studs: number)
		shown = studs
		local t = share(studs)
		knob.Position = UDim2.fromScale(t, 0.5)
		for i, flame in flames do
			flame.BackgroundColor3 = if (i - 1) / (FLAMES - 1) <= t + 1e-6
				then Theme.Color.amber
				else Theme.Color.tarnish
		end
	end
	local function ready(): boolean
		return player:GetAttribute("SettingsReady") == true
	end
	local function drag(x: number)
		local t = (x - slot.AbsolutePosition.X) / math.max(slot.AbsoluteSize.X, 1)
		local studs = studsAt(t)
		if studs ~= shown then
			show(studs)
			apply(studs) -- at once, on this client
		end
		showRing(studs, false)
	end
	local function release()
		if not dragging then
			return
		end
		dragging = false
		showRing(shown, true)
		Net.Fire("SetSetting", KEY, tostring(shown))
	end

	local function begin(input: InputObject)
		if
			ready()
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragging = true
			drag(input.Position.X)
		end
	end
	plate.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			drag(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			release()
		end
	end)
	-- gamepad and keys: with the winder selected, left and right turn it a stud
	UserInputService.InputBegan:Connect(function(input)
		if GuiService.SelectedObject ~= knob or not ready() then
			return
		end
		local step = if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.Left
			then -1
			elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.Right then 1
			else 0
		if step ~= 0 then
			dragging = true
			local studs = math.clamp(shown + step, RANGE.min, RANGE.max)
			show(studs)
			apply(studs)
			release()
		end
	end)

	local function repaint()
		local on = ready()
		knob.Active = on
		knob.Selectable = on
		knob.BackgroundTransparency = if on then 0 else 0.5
		if not dragging then
			show(current(player))
		end
	end
	player:GetAttributeChangedSignal(KEY):Connect(repaint)
	player:GetAttributeChangedSignal("SettingsReady"):Connect(repaint)
	repaint()
	return repaint
end

return LanternSlider
