--!strict
--[[
	Junction ballot: one black ticket per line on offer, showing the station, its danger in
	boxes, the coal the leg will burn against what the bunker holds and the live tally.
	Clicking a ticket's button casts (or moves) your vote; its arrow lays the station's
	dossier on the table in the middle of the screen: the leg, the haul, the dangers, what
	stands in the yard and the clerk's note. Gamepad B, the backdrop or CLOSE puts it away.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
local Ledger = require(Shared.Logic.Ledger)
local Vote = require(Shared.Logic.Vote)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local RouteVote = {}

local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

local CARD = Color3.fromRGB(8, 8, 10)
local BOX_EMPTY = Color3.fromRGB(32, 32, 36)
local BOX_RIM = Color3.fromRGB(74, 74, 82)
local TIER_COLOR = {
	Color3.fromRGB(96, 255, 150),
	Color3.fromRGB(255, 176, 54),
	Color3.fromRGB(255, 72, 56),
}
local BLUE_INK = Color3.fromRGB(38, 58, 120)

local LAYOUT_TEXT = {
	Street = "A lane to the far edge, a cross street, lots either side",
	Plaza = "An open square at its heart, lanes in and out",
	Yard = "A forecourt by the platform, buildings all round it",
	Sidings = "Tracks the length of the yard, heaps between them",
}

-- "ToolChest" -> "TOOL CHEST"
local function words(id: string): string
	return string.upper((string.gsub(id, "(%l)(%u)", "%1 %2")))
end

local function routeHint(arch: Stations.Archetype): string
	if arch.terminus then
		return "The last stop"
	end
	local lootNames = { "coal", "parts", "relics", "tools" }
	local lootBest = ""
	local lootValue = 1
	for _, kind in lootNames do
		local value = arch.loot[kind == "relics" and "relic" or kind] or 0
		if value > lootValue then
			lootValue = value
			lootBest = kind
		end
	end
	local hazardNames = { fog = "heavy fog", collapse = "unstable ground", hollows = "Hollows nearby" }
	local hazardBest = ""
	local hazardValue = 1
	for _, kind in { "fog", "collapse", "hollows" } do
		local value = arch.hazard[kind] or 0
		if value > hazardValue then
			hazardValue = value
			hazardBest = hazardNames[kind]
		end
	end
	local loot = if lootBest ~= "" then `Lots of {lootBest}` else "Balanced haul"
	local hazard = if hazardBest ~= "" then hazardBest else "standard hazards"
	return `{loot}, {hazard}`
end

local function plural(word: string, count: number): string
	if count == 1 then
		return word
	end
	local last = string.sub(word, -1)
	if last == "S" or last == "X" or last == "H" then
		return word .. "ES"
	end
	return word .. "S"
end

-- A row of `of` little boxes, the first `filled` of them lit in `color`.
local function boxes(
	filled: number,
	of: number,
	color: Color3,
	w: number,
	h: number,
	gap: number,
	empty: Color3?,
	rim: Color3?
): Frame
	local row = Ui.new("Frame", {
		Name = "Boxes",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(of * w + (of - 1) * gap, h),
	})
	for i = 1, of do
		local lit = i <= filled
		local box = Ui.new("Frame", {
			Size = UDim2.fromOffset(w, h),
			Position = UDim2.fromOffset((i - 1) * (w + gap), 0),
			BackgroundColor3 = if lit then color else empty or BOX_EMPTY,
			BorderSizePixel = 0,
			Parent = row,
		})
		Ui.corner(1).Parent = box
		Ui.stroke(if lit then color else rim or BOX_RIM, 1, if lit then 0.55 else 0.2).Parent = box
	end
	return row
end

function RouteVote.mount(gui: ScreenGui)
	local State = Registry.StateController

	local container = Ui.new("Frame", {
		Name = "RouteVote",
		Size = UDim2.fromOffset(760, 190),
		Position = UDim2.new(0.5, 0, 1, -118),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local layout = Ui.list(
		Enum.FillDirection.Horizontal,
		14,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Bottom
	)
	layout.Parent = container

	-- The dossier ---------------------------------------------------------------------------------
	local backdrop = Ui.new("TextButton", {
		Name = "DossierBackdrop",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	})
	local dossier: Frame? = nil
	local openIndex: number? = nil
	local render: () -> ()

	local function closeDossier()
		if dossier then
			dossier:Destroy()
			dossier = nil
		end
		openIndex = nil
		backdrop.Visible = false
		ContextActionService:UnbindAction("LTO_CloseDossier")
	end
	backdrop.Activated:Connect(function()
		closeDossier()
		render()
	end)

	local function buildDossier(index: number, option: any, cost: number, short: boolean, train: any)
		local arch = Stations.List[option.archetype]
		-- the sheet, laid a little crooked, and its shadow on the table under it
		local holder = Ui.new("Frame", {
			Name = "Dossier",
			Size = UDim2.fromOffset(460, 420),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -1.2,
			BackgroundTransparency = 1,
			ZIndex = 41,
			Parent = gui,
		})
		local shadow = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(7, 9),
			BackgroundColor3 = Theme.Color.black,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = holder,
		})
		Ui.corner(2).Parent = shadow
		local paper = Ui.new("Frame", {
			Name = "Sheet",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.paper,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = holder,
		})
		Ui.corner(2).Parent = paper
		Ui.stroke(Theme.Color.paperShade, 1, 0).Parent = paper
		-- the age the sheet has gathered towards its foot
		local age = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.paperShade,
			BorderSizePixel = 0,
			Parent = paper,
		})
		Ui.corner(2).Parent = age
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.7, 0.85),
				NumberSequenceKeypoint.new(1, 0.45),
			}),
			Parent = age,
		})
		-- a brass paper clip over the top edge
		for i, inset in { 0, 4 } do
			local loop = Ui.new("Frame", {
				Size = UDim2.fromOffset(14 - inset * 2, 42 - inset * 3),
				Position = UDim2.fromOffset(236 + inset, -12 + inset),
				Rotation = -6,
				BackgroundTransparency = 1,
				ZIndex = 4 + i,
				Parent = paper,
			})
			Ui.corner(7).Parent = loop
			Ui.stroke(Theme.Color.brass, 2, 0).Parent = loop
		end

		local function label(
			text: string,
			x: number,
			y: number,
			w: number,
			props: { [string]: any }?
		): TextLabel
			local p: { [string]: any } = props or {}
			local l = Ui.text({
				Text = text,
				Font = p.Font or Theme.Font.type,
				TextSize = p.TextSize or 12,
				Color = p.Color or Theme.Color.inkSoft,
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w, p.Height or (p.TextSize or 12) + 4),
				XAlign = p.XAlign,
				Wrapped = p.Wrapped,
			})
			l.ZIndex = 3
			l.Parent = paper
			return l
		end
		local function rule(y: number, thick: number, x: number?, w: number?)
			Ui.new("Frame", {
				Size = UDim2.fromOffset(w or 404, thick),
				Position = UDim2.fromOffset(x or 28, y),
				BackgroundColor3 = Theme.Color.ink,
				BackgroundTransparency = if thick > 1 then 0 else 0.55,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = paper,
			})
		end

		-- heading
		label("STATION DOSSIER", 28, 22, 200)
		label(`LINE {string.char(64 + index)}`, 232, 22, 200, { XAlign = Enum.TextXAlignment.Right })
		local title = label(
			string.upper(arch.name),
			28,
			38,
			290,
			{ Font = HEAVY, TextSize = 26, Color = Theme.Color.ink }
		)
		title.TextScaled = true
		Ui.new("UITextSizeConstraint", { MaxTextSize = 26, Parent = title })
		rule(76, 2)
		rule(81, 1)
		-- the danger stamp, struck a little crooked
		local stamp = Ui.new("TextLabel", {
			Size = UDim2.fromOffset(118, 34),
			Position = UDim2.fromOffset(326, 36),
			Rotation = 7,
			BackgroundTransparency = 1,
			Text = if arch.terminus then "TERMINUS" else `DANGER {string.rep("I", option.tier)}`,
			FontFace = HEAVY,
			TextSize = 18,
			TextColor3 = Theme.Color.signal,
			TextTransparency = 0.12,
			ZIndex = 6,
			Parent = paper,
		})
		Ui.corner(3).Parent = stamp
		Ui.stroke(Theme.Color.signal, 2.5, 0.2).Parent = stamp

		-- left column: the leg
		local y = 94
		label("THE LEG", 28, y, 180, { Font = BOLD, TextSize = 12, Color = Theme.Color.ink })
		y += 20
		local bunker = if train then math.floor(train.coal) else nil
		local legRows = {
			{ "DISTANCE", `{option.distanceKm} KM` },
			{
				"COAL BURN",
				if bunker then `{cost} OF {bunker} IN THE BUNKER` else `{cost} COAL`,
			},
			{
				"TIME AT THE STOP",
				if arch.dwellMultiplier > 1.02
					then "LONGER THAN USUAL"
					elseif arch.dwellMultiplier < 0.98 then "SHORTER THAN USUAL"
					else "THE USUAL",
			},
			{ "LAID OUT AS", if arch.layout then words(arch.layout.style) else "SCATTERED" },
			{ "UNDERFOOT", words(arch.ground) },
		}
		for i, row in legRows do
			label(row[1], 28, y, 190, { TextSize = 11 })
			label(row[2], 28, y + 13, 190, {
				Font = Theme.Font.display,
				TextSize = 16,
				Color = if i == 2 and short then Theme.Color.signal else Theme.Color.ink,
			})
			y += 31
		end
		if arch.layout then
			label(
				LAYOUT_TEXT[arch.layout.style] or "",
				28,
				y - 2,
				190,
				{ TextSize = 10, Height = 26, Wrapped = true }
			)
		end

		-- right column: the haul and the dangers, five boxes each (three is ordinary)
		local function level(m: number): number
			return math.clamp(math.floor(m * 2.5 + 0.5), 1, 5)
		end
		local ry = 94
		local function meterRow(name: string, m: number, color: Color3)
			label(name, 244, ry, 90, { TextSize = 11 })
			local row = boxes(level(m), 5, color, 18, 8, 3, Theme.Color.paperShade, Theme.Color.inkSoft)
			row.Position = UDim2.fromOffset(342, ry + 4)
			row.Parent = paper
			ry += 18
		end
		label("THE HAUL", 244, ry, 180, { Font = BOLD, TextSize = 12, Color = Theme.Color.ink })
		ry += 20
		meterRow("COAL", arch.loot.coal, Theme.Color.ink)
		meterRow("PARTS", arch.loot.parts, Theme.Color.ink)
		meterRow("RELICS", arch.loot.relic, Theme.Color.ink)
		meterRow("TOOLS", arch.loot.tools, Theme.Color.ink)
		ry += 10
		label("THE DANGERS", 244, ry, 180, { Font = BOLD, TextSize = 12, Color = Theme.Color.signalDark })
		ry += 20
		meterRow("COLLAPSE", arch.hazard.collapse, Theme.Color.signal)
		meterRow("FOG", arch.hazard.fog, Theme.Color.signal)
		meterRow("HOLLOWS", arch.hazard.hollows, Theme.Color.signal)

		-- what stands in the yard
		rule(300, 1)
		local found = {}
		local kinds = {}
		for kind in arch.containers do
			table.insert(kinds, kind)
		end
		table.sort(kinds)
		for _, kind in kinds do
			local count = arch.containers[kind]
			table.insert(found, `{count} {plural(words(kind), count)}`)
		end
		if arch.looseItems > 0 then
			table.insert(found, `{arch.looseItems} LOOSE`)
		end
		label("ON THE GROUND", 28, 308, 200, { TextSize = 11 })
		label(table.concat(found, "  ·  "), 28, 322, 200, {
			Font = Theme.Font.display,
			TextSize = 13,
			Color = Theme.Color.ink,
			Height = 36,
			Wrapped = true,
		})
		local inside = {}
		local landmarks: { Stations.LandmarkRule } = arch.landmarks or {}
		for _, landmark in landmarks do
			table.insert(inside, words(landmark.kind))
		end
		label("TO SEARCH INSIDE", 244, 308, 190, { TextSize = 11 })
		label(if #inside > 0 then table.concat(inside, "  ·  ") else "NOTHING WITH A DOOR", 244, 322, 190, {
			Font = Theme.Font.display,
			TextSize = 13,
			Color = Theme.Color.ink,
			Height = 36,
			Wrapped = true,
		})

		-- the clerk's note in blue ink, and the foot of the sheet
		local note = label(`Clerk's note: {option.hint}.`, 28, 362, 290, { TextSize = 14, Color = BLUE_INK })
		note.Rotation = -1.5
		if short then
			label(
				"Not enough coal: the hull will suffer",
				28,
				380,
				290,
				{ TextSize = 11, Color = Theme.Color.signal }
			)
		end
		label("FILED AT THE JUNCTION  ·  LAST TRAIN OUT", 28, 398, 300, { TextSize = 9 })
		local close = Ui.button("CLOSE", "Primary", function()
			closeDossier()
			render()
		end, {
			Size = UDim2.fromOffset(92, 30),
			Position = UDim2.new(1, -28, 1, -16),
			AnchorPoint = Vector2.new(1, 1),
			TextSize = 14,
		})
		close.BackgroundColor3 = Theme.Color.ink
		close.TextColor3 = Theme.Color.white
		close.FontFace = HEAVY
		close.ZIndex = 3
		close.Parent = paper
		return holder
	end

	local function openDossier(index: number)
		openIndex = index
		backdrop.Visible = true
		ContextActionService:BindActionAtPriority("LTO_CloseDossier", function(_, inputState)
			if inputState == Enum.UserInputState.Begin and openIndex then
				closeDossier()
				render()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, 3000, Enum.KeyCode.ButtonB)
	end

	-- The tickets ---------------------------------------------------------------------------------
	function render()
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if dossier then
			dossier:Destroy()
			dossier = nil
		end
		local phase = Session.phase()
		local route = State.Get({ "run", "route" })
		local visible = phase == "Junction" and route ~= nil and Session.isAlive()
		container.Visible = visible
		if not visible then
			if openIndex then
				closeDossier()
			end
			return
		end
		local options = route.options or {}
		local votes = route.votes or {}
		local counts = Vote.counts(votes, #options)
		local mine = votes[Session.userKey]
		local train = State.Get({ "train" })

		for index, option in options do
			local arch = Stations.List[option.archetype]
			local selected = mine == index
			local cost = Ledger.legCoalCost(train or Ledger.newTrain(), option.distanceKm)
			local short = train ~= nil and cost > train.coal
			local card = Ui.new("Frame", {
				Name = "Option",
				Size = UDim2.fromOffset(206, if short then 178 else 150),
				LayoutOrder = index,
				BackgroundColor3 = CARD,
				BorderSizePixel = 0,
				Parent = container,
			})
			Ui.corner(4).Parent = card
			Ui.stroke(
				if selected then Theme.Color.brass else Theme.Color.white,
				if selected then 2 else 1,
				if selected then 0 else 0.84
			).Parent =
				card
			-- a tab of the danger's colour along the top edge
			Ui.new("Frame", {
				Name = "Tab",
				Size = UDim2.new(1, -28, 0, 3),
				Position = UDim2.fromOffset(14, 0),
				BackgroundColor3 = if arch.terminus
					then Theme.Color.brass
					else TIER_COLOR[option.tier] or Theme.Color.white,
				BorderSizePixel = 0,
				Parent = card,
			})
			local lineTag = Ui.text({
				Text = `LINE {string.char(64 + index)}`,
				Font = Theme.Font.display,
				TextSize = 11,
				Color = Theme.Color.textDim,
				Position = UDim2.fromOffset(14, 9),
				Size = UDim2.fromOffset(80, 14),
			})
			lineTag.Parent = card
			local name = Ui.text({
				Text = string.upper(arch.name),
				Font = HEAVY,
				TextSize = 17,
				Color = Theme.Color.white,
				Position = UDim2.fromOffset(14, 23),
				Size = UDim2.new(1, -28, 0, 20),
			})
			name.TextScaled = true
			Ui.new("UITextSizeConstraint", { MaxTextSize = 17, Parent = name })
			name.Parent = card

			local dangerLabel = Ui.text({
				Text = if arch.terminus then "THE END OF THE LINE" else `DANGER {option.tier}`,
				Font = BOLD,
				TextSize = 11,
				Color = Theme.Color.textDim,
				Position = UDim2.fromOffset(14, 49),
				Size = UDim2.fromOffset(140, 14),
			})
			dangerLabel.Parent = card
			if not arch.terminus then
				local row = boxes(option.tier, 3, TIER_COLOR[option.tier] or Theme.Color.white, 16, 8, 3)
				row.Position = UDim2.fromOffset(66, 52)
				row.Parent = card
			end

			-- the arrow that lays this station's dossier out
			local isOpen = openIndex == index
			local arrow = Ui.new("TextButton", {
				Name = "Dossier",
				Size = UDim2.fromOffset(26, 22),
				Position = UDim2.new(1, -14, 0, 46),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = if isOpen then Theme.Color.white else CARD,
				AutoButtonColor = false,
				Text = "",
				Selectable = true,
				Parent = card,
			})
			Ui.corner(3).Parent = arrow
			local arrowRim = Ui.stroke(Theme.Color.white, 1, 0.6)
			arrowRim.Parent = arrow
			local chevron = Ui.new("Frame", {
				Size = UDim2.fromOffset(12, 8),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = if isOpen then 180 else 0,
				BackgroundTransparency = 1,
				Parent = arrow,
			})
			for _, arm in { { 3.5, 45 }, { 8.5, -45 } } do
				Ui.new("Frame", {
					Size = UDim2.fromOffset(7, 2),
					Position = UDim2.fromOffset(arm[1], 4),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = arm[2],
					BackgroundColor3 = if isOpen then CARD else Theme.Color.white,
					BorderSizePixel = 0,
					Parent = chevron,
				})
			end
			arrow.MouseEnter:Connect(function()
				Ui.tween(arrowRim, { Transparency = 0 })
			end)
			arrow.MouseLeave:Connect(function()
				Ui.tween(arrowRim, { Transparency = 0.6 })
			end)
			arrow.Activated:Connect(function()
				if openIndex == index then
					closeDossier()
				else
					openDossier(index)
				end
				render()
			end)

			local legLine = Ui.text({
				Text = `{option.distanceKm} KM  ·  BURNS {cost} COAL`,
				Font = BOLD,
				TextSize = 12,
				Color = if short then Theme.Color.signal else Theme.Color.white,
				Position = UDim2.fromOffset(14, 70),
				Size = UDim2.new(1, -28, 0, 16),
			})
			legLine.Parent = card
			local hint = Ui.text({
				Text = routeHint(arch),
				Font = Theme.Font.type,
				TextSize = 10,
				Color = Theme.Color.textDim,
				Position = UDim2.fromOffset(14, 88),
				Size = UDim2.new(1, -28, 0, 24),
			})
			hint.TextWrapped = true
			hint.Parent = card
			if short then
				local warn = Ui.text({
					Text = "NOT ENOUGH COAL: THE HULL WILL SUFFER",
					Font = BOLD,
					TextSize = 9,
					Color = Theme.Color.signal,
					Position = UDim2.fromOffset(14, 132),
					Size = UDim2.new(1, -28, 0, 12),
				})
				warn.Parent = card
			end

			local button = Ui.button(
				if selected then "YOUR VOTE" elseif #options == 1 then "FINAL LEG" else "TAKE THIS LINE",
				if selected then "Primary" else "Paper",
				function()
					if #options > 1 then
						Net.Fire("CastVote", index)
					end
				end,
				{ Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 1, -38), TextSize = 13 }
			)
			button.FontFace = HEAVY
			if not selected then
				button.BackgroundColor3 = Theme.Color.white
			end
			button.Parent = card

			local tally = Ui.new("TextLabel", {
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.new(1, 8, 0, -8),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Theme.Color.signal,
				Text = tostring(counts[index] or 0),
				FontFace = HEAVY,
				TextSize = 13,
				TextColor3 = Theme.Color.white,
				Visible = #options > 1,
				Parent = card,
			})
			Ui.corner(3).Parent = tally
			Ui.stroke(CARD, 2, 0).Parent = tally

			if isOpen then
				dossier = buildDossier(index, option, cost, short, train)
			end
		end
		if openIndex and openIndex > #options then
			closeDossier()
		end
	end

	State.Observe("public", { "run", "route" }, render)
	State.Observe("public", { "run", "phase" }, render)
	State.Observe("public", { "crew", Session.userKey }, render)
	State.Observe("public", { "train", "coal" }, render)
end

return RouteVote
