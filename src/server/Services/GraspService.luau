--!strict
--[[
	The railing grasp (docs/FINAL-DESIGN.md Prompt 4; rules in Logic/RailingGrasp). During the live
	Departure chase window an off-train player's Jump sends Grasp. The server snapshots its own
	replicated root and the nearest static GraspRail once, at receipt, and decides from that alone.
	A catch credits Aboard at once (CrewService.CreditGrasp), welds the root to the rail, hangs 0.6 s,
	hauls 0.5 s into the doorway with the character's collision off, then lets go. A miss plays a
	0.5 s stumble and allows another try while the window is open; the measured shortfall is kept for
	the left-behind line. RunDirector holds Departure 0.2 s past the window so late receipts resolve.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Rules = require(Shared.Logic.RailingGrasp)
local Telemetry = require(Shared.Logic.Telemetry)
local Safe = require(Shared.Util.Safe)
local Registry = require(script.Parent.Parent.Registry)
local G = Tuning.Grasp
local GraspService = {}

type AttachmentState = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	rail: BasePart,
	weld: Weld,
	tween: Tween?,
	collisions: { [BasePart]: boolean },
	autoRotate: boolean,
	platformStand: boolean,
	died: RBXScriptConnection?,
}
type Attempt = { reason: string, shortfall: number? }
local attached: { [Player]: AttachmentState } = {}
local occupied: { [BasePart]: Player } = {}
local attempts: { [Player]: Attempt } = {}
local missUntil: { [Player]: number } = {}

function GraspService.IsAttached(player: Player): boolean
	return attached[player] ~= nil
end

function GraspService.Cleanup(player: Player)
	local state = attached[player]
	attached[player] = nil
	missUntil[player] = nil
	if state then
		occupied[state.rail] = nil
		if state.died then
			state.died:Disconnect()
		end
		if state.tween then
			state.tween:Cancel()
		end
		state.weld:Destroy()
		for part, collide in state.collisions do
			if part.Parent then
				part.CanCollide = collide
			end
		end
		if state.humanoid.Parent then
			state.humanoid.AutoRotate = state.autoRotate
			state.humanoid.PlatformStand = state.platformStand
		end
		if state.root.Parent then
			state.root.AssemblyLinearVelocity = Vector3.zero
			state.root.AssemblyAngularVelocity = Vector3.zero
			local canSet = state.root:CanSetNetworkOwnership()
			if canSet then
				state.root:SetNetworkOwnershipAuto()
			end
		end
		state.character:SetAttribute("Grasp", nil)
		state.character:SetAttribute("GraspAt", nil)
	end
	local character = player.Character
	if character and character:GetAttribute("Grasp") == "Miss" then
		character:SetAttribute("Grasp", nil)
		character:SetAttribute("GraspAt", nil)
	end
end

function GraspService.LeftBehindText(player: Player): string?
	local attempt = attempts[player]
	if not attempt then
		return nil
	end
	if attempt.reason == "missed" and attempt.shortfall then
		return Rules.shortfallText(attempt.shortfall)
	elseif attempt.reason == "window" then
		return "The grasp was outside the departure window."
	elseif attempt.reason == "occupied" then
		return "That handhold was occupied."
	elseif attempt.reason == "state" then
		return "Unable to grasp in that state."
	end
	return nil
end

local function record(
	player: Player,
	reason: string,
	secondsLeft: number,
	gap: number?,
	reach: number?,
	pressOffset: number?
)
	local fields = { reason, Telemetry.secondsLeft(secondsLeft), Registry.TelemetryService.Device(player) }
	Registry.TelemetryService.Event(player, "grasp", gap or 0, fields)
	if gap and reach then
		Registry.TelemetryService.Event(player, "grasp_shortfall", math.max(0, gap - reach), fields)
		Registry.TelemetryService.Event(player, "grasp_reach", reach, fields)
	end
	if pressOffset then
		Registry.TelemetryService.Event(player, "grasp_press_offset", pressOffset, fields)
	end
end

local function reject(
	player: Player,
	character: Model?,
	reason: string,
	receipt: number,
	secondsLeft: number,
	gap: number?,
	reach: number?,
	pressOffset: number?
)
	attempts[player] =
		{ reason = reason, shortfall = if gap and reach then math.max(0, gap - reach) else nil }
	record(player, reason, secondsLeft, gap, reach, pressOffset)
	if reason == "missed" and character then
		missUntil[player] = receipt + G.MissSeconds
		character:SetAttribute("GraspAt", receipt)
		character:SetAttribute("Grasp", "Miss")
		task.delay(G.MissSeconds, function()
			if missUntil[player] == receipt + G.MissSeconds then
				missUntil[player] = nil
				if character.Parent and character:GetAttribute("Grasp") == "Miss" then
					character:SetAttribute("Grasp", nil)
					character:SetAttribute("GraspAt", nil)
				end
			end
		end)
	end
end

local function attach(
	player: Player,
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	rail: BasePart,
	receipt: number
)
	local collisions: { [BasePart]: boolean } = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			collisions[part] = part.CanCollide
			part.CanCollide = false
		end
	end
	local canSet = root:CanSetNetworkOwnership()
	if canSet then
		root:SetNetworkOwner(nil)
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local weld = Instance.new("Weld")
	weld.Name = "RailingGrasp"
	weld.Part0 = rail
	weld.Part1 = root
	weld.C0 = CFrame.new(0, -G.HangDrop, G.HangOutside)
	root.CFrame = rail.CFrame * weld.C0
	weld.Parent = root
	local state: AttachmentState = {
		character = character,
		root = root,
		humanoid = humanoid,
		rail = rail,
		weld = weld,
		tween = nil,
		collisions = collisions,
		autoRotate = humanoid.AutoRotate,
		platformStand = humanoid.PlatformStand,
		died = nil,
	}
	attached[player] = state
	occupied[rail] = player
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	character:SetAttribute("GraspAt", receipt)
	character:SetAttribute("Grasp", "Hang")
	character:SetAttribute("OffTrain", false)
	state.died = humanoid.Died:Connect(function()
		GraspService.Cleanup(player)
	end)
	Registry.CrewService.CreditGrasp(player)
	task.delay(G.HangSeconds, function()
		Safe.call("Grasp.haul", function()
			if attached[player] ~= state then
				return
			end
			character:SetAttribute("GraspAt", Workspace:GetServerTimeNow())
			character:SetAttribute("Grasp", "Haul")
			local tween = TweenService:Create(
				weld,
				TweenInfo.new(G.HaulSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{
					C0 = CFrame.new(0, -G.HaulDrop, -G.HaulInside),
				}
			)
			state.tween = tween
			tween.Completed:Once(function()
				if attached[player] == state then
					GraspService.Cleanup(player)
				end
			end)
			tween:Play()
		end)
	end)
end

local function attempt(player: Player)
	local receipt = Workspace:GetServerTimeNow()
	if attached[player] or (missUntil[player] and receipt < missUntil[player]) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local chaseStart, chaseEnd = Registry.RunDirector.ChaseWindow()
	local secondsLeft = if chaseEnd then chaseEnd - receipt else 0
	if
		not character
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or not Registry.CrewService.IsAlive(player)
		or Registry.CrewService.IsAboard(player)
		or Registry.HollowService.IsHeld(player)
		or root.Anchored
	then
		reject(player, character, "state", receipt, secondsLeft, nil, nil, nil)
		return
	end
	if Registry.RunDirector.Phase() ~= "Departure" or not chaseStart or not chaseEnd then
		reject(player, character, "window", receipt, secondsLeft, nil, nil, nil)
		return
	end
	-- Snapshot once: no position history, extrapolation, or client-provided time.
	local position, velocity = root.Position, root.AssemblyLinearVelocity
	local rail: BasePart? = nil
	local gap = math.huge
	for _, candidate in Registry.TrainService.GraspRails() do
		local distance = (candidate.Position - position).Magnitude
		if distance < gap then
			rail = candidate
			gap = distance
		end
	end
	if not rail then
		reject(player, character, "state", receipt, secondsLeft, nil, nil, nil)
		return
	end
	local direction = rail.Position - position
	local closing = Rules.closing(velocity.X, velocity.Y, velocity.Z, direction.X, direction.Y, direction.Z)
	-- GetNetworkPing is round-trip latency in seconds; use measured one-way only for timing.
	local oneWay = player:GetNetworkPing() / 2
	local result = Rules.evaluate(receipt, oneWay, chaseStart, chaseEnd, gap, closing)
	local offset = receipt - result.estimatedPress
	if not result.accepted then
		reject(player, character, result.reason, receipt, secondsLeft, gap, result.reach, offset)
		return
	end
	if occupied[rail] then
		reject(player, character, "occupied", receipt, secondsLeft, nil, nil, offset)
		return
	end
	attempts[player] = nil
	record(player, "caught", secondsLeft, gap, result.reach, offset)
	attach(player, character, root, humanoid, rail, receipt)
end

-- Studio: the server holds `player` `studs` out from the nearest rail on the platform side (taking
-- ownership for the moment, so the snapshot is exactly that pose) and runs a normal attempt. Checks
-- the decision, hang, haul and miss without the client's movement; the network path stays a
-- two-client test.
function GraspService.DevAttempt(player: Player, studs: number): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return "no character"
	end
	local rail: BasePart? = nil
	for _, candidate in Registry.TrainService.GraspRails() do
		if
			rail == nil
			or (candidate.Position - root.Position).Magnitude < (rail.Position - root.Position).Magnitude
		then
			rail = candidate
		end
	end
	if rail == nil then
		return "no rail"
	end
	local out = Vector3.new(0, 0, if rail.Position.Z >= 0 then 1 else -1)
	local spot = Vector3.new(rail.Position.X, rail.Position.Y - 1.3, rail.Position.Z) + out * studs
	if root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(nil)
	end
	root.CFrame = CFrame.lookAt(spot, Vector3.new(rail.Position.X, spot.Y, rail.Position.Z))
	root.AssemblyLinearVelocity = Vector3.zero
	attempt(player)
	if not attached[player] then
		task.delay(G.MissSeconds, function()
			if root.Parent and not attached[player] and root:CanSetNetworkOwnership() then
				root:SetNetworkOwnershipAuto()
			end
		end)
	end
	return if attached[player] then "caught" else (attempts[player] and attempts[player].reason or "rejected")
end

function GraspService.Init() end
function GraspService.Start()
	Registry.NetService.Handle("Grasp", function(player: Player)
		Safe.call("Grasp.attempt", attempt, player)
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			GraspService.Cleanup(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		GraspService.Cleanup(player)
		attempts[player] = nil
	end)
	Registry.RunDirector.PhaseChanged:Connect(function(phase: string)
		if phase == "Dwell" or phase == "Lobby" or phase == "RunEnd" or phase == "Boarding" then
			for _, player in Players:GetPlayers() do
				GraspService.Cleanup(player)
			end
			table.clear(attempts)
		end
	end)
end
return GraspService
