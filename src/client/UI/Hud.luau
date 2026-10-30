--!strict
--[[
	In-run HUD: the conductor's pocket watch (the hour, the moon, what is left of the stop and a
	compass back to the train) with its ticket, train gauges, backpack and crew roster. Each
	piece fades back when nothing about it has changed for a few seconds. Health and stamina
	have no bars: Overlay.vitals shows them on the screen's edges.
	Visible only to crew members while a run is active; the lobby has its own panel.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local CarryPriority = require(Shared.Logic.CarryPriority)
local InjuryConfig = require(Shared.Config.Injury)
local Tuning = require(Shared.Config.Tuning)
local Inventory = require(Shared.Logic.Inventory)
local Format = require(Shared.Util.Format)
local MathX = require(Shared.Util.MathX)
local Safe = require(Shared.Util.Safe)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Sky = require(script.Parent.Parent.Scenery.Sky)
local ItemIcon = require(script.Parent.ItemIcon)
local Modal = require(script.Parent.Modal)
local Overlay = require(script.Parent.Overlay)
local Operators = require(script.Parent.Operators)
local Theme = require(script.Parent.Theme)
local TouchButtons = require(script.Parent.TouchButtons)
local Ui = require(script.Parent.Ui)

local Hud = {}

local CELL = 58
local GAP = 6
local WATCH = 168 -- the pocket watch's case, in pixels
local WATCH_SCALE = 0.98 -- the case is drawn this much smaller (the ticket keeps its size)
local BLUED = Color3.fromRGB(30, 38, 70) -- heat-blued steel, the hands of a good watch
local TOUCH_GAP = 10 -- px between the watch and the touch buttons below it
local COMPACT_WATCH = 0.8 -- the watch's size on a phone, so the lifted watch stays under the crew roster
local TOUCH_GUIS = { "TouchGui", "ContextActionGui" } -- the jump button, and RUN and other action buttons
local PIPS = 60 -- the countdown ring round its dial
local BRASS_DARK = Color3.fromRGB(112, 84, 38)
-- Fading: how long a piece stays up after it changes, how fast it fades, and how far.
local WAKE_SECONDS = 5
local FADE_RATE = 2.5
local WATCH_IDLE = 0.2 -- settled, but the stop ticket must stay legible over bright scenery
local BACKPACK_IDLE = 0.5
local ROSTER_IDLE = 0.2 -- the Operators panel never fades out
-- Stamina bar above the hotbar: size, its gap above the slots (the hint line sits higher), and
-- how faint it is when full.
local STAMINA_W, STAMINA_H, STAMINA_GAP = 200, 8, 10
local STAMINA_REST = 0.7
-- The leak alert's slot, top right under the Operators panel (it follows the panel's height;
-- `y` is the gap below it). The Settings button sits under the gauge case in a run (UI/Settings).
local LEAK_SLOT = { x = 14, y = 8, w = 236, h = 40 }
-- Full-screen UI the leak slot hides behind (direct children of the HUD ScreenGui).
local FULL_SCREEN = { "RouteVote", "RunCard", "Unseal", "CarBoarding", "Eliminated" }
local leakSlot: Frame? = nil
-- The tutorial prompt's slot (Controllers/TutorialController): the left column, under the in-run
-- Settings button (14, 146, 160x40). It yields exactly like the leak slot.
local TUTORIAL_SLOT = { x = 14, y = 196, w = 236, h = 84 }
local tutorialSlot: Frame? = nil
local pingTarget: Vector3? = nil -- where the last ping came from (Hud.pointCompass)
local pingUntil = 0

local function tierStamps(tier: number): string
	return string.rep("●", tier) .. string.rep("○", 3 - tier)
end

