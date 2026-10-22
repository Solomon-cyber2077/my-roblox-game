--!strict
--[[
	Depot Hall UI: profile card, the START toggle (ready), join-in-progress, shortcuts to
	the Outfitter and the Ledger, and the in-world departure board.
	First visit (Prompt 10): players spawn facing the board, which names the two plain choices:
	START (ride now, the hall's ready) or BOARD A CAR (walks you to a boarding car's door to ride
	with others). Above the panel: the line (Logic/Routes: SHORT or LONG, or fixed while a new Hand
	is in the hall), BOARD A CAR and INVITE (UI/Invite, hidden when inviting is not allowed).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Rank = require(Shared.Logic.Rank)
local RunRules = require(Shared.Logic.RunRules)
local Format = require(Shared.Util.Format)
local Routes = require(Shared.Logic.Routes)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local CarBoarding = require(script.Parent.CarBoarding)
local Invite = require(script.Parent.Invite)
local Menu = require(script.Parent.Menu)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Lobby = {}

local PANEL_W, PANEL_H = 360, 124 -- the departure panel

function Lobby.mount(gui: ScreenGui)
	local State = Registry.StateController

	local container = Ui.new("Frame", {
		Name = "Lobby",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	-- A small caps caption in the dim tone (headers, field names).
	local function caption(text: string, props: { [string]: any }): TextLabel
		local l = Ui.text({
			Text = text,
			Font = Theme.Font.displayMedium,
			TextSize = props.TextSize or 15,
			Color = props.Color or Theme.Color.boneDim,
			Position = props.Position,
			Size = props.Size,
			XAlign = props.XAlign,
		})
		l.Parent = props.Parent
		return l
	end

	-- A soft lamp halo (or a shadow, tinted black) laid behind or over a piece.
	local function halo(props: { [string]: any }): ImageLabel
		props.BackgroundTransparency = 1
		props.Image = Theme.Image.glow.id
		props.ScaleType = Enum.ScaleType.Slice
		props.SliceCenter = Theme.Image.glow.slice
		return Ui.new("ImageLabel", props) :: ImageLabel
	end
	-- An engraved brass plate: dark letters cut into it, the lamp catching their lower lip.
	-- Returns the plate, the cut letters and their highlight (set both texts together).
	local function engravedPlate(
		props: { [string]: any },
		textSize: number
	): (ImageLabel, TextLabel, TextLabel)
		props.BackgroundTransparency = 1
		props.Image = Theme.Image.plateEngraved.id
		props.ScaleType = Enum.ScaleType.Slice
		props.SliceCenter = Theme.Image.plateEngraved.slice
		props.SliceScale = props.SliceScale or 0.3
		local plate = Ui.new("ImageLabel", props) :: ImageLabel
		local function letters(offset: number, color: Color3, transparency: number): TextLabel
			local l = Ui.text({
				Font = Theme.Font.display,
				TextSize = textSize,
				Color = color,
				Transparency = transparency,
				XAlign = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, -40, 1, 0),
				Position = UDim2.fromOffset(20, offset),
			})
			l.Parent = plate
			return l
		end
		local light = letters(1, Theme.Color.brassLight, 0.3)
		return plate, letters(0, Theme.Color.inkDeep, 0), light
	end

	-- Profile card: the operator's crew pass --------------------------------------------------
	local card = Ui.panel({
		Name = "Profile",
		Size = UDim2.fromOffset(330, 164),
		Position = UDim2.fromOffset(14, 12),
		Parent = container,
	})
	-- tooled leather in a brass rim, warmest where the hall's lamps reach it (top left)
	card.Image = Theme.Image.cardLeather.id
	card.SliceCenter = Theme.Image.cardLeather.slice
	card.SliceScale = 0.4
	card.BackgroundTransparency = 1
	Ui.new("ImageLabel", {
		Name = "Falloff",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = Theme.Image.vignette,
		ImageColor3 = Theme.Color.black,
		ImageTransparency = 0.35,
		Parent = card,
	})
	halo({
		Name = "Lamp",
		Size = UDim2.fromOffset(300, 200),
		Position = UDim2.fromOffset(-80, -70),
		ImageColor3 = Theme.Color.amber,
		ImageTransparency = 0.84,
		Parent = card,
	})
	local band = engravedPlate({
		Name = "Band",
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 8),
	}, 14)
	band.Parent = card
	Ui.new("ImageLabel", {
		Name = "Crest",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(16, -2),
		Image = Theme.Image.crest,
		Parent = band,
	})
	caption("CREW PASS  ·  LAST TRAIN OUT", {
		Color = Theme.Color.inkDeep,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -72, 1, 0),
		Parent = band,
	})
	caption(`No. {string.format("%05d", Session.player.UserId % 100000)}`, {
		Color = Theme.Color.inkDeep,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -30, 1, 0),
		XAlign = Enum.TextXAlignment.Right,
		Parent = band,
	})
	local nameLabel = Ui.text({
		Text = Session.player.DisplayName,
		Font = Theme.Font.display,
		TextSize = 31,
		Color = Theme.Color.bone,
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -32, 0, 34),
	})
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card
	-- the rank number on a square badge, the XP to the next rank beside it
	local badge = Ui.new("TextLabel", {
		Name = "RankBadge",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(16, 80),
		BackgroundColor3 = Theme.Color.leather,
		BorderSizePixel = 0,
		FontFace = Theme.Font.display,
		TextSize = 23,
		TextColor3 = Theme.Color.brassLight,
		Text = "1",
		Parent = card,
	})
	Ui.corner(2).Parent = badge
	Ui.stroke(Theme.Color.brass, 1, 0).Parent = badge
	caption(
		"CREW RANK",
		{ Position = UDim2.fromOffset(62, 78), Size = UDim2.fromOffset(130, 19), Parent = card }
	)
	local rankLabel = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 17,
		Color = Theme.Color.bone,
		Position = UDim2.fromOffset(62, 78),
		Size = UDim2.new(1, -78, 0, 19),
		XAlign = Enum.TextXAlignment.Right,
	})
	rankLabel.Parent = card
	-- progress as a row of ticket punches: lit holes are earned
	local HOLES = 20
	local holes = Ui.new("Frame", {
		Name = "Punches",
		Size = UDim2.new(1, -78, 0, 10),
		Position = UDim2.fromOffset(62, 103),
		BackgroundTransparency = 1,
		Parent = card,
	})
	Ui.list(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left).Parent = holes
	local holeFrames: { Frame } = {}
	for i = 1, HOLES do
		holeFrames[i] = Ui.new("Frame", {
			Size = UDim2.new(1 / HOLES, -3, 1, 0),
			BackgroundColor3 = Theme.Color.inkDeep,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = holes,
		})
	end
	local function setXp(fraction: number)
		local lit = math.floor(math.clamp(fraction, 0, 1) * HOLES + 0.5)
		for i, hole in holeFrames do
			hole.BackgroundColor3 = if i <= lit then Theme.Color.brass else Theme.Color.inkDeep
		end
	end
	Ui.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -32, 0, 1),
		Position = UDim2.fromOffset(16, 124),
		BackgroundColor3 = Theme.Color.tarnish,
		BorderSizePixel = 0,
		Parent = card,
	})
	local brassLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 23,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromOffset(16, 130),
		Size = UDim2.new(0.6, 0, 0, 26),
	})
	brassLabel.Parent = card
	local savingLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 16,
		Color = Theme.Color.dangerText,
		Position = UDim2.new(0.4, 0, 0, 132),
		Size = UDim2.new(0.6, -16, 0, 22),
		XAlign = Enum.TextXAlignment.Right,
	})
	savingLabel.Parent = card

	-- On a phone the pass folds to one line (name, rank, Brass) so the hall is not a wall of boxes;
	-- a tap opens it, another folds it. Desktop keeps it open. MENU sits just under it (UI/Menu).
	local fullLayout: { [GuiObject]: { position: UDim2, size: UDim2, textSize: number? } } = {}
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") then
			fullLayout[child] = {
				position = child.Position,
				size = child.Size,
				textSize = if child:IsA("TextLabel") then child.TextSize else nil,
			}
		end
	end
	local KEEP: { [GuiObject]: boolean } = { [nameLabel] = true, [badge] = true, [brassLabel] = true }
	local folded = false
	local userOpened = false
	local function layoutCard()
		local compact = gui:GetAttribute("Compact") == true
		folded = compact and not userOpened
		card.Size = if folded then UDim2.fromOffset(250, 58) else UDim2.fromOffset(330, 164)
		for child, layout in fullLayout do
			child.Visible = not folded or KEEP[child] == true or child.Name == "Falloff"
			child.Position, child.Size = layout.position, layout.size
			if child:IsA("TextLabel") and layout.textSize then
				child.TextSize = layout.textSize
			end
		end
		if folded then
			badge.Position = UDim2.fromOffset(10, 11)
			nameLabel.Position, nameLabel.Size = UDim2.fromOffset(56, 6), UDim2.new(1, -64, 0, 24)
			nameLabel.TextSize = 21
			brassLabel.Position, brassLabel.Size = UDim2.fromOffset(56, 31), UDim2.new(1, -64, 0, 20)
			brassLabel.TextSize = 15
		end
		Menu.setLobbyY(if folded then 12 + 58 + 8 else 186)
	end
	local fold = Ui.new("TextButton", {
		Name = "Fold",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = card,
	})
	fold.Activated:Connect(function()
		userOpened = folded
		layoutCard()
	end)
	gui:GetAttributeChangedSignal("Compact"):Connect(layoutCard)
	layoutCard()

	-- Departure panel: the platform indicator --------------------------------------------------
	local panel = Ui.panel({
		Name = "Departure",
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 0.06,
		Parent = container,
	})
	local headStrip = Ui.new("Frame", {
		Name = "Head",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = Theme.Color.steelLight,
		BorderSizePixel = 0,
		Parent = panel,
	})
	Ui.corner(2).Parent = headStrip
	local platformPlate = Ui.new("TextLabel", {
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		FontFace = Theme.Font.display,
		TextSize = 14,
		TextColor3 = Theme.Color.ink,
		Text = "1",
		Parent = headStrip,
	})
	Ui.corner(2).Parent = platformPlate
	caption("PLATFORM 1  ·  DEPOT HALL", {
		Color = Theme.Color.white,
		TextSize = 13,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Parent = headStrip,
	})
	caption("TO THE TERMINUS", {
		TextSize = 13,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -36, 1, 0),
		XAlign = Enum.TextXAlignment.Right,
		Parent = headStrip,
	})
	local status = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 22),
		XAlign = Enum.TextXAlignment.Center,
	})
	status.Parent = panel
	local detail = Ui.text({
		Text = "",
		Font = Theme.Font.body,
		TextSize = 14,
		Color = Theme.Color.boneDim,
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 16),
		XAlign = Enum.TextXAlignment.Center,
	})
	detail.Parent = panel
	local readyButton = Ui.button("START", "Primary", nil, {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 20,
	})
	readyButton.ZIndex = 2
	readyButton.Parent = panel
	-- a flat brass plate: one tone, no lit gradient, rim or keel
	for _, child in readyButton:GetChildren() do
		if child:IsA("UIGradient") or child:IsA("UIStroke") then
			(child :: any).Enabled = false
		elseif child.Name == "Keel" then
			(child :: Frame).BackgroundTransparency = 1
		elseif child:IsA("UIPadding") then
			child.PaddingBottom = UDim.new(0, 0)
		end
	end
	-- raised: a shaded lip along the bottom and right edges; hover sinks it halfway, a press pushes it flush
	local READY_AT, LIP = readyButton.Position, 5
	local lipColor = Color3.fromRGB(138, 100, 44)
	local lipBottom = Ui.new("Frame", {
		Name = "LipBottom",
		BackgroundColor3 = lipColor,
		BorderSizePixel = 0,
		Parent = readyButton,
	})
	local lipRight = Ui.new("Frame", {
		Name = "LipRight",
		BackgroundColor3 = lipColor:Lerp(Color3.new(0, 0, 0), 0.25),
		BorderSizePixel = 0,
		Parent = readyButton,
	})
	local function raise(depth: number)
		readyButton.Position = READY_AT + UDim2.fromOffset(LIP - depth, LIP - depth)
		lipBottom.Position = UDim2.new(0, depth, 1, 0)
		lipBottom.Size = UDim2.new(1, 0, 0, depth)
		lipRight.Position = UDim2.new(1, 0, 0, depth)
		lipRight.Size = UDim2.new(0, depth, 1, 0)
		lipBottom.Visible, lipRight.Visible = depth > 0, depth > 0
	end
	READY_AT -= UDim2.fromOffset(LIP, LIP)
	raise(LIP)
	local readyHover = false
	readyButton.MouseEnter:Connect(function()
		readyHover = true
		raise(LIP // 2)
	end)
	readyButton.MouseLeave:Connect(function()
		readyHover = false
		raise(LIP)
	end)
	readyButton.MouseButton1Down:Connect(function()
		raise(0)
	end)
	readyButton.MouseButton1Up:Connect(function()
		raise(if readyHover then LIP // 2 else LIP)
	end)
	readyButton.Activated:Connect(function()
		if readyButton:GetAttribute("Disabled") then
			return
		end
		local phase = Session.phase()
		if RunRules.isRunPhase(phase :: any) then
			Net.Fire("JoinInProgress")
		else
			local mine = State.Get({ "lobby", "ready", Session.userKey }) == true
			Net.Fire("SetReady", not mine)
		end
	end)

	-- Above the panel: BOARD A CAR, INVITE and the line --------------------------------------------
	local hallRow = Ui.new("Frame", {
		Name = "HallRow",
		Size = UDim2.fromOffset(PANEL_W, 32),
		Position = UDim2.new(0.5, 0, 1, -20 - PANEL_H - 8),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = container,
	})
	-- walks this player to the door of the boarding car to join: one with riders first, then the nearest
	local function boardACar()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local doors = Workspace:FindFirstChild("CarDoors", true)
		if humanoid == nil or root == nil or doors == nil then
			return
		end
		local cars = State.Get({ "lobby", "cars" }) or {}
		local best: BasePart? = nil
		local bestScore = math.huge
		for _, door in doors:GetChildren() do
			if door:IsA("BasePart") and door.Name == "CarDoorOut" then
				local car = cars[door:GetAttribute("Car") :: number]
				local riders = if car then #car.occupants else 0
				if not (car and car.departing) and riders < Tuning.Cars.MaxPlayers then
					local score = (door.Position - root.Position).Magnitude - (if riders > 0 then 1000 else 0)
					if score < bestScore then
						best, bestScore = door, score
					end
				end
			end
		end
		local target = best
		if target == nil then
			return
		end
		-- MoveTo gives up after 8 s: ask again until close or three tries
		task.spawn(function()
			for _ = 1, 3 do
				humanoid:MoveTo(target.Position)
				local reached = humanoid.MoveToFinished:Wait()
				if reached or (root.Position - target.Position).Magnitude < 4 then
					return
				end
			end
		end)
	end
	local carButton = Ui.button("BOARD A CAR", "Secondary", boardACar, {
		Name = "BoardACar",
		Size = UDim2.new(0.5, -4, 0, 32),
		TextSize = 17,
	})
	carButton.TextColor3 = Theme.Color.bone
	carButton.Parent = hallRow
	-- the line: one button. With a new Hand aboard it only names the fixed line; otherwise a tap
	-- switches your vote between the Short and the Long Line (the crew's votes decide at boarding)
	local lineButton = Ui.button("", "Secondary", nil, {
		Name = "Line",
		Size = UDim2.new(0.5, -4, 0, 32),
		Position = UDim2.new(0.5, 4, 0, 0),
		TextSize = 15,
	})
	lineButton.TextColor3 = Theme.Color.bone
	lineButton.Parent = hallRow
	local lineFixed, myLine = false, "Long"
	lineButton.Activated:Connect(function()
		if not lineFixed then
			Net.Fire("VoteLine", if myLine == "Short" then "Long" else "Short")
		end
	end)

	local function renderLine()
		local line = State.Get({ "lobby", "line" })
		local known = type(line) == "table"
		lineFixed = known and line.fixed == true
		local route = if known then line.route else "Long"
		local mine = if known and line.votes then line.votes[Session.userKey] else nil
		if lineFixed then
			lineButton.Text = `{string.upper(route)} LINE · NEW HAND`
		else
			myLine = mine or route
			lineButton.Text = `{string.upper(myLine)} LINE · {Routes.length(myLine :: any)} STOPS`
		end
		Ui.setButtonEnabled(lineButton, not lineFixed)
	end
	State.Observe("public", { "lobby", "line" }, renderLine)
	renderLine()

	-- The hall's shortcuts live in the MENU dropdown (UI/Menu): Line Mastery while in the hall,
	-- INVITE when this player may invite
	Menu.add("LINE MASTERY", 20, function()
		Registry.UIController.Open("Ledger")
	end, function()
		return container.Visible
	end)
	local inviteAllowed = false
	Invite.whenChecked(function(allowed)
		inviteAllowed = allowed
	end)
	Menu.add("INVITE FRIENDS", 10, function()
		Invite.prompt("depot")
	end, function()
		return inviteAllowed
	end)

	-- In-world departure board ----------------------------------------------------------------
	local boardGui: SurfaceGui? = nil
	local boardRows: TextLabel? = nil
	local boardHead: TextLabel? = nil
	task.spawn(function()
		local hall = Workspace:WaitForChild("DepotHall", 30)
		local board = hall and hall:WaitForChild("DepartureBoard", 10)
		if board == nil then
			return
		end
		local surface = Ui.new("SurfaceGui", {
			Name = "DepartureBoard",
			Adornee = board,
			Face = Enum.NormalId.Front,
			CanvasSize = Vector2.new(1100, 400),
			LightInfluence = 0,
			Brightness = 1.6,
			Parent = gui.Parent,
		})
		boardHead = Ui.text({
			Text = "",
			Font = Theme.Font.display,
			TextSize = 64,
			Color = Theme.Color.brassLight,
			Position = UDim2.fromOffset(40, 24),
			Size = UDim2.new(1, -80, 0, 70),
		});
		(boardHead :: TextLabel).Parent = surface
		boardRows = Ui.text({
			Text = "",
			Font = Theme.Font.display,
			TextSize = 40,
			Color = Theme.Color.white,
			Position = UDim2.fromOffset(40, 110),
			Size = UDim2.new(1, -80, 1, -130),
			YAlign = Enum.TextYAlignment.Top,
			Wrapped = true,
		});
		(boardRows :: TextLabel).Parent = surface
		boardGui = surface
	end)

	local function readyLine(): (number, number)
		local ready = State.Get({ "lobby", "ready" }) or {}
		local readyCount = 0
		for _ in ready do
			readyCount += 1
		end
		local crew = State.Get({ "crew" }) or {}
		-- players aboard a boarding car leave with their car, not the hall's countdown
		local inCars: { [string]: boolean } = {}
		for _, car in State.Get({ "lobby", "cars" }) or {} do
			for _, key in car.occupants do
				inCars[key] = true
			end
		end
		local inLobby = 0
		for _, player in game:GetService("Players"):GetPlayers() do
			local key = tostring(player.UserId)
			if crew[key] == nil and not inCars[key] then
				inLobby += 1
			end
		end
		return readyCount, RunRules.requiredReady(math.max(inLobby, 1))
	end

	local function renderProfile(profile)
		if profile == nil then
			return
		end
		local rank, into, span = Rank.progress(profile.xp or 0)
		badge.Text = tostring(rank)
		rankLabel.Text = if span > 0 then `{into} / {span} XP` else "MAX RANK"
		setXp(if span > 0 then into / span else 1)
		-- the deepest stop ever reached (stats.bestStation; Prompt 8 styles it)
		local deepest = if profile.stats then profile.stats.bestStation or 0 else 0
		brassLabel.Text = `{Format.thousands(profile.brass or 0)} BRASS{if deepest > 0
			then `  ·  DEEPEST STOP {deepest}`
			else ""}`
		savingLabel.Text = if profile.saving == "Offline" then "NOT SAVING" else ""
	end
	State.Observe("private", { "profile" }, renderProfile)

	RunService.RenderStepped:Connect(function()
		local member = Session.isMember()
		-- the Settings menu's HUD toggle hides the lobby cards too (Settings.luau moves its button)
		container.Visible = not member and Players.LocalPlayer:GetAttribute("Hud") ~= "Hide"
		-- aboard a boarding car you are ready already: its countdown (UI/CarBoarding) replaces this panel
		panel.Visible = CarBoarding.MyCar() == nil
		local phase = Session.phase()
		local run = State.Get({ "run" }) or {}
		local now = Session.now()
		local readyCount, needed = readyLine()
		local mine = State.Get({ "lobby", "ready", Session.userKey }) == true

		local head, rows = "PLATFORM 1  ·  LAST TRAIN OUT", ""
		local stopCount = run.stopCount or Tuning.Run.StationCount
		hallRow.Visible = panel.Visible and (phase == "Lobby" or phase == "Countdown")
		if RunRules.isRunPhase(phase :: any) or phase == "RunEnd" then
			local stop = math.min(run.nextStop or 1, stopCount)
			status.Text = `RUN UNDERWAY  ·  STOP {stop}/{stopCount}`
			local joinable = (run.nextStop or 1) <= Tuning.Run.JoinInProgressMaxStation and phase ~= "RunEnd"
			detail.Text = if joinable
				then "Jump in: you'll arrive at the next station and run for the train."
				else "Too far down the line. Next departure after this run."
			readyButton.Text = "JOIN RUN"
			Ui.setButtonEnabled(readyButton, joinable)
			rows = `EN ROUTE  ·  STOP {stop} OF {stopCount}\nNEXT DEPARTURE AFTER THIS RUN`
		elseif phase == "Countdown" then
			local remaining = math.max((run.phaseEndsAt or now) - now, 0)
			status.Text = `DEPARTING IN {Format.clock(remaining)}`
			detail.Text = `{readyCount} ready to depart`
			readyButton.Text = if mine then "CANCEL" else "START"
			Ui.setButtonEnabled(readyButton, true)
			rows = `BOARDING NOW  ·  DEPARTS {Format.clock(remaining)}\n{readyCount} CREW READY`
		else
			status.Text = "WAITING FOR CREW"
			detail.Text = `{readyCount}/{needed} ready to depart`
			readyButton.Text = if mine then "CANCEL" else "START"
			Ui.setButtonEnabled(readyButton, true)
			-- the first-visit prompt: the board names the two ways to ride
			head = "START  ·  OR BOARD A CAR"
			rows = "START to ride now.\nBOARD A CAR to ride with others."
		end
		if boardHead and boardRows and boardGui then
			boardHead.Text = head
			boardRows.Text = rows
		end
	end)
end

return Lobby
