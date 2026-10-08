--!strict
--[[
	Depot Hall UI: profile card, the ready toggle, join-in-progress, shortcuts to
	the Outfitter and the Ledger, the run tier picker (host only) and the in-world
	departure board.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Rank = require(Shared.Logic.Rank)
local RunRules = require(Shared.Logic.RunRules)
local Format = require(Shared.Util.Format)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local CarBoarding = require(script.Parent.CarBoarding)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Lobby = {}

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
			TextSize = props.TextSize or 13,
			Color = props.Color or Theme.Color.textDim,
			Position = props.Position,
			Size = props.Size,
			XAlign = props.XAlign,
		})
		l.Parent = props.Parent
		return l
	end

	-- Profile card: the operator's crew pass --------------------------------------------------
	local card = Ui.panel({
		Name = "Profile",
		Size = UDim2.fromOffset(300, 138),
		Position = UDim2.fromOffset(14, 12),
		BackgroundTransparency = 0.08,
		Parent = container,
	})
	local band = Ui.new("Frame", {
		Name = "Band",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		Parent = card,
	})
	Ui.corner(2).Parent = band
	caption("CREW PASS  ·  LAST TRAIN OUT", {
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(10, 1),
		Size = UDim2.new(1, -20, 1, 0),
		Parent = band,
	})
	caption(`No. {string.format("%05d", Session.player.UserId % 100000)}`, {
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(10, 1),
		Size = UDim2.new(1, -20, 1, 0),
		XAlign = Enum.TextXAlignment.Right,
		Parent = band,
	})
	local nameLabel = Ui.text({
		Text = Session.player.DisplayName,
		Font = Theme.Font.display,
		TextSize = 26,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 28),
	})
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card
	-- the rank number on a square badge, the XP to the next rank beside it
	local badge = Ui.new("TextLabel", {
		Name = "RankBadge",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(12, 60),
		BackgroundColor3 = Theme.Color.steelLight,
		BorderSizePixel = 0,
		FontFace = Theme.Font.display,
		TextSize = 20,
		TextColor3 = Theme.Color.brassLight,
		Text = "1",
		Parent = card,
	})
	Ui.corner(2).Parent = badge
	Ui.stroke(Theme.Color.brass, 1, 0).Parent = badge
	caption(
		"CREW RANK",
		{ Position = UDim2.fromOffset(50, 58), Size = UDim2.fromOffset(120, 16), Parent = card }
	)
	local rankLabel = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 15,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(50, 58),
		Size = UDim2.new(1, -62, 0, 16),
		XAlign = Enum.TextXAlignment.Right,
	})
	rankLabel.Parent = card
	-- progress as a row of ticket punches: lit holes are earned
	local HOLES = 20
	local holes = Ui.new("Frame", {
		Name = "Punches",
		Size = UDim2.new(1, -62, 0, 8),
		Position = UDim2.fromOffset(50, 80),
		BackgroundTransparency = 1,
		Parent = card,
	})
	Ui.list(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left).Parent = holes
	local holeFrames: { Frame } = {}
	for i = 1, HOLES do
		holeFrames[i] = Ui.new("Frame", {
			Size = UDim2.new(1 / HOLES, -3, 1, 0),
			BackgroundColor3 = Theme.Color.steelLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = holes,
		})
	end
	local function setXp(fraction: number)
		local lit = math.floor(math.clamp(fraction, 0, 1) * HOLES + 0.5)
		for i, hole in holeFrames do
			hole.BackgroundColor3 = if i <= lit then Theme.Color.brass else Theme.Color.steelLight
		end
	end
	Ui.new("Frame", {
		Name = "Rule",
		Size = UDim2.new(1, -24, 0, 1),
		Position = UDim2.fromOffset(12, 100),
		BackgroundColor3 = Theme.Color.steelLine,
		BorderSizePixel = 0,
		Parent = card,
	})
	local brassLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromOffset(12, 106),
		Size = UDim2.new(0.6, 0, 0, 24),
	})
	brassLabel.Parent = card
	local savingLabel = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 13,
		Color = Theme.Color.signal,
		Position = UDim2.new(0.4, 0, 0, 108),
		Size = UDim2.new(0.6, -12, 0, 20),
		XAlign = Enum.TextXAlignment.Right,
	})
	savingLabel.Parent = card

	-- Departure panel: the platform indicator --------------------------------------------------
	local panel = Ui.panel({
		Name = "Departure",
		Size = UDim2.fromOffset(440, 168),
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 0.06,
		Parent = container,
	})
	local headStrip = Ui.new("Frame", {
		Name = "Head",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Theme.Color.steelLight,
		BorderSizePixel = 0,
		Parent = panel,
	})
	Ui.corner(2).Parent = headStrip
	local platformPlate = Ui.new("TextLabel", {
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		FontFace = Theme.Font.sign,
		TextSize = 16,
		TextColor3 = Theme.Color.ink,
		Text = "1",
		Parent = headStrip,
	})
	Ui.corner(2).Parent = platformPlate
	caption("PLATFORM 1  ·  DEPOT HALL", {
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Parent = headStrip,
	})
	caption("ALL STOPS TO THE TERMINUS", {
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -44, 1, 0),
		XAlign = Enum.TextXAlignment.Right,
		Parent = headStrip,
	})
	local status = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 26,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 28),
		XAlign = Enum.TextXAlignment.Center,
	})
	status.Parent = panel
	local detail = Ui.text({
		Text = "",
		Font = Theme.Font.body,
		TextSize = 15,
		Color = Theme.Color.textDim,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 18),
		XAlign = Enum.TextXAlignment.Center,
	})
	detail.Parent = panel
	-- one signal lamp per crewmate the departure needs: lit when they are ready
	local lampRow = Ui.new("Frame", {
		Name = "Lamps",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 86),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Ui.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center).Parent = lampRow
	local lamps: { Frame } = {}
	for i = 1, 4 do
		local lamp = Ui.new("Frame", {
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Theme.Color.steelLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = lampRow,
		})
		Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = lamp })
		Ui.stroke(Theme.Color.steelLine, 1, 0).Parent = lamp
		lamps[i] = lamp
	end
	local function setLamps(ready: number, needed: number)
		for i, lamp in lamps do
			lamp.Visible = i <= math.max(needed, ready)
			lamp.BackgroundColor3 = if i <= ready then Theme.Color.go else Theme.Color.steelLight
		end
	end
	local readyButton = Ui.button("READY", "Primary", nil, {
		Size = UDim2.new(1, -32, 0, 46),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 22,
	})
	readyButton.Parent = panel
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

	-- Run tier: a tab on top of the panel; everyone sees it, only the host can change it -------
	local tierRow = Ui.panel({
		Name = "RunTier",
		Size = UDim2.fromOffset(300, 34),
		Position = UDim2.new(0.5, 0, 1, -194),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 0.06,
		Parent = container,
	})
	local tierLabel = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 15,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -80, 1, 0),
		XAlign = Enum.TextXAlignment.Center,
	})
	tierLabel.Parent = tierRow
	local function pickTier(step: number)
		local tier = State.Get({ "lobby", "tier" }) or {}
		local nextTier = math.clamp((tier.selected or 1) + step, 1, tier.max or 1)
		if nextTier ~= tier.selected then
			Net.Fire("SetRunTier", nextTier)
		end
	end
	local tierDown = Ui.button("◀", "Secondary", function()
		pickTier(-1)
	end, { Size = UDim2.fromOffset(34, 34), TextSize = 14 })
	tierDown.Parent = tierRow
	local tierUp = Ui.button("▶", "Secondary", function()
		pickTier(1)
	end, { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -34, 0, 0), TextSize = 14 })
	tierUp.Parent = tierRow

	-- Shortcuts: two plates under the pass -----------------------------------------------------
	local shortcuts = Ui.new("Frame", {
		Size = UDim2.fromOffset(300, 40),
		Position = UDim2.fromOffset(14, 158),
		BackgroundTransparency = 1,
		Parent = container,
	})
	Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = shortcuts
	Ui.button("OUTFITTER", "Secondary", function()
		Registry.UIController.Open("Outfitter")
	end, { Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1, TextSize = 17 }).Parent =
		shortcuts
	Ui.button("LINE MASTERY", "Secondary", function()
		Registry.UIController.Open("Ledger")
	end, { Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 2, TextSize = 17 }).Parent =
		shortcuts

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
			Font = Theme.Font.sign,
			TextSize = 64,
			Color = Theme.Color.brassLight,
			Position = UDim2.fromOffset(40, 24),
			Size = UDim2.new(1, -80, 0, 70),
		});
		(boardHead :: TextLabel).Parent = surface
		boardRows = Ui.text({
			Text = "",
			Font = Theme.Font.sign,
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
		brassLabel.Text = `{Format.thousands(profile.brass or 0)} BRASS`
		savingLabel.Text = if profile.saving == "Offline" then "NOT SAVING" else ""
	end
	State.Observe("private", { "profile" }, renderProfile)

	RunService.RenderStepped:Connect(function()
		local member = Session.isMember()
		container.Visible = not member
		-- aboard a boarding car you are ready already: its countdown (UI/CarBoarding) replaces this panel
		panel.Visible = CarBoarding.MyCar() == nil
		local phase = Session.phase()
		local run = State.Get({ "run" }) or {}
		local now = Session.now()
		local readyCount, needed = readyLine()
		local mine = State.Get({ "lobby", "ready", Session.userKey }) == true

		local tier = State.Get({ "lobby", "tier" }) or {}
		local selected, maxTier = tier.selected or 1, tier.max or 1
		local isHost = tier.host == Session.userKey
		tierRow.Visible = panel.Visible and not RunRules.isRunPhase(phase :: any) and phase ~= "RunEnd"
		tierLabel.Text = if isHost
			then `RUN TIER {selected}  ·  UP TO {maxTier}`
			else `RUN TIER {selected}  ·  HOST PICKS`
		tierDown.Visible = isHost
		tierUp.Visible = isHost
		Ui.setButtonEnabled(tierDown, selected > 1)
		Ui.setButtonEnabled(tierUp, selected < maxTier)

		local head, rows = "PLATFORM 1  ·  LAST TRAIN OUT", ""
		if RunRules.isRunPhase(phase :: any) or phase == "RunEnd" then
			local stop = math.min(run.nextStop or 1, Tuning.Run.StationCount)
			status.Text = `RUN UNDERWAY  ·  STOP {stop}/{Tuning.Run.StationCount}`
			local joinable = (run.nextStop or 1) <= Tuning.Run.JoinInProgressMaxStation and phase ~= "RunEnd"
			detail.Text = if joinable
				then "Jump in: you'll arrive at the next station and run for the train."
				else "Too far down the line. Next departure after this run."
			readyButton.Text = "JOIN AT NEXT STOP"
			Ui.setButtonEnabled(readyButton, joinable)
			setLamps(0, 0)
			rows = `EN ROUTE  ·  STOP {stop} OF {Tuning.Run.StationCount}\nNEXT DEPARTURE AFTER THIS RUN`
		elseif phase == "Countdown" then
			local remaining = math.max((run.phaseEndsAt or now) - now, 0)
			status.Text = `DEPARTING IN {Format.clock(remaining)}`
			detail.Text = `{readyCount} ready  ·  everyone in the hall boards`
			readyButton.Text = if mine then "READY ✓" else "READY"
			Ui.setButtonEnabled(readyButton, true)
			setLamps(readyCount, readyCount)
			rows = `BOARDING NOW  ·  DEPARTS {Format.clock(remaining)}\n{readyCount} CREW READY`
		else
			status.Text = "WAITING FOR CREW"
			detail.Text = `{readyCount}/{needed} ready to depart`
			readyButton.Text = if mine then "READY ✓" else "READY"
			Ui.setButtonEnabled(readyButton, true)
			setLamps(readyCount, needed)
			rows = `STATUS  ·  WAITING FOR CREW\n{readyCount} OF {needed} READY`
		end
		if boardHead and boardRows and boardGui then
			boardHead.Text = head
			boardRows.Text = rows
		end
	end)
end

return Lobby
