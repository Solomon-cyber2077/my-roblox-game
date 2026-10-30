--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local H = require(Shared.Config.Haul)
local Tuning = require(Shared.Config.Tuning)
local Items = require(Shared.Config.Items)
local Types = require(Shared.Types)
local Payroll = require(Shared.Logic.Payroll)
local RunRules = require(Shared.Logic.RunRules)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Safe = require(Shared.Util.Safe)
local Builder = require(script.Parent.Parent.Builders.HaulBuilder)
local Registry = require(script.Parent.Parent.Registry)
local Service = {}
local stores: Model
local box: BasePart
local marker: BasePart
local crate: Model? = nil
local tracking: Payroll.State? = nil
local ground: Vector3? = nil -- station-local: dropped crates remain at their own station
local valuables: { string } = {}
local trophies: { string } = {}
local closed = false
local settled = false
local lamps: { [number]: any } = {}
local grabbed: { [Player]: boolean } = {}
local movementBudget = H.MovementSlack
local function root(player: Player): BasePart?
	local ch = player.Character
	local r = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
	return if r and r:IsA("BasePart") then r else nil
end
local function alive(player: Player): boolean
	return Registry.CrewService.IsAlive(player)
		and player.Character ~= nil
		and player.Character:GetAttribute("GrabStyle") == nil
end
local function distance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end
local function prompt(part: BasePart, label: string, callback: (Player) -> (), reach: number?)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = label
	p.ObjectText = part.Name
	p.KeyboardKeyCode = Enum.KeyCode.E
	local maxReach = reach or H.PromptReach
	p.MaxActivationDistance = maxReach
	p.RequiresLineOfSight = false
	p.HoldDuration = 0.25
	p.Parent = part
	p.Triggered:Connect(function(player)
		local r = root(player)
		if r and alive(player) and (r.Position - part.Position).Magnitude <= maxReach + 1 then
			callback(player)
		end
	end)
end
local function returnLamp(id: number)
	local saved = lamps[id]
	if not saved then
		return
	end
	for p, transparency in saved.parts do
		if p.Parent then
			p.Transparency = transparency
		end
	end
	for light, enabled in saved.lights do
		if light.Parent then
			light:SetAttribute("PayrollAttached", nil)
			light.Enabled = enabled
		end
	end
	saved.copy:Destroy()
	lamps[id] = nil
end
local function attachLamp(player: Player)
	local c = crate
	if not c or lamps[player.UserId] then
		return
	end
	local cosmetics = player.Character and player.Character:FindFirstChild("Cosmetics")
	local source = cosmetics and cosmetics:FindFirstChild("Lantern")
	if not source or not source:IsA("Model") then
		return
	end
	local copy = source:Clone()
	local saved: any = { copy = copy, parts = {}, lights = {}, color = Color3.fromRGB(240, 195, 125) }
	for _, node in copy:GetDescendants() do
		if node:IsA("WeldConstraint") then
			node:Destroy()
		elseif node:IsA("BasePart") then
			node.Anchored = true
			node.CanCollide = false
		elseif node:IsA("Light") then
			saved.color = node.Color
			node.Enabled = false
		elseif node:IsA("ParticleEmitter") then
			node.Enabled = false
		end
	end
	for _, node in source:GetDescendants() do
		if node:IsA("BasePart") then
			saved.parts[node] = node.Transparency
			node.Transparency = 1
		elseif node:IsA("Light") or node:IsA("ParticleEmitter") then
			saved.lights[node] = node.Enabled
			node:SetAttribute("PayrollAttached", true)
			local effect = node :: any
			effect.Enabled = false
		end
	end
	copy.Parent = c
	lamps[player.UserId] = saved
end
local function syncCarriers()
	local state = tracking
	for _, player in Players:GetPlayers() do
		local carrying = state ~= nil and table.find(state.carriers, player.UserId) ~= nil
		if player.Character then
			player.Character:SetAttribute(
				"PayrollCarriers",
				if carrying and state then #state.carriers else nil
			)
		end
		if carrying then
			attachLamp(player)
		else
			returnLamp(player.UserId)
		end
	end
end
local function leave(id: number)
	if tracking then
		Payroll.leave(tracking, id)
	end
	returnLamp(id)
	if crate and tracking and #tracking.carriers == 0 then
		local position = crate:GetPivot().Position
		ground = if Registry.TrainService.IsInside(position)
			then nil
			else Registry.StationService.ToLocal(position)
	end
	syncCarriers()
end
local function clearCrate()
	if tracking then
		for _, id in table.clone(tracking.carriers) do
			leave(id)
		end
	end
	if crate then
		crate:Destroy()
	end
	crate = nil
	tracking = nil
	ground = nil
