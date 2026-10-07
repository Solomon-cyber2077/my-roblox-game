--!strict
--[[
	In-run HUD: the conductor's pocket watch (the hour, the moon, what is left of the stop and a
	compass back to the train) with its ticket, train gauges, backpack and crew roster. Each
	piece fades back when nothing about it has changed for a few seconds. Health and stamina
	have no bars: Overlay.vitals shows them on the screen's edges.
	Visible only to crew members while a run is active; the lobby has its own panel.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local Inventory = require(Shared.Logic.Inventory)
local Format = require(Shared.Util.Format)
local MathX = require(Shared.Util.MathX)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Sky = require(script.Parent.Parent.Scenery.Sky)
local ItemIcon = require(script.Parent.ItemIcon)
local Overlay = require(script.Parent.Overlay)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Hud = {}

local CELL = 58
local GAP = 6
local WATCH = 168 -- the pocket watch's case, in pixels
local PIPS = 60 -- the countdown ring round its dial
local BRASS_DARK = Color3.fromRGB(112, 84, 38)
-- Fading: how long a piece stays up after it changes, how fast it fades, and how far.
local WAKE_SECONDS = 5
local FADE_RATE = 2.5
local WATCH_IDLE = 0.4
local BACKPACK_IDLE = 0.5
local HIDDEN = 1

local function tierStamps(tier: number): string
	return string.rep("●", tier) .. string.rep("○", 3 - tier)
end

function Hud.mount(gui: ScreenGui)
	local State = Registry.StateController

	local container = Ui.new("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

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
	tagMoon.TextTruncate = Enum.TextTruncate.AtEnd
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
	Ui.stroke(BRASS_DARK, 2, 0).Parent = case
	local watchScale = Ui.new("UIScale", { Parent = case })
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
	Ui.stroke(Theme.Color.brass, 3, 0).Parent = bow
	Ui.new("Frame", {
		Name = "Crown",
		Size = UDim2.fromOffset(10, 6),
		Position = UDim2.new(0.5, 0, 0, -5),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = BRASS_DARK,
		BorderSizePixel = 0,
		Parent = case,
	})

	local ring = circle("Ring", WATCH - 12, Theme.Color.steel, case)
	local pips: { Frame } = {}
	for i = 0, PIPS - 1 do
		local major = i % 5 == 0
		table.insert(
			pips,
			bar(
				spindle(ring, i * 360 / PIPS),
				if major then 3 else 2,
				if major then 8 else 6,
				Theme.Color.steelLine,
				2
			)
		)
	end

	local face = circle("Face", WATCH - 34, Theme.Color.paper, case)
	Ui.stroke(Theme.Color.inkSoft, 1, 0.4).Parent = face
	for h = 0, 11 do
		bar(spindle(face, h * 30), 2, if h % 3 == 0 then 7 else 4, Theme.Color.ink, 3)
	end
	local radius = (WATCH - 34) / 2 - 18
	for h, numeral in { [0] = "XII", [3] = "III", [6] = "VI", [9] = "IX" } do
		local angle = math.rad(h * 30)
		Ui.text({
			Text = numeral,
			Font = Theme.Font.display,
			TextSize = 12,
			Color = Theme.Color.ink,
			Size = UDim2.fromOffset(26, 14),
			Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius),
			AnchorPoint = Vector2.new(0.5, 0.5),
			XAlign = Enum.TextXAlignment.Center,
		}).Parent =
			face
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

	local hourHand = spindle(face, 0, 3)
	bar(hourHand, 4, 30, Theme.Color.ink, (WATCH - 34) / 2 - 30)
	local minuteHand = spindle(face, 0, 3)
	bar(minuteHand, 2, 46, Theme.Color.ink, (WATCH - 34) / 2 - 46)
	local cap = circle("Cap", 8, BRASS_DARK, face)
	cap.ZIndex = 4

	local PHASE_COLORS: { [string]: Color3 } = {
		SUNSET = Theme.Color.caution,
		MOONRISE = Color3.fromRGB(240, 160, 84),
		["AMBER MOON"] = Color3.fromRGB(236, 146, 76),
		["COPPER MOON"] = Color3.fromRGB(218, 112, 66),
		ECLIPSE = Color3.fromRGB(200, 82, 60),
		["BLOOD MOON"] = Theme.Color.signal,
		["MOON WANING"] = Color3.fromRGB(196, 110, 92),
		["PALE MOON"] = Color3.fromRGB(214, 206, 196),
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
		if aboard or camera == nil or target == nil then
			-- aboard, the needle idles about the twelve
			needle.Rotation = 8 * math.sin(now * 0.8)
		else
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			local to = (target - camera.CFrame.Position) * Vector3.new(1, 0, 1)
			needle.Rotation = -math.deg(math.atan2(look:Cross(to).Y, look:Dot(to)))
		end
	end

	-- Train gauges -----------------------------------------------------------------------------
	-- A steel plate read left to right, row by row: the name, its figure, then a flat gauge.
	-- It shows when a figure moves or something is wrong, and is gone otherwise.
	local TINT = {
		coal = Theme.Color.brass,
		parts = Theme.Color.parts,
		hull = Theme.Color.go,
		caution = Theme.Color.caution,
		signal = Theme.Color.signal,
	}
	local gaugeFade = fader("GaugeCase", HIDDEN, {
		Size = UDim2.fromOffset(236, 136),
		Position = UDim2.fromOffset(14, 12),
	})
	local gauges = Ui.panel({
		Name = "Gauges",
		Size = UDim2.fromOffset(236, 96),
		Parent = gaugeFade.group,
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
	local rosterFade = fader("CrewCase", HIDDEN, {
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

	local function renderBackpack(inv: { [string]: any }?)
		for _, child in backpack:GetChildren() do
			if child.Name == "Cell" or child.Name == "Item" then
				child:Destroy()
			end
		end
		local state = inv or { items = {}, capacity = Tuning.Crew.BackpackSlots }
		local capacity = state.capacity or Tuning.Crew.BackpackSlots
		backpack.Size = UDim2.fromOffset(capacity * CELL + (capacity - 1) * GAP, CELL)
		for i = 1, capacity do
			local cell = Ui.new("Frame", {
				Name = "Cell",
				Size = UDim2.fromOffset(CELL, CELL),
				Position = UDim2.fromOffset((i - 1) * (CELL + GAP), 0),
				BackgroundColor3 = Theme.Color.steel,
				BackgroundTransparency = 0.35,
				Parent = backpack,
			})
			Ui.corner(2).Parent = cell
			Ui.stroke(Theme.Color.steelLine, 1, 0.3).Parent = cell
		end
		local cursor = 0
		local heavy = 0
		local hasTool = false
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
				Ui.corner(2).Parent = button
				Ui.stroke(
					if def.kind == "Relic" then Theme.Color.brass else Theme.Color.steelLine,
					if def.kind == "Relic" then 2 else 1,
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
				button.Activated:Connect(function()
					if def.kind == "Tool" then
						Net.Fire("UseItem", index)
					end
				end)
				button.MouseButton2Click:Connect(function()
					Net.Fire("DropItem", index)
				end)
				cursor += def.slots
			end
		end
		local hints = {}
		if hasTool then
			table.insert(hints, "1-6 use a tool")
		end
		if heavy > 0 then
			table.insert(
				hints,
				`Heavy load: {math.floor((1 - Inventory.speedMultiplier(state :: any)) * 100 + 0.5)}% slower`
			)
		end
		if #state.items > 0 then
			table.insert(hints, "right-click drops")
		end
		backpackHint.Text = table.concat(hints, "  ·  ")
	end

	-- Bindings ------------------------------------------------------------------------------
	local function refreshVisibility()
		local visible = Session.isMember() and Session.isRunActive()
		if visible and not container.Visible then
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
	-- the gauges come up when coal goes in, parts or the hull change, or a leak opens; the
	-- steady burn of coal on the move does not wake them
	local lastTrain = { coal = 0, parts = 0, integrity = 0, breaches = 0 }
	State.Observe("public", { "train" }, function(train: any)
		if train == nil then
			return
		end
		local leaks = 0
		for _ in train.breaches or {} do
			leaks += 1
		end
		if
			train.coal > lastTrain.coal + 0.5
			or train.parts ~= lastTrain.parts
			or math.abs(train.integrity - lastTrain.integrity) >= 1
			or leaks ~= lastTrain.breaches
		then
			wake(gaugeFade)
		end
		lastTrain = { coal = train.coal, parts = train.parts, integrity = train.integrity, breaches = leaks }
		setCoal(train.coal / math.max(train.coalMax, 1))
		coalValue.Text = `{math.floor(train.coal)}/{train.coalMax}`
		partsValue.Text = tostring(train.parts)
		setParts(math.min(train.parts / 20, 1))
		local hull = train.integrity / math.max(train.integrityMax, 1)
		setHull(hull, if hull > 0.6 then TINT.hull elseif hull > 0.3 then TINT.caution else TINT.signal)
		hullValue.Text = `{math.floor(hull * 100 + 0.5)}%`
		local breaches = 0
		for _ in train.breaches or {} do
			breaches += 1
		end
		if train.starving then
			warning.Text = "FIREBOX EMPTY: HULL FAILING"
		elseif breaches > 0 then
			warning.Text = `{breaches} STEAM LEAK{if breaches > 1 then "S" else ""}: PATCH WITH PARTS`
		else
			warning.Text = ""
		end
	end)

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
				Net.Fire("UseItem", slot)
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
	ContextActionService:BindAction("LTO_DropLast", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and container.Visible then
			local inv = State.GetPrivate({ "inventory" })
			if inv and inv.items and #inv.items > 0 then
				Net.Fire("DropItem", #inv.items)
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

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
				danger = `DANGER {tierStamps(destination.tier)}`
			end
		elseif phase == "Arrival" then
			title, status = if station then string.upper(station.name) else "", "ARRIVING"
		elseif phase == "Dwell" or phase == "LastCall" then
			title = if station then `{string.upper(station.name)} · {stopText}` else stopText
			timerValue = if station then math.max(station.departAt - now, 0) else timerValue
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
		local hurry = phase == "LastCall" or phase == "Departure"
		watchScale.Scale = if hurry then 1 + 0.03 * math.sin(now * 10) else 1
		if hurry or (phase == "Dwell" and timerValue < 30) then
			wake(watchFade, 0.5)
		end
		if warning.Text ~= "" then
			wake(gaugeFade, 0.5)
		end
		updateWatch(now, left, lastCall, Session.status() == "Aboard")

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
			winded = MathX.saturate((0.45 - movement.StaminaFraction()) / 0.45)
			if movement.IsExhausted() then
				winded = math.max(winded, 0.75 + 0.25 * math.sin(now * 5))
			end
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

		local clock = os.clock()
		for _, f in faders do
			local target = if clock < f.untilAt then 0 else f.idle
			f.shown = MathX.approach(f.shown, target, dt * FADE_RATE)
			f.group.GroupTransparency = f.shown
		end
	end)
end

return Hud
