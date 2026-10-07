--!strict
--[[
	Depot Hall UI: profile card, the ready toggle, join-in-progress, shortcuts to
	the Outfitter and the Ledger, and the in-world departure board.
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

	-- Bold text straight over the hall: a dark outline thickens it and keeps it readable.
	local function outlined(label: TextLabel): TextLabel
		Ui.new("UIStroke", {
			Color = Theme.Color.black,
			Thickness = 1.5,
			Transparency = 0.2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
		return label
	end

	-- Profile card ---------------------------------------------------------------------------
	local card = Ui.new("Frame", {
		Name = "Profile",
		Size = UDim2.fromOffset(300, 124),
		Position = UDim2.fromOffset(14, 12),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local nameLabel = Ui.text({
		Text = `OPERATOR: {Session.player.DisplayName}`,
		Font = Theme.Font.display,
		TextSize = 24,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(4, 8),
		Size = UDim2.new(1, -40, 0, 26),
	})
	outlined(nameLabel).Parent = card
	local rankLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(4, 36),
		Size = UDim2.new(1, -40, 0, 22),
	})
	outlined(rankLabel).Parent = card
	local xpFrame, setXp = Ui.meter({
		Size = UDim2.new(1, -44, 0, 6),
		Position = UDim2.fromOffset(4, 62),
		FillColor = Theme.Color.brass,
	})
	xpFrame.BackgroundColor3 = Theme.Color.paperShade
	xpFrame.BackgroundTransparency = 0
	xpFrame.Parent = card
	local brassLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 22,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromOffset(4, 76),
		Size = UDim2.new(0.6, 0, 0, 24),
	})
	outlined(brassLabel).Parent = card
	local savingLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 17,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(4, 102),
		Size = UDim2.fromOffset(180, 20),
	})
	outlined(savingLabel).Parent = card

	-- Departure panel -------------------------------------------------------------------------
	local panel = Ui.new("Frame", {
		Name = "Departure",
		Size = UDim2.fromOffset(420, 120),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local status = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 24,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 24),
		XAlign = Enum.TextXAlignment.Center,
	})
	outlined(status).Parent = panel
	local detail = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 16,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 18),
		XAlign = Enum.TextXAlignment.Center,
	})
	outlined(detail).Parent = panel
	local readyButton = Ui.button("READY", "Primary", nil, {
		Size = UDim2.fromOffset(220, 44),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 22,
	})
	readyButton.Parent = panel
	readyButton.Activated:Connect(function()
		local phase = Session.phase()
		if RunRules.isRunPhase(phase :: any) then
			Net.Fire("JoinInProgress")
		else
			local mine = State.Get({ "lobby", "ready", Session.userKey }) == true
			Net.Fire("SetReady", not mine)
		end
	end)

	-- Shortcuts -------------------------------------------------------------------------------
	local shortcuts = Ui.new("Frame", {
		Size = UDim2.fromOffset(180, 88),
		Position = UDim2.fromOffset(14, 140),
		BackgroundTransparency = 1,
		Parent = container,
	})
	Ui.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left).Parent = shortcuts
	Ui.button("OUTFITTER", "Secondary", function()
		Registry.UIController.Open("Outfitter")
	end, { Size = UDim2.fromOffset(180, 40), LayoutOrder = 1 }).Parent =
		shortcuts
	Ui.button("LINE MASTERY", "Secondary", function()
		Registry.UIController.Open("Ledger")
	end, { Size = UDim2.fromOffset(180, 40), LayoutOrder = 2 }).Parent =
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
			Color = Theme.Color.paper,
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
		rankLabel.Text = if span > 0
			then `CREW RANK {rank}  ·  {into}/{span} XP`
			else `CREW RANK {rank}  ·  MAX`
		setXp(if span > 0 then into / span else 1)
		brassLabel.Text = `{Format.thousands(profile.brass or 0)} BRASS`
		savingLabel.Text = if profile.saving == "Offline" then "PROGRESS NOT SAVED" else ""
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
			rows = `EN ROUTE  ·  STOP {stop} OF {Tuning.Run.StationCount}\nNEXT DEPARTURE AFTER THIS RUN`
		elseif phase == "Countdown" then
			local remaining = math.max((run.phaseEndsAt or now) - now, 0)
			status.Text = `DEPARTING IN {Format.clock(remaining)}`
			detail.Text = `{readyCount} ready  ·  everyone in the hall boards`
			readyButton.Text = if mine then "READY ✓" else "READY"
			Ui.setButtonEnabled(readyButton, true)
			rows = `BOARDING NOW  ·  DEPARTS {Format.clock(remaining)}\n{readyCount} CREW READY`
		else
			status.Text = "WAITING FOR CREW"
			detail.Text = `{readyCount}/{needed} ready to depart`
			readyButton.Text = if mine then "READY ✓" else "READY"
			Ui.setButtonEnabled(readyButton, true)
			rows = `STATUS  ·  WAITING FOR CREW\n{readyCount} OF {needed} READY`
		end
		if boardHead and boardRows and boardGui then
			boardHead.Text = head
			boardRows.Text = rows
		end
	end)
end

return Lobby
