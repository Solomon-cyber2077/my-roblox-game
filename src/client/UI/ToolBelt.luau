--!strict
--[[
	The phone hotbar (docs/direction/2026-10-30-phone-hotbar-and-downtime.md; places in Logic/TouchCluster, checked by
	`lune run layout`). On a phone the HUD's backpack row only shows what you carry (UI/Hud); its taps move here, at
	thumb size (TouchCluster.Size, ~9.4 mm on an iPhone SE):

	  tool belt   your first two tools, left of PING on RUN's row: tap to hold, tap the held one to use it (the
	              flare, the flashbulb, the tonic, mid-chase), as the row did on PC
	  bag         the bag button, left of the action button: opens the bag sheet
	  bag sheet   every item at full size; pick one, then HOLD/USE, MOVE LEFT (it is kept first when an arm is
	              lost) or DROP; a tap outside closes it

	Everything is placed in screen units against our UIScale, like UI/ActionButton. PC, tablet and gamepad keep the
	row as it was. The plates are the rendered brass lever plate (Theme.Image.actionPlate); the bag button's icon is
	the rendered conductor's satchel (Theme.Image.bagIcon) once uploaded, its name until then.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local TouchCluster = require(Shared.Logic.TouchCluster)

local Hud = require(script.Parent.Hud)
local ItemIcon = require(script.Parent.ItemIcon)
local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local TouchButtons = require(script.Parent.TouchButtons)
local Ui = require(script.Parent.Ui)

local ToolBelt = {}

type Rect = TouchCluster.Rect

function ToolBelt.mount(gui: ScreenGui)
	local State = Registry.StateController
	local uiScale = gui:FindFirstChildOfClass("UIScale")
	local plate = Theme.Image.actionPlate

	local function scale(): number
		return if uiScale and uiScale.Scale > 0 then uiScale.Scale else 1
	end
	-- a screen rectangle (AbsolutePosition space) as a canvas position and size in our gui
	local function place(obj: GuiObject, r: Rect)
		local s, o = scale(), gui.AbsolutePosition
		obj.AnchorPoint = Vector2.zero
		obj.Position = UDim2.fromOffset((r.x - o.X) / s, (r.y - o.Y) / s)
		obj.Size = UDim2.fromOffset(r.w / s, r.h / s)
	end
	-- a thumb-sized brass button: the lever plate when uploaded, the enamel button until then
	local function key(name: string): GuiButton
		local b: GuiButton
		if plate.up ~= "" then
			b = Ui.new("ImageButton", {
				Name = name,
				Image = plate.up,
				PressedImage = plate.down,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = plate.slice,
				SliceScale = plate.scale,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Visible = false,
				Parent = gui,
			})
		else
			b = Ui.button("", "Secondary")
			b.Name = name
			b.Visible = false
			b.Parent = gui
		end
		b.Selectable = false
		return b
	end
	local function iconIn(button: GuiObject, itemId: string?)
		for _, child in button:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		if itemId then
			local icon = ItemIcon.new(itemId, UDim2.fromScale(0.8, 0.8))
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.Parent = button
		end
	end

	local function phone(): boolean
		return gui:GetAttribute("Compact") == true and UserInputService.TouchEnabled
	end
	local function inventory(): { items: { string }, capacity: number, revision: number? }
		return State.GetPrivate({ "inventory" }) or { items = {}, capacity = 6 }
	end

	-- the belt ---------------------------------------------------------------------------------
	local belt = { key("BeltTool1"), key("BeltTool2") }
	local beltSlot: { number? } = { nil, nil }
	for i, b in belt do
		b.Activated:Connect(function()
			local slot = beltSlot[i]
			if slot == nil then
				return
			end
			if Hud.handSlot and Hud.handSlot() == slot then
				Net.Fire("UseItem", slot)
			elseif Hud.hold then
				Hud.hold(slot)
			end
		end)
	end

	-- the bag button and its sheet ------------------------------------------------------------
	local bag = key("Bag")
	local bagIcon = Ui.new("ImageLabel", {
		Name = "Satchel",
		Image = Theme.Image.bagIcon,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.78, 0.78),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = Theme.Image.bagIcon ~= "",
		Parent = bag,
	})
	if not bagIcon.Visible then
		local word = Ui.text({
			Text = "BAG",
			Font = Theme.Font.display,
			TextSize = 18,
			Color = Theme.Color.brassLight,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		word.Parent = bag
	end

	local backdrop = Ui.new("TextButton", {
		Name = "BagBackdrop",
		Text = "",
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.6,
		AutoButtonColor = false,
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(-1, -1),
		Visible = false,
		Parent = gui,
	})
	local sheet = Ui.panel({ Name = "BagSheet", Visible = false, Parent = gui })
	local selected: number? = nil
	local cells: { GuiButton } = {}
	local actions: { TextButton } = {}
	local open = false

	local function close()
		open, selected = false, nil
		sheet.Visible, backdrop.Visible = false, false
	end
	backdrop.Activated:Connect(close)

	local render: () -> ()
	local function act(i: number)
		local inv = inventory()
		local slot = selected
		if slot == nil or inv.items[slot] == nil then
			return
		end
		local def = Items[inv.items[slot]]
		if i == 1 and def and def.kind == "Tool" then
			if Hud.handSlot and Hud.handSlot() == slot then
				Net.Fire("UseItem", slot)
			elseif Hud.hold then
				Hud.hold(slot)
			end
			close()
		elseif i == 2 and slot > 1 then
			local order = table.create(#inv.items, 0)
			for k = 1, #inv.items do
				order[k] = k
			end
			order[slot - 1], order[slot] = slot, slot - 1
			Net.Fire("ReorderItems", order, inv.revision or 0)
			selected = slot - 1
		elseif i == 3 then
			Net.Fire("DropItem", slot)
			selected = nil
		end
		render()
	end
	for i, label in { "HOLD", "MOVE LEFT", "DROP" } do
		local b = Ui.button(label, if i == 3 then "Danger" else "Primary", function()
			act(i)
		end)
		b.Name = label
		b.TextScaled = true
		Ui.new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10, Parent = b })
		b.Parent = sheet
		actions[i] = b
	end
	bag.Activated:Connect(function()
		if open then
			close()
		else
			open = true
			render()
		end
	end)

	render = function()
		local show = phone() and Session.isMember()
		local inv = inventory()
		local cluster = TouchButtons.layout()
		-- belt: the first two tools in carrying order
		local tools: { number } = {}
		for slot, itemId in inv.items do
			local def = Items[itemId]
			if def and def.kind == "Tool" and #tools < 2 then
				table.insert(tools, slot)
			end
		end
		local hand = if Hud.handSlot then Hud.handSlot() else nil
		for i, b in belt do
			local slot = tools[i]
			beltSlot[i] = slot
			b.Visible = show and slot ~= nil and not open
			if b.Visible then
				place(b, cluster.belt[i])
				iconIn(b, inv.items[slot :: number])
				b:SetAttribute("InHand", hand == slot)
				local stroke = b:FindFirstChildOfClass("UIStroke") or Ui.stroke(Theme.Color.brassLight, 3, 0)
				stroke.Parent = b
				stroke.Enabled = hand == slot
			end
		end
		bag.Visible = show and #inv.items > 0
		if bag.Visible then
			place(bag, cluster.bag)
		end
		if not show then
			close()
			return
		end
		sheet.Visible, backdrop.Visible = open, open
		if not open then
			return
		end
		local area = {
			x = gui.AbsolutePosition.X,
			y = gui.AbsolutePosition.Y,
			w = gui.AbsoluteSize.X,
			h = gui.AbsoluteSize.Y,
		}
		local layout = TouchCluster.sheet(cluster, area, math.max(#inv.items, 1))
		place(sheet, layout.frame)
		for _, c in cells do
			c:Destroy()
		end
		table.clear(cells)
		local s = scale()
		for slot, itemId in inv.items do
			local r = layout.cells[slot]
			local c = Ui.new("TextButton", {
				Name = "Item",
				Text = "",
				BackgroundColor3 = Theme.Color.steel,
				BackgroundTransparency = 0.2,
				AutoButtonColor = true,
				Position = UDim2.fromOffset((r.x - layout.frame.x) / s, (r.y - layout.frame.y) / s),
				Size = UDim2.fromOffset(r.w / s, r.h / s),
				Parent = sheet,
			})
			Ui.corner(3).Parent = c
			Ui.stroke(
				if slot == selected then Theme.Color.brassLight else Theme.Color.steelLine,
				if slot == selected then 3 else 1,
				0.1
			).Parent =
				c
			iconIn(c, itemId)
			c.Activated:Connect(function()
				selected = slot
				render()
			end)
			table.insert(cells, c)
		end
		local def = if selected then Items[inv.items[selected :: number]] else nil
		for i, b in actions do
			local r = layout.actions[i]
			b.Position = UDim2.fromOffset((r.x - layout.frame.x) / s, (r.y - layout.frame.y) / s)
			b.Size = UDim2.fromOffset(r.w / s, r.h / s)
			b.Visible = selected ~= nil
		end
		actions[1].Text = if def and def.kind == "Tool" and hand == selected then "USE" else "HOLD"
		actions[1].Visible = def ~= nil and def.kind == "Tool"
		actions[2].Visible = selected ~= nil and (selected :: number) > 1
	end

	State.Observe("private", { "inventory" }, render)
	State.Observe("public", { "run", "phase" }, render)
	gui:GetAttributeChangedSignal("Compact"):Connect(render)
	task.spawn(function()
		-- the hand changes inside Hud (keys, taps): follow it without a signal of its own
		while true do
			task.wait(0.25)
			if phone() then
				render()
			end
		end
	end)
	render()
end

return ToolBelt
