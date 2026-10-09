--!strict
-- The Workshop car's bench: spend parts on run upgrades or patch the hull.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Ledger = require(Shared.Logic.Ledger)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Workshop = {}

local modal: Modal.Modal

-- a plate the crew cannot afford yet: tarnished brass, plainly out of reach
local SPENT_BRASS = Color3.fromRGB(74, 58, 40)
local SPENT_TEXT = Color3.fromRGB(150, 128, 98)

local function setPlate(button: TextButton, enabled: boolean)
	Ui.setButtonEnabled(button, enabled)
	if not enabled then
		button.BackgroundColor3 = SPENT_BRASS
		button.TextColor3 = SPENT_TEXT
		local shade = button:FindFirstChild("Shade") :: Frame?
		if shade then
			shade.BackgroundTransparency = 1
		end
	end
end

function Workshop.mount(gui: ScreenGui)
	local State = Registry.StateController
	modal = Modal.new(gui, "Workshop", Vector2.new(560, 520))
	-- tooled leather in a brass rim, like the crew pass
	modal.frame.Image = Theme.Image.cardLeather.id
	modal.frame.SliceCenter = Theme.Image.cardLeather.slice
	modal.frame.SliceScale = 0.4
	modal.frame.BackgroundTransparency = 1
	Ui.new("ImageLabel", {
		Name = "Falloff",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = Theme.Image.vignette,
		ImageColor3 = Theme.Color.black,
		ImageTransparency = 0.35,
		ZIndex = 31,
		Parent = modal.frame,
	})

	local partsLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.brassLight,
		Position = UDim2.new(1, -130, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(180, 52),
		XAlign = Enum.TextXAlignment.Right,
	})
	partsLabel.ZIndex = 34
	partsLabel.Parent = modal.header

	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 32,
		Parent = modal.body,
	})
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = list

	local ordered = {}
	for _, def in UpgradesConfig.List do
		table.insert(ordered, def)
	end
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local train = State.Get({ "train" })
		if train == nil then
			return
		end
		partsLabel.Text = `{train.parts} PARTS`
		for i, def in ordered do
			local level = Ledger.level(train, def.id)
			local cost = Ledger.upgradeCost(train, def.id)
			local row = Ui.new("Frame", {
				Size = UDim2.new(1, -8, 0, 76),
				BackgroundColor3 = Theme.Color.leather, -- oxblood bench drawers, ruled in old brass
				BackgroundTransparency = 0.1,
				LayoutOrder = i,
				ZIndex = 32,
				Parent = list,
			})
			Ui.corner(2).Parent = row
			Ui.stroke(Theme.Color.tarnish, 1, 0.45).Parent = row
			local name = Ui.text({
				Text = string.upper(def.name),
				Font = Theme.Font.display,
				TextSize = 19,
				Color = Theme.Color.bone,
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -176, 0, 22),
			})
			name.ZIndex = 33
			name.Parent = row
			local desc = Ui.text({
				Text = def.description,
				TextSize = 14,
				Color = Theme.Color.boneDim,
				Position = UDim2.fromOffset(14, 32),
				Size = UDim2.new(1, -176, 0, 36),
				Wrapped = true,
				YAlign = Enum.TextYAlignment.Top,
			})
			desc.ZIndex = 33
			desc.Parent = row
			-- the fitting's level: a brass pip per level fitted, then what the next one needs
			local levels = #def.costs
			local levelLabel = Ui.text({
				Text = `LV {level}/{levels}`,
				Font = Theme.Font.displayMedium,
				TextSize = 13,
				Color = if level >= levels then Theme.Color.brassLight else Theme.Color.boneDim,
				Position = UDim2.new(1, -152, 0, 6),
				Size = UDim2.fromOffset(44, 16),
			})
			levelLabel.ZIndex = 33
			levelLabel.Parent = row
			for pip = 1, levels do
				local lit = pip <= level
				local box = Ui.new("Frame", {
					Size = UDim2.fromOffset(16, 8),
					Position = UDim2.new(1, -104 + (pip - 1) * 20, 0, 10),
					BackgroundColor3 = if lit then Theme.Color.brass else Theme.Color.inkDeep,
					BorderSizePixel = 0,
					ZIndex = 33,
					Parent = row,
				})
				Ui.stroke(if lit then Theme.Color.brassLight else Theme.Color.tarnish, 1, 0.2).Parent = box
			end
			local affordable = cost ~= nil and train.parts >= cost
			local label = if cost == nil
				then "FULLY FITTED"
				elseif affordable then `FIT · {cost} PARTS`
				else `NEED {cost - train.parts} MORE`
			local button = Ui.button(label, if cost then "Primary" else "Secondary", function()
				Net.Fire("BuyUpgrade", def.id)
			end, {
				Size = UDim2.fromOffset(140, 36),
				Position = UDim2.new(1, -12, 0.5, 8),
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 15,
			})
			button.ZIndex = 34
			button.Parent = row
			setPlate(button, affordable)
		end

		local patch = Ui.new("Frame", {
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundColor3 = Theme.Color.leather,
			BackgroundTransparency = 0.1,
			LayoutOrder = 100,
			ZIndex = 32,
			Parent = list,
		})
		Ui.corner(2).Parent = patch
		Ui.stroke(Theme.Color.signal, 1, 0.5).Parent = patch
		local patchText = Ui.text({
			Text = `HULL PATCH  ·  +{Tuning.Train.HullPatchAmount} hull for {Tuning.Train.HullPatchCost} parts  ·  hull {math.floor(
				train.integrity
			)}%`,
			Font = Theme.Font.displayMedium,
			TextSize = 16,
			Color = Theme.Color.bone,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -160, 1, 0),
			Wrapped = true,
		})
		patchText.ZIndex = 33
		patchText.Parent = patch
		local sound = train.integrity >= train.integrityMax
		local short = Tuning.Train.HullPatchCost - train.parts
		local patchLabel = if sound then "HULL SOUND" elseif short > 0 then `NEED {short} MORE` else "PATCH"
		local patchButton = Ui.button(patchLabel, "Danger", function()
			Net.Fire("HullPatch")
		end, {
			Size = UDim2.fromOffset(130, 36),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 16,
		})
		patchButton.ZIndex = 34
		patchButton.Parent = patch
		setPlate(patchButton, short <= 0 and not sound)
	end

	modal.onOpen = render
	State.Observe("public", { "train" }, function()
		if modal:isOpen() then
			render()
		end
	end)
	State.Observe("public", { "crew", Session.userKey }, function(entry)
		if modal:isOpen() and (entry == nil or entry.status ~= "Aboard") then
			modal:close()
		end
	end)
end

function Workshop.open()
	if Session.status() == "Aboard" then
		modal:open()
	end
end

return Workshop
