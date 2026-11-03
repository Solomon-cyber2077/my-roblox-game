--!strict
--[[
	The frame sample behind the client health report (Controllers/HealthController). Pure: the
	controller feeds it frame times and takes one window's numbers per report.
]]

local ClientHealth = {}

export type Sampler = {
	seconds: number, -- this window
	frames: number,
	second: number, -- the whole second being counted
	secondFrames: number,
	lowest: number?, -- worst whole second so far, in frames a second
}

function ClientHealth.new(): Sampler
	return { seconds = 0, frames = 0, second = 0, secondFrames = 0, lowest = nil }
end

function ClientHealth.reset(sampler: Sampler)
	sampler.seconds = 0
	sampler.frames = 0
	sampler.second = 0
	sampler.secondFrames = 0
	sampler.lowest = nil
end

function ClientHealth.frame(sampler: Sampler, dt: number)
	sampler.seconds += dt
	sampler.frames += 1
	sampler.second += dt
	sampler.secondFrames += 1
	if sampler.second >= 1 then
		local rate = sampler.secondFrames / sampler.second
		local lowest = sampler.lowest
		sampler.lowest = if lowest then math.min(lowest, rate) else rate
		sampler.second = 0
		sampler.secondFrames = 0
	end
end

-- The window's average and worst second, then a fresh window; nil when it is shorter than
-- `minSeconds` (too little to mean anything).
function ClientHealth.take(sampler: Sampler, minSeconds: number): (number?, number?)
	if sampler.seconds < minSeconds then
		return nil, nil
	end
	local average = sampler.frames / sampler.seconds
	local lowest = sampler.lowest or average
	ClientHealth.reset(sampler)
	return average, lowest
end

return ClientHealth
