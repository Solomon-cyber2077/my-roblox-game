--!strict
--[[
	The tutorial's prompts (Config/Tutorial Prompts, a rough draft the owner edits there): short
	contextual lines in the HUD's tutorial slot (UI/Hud), each shown once per run when its moment
	first comes, on runs of its tier (run.tutorial, the crew's tier from TutorialService).

	One at a time, queued in the data's order. The slot yields like the leak slot: it hides while
	a modal or full-screen UI is open, and a prompt's time does not run down while it is hidden.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Hud = require(script.Parent.Parent.UI.Hud)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)

local T = Difficulty.Tutorial

local TutorialController = {}

local panel: Frame? = nil
local label: TextLabel? = nil
local runId = ""
local seen: { [string]: boolean } = {}
local queue: { string } = {}
local showing: { id: string, left: number }? = nil
local restUntil = 0
local offSince: number? = nil -- os.clock() you stepped off the train at this stop
local lastStop = 0

local function keyName(): string
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad", 1, true) then
		return "A"
	elseif last == Enum.UserInputType.Touch then
		return "TAP"
	end
	return "SPACE"
end

local function textOf(id: string): string
	for _, prompt in T.Prompts do
		if prompt.id == id then
			local touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
			local text = if touch and prompt.touch then prompt.touch else prompt.text
			return (string.gsub(text, "{KEY}", keyName()))
		end
	end
	return ""
end

local function build(slot: Frame)
	local plate = Ui.panel({
		Name = "TutorialPrompt",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.12,
		Visible = false,
		Parent = slot,
	})
	Ui.padding(8, 10).Parent = plate
	Ui.stroke(Theme.Color.brass, 1, 0.25).Parent = plate
	local text = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 15,
		Color = Theme.Color.white,
		Size = UDim2.fromScale(1, 0),
	})
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.TextWrapped = true
	text.Parent = plate
	panel = plate :: any
	label = text
end

-- True while the slot (and the HUD around it) is on screen.
local function slotShown(): boolean
	local slot = Hud.tutorialSlot()
	local node: Instance? = slot
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return slot ~= nil
end

local function happening(when: string, run: any): boolean
	local phase = Session.phase()
	local status = Session.status()
	local off = status == "Afield" or status == "Straggler"
	if when == "RunStart" then
		return (phase == "Boarding" or phase == "Junction") and (run.nextStop or 1) == 1
	elseif when == "OffTrain" then
		return off
	elseif when == "AwayFromTrain" then
		return off and offSince ~= nil and os.clock() - offSince >= T.AwaySeconds
	elseif when == "NearEdge" then
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root == nil or not off then
			return false
		end
		for _, edge in CollectionService:GetTagged(T.EdgeTag) do
			-- on the ground plane: the rail is a tall wall (Tuning.VoidMist.WallHeight)
			local gap = edge:IsA("BasePart") and (edge.Position - root.Position) * Vector3.new(1, 0, 1)
			if gap and gap.Magnitude <= T.EdgeDistance then
				return true
			end
		end
		return false
	elseif when == "Grabbed" then
		local character = Players.LocalPlayer.Character
		return character ~= nil and character:GetAttribute("GrabStyle") ~= nil
	elseif when == "Cruise" then
		return phase == "Cruise"
	elseif when == "Leak" then
		local train = Registry.StateController.Get({ "train" })
		return train ~= nil and next(train.breaches or {}) ~= nil
	elseif when == "Exhausted" then
		return Registry.MovementController.IsExhausted()
	elseif when == "Junction" then
		return phase == "Junction"
	elseif when == "Carrying" then
		local inv = Registry.StateController.GetPrivate({ "inventory" })
		return inv ~= nil and inv.items ~= nil and #inv.items > 0
	elseif when == "Stalked" then
		-- a Hollow holding the Stalk freeze or slipping between cover within 1.2r (Logic/Tells)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local folder = Workspace:FindFirstChild("Hollows")
		if root == nil or folder == nil then
			return false
		end
		local range = Tuning.Stalk.WatchRadius * Tuning.Stalk.ReferenceRadius
		for _, hollow in folder:GetChildren() do
			local body = hollow:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				body
				and hollow:GetAttribute("State") == "Stalk"
				and (body.Position - root.Position).Magnitude <= range
			then
				return true
			end
		end
		return false
	elseif when == "BackAboard" then
		-- aboard again while the doors are open, having been off: the bell is the next thing
		return status == "Aboard" and phase == "Dwell" and offSince ~= nil
	end
	return false
end

local function step(dt: number)
	local run = Registry.StateController.Get({ "run" }) or {}
	local tier = run.tutorial or 0
	if not Session.isRunActive() or not Session.isMember() or tier < 1 then
		queue = {}
		showing = nil
		if panel then
			panel.Visible = false
		end
		return
	end
	-- once per prompt per run
	if run.runId ~= runId then
		runId = run.runId or ""
		seen = {}
		queue = {}
		showing = nil
	end
	local status = Session.status()
	local stop = run.nextStop or 1
	if stop ~= lastStop then
		lastStop = stop
		offSince = nil
	end
	if offSince == nil and (status == "Afield" or status == "Straggler") then
		offSince = os.clock()
	end
	for _, prompt in T.Prompts do
		if prompt.tier == tier and not seen[prompt.id] and happening(prompt.when, run) then
			seen[prompt.id] = true
			table.insert(queue, prompt.id)
		end
	end
	local shown = slotShown()
	local current = showing
	if current then
		if shown then
			current.left -= dt
		end
		if current.left <= 0 then
			showing = nil
			restUntil = os.clock() + T.PromptGap
		end
	elseif #queue > 0 and shown and os.clock() >= restUntil then
		local id = table.remove(queue, 1) :: string
		showing = { id = id, left = T.PromptSeconds }
		if label then
			label.Text = textOf(id)
		end
	end
	if panel then
		panel.Visible = showing ~= nil
	end
end

function TutorialController.Init() end

function TutorialController.Start()
	local slot = Hud.tutorialSlot()
	if slot == nil then
		warn("TutorialController: the HUD has no tutorial slot")
		return
	end
	build(slot)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			Safe.call("TutorialController.step", step, acc)
			acc = 0
		end
	end)
end

return TutorialController
