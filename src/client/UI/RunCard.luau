--!strict
--[[
	The end-of-run screen: one stamped run ticket (UI/RunTicket, data from Logic/RunTicketModel),
	shown once per run when it ends, win or wipe, even at stop 1. It replaced the old run card and
	the run receipt (UI/Summary, no longer shown). The ticket sits centred on a dim backdrop.

	AGAIN (gamepad A) readies this player for another run with the same crew (Logic/Again: pressed
	during RunEnd it waits for the hall, then the hall holds its countdown until the crew is ready
	or 20 s pass with one ready); the count beside it is the crew's ready count. DEPOT (gamepad B)
	leaves them unready in the hall and closes the card; the backdrop just closes it. H hides the
	buttons and the hint for a clean screenshot. Only the ended run's members see AGAIN.
	INVITE (UI/Invite) opens Roblox's invite prompt; hidden when this player may not invite.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunTicketModel = require(ReplicatedStorage.Shared.Logic.RunTicketModel)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Invite = require(script.Parent.Invite)
local RunTicket = require(script.Parent.RunTicket)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local RunCard = {}

local Z = 60
local PAD = 28

local root: TextButton
local closeButton: TextButton -- DEPOT
local againButton: TextButton
local countLabel: TextLabel
local inviteButton: TextButton
local inviteAllowed = false
local hint: TextLabel
local ticket: ImageLabel? = nil
local shownFor: string? = nil

local function hide()
	if root.Visible then
		root.Visible = false
		ContextActionService:UnbindAction("LTO_RunCard")
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
	end
end

-- This run, as the ticket's data table.
local function runData(): RunTicketModel.Data
	local State = Registry.StateController
	return RunTicketModel.build({
		outcome = State.Get({ "run", "outcome" }),
		log = State.Get({ "run", "log" }),
		nextStop = State.Get({ "run", "nextStop" }),
		stopCount = State.Get({ "run", "stopCount" }),
		runId = State.Get({ "run", "runId" }),
		crew = State.Get({ "crew" }),
		me = Session.userKey,
	})
end

-- The card's AGAIN state for this player (LobbyService publishes lobby.again).
local function againState(): (boolean, string?, number, number)
	local data = Registry.StateController.Get({ "lobby", "again" })
	if type(data) ~= "table" then
		return false, nil, 0, 0
	end
	local eligible = data.eligible and data.eligible[Session.userKey] == true
	local chose = data.chose and data.chose[Session.userKey]
	return eligible, chose, data.ready or 0, data.of or 0
end

local function refreshAgain()
	local eligible, chose, ready, of = againState()
	local shown = closeButton.Visible
	inviteButton.Visible = inviteAllowed and shown
	againButton.Visible = eligible and shown
	countLabel.Visible = eligible and shown and of > 0
	countLabel.Text = `{ready}/{of} READY`
	againButton.Text = if chose == "again" then "READY" else "AGAIN"
	againButton.Active = chose ~= "again"
	againButton.AutoButtonColor = chose ~= "again"
end

local function pressAgain()
	local eligible, chose = againState()
	if eligible and chose ~= "again" then
		Net.Fire("Again", true)
	end
end

local function depot()
	local eligible = againState()
	if eligible then
		Net.Fire("Again", false)
	end
	hide()
end

local function show()
	if ticket then
		-- the buttons and the hint live on the ticket; lift them off before it goes, or they go with it
		closeButton.Parent = root
		againButton.Parent = root
		countLabel.Parent = root
		inviteButton.Parent = root
		hint.Parent = root
		ticket:Destroy()
	end
	local built, play = RunTicket.build(runData(), Z + 1, true)
	Ui.phoneScale(built, root.Parent :: Instance, 0.78) -- the run ticket, smaller on a phone
	built.Position = UDim2.new(0.5, 0, 0.5, 20) -- centred in the visible area (the root reaches 60 above, 20 below)
	built.AnchorPoint = Vector2.new(0.5, 0.5)
	built.Active = true
	built.Parent = root
	ticket = built
	closeButton.Parent = built
	againButton.Parent = built
	countLabel.Parent = built
	inviteButton.Parent = built
	hint.Parent = built
	closeButton.Visible = true
	hint.Visible = true
	refreshAgain()

	root.Visible = true
	GuiService.SelectedObject = if againButton.Visible then againButton else closeButton
	ContextActionService:BindActionAtPriority("LTO_RunCard", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.H then
			closeButton.Visible = not closeButton.Visible
			hint.Visible = closeButton.Visible
			refreshAgain()
		elseif input.KeyCode == Enum.KeyCode.ButtonA then
			pressAgain()
		else
			depot()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3100, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.H)

	-- a beat to read the hero line, then the stamp comes down
	task.delay(0.6, function()
		if ticket == built then
			play()
			if Registry.AudioController then
				Registry.AudioController.Play("TicketPunch")
			end
		end
	end)
end

function RunCard.mount(gui: ScreenGui)
	root = Ui.new("TextButton", {
		Name = "RunCard",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = Z,
		Parent = gui,
	})
	root.Activated:Connect(hide)
	-- one large bottom row: AGAIN, the crew's ready count, DEPOT; the stamps sit above it
	againButton = Ui.button("AGAIN", "Primary", pressAgain, {
		Name = "Again",
		Size = UDim2.fromOffset(116, 42),
		Position = UDim2.new(0, PAD, 1, -RunTicket.FOOT + 6),
		TextSize = 18,
	})
	againButton.ZIndex = Z + 12
	againButton.Visible = false
	countLabel = Ui.text({
		Name = "ReadyCount",
		Text = "",
		Font = Theme.Font.body,
		TextSize = 15,
		Color = Theme.Color.ink,
		Position = UDim2.new(0, PAD + 124, 1, -RunTicket.FOOT + 16),
		Size = UDim2.fromOffset(70, 22),
	})
	countLabel.ZIndex = Z + 12
	countLabel.Visible = false
	closeButton = Ui.button("DEPOT", "Secondary", depot, {
		Name = "Close",
		Size = UDim2.fromOffset(100, 42),
		Position = UDim2.new(0, PAD + 198, 1, -RunTicket.FOOT + 6),
		TextSize = 17,
	})
	closeButton.ZIndex = Z + 12
	inviteButton = Ui.button("INVITE", "Secondary", function()
		Invite.prompt("runcard")
	end, {
		Name = "Invite",
		Size = UDim2.fromOffset(100, 42),
		Position = UDim2.new(0, PAD + 306, 1, -RunTicket.FOOT + 6),
		TextSize = 17,
	})
	inviteButton.ZIndex = Z + 12
	inviteButton.Visible = false
	Invite.whenChecked(function(allowed)
		inviteAllowed = allowed
		if root.Visible then
			refreshAgain()
		end
	end)
	hint = Ui.text({
		Name = "Hint",
		Text = "H hides these buttons",
		Font = Theme.Font.body,
		TextSize = 12,
		Color = Theme.Color.boneDim,
		-- under the ticket, on the backdrop: the foot's right is the stamp's
		Position = UDim2.new(0, 0, 1, 8),
		Size = UDim2.new(1, 0, 0, 22),
		XAlign = Enum.TextXAlignment.Center,
	})
	hint.ZIndex = Z + 12

	-- keep gamepad selection on AGAIN (or DEPOT) while the ticket is up
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local selected = GuiService.SelectedObject
		if root.Visible and closeButton.Visible and selected and not selected:IsDescendantOf(root) then
			GuiService.SelectedObject = if againButton.Visible then againButton else closeButton
		end
	end)

	local State = Registry.StateController
	State.Observe("public", { "lobby", "again" }, function()
		if root.Visible then
			refreshAgain()
		end
	end)
	State.Observe("public", { "run", "phase" }, function(phase)
		if phase == "RunEnd" then
			local runId = State.Get({ "run", "runId" })
			if shownFor ~= runId then
				shownFor = runId
				-- the last stop's entry lands in the same flush as the phase; let it settle
				task.delay(0.3, show)
			end
		elseif phase ~= "Lobby" then
			hide()
		end
	end)
end

-- Studio check: draw the ticket for whatever the run state holds now.
function RunCard.show()
	show()
end

return RunCard
