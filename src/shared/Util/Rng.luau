--!strict
--[[
	Deterministic 32-bit random number generator (Mulberry32) plus helpers.

	Every random decision that must agree between server, client and tests
	(route options, station layouts, loot rolls, hazard schedules) draws from an
	Rng seeded from the run seed. The math is pure bit32, so the Lune test runner
	produces exactly the sequence the game produces.
]]

local MASK = 0xFFFFFFFF

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { _seed: number, _state: number }, Rng))
export type Weighted<T> = { weight: number, value: T }

-- 32-bit integer multiply without losing precision in double arithmetic.
local function imul(a: number, b: number): number
	local aHi, aLo = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	local bHi, bLo = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
	local mid = bit32.band(aHi * bLo + aLo * bHi, 0xFFFF)
	return bit32.band(aLo * bLo + bit32.lshift(mid, 16), MASK)
end

local function normalize(seed: number): number
	return bit32.band(math.floor(seed) % 4294967296, MASK)
end

--[[
	Mixes a seed with any number of salts (strings or numbers) into a new seed.
	Used to give each subsystem its own independent stream: Rng.derive(runSeed, "loot", 3).
]]
function Rng.derive(seed: number, ...: string | number): number
	local h = bit32.bxor(2166136261, normalize(seed))
	h = imul(h, 16777619)
	for i = 1, select("#", ...) do
		local salt = tostring((select(i, ...)))
		for c = 1, #salt do
			h = imul(bit32.bxor(h, string.byte(salt, c)), 16777619)
		end
		h = imul(bit32.bxor(h, 0x9E), 16777619)
	end
	return h
end

function Rng.new(seed: number): Rng
	local s = normalize(seed)
	return setmetatable({ _seed = s, _state = s }, Rng)
end

function Rng.nextUint32(self: Rng): number
	local s = bit32.band(self._state + 0x6D2B79F5, MASK)
	self._state = s
	local t = imul(bit32.bxor(s, bit32.rshift(s, 15)), bit32.bor(s, 1))
	t = bit32.bxor(t, bit32.band(t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61)), MASK))
	return bit32.bxor(t, bit32.rshift(t, 14))
end

-- Uniform float in [0, 1).
function Rng.next(self: Rng): number
	return self:nextUint32() / 4294967296
end

-- Uniform integer in [lo, hi], inclusive.
function Rng.int(self: Rng, lo: number, hi: number): number
	return lo + math.floor(self:next() * (hi - lo + 1))
end

-- Uniform float in [lo, hi).
function Rng.range(self: Rng, lo: number, hi: number): number
	return lo + self:next() * (hi - lo)
end

function Rng.chance(self: Rng, p: number): boolean
	return self:next() < p
end

function Rng.sign(self: Rng): number
	return if self:next() < 0.5 then -1 else 1
end

function Rng.pick<T>(self: Rng, list: { T }): T
	assert(#list > 0, "Rng.pick on an empty list")
	return list[self:int(1, #list)]
end

function Rng.weighted<T>(self: Rng, entries: { Weighted<T> }): T
	local total = 0
	for _, entry in entries do
		total += math.max(entry.weight, 0)
	end
	assert(total > 0, "Rng.weighted needs a positive total weight")
	local roll = self:next() * total
	for _, entry in entries do
		roll -= math.max(entry.weight, 0)
		if roll < 0 then
			return entry.value
		end
	end
	return entries[#entries].value
end

-- In-place Fisher-Yates shuffle. Returns the same list for chaining.
function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- A child stream that depends only on this stream's seed and the salt, never on
-- how many numbers have been drawn, so adding a roll elsewhere cannot shift it.
function Rng.fork(self: Rng, ...: string | number): Rng
	return Rng.new(Rng.derive(self._seed, ...))
end

function Rng.seed(self: Rng): number
	return self._seed
end

return table.freeze(Rng)
