--!strict
--[[
	The crew chest in the stores car (Logic/CrewChest): E on the chest opens this. Left, the
	consumables in your backpack, each with STOW; right, what the crew has put in the chest,
	each with TAKE. The server does the moving (ChestStow, ChestTake); this redraws from the
	train's state and your backpack. Walking away from the chest closes it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local CrewChestLogic = require(Shared.Logic.CrewChest)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local ItemIcon = require(script.Parent.ItemIcon)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local CrewChest = {}

local modal: Modal.Modal
local ROW_H = 56

local function chestPart(): BasePart?
	local train = Workspace:FindFirstChild("Train")
	local part = train and train:FindFirstChild("CrewChest", true)
	return if part and part:IsA("BasePart") then part else nil
end

local function column(parent: Instance, title: string, left: boolean): ScrollingFrame
	local head = Ui.text({
		Text = title,
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromScale(if left then 0 else 0.52, 0),
		Size = UDim2.new(0.48, 0, 0, 26),
	})
	head.ZIndex = 33
	head.Parent = parent
	local list = Ui.new("ScrollingFrame", {
		Size = UDim2.new(0.48, 0, 1, -34),
		Position = UDim2.new(if left then 0 else 0.52, 0, 0, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
		Parent = parent,
	})
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = list
	return list
end

local function row(
	list: Instance,
	order: number,
	itemId: string,
	label: string,
	action: string,
	onClick: () -> ()
)
	local frame = Ui.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, -8, 0, ROW_H),
		BackgroundColor3 = Theme.Color.steelLight,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		ZIndex = 32,
		Parent = list,
	})
	Ui.corner(2).Parent = frame
	local icon = ItemIcon.new(itemId, UDim2.fromOffset(ROW_H - 10, ROW_H - 10))
	icon.Position = UDim2.fromOffset(5, 5)
	icon.ZIndex = 33
	icon.Parent = frame
	local name = Ui.text({
		Text = label,
		Font = Theme.Font.bodyBold,
		TextSize = 16,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(ROW_H + 4, 0),
		Size = UDim2.new(1, -(ROW_H + 120), 1, 0),
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 33
	name.Parent = frame
	local button = Ui.button(action, "Secondary", onClick, {
		Size = UDim2.fromOffset(100, 38),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = 18,
	})
	button.ZIndex = 34
	button.Parent = frame
end

local function empty(list: Instance, text: string)
	local note = Ui.text({
		Name = "Row",
		Text = text,
		Font = Theme.Font.body,
		TextSize = 15,
		Color = Theme.Color.textDim,
		Wrapped = true,
		Size = UDim2.new(1, -8, 0, 44),
	})
	note.ZIndex = 33
	note.Parent = list
end

function CrewChest.mount(gui: ScreenGui)
	local State = Registry.StateController
	modal = Modal.new(gui, "Crew Chest", Vector2.new(720, 460))
	local mine = column(modal.body, "YOUR BACKPACK", true)
	local shared = column(modal.body, "IN THE CHEST", false)

	local function render()
		for _, list in { mine, shared } do
			for _, child in list:GetChildren() do
				if child.Name == "Row" then
					child:Destroy()
				end
			end
		end
		local inv = State.GetPrivate({ "inventory" }) or { items = {} }
		local any = false
		for slot, itemId in inv.items or {} do
			if CrewChestLogic.storable(itemId) then
				any = true
				row(mine, slot, itemId, Items[itemId].name, "STOW", function()
					Net.Fire("ChestStow", slot)
				end)
			end
		end
		if not any then
			empty(mine, "Nothing to stow: flares, tonics and flashbulbs go in here.")
		end
		local train = State.Get({ "train" }) or {}
		local stored: { string } = train.chest or {}
		local counts, order = CrewChestLogic.counts(stored)
		for i, itemId in order do
			local def = Items[itemId]
			row(
				shared,
				i,
				itemId,
				`{if def then def.name else itemId}  ×{counts[itemId]}`,
				"TAKE",
				function()
					Net.Fire("ChestTake", itemId)
				end
			)
		end
		if #order == 0 then
			empty(shared, "The chest is empty.")
		end
	end

	modal.onOpen = render
	State.Observe("private", { "inventory" }, function()
		if modal:isOpen() then
			render()
		end
	end)
	State.Observe("public", { "train" }, function()
		if modal:isOpen() then
			render()
		end
	end)
	-- the chest is in the stores car: walk away (or step off) and it closes
	RunService.Heartbeat:Connect(function()
		if not modal:isOpen() then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local part = chestPart()
		if
			root == nil
			or part == nil
			or (root.Position - part.Position).Magnitude > Tuning.CrewChest.Reach + 2
		then
			modal:close()
		end
	end)
end

function CrewChest.open()
	modal:open()
end

return CrewChest
