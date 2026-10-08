--!strict
--[[
	The route board on the crew saloon's end wall (Builders/TrainInterior builds its parts).
	Near it, the junction's tickets leave the screen and hang on the board: RouteVote hands
	over the same Ticket handles, so a ticket is only ever in one place. Far from it, in
	the train camera, in another car or with more lines than the board has slots, they stay
	on screen, and voting never needs the walk. A two-way ballot hangs in TicketSlot1-2 under
	Lantern1-2; a three-way one in the narrower WideSlot1-3, its middle line under Lantern3.
	A sealed mystery's lantern flickers in a neutral lamp colour, never a danger colour.

	The room answers the vote, on this client only, from the replicated ballot: each
	ticket's lantern burns in its line's danger colour as bright as its share of the votes
	(a tie leaves them even), the ticket you point at or look at nudges its lantern and
	swings the coal gauge to what the bunker would hold after that line, and at lock-in the
	winner's lantern flares and the loser's goes out. The clock keeps the hour and sweeps a
	red hand through the stop's countdown (Controllers/DepartureClock).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ledger = require(ReplicatedStorage.Shared.Logic.Ledger)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ticket = require(script.Parent.Ticket)
local Ui = require(script.Parent.Ui)

local RouteBoard = {}

local SLOTS = 2 -- two-way ticket slots on the board (TrainInterior)
local WIDE = 3 -- three-way slots
local LANTERNS = 3
-- which option each lantern lights, by ballot size: Lantern3 hangs in the middle
local LANTERN_OPTION: { [number]: { number? } } = { [1] = { 1 }, [2] = { 1, 2 }, [3] = { 1, 3, 2 } }
local ENGAGE = 10 -- studs from the board: the tickets move onto it
local RELEASE = 12 -- and back to the screen (a gap, so they never flicker)
local ROOM_DEPTH = 16 -- the saloon car runs this far from the board along -X
local PROMPT_RANGE = 8
local LOOKUP_EVERY = 0.5 -- seconds between looks for the board while it is not streamed in
local DIAL_RANGE = 40 -- the dials are only wound while someone stands this close
local EASE = 6 -- lantern and needle easing, per second

local IDLE = { brightness = 0.4, range = 12 } -- as built, when no ballot is up
local LIT = { base = 0.3, share = 1.5, range = 8, rangeShare = 8 }
local NUDGE = 0.45 -- extra brightness on the ticket you point at
local FLARE = 1.2 -- the winner's flare at lock-in, fading over FLARE_SECONDS
local FLARE_SECONDS = 1.2
local GAUGE_SWEEP = 120 -- needle degrees either side of straight up
local DARK_GLASS = Color3.fromRGB(46, 36, 30)
local WARM = Color3.fromRGB(255, 206, 150)
local LAMP = Color3.fromRGB(196, 222, 226) -- a sealed mystery's lantern
local FLICKER = 9 -- noise speed of its flicker
local DANGER = { -- by danger tier: amber, burnt orange, signal red
	Color3.fromRGB(240, 186, 90),
	Color3.fromRGB(236, 118, 52),
	Color3.fromRGB(214, 52, 40),
}

export type Ballot = {
	active: boolean, -- the ballot is up (a junction, or the punch lingering after it)
	tickets: { Ticket.Handle },
	options: { any },
	votes: { [string]: number },
	chosen: number?,
	mine: number?,
	train: any?,
	vote: (index: number) -> (),
}

export type Board = {
	update: (ballot: Ballot) -> (),
	engaged: () -> boolean,
	host: (index: number) -> SurfaceGui?,
}

type Lantern = { glass: BasePart, light: PointLight, brightness: number }
type Parts = {
	board: BasePart,
	slots: { BasePart },
	wide: { BasePart },
	lanterns: { Lantern },
	clock: BasePart,
	gauge: BasePart,
}

local function surface(name: string, part: BasePart, pixels: number, gui: Instance): SurfaceGui
	local s = Instance.new("SurfaceGui")
	s.Name = name
	s.Face = Enum.NormalId.Front
	s.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	s.PixelsPerStud = pixels
	s.LightInfluence = 0.35
	s.ResetOnSpawn = false
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Adornee = part
	s.Parent = gui
	return s
end

-- A frame the size of the dial, turned about its middle: whatever hangs in it turns too.
local function pivot(parent: Instance, rotation: number): Frame
	return Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = rotation,
		Parent = parent,
	})
