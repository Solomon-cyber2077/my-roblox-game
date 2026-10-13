--!strict
--[[
	The end-of-run screen: one stamped run ticket (UI/RunTicket, data from Logic/RunTicketModel),
	shown once per run when it ends, win or wipe, even at stop 1. It replaced the old run card and
	the run receipt (UI/Summary, no longer shown). The ticket sits centred on a dim backdrop and
	closes with CLOSE, the backdrop or gamepad B; H hides CLOSE and its hint for a clean screenshot.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunTicketModel = require(ReplicatedStorage.Shared.Logic.RunTicketModel)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local RunTicket = require(script.Parent.RunTicket)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local RunCard = {}

local Z = 60
local PAD = 28

local root: TextButton
local closeButton: TextButton
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
		runId = State.Get({ "run", "runId" }),
		crew = State.Get({ "crew" }),
		me = Session.userKey,
	})
end

local function show()
	if ticket then
		ticket:Destroy()
	end
	local built, play = RunTicket.build(runData(), Z + 1, true)
	built.Position = UDim2.new(0.5, 0, 0.5, 20) -- centred in the visible area (the root reaches 60 above, 20 below)
	built.AnchorPoint = Vector2.new(0.5, 0.5)
	built.Active = true
	built.Parent = root
	ticket = built
	closeButton.Parent = built
	hint.Parent = built
	closeButton.Visible = true
	hint.Visible = true

	root.Visible = true
	GuiService.SelectedObject = closeButton
	ContextActionService:BindActionAtPriority("LTO_RunCard", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.H then
			closeButton.Visible = not closeButton.Visible
			hint.Visible = closeButton.Visible
		else
			hide()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3100, Enum.KeyCode.ButtonB, Enum.KeyCode.H)

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
	closeButton = Ui.button("CLOSE", "Secondary", hide, {
		Name = "Close",
		Size = UDim2.fromOffset(110, 38),
		Position = UDim2.new(0, PAD, 1, -RunTicket.FOOT + 8),
		TextSize = 17,
	})
	closeButton.ZIndex = Z + 12
	hint = Ui.text({
		Name = "Hint",
		Text = "H hides this button",
		Font = Theme.Font.body,
		TextSize = 12,
		Color = Theme.Color.inkSoft,
		Position = UDim2.new(0, PAD + 120, 1, -RunTicket.FOOT + 16),
		Size = UDim2.fromOffset(120, 22),
	})
	hint.ZIndex = Z + 12

	-- keep gamepad selection on CLOSE while the ticket is up
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local selected = GuiService.SelectedObject
		if root.Visible and closeButton.Visible and selected and not selected:IsDescendantOf(root) then
			GuiService.SelectedObject = closeButton
		end
	end)

	local State = Registry.StateController
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
