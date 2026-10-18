--!strict

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Items = require(ReplicatedStorage.Shared.Config.Items)

local HaulReceipt = {}
local modal: Modal.Modal
local generation = 0
local content: ScrollingFrame

local function clearBody()
	for _, child in modal.body:GetChildren() do
		child:Destroy()
	end
	content = Ui.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = modal.body,
	}) :: ScrollingFrame
	Ui.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content }
	)
end

local function line(text: string, color: Color3, size: number)
	local label = Ui.text({
		Text = text,
		Font = Theme.Font.type,
		TextSize = size,
		Color = color,
		Size = UDim2.new(1, -24, 0, size + 10),
		Position = UDim2.fromOffset(12, 0),
		Wrapped = true,
		Parent = content,
	})
	label.ZIndex = 35
	return label
end

function HaulReceipt.mount(gui: ScreenGui)
	modal = Modal.new(gui, "Terminus haul", Vector2.new(520, 500))
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and modal:isOpen() then
			modal:close()
		end
	end)
end

function HaulReceipt.show(data: { [string]: any })
	clearBody()
	generation += 1
	local thisGeneration = generation
	local haul = data.haul or {}
	local won = data.outcome == "Victory"
	if not won then
		line("STRONGBOX LOST", Theme.Color.signalDark, 26)
		local stamp = line("LOST", Theme.Color.signal, 42)
		stamp.TextTransparency = 1
		local stampScale = Ui.new("UIScale", { Scale = 2, Parent = stamp })
		local lost = haul.valuables or {}
		if #lost == 0 then
			line("No valuables recovered.", Theme.Color.inkSoft, 16)
		else
			line("Valuables lost:", Theme.Color.goInk, 18)
			for _, itemId in lost do
				local def = Items[itemId]
				line(if def then def.name else itemId, Theme.Color.ink, 16)
			end
		end
		modal:open()
		TweenService:Create(
			stamp,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		):Play()
		TweenService:Create(
			stampScale,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		return
	end

	line("TERMINUS LEDGER", Theme.Color.goInk, 26)
	line("The strongbox opens. Your earned haul is entered in the crew book.", Theme.Color.ink, 16)
	local counts: { [string]: number } = {}
	for _, itemId in haul.valuables or {} do
		counts[itemId] = (counts[itemId] or 0) + 1
	end
	local row = 0
	for itemId, count in counts do
		row += 1
		local def = Items[itemId]
		local name = if def then def.name else itemId
		local suffix = if count > 1 then `  ×{count}` else ""
		task.delay((row - 1) * 0.08, function()
			if generation == thisGeneration and modal:isOpen() then
				line(`VALUABLE  ·  {name}{suffix}`, Theme.Color.goInk, 16)
			end
		end)
	end
	for _, trophy in haul.trophies or {} do
		line(`TROPHY  ·  {trophy}`, Theme.Color.amber, 16)
	end
	if haul.xp then
		line(`CREW RANK PROGRESS  ·  {haul.xp} XP`, Theme.Color.goInk, 16)
	end
	if data.rankAfter then
		line(`CREW RANK  ·  {data.rankAfter}`, Theme.Color.goInk, 16)
	end
	modal:open()
end

return HaulReceipt