end

local function hand(parent: Instance, length: number, width: number, color: Color3, z: number): Frame
	local p = pivot(parent, 0)
	p.ZIndex = z
	Ui.new("Frame", {
		Size = UDim2.new(0, width, length, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = p,
	})
	return p
end

-- A card dial face with `ticks` marks spread over `arc` degrees, centred on twelve.
local function dial(gui: SurfaceGui, ticks: number, arc: number, caption: string): Frame
	local face = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.paper,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = face })
	Ui.stroke(Theme.Color.ink, 3, 0).Parent = face
	for i = 0, ticks - 1 do
		local a = if arc >= 360 then i * 360 / ticks else -arc / 2 + i * arc / (ticks - 1)
		local p = pivot(face, a)
		Ui.new("Frame", {
			Size = UDim2.new(0, 3, 0.12, 0),
			Position = UDim2.fromScale(0.5, 0.06),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.Color.ink,
			BorderSizePixel = 0,
			Parent = p,
		})
	end
	Ui.text({
		Text = caption,
		Font = Theme.Font.type,
		TextSize = 14,
		Color = Theme.Color.inkSoft,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromScale(0, 0.68),
		XAlign = Enum.TextXAlignment.Center,
	}).Parent =
		face
	return face
end

local function hub(face: Frame)
	local dot = Ui.new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = face,
	})
	Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
end

local function find(): Parts?
	local train = Workspace:FindFirstChild("Train")
	local model = train and train:FindFirstChild("RouteBoard", true)
	if model == nil then
		return nil
	end
	local function get(name: string): BasePart?
		local p = model:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	local board, clock, gauge = get("Board"), get("Clock"), get("CoalGauge")
	if board == nil or clock == nil or gauge == nil then
		return nil
	end
	local slots: { BasePart } = {}
	local wide: { BasePart } = {}
	local lanterns: { Lantern } = {}
	for i = 1, SLOTS do
		local slot = get(`TicketSlot{i}`)
		if slot == nil then
			return nil
		end
		slots[i] = slot
	end
	for i = 1, WIDE do
		local slot = get(`WideSlot{i}`)
		if slot == nil then
			return nil
		end
		wide[i] = slot
	end
	for i = 1, LANTERNS do
		local glass = get(`Lantern{i}`)
		local light = glass and glass:FindFirstChildOfClass("PointLight")
		if glass == nil or light == nil then
			return nil
		end
		lanterns[i] = { glass = glass, light = light, brightness = IDLE.brightness }
	end
	return { board = board, slots = slots, wide = wide, lanterns = lanterns, clock = clock, gauge = gauge }
end

