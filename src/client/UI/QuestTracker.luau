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
local Stamp = require(script.Parent.Stamp)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local QuestTracker = {}

type Entry = { npc: string, name: string, title: string, text: string, status: string, helper: boolean }

local CANVAS = Vector2.new(540, 580) -- the face is 2.7 x 2.9 studs
local SHOW_SECONDS = 6

-- The computer's screen list (a phone has only the board).
local function screenList(gui: ScreenGui): ({ Entry }) -> ()
	-- a slip of the same aged card as the board, its punched edge on the left
	local frame = Ui.ticket({
		Name = "QuestTracker",
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -14, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		Parent = gui,
	})
	-- the lines sit in their own frame, clear of the card's grain and punched edge
	local body = Ui.new("Frame", {
		Name = "Lines",
		Size = UDim2.new(1, -36, 0, 0),
		Position = UDim2.fromOffset(24, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Ui.padding(0, 0, 12, 0).Parent = body
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = body
	local count, shownKey, changedAt = 0, "", -math.huge
	RunService.Heartbeat:Connect(function()
		local recent = os.clock() - changedAt < SHOW_SECONDS
		frame.Visible = gui:GetAttribute("Compact") ~= true
			and count > 0
			and (not Session.isMember() or recent)
	end)
	return function(list: { Entry })
		for _, child in body:GetChildren() do
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
			Font = Theme.Font.display,
			TextSize = 15,
			Color = Theme.Color.ink,
			LayoutOrder = 0,
		})
		header.Parent = body
		for i, entry in list do
			local done = entry.status == "Done"
			local title = Ui.text({
				Text = `{entry.title}{if entry.helper then "  (lending a hand)" else ""}`,
				Font = Theme.Font.bodyBold,
				TextSize = 16,
				Color = if entry.status == "Failed" then Theme.Color.inkSoft else Theme.Color.ink,
				LayoutOrder = i * 2 - 1,
			})
			title.Parent = body
			local line = Ui.text({
				Text = `{if done then "✓ " else ""}{entry.text} — {entry.name}`,
				Font = Theme.Font.hand,
				TextSize = 15,
				Color = if done then Theme.Color.goInk else Theme.Color.inkSoft,
				Wrapped = true,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = i * 2,
			})
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Parent = body
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
	-- A posted company notice: aged card with burnt edges, four brass tacks, the company's
	-- printed head and double rule, each errand pencilled in by its resident, DONE stamped in red.
	local page = Ui.new("ImageLabel", {
		Name = "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.paper,
		BorderSizePixel = 0,
		Image = Theme.Image.card.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.card.slice,
		SliceScale = Theme.Slice.card,
		Parent = surface,
	})
	Ui.new("ImageLabel", {
		Name = "Grain",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.paperGrain,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(256, 256),
		ImageTransparency = 0.62,
		Parent = page,
	})
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		Ui.new("ImageLabel", {
			Name = "Tack",
			AnchorPoint = corner,
			Position = UDim2.new(
				corner.X,
				if corner.X > 0 then -12 else 12,
				corner.Y,
				if corner.Y > 0 then -12 else 12
			),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = Theme.Image.rivet,
			ZIndex = 3,
			Parent = page,
		})
	end
	Ui.text({
		Name = "Order",
		Text = "By order of the Company  ·  Depot Hall",
		Font = Theme.Font.type,
		TextSize = 17,
		Color = Theme.Color.inkSoft,
		XAlign = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 22),
	}).Parent =
		page
	local body = Ui.new("Frame", {
		Name = "Notice",
		Size = UDim2.new(1, -68, 1, -70),
		Position = UDim2.fromOffset(34, 22),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = page,
	})
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = body

	local entries: { Entry } = {}
	local function render()
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		Ui.new("ImageLabel", {
			Name = "Crest",
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Image = Theme.Image.crest,
			ImageColor3 = Theme.Color.inkSoft,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 0,
			Parent = body,
		})
		Ui.text({
			Text = "LAST TRAIN OUT RAILWAY  ·  NOTICE TO CREW",
			Font = Theme.Font.type,
			TextSize = 17,
			Color = Theme.Color.inkSoft,
			XAlign = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 20),
		}).Parent =
			body
		Ui.text({
			Text = "CREW ERRANDS",
			Font = Theme.Font.display,
			TextSize = 52,
			Color = Theme.Color.ink,
			XAlign = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 58),
		}).Parent =
			body
		-- the printer's double rule: heavy over hairline
		local rule = Ui.new("Frame", {
			Name = "Rule",
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = body,
		})
		for _, line in { { 1, 3 }, { 7, 1 } } do
			Ui.new("Frame", {
				Position = UDim2.fromOffset(0, line[1]),
				Size = UDim2.new(1, 0, 0, line[2]),
				BackgroundColor3 = Theme.Color.ink,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Parent = rule,
			})
		end
		if #entries == 0 then
			Ui.text({
				Text = "No errands this run.",
				Font = Theme.Font.hand,
				TextSize = 30,
				Color = Theme.Color.inkSoft,
				XAlign = Enum.TextXAlignment.Center,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 40),
			}).Parent =
				body
		end
		for i, entry in entries do
			local done = entry.status == "Done"
			local failed = entry.status == "Failed"
			local item = Ui.new("Frame", {
				Name = `Errand{i}`,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 3 + i,
				Parent = body,
			})
			Ui.text({
				Text = `No. {i}`,
				Font = Theme.Font.type,
				TextSize = 18,
				Color = Theme.Color.inkSoft,
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.fromOffset(56, 22),
			}).Parent =
				item
			local lines = Ui.new("Frame", {
				Size = UDim2.new(1, -60, 0, 0),
				Position = UDim2.fromOffset(60, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = item,
			})
			Ui.list(Enum.FillDirection.Vertical, 2).Parent = lines
			Ui.text({
				Text = `{entry.title}{if entry.helper then "  (lending a hand)" else ""}`,
				Font = Theme.Font.bodyBold,
				TextSize = 32,
				Color = if failed then Theme.Color.inkSoft else Theme.Color.ink,
				LayoutOrder = 1,
				Size = UDim2.new(1, if done then -110 else 0, 0, 42),
			}).Parent =
				lines
			local line = Ui.text({
				Text = `{entry.text}  — {entry.name}`,
				Font = Theme.Font.hand,
				TextSize = 28,
				Color = Theme.Color.inkSoft,
				Wrapped = true,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = 2,
			})
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Parent = lines
			if done then
				local mark = Stamp.word({
					key = `errand{entry.npc}{entry.title}`,
					text = "DONE",
					color = Theme.Color.oxblood,
					size = 22,
					Position = UDim2.new(1, -52, 0, 22),
					ZIndex = 4,
				})
				mark.Parent = item
			end
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
