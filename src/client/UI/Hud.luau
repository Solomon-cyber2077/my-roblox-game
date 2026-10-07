--!strict
--[[
	In-run HUD: station clock, the night dial (24-hour time and the moon's phases), train
	gauges, backpack, crew roster and stamina.
	Visible only to crew members while a run is active; the lobby has its own panel.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Hud = {}

local CELL = 58
local GAP = 6

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

	-- Station clock -------------------------------------------------------------------------
	local clock = Ui.ticket({
		Name = "StationClock",
		Size = UDim2.fromOffset(380, 96),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = container,
	})
	local clockTitle = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 15,
		Color = Theme.Color.inkSoft,
		Position = UDim2.fromOffset(26, 8),
		Size = UDim2.new(1, -40, 0, 18),
	})
	clockTitle.Parent = clock
	local clockTimer = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 42,
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.new(0.5, 0, 0, 46),
	})
	clockTimer.Parent = clock
	local clockStatus = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 19,
		Color = Theme.Color.ink,
		Position = UDim2.new(1, -14, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.5, 0, 0, 22),
		XAlign = Enum.TextXAlignment.Right,
	})
	clockStatus.Parent = clock
	local clockDanger = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 13,
		Color = Theme.Color.signal,
		Position = UDim2.new(1, -14, 0, 54),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.5, 0, 0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	clockDanger.Parent = clock
	local barFrame, setBar = Ui.meter({
		Size = UDim2.new(1, -40, 0, 6),
		Position = UDim2.new(0, 26, 1, -14),
		FillColor = Theme.Color.ink,
	})
	barFrame.BackgroundColor3 = Theme.Color.paperShade
	barFrame.BackgroundTransparency = 0
	barFrame.Parent = clock
	local lastCallZone = Ui.new("Frame", {
		Name = "LastCallZone",
		BackgroundColor3 = Theme.Color.signal,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.15, 1),
		Parent = barFrame,
	})
	Ui.corner(3).Parent = lastCallZone
	local clockScale = Ui.new("UIScale", { Parent = clock })

	-- Night dial: the 24-hour time, the night from dusk to dawn with the moon on it, and
	-- what the moon is doing now and next, so the crew know when the blood moon comes
	local dial = Ui.panel({
		Name = "NightDial",
		Size = UDim2.fromOffset(380, 50),
		Position = UDim2.new(0.5, 0, 0, 114),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = container,
	})
	local dialTime = Ui.text({
		Text = "18:00",
		Font = Theme.Font.display,
		TextSize = 28,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 74, 1, 0),
	})
	dialTime.Parent = dial
	local track = Ui.new("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Color.steelLine,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(92, 25),
		Size = UDim2.fromOffset(150, 2),
		Parent = dial,
	})
	local DIAL_FROM, DIAL_TO = 18, 30.5 -- six in the evening to half past six in the morning
	local function along(hour: number): UDim2
		return UDim2.fromScale(MathX.saturate((hour - DIAL_FROM) / (DIAL_TO - DIAL_FROM)), 0.5)
	end
	for h = DIAL_FROM, 30, 2 do
		Ui.new("Frame", {
			BackgroundColor3 = Theme.Color.textDim,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = along(h),
			Size = UDim2.fromOffset(1, if h % 6 == 0 then 9 else 5),
			Parent = track,
		})
	end
	-- the marks the crew watch for: moonrise, the blood moon at two, sunrise at the Terminus
	for _, mark in
		{
			{ hour = 18.2, color = Color3.fromRGB(240, 160, 84), size = 6 },
			{ hour = 26, color = Theme.Color.signal, size = 9 },
			{ hour = 30.5, color = Theme.Color.brassLight, size = 6 },
		}
	do
		local dot = Ui.new("Frame", {
			BackgroundColor3 = mark.color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = along(mark.hour),
			Size = UDim2.fromOffset(mark.size, mark.size),
			Parent = track,
		})
		Ui.corner(mark.size).Parent = dot
	end
	local moonMark = Ui.new("Frame", {
		Name = "Moon",
		BackgroundColor3 = Color3.fromRGB(240, 160, 84),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = along(DIAL_FROM),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 3,
		Parent = track,
	})
	Ui.corner(7).Parent = moonMark
	local moonRing = Ui.stroke(Theme.Color.white, 1.5, 0.3)
	moonRing.Parent = moonMark
	local dialPhase = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 16,
		Color = Theme.Color.white,
		Position = UDim2.new(1, -12, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(124, 20),
		XAlign = Enum.TextXAlignment.Right,
	})
	dialPhase.Parent = dial
	local dialNext = Ui.text({
		Text = "",
		Font = Theme.Font.body,
		TextSize = 12,
		Color = Theme.Color.textDim,
		Position = UDim2.new(1, -12, 0, 27),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(124, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	-- Long names such as "COPPER MOON AT 21:36" must fit beside the night track.
	dialNext.TextScaled = true
	Ui.new("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = 12, Parent = dialNext })
	dialNext.Parent = dial
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
	local function updateDial(now: number)
		local atmosphere = Registry.AtmosphereController
		if atmosphere == nil then
			return
		end
		local hour = atmosphere.Hour()
		dialTime.Text = clockText(hour)
		local name, nextName, nextFrom = Sky.phase(hour)
		local color = PHASE_COLORS[name] or Theme.Color.white
		dialPhase.Text = name
		dialPhase.TextColor3 = color
		dialNext.Text = if nextName and nextFrom
			then `{nextName} AT {clockText(nextFrom)}`
			else `SUNRISE AT {clockText(DIAL_TO)}`
		moonMark.Position = along(hour)
		local moon = atmosphere.Moon()
		local blood = name == "BLOOD MOON"
		moonMark.BackgroundColor3 = if moon then moon.color else color
		moonRing.Color = if blood then Theme.Color.signal else Theme.Color.white
		moonRing.Transparency = if blood then 0.1 + 0.4 * (0.5 + 0.5 * math.sin(now * 4)) else 0.35
	end

	-- Train gauges -----------------------------------------------------------------------------
	-- A solid black plate read left to right, row by row: the name, its figure, then a lit tube.
	local NEON = {
		coal = Color3.fromRGB(255, 190, 84),
		parts = Color3.fromRGB(150, 214, 255),
		hull = Color3.fromRGB(96, 255, 150),
		caution = Color3.fromRGB(255, 176, 54),
		signal = Color3.fromRGB(255, 72, 56),
	}
	local gauges = Ui.panel({
		Name = "Gauges",
		Size = UDim2.fromOffset(236, 96),
		Position = UDim2.fromOffset(14, 12),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0,
		Parent = container,
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
			XAlign = Enum.TextXAlignment.Right,
		})
		value.Parent = row
		local meter, set = Ui.meter({
			Size = UDim2.new(1, -108, 0, 8),
			Position = UDim2.new(0, 108, 0.5, -4),
			FillColor = color,
		})
		meter.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
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
		-- the lit tube: a glowing rim round the fill, a sheen across its top
		local fill = meter:FindFirstChild("Fill") :: Frame
		fill.ZIndex = 2
		local glow = Ui.stroke(color, 1.5, 0.45)
		glow.Parent = fill
		Ui.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
			Parent = fill,
		})
		local function setNeon(fraction: number, tint: Color3?, instant: boolean?)
			set(fraction, tint, instant)
			if tint then
				glow.Color = tint
			end
		end
		return value, setNeon, meter
	end
	local coalValue, setCoal, coalMeter = gaugeRow(1, "COAL", NEON.coal)
	local partsValue, setParts = gaugeRow(2, "PARTS", NEON.parts)
	local hullValue, setHull = gaugeRow(3, "HULL", NEON.hull)
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
	local roster = Ui.panel({
		Name = "Crew",
		Size = UDim2.fromOffset(142, 40),
		Position = UDim2.new(1, -14, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0,
		Parent = container,
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
			Ui.corner(8).Parent = pill
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
	local backpack = Ui.new("Frame", {
		Name = "Backpack",
		Size = UDim2.fromOffset(4 * CELL + 3 * GAP, CELL),
		Position = UDim2.new(0.5, 0, 1, -22),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = container,
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
	local staminaFrame, setStamina = Ui.meter({
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.fromOffset(0, -18),
		FillColor = Theme.Color.sky,
	})
	staminaFrame.Parent = backpack

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
			Ui.corner(6).Parent = cell
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
				Ui.corner(6).Parent = button
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
		container.Visible = Session.isMember() and Session.isRunActive()
	end

	State.Observe("public", { "crew" }, function(crew)
		renderRoster(crew)
		refreshVisibility()
	end)
	State.Observe("public", { "run", "phase" }, function()
		refreshVisibility()
	end)
	State.Observe("private", { "inventory" }, renderBackpack)
	State.Observe("public", { "train" }, function(train: any)
		if train == nil then
			return
		end
		setCoal(train.coal / math.max(train.coalMax, 1))
		coalValue.Text = `{math.floor(train.coal)}/{train.coalMax}`
		partsValue.Text = tostring(train.parts)
		setParts(math.min(train.parts / 20, 1))
		local hull = train.integrity / math.max(train.integrityMax, 1)
		setHull(hull, if hull > 0.6 then NEON.hull elseif hull > 0.3 then NEON.caution else NEON.signal)
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
	RunService.RenderStepped:Connect(function()
		if not container.Visible then
			return
		end
		local now = Session.now()
		local phase = Session.phase()
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
		local showBar = false
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
				showBar = true
				setBar(MathX.saturate((now - station.startedAt) / station.dwell), nil, true)
				lastCallZone.Size = UDim2.fromScale(station.lastCall / station.dwell, 1)
				danger = `DANGER {tierStamps(station.tier)}`
			end
		elseif phase == "Departure" then
			title = if station then string.upper(station.name) else ""
			status, statusColor, timerColor = "DEPARTING", Theme.Color.signal, Theme.Color.signal
		elseif phase == "Terminus" then
			title, status = "TERMINUS", "END OF THE LINE"
		end
		clockTitle.Text = title
		clockStatus.Text = status
		clockStatus.TextColor3 = statusColor
		clockTimer.Text = Format.clock(timerValue)
		clockTimer.TextColor3 = timerColor
		clockDanger.Text = danger
		barFrame.Visible = showBar
		local pulse = if phase == "LastCall" or phase == "Departure" then 1 + 0.04 * math.sin(now * 10) else 1
		clockScale.Scale = pulse
		updateDial(now)

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

		local movement = Registry.MovementController
		if movement then
			local fraction = movement.StaminaFraction()
			local color = if movement.IsExhausted() then Color3.fromRGB(214, 86, 64) else Theme.Color.sky
			staminaFrame.Visible = fraction < 0.999 or movement.IsSprinting()
			setStamina(fraction, color, true)
		end
	end)
end

return Hud