function Hud.mount(gui: ScreenGui)
	local State = Registry.StateController

	-- the HUD setting hides only this outer frame, so container.Visible (which gates the tool keys) is untouched
	local root = Ui.new("Frame", {
		Name = "HudRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local container = Ui.new("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	-- the Settings menu's HUD toggle (player attribute "Hud", saved with the other settings)
	local player = Players.LocalPlayer
	local function applyHudSetting()
		root.Visible = player:GetAttribute("Hud") ~= "Hide"
	end
	applyHudSetting()
	player:GetAttributeChangedSignal("Hud"):Connect(applyHudSetting)

	-- Fading ---------------------------------------------------------------------------------
	-- Each piece of the HUD sits in a CanvasGroup that comes up when its figures change (or
	-- while something is wrong) and settles back to its idle look a few seconds later.
	type Fader = { group: CanvasGroup, idle: number, untilAt: number, shown: number }
	local faders: { Fader } = {}
	local function fader(name: string, idle: number, props: { [any]: any }): Fader
		props.Name = name
		props.BackgroundTransparency = 1
		props.GroupTransparency = idle
		props.Parent = container
		local f: Fader =
			{ group = Ui.new("CanvasGroup", props) :: CanvasGroup, idle = idle, untilAt = 0, shown = idle }
		table.insert(faders, f)
		return f
	end
	local function wake(f: Fader, seconds: number?)
		f.untilAt = math.max(f.untilAt, os.clock() + (seconds or WAKE_SECONDS))
	end
	local function wakeAll()
		for _, f in faders do
			wake(f)
		end
	end

	-- Pocket watch ---------------------------------------------------------------------------
	-- The conductor's watch, bottom right. Its hands tell the hour of the night, the moon sits
	-- in an aperture under the twelve, the ring of pips round the dial is what is left of this
	-- stop or leg (red where last call begins), and the small dial points back to the train.
	-- The ticket tied to it names the stop and gives the minutes.
	local watchFade = fader("PocketWatch", WATCH_IDLE, {
		Size = UDim2.fromOffset(WATCH + 206, WATCH + 16),
		Position = UDim2.new(1, -14, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
	})
	-- On a touch screen the jump and action buttons (RUN) own the bottom-right corner: the watch
	-- rides up clear of the highest of them, measured live so phones and tablets both fit, and
	-- on a phone it is drawn a little smaller so it still sits under the crew roster.
	local playerGui = gui.Parent :: Instance
	local clusterScale = Ui.new("UIScale", { Parent = watchFade.group })
	local function touchTop(exclude: Instance?): number?
		local top: number? = nil
		local half = container.AbsolutePosition.X + container.AbsoluteSize.X / 2
		for _, name in TOUCH_GUIS do
			local layer = playerGui:FindFirstChild(name)
			if layer and layer:IsA("ScreenGui") and layer.Enabled then
				for _, button in layer:GetDescendants() do
					if
						button:IsA("GuiButton")
						and button ~= exclude
						and button.Visible
						and button.AbsoluteSize.X > 0
						and button.AbsolutePosition.X > half
					then
						top = math.min(top or math.huge, button.AbsolutePosition.Y)
					end
				end
			end
		end
		return top
	end
	local function placeWatch()
		local compact = gui:GetAttribute("Compact") == true
		clusterScale.Scale = if compact then COMPACT_WATCH else 1
		local lift = 0
		-- RUN, LOOK and PING around Roblox's jump button at a thumb-sized 60 units (UI/TouchButtons,
		-- Logic/TouchCluster; `lune run layout` checks it on real screens)
		TouchButtons.apply()
		local top = touchTop(nil)
		local scale = gui:FindFirstChildOfClass("UIScale")
		if top and scale and scale.Scale > 0 then
			local bottom = container.AbsolutePosition.Y + container.AbsoluteSize.Y
			lift = math.max(0, bottom - (top - TOUCH_GAP)) / scale.Scale
		end
		watchFade.group.Position = UDim2.new(1, -14, 1, -14 - lift)
	end
	-- on its own thread: the touch buttons may still be on their way, and the rest of the UI must
	-- not wait for them (a stalled placement once kept every UI after the HUD from mounting)
	task.spawn(placeWatch)
	-- the touch controls arrive after the character and move when the screen turns
	for _, name in TOUCH_GUIS do
		local layer = playerGui:FindFirstChild(name)
		if layer then
			layer.DescendantAdded:Connect(placeWatch)
		end
	end
	playerGui.ChildAdded:Connect(function(child)
		if table.find(TOUCH_GUIS, child.Name) then
			child.DescendantAdded:Connect(placeWatch)
			task.delay(1, placeWatch)
		end
	end)
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeWatch)
	gui:GetAttributeChangedSignal("Compact"):Connect(placeWatch)
	task.spawn(function()
		-- buttons that show or move without being re-added (CAS re-lays them out on spawn)
		while true do
			task.wait(2)
			Safe.call("HudWatch", placeWatch)
		end
	end)
	local watchTag = Ui.ticket({
		Name = "Tag",
		Size = UDim2.fromOffset(218, 74),
		Position = UDim2.new(1, -(WATCH - 12), 1, -22),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 1,
		Parent = watchFade.group,
	})
	local tagTitle = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 13,
		Color = Theme.Color.inkSoft,
		Position = UDim2.fromOffset(22, 6),
		Size = UDim2.new(1, -40, 0, 16),
	})
	tagTitle.TextTruncate = Enum.TextTruncate.AtEnd
	tagTitle.Parent = watchTag
	local tagTimer = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 28,
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(22, 21),
		Size = UDim2.fromOffset(84, 30),
	})
	tagTimer.Parent = watchTag
	local tagStatus = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 15,
		Color = Theme.Color.ink,
		Position = UDim2.new(1, -28, 0, 26),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(100, 20),
		XAlign = Enum.TextXAlignment.Right,
	})
	tagStatus.Parent = watchTag
	local tagMoon = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 11,
		Color = Theme.Color.inkSoft,
		Position = UDim2.fromOffset(22, 52),
		Size = UDim2.fromOffset(110, 16),
	})
	-- shrinks to fit rather than cutting "MOONRISE · AMBER ..." short; widens when no danger is shown
	tagMoon.TextScaled = true
	Ui.new("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 7, Parent = tagMoon })
	tagMoon.Parent = watchTag
	local tagDanger = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 11,
		Color = Theme.Color.signal,
		Position = UDim2.new(1, -28, 0, 52),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(80, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	tagDanger.Parent = watchTag

	local function circle(name: string, size: number, color: Color3, parent: Instance, y: number?): Frame
		local frame = Ui.new("Frame", {
			Name = name,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.new(0.5, 0, 0.5, y or 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = parent,
		})
		Ui.corner(size // 2).Parent = frame
		return frame
	end
	-- a square the size of its parent, turned about the centre: hands, needles and pips ride it
	local function spindle(parent: Instance, rotation: number, z: number?): Frame
		return Ui.new("Frame", {
			Name = "Spindle",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Rotation = rotation,
			ZIndex = z or 1,
			Parent = parent,
		})
	end
	local function bar(parent: Instance, width: number, length: number, color: Color3, from: number): Frame
		return Ui.new("Frame", {
			Size = UDim2.fromOffset(width, length),
			Position = UDim2.new(0.5, 0, 0, from),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = parent,
		})
	end

	-- lamp-lit metal: bright toward the upper left, falling off to the lower right
	local function sheen(parent: Instance, low: number)
		Ui.new("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.45, Color3.new(0.86, 0.86, 0.86)),
				ColorSequenceKeypoint.new(1, Color3.new(low, low, low)),
			}),
			Parent = parent,
		})
	end

	local case = Ui.new("Frame", {
		Name = "Case",
		Size = UDim2.fromOffset(WATCH, WATCH),
		Position = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = watchFade.group,
	})
	Ui.corner(WATCH // 2).Parent = case
	local caseStroke = Ui.stroke(BRASS_DARK, 2, 0)
	caseStroke.Parent = case
	-- the rendered knurled bezel stands in for the flat brass disc; the dial covers its inner half
	case.BackgroundTransparency = 1
	caseStroke.Transparency = 1
	local bezel = Ui.new("ImageLabel", {
		Name = "Bezel",
		Size = UDim2.fromScale(1.2, 1.2),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Theme.Image.bezel,
		ZIndex = 0,
		Parent = case,
	})
	sheen(bezel, 0.72)
	local watchScale = Ui.new("UIScale", { Scale = WATCH_SCALE, Parent = case })
	-- the bow and crown it hangs from
	local bow = Ui.new("Frame", {
		Name = "Bow",
		Size = UDim2.fromOffset(22, 16),
		Position = UDim2.new(0.5, 0, 0, -12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = case,
	})
	Ui.corner(8).Parent = bow
	local bowStroke = Ui.stroke(Theme.Color.brass, 3, 0)
	bowStroke.Parent = bow
	sheen(bowStroke, 0.55)
	-- the crown: a short stem and a ribbed knob
	Ui.new("Frame", {
		Name = "Stem",
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0.5, 0, 0, -2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = BRASS_DARK,
		BorderSizePixel = 0,
		Parent = case,
	})
	local crown = Ui.new("Frame", {
		Name = "Crown",
		Size = UDim2.fromOffset(14, 7),
		Position = UDim2.new(0.5, 0, 0, -7),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		Parent = case,
	})
	Ui.corner(2).Parent = crown
	sheen(crown, 0.5)
	for r = 1, 3 do
		Ui.new("Frame", {
			Size = UDim2.new(0, 1, 1, -2),
			Position = UDim2.new(r / 4, 0, 0, 1),
			BackgroundColor3 = BRASS_DARK,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = crown,
		})
	end

	local ring = circle("Ring", WATCH - 12, Theme.Color.steel, case)
	sheen(ring, 0.6)
	local pips: { Frame } = {}
	for i = 0, PIPS - 1 do
		local major = i % 5 == 0
		table.insert(
			pips,
			bar(
				spindle(ring, i * 360 / PIPS),
				if major then 2 else 1,
				if major then 8 else 5,
				Theme.Color.steelLine,
				2
			)
		)
	end

	local face = circle("Face", WATCH - 34, Theme.Color.paper, case)
	Ui.stroke(Theme.Color.inkSoft, 1, 0.4).Parent = face
	-- an aged dial: the enamel yellowed and smoked toward its rim
	Ui.new("UIGradient", {
		Rotation = 70,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(214, 206, 190)),
			ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 184, 166)),
		}),
		Parent = face,
	})
	-- A Victorian enamel dial: a railroad minute track (two fine rings with the minutes ruled
	-- between them, the fives heavier) round twelve Roman hours set radially, the four as IIII.
	local dial = WATCH - 34
	for _, inset in { 3, 9 } do
		local track = circle("Track", dial - 2 * inset, Theme.Color.ink, face)
		track.BackgroundTransparency = 1
		Ui.stroke(Theme.Color.ink, 1, 0.15).Parent = track
	end
	for m = 0, 59 do
		local five = m % 5 == 0
		bar(spindle(face, m * 6), if five then 2 else 1, 6, Theme.Color.ink, 3).BackgroundTransparency = if five
			then 0
			else 0.25
	end
	local radius = dial / 2 - 17
	local numerals = { "XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI" }
	for h, numeral in numerals do
		local angle = math.rad((h - 1) * 30)
		local label = Ui.text({
			Text = numeral,
			Font = Theme.Font.dial,
			TextSize = 13,
			Color = Theme.Color.ink,
			Size = UDim2.fromOffset(30, 14),
			Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius),
			AnchorPoint = Vector2.new(0.5, 0.5),
			XAlign = Enum.TextXAlignment.Center,
		})
		-- each figure stands on the centre, so the VI is read upside down, as on the real thing
		label.Rotation = (h - 1) * 30
		label.Parent = face
	end

	-- the moon in its aperture under the twelve
	local aperture = Ui.new("Frame", {
		Name = "MoonAperture",
		Size = UDim2.fromOffset(34, 16),
		Position = UDim2.new(0.5, 0, 0.5, -24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.steel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = face,
	})
	Ui.corner(8).Parent = aperture
	Ui.stroke(Theme.Color.inkSoft, 1, 0.2).Parent = aperture
	local moonDisc = circle("Moon", 12, Theme.Color.white, aperture)
	local moonRim = Ui.stroke(Theme.Color.white, 1, 0.5)
	moonRim.Parent = moonDisc

	-- the compass: a small dial under the hands whose needle points back to the train
	local compass = circle("Compass", 32, Theme.Color.paperShade, face, 25)
	Ui.stroke(Theme.Color.inkSoft, 1, 0.3).Parent = compass
	for q = 0, 3 do
		bar(spindle(compass, q * 90), 1, 3, Theme.Color.inkSoft, 1)
	end
	local needle = spindle(compass, 0, 2)
	bar(needle, 2, 12, Theme.Color.signal, 4)
	bar(needle, 2, 9, Theme.Color.ink, 16)

	-- blued-steel spade hands: a tapered shaft with a pierced spade toward the tip, a short tail
	-- and a round counterweight past the cap
	local centre = (WATCH - 34) / 2
	local function hand(length: number, width: number, tail: number, spade: number): Frame
		local spin = spindle(face, 0, 3)
		local base = math.floor(length * 0.4)
		bar(spin, math.max(width - 2, 1), length - base, BLUED, centre - length)
		bar(spin, width, base, BLUED, centre - base)
		bar(spin, math.max(width - 1, 1), tail, BLUED, centre)
		circle("Weight", width + 2, BLUED, spin, tail)
		local at = centre - math.floor(length * 0.72)
		local function diamond(size: number, color: Color3)
			Ui.new("Frame", {
				Name = "Spade",
				Size = UDim2.fromOffset(size, size),
				Position = UDim2.new(0.5, 0, 0, at),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = spin,
			})
		end
		diamond(spade, BLUED)
		diamond(math.max(spade - 4, 1), Theme.Color.paper) -- pierced
		return spin
	end
	local hourHand = hand(32, 4, 8, 9)
	local minuteHand = hand(54, 3, 10, 7)
	local cap = circle("Cap", 8, BRASS_DARK, face)
	cap.ZIndex = 4
	-- the departure hand: from T-30 it points at the seconds left on the ring, a twitch a tick
	local tickHand = spindle(face, 0, 3)
	bar(tickHand, 2, (WATCH - 34) / 2 - 10, Theme.Color.signal, 10)
	tickHand.Visible = false
	-- the last ten seconds, in the moon's aperture
	local tickCount = Ui.text({
		Name = "TickCount",
		Text = "",
		Font = Theme.Font.display,
		TextSize = 18,
		Color = Theme.Color.signal,
		Size = UDim2.fromOffset(34, 20),
		Position = UDim2.new(0.5, 0, 0.5, -24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})
	tickCount.ZIndex = 5
	tickCount.Visible = false
	tickCount.Parent = face

	-- the crystal: a soft lamp highlight over the upper left of the glass
	local glass = circle("Glass", WATCH - 34, Theme.Color.white, case)
	glass.ZIndex = 6
	Ui.new("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.3, 0.84),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glass,
	})

	local PHASE_COLORS: { [string]: Color3 } = {
		SUNSET = Theme.Color.caution,
		MOONRISE = Color3.fromRGB(240, 160, 84),
		["AMBER MOON"] = Color3.fromRGB(236, 146, 76),
		["COPPER MOON"] = Color3.fromRGB(218, 112, 66),
		ECLIPSE = Color3.fromRGB(200, 82, 60),
		["BLOOD MOON"] = Theme.Color.signal,
		["MOON WANING"] = Color3.fromRGB(196, 110, 92),
		["PALE MOON"] = Color3.fromRGB(192, 208, 220),
		DAWN = Theme.Color.brassLight,
	}
	local function clockText(hour: number): string
		local h = hour % 24
		local minutes = math.floor(h * 60 + 1e-6) % 1440
		return string.format("%02d:%02d", minutes // 60, minutes % 60)
	end

	-- The train never moves, so its middle is found once.
	local trainCentre: Vector3? = nil
	local function trainPosition(): Vector3?
		if trainCentre == nil then
			local train = workspace:FindFirstChild("Train")
			if train and train:IsA("Model") then
				trainCentre = train:GetBoundingBox().Position
			end
		end
		return trainCentre
	end

	-- `left` is the share of the ring still lit (nil when nothing is counting down) and
	-- `lastCall` the share at the twelve that burns red.
	local function updateWatch(now: number, left: number?, lastCall: number, aboard: boolean)
		local atmosphere = Registry.AtmosphereController
		if atmosphere then
			local hour = atmosphere.Hour()
			hourHand.Rotation = (hour % 12) / 12 * 360
			minuteHand.Rotation = (hour % 1) * 360
			local name, nextName, nextFrom = Sky.phase(hour)
			local color = PHASE_COLORS[name] or Theme.Color.white
			local moon = atmosphere.Moon()
			local blood = name == "BLOOD MOON"
			moonDisc.BackgroundColor3 = if moon then moon.color else color
			moonRim.Color = if blood then Theme.Color.signal else Theme.Color.white
			moonRim.Transparency = if blood then 0.1 + 0.4 * (0.5 + 0.5 * math.sin(now * 4)) else 0.5
			tagMoon.Text = if nextName and nextFrom
				then `{name} · {nextName} {clockText(nextFrom)}`
				else `{name} · SUNRISE`
			tagMoon.TextColor3 = if blood then Theme.Color.signal else Theme.Color.inkSoft
		end
		for i, pip in pips do
			local at = (i - 1) / PIPS
			pip.BackgroundColor3 = if left == nil or at >= left
				then Theme.Color.steelLine
				elseif at < lastCall then Theme.Color.signal
				else Theme.Color.brassLight
		end
		local camera = workspace.CurrentCamera
		local target = trainPosition()
		-- a crewmate's ping: the needle swings to them for a moment, aboard or not
		local pinged = os.clock() < pingUntil and pingTarget ~= nil
		if pinged then
			target = pingTarget
		end
		if (aboard and not pinged) or camera == nil or target == nil then
			-- aboard, the needle idles about the twelve
			needle.Rotation = 8 * math.sin(now * 0.8)
		else
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			local to = (target - camera.CFrame.Position) * Vector3.new(1, 0, 1)
			needle.Rotation = -math.deg(math.atan2(look:Cross(to).Y, look:Dot(to)))
		end
		-- something stalks within 1.2r (Logic/Tells): the needle stutters
		local visibility = Registry.VisibilityController
		if visibility and visibility.Tells().stutter then
			needle.Rotation += (if math.floor(now * 9) % 2 == 0 then 1 else -1) * 7
		end
	end

	-- Train gauges -----------------------------------------------------------------------------
	-- A steel plate read left to right, row by row: the name, its figure, then a flat gauge.
	-- Always on through a run: the crew must be able to read coal, parts and hull at a glance.
	local TINT = {
		coal = Theme.Color.brass,
		parts = Theme.Color.parts,
		hull = Theme.Color.go,
		caution = Theme.Color.caution,
		signal = Theme.Color.signal,
	}
	local gaugeCase = Ui.new("Frame", {
		Name = "GaugeCase",
		Size = UDim2.fromOffset(236, 136),
		Position = UDim2.fromOffset(14, 12),
		BackgroundTransparency = 1,
		Parent = container,
	})
	-- Reserved for the leak alert (fix pass part 2 fills it). It holds nothing yet. Whatever it
	-- holds yields: it hides while a modal or full-screen UI is open, sits at the bottom of the
	-- HUD's z-order and clips its contents, so it never draws over anything.
	local leakFrame = Ui.new("Frame", {
		Name = "LeakSlot",
		Size = UDim2.fromOffset(LEAK_SLOT.w, LEAK_SLOT.h),
		Position = UDim2.new(1, -LEAK_SLOT.x, 0, 12 + 40 + LEAK_SLOT.y),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = container,
	})
	leakSlot = leakFrame
	local tutorialFrame = Ui.new("Frame", {
		Name = "TutorialSlot",
		Size = UDim2.fromOffset(TUTORIAL_SLOT.w, TUTORIAL_SLOT.h),
		Position = UDim2.fromOffset(TUTORIAL_SLOT.x, TUTORIAL_SLOT.y),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = container,
	})
	tutorialSlot = tutorialFrame
	local function slotBlocked(): boolean
		if Modal.anyOpen() then
			return true
		end
		for _, name in FULL_SCREEN do
			local screen = gui:FindFirstChild(name)
			if screen and screen:IsA("GuiObject") and screen.Visible then
				return true
			end
		end
		return false
	end

	local gauges = Ui.panel({
		Name = "Gauges",
		Size = UDim2.fromOffset(236, 96),
		Parent = gaugeCase,
	})
	Ui.padding(10, 14, 10, 12).Parent = gauges
	local function gaugeRow(
		order: number,
		label: string,
		color: Color3
	): (TextLabel, (number, Color3?, boolean?) -> (), Frame)
		local row = Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, (order - 1) * 27),
			BackgroundTransparency = 1,
			Parent = gauges,
		})
		local name = Ui.text({
			Text = label,
			Font = Theme.Font.display,
			TextSize = 14,
			Color = Theme.Color.textDim,
			Size = UDim2.fromOffset(44, 22),
		})
		name.Parent = row
		local value = Ui.text({
			Text = "",
			Font = Theme.Font.display,
			TextSize = 16,
			Color = Theme.Color.white,
			Size = UDim2.fromOffset(54, 22),
			Position = UDim2.fromOffset(44, 0),
			XAlign = Enum.TextXAlignment.Left,
		})
		value.Parent = row
		local meter, set = Ui.meter({
			Size = UDim2.new(1, -108, 0, 8),
			Position = UDim2.new(0, 108, 0.5, -4),
			FillColor = color,
		})
		meter.BackgroundColor3 = Theme.Color.steelLight
		meter.BackgroundTransparency = 0
		meter.Parent = row
		-- quarter marks etched into the empty tube
		for q = 1, 3 do
			Ui.new("Frame", {
				Name = "Tick",
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.fromScale(q / 4, 0),
				BackgroundColor3 = Color3.fromRGB(58, 58, 64),
				BorderSizePixel = 0,
				Parent = meter,
			})
		end
		local fill = meter:FindFirstChild("Fill") :: Frame
		fill.ZIndex = 2
		return value, set, meter
	end
	local coalValue, setCoal, coalMeter = gaugeRow(1, "COAL", TINT.coal)
	local partsValue, setParts = gaugeRow(2, "PARTS", TINT.parts)
	local hullValue, setHull = gaugeRow(3, "HULL", TINT.hull)
	local costMarker = Ui.new("Frame", {
		Name = "LegCost",
		BackgroundColor3 = Theme.Color.signal,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Visible = false,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 3,
		Parent = coalMeter,
	})
	local warning = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 14,
		Color = Theme.Color.signal,
		Position = UDim2.new(0, 0, 1, 14),
		Size = UDim2.new(1, 0, 0, 18),
	})
	warning.Parent = gauges

	-- Crew roster ------------------------------------------------------------------------------
	-- Operators go by call signs, not names: a letter by seat on the run, a digit from the key.
	local rosterFade = fader("CrewCase", ROSTER_IDLE, {
		Size = UDim2.fromOffset(142, 40),
		Position = UDim2.new(1, -14, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local roster = Ui.panel({
		Name = "Crew",
		Size = UDim2.fromOffset(142, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = rosterFade.group,
	})
	Ui.padding(8, 10).Parent = roster
	Ui.list(Enum.FillDirection.Vertical, 4).Parent = roster
	local rosterTitle = Ui.text({
		Text = "OPERATORS",
		Font = Theme.Font.display,
		TextSize = 14,
		Color = Theme.Color.brass,
		LayoutOrder = 0,
	})
	rosterTitle.Parent = roster
	Operators.mount(rosterFade.group, container)

	local function callSigns(map: { [string]: any }): { [string]: string }
		local keys = {}
		for key in map do
			table.insert(keys, key)
		end
		table.sort(keys)
		local signs = {}
		for i, key in keys do
			local sum = 0
			for b = 1, #key do
				sum += string.byte(key, b) * b
			end
			signs[key] = `{string.char(64 + (i - 1) % 26 + 1)}{sum % 9 + 1}`
		end
		return signs
	end

	local function renderRoster(crew: { [string]: any }?)
		for _, child in roster:GetChildren() do
			if child:IsA("Frame") and child.Name == "Member" then
				child:Destroy()
			end
		end
		local entries = {}
		local map: { [string]: any } = crew or {}
		local signs = callSigns(map)
		for key, entry in map do
			table.insert(entries, { key = key, entry = entry })
		end
		-- a solo run has nobody else to track: the panel only takes room from the watch
		rosterFade.group.Visible = #entries > 1
		table.sort(entries, function(a, b)
			local aliveA = a.entry.status ~= "Eliminated"
			local aliveB = b.entry.status ~= "Eliminated"
			if aliveA ~= aliveB then
				return aliveA
			end
			return signs[a.key] < signs[b.key]
		end)
		for i, item in entries do
			local entry = item.entry
			local status = Theme.Status[entry.status] or Theme.Status.Lobby
			local isMe = item.key == Session.userKey
			local row = Ui.new("Frame", {
				Name = "Member",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = roster,
			})
			-- your own sign carries a brass tab in front of it
			if isMe then
				Ui.new("Frame", {
					Size = UDim2.fromOffset(2, 12),
					Position = UDim2.new(0, -6, 0.5, -6),
					BackgroundColor3 = Theme.Color.brass,
					BorderSizePixel = 0,
					Parent = row,
				})
			end
			local name = Ui.text({
				Text = signs[item.key],
				Font = Theme.Font.display,
				TextSize = 16,
				Color = if entry.status == "Eliminated"
					then Theme.Color.textDim
					elseif isMe then Theme.Color.brassLight
					else Theme.Color.white,
				Size = UDim2.new(0, 26, 1, 0),
			})
			name.Parent = row
			local pill = Ui.new("TextLabel", {
				Size = UDim2.fromOffset(56, 16),
				Position = UDim2.fromScale(1, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = status.color,
				BackgroundTransparency = 0.15,
				Text = status.text,
				FontFace = Theme.Font.display,
				TextSize = 11,
				TextColor3 = Theme.Color.ink,
				Parent = row,
			})
			Ui.corner(2).Parent = pill
			if entry.load and entry.load > 0 and entry.status ~= "Eliminated" then
				for d = 1, math.min(entry.load, 6) do
					Ui.new("Frame", {
						Size = UDim2.fromOffset(4, 4),
						Position = UDim2.new(1, -58 - d * 6, 0.5, -2),
						BackgroundColor3 = Theme.Color.brass,
						BorderSizePixel = 0,
						Parent = row,
					})
				end
			end
		end
	end

	-- Backpack ------------------------------------------------------------------------------------
	local backpackFade = fader("BackpackCase", BACKPACK_IDLE, {
		Size = UDim2.fromOffset(560, CELL + 46),
		Position = UDim2.new(0.5, 0, 1, -22),
		AnchorPoint = Vector2.new(0.5, 1),
	})
	local backpack = Ui.new("Frame", {
		Name = "Backpack",
		Size = UDim2.fromOffset(4 * CELL + 3 * GAP, CELL),
		Position = UDim2.fromScale(0.5, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = backpackFade.group,
	})
	local backpackHint = Ui.text({
		Text = "",
		Font = Theme.Font.body,
		TextSize = 13,
		Color = Theme.Color.textDim,
		Position = UDim2.new(0.5, 0, 0, -40),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(2, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Center,
	})
	backpackHint.Parent = backpack

	-- Stamina: a thin brass-rimmed gauge just above the hotbar (below the hint line). It sits
	-- dim while you are fresh, brightens as a sprint drains it and pulses red when you are spent.
	local staminaCase = Ui.new("CanvasGroup", {
		Name = "Stamina",
		Size = UDim2.fromOffset(STAMINA_W, STAMINA_H),
		Position = UDim2.new(0.5, 0, 1, -22 - CELL - STAMINA_GAP),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.15,
		GroupTransparency = STAMINA_REST,
		Parent = container,
	})
	Ui.corner(3).Parent = staminaCase
	Ui.stroke(BRASS_DARK, 1, 0).Parent = staminaCase
	local staminaFill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		Parent = staminaCase,
	})
	Ui.corner(2).Parent = staminaFill
	Ui.new("UIGradient", { -- a worn brass sheen along the bar
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 164, 140)),
		Parent = staminaFill,
	})

	-- The tool in hand: its slot key holds it, E uses it (Logic/Inventory's hand rules).
	local handSlot: number? = nil
	local handId: string? = nil
	local promptsOnE: { [ProximityPrompt]: true } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.KeyboardKeyCode == Enum.KeyCode.E then
			promptsOnE[prompt] = true
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		promptsOnE[prompt] = nil
	end)
	local function promptOnE(): boolean
		for prompt in promptsOnE do
			if prompt.Parent and prompt.Enabled then
				return true
			end
			promptsOnE[prompt] = nil
		end
		return false
	end

	local renderBackpack: (inv: { [string]: any }?) -> ()
	-- gamepad: the slot a "<" press moved an item to, kept selected once the server's reorder lands
	local refocus: { slot: number, revision: any }? = nil
	local function hold(slot: number?)
		local inv = State.GetPrivate({ "inventory" })
		-- taking a tool in hand or putting it away is felt (Config/Audio ItemEquip, ItemStow)
		if slot ~= handSlot and Registry.AudioController then
			Registry.AudioController.Play(if slot then "ItemEquip" else "ItemStow")
		end
		handSlot = slot
		handId = if slot and inv and inv.items then inv.items[slot] else nil
		renderBackpack(inv)
	end
	-- the phone tool belt and bag sheet (UI/ToolBelt) take and read the hand through these
	Hud.hold = hold
	Hud.handSlot = function(): number?
		return handSlot
	end

	function renderBackpack(inv: { [string]: any }?)
		-- a gamepad selection inside the backpack would be left on a destroyed button: note its slot
		local selected = GuiService.SelectedObject
		local keep: { slot: number, left: boolean }? = nil
		if selected and selected:IsDescendantOf(backpack) then
			local item = if selected.Name == "Item" then selected else selected:FindFirstAncestor("Item")
			local slot = item and item:GetAttribute("Slot")
			if type(slot) == "number" then
				keep = { slot = slot, left = selected ~= item }
			end
		end
		for _, child in backpack:GetChildren() do
			if child.Name == "Cell" or child.Name == "Item" then
				child:Destroy()
			end
		end
		local state = inv or { items = {}, capacity = Tuning.Crew.BackpackSlots }
		local capacity = state.capacity or Tuning.Crew.BackpackSlots
		handSlot = Inventory.follow({ items = state.items or {}, capacity = capacity }, handSlot, handId)
		handId = if handSlot then state.items[handSlot] else nil
		backpack.Size = UDim2.fromOffset(capacity * CELL + (capacity - 1) * GAP, CELL)
		-- on a phone the empty wells are faint, so an empty backpack is not a row of boxes
		local faint = gui:GetAttribute("Compact") == true
		for i = 1, capacity do
			-- an empty slot: a sunken leather well in a blackened-brass bezel
			local cell = Ui.new("ImageLabel", {
				Name = "Cell",
				Size = UDim2.fromOffset(CELL, CELL),
				Position = UDim2.fromOffset((i - 1) * (CELL + GAP), 0),
				BackgroundColor3 = Theme.Color.steel,
				BackgroundTransparency = if faint then 0.8 else 0.2,
				Image = Theme.Image.cardLeather.id,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Theme.Image.cardLeather.slice,
				SliceScale = 0.16,
				ImageTransparency = if faint then 0.75 else 0.1,
				Parent = backpack,
			})
			Ui.corner(2).Parent = cell
		end
		local cursor = 0
		local heavy = 0
		local hasTool = false
		-- limb loss (Config/Injury): leftmost is kept first. Mark what losing an arm would drop,
		-- and give every item but the first a button that moves it one place left
		local priority = ReplicatedStorage:GetAttribute("LimbLoss") == true
		local wouldDrop: { [number]: boolean } = {}
		if priority then
			local items = state.items or {}
			local _, dropped =
				CarryPriority.overflow(items, math.max(capacity - InjuryConfig.OneArmPenalty, 0))
			local fromRight = #items
			for _ = 1, #dropped do
				while fromRight > 0 and CarryPriority.protected(items[fromRight]) do
					fromRight -= 1
				end
				wouldDrop[fromRight] = true
				fromRight -= 1
			end
		end
		for index, itemId in state.items or {} do
			local def = Items[itemId]
			if def then
				local width = def.slots * CELL + (def.slots - 1) * GAP
				local button = Ui.new("TextButton", {
					Name = "Item",
					Size = UDim2.fromOffset(width, CELL),
					Position = UDim2.fromOffset(cursor * (CELL + GAP), 0),
					BackgroundColor3 = if def.kind == "Tool"
						then Theme.Color.steelLight
						else Theme.Color.paper,
					BackgroundTransparency = if def.kind == "Tool" then 0.05 else 0.1,
					AutoButtonColor = true,
					Text = "",
					ZIndex = 2,
					Parent = backpack,
				})
				button:SetAttribute("Slot", index)
				Ui.corner(2).Parent = button
				-- on a phone this row only shows what you carry: the tool belt and the bag sheet (UI/ToolBelt)
				-- are the thumb-sized ways to hold, use, move and drop
				local phoneRow = gui:GetAttribute("Compact") == true and UserInputService.TouchEnabled
				if phoneRow then
					button.Interactable = false
				end
				local inHand = index == handSlot
				Ui.stroke(
					if inHand
						then Theme.Color.brassLight
						elseif def.kind == "Relic" then Theme.Color.brass
						else Theme.Color.steelLine,
					if inHand then 3 elseif def.kind == "Relic" then 2 else 1,
					0.1
				).Parent =
					button
				local icon = ItemIcon.new(itemId, UDim2.new(0, CELL - 6, 1, -6))
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.ZIndex = 3
				icon.Parent = button
				local key = Ui.text({
					Text = tostring(index),
					Font = Theme.Font.display,
					TextSize = 13,
					Color = if def.kind == "Tool" then Theme.Color.brass else Theme.Color.inkSoft,
					Position = UDim2.fromOffset(5, 2),
					Size = UDim2.fromOffset(16, 14),
				})
				key.ZIndex = 4
				key.Parent = button
				if def.heavy then
					heavy += 1
					local tag = Ui.text({
						Text = "HEAVY",
						Font = Theme.Font.display,
						TextSize = 11,
						Color = Theme.Color.signal,
						Position = UDim2.new(1, -5, 0, 2),
						AnchorPoint = Vector2.new(1, 0),
						Size = UDim2.fromOffset(40, 14),
						XAlign = Enum.TextXAlignment.Right,
					})
					tag.ZIndex = 4
					tag.Parent = button
				end
				if def.kind == "Tool" then
					hasTool = true
				end
				if priority and wouldDrop[index] then
					-- a phone scales the HUD to about 0.7: 10 px would read as 7
					local small = gui:GetAttribute("Compact") ~= true
					local mark = Ui.text({
						Text = "DROPS",
						Font = Theme.Font.display,
						TextSize = if small then 10 else 12,
						Color = Theme.Color.dangerText,
						Position = UDim2.new(1, -3, 1, -2),
						AnchorPoint = Vector2.new(1, 1),
						Size = if small then UDim2.fromOffset(40, 12) else UDim2.fromOffset(40, 14),
						XAlign = Enum.TextXAlignment.Right,
					})
					mark.ZIndex = 4
					mark.Parent = button
				end
				if priority and index > 1 then
					-- on a phone the 18 px mark is a hard tap: a bigger mark inside an invisible target
					-- in the slot's corner, so a near miss still moves the item. The HUD is scaled to
					-- about 0.7 there, so 40x36 lands near 28x25 on screen; the top band of the slot
					-- stays free for tapping the slot itself
					local compact = gui:GetAttribute("Compact") == true
					local left = if compact
						then Ui.new("TextButton", {
							Name = "MoveLeft",
							Text = "",
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(40, 36),
							Position = UDim2.new(0, 0, 1, -36),
							ZIndex = 5,
							Parent = button,
						})
						else nil
					local mark = Ui.new(if compact then "TextLabel" else "TextButton", {
						Name = if compact then "Mark" else "MoveLeft",
						Text = "<",
						FontFace = Theme.Font.display,
						TextSize = if compact then 18 else 14,
						TextColor3 = Theme.Color.bone,
						BackgroundColor3 = Theme.Color.steel,
						BackgroundTransparency = 0.15,
						Size = if compact then UDim2.fromOffset(22, 22) else UDim2.fromOffset(18, 18),
						Position = if compact then UDim2.fromOffset(1, 12) else UDim2.new(0, 2, 1, -20),
						ZIndex = 5,
						Parent = left or button,
					})
					Ui.corner(3).Parent = mark
					left = left or mark
					if gui:GetAttribute("Compact") == true and UserInputService.TouchEnabled then
						left.Interactable = false
						left.Visible = false
					end
					left.Activated:Connect(function()
						local count = #(state.items or {})
						local order = table.create(count, 0)
						for i = 1, count do
							order[i] = i
						end
						order[index - 1], order[index] = index, index - 1
						if GuiService.SelectedObject == left then
							refocus = { slot = index - 1, revision = (state :: any).revision }
						end
						Net.Fire("ReorderItems", order, (state :: any).revision or 0)
					end)
				end
				button.Activated:Connect(function()
					-- a click or tap holds a tool; on the one in hand it uses it (touch has no E)
					if def.kind == "Tool" then
						if inHand then
							Net.Fire("UseItem", index)
						else
							hold(index)
						end
					end
				end)
				button.MouseButton2Click:Connect(function()
					Net.Fire("DropItem", index)
				end)
				-- touch has no right click: press and hold the slot
				button.TouchLongPress:Connect(function(_, pressState)
					if pressState == Enum.UserInputState.Begin then
						Net.Fire("DropItem", index)
					end
				end)
				cursor += def.slots
			end
		end
		if keep then
			-- follow the moved item once the reorder lands, else stay on the same slot
			local pending = refocus
			if pending and pending.revision ~= (state :: any).revision then
				keep = { slot = pending.slot, left = true }
				refocus = nil
			end
			for _, child in backpack:GetChildren() do
				if child.Name == "Item" and child:GetAttribute("Slot") == keep.slot then
					GuiService.SelectedObject = (
						keep.left and child:FindFirstChild("MoveLeft") or child
					) :: GuiObject
				end
			end
		end
		local hints = {}
		if hasTool then
			table.insert(hints, if handSlot then "E use  ·  same key puts away" else "1-6 hold a tool")
		end
		if heavy > 0 then
			table.insert(
				hints,
				`Heavy load: {math.floor((1 - Inventory.speedMultiplier(state :: any)) * 100 + 0.5)}% slower`
			)
		end
		backpackHint.Text = table.concat(hints, "  ·  ")
	end

	-- Bindings ------------------------------------------------------------------------------
	local renderTrain: (train: any) -> ()
	local function refreshVisibility()
		local visible = Session.isMember() and Session.isRunActive()
		if visible and not container.Visible then
			-- a run that starts with the same figures as the last one still shows them
			renderTrain(State.Get({ "train" }))
			wakeAll()
		elseif not visible then
			Overlay.vitals(0, 0)
		end
		container.Visible = visible
	end

	State.Observe("public", { "crew" }, function(crew)
		renderRoster(crew)
		wake(rosterFade)
		refreshVisibility()
	end)
	State.Observe("public", { "run", "phase" }, function()
		refreshVisibility()
	end)
	State.Observe("private", { "inventory" }, function(inv)
		renderBackpack(inv)
		wake(backpackFade)
	end)
	function renderTrain(train: any)
		if train == nil then
			return
		end
		setCoal(train.coal / math.max(train.coalMax, 1))
		coalValue.Text = `{math.floor(train.coal)}/{train.coalMax}`
		partsValue.Text = tostring(train.parts)
		setParts(math.min(train.parts / 20, 1))
		local hull = train.integrity / math.max(train.integrityMax, 1)
		setHull(hull, if hull > 0.6 then TINT.hull elseif hull > 0.3 then TINT.caution else TINT.signal)
		hullValue.Text = `{math.floor(hull * 100 + 0.5)}%`
		-- leaks have their own alert in the leak slot (Controllers/LeakController), from the leak
		-- objects and only with Broken Things Markers on
		warning.Text = if train.starving then "FIREBOX EMPTY: HULL FAILING" else ""
	end
	State.Observe("public", { "train" }, renderTrain)

	-- Tool hotkeys 1-6
	local function onKey(
		_: string,
		inputState: Enum.UserInputState,
		input: InputObject
	): Enum.ContextActionResult
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local map = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
			[Enum.KeyCode.Five] = 5,
			[Enum.KeyCode.Six] = 6,
		}
		local slot = map[input.KeyCode]
		if slot and container.Visible then
			wake(backpackFade)
			local inv = State.GetPrivate({ "inventory" })
			local itemId = inv and inv.items and inv.items[slot]
			if itemId and Items[itemId] and Items[itemId].kind == "Tool" then
				hold(Inventory.select(inv, handSlot, slot))
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindAction(
		"LTO_UseTool",
		onKey,
		false,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six
	)
	-- E uses the tool in hand, but only while no interact prompt (Pick up, Pull free) is on E
	ContextActionService:BindAction("LTO_UseHand", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or not container.Visible or handSlot == nil then
			return Enum.ContextActionResult.Pass
		end
		local inv = State.GetPrivate({ "inventory" })
		if inv and inv.items and Inventory.canUseHand(inv, handSlot, promptOnE()) then
			Net.Fire("UseItem", handSlot)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)
	ContextActionService:BindAction("LTO_DropLast", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and container.Visible then
			local inv = State.GetPrivate({ "inventory" })
			if inv and inv.items and #inv.items > 0 then
				Net.Fire("DropItem", #inv.items)
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.DPadDown) -- gamepad Y is the ping now
	-- the co-op ping: V, gamepad Y or the touch PING beside LOOK (a crew member in a run only)
	ContextActionService:BindAction("LTO_Ping", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and Session.isMember() then
			Net.Fire("Ping")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("LTO_Ping", "PING")
	-- Creator mode (the Hud setting off) also takes the name tags off every crew member, locally
	task.spawn(function()
		while true do
			local hidden = Players.LocalPlayer:GetAttribute("Hud") == "Hide"
			for _, other in Players:GetPlayers() do
				local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = if hidden
						then Enum.HumanoidDisplayDistanceType.None
						else Enum.HumanoidDisplayDistanceType.Viewer
				end
			end
			task.wait(1)
		end
	end)

	-- Per-frame clock -------------------------------------------------------------------------
	local lastPhase = ""
	local span, spanEnds = 1, 0 -- the countdown the watch's ring is measuring
	local heartAt = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not container.Visible then
			return
		end
		local now = Session.now()
		local phase = Session.phase()
		if phase ~= lastPhase then
			lastPhase = phase
			wakeAll()
		end
		local run = State.Get({ "run" }) or {}
		local station = run.station
		local destination = run.destination
		local endsAt = run.phaseEndsAt or now
		local stop = run.nextStop or 1
		local stopCount = run.stopCount or Tuning.Run.StationCount
		local stopText = if stop > stopCount then "FINAL LEG" else `STOP {stop}/{stopCount}`

		local timerValue = math.max(endsAt - now, 0)
		local title, status = "", ""
		local statusColor = Theme.Color.ink
		local timerColor = Theme.Color.ink
		local left: number? = nil
		local lastCall = 0
		local danger = ""

		if phase == "Boarding" then
			title, status = "ALL ABOARD", "BOARDING"
		elseif phase == "Junction" then
			title, status = `JUNCTION AHEAD · {stopText}`, "CHOOSE A LINE"
		elseif phase == "Cruise" then
			title = if destination then `NEXT: {string.upper(destination.name)}` else "EN ROUTE"
			status = if destination then `{destination.distanceKm} KM` else ""
			if destination and not destination.terminus then
				danger = if destination.sealed then "DANGER ???" else `DANGER {tierStamps(destination.tier)}`
			end
		elseif phase == "Arrival" then
			title, status = if station then string.upper(station.name) else "", "ARRIVING"
		elseif phase == "Dwell" or phase == "LastCall" then
			title = if station then `{string.upper(station.name)} · {stopText}` else stopText
			timerValue = Registry.DepartureClock.Remaining() or timerValue
			status = if phase == "LastCall" then "LAST CALL" else "DOORS OPEN"
			if phase == "LastCall" then
				statusColor = Theme.Color.signal
				timerColor = Theme.Color.signal
			end
			if station then
				left = 1 - MathX.saturate((now - station.startedAt) / station.dwell)
				lastCall = station.lastCall / station.dwell
				danger = `DANGER {tierStamps(station.tier)}`
			end
		elseif phase == "Departure" then
			title = if station then string.upper(station.name) else ""
			status, statusColor, timerColor = "DEPARTING", Theme.Color.signal, Theme.Color.signal
			if Registry.DepartureClock.InGrace() then
				-- the Last Call grace: the station is still docked, the watch counts it down
				status = "LAST CALL"
				timerValue = Registry.DepartureClock.Remaining() or timerValue
			end
		elseif phase == "Terminus" then
			title, status = "TERMINUS", "END OF THE LINE"
		end
		-- any other countdown fills the ring when it starts and empties as it runs
		if left == nil and timerValue > 0 then
			if endsAt ~= spanEnds then
				spanEnds, span = endsAt, math.max(timerValue, 1)
			end
			left = timerValue / span
		end
		tagTitle.Text = title
		tagStatus.Text = status
		tagStatus.TextColor3 = statusColor
		tagTimer.Text = Format.clock(timerValue)
		tagTimer.TextColor3 = timerColor
		tagDanger.Text = danger
		tagMoon.Size = if danger == "" then UDim2.new(1, -50, 0, 16) else UDim2.fromOffset(110, 16)
		local hurry = phase == "LastCall" or phase == "Departure"
		watchScale.Scale = WATCH_SCALE * (if hurry then 1 + 0.03 * math.sin(now * 10) else 1)
		if hurry or (phase == "Dwell" and timerValue < 30) then
			wake(watchFade, 0.5)
		end
		updateWatch(now, left, lastCall, Session.status() == "Aboard")

		-- Departure warning (Controllers/DepartureClock): ticking from T-30, shaking from T-10
		local warn = Registry.DepartureClock.Level()
		local ticking = warn == "warning" or warn == "escalated"
		local remaining = Registry.DepartureClock.Remaining() or 0
		tickHand.Visible = ticking
		if ticking then
			wake(watchFade, 0.5)
			local second = math.ceil(remaining)
			local twitch = math.max(0, 1 - (second - remaining) * 8) -- a small kick just after each tick
			tickHand.Rotation = (second % 60) * 6 + 2 * twitch
		end
		local glow = if ticking then 0.5 + 0.5 * math.sin(now * 2) else 0
		-- the last seconds: the rim burns ember, then moon red once the count is out loud
		caseStroke.Color = Theme.Color.ember:Lerp(Theme.Color.signal, if warn == "escalated" then 1 else 0)
		caseStroke.Thickness = 2 + 2 * glow
		caseStroke.Transparency = 1 - glow
		local escalated = warn == "escalated"
		tickCount.Visible = escalated
		aperture.Visible = not escalated
		tickCount.Text = if escalated then tostring(math.ceil(remaining)) else ""
		case.Position = if escalated
			then UDim2.new(1, math.random(-1, 1), 1, math.random(-1, 1))
			else UDim2.fromScale(1, 1)

		-- Leg coal cost marker
		local train = State.Get({ "train" })
		if destination and train and (phase == "Cruise") then
			local fraction = math.min(
				destination.coalCost / math.max(train.coalMax, 1),
				train.coal / math.max(train.coalMax, 1)
			)
			costMarker.Visible = true
			costMarker.AnchorPoint = Vector2.new(1, 0)
			costMarker.Position = UDim2.fromScale(train.coal / math.max(train.coalMax, 1), 0)
			costMarker.Size = UDim2.fromScale(fraction, 1)
		else
			costMarker.Visible = false
		end

		-- Vitals: wounds and breath on the screen's edges (Overlay.vitals), the heart when it is bad
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local life = if humanoid and humanoid.MaxHealth > 0
			then MathX.saturate(humanoid.Health / humanoid.MaxHealth)
			else 1
		local wound = MathX.saturate((0.95 - life) / 0.85)
		local winded = 0
		local movement = Registry.MovementController
		if movement then
			local fraction = movement.StaminaFraction()
			winded = MathX.saturate((0.45 - fraction) / 0.45)
			local exhausted = movement.IsExhausted()
			if exhausted then
				winded = math.max(winded, 0.75 + 0.25 * math.sin(now * 5))
			end
			staminaFill.Size = UDim2.new(MathX.saturate(fraction), -4, 1, -4)
			staminaFill.BackgroundColor3 = if exhausted
				then Theme.Color.signal
				else Theme.Color.ember:Lerp(Theme.Color.brass, MathX.saturate(fraction * 1.6))
			staminaCase.GroupTransparency = if exhausted
				then 0.25 * (0.5 + 0.5 * math.sin(now * 6))
				else STAMINA_REST * MathX.saturate((fraction - 0.5) / 0.5)
		end
		Overlay.vitals(wound, winded)
		-- (GrabController keeps the heart while a Hollow holds you)
		local held = character ~= nil and character:GetAttribute("GrabStyle") ~= nil
		if life < 0.35 and life > 0 and not held and os.clock() >= heartAt then
			heartAt = os.clock() + 0.5 + 0.9 * life
			if Registry.AudioController then
				Registry.AudioController.Play("Heartbeat", nil, 0.5 + (0.35 - life), 1)
			end
		end

		leakFrame.Visible = not slotBlocked()
		-- the leak slot rides under the Operators panel, whatever its height (crew size)
		local uiScale = gui:FindFirstChildOfClass("UIScale")
		local rosterHeight = if rosterFade.group.Visible
			then rosterFade.group.AbsoluteSize.Y / (if uiScale and uiScale.Scale > 0 then uiScale.Scale else 1)
			else -LEAK_SLOT.y + 2
		leakFrame.Position = UDim2.new(1, -LEAK_SLOT.x, 0, 12 + rosterHeight + LEAK_SLOT.y)
		tutorialFrame.Visible = leakFrame.Visible

		local clock = os.clock()
		for _, f in faders do
			local target = if clock < f.untilAt then 0 else f.idle
			f.shown = MathX.approach(f.shown, target, dt * FADE_RATE)
			f.group.GroupTransparency = f.shown
		end
	end)
end

-- The leak alert's layout slot under the Operators panel (nil before mount). Parent the alert into it;
-- the slot hides itself whenever a modal or full-screen UI is open.
-- A crewmate pinged at `position`: the watch's compass points there for Tuning.Ping.CompassSeconds.
function Hud.pointCompass(position: Vector3)
	pingTarget = position
	pingUntil = os.clock() + Tuning.Ping.CompassSeconds
end

function Hud.leakSlot(): Frame?
	return leakSlot
end

-- The tutorial prompt's slot (nil before mount). It is shown only in a run, with the HUD, and
-- never while a modal or full-screen UI is open: check `Visible` on its ancestors.
function Hud.tutorialSlot(): Frame?
	return tutorialSlot
end

return Hud
