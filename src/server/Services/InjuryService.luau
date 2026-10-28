--!strict
--[[
	Recoverable arm loss (Config/Injury, rules in Logic/Injury). Behind the feature flag: with it
	off nothing here changes the game.

	The server is the only judge. Each crew member's missing arms live here for the run and are
	published as character attributes every client reads:

	  MissingArms  "", "L", "R" or "LR"
	  ReturnBy     server time an armless crew member must be safe aboard by (nil when safe)
	  Healing      server time an arm-restoring Tonic completes (nil when none)

	An arm is lost only through HollowService's crew rescue (Tear). Carrying capacity follows
	(InventoryService.Refit). A Tonic brings back the last-lost arm after an interruptible
	HealSeconds: used by a one-armed crew member themself, given by a crewmate (the "Give Tonic"
	prompt on the injured), or, for the armless aboard, from the crew chest ("Treat wounds").
	Every heal is one reservation per patient, consumed once on completion; a grab, death,
	disconnect, leaving reach or the run ending cancels it with nothing spent.

	Armless off the train: a ReturnSeconds deadline. Safe aboard clears it (no arm comes back);
	leaving armless starts a fresh one. Strictly past it, the crew member dies at once.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Injury)
local Injury = require(Shared.Logic.Injury)
local RunRules = require(Shared.Logic.RunRules)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)

local InjuryService = {}

type Heal = {
	patient: Player,
	provider: Player?, -- nil: from the crew chest
	source: "Self" | "Ally" | "Chest",
	doneAt: number,
}

local injuries: { [Player]: Injury.State } = {}
local heals: { [Player]: Heal } = {}
local prompts: { [Model]: ProximityPrompt } = {}
local chestPrompt: ProximityPrompt? = nil
local wasAboard: { [Player]: boolean } = {}

local ARMS: { [string]: string } = { L = "Left Arm", R = "Right Arm" }

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The flag: Config.Enabled, or the Studio-only dev toggle (DevService `limbs`).
function InjuryService.Enabled(): boolean
	return Config.Enabled or (RunService:IsStudio() and ReplicatedStorage:GetAttribute("LimbLossDev") == true)
end

function InjuryService.Get(player: Player): Injury.State
	return injuries[player] or Injury.new()
end

-- Ordinary carrying capacity from the uninjured capacity `base` (InventoryService).
function InjuryService.Capacity(player: Player, base: number): number
	return Injury.capacity(base, InjuryService.Get(player))
end

function InjuryService.CanUseItems(player: Player): boolean
	return Injury.canUseItems(InjuryService.Get(player))
end

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Shows the state on the character: arm visibility and the attributes clients read.
local function publish(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local state = InjuryService.Get(player)
	character:SetAttribute("MissingArms", Injury.attribute(state))
	character:SetAttribute("ReturnBy", state.returnBy)
	local heal = heals[player]
	character:SetAttribute("Healing", if heal then heal.doneAt else nil)
	for key, name in ARMS do
		local arm = character:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			arm.Transparency = if Injury.missing(state, key :: Injury.Arm) then 1 else 0
		end
	end
end

local function set(player: Player, state: Injury.State)
	injuries[player] = state
	publish(player)
	Registry.InventoryService.Refit(player)
end

local function cancelHeal(patient: Player, why: string?)
	local heal = heals[patient]
	if heal == nil then
		return
	end
	heals[patient] = nil
	publish(patient)
	if why then
		NetService.Fire("Notify", patient, "Warning", why)
		if heal.provider and heal.provider ~= patient and heal.provider.Parent then
			NetService.Fire("Notify", heal.provider, "Warning", why)
		end
	end
end

--[[
	The rescue tore an arm away (HollowService). `arm` comes from Injury.targetArm; nothing
	happens if it is already gone or the flag is off.
]]
function InjuryService.Tear(player: Player, arm: Injury.Arm)
	if not InjuryService.Enabled() then
		return
	end
	local before = InjuryService.Get(player)
	if Injury.missing(before, arm) then
		return
	end
	cancelHeal(player, nil)
	local character = player.Character
	local part = character and character:FindFirstChild(ARMS[arm]) :: BasePart?
	-- every client builds the falling arm from this, before the arm is hidden
	NetService.FireAll("Fx", "ArmTorn", {
		userId = player.UserId,
		arm = arm,
		cframe = if part then part.CFrame else nil,
	})
	local state = Injury.tear(before, arm, now(), Registry.CrewService.IsAboard(player))
	set(player, state)
	wasAboard[player] = Registry.CrewService.IsAboard(player)
	if Injury.armless(state) then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			`No arms left. Get back aboard within {Config.ReturnSeconds}s. A crewmate's Tonic or the crew chest can help.`
		)
	else
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			"You lost an arm. You carry less; a Tonic brings it back."
		)
	end
