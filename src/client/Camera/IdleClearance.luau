--!strict
--[[
	Clearance for the lobby idle view (docs/direction/2026-10-23_lobby-idle-final.md, prompt 3).
	Not booted: the idle camera (prompt 4) owns one of these and asks it each frame where the
	view may sit. CameraController's train wallPull is untouched.

	What counts as geometry: every part with CanQuery on, collidable or not and whatever its
	Transparency, so the train's invisible collision walls and the hall's decorative props both
	block. MeshParts are tested through their collision fidelity, so a coarse box proxy blocks
	early and a mesh with no proxy blocks only where its collision geometry is. Our own character
	is ignored; other characters are obstacles (one walking past pulls the view in or cancels it).
	Geometry that is not loaded (streamed out) or has CanQuery off cannot be seen: this is a
	bounded check, not a guarantee that nothing ever clips.

	The probe is a sphere around the camera that holds the near plane's four corners for the
	current FOV and viewport, plus Tuning.LobbyIdle.ClearanceMargin. Each query checks the probe
	at the focus (a cast misses what its start already touches), casts it out from the focus,
	then sweeps it from the last accepted pose to the new one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CameraClearance = require(Shared.Logic.CameraClearance)
local Tuning = require(Shared.Config.Tuning)

local IDLE = Tuning.LobbyIdle
local EPSILON = 1e-3

local IdleClearance = {}

export type Result = CameraClearance.Result

export type Clearance = {
	Query: (
		self: Clearance,
		camera: Camera,
		focus: Vector3,
		direction: Vector3,
		desired: number,
		dt: number
	) -> Result,
	Reset: (self: Clearance) -> (),
}

function IdleClearance.new(): Clearance
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.RespectCanCollide = false
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.RespectCanCollide = false

	local previousDistance: number? = nil
	local previousPosition: Vector3? = nil

	local clearance = {} :: Clearance

	function clearance:Reset()
		previousDistance = nil
		previousPosition = nil
	end

	function clearance:Query(camera, focus, direction, desired, dt): Result
		local viewport = camera.ViewportSize
		if viewport.Y < 1 or direction.Magnitude < EPSILON or not (dt >= 0) then
			self:Reset()
			return { ok = false, reason = "invalid" }
		end
		local radius = CameraClearance.probeRadius(
			camera.FieldOfView,
			viewport.X / viewport.Y,
			math.abs(camera.NearPlaneZ),
			IDLE.ClearanceMargin
		)
		if radius == nil then
			self:Reset()
			return { ok = false, reason = "invalid" }
		end

		local exclude: { Instance } = {}
		local character = Players.LocalPlayer.Character
		if character then
			table.insert(exclude, character)
		end
		castParams.FilterDescendantsInstances = exclude
		overlapParams.FilterDescendantsInstances = exclude

		local unit = direction.Unit
		local overlap = #Workspace:GetPartBoundsInRadius(focus, radius, overlapParams) > 0
		local hit = if overlap then nil else Workspace:Spherecast(focus, radius, unit * desired, castParams)
		local result = CameraClearance.resolve({
			desired = desired,
			minDistance = IDLE.ClearanceMinDistance,
			hitDistance = hit and hit.Distance,
			overlap = overlap,
			sweepBlocked = false,
			previous = previousDistance,
			maxOut = IDLE.ClearanceEaseOut * dt,
		})
		if result.ok then
			local candidate = focus + unit * result.distance
			local from = previousPosition
			if from then
				local step = candidate - from
				if step.Magnitude > EPSILON and Workspace:Spherecast(from, radius, step, castParams) then
					result = CameraClearance.resolve({
						desired = desired,
						minDistance = IDLE.ClearanceMinDistance,
						overlap = false,
						sweepBlocked = true,
						maxOut = 0,
					})
				end
			end
			if result.ok then
				previousDistance = result.distance
				previousPosition = candidate
				return result
			end
		end
		self:Reset()
		return result
	end

	return clearance
end

return IdleClearance
