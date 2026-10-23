--!strict
--[[
	Crew errands, written on the errand board in the crew saloon (Builders/TrainInterior's
	ErrandBoard, its clear ErrandFace): one entry per resident with an errand this run, from the
	private `quests` list (NpcService), read aboard on the wall opposite the route board. The train
	is rebuilt each run, so the board is found again whenever it goes.
	On a computer the errands are also on the right edge of the screen: always in the hall, and
	in a run for SHOW_SECONDS after an errand changes. A phone (gui Compact) has the board only.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local QuestTracker = {}

type Entry = { npc: string, name: string, title: string, text: string, status: string, helper: boolean }

local CANVAS = Vector2.new(540, 580) -- the face is 2.7 x 2.9 studs
local SHOW_SECONDS = 6

-- The computer's screen list (a phone has only the board).
local function screenList(gui: ScreenGui): ({ Entry }) -> ()
	local frame = Ui.panel({
		Name = "QuestTracker",
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -14, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 0.18,
		Visible = false,
		Parent = gui,
	})
	Ui.padding(10, 12).Parent = frame
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = frame
	local count, shownKey, changedAt = 0, "", -math.huge
	RunService.Heartbeat:Connect(function()
		local recent = os.clock() - changedAt < SHOW_SECONDS
		frame.Visible = gui:GetAttribute("Compact") ~= true
			and count > 0
			and (not Session.isMember() or recent)
	end)
	return function(list: { Entry })
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		count = #list
		local key = ""
		for _, entry in list do
			key ..= `{entry.npc}|{entry.title}|{entry.text}|{entry.status};`
		end
		if key ~= shownKey then
			shownKey = key
			changedAt = os.clock()
		end
		local header = Ui.text({
			Text = "CREW ERRANDS",
			Font = Theme.Font.displayMedium,
			TextSize = 13,
			Color = Theme.Color.brassLight,
			LayoutOrder = 0,
		})
		header.Parent = frame
		for i, entry in list do
			local done = entry.status == "Done"
			local title = Ui.text({
				Text = `{entry.title}{if entry.helper then "  (lending a hand)" else ""}`,
				Font = Theme.Font.bodyBold,
				TextSize = 16,
				Color = if entry.status == "Failed" then Theme.Color.textDim else Theme.Color.white,
				LayoutOrder = i * 2 - 1,
			})
			title.Parent = frame
			local line = Ui.text({
				Text = `{if done then "✓ " else ""}{entry.name}: {entry.text}`,
				TextSize = 14,
				Color = if done then Theme.Color.brassLight else Theme.Color.textDim,
				Wrapped = true,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = i * 2,
			})
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Parent = frame
		end
	end
end

function QuestTracker.mount(gui: ScreenGui)
	local State = Registry.StateController
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local surface = Ui.new("SurfaceGui", {
		Name = "ErrandBoard",
		ResetOnSpawn = false, -- boarding respawns you aboard; the board must survive it
		Face = Enum.NormalId.Front,
		CanvasSize = CANVAS,
		LightInfluence = 0.6,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		Parent = playerGui,
	})
	local page = Ui.new("Frame", {
		Name = "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.paper,
		BorderSizePixel = 0,
		Parent = surface,
	})
	Ui.padding(24, 26).Parent = page
	Ui.list(Enum.FillDirection.Vertical, 10).Parent = page

	local entries: { Entry } = {}
	local function render()
		for _, child in page:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local header = Ui.text({
			Text = "CREW ERRANDS",
			Font = Theme.Font.display,
			TextSize = 44,
			Color = Theme.Color.ink,
			LayoutOrder = 0,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 52),
		})
		header.Parent = page
		if #entries == 0 then
			local none = Ui.text({
				Text = "No errands this run.",
				Font = Theme.Font.body,
				TextSize = 30,
				Color = Theme.Color.inkSoft,
				LayoutOrder = 1,
				XAlign = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 40),
			})
			none.Parent = page
		end
		for i, entry in entries do
			local done = entry.status == "Done"
			local failed = entry.status == "Failed"
			local title = Ui.text({
				Text = `{if done then "✓ " else ""}{entry.title}{if entry.helper
					then "  (lending a hand)"
					else ""}`,
				Font = Theme.Font.bodyBold,
				TextSize = 38,
				Color = if failed then Theme.Color.inkSoft else Theme.Color.ink,
				LayoutOrder = i * 2 - 1,
				Size = UDim2.new(1, 0, 0, 46),
			})
			title.Parent = page
			local line = Ui.text({
				Text = `{entry.name}: {entry.text}`,
				TextSize = 32,
				Color = Theme.Color.inkSoft,
				Wrapped = true,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = i * 2,
			})
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Parent = page
		end
	end

	local renderScreen = screenList(gui)
	State.Observe("private", { "quests" }, function(list: { Entry }?)
		entries = list or {}
		render()
		renderScreen(entries)
	end)
	render()

	-- follow the board: the run's train is built anew, so look it up again when it is gone
	local nextLook = 0
	RunService.Heartbeat:Connect(function()
		local adornee = surface.Adornee
		if adornee and adornee.Parent then
			return
		end
		if os.clock() < nextLook then
			return
		end
		nextLook = os.clock() + 1
		local train = Workspace:FindFirstChild("Train")
		surface.Adornee = if train then train:FindFirstChild("ErrandFace", true) :: BasePart? else nil
	end)
end

return QuestTracker