end

-- Whether `player` may start a heal on `patient` now, with the reason when not.
local function canHeal(patient: Player, source: "Self" | "Ally" | "Chest"): (boolean, string?)
	local state = InjuryService.Get(patient)
	if Injury.count(state) == 0 then
		return false, "Nothing to heal."
	end
	if heals[patient] then
		return false, "Already being treated."
	end
	if not Registry.CrewService.IsAlive(patient) or Registry.HollowService.IsHeld(patient) then
		return false, nil
	end
	if source == "Self" and Injury.armless(state) then
		return false, "With no arms you need a crewmate or the crew chest."
	end
	if source == "Chest" and not Injury.armless(state) then
		return false, "Take a Tonic from the chest and use it yourself."
	end
	return true, nil
end

local function begin(patient: Player, provider: Player?, source: "Self" | "Ally" | "Chest")
	local ok, why = canHeal(patient, source)
	if not ok then
		if why then
			NetService.Fire("Notify", provider or patient, "Warning", why)
		end
		return
	end
	if source == "Ally" and provider and heals[provider] and heals[provider].provider == provider then
		return
	end
	if source == "Chest" and not table.find(Registry.TrainService.ChestItems(), Config.HealItem) then
		NetService.Fire("Notify", patient, "Warning", "No Tonic in the crew chest.")
		return
	end
	if
		(source == "Self" or source == "Ally")
		and provider
		and not Registry.InventoryService.Has(provider, Config.HealItem)
	then
		return
	end
	heals[patient] = {
		patient = patient,
		provider = provider,
		source = source,
		doneAt = now() + Config.HealSeconds,
	}
	publish(patient)
end

-- A one-armed crew member used a Tonic from their backpack (InventoryService.Use).
function InjuryService.BeginSelfHeal(player: Player)
	begin(player, player, "Self")
end

function InjuryService.NeedsArm(player: Player): boolean
	return InjuryService.Enabled() and Injury.count(InjuryService.Get(player)) > 0
end

local function complete(heal: Heal)
	local patient = heal.patient
	heals[patient] = nil
	local spent = false
	if heal.source == "Chest" then
		spent = Registry.TrainService.ChestUse(Config.HealItem)
	elseif heal.provider then
		spent = Registry.InventoryService.Consume(heal.provider, Config.HealItem)
	end
	if not spent then
		publish(patient)
		NetService.Fire("Notify", patient, "Warning", "The Tonic was gone.")
		return
	end
	local humanoid = humanoidOf(patient)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Tuning.Tools.TonicHeal)
	end
	local arm = Injury.nextRestore(InjuryService.Get(patient))
	set(patient, Injury.restore(InjuryService.Get(patient)))
	NetService.FireAll("Fx", "ArmRestored", { userId = patient.UserId, arm = arm })
	NetService.Fire("Fx", patient, "Heal", {})
	NetService.Fire("Notify", patient, "Crew", "Your arm grows back.")
end

-- One step of a heal: interrupted, still going, or done.
local function stepHeal(heal: Heal, t: number)
	local patient = heal.patient
	local provider = heal.provider
	if patient.Parent == nil or not Registry.CrewService.IsAlive(patient) then
		cancelHeal(patient, nil)
		return
	end
	if Registry.HollowService.IsHeld(patient) then
		cancelHeal(patient, "Treatment interrupted.")
		return
	end
	if provider and provider ~= patient then
		local a, b = root(provider), root(patient)
		if
			provider.Parent == nil
			or not Registry.CrewService.IsAlive(provider)
			or Registry.HollowService.IsHeld(provider)
			or a == nil
			or b == nil
			or (a.Position - b.Position).Magnitude > Config.HealReach
		then
			cancelHeal(patient, "Treatment interrupted.")
			return
		end
	end
	if heal.source == "Chest" and not Registry.CrewService.IsAboard(patient) then
		cancelHeal(patient, "Treatment interrupted.")
		return
	end
	if t >= heal.doneAt then
		complete(heal)
	end
end