end
local function deposit(player: Player)
	if closed or settled then
		return
	end
	local inventory: { items: { string } } = Registry.InventoryService.Get(player)
	for _, id in table.clone(inventory.items) do
		if Items[id] and Items[id].kind == "Valuable" and Registry.InventoryService.Consume(player, id) then
			table.insert(valuables, id)
		end
	end
	Builder.stack(stores, valuables)
end
local function deliver(player: Player)
	local state, c = tracking, crate
	if not state or not c or not table.find(state.carriers, player.UserId) or settled then
		return
	end
	if distance(c:GetPivot().Position, marker.Position) > H.DeliveryReach then
		return
	end
	Payroll.sample(state, distance(c:GetPivot().Position, marker.Position))
	local bonus = Payroll.eligible(state)
	for _, id in table.clone(state.carriers) do
		leave(id)
	end
	Payroll.deliver(state)
	for _ = 1, if bonus then 2 else 1 do
		for _, id in H.CrateValuables do
			table.insert(valuables, id)
		end
	end
	table.insert(trophies, H.Trophy)
	local oldTicket = stores:FindFirstChild("Burnt railway ticket")
	if oldTicket then
		oldTicket:Destroy()
	end
	Builder.ticket(stores, marker.CFrame * CFrame.new(0.9, 0.16, 0.8))
	Registry.TrainService.Deposit({ "Scrap" })
	-- A physical supply tray keeps the consumable recoverable even with a full backpack.
	local usedSlots: { [number]: boolean } = {}
	for _, child in stores:GetChildren() do
		if child.Name == "Payroll supply" then
			local slot = child:GetAttribute("PayrollSlot")
			if typeof(slot) == "number" then
				usedSlots[slot] = true
			end
		end
	end
	local supplySlot = 0
	while usedSlots[supplySlot] and supplySlot < 10 do
		supplySlot += 1
	end
	if supplySlot >= 10 then
		return
	end
	local supplyOffset =
		Vector3.new((supplySlot % 5 - 2) * 0.65, 0.7, (math.floor(supplySlot / 5) - 1) * 0.65)
	local supply = require(Shared.Visual.ItemModel).build("Tonic", marker.CFrame * CFrame.new(supplyOffset))
	supply.Name = "Payroll supply"
	supply:SetAttribute("PayrollSlot", supplySlot)
	supply.Parent = stores
	prompt(supply.PrimaryPart :: BasePart, "Take tonic", function(receiver)
		if #Registry.InventoryService.Give(receiver, { "Tonic" }) == 0 then
			supply:Destroy()
		end
	end)
	Registry.NetService.FireAll(
		"Notify",
		"Station",
		"Seal broken: payroll, a burnt railway ticket, scrap and tonic recovered."
	)
	clearCrate()
	Builder.stack(stores, valuables)
end
function Service.Activate(built: any, plan: any)
	clearCrate()
	if not plan.payroll then
		return
	end
	local spot = plan.payroll
	local position = Registry.StationService.ToWorld(spot.x, 1, spot.z)
	crate = Builder.crate(built.model, CFrame.new(position))
	ground = Registry.StationService.ToLocal(position)
	local c = crate :: Model
	prompt(c.PrimaryPart :: BasePart, "Carry / put down", function(player)
		if not RunRules.isStationOpen(Registry.RunDirector.Phase()) then
			return
		end
		local r = root(player)
		if not r or distance(r.Position, c:GetPivot().Position) > H.PickupReach then
			return
		end
		if not tracking then
			tracking = Payroll.new(distance(c:GetPivot().Position, marker.Position))
		end
		local state = tracking :: Payroll.State
		if table.find(state.carriers, player.UserId) then
			leave(player.UserId)
		elseif Payroll.join(state, player.UserId) then
			ground = nil
			movementBudget = H.MovementSlack
			syncCarriers()
		end
	end, H.PickupReach)
	for i, id in H.LooseValuables do
		Registry.LootService.DropAt(id, position + Vector3.new((i - 2) * 2, 0, -3))
	end
end
function Service.Reset()
	clearCrate()
	table.clear(valuables)
	table.clear(trophies)
	table.clear(grabbed)
	closed = false
	settled = false
	local lid = stores:FindFirstChild("Lid") :: BasePart
	lid.CFrame = box.CFrame * CFrame.new(0, 0.98, 0)
	for _, child in stores:GetChildren() do
		if child.Name == "Payroll supply" or child.Name == "Burnt railway ticket" then
			child:Destroy()
		end
	end
	Builder.stack(stores, valuables)
end
function Service.Open()
	if closed then
		return
	end
	-- Bank carried valuables aboard before sealing the final ledger.
	for _, player in Players:GetPlayers() do
		if Registry.CrewService.IsAboard(player) then
			deposit(player)
		end
	end
	closed = true
	local lid = stores:FindFirstChild("Lid") :: BasePart
	lid.CFrame = box.CFrame * CFrame.new(0, 1.7, -0.9) * CFrame.Angles(math.rad(-75), 0, 0)
