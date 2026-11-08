--!strict
--[[
	The Depot hall's passive people (Config/Passengers), run by the server. Each one is a real R6
	body (Builders/PassengerFigure) that walks the hall's spot graph with Humanoid:MoveTo, so it
	collides and takes up room like a person; Logic/Passenger decides what it does next:

	  wander  walk to another spot along the graph's links
	  sit     take a bench seat (never two on one bench, at most Walk.maxSitting at once),
	          approached from the spot in front of it, and stay a while
	  idle    stand about at the spot
	  greet   turn to the nearest Hand, wave and say the next of its three lines

	A greeting is told to clients through attributes on the rig: WaveAt (server time, read by
	CharacterAnimator) and Say/SayAt (shown as a bubble by PassengerController). With no Hand
	near the hall, everyone stands still. No passengers aboard or at stations yet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Passengers = require(Shared.Config.Passengers)
local Tuning = require(Shared.Config.Tuning)
local Passenger = require(Shared.Logic.Passenger)
local Rng = require(Shared.Util.Rng)
local Safe = require(Shared.Util.Safe)

local PassengerFigure = require(script.Parent.Parent.Builders.PassengerFigure)
local Registry = require(script.Parent.Parent.Registry)

type Person = {
	def: Passengers.Person,
	rig: Model,
	humanoid: Humanoid,
	root: BasePart,
	rng: Rng.Rng,
	spot: number,
	line: number,
	seat: Seat?,
	satAt: number,
	sitFor: number,
	greeted: { [number]: number }, -- user id -> os.clock() of the last greeting
	target: number?, -- the spot it is walking to (no one else picks it meanwhile)
}

local PassengerService = {}

local HALL = Passengers.Hall
local W = Passengers.Walk
local STEP = 24 -- studs per MoveTo (the engine gives up on one after 8 s)

local people: { Person } = {}
local lastGreet = -math.huge -- os.clock() of the hall's last greeting
local seats: { Seat } = {}
local origin = CFrame.new()

local function at(x: number, z: number): Vector3
	return (origin * CFrame.new(x, 0, z)).Position
end

local function spotAt(i: number): Vector3
	local s = HALL.spots[i]
	return at(s.x, s.z)
end

local function local2(position: Vector3): (number, number)
	local p = origin:PointToObjectSpace(position)
	return p.X, p.Z
end

-- Walks straight to `target` in steps the engine will finish; false if it gets stuck.
-- Someone else of ours within personal space of `p`, ahead along `heading` when one is given.
local function crowded(p: Person, heading: Vector3?): boolean
	for _, other in people do
		if other ~= p then
			local gap = other.root.Position - p.root.Position
			local flat = Vector3.new(gap.X, 0, gap.Z)
			if flat.Magnitude < W.personalSpace and (heading == nil or flat:Dot(heading) > 0) then
				return true
			end
		end
	end
	return false
end

local function walkTo(p: Person, target: Vector3): boolean
	while p.rig.Parent do
		local here = p.root.Position
		local flat = Vector3.new(target.X - here.X, 0, target.Z - here.Z)
		if flat.Magnitude < 1.5 then
			return true
		end
		local goal = if flat.Magnitude > STEP then here + flat.Unit * STEP else target
		local finished, reached = false, false
		local connection = p.humanoid.MoveToFinished:Connect(function(ok: boolean)
			finished, reached = true, ok
		end)
		p.humanoid:MoveTo(goal)
		local deadline = os.clock() + W.stepTimeout
		local waited = false -- one wait a step: people who stand in each other's way never wait forever
		while not finished and os.clock() < deadline and p.rig.Parent do
			task.wait(0.2)
			-- someone close ahead: stand and let them get on, then carry on (or go anyway after a while)
			local heading = Vector3.new(goal.X - p.root.Position.X, 0, goal.Z - p.root.Position.Z)
			if not waited and heading.Magnitude > 0.5 and crowded(p, heading.Unit) then
				waited = true
				p.humanoid:MoveTo(p.root.Position)
				local until_ = os.clock() + W.waitAhead
				while os.clock() < until_ and crowded(p, heading.Unit) and p.rig.Parent do
					task.wait(0.3)
				end
				deadline += W.waitAhead
				if crowded(p, heading.Unit) then
					-- still someone in the way (two meeting head-on): pass on the right, as people do
					local right = heading.Unit:Cross(Vector3.yAxis)
					p.humanoid:MoveTo(p.root.Position + right * W.sidestep)
					local aside = os.clock() + 1.2
					while os.clock() < aside and p.rig.Parent do
						task.wait(0.1)
					end
				end
				p.humanoid:MoveTo(goal)
			end
		end
		connection:Disconnect()
		if not reached then
			p.humanoid:MoveTo(p.root.Position) -- stop where it is
			return false
		end
	end
	return false
end

-- Along the links to spot `to`; the person's spot is wherever they got to.
local function walkRoute(p: Person, to: number)
	local path = Passenger.route(HALL.links, p.spot, to)
	if path == nil then
		return
	end
	for i = 2, #path do
		if not walkTo(p, spotAt(path[i])) then
			local x, z = local2(p.root.Position)
			p.spot = Passenger.nearest(HALL.spots, x, z)
			return
		end
		p.spot = path[i]
	end
end

local function sittingCount(): number
	local n = 0
	for _, other in people do
		if other.seat then
			n += 1
		end
	end
	return n
end

-- A free bench seat with nobody else of ours on its bench.
local function freeSeat(): Seat?
	local open: { Seat } = {}
	for _, seat in seats do
		if seat.Occupant ~= nil then
			continue
		end
		local busy = false
		for _, other in people do
			if other.seat and (other.seat.Position - seat.Position).Magnitude < 4 then
				busy = true
				break
			end
		end
		if not busy then
			table.insert(open, seat)
		end
	end
	return if #open > 0 then open[math.random(1, #open)] else nil
end

-- The nearest Hand's character within `radius` of `position`.
local function nearestHand(position: Vector3, radius: number): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, radius
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDistance then
				best, bestRoot, bestDistance = player, root, d
			end
		end
	end
	return best, bestRoot
end

local function sit(p: Person)
	local seat = freeSeat()
	if seat == nil then
		return
	end
	local front = seat.CFrame * CFrame.new(0, 0, -2.4)
	local fx, fz = local2(front.Position)
	local look = origin:VectorToObjectSpace(seat.CFrame.LookVector)
	local from = Passenger.approach(HALL.spots, fx, fz, look.X, look.Z)
	for _, other in people do
		if other ~= p and (other.spot == from or other.target == from) then
			return -- someone else of ours stands at or is making for that bench's spot
		end
	end
	p.target = from -- reserved like a wander's spot, so two of ours never make for one bench's spot
	walkRoute(p, from)
	p.target = nil
	if p.spot ~= from or seat.Occupant ~= nil then
		return
	end
	p.seat = seat -- claimed before the last steps so nobody else of ours picks its bench
	if not walkTo(p, front.Position) or seat.Occupant ~= nil then
		p.seat = nil
		walkTo(p, spotAt(from))
		return
	end
	seat:Sit(p.humanoid)
	p.satAt = os.clock()
	p.sitFor = p.rng:range(W.sit[1], W.sit[2])
end

local function stand(p: Person)
	p.humanoid.Sit = false
	p.humanoid.Jump = true
	p.seat = nil
	task.wait(0.6)
	walkTo(p, spotAt(p.spot))
end

local function greet(p: Person, player: Player, target: BasePart)
	local now = os.clock()
	p.greeted[player.UserId] = now
	lastGreet = now
	if p.seat == nil then
		-- turn to face them, a few steps of the turn so it reads as turning
		p.humanoid.AutoRotate = false
		local from = p.root.CFrame
		local flat = Vector3.new(target.Position.X, from.Position.Y, target.Position.Z)
		if (flat - from.Position).Magnitude > 0.5 then
			local to = CFrame.lookAt(from.Position, flat)
			for i = 1, 6 do
				p.root.CFrame = from:Lerp(to, i / 6)
				task.wait(0.05)
			end
		end
	end
	p.line = Passenger.nextLine(p.line, #p.def.lines)
	local serverNow = Workspace:GetServerTimeNow()
	p.rig:SetAttribute("WaveAt", serverNow)
	p.rig:SetAttribute("Say", p.def.lines[p.line])
	p.rig:SetAttribute("SayAt", serverNow)
	task.wait(W.waveSeconds + 1)
	p.humanoid.AutoRotate = true
end

local function step(p: Person)
	local _, nearHall = nearestHand(origin.Position, W.quietRadius)
	if nearHall == nil then
		task.wait(3)
		return
	end
	local player, target = nearestHand(p.root.Position, W.greetRadius)
	local last = player and p.greeted[player.UserId]
	local action = Passenger.choose(p.rng, {
		sitting = p.seat ~= nil,
		satFor = if p.seat then os.clock() - p.satAt else 0,
		seatFree = freeSeat() ~= nil,
		othersSitting = sittingCount(),
		handNear = player ~= nil,
		-- off this Hand's cooldown, nobody else speaking, and no one of ours at its elbow
		canGreet = player ~= nil
			and Passenger.offCooldown(os.clock(), last, W.greetCooldown)
			and Passenger.mayGreet(os.clock(), lastGreet, W.greetGap)
			and not crowded(p, nil),
	}, p.sitFor)
	if action == "greet" and player and target then
		greet(p, player, target)
	elseif action == "wander" then
		-- half the time somewhere a Hand at the spawn ring can see them; never a spot someone else of
		-- ours stands at or is heading for
		local taken: { [number]: boolean } = {}
		for _, other in people do
			if other ~= p then
				taken[other.spot] = true
				if other.target then
					taken[other.target] = true
				end
			end
		end
		local to = Passenger.pickSpot(p.rng, #HALL.spots, HALL.seen, taken)
		if to then
			p.target = to
			walkRoute(p, to)
			p.target = nil
		end
	elseif action == "sit" then
		sit(p)
	elseif action == "stand" then
		stand(p)
	else
		task.wait(p.rng:range(W.idle[1], W.idle[2]))
	end
end

function PassengerService.Init() end

function PassengerService.Start()
	task.spawn(function()
		local lobby = Registry.LobbyService
		local board = lobby and lobby.Board()
		if board == nil then
			return
		end
		local hall: Instance = board
		while hall.Parent and hall.Parent ~= Workspace do
			hall = hall.Parent
		end
		local o = Tuning.World.LobbyOrigin
		origin = CFrame.new(o[1], o[2], o[3])
		for _, d in hall:GetDescendants() do
			if d:IsA("Seat") and d:GetAttribute("SeatName") == HALL.seatName then
				table.insert(seats, d)
			end
		end
		local folder = Instance.new("Folder")
		folder.Name = "Passengers"
		folder.Parent = Workspace
		local rng = Rng.new(Rng.derive(os.time(), "Passengers"))
		local taken: { [number]: boolean } = {}
		for i = 1, math.min(HALL.count, #Passengers.People) do
			local def = Passengers.People[i]
			local spot = rng:int(1, #HALL.spots)
			while taken[spot] do
				spot = spot % #HALL.spots + 1
			end
			taken[spot] = true
			local s = HALL.spots[spot]
			local cf = origin * CFrame.new(s.x, 0, s.z) * CFrame.Angles(0, rng:range(0, math.pi * 2), 0)
			local rig = PassengerFigure.build(def, cf, folder)
			if rig == nil then
				continue
			end
			rig:SetAttribute("PerformanceKeep", i <= HALL.performance)
			local person: Person = {
				def = def,
				rig = rig,
				humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid,
				root = rig:FindFirstChild("HumanoidRootPart") :: BasePart,
				rng = Rng.new(Rng.derive(os.time(), "Passenger", i)),
				spot = spot,
				line = 0,
				seat = nil,
				satAt = 0,
				sitFor = 0,
				greeted = {},
			}
			table.insert(people, person)
			task.spawn(function()
				task.wait(person.rng:range(0, 3)) -- not all at once
				while rig.Parent do
					Safe.call("Passenger", step, person)
					task.wait(0.25)
				end
			end)
		end
	end)
end

-- How many are walking the hall (DevService, tests).
function PassengerService.Count(): number
	return #people
end

return PassengerService