function RouteBoard.new(onEngagedChanged: () -> ()): Board
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local parts: Parts? = nil
	-- by ballot size: two-way slots for 1-2 lines, the wide slots for 3
	local hosts: { [number]: { SurfaceGui } } = { [2] = {}, [3] = {} }
	local prompts: { [number]: { ProximityPrompt } } = { [2] = {}, [3] = {} }
	local clockHands: { hour: Frame, minute: Frame, depart: Frame }? = nil
	local needle: Frame? = nil
	local needleAngle = -GAUGE_SWEEP
	local engaged = false
	local ballot: Ballot? = nil
	local hooked: { Ticket.Handle } = {}
	local hovered: number? = nil
	local promptFocus: number? = nil
	local flareAt = 0
	local flaredFor: number? = nil
	local lastLookup = -math.huge
	local syncPrompts: () -> ()

	local function dress(found: Parts)
		for _, size in { SLOTS, WIDE } do
			for _, host in hosts[size] do
				host:Destroy()
			end
			for _, p in prompts[size] do
				p:Destroy()
			end
			table.clear(hosts[size])
			table.clear(prompts[size])
		end
		for _, entry in { { size = 2, slots = found.slots }, { size = 3, slots = found.wide } } do
			for i, slot in entry.slots do
				-- the ticket fills the slot exactly: its 224 x 310 px over the slot's width
				hosts[entry.size][i] =
					surface(`RouteBoardTicket{entry.size}_{i}`, slot, 224 / slot.Size.X, gui)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "RouteBoardVote"
				prompt.ActionText = "Take this line"
				prompt.ObjectText = ""
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = PROMPT_RANGE
				prompt.RequiresLineOfSight = false
				prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
				prompt.Enabled = false
				prompt.Triggered:Connect(function()
					if ballot then
						ballot.vote(i)
					end
				end)
				prompt.PromptShown:Connect(function()
					promptFocus = i
				end)
				prompt.PromptHidden:Connect(function()
					if promptFocus == i then
						promptFocus = nil
					end
				end)
				prompt.Parent = slot
				prompts[entry.size][i] = prompt
			end
		end
		local clockGui = surface("RouteBoardClock", found.clock, 128 / found.clock.Size.X, gui)
		local clockFace = dial(clockGui, 12, 360, "L.T.O.")
		clockHands = {
			hour = hand(clockFace, 0.24, 6, Theme.Color.ink, 6),
			minute = hand(clockFace, 0.36, 4, Theme.Color.ink, 7),
			depart = hand(clockFace, 0.4, 2, Theme.Color.signal, 8),
		}
		hub(clockFace)
		local gaugeGui = surface("RouteBoardGauge", found.gauge, 128 / found.gauge.Size.X, gui)
		local gaugeFace = dial(gaugeGui, 5, GAUGE_SWEEP * 2, "COAL")
		needle = hand(gaugeFace, 0.38, 3, Theme.Color.signal, 7)
		hub(gaugeFace)
	end

	local function present(): boolean
		return parts ~= nil and parts.board.Parent ~= nil
	end

	local function shares(b: Ballot): { number }
		local counts: { number } = {}
		local total = 0
		for i = 1, #b.options do
			counts[i] = 0
		end
		for _, index in b.votes do
			if counts[index] then
				counts[index] += 1
				total += 1
			end
		end
		for i = 1, #b.options do
			counts[i] = if total > 0 then counts[i] / total else 1 / #b.options
		end
		return counts
	end

	-- The ticket being pointed at: the mouse over it, the gamepad's selection, or its prompt.
	local function focus(): number?
		return hovered or promptFocus
	end

	local function hook(b: Ballot)
		if #hooked == #b.tickets and hooked[1] == b.tickets[1] then
			return
		end
		hooked = table.clone(b.tickets)
		hovered = nil
		for index, handle in b.tickets do
			handle.slot.MouseEnter:Connect(function()
				hovered = index
			end)
			handle.slot.MouseLeave:Connect(function()
				if hovered == index then
					hovered = nil
				end
			end)
			handle.button.SelectionGained:Connect(function()
				hovered = index
			end)
			handle.button.SelectionLost:Connect(function()
				if hovered == index then
					hovered = nil
				end
			end)
		end
	end

	local function wanted(): boolean
		local b = ballot
		if not (b and b.active and #b.tickets > 0 and #b.options <= WIDE and present()) then
			return false
		end
		if not Session.isAlive() then
			return false
		end
		local cam = Registry.TrainCamController
		if cam and cam.Active() then
			return false
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root == nil or parts == nil then
			return false
		end
		-- the saloon lies on the board's -X side; the Workshop is behind the wall
		local rel = parts.board.CFrame:PointToObjectSpace(root.Position)
		if rel.X > 0 or rel.X < -ROOM_DEPTH then
			return false
		end
		return rel.Magnitude < (if engaged then RELEASE else ENGAGE)
	end

	local function setLanterns(dt: number)
		if parts == nil then
			return
		end
		local b = ballot
		local up = b ~= nil and b.active and #b.options > 0
		local share = if b and up then shares(b) else {}
		local target = focus()
		local flare = math.max(0, 1 - (os.clock() - flareAt) / FLARE_SECONDS) * FLARE
		local map = LANTERN_OPTION[if b and up then #b.options else 0] or {}
		for li, lantern in parts.lanterns do
			local i = map[li] or 0
			local option = if b and up then b.options[i] else nil
			local out = b ~= nil and b.chosen ~= nil and b.chosen ~= i and option ~= nil
			local goal, range, color = IDLE.brightness, IDLE.range, WARM
			if option then
				local s = share[i] or 0
				local tier = math.clamp(math.floor(option.tier or 1), 1, #DANGER)
				goal = LIT.base + LIT.share * s
				range = LIT.range + LIT.rangeShare * s
				color = if option.mystery then LAMP else WARM:Lerp(DANGER[tier], 0.35 + 0.65 * s)
				if option.mystery then
					goal *= 0.6 + 0.4 * math.noise(os.clock() * FLICKER, li)
				end
				if target == i and b and b.chosen == nil then
					goal += NUDGE
				end
				if b and b.chosen == i then
					goal = LIT.base + LIT.share + flare
				end
			end
			if out then
				goal = 0
			end
			lantern.brightness += (goal - lantern.brightness) * math.min(1, dt * EASE)
			lantern.light.Brightness = lantern.brightness
			lantern.light.Range = range
			lantern.light.Color = color
			lantern.light.Enabled = lantern.brightness > 0.02
			lantern.glass.Color = DARK_GLASS:Lerp(color, math.clamp(lantern.brightness / 0.6, 0, 1))
		end
	end

	local function setDials(dt: number)
		if parts == nil or clockHands == nil or needle == nil then
			return
		end
		local atmosphere = Registry.AtmosphereController
		if atmosphere then
			local hour = atmosphere.Hour()
			clockHands.hour.Rotation = (hour % 12) / 12 * 360
			clockHands.minute.Rotation = (hour % 1) * 360
		end
		local departure = Registry.DepartureClock
		local remaining = if departure then departure.Remaining() else nil
		clockHands.depart.Visible = remaining ~= nil
		if remaining then
			clockHands.depart.Rotation = -(remaining % 60) / 60 * 360
		end
		-- the gauge reads the bunker, or what it would hold after the line you point at
		local b = ballot
		local train = if b then b.train else nil
		local fill = 0
		if train and train.coal and train.coalMax and train.coalMax > 0 then
			local coal = train.coal
			local index = focus()
			local option = if b and b.active and index then b.options[index] else nil
			if option then
				coal = math.max(0, coal - Ledger.legCoalCost(train, option.distanceKm))
			end
			fill = math.clamp(coal / train.coalMax, 0, 1)
		end
		local goal = -GAUGE_SWEEP + 2 * GAUGE_SWEEP * fill
		needleAngle += (goal - needleAngle) * math.min(1, dt * EASE)
		needle.Rotation = needleAngle
	end

	-- A Vote prompt on each ticket while it hangs on the board and the ballot is open.
	function syncPrompts()
		local b = ballot
		local size = if b and #b.options >= WIDE then WIDE else SLOTS
		for _, set in { SLOTS, WIDE } do
			for i, prompt in prompts[set] do
				local option = if b then b.options[i] else nil
				prompt.Enabled = engaged
					and set == size
					and b ~= nil
					and b.active
					and b.chosen == nil
					and option ~= nil
					and #b.options > 1
				prompt.ActionText = if b and b.mine == i then "Your vote" else "Take this line"
				prompt.ObjectText = if option then `No. {i}` else ""
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		if not present() then
			local now = os.clock()
			if now - lastLookup >= LOOKUP_EVERY then
				lastLookup = now
				local found = find()
				if found then
					parts = found
					dress(found)
					syncPrompts()
				end
			end
		end
		local want = wanted()
		if want ~= engaged then
			engaged = want
			syncPrompts()
			onEngagedChanged()
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if parts and root and (root.Position - parts.board.Position).Magnitude < DIAL_RANGE then
			setLanterns(dt)
			setDials(dt)
		end
	end)

	local board = {} :: Board

	function board.update(b: Ballot)
		ballot = b
		if b.active then
			hook(b)
		else
			hooked = {}
			hovered = nil
		end
		if b.chosen ~= nil and flaredFor ~= b.chosen then
			flaredFor = b.chosen
			flareAt = os.clock()
		elseif b.chosen == nil then
			flaredFor = nil
		end
		syncPrompts()
	end

	function board.engaged(): boolean
		return engaged
	end

	function board.host(index: number): SurfaceGui?
		local b = ballot
		return hosts[if b and #b.options >= WIDE then WIDE else SLOTS][index]
	end

	return board
end

return RouteBoard