end
function Service.Settle(success: boolean): Types.HaulReceipt
	if settled then
		return { valuables = {}, trophies = {}, xp = 0 }
	end
	if success then
		Service.Open()
	end
	settled = true
	local receipt: Types.HaulReceipt = {
		valuables = table.clone(valuables),
		trophies = if success then table.clone(trophies) else {},
		xp = 0,
	}
	if success then
		for _, id in valuables do
			receipt.xp += H.Xp[id] or 0
		end
	else
		for _, player in Players:GetPlayers() do
			for _, id in Registry.InventoryService.Get(player).items do
				if Items[id] and Items[id].kind == "Valuable" then
					table.insert(receipt.valuables, id)
				end
			end
		end
	end
	table.clear(valuables)
	table.clear(trophies)
	clearCrate()
	Builder.stack(stores, valuables)
	return receipt
end
local function step(dt: number)
	for _, player in Players:GetPlayers() do
		local ch = player.Character
		local held = ch ~= nil and ch:GetAttribute("GrabStyle") ~= nil
		if held and not grabbed[player] then
			leave(player.UserId)
			local r = root(player)
			if r then
				local inventory: { items: { string } } = Registry.InventoryService.Get(player)
				for _, id in table.clone(inventory.items) do
					if Items[id] and Items[id].kind == "Valuable" then
						if Registry.LootService.DropAt(id, r.Position) then
							Registry.InventoryService.Consume(player, id)
						end
					end
				end
			end
		end
		grabbed[player] = held
	end
	local c, state = crate, tracking
	if not c or not c.Parent then
		return
	end
	if not state or #state.carriers == 0 then
		if ground then
			local plan = Registry.StationService.Plan()
			local slab = plan and LayoutGen.slabAt(plan, ground.X, ground.Z)
			if not slab or Registry.StationService.IsCollapsed(slab.id) then
				clearCrate()
				return
			end
			c:PivotTo(CFrame.new(Registry.StationService.ToWorld(ground.X, ground.Y, ground.Z)))
		end
	else
		local positions: { Vector3 } = {}
		for _, id in table.clone(state.carriers) do
			local p = Players:GetPlayerByUserId(id)
			local r = p and root(p)
			if
				not p
				or not r
				or not alive(p)
				or distance(r.Position, c:GetPivot().Position) > H.CarrierSeparation
			then
				leave(id)
			else
				table.insert(positions, r.Position)
			end
		end
		if #positions > 0 and #positions == #state.carriers then
			local target = positions[1]
			if positions[2] then
				target = (target + positions[2]) / 2
			end
			target -= Vector3.new(0, 2, 0)
			local delta = distance(target, c:GetPivot().Position)
			local speed = Tuning.Crew.WalkSpeed
				* (1 - (if #positions == 2 then H.DuoPenalty else H.SoloPenalty))
			-- No credit for teleports or impossibly fast movement. Drop instead of banking it.
			movementBudget = math.min(H.MovementSlack, movementBudget + speed * dt)
			if delta > movementBudget then
				for _, id in table.clone(state.carriers) do
					leave(id)
				end
			else
				movementBudget -= delta
				c:PivotTo(CFrame.new(target))
				Payroll.sample(state, distance(target, marker.Position))
			end
		end
	end
	local count = if state then #state.carriers else 0
	local light = (c.PrimaryPart :: BasePart):FindFirstChild("Pool") :: PointLight
	light.Range = if count == 0
		then 8
		else Tuning.Visibility.Default * (if count == 2 then 1 + H.LampBonus else 1)
	light.Brightness = if count == 0 then H.DroppedBrightness else 1
	if state then
		local color: Color3? = nil
		for i, id in state.carriers do
			local lamp = lamps[id]
			if lamp then
				lamp.copy:PivotTo(c:GetPivot() * CFrame.new(if i == 1 then -1.5 else 1.5, 0.4, 0))
				color = if color then color:Lerp(lamp.color, 0.5) else lamp.color
			end
		end
		if color then
			light.Color = color
		end
	end
end
function Service.Init()
	stores, box, marker = Builder.stores(Registry.TrainService.Model(), Registry.TrainService.Origin())
	prompt(box, "Deposit valuables", deposit)
	prompt(marker, "Deliver sealed payroll", deliver)
end
-- Takes a player off the crate and the lamp, as when they leave the game (a cash-out, CrewService).
function Service.Drop(player: Player)
	leave(player.UserId)
	grabbed[player] = nil
end

function Service.Start()
	Registry.StationService.Cleared:Connect(clearCrate)
	Players.PlayerRemoving:Connect(Service.Drop)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= H.Tick then
			local duration = elapsed
			elapsed = 0
			Safe.call("Haul", step, duration)
		end
	end)
end
return Service