local function makePrompt(parent: Instance, objectText: string, actionText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.HealReach
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Action", "Treat")
	prompt.Parent = parent
	return prompt
end

-- "Give Tonic" on every injured crew member; triggered by a crewmate carrying one.
local function syncPrompts()
	local wanted: { [Model]: Player } = {}
	if InjuryService.Enabled() then
		for player, state in injuries do
			local character = player.Character
			if character and Injury.count(state) > 0 and Registry.CrewService.IsAlive(player) then
				wanted[character] = player
			end
		end
	end
	for character, prompt in prompts do
		if not wanted[character] then
			prompt:Destroy()
			prompts[character] = nil
		end
	end
	for character, patient in wanted do
		if not prompts[character] then
			local part = character:FindFirstChild("HumanoidRootPart")
			if part then
				local prompt = makePrompt(part, patient.DisplayName, "Give Tonic")
				prompt.Triggered:Connect(function(ally)
					if
						ally ~= patient
						and Registry.CrewService.IsAlive(ally)
						and InjuryService.CanUseItems(ally)
					then
						if not Registry.InventoryService.Has(ally, Config.HealItem) then
							NetService.Fire("Notify", ally, "Warning", "You need a Tonic.")
							return
						end
						begin(patient, ally, "Ally")
					end
				end)
				prompts[character] = prompt
			end
		end
	end
	local chest = Registry.TrainService.ChestPart()
	if InjuryService.Enabled() and chest and chestPrompt == nil then
		chestPrompt = makePrompt(chest, "Crew chest", "Treat wounds");
		(chestPrompt :: ProximityPrompt).Triggered:Connect(function(player)
			if Registry.CrewService.IsAboard(player) then
				begin(player, nil, "Chest")
			end
		end)
	elseif (not InjuryService.Enabled() or chest == nil) and chestPrompt then
		chestPrompt:Destroy()
		chestPrompt = nil
	end
end

local function clearAll()
	for player in heals do
		cancelHeal(player, nil)
	end
	for player in injuries do
		injuries[player] = nil
		publish(player)
		Registry.InventoryService.Refit(player)
	end
	table.clear(wasAboard)
end

local function step()
	ReplicatedStorage:SetAttribute("LimbLoss", InjuryService.Enabled())
	local phase = Registry.RunDirector.Phase()
	if not RunRules.isRunPhase(phase) or not InjuryService.Enabled() then
		if next(injuries) or next(heals) then
			clearAll()
		end
		syncPrompts()
		return
	end
	local t = now()
	for _, heal in table.clone(heals) do
		stepHeal(heal, t)
	end
	for player, state in table.clone(injuries) do
		if player.Parent == nil then
			injuries[player] = nil
			wasAboard[player] = nil
		elseif Registry.CrewService.IsAlive(player) then
			local aboard = Registry.CrewService.IsAboard(player)
			local nextState = state
			if aboard then
				nextState = Injury.board(nextState)
			elseif wasAboard[player] then
				nextState = Injury.leave(nextState, t)
			end
			wasAboard[player] = aboard
			if nextState ~= state then
				injuries[player] = nextState
				publish(player)
			end
			if
				Injury.expired(nextState, t)
				and not Registry.DevService.IsGod(player)
				and heals[player] == nil
			then
				local humanoid = humanoidOf(player)
				if humanoid and humanoid.Health > 0 then
					Registry.CrewService.TagDamage(player.Character :: Model, "Hollow")
					humanoid.Health = 0
					NetService.FireAll("Notify", "Crew", `{player.DisplayName} did not make it back.`)
				end
			end
		end
	end
	syncPrompts()
end

function InjuryService.Init() end

function InjuryService.Start()
	Players.PlayerRemoving:Connect(function(player)
		cancelHeal(player, nil)
		for _, heal in table.clone(heals) do
			if heal.provider == player then
				cancelHeal(heal.patient, "Treatment interrupted.")
			end
		end
		injuries[player] = nil
		wasAboard[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(publish, player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.defer(publish, player)
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.1)
			Safe.call("InjuryService.step", step)
		end
	end)
end

-- Dev (Studio only): flip the flag for a playtest.
function InjuryService.DevToggle(): boolean
	local on = not (ReplicatedStorage:GetAttribute("LimbLossDev") == true)
	ReplicatedStorage:SetAttribute("LimbLossDev", on)
	return on
end

-- Dev (Studio only): tear an arm without a rescue, to look at the rest.
function InjuryService.DevTear(player: Player)
	local arm = Injury.targetArm(InjuryService.Get(player), 1)
	if arm then
		InjuryService.Tear(player, arm :: Injury.Arm)
	end
end

return InjuryService
