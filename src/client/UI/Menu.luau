--!strict
--[[
	One MENU button, top left, that drops a short list: the screen keeps one small box instead of
	a stack of them (phones first: most players are young and on a phone, and the first thing they
	see should not be clutter). Other UI adds its entries with Menu.add; an entry with `shown`
	appears only while that says so (Line Mastery in the hall, INVITE when inviting is allowed).
	The list closes on a pick, on the button again, or when the place it belongs to changes.

	Where it sits: under the hall's crew pass in the lobby (Lobby sets the slot through
	Menu.setLobbyY, since the pass folds up on a phone), under the gauges in a run, top left with
	the HUD hidden.
]]

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Menu = {}

type Item = { label: string, order: number, onClick: () -> (), shown: (() -> boolean)? }

local items: { Item } = {}
local list: GuiObject? = nil
local lobbyY = 186
local rebuild: (() -> ())? = nil

local WIDTH, ROW, GAP = 150, 34, 4

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
	local open = Ui.button("MENU", "Secondary", nil, {
		Name = "MenuButton",
		Size = UDim2.fromOffset(104, 30),
		Position = UDim2.fromOffset(14, lobbyY),
		TextSize = 15,
		Selectable = true,
	})
	open.ZIndex = 20
	open.Parent = gui
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
	open.Activated:Connect(function()
		if not drop.Visible then
			build() -- entries that come and go (Line Mastery, INVITE) are read on opening
		end
		drop.Visible = not drop.Visible
	end)

	-- where it sits: the lobby slot, under the run's gauges, or the corner with the HUD hidden
	task.spawn(function()
		local lobby = gui:WaitForChild("Lobby") :: GuiObject
		local function place()
			local y = if player:GetAttribute("Hud") == "Hide" then 14 elseif lobby.Visible then lobbyY else 146
			if open.Position.Y.Offset ~= y then
				open.Position = UDim2.fromOffset(14, y)
				drop.Visible = false
			end
		end
		place()
		lobby:GetPropertyChangedSignal("Visible"):Connect(place)
		player:GetAttributeChangedSignal("Hud"):Connect(place)
		game:GetService("RunService").Heartbeat:Connect(place)
	end)
end

return Menu
