--!strict
--[[
	Life over the landscape: flocks of crows wheeling above the fields.

	Flocks live in land coordinates like everything else, so they drift past
	with the scenery; when one falls far behind the train it is re-seeded
	ahead. Each crow is a body and two wings, all anchored, moved together with
	one BulkMoveTo per frame. Wings beat in bursts and the birds glide between.
]]

local Workspace = game:GetService("Workspace")

local World = require(script.Parent.World)

type Crow = {
	body: BasePart,
	left: BasePart,
	right: BasePart,
	phase: number,
	radius: number,
	height: number,
	turn: number, -- radians per second around the flock centre
	lift: number,
}

type Flock = { x: number, y: number, z: number, crows: { Crow } }

local Life = {}

local FLOCKS = 4
local CROWS = 7
local BEHIND = -1600 -- world x where a flock is re-seeded ahead
local AHEAD_MIN, AHEAD_MAX = 1800, 4200
local CROW = Color3.fromRGB(16, 14, 18)

local flocks: { Flock } = {}
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local rng = Random.new(4242)
local folder: Folder? = nil

local function part(size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Size = size
	p.Color = CROW
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function place(flock: Flock, odometer: number, ahead: number)
	flock.x = odometer + ahead
	flock.z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(90, 700)
	flock.y = rng:NextNumber(30, 85)
end

function Life.init(parent: Instance)
	local holder = Instance.new("Folder")
	holder.Name = "Life"
	holder.Parent = parent
	folder = holder
	local count = math.max(2, math.floor(CROWS * World.density + 0.5))
	for i = 1, FLOCKS do
		local flock: Flock = { x = 0, y = 0, z = 0, crows = {} }
		place(flock, 0, rng:NextNumber(-800, AHEAD_MAX))
		for _ = 1, count do
			local scale = rng:NextNumber(0.85, 1.15)
			table.insert(flock.crows, {
				body = part(Vector3.new(0.9, 0.7, 2.0) * scale),
				left = part(Vector3.new(2.6, 0.12, 1.1) * scale),
				right = part(Vector3.new(2.6, 0.12, 1.1) * scale),
				phase = rng:NextNumber(0, math.pi * 2),
				radius = rng:NextNumber(14, 42),
				height = rng:NextNumber(-6, 6),
				turn = rng:NextNumber(0.35, 0.7) * (if i % 2 == 0 then 1 else -1),
				lift = rng:NextNumber(0, 10),
			})
		end
		table.insert(flocks, flock)
	end
end

function Life.update(odometer: number, _dt: number, clock: number)
	table.clear(parts)
	table.clear(frames)
	for _, flock in flocks do
		if flock.x - odometer < BEHIND then
			place(flock, odometer, rng:NextNumber(AHEAD_MIN, AHEAD_MAX))
		end
		local cx, cy, cz = flock.x - odometer, flock.y, flock.z
		for _, crow in flock.crows do
			local a = crow.phase + clock * crow.turn
			local bob = math.sin(clock * 0.8 + crow.phase) * 2.5
			local position = Vector3.new(
				cx + math.cos(a) * crow.radius,
				cy + crow.height + bob,
				cz + math.sin(a) * crow.radius
			)
			-- the tangent of the circle is the heading
			local heading = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(crow.turn)
			local bank = math.rad(18) * math.sign(crow.turn)
			local body = CFrame.lookAt(position, position + heading) * CFrame.Angles(0, 0, bank)
			-- beat in bursts, glide in between
			local burst = math.max(0, math.sin(clock * 0.9 + crow.lift))
			local flap = math.sin(clock * 11 + crow.phase) * 0.55 * burst + 0.12
			table.insert(parts, crow.body)
			table.insert(frames, body)
			table.insert(parts, crow.left)
			table.insert(frames, body * CFrame.Angles(0, 0, flap) * CFrame.new(-1.3, 0, 0.1))
			table.insert(parts, crow.right)
			table.insert(frames, body * CFrame.Angles(0, 0, -flap) * CFrame.new(1.3, 0, 0.1))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return Life
