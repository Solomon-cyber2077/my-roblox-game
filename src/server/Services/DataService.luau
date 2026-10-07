--!strict
--[[
	Player profiles with session locking.

	A profile is loaded with UpdateAsync, which stamps a lock { job, time }.
	Another server that finds a fresh lock retries with backoff, and takes the
	profile over only after the lock is older than LockTimeoutSeconds. Saves
	run every AutosaveSeconds, on leave (releasing the lock) and on shutdown.

	When DataStores are unavailable (an unpublished Studio place, an outage),
	the player gets an in-memory profile and the UI shows "Progress not saved".
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Difficulty = require(Shared.Config.Difficulty)
local Progression = require(Shared.Config.Progression)
local Tuning = require(Shared.Config.Tuning)
local Rank = require(Shared.Logic.Rank)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local StateService = require(script.Parent.StateService)

type Profile = Types.Profile
type Session = { profile: Profile, online: boolean, dirty: boolean, released: boolean }

local SCHEMA_VERSION = 1

local DataService = {
	ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>,
	ProfileChanged = Signal.new() :: Signal.Signal<Player, Profile>,
}

local store: DataStore? = nil
local sessions: { [Player]: Session } = {}

local function defaultProfile(): Profile
	local equipped: { [string]: string } = table.clone(Cosmetics.Defaults)
	local stats: { [string]: number } = {}
	for _, name in Progression.Stats do
		stats[name] = 0
	end
	return {
		version = SCHEMA_VERSION,
		brass = 0,
		xp = 0,
		unlockedTier = Difficulty.RunTier.Default,
		owned = {},
		equipped = equipped,
		milestones = {},
		stats = stats,
		daily = { lastBonusDay = 0, charterBrassDay = 0, charterBrass = 0 },
		receipts = {},
		settings = {},
	}
end

-- Fills fields added after a profile was first saved, and runs version migrations.
local function reconcile(data: any): Profile
	local base: { [string]: any } = defaultProfile() :: any
	if type(data) ~= "table" then
		return base :: any
	end
	for key, value in base do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			local defaults: { [any]: any } = value
			for subKey, subValue in defaults do
				if data[key][subKey] == nil then
					data[key][subKey] = subValue
				end
			end
		end
	end
	data.version = SCHEMA_VERSION
	return data :: Profile
end

local function publish(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	local profile = session.profile
	StateService.SetPrivate(player, { "profile" }, {
		brass = profile.brass,
		xp = profile.xp,
		rank = Rank.fromXp(profile.xp),
		unlockedTier = profile.unlockedTier,
		owned = profile.owned,
		equipped = profile.equipped,
		milestones = profile.milestones,
		stats = profile.stats,
		saving = if session.online then "Online" else "Offline",
	})
end

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

local function tryLoad(player: Player): (Profile?, boolean)
	if store == nil then
		return nil, false
	end
	local now = os.time()
	for attempt = 1, Tuning.Data.LoadRetries do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
				local data = if type(old) == "table" then old else { profile = nil, lock = nil }
				local lock = data.lock
				if
					lock
					and lock.job ~= game.JobId
					and now - (lock.time or 0) < Tuning.Data.LockTimeoutSeconds
					and attempt < Tuning.Data.LoadRetries
				then
					lockedElsewhere = true
					return nil -- cancel the write and retry
				end
				data.lock = { job = game.JobId, time = now }
				return data
			end)
		end)
		if not ok then
			warn(`[DataService] load failed for {player.Name}: {result}`)
			return nil, false
		end
		if not lockedElsewhere then
			local data = result :: any
			return reconcile(data and data.profile), true
		end
		task.wait(2 ^ attempt)
	end
	return nil, false
end

local function save(player: Player, release: boolean): boolean
	local session = sessions[player]
	if session == nil or not session.online or store == nil then
		return false
	end
	local profile = session.profile
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
			local data = if type(old) == "table" then old else {}
			if data.lock and data.lock.job ~= game.JobId then
				return nil -- another server owns this profile now; never overwrite it
			end
			data.profile = profile
			data.lock = if release then nil else { job = game.JobId, time = os.time() }
			return data
		end)
	end)
	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
		return false
	end
	session.dirty = false
	return true
end

local function onPlayerAdded(player: Player)
	local profile, online = tryLoad(player)
	if player.Parent == nil then
		return
	end
	local session: Session =
		{ profile = profile or defaultProfile(), online = online, dirty = false, released = false }
	sessions[player] = session
	publish(player)
	DataService.ProfileLoaded:Fire(player, session.profile)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session and not session.released then
		session.released = true
		save(player, true)
	end
	sessions[player] = nil
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Tuning.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable; profiles will not be saved this session")
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Tuning.Data.AutosaveSeconds)
			for player, session in sessions do
				if session.dirty then
					task.spawn(save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			if not session.released then
				session.released = true
				pending += 1
				task.spawn(function()
					save(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.GetProfile(player: Player): Profile?
	local session = sessions[player]
	return if session then session.profile else nil
end

function DataService.WaitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while sessions[player] == nil and player.Parent ~= nil and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.GetProfile(player)
end

function DataService.IsOnline(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.online
end

-- The only way to change a profile. The mutator edits the profile in place.
function DataService.Update(player: Player, mutator: (Profile) -> ())
	local session = sessions[player]
	if session == nil then
		return
	end
	mutator(session.profile)
	session.dirty = true
	publish(player)
	DataService.ProfileChanged:Fire(player, session.profile)
end

-- Immediate save, used after a Robux purchase is granted.
function DataService.SaveNow(player: Player): boolean
	return save(player, false)
end

function DataService.UnlockedTier(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then profile.unlockedTier else Difficulty.RunTier.Default
end

function DataService.Rank(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then Rank.fromXp(profile.xp) else 1
end

return DataService
