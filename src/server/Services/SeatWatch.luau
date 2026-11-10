--!strict
--[[
	Walk-on seats for the hall (LobbyService) and the train (TrainService); a helper, not a service.
	Step up onto a seat and you sit; brushing past does nothing (Logic/SeatStep); jump to stand.
	Many seats are invisible pads over their chair or bench that feet on the cushion never touch,
	so a Touched event cannot tell; instead, POLL times a second, a short ray down under each player
	finds what they stand on, and a free seat whose footprint holds that spot takes them. After
	someone stands, a seat waits `retouch` seconds before it takes anyone, so jumping off does not
	drop you straight back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SeatStep = require(ReplicatedStorage.Shared.Logic.SeatStep)
local Safe = require(ReplicatedStorage.Shared.Util.Safe)

local SeatWatch = {}

local POLL = 5 -- times a second
local NEAR = 4 -- studs: only seats this close to the spot are tested

function SeatWatch.watch(label: string, seats: { Seat }, retouch: number)
	local freeAt: { [Seat]: number } = {}
	for _, seat in seats do
		freeAt[seat] = 0
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant == nil then
				freeAt[seat] = os.clock() + retouch
			end
		end)
	end
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude
	local function check(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			humanoid == nil
			or root == nil
			or humanoid.Health <= 0
			or humanoid.Sit
			or root.Anchored
			or humanoid.FloorMaterial == Enum.Material.Air
		then
			return
		end
		down.FilterDescendantsInstances = { character :: Model }
		local reach = root.Size.Y / 2 + SeatStep.legs(humanoid) + 1.5
		local hit = Workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), down)
		if hit == nil then
			return
		end
		local now = os.clock()
		for _, seat in seats do
			if
				seat.Parent ~= nil
				and seat.Occupant == nil
				and now >= freeAt[seat]
				and (seat.Position - hit.Position).Magnitude < NEAR
			then
				local f, size = seat.CFrame:PointToObjectSpace(hit.Position), seat.Size
				if SeatStep.onCushion(f.X, f.Y, f.Z, size.X, size.Y, size.Z) then
					seat:Sit(humanoid)
					return
				end
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(1 / POLL)
			for _, player in Players:GetPlayers() do
				Safe.call(label, check, player)
			end
		end
	end)
end

return SeatWatch
