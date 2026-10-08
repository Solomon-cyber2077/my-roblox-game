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

function Workshop.mount(gui: ScreenGui)
	local State = Registry.StateController
	modal = Modal.new(gui, "Workshop", Vector2.new(560, 520))

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
				Size = UDim2.new(1, -8, 0, 70),
				BackgroundColor3 = Theme.Color.steelLight,
				BackgroundTransparency = 0.2,
				LayoutOrder = i,
				ZIndex = 32,
				Parent = list,
			})
			Ui.corner().Parent = row
			local name = Ui.text({
				Text = string.upper(def.name),
				Font = Theme.Font.display,
				TextSize = 19,
				Color = Theme.Color.white,
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -170, 0, 22),
			})
			name.ZIndex = 33
			name.Parent = row
			local desc = Ui.text({
				Text = def.description,
				TextSize = 14,
				Color = Theme.Color.textDim,
				Position = UDim2.fromOffset(14, 32),
				Size = UDim2.new(1, -170, 0, 32),
				Wrapped = true,
				YAlign = Enum.TextYAlignment.Top,
			})
			desc.ZIndex = 33
			desc.Parent = row
			for pip = 1, #def.costs do
				Ui.new("Frame", {
					Size = UDim2.fromOffset(14, 6),
					Position = UDim2.new(1, -150 + (pip - 1) * 18, 0, 14),
					BackgroundColor3 = if pip <= level then Theme.Color.brass else Theme.Color.steelLine,
					BorderSizePixel = 0,
					ZIndex = 33,
					Parent = row,
				})
			end
			local label = if cost then `FIT · {cost}` else "FITTED"
			local button = Ui.button(label, if cost then "Primary" else "Secondary", function()
				Net.Fire("BuyUpgrade", def.id)
			end, {
				Size = UDim2.fromOffset(120, 34),
				Position = UDim2.new(1, -12, 0.5, 6),
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 16,
			})
			button.ZIndex = 34
			button.Parent = row
			Ui.setButtonEnabled(button, cost ~= nil and train.parts >= cost)
		end

		local patch = Ui.new("Frame", {
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundColor3 = Theme.Color.signalDark,
			BackgroundTransparency = 0.3,
			LayoutOrder = 100,
			ZIndex = 32,
			Parent = list,
		})
		Ui.corner().Parent = patch
		local patchText = Ui.text({
			Text = `HULL PATCH  ·  +{Tuning.Train.HullPatchAmount} hull for {Tuning.Train.HullPatchCost} parts  ·  hull {math.floor(
				train.integrity
			)}%`,
			Font = Theme.Font.displayMedium,
			TextSize = 16,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -150, 1, 0),
		})
		patchText.ZIndex = 33
		patchText.Parent = patch
		local patchButton = Ui.button("PATCH", "Danger", function()
			Net.Fire("HullPatch")
		end, {
			Size = UDim2.fromOffset(110, 34),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 16,
		})
		patchButton.ZIndex = 34
		patchButton.Parent = patch
		Ui.setButtonEnabled(
			patchButton,
			train.parts >= Tuning.Train.HullPatchCost and train.integrity < train.integrityMax
		)
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
