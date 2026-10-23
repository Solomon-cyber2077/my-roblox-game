--!strict
--[[
	One MENU button, top left, that drops a short list: the screen keeps one small box instead of
	a stack of them (phones first: most players are young and on a phone, and the first thing they
	see should not be clutter). Other UI adds its entries with Menu.add; an entry with `shown`
	appears only while that says so. The box is split: MENU, and beside it a friends mark (two
	figures, one behind the other) that opens the invite prompt, shown only while inviting is
	allowed (Menu.invite).
	The list closes on a pick, on the button again, or when the place it belongs to changes.

	Where it sits: under the hall's crew pass in the lobby (Lobby sets the slot through
	Menu.setLobbyY, since the pass folds up on a phone), under the gauges in a run, top left with
	the HUD hidden.
]]

local Players = game:GetService("Players")

local Registry = require(script.Parent.Parent.Registry)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Menu = {}

type Item = { label: string, order: number, onClick: () -> (), shown: (() -> boolean)? }

local items: { Item } = {}
local list: GuiObject? = nil
local lobbyY = 186
local rebuild: (() -> ())? = nil
local onInvite: (() -> ())? = nil
local inviteShown: (() -> boolean)? = nil

local WIDTH, ROW, GAP = 150, 34, 4
local MENU_W, FRIENDS_W, HEIGHT = 74, 34, 30

-- Adds an entry (callable before or after mount).
function Menu.add(label: string, order: number, onClick: () -> (), shown: (() -> boolean)?)
	table.insert(items, { label = label, order = order, onClick = onClick, shown = shown })
	table.sort(items, function(a, b)
		return a.order < b.order
	end)
	if rebuild then
		rebuild()
	end
end

-- The friends mark beside MENU: `onClick` opens the invite prompt; it shows while `shown` says so.
function Menu.invite(onClick: () -> (), shown: () -> boolean)
	onInvite = onClick
	inviteShown = shown
end

-- Two figures, one a little behind and above the other: a head and the round of the shoulders.
local function friendsMark(parent: Instance)
	local mark = Ui.new("Frame", {
		Name = "Mark",
		Size = UDim2.fromOffset(20, 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = parent,
	})
	local function figure(x: number, y: number, color: Color3, z: number)
		local head = Ui.new("Frame", {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.fromOffset(x + 3, y),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = mark,
		})
		Ui.corner(3).Parent = head
		-- the shoulders: a rounded block whose bottom half is cut off by a clipping frame
		local clip = Ui.new("Frame", {
			Size = UDim2.fromOffset(12, 6),
			Position = UDim2.fromOffset(x, y + 7),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = z,
			Parent = mark,
		})
		local body = Ui.new("Frame", {
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = clip,
		})
		Ui.corner(6).Parent = body
	end
	figure(7, 1, Theme.Color.boneDim, 21) -- behind
	figure(1, 4, Theme.Color.bone, 22) -- in front
	return mark
end

-- The lobby's slot for the button: just under the crew pass, whatever size it is folded to.
function Menu.setLobbyY(y: number)
	lobbyY = y
end

function Menu.close()
	if list then
		list.Visible = false
	end
end

function Menu.mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	-- one split box: MENU, a hairline, then the friends mark
	local box = Ui.new("Frame", {
		Name = "MenuBox",
		Size = UDim2.fromOffset(MENU_W + FRIENDS_W, HEIGHT),
		Position = UDim2.fromOffset(14, lobbyY),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})
	local open = Ui.button("MENU", "Secondary", nil, {
		Name = "MenuButton",
		Size = UDim2.fromOffset(MENU_W, HEIGHT),
		TextSize = 15,
		Selectable = true,
	})
	open.ZIndex = 20
	open.Parent = box
	local friends = Ui.button("", "Secondary", function()
		local handler = onInvite
		if handler then
			handler()
		end
	end, {
		Name = "Friends",
		Size = UDim2.fromOffset(FRIENDS_W, HEIGHT),
		Position = UDim2.fromOffset(MENU_W, 0),
		Selectable = true,
	})
	friends.ZIndex = 20
	friends.Visible = false
	friends.Parent = box
	friendsMark(friends)
	Ui.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1, 1, -10),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 23,
		Parent = friends,
	})
	local drop = Ui.panel({
		Name = "MenuList",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 0, 1, 6),
		Visible = false,
		Parent = open,
	})
	drop.ZIndex = 21
	Ui.padding(6, 6).Parent = drop
	Ui.list(Enum.FillDirection.Vertical, GAP).Parent = drop
	list = drop

	local function build()
		for _, child in drop:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for i, item in items do
			if item.shown == nil or item.shown() then
				local entry = Ui.button(item.label, "Secondary", function()
					drop.Visible = false
					item.onClick()
				end, {
					Name = "MenuItem",
					Size = UDim2.new(1, 0, 0, ROW),
					LayoutOrder = i,
					TextSize = 15,
					Selectable = true,
				})
				entry.ZIndex = 22
				entry.TextColor3 = Theme.Color.bone
				entry.Parent = drop
			end
		end
	end
	rebuild = build
	local function toggle()
		if not drop.Visible then
			build() -- entries that come and go (Line Mastery, INVITE) are read on opening
		end
		drop.Visible = not drop.Visible
		if Registry.AudioController then
			Registry.AudioController.Tap("MenuClick")
		end
	end
	-- a mouse or a finger opens it as it goes down, with its key sound: waiting for the release
	-- (Activated) felt like a missed press, and the second press shut it again
	local pointerDown = false
	open.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			pointerDown = true
			toggle()
		end
	end)
	open.Activated:Connect(function()
		if pointerDown then
			pointerDown = false -- the release of the press that already toggled it
			return
		end
		toggle() -- gamepad A or Enter
	end)

	-- where it sits: the lobby slot, under the run's gauges, or the corner with the HUD hidden
	task.spawn(function()
		local lobby = gui:WaitForChild("Lobby") :: GuiObject
		local function place()
			local y = if player:GetAttribute("Hud") == "Hide" then 14 elseif lobby.Visible then lobbyY else 146
			if box.Position.Y.Offset ~= y then
				box.Position = UDim2.fromOffset(14, y)
				drop.Visible = false
			end
			local shown = inviteShown
			friends.Visible = onInvite ~= nil and shown ~= nil and shown()
		end
		place()
		lobby:GetPropertyChangedSignal("Visible"):Connect(place)
		player:GetAttributeChangedSignal("Hud"):Connect(place)
		game:GetService("RunService").Heartbeat:Connect(place)
	end)
end

return Menu
