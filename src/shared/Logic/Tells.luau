--!strict
--[[
	A stalking Hollow's tells on the local player's side (docs/FINAL-DESIGN.md Prompt 2). Pure: the
	client feeds replicated Hollow states and positions; this module says how far the lantern's light
	leans and which way, how much it flickers, whether the pocket watch stutters and how loud a
	Hollow's stalk breath is. Thresholds use the fixed r = Tuning.Stalk.ReferenceRadius (30), never
	the Visibility slider, so every player's cues start at the same distance.

	  lean, flicker   a stalking or coiling Hollow within r: the light leans away, up to LeanDegrees,
	                  and dims by at most FlickerMax (never under the readability floor: only the
	                  brightness moves, not the light's reach)
	  stutter         one within 1.2r: the watch's needle stutters
	  breath          its breath, full at 0.5r, gone at 1.0r
	  fade            every tell eases toward its target; leaving range clears it within
	                  TellClearSeconds
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

local S = Tuning.Stalk

local Tells = {}

export type Source = {
	x: number,
	z: number,
	state: string,
	coil: boolean, -- a guarded hunter's warning coil (the WarningCoil attribute)
}

export type Look = {
	strength: number, -- 0..1: how near the nearest stalker is, inside r
	leanX: number, -- unit direction the light leans (away from the stalker), flat
	leanZ: number,
	flicker: number, -- 0..FlickerMax: the share taken off the lantern's brightness
	stutter: boolean,
	breath: number, -- 0..1, for that Hollow's breath
}

local function stalking(source: Source): boolean
	return source.state == "Stalk" or (source.state == "Hunt" and source.coil)
end

-- Breath volume at `distance`: 1 inside 0.5r, 0 beyond 1.0r, linear between.
function Tells.breath(distance: number): number
	local near, far = S.BreathNear * S.ReferenceRadius, S.BreathFar * S.ReferenceRadius
	if distance <= near then
		return 1
	elseif distance >= far then
		return 0
	end
	return 1 - (distance - near) / (far - near)
end

-- The tells for a player at (x, z), at time `t` (seconds; drives the flicker's phase).
function Tells.compute(x: number, z: number, sources: { Source }, t: number): Look
	local nearest, nx, nz = math.huge, 0, 0
	for _, source in sources do
		if stalking(source) then
			local dx, dz = source.x - x, source.z - z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance < nearest then
				nearest, nx, nz = distance, dx, dz
			end
		end
	end
	local r = S.ReferenceRadius
	local look: Look = { strength = 0, leanX = 0, leanZ = 0, flicker = 0, stutter = false, breath = 0 }
	if nearest == math.huge then
		return look
	end
	look.stutter = nearest <= S.WatchRadius * r
	look.breath = Tells.breath(nearest)
	if nearest <= S.LeanRadius * r then
		look.strength = 1 - nearest / (S.LeanRadius * r)
		if nearest > 1e-6 then
			look.leanX, look.leanZ = -nx / nearest, -nz / nearest
		end
		-- an uneven gutter: two waves, never past FlickerMax
		local wave = 0.5 + 0.25 * math.sin(t * 17) + 0.25 * math.sin(t * 6.3 + 1.7)
		look.flicker = S.FlickerMax * look.strength * math.clamp(wave, 0, 1)
	end
	return look
end

-- Eases `current` toward `target` so a tell that ends clears within TellClearSeconds.
function Tells.fade(current: number, target: number, dt: number): number
	local rate = dt / S.TellClearSeconds
	if target > current then
		return math.min(target, current + rate * 4) -- arrives quickly
	end
	return math.max(target, current - rate)
end

return table.freeze(Tells)
