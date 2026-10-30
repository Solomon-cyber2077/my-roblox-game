--!strict
--[[
	Limb loss on the client (Config/Injury; the server's InjuryService and HollowService judge
	everything). Only presentation and input lives here:

	  the torn arm   on ArmTorn, every client builds a cosmetic copy of that arm (with the
	                 wearer's shirt) that swings out and falls; no collision, no queries, no
	                 touch, no gameplay meaning. At most Limbs.MaxPerClient at once (the oldest
	                 goes first), at rest by SettleSeconds, gone by RemoveSeconds.
	  pain, panic    the same moment (Config/Injury Tear, Logic/TearFeedback): a wet tear, a
	                 snap and the wearer's own cry; a dark burst at the shoulder and a brief drip
	                 from it, short of gore. The one who lost it gets the shock: the view whites
	                 out and floods dark from that side (UI/Trauma), the world goes dull under a
	                 ringing (AudioController.Shock), a racing heart, panting, a shake, a kick and a
	                 controller rumble. Crewmates nearby flinch with it. Camera Motion "Reduced"
	                 (or the system's reduced motion) keeps the camera still.
	  the rescue     the invited crew see who is going under; the one rescuer gets the three
	                 beats (Space / ButtonA / the PULL button) and sends each press with the
	                 server time they saw; the victim sees who is pulling.
	  the way back   with no arms off the train: the server-clock countdown and an arrow toward
	                 the train. The last WarningSeconds add posture and a subdued cue, no flashing.
	  treatment      while a Tonic works on you, how long is left.

	The missing arm itself is hidden by the server (its Transparency), so late joiners and
	respawns see the authoritative state without anything here.
]]

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Injury)
local Difficulty = require(Shared.Config.Difficulty)
local SkillCheck = require(Shared.Logic.SkillCheck)
local Registry = require(script.Parent.Parent.Registry)
local CrewPoses = require(script.Parent.Parent.Animation.CrewPoses)
local TearFeedback = require(Shared.Logic.TearFeedback)

local FrameTime = require(script.Parent.Parent.FrameTime)
local Net = require(script.Parent.Parent.Net)
local Overlay = require(script.Parent.Parent.UI.Overlay)
local Theme = require(script.Parent.Parent.UI.Theme)
local Trauma = require(script.Parent.Parent.UI.Trauma)
local Ui = require(script.Parent.Parent.UI.Ui)

local InjuryController = {}

local ACTION = "RescuePull"
local L = Config.Limbs

type Limb = { model: Model, bornAt: number }

local limbs: { Limb } = {}
local gui: ScreenGui
local rescuePanel: Frame
local rescueTitle: TextLabel
local rescueTrack: Frame
local rescueMarker: Frame
local rescueHint: TextLabel
local pullButton: TextButton
local notches: { Frame } = {}
local HINT = "PRESS ON EACH MARK"
local hintUntil = 0
local returnPanel: Frame
local returnText: TextLabel
local returnArrow: TextLabel
local healText: TextLabel

type Active = {
	id: number,
	startsAt: number,
	endsAt: number,
	beats: { number },
	pressed: { [number]: boolean },
}
local active: Active? = nil
type Motion = { arm: string?, torn: number?, restored: number?, died: number? }
local motions: { [Model]: Motion } = setmetatable({}, { __mode = "k" }) :: any
-- every client's view of the rescues in progress, for the pre-tear poses (id -> who and when)
type Pull = { victim: number, rescuer: number, startsAt: number, endsAt: number, beats: { number } }
local pulls: { [number]: Pull } = {}

-- 1 at a beat, falling away within a tenth of a second either side: the rescuer's tug
local function tugAt(pull: Pull, now: number): number
	local tug = 0
	for _, offset in pull.beats do
		local d = (now - (pull.startsAt + offset)) / 0.08
		tug = math.max(tug, math.exp(-d * d))
	end
	return tug
end

-- -1 or 1: which side of `from` (in its own frame) `to` is on
local function sideOf(from: Model, to: Model): number
	local a = from:FindFirstChild("HumanoidRootPart") :: BasePart?
	local b = to:FindFirstChild("HumanoidRootPart") :: BasePart?
	if a == nil or b == nil then
		return 1
	end
	return if a.CFrame:PointToObjectSpace(b.Position).X >= 0 then 1 else -1
end

-- The pre-tear choreography (CrewPoses.rescuePull / rescueReach) while a rescue runs.
local function pullPose(character: Model, base: CrewPoses.Pose, now: number): CrewPoses.Pose?
	local player = Players:GetPlayerFromCharacter(character)
	if player == nil then
		return nil
	end
	for id, pull in pulls do
		if now > pull.endsAt + 0.5 then
			pulls[id] = nil
		else
			local u = math.clamp((now - pull.startsAt) / math.max(pull.endsAt - pull.startsAt, 0.01), 0, 1)
			local victim = Players:GetPlayerByUserId(pull.victim)
			local rescuer = Players:GetPlayerByUserId(pull.rescuer)
			local other = if player.UserId == pull.victim
				then rescuer and rescuer.Character
				elseif player.UserId == pull.rescuer then victim and victim.Character
				else nil
			if other and player.UserId == pull.victim then
				return CrewPoses.rescueReach(base, sideOf(character, other), u)
			elseif other then
				return CrewPoses.rescuePull(base, sideOf(character, other), u, tugAt(pull, now))
			end
		end
	end
	return nil
end
local warningCharacter: Model? = nil
local warningDeadline: number? = nil
local nextWarning = 0

function InjuryController.Pose(character: Model, base: CrewPoses.Pose, now: number): CrewPoses.Pose
	if ReplicatedStorage:GetAttribute("LimbLoss") ~= true then
		motions[character] = nil
		return base
	end
	local pulled = if next(pulls) then pullPose(character, base, now) else nil
	if pulled then
		return pulled
	end
	local missing = character:GetAttribute("MissingArms")
	if typeof(missing) ~= "string" then
		return base
	end
	local motion: Motion = motions[character] or {}
	motions[character] = motion
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 and missing ~= "" then
		motion.died = motion.died or now
	end
	-- Keep grab/grasp contact targets intact until the server releases them.
	if character:GetAttribute("GrabStyle") ~= nil or character:GetAttribute("Grasp") ~= nil then
		return base
	end
	local deadline = character:GetAttribute("ReturnBy")
	local warning = if missing == "LR" and typeof(deadline) == "number"
		then math.clamp(1 - (deadline - now) / Config.WarningSeconds, 0, 1)
		else 0
	local healing = if typeof(character:GetAttribute("Healing")) == "number" then 1 else 0
	local p = Config.Presentation
	return CrewPoses.injured(
		base,
		missing,
		motion.arm,
		if motion.torn then (now - motion.torn) / p.RecoilSeconds else 0,
		if motion.restored then (now - motion.restored) / p.RegrowSeconds else 0,
		warning,
		healing,
		if motion.died then math.clamp((now - motion.died) / p.CollapseSeconds, 0, 1) else 0
	)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function nameOf(userId: number?): string
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	return if player then player.DisplayName else "A crewmate"
end

-- The torn arm --------------------------------------------------------------------------------

local function evict()
	while #limbs > L.MaxPerClient do
		local oldest = table.remove(limbs, 1) :: Limb
		oldest.model:Destroy()
	end
end

local function spawnLimb(userId: number, arm: string, from: CFrame?)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local name = if arm == "L" then "Left Arm" else "Right Arm"
	local source = character and character:FindFirstChild(name) :: BasePart?
	if character == nil or source == nil then
		return
	end
	-- a small rig of its own so the wearer's shirt still dresses the arm
	local model = Instance.new("Model")
	model.Name = "TornArm"
	local part = source:Clone()
	for _, child in part:GetChildren() do
		if not (child:IsA("Decal") or child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")) then
			child:Destroy()
		end
	end
	part.Transparency = 0
	part.LocalTransparencyModifier = 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = from or source.CFrame
	part.Parent = model
	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt then
		shirt:Clone().Parent = model
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors then
		colors:Clone().Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.EvaluateStateMachine = false
	humanoid.Parent = model
	model.PrimaryPart = part
	model.Parent = Workspace

	local entry = { model = model, bornAt = os.clock() }
	table.insert(limbs, entry)
	evict()

	-- away from the body on the arm's side, up a little, then down to the ground, tumbling
	local torso = character:FindFirstChild("Torso") :: BasePart?
	local start = part.CFrame
	local side = if torso
		then (if arm == "L" then -torso.CFrame.RightVector else torso.CFrame.RightVector)
		else start.RightVector
	local velocity = side * 9 + Vector3.yAxis * 7
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, character }
	local floor = Workspace:Raycast(start.Position, Vector3.new(0, -40, 0), params)
	local floorY = if floor then floor.Position.Y + part.Size.X / 2 else start.Position.Y - 3
	local spin = Vector3.new(if arm == "L" then 7 else -7, 2, 5)
	local t = 0
	local resting = false
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		if model.Parent == nil then
			(connection :: RBXScriptConnection):Disconnect()
			return
		end
		local age = os.clock() - entry.bornAt
		if not resting then
			t += dt
			local position = start.Position
				+ velocity * t
				+ Vector3.new(0, -Workspace.Gravity * 0.5 * t * t, 0)
			local turn = CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
			if position.Y <= floorY or age >= L.SettleSeconds then
				-- lie on the ground on its side
				local yaw = select(2, (start.Rotation * turn):ToEulerAnglesYXZ())
				part.CFrame = CFrame.new(position.X, floorY, position.Z)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(0, 0, math.rad(90))
				resting = true
			else
				part.CFrame = CFrame.new(position) * start.Rotation * turn
			end
		end
		local fadeFrom = L.RemoveSeconds - 1.5
		if age >= fadeFrom then
			part.Transparency = math.clamp((age - fadeFrom) / 1.5, 0, 1)
		end
		if age >= L.RemoveSeconds then
			(connection :: RBXScriptConnection):Disconnect()
			local index = table.find(limbs, entry)
			if index then
				table.remove(limbs, index)
			end
			model:Destroy()
		end
	end)
end

-- Pain and panic -----------------------------------------------------------------------------

local TEAR = Config.Tear
local PAIN_CRIES = { "PainCry1", "PainCry2", "PainCry3" }
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BLOOD = Color3.fromRGB(70, 6, 9) -- dark, dried rather than bright (as UI/Trauma's veins)
local GRIT = Color3.fromRGB(58, 44, 36) -- torn cloth and dust

local function reducedMotion(): boolean
	return Players.LocalPlayer:GetAttribute("Motion") == "Reduced" or GuiService.ReducedMotionEnabled
end

local function play(cue: string, position: Vector3?, gain: number?, pitch: number?)
	local audio = Registry.AudioController
	if audio then
		audio.Play(cue, position, gain, pitch)
	end
end

-- A controller's rumble, when the input in use is a gamepad that has one.
local function rumble(strength: number, seconds: number)
	local input = UserInputService:GetLastInputType()
	if input.Name:sub(1, 7) ~= "Gamepad" then
		return
	end
	pcall(function()
		if HapticService:IsMotorSupported(input, Enum.VibrationMotor.Large) then
			HapticService:SetMotor(input, Enum.VibrationMotor.Large, strength)
		end
		if HapticService:IsMotorSupported(input, Enum.VibrationMotor.Small) then
			HapticService:SetMotor(input, Enum.VibrationMotor.Small, strength * 0.6)
		end
	end)
	task.delay(seconds, function()
		pcall(function()
			HapticService:SetMotor(input, Enum.VibrationMotor.Large, 0)
			HapticService:SetMotor(input, Enum.VibrationMotor.Small, 0)
		end)
	end)
end

local function emitter(props: { [string]: any }): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Texture = SMOKE
	made.Rate = 0
	made.LightInfluence = 1
	for key, value in props do
		(made :: any)[key] = value
	end
	return made
end

-- Where the arm met the body, in the world (the arm's own frame from the server when it has one).
local function shoulderOf(character: Model, arm: string, from: CFrame?): Vector3?
	if from then
		return (from * CFrame.new(0, 0.8, 0)).Position
	end
	local torso = character:FindFirstChild("Torso") :: BasePart?
	return if torso
		then (torso.CFrame * CFrame.new(if arm == "L" then -1.1 else 1.1, 0.75, 0)).Position
		else nil
end

-- Every client: a dark burst where the arm came away and a brief drip from the shoulder.
local function burst(character: Model, arm: string, at: Vector3)
	local torso = character:FindFirstChild("Torso") :: BasePart?
	local outward = if torso
		then (if arm == "L" then -torso.CFrame.RightVector else torso.CFrame.RightVector)
		else Vector3.xAxis
	local holder = Instance.new("Part")
	holder.Name = "TearBurst"
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.CFrame = CFrame.lookAt(at, at + outward)
	local droplets = emitter({
		Color = ColorSequence.new(BLOOD),
		Lifetime = NumberRange.new(0.45, 0.9),
		Speed = NumberRange.new(TEAR.DropletSpeed * 0.45, TEAR.DropletSpeed),
		SpreadAngle = Vector2.new(38, 38),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -Workspace.Gravity * 0.45, 0),
		Drag = 2.5,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0.08),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.75, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = NumberRange.new(0, 360),
	})
	droplets.Parent = holder
	local mist = emitter({
		Color = ColorSequence.new(BLOOD, GRIT),
		Lifetime = NumberRange.new(0.5, 0.95),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Front,
		Drag = 4,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1.5),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	mist.Parent = holder
	holder.Parent = Workspace
	droplets:Emit(TEAR.Droplets)
	mist:Emit(TEAR.Mist)
	Debris:AddItem(holder, 2.5)
	-- the drip follows the body for a moment
	if torso then
		local attach = Instance.new("Attachment")
		attach.Name = "TearDrip"
		attach.Parent = torso
		attach.WorldPosition = at
		local drip = emitter({
			Color = ColorSequence.new(BLOOD),
			Rate = TEAR.StumpRate,
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(0, -Workspace.Gravity * 0.4, 0),
			Size = NumberSequence.new(0.09),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
		drip.Parent = attach
		task.delay(TEAR.StumpSeconds, function()
			drip.Enabled = false
		end)
		Debris:AddItem(attach, TEAR.StumpSeconds + 1)
	end
end

-- The one who lost it: the shock, the heart and the breath.
local function shock(side: number, cry: string, pitch: number)
	play("LimbRip")
	play("LimbThud")
	task.delay(TEAR.CryDelay, play, cry, nil, 1, pitch)
	Trauma.torn(side)
	Overlay.pulse(Theme.Color.signalDark, 1, 1.2)
	local audio = Registry.AudioController
	if audio then
		audio.Shock()
	end
	local still = reducedMotion()
	local camera = Registry.CameraController
	if camera and not still then
		camera.Shake(TEAR.Shake)
		camera.ShakeFor(TEAR.Kick, TEAR.KickSeconds)
	end
	rumble(TEAR.Haptic, TEAR.HapticSeconds)
	-- a rescue's rush already pants (GrabController); otherwise the panting is ours
	if Trauma.rush() < 0.25 then
		task.delay(TEAR.BreathAt, play, "TornBreath")
	end
	task.spawn(function()
		local started = os.clock()
		while true do
			local since = os.clock() - started
			if since >= TEAR.ShockSeconds then
				break
			end
			local strength = 1 - 0.5 * since / TEAR.ShockSeconds
			play("Heartbeat", nil, strength)
			Trauma.beat(strength)
			if camera and not still then
				camera.Pulse(0.3 * strength)
			end
			task.wait(TearFeedback.heartGap(since))
		end
	end)
end

-- ArmTorn on every client: where it happened, what it sounded like, and how it hits you.
local function painAndPanic(userId: number, arm: string, from: CFrame?)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if character == nil then
		return
	end
	local index, pitch = TearFeedback.voice(userId, #PAIN_CRIES)
	local cry = PAIN_CRIES[index]
	local at = shoulderOf(character, arm, from)
	if at then
		burst(character, arm, at)
	end
	if player == Players.LocalPlayer then
		shock(if arm == "L" then -1 else 1, cry, pitch)
		return
	end
	if at == nil then
		return
	end
	play("LimbRip", at)
	task.delay(TEAR.CryDelay, play, cry, at, 1, pitch)
	local camera = Workspace.CurrentCamera
	local near = if camera then TearFeedback.nearby((camera.Focus.Position - at).Magnitude) else 0
	if near > 0 then
		Overlay.pulse(Theme.Color.signalDark, TEAR.OnlookerPulse * near, 0.7)
		local shaker = Registry.CameraController
		if shaker and not reducedMotion() then
			shaker.Shake(TEAR.OnlookerShake * near)
		end
	end
end

-- The rescue -------------------------------------------------------------------------------------

local function stopRescue()
	active = nil
	rescuePanel.Visible = false
	ContextActionService:UnbindAction(ACTION)
end

-- The button's own words for the input in use: touch taps it, the others press a key.
local function labelPull()
	local kind = UserInputService:GetLastInputType()
	pullButton.Text = if kind == Enum.UserInputType.Touch
		then "PULL"
		elseif kind.Name:sub(1, 7) == "Gamepad" then "A"
		else "SPACE"
end

local function press(touch: boolean)
	local session = active
	if session == nil then
		return
	end
	-- the instant the key went down, on the clock that draws the marker (a tap arrives late)
	local at = serverNow() - SkillCheck.frameLead(FrameTime.get())
	if touch then
		at -= Difficulty.SkillCheck.TouchLead
	end
	-- the nearest beat not pressed yet
	local best, bestGap = nil :: number?, math.huge
	for i, offset in session.beats do
		local gap = math.abs(session.startsAt + offset - at)
		if not session.pressed[i] and gap < bestGap then
			best, bestGap = i, gap
		end
	end
	if best == nil then
		return
	end
	-- nowhere near a mark (a press in the lead-in, a double tap, a jump): the server would judge
	-- it a miss and end the rescue, so it stays here as a hint instead
	if bestGap > Config.Rescue.Window + Config.Rescue.CompensationMax then
		rescueHint.Text = "WAIT FOR THE MARK"
		rescueHint.TextColor3 = Theme.Color.caution
		hintUntil = os.clock() + 0.6
		return
	end
	session.pressed[best] = true
	Net.Fire("Rescue", session.id, best, at)
end

local function onAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		press(false)
	end
	return Enum.ContextActionResult.Sink
end

local function startRescue(data: { [string]: any })
	local beats = data.beats :: { number }
	active = {
		id = data.id,
		startsAt = data.startsAt,
		endsAt = data.endsAt,
		beats = beats,
		pressed = {},
	}
	rescueTitle.Text = `PULL {string.upper(nameOf(data.victim))} FREE`
	rescueHint.Text = HINT
	rescueHint.TextColor3 = Theme.Color.boneDim
	hintUntil = 0
	labelPull()
	local length = data.endsAt - data.startsAt
	for i, notch in notches do
		local offset = beats[i]
		notch.Visible = offset ~= nil
		if offset then
			notch.Position = UDim2.fromScale(offset / length, 0.5)
			notch.BackgroundColor3 = Theme.Color.brass
		end
	end
	rescuePanel.Visible = true
	-- a selected button (gamepad UI navigation) would take A before the beats could
	GuiService.SelectedObject = nil
	ContextActionService:BindActionAtPriority(
		ACTION,
		onAction,
		false,
		Enum.ContextActionPriority.High.Value + 110,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
end

local function onFx(kind: string, data: any)
	if ReplicatedStorage:GetAttribute("LimbLoss") ~= true then
		return
	end
	if (kind == "ArmTorn" or kind == "ArmRestored") and type(data) == "table" then
		local player = if typeof(data.userId) == "number" then Players:GetPlayerByUserId(data.userId) else nil
		local character = player and player.Character
		if character and (data.arm == "L" or data.arm == "R") then
			local motion: Motion = motions[character] or {}
			motions[character] = motion
			motion.arm = data.arm
			if kind == "ArmTorn" then
				motion.torn = serverNow()
				motion.restored = nil
			else
				motion.restored = serverNow()
				motion.torn = nil
			end
		end
	end
	local me = Players.LocalPlayer.UserId
	if kind == "ArmTorn" and type(data) == "table" then
		spawnLimb(data.userId, data.arm, data.cframe)
		if typeof(data.userId) == "number" and (data.arm == "L" or data.arm == "R") then
			painAndPanic(data.userId, data.arm, if typeof(data.cframe) == "CFrame" then data.cframe else nil)
		end
	elseif kind == "RescueOpen" and type(data) == "table" then
		if data.victim == me then
			Overlay.alert("HOLD ON: YOUR CREW CAN STILL REACH YOU", Theme.Color.caution, 2)
		else
			Overlay.alert(
				`{string.upper(nameOf(data.victim))} IS GOING UNDER: RESCUE`,
				Theme.Color.dangerText,
				2
			)
		end
	elseif kind == "RescueStart" and type(data) == "table" then
		pulls[data.id] = {
			victim = data.victim,
			rescuer = data.rescuer,
			startsAt = data.startsAt,
			endsAt = data.endsAt,
			beats = data.beats,
		}
		if data.rescuer == me then
			startRescue(data)
		elseif data.victim == me then
			Overlay.alert(`{string.upper(nameOf(data.rescuer))} IS PULLING YOU FREE`, Theme.Color.caution, 2)
		end
	elseif kind == "RescueBeat" and type(data) == "table" then
		local session = active
		if session and session.id == data.id then
			local notch = notches[data.beat]
			if notch and (data.result == "Hit" or data.result == "Miss") then
				notch.BackgroundColor3 = if data.result == "Hit" then Theme.Color.go else Theme.Color.signal
			end
		end
	elseif kind == "RescueEnd" and type(data) == "table" then
		pulls[data.id] = nil
		local session = active
		if session and session.id == data.id then
			stopRescue()
		end
	end
end

-- The HUD ----------------------------------------------------------------------------------------

local function trainPosition(): Vector3?
	local train = Workspace:FindFirstChild("Train")
	return if train and train:IsA("Model") then train:GetPivot().Position else nil
end

local function step()
	local session = active
	if session then
		local u = (serverNow() - session.startsAt) / math.max(session.endsAt - session.startsAt, 0.01)
		rescueMarker.Position = UDim2.fromScale(math.clamp(u, 0, 1), 0.5)
		if u > 1.5 then
			stopRescue() -- the end never arrived (a missed event): let go of the controls
		end
		if hintUntil > 0 and os.clock() >= hintUntil then
			hintUntil = 0
			rescueHint.Text = HINT
			rescueHint.TextColor3 = Theme.Color.boneDim
		end
	end
	local character = Players.LocalPlayer.Character
	local returnBy = character and character:GetAttribute("ReturnBy")
	local now = serverNow()
	local warning = ReplicatedStorage:GetAttribute("LimbLoss") == true
		and character ~= nil
		and character:GetAttribute("MissingArms") == "LR"
		and typeof(returnBy) == "number"
		and returnBy > now
		and returnBy - now <= Config.WarningSeconds
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if warning and humanoid and humanoid.Health > 0 then
		if warningCharacter ~= character or warningDeadline ~= returnBy then
			warningCharacter, warningDeadline, nextWarning = character, returnBy :: number, 0
		end
		if now >= nextWarning and Registry.AudioController then
			Registry.AudioController.Play("InjuryWarning")
			nextWarning = now + Config.Presentation.WarningInterval
		end
	else
		warningCharacter, warningDeadline, nextWarning = nil, nil, 0
	end
	if typeof(returnBy) == "number" then
		local left = math.max(returnBy - serverNow(), 0)
		returnPanel.Visible = true
		returnText.Text = string.format("GET BACK ABOARD  %d", math.ceil(left))
		returnText.TextColor3 = if left <= Config.WarningSeconds
			then Theme.Color.dangerText
			else Theme.Color.bone
		local target = trainPosition()
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		if target and root and camera then
			local flat = camera.CFrame:VectorToObjectSpace(target - root.Position)
			returnArrow.Rotation = math.deg(math.atan2(flat.X, -flat.Z))
			returnArrow.Visible = true
		else
			returnArrow.Visible = false
		end
	else
		returnPanel.Visible = false
	end
	local healing = character and character:GetAttribute("Healing")
	if typeof(healing) == "number" then
		healText.Visible = true
		healText.Text = string.format("TREATING  %.1f", math.max(healing - serverNow(), 0))
	else
		healText.Visible = false
	end
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Injury",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	rescuePanel = Ui.panel({
		Name = "Rescue",
		Size = UDim2.fromOffset(380, 112),
		Position = UDim2.new(0.5, 0, 1, -170),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = gui,
	}) :: any
	rescueTitle = Ui.text({
		Text = "PULL THEM FREE",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.bone,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 8),
	})
	rescueTitle.Parent = rescuePanel
	rescueTrack = Ui.new("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.Color.steelLight,
		Size = UDim2.new(1, -150, 0, 10),
		Position = UDim2.fromOffset(20, 64),
		Parent = rescuePanel,
	}, { Ui.corner(5) :: Instance, Ui.stroke(Theme.Color.tarnish, 1) })
	for i = 1, 3 do
		notches[i] = Ui.new("Frame", {
			Name = `Beat{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(14, 22),
			BackgroundColor3 = Theme.Color.brass,
			Parent = rescueTrack,
		}, { Ui.corner(3) :: Instance })
	end
	rescueMarker = Ui.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(4, 30),
		BackgroundColor3 = Theme.Color.bone,
		ZIndex = 3,
		Parent = rescueTrack,
	})
	-- touch: a big button, read on the press (not the release, which comes a tap late)
	pullButton = Ui.new("TextButton", {
		Name = "Pull",
		Text = "PULL",
		FontFace = Theme.Font.display,
		TextSize = 22,
		TextColor3 = Theme.Color.inkDeep,
		BackgroundColor3 = Theme.Color.brassLight,
		Size = UDim2.fromOffset(100, 60),
		Position = UDim2.new(1, -116, 0, 38),
		AutoButtonColor = true,
		Selectable = false, -- gamepad presses A for the beats; the button is for touch and mouse
		Parent = rescuePanel,
	}, { Ui.corner(6) :: Instance })
	pullButton.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			press(kind == Enum.UserInputType.Touch)
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		if rescuePanel.Visible then
			labelPull()
		end
	end)
	rescueHint = Ui.text({
		Text = HINT,
		Font = Theme.Font.type,
		TextSize = 13,
		Color = Theme.Color.boneDim,
		Size = UDim2.new(1, -150, 0, 16),
		Position = UDim2.fromOffset(20, 84),
	})
	rescueHint.Parent = rescuePanel

	returnPanel = Ui.panel({
		Name = "Return",
		Size = UDim2.fromOffset(330, 56),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Parent = gui,
	}) :: any
	returnText = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 24,
		Color = Theme.Color.bone,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(52, 0),
	})
	returnText.Parent = returnPanel
	returnArrow = Ui.text({
		Text = "▲",
		Font = Theme.Font.display,
		TextSize = 30,
		Color = Theme.Color.brassLight,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(12, 6),
	})
	returnArrow.Parent = returnPanel

	healText = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.go,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(240, 26),
		Position = UDim2.new(0.5, 0, 1, -292), -- above the rescue panel, never under it
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
	})
	healText.Parent = gui

	-- this ScreenGui is not under the main one's UIScale: shrink with it on a phone held sideways
	local main = Registry.UIController.Gui()
	Ui.phoneScale(rescuePanel, main, 0.75)
	Ui.phoneScale(returnPanel, main, 0.75)
	Ui.phoneScale(healText, main, 0.75)
end

function InjuryController.Init() end

-- The "Give Tonic" prompt on your own body is for your crewmates: hide it from yourself (the server
-- ignores a self-trigger anyway, so all it did was offer a button that does nothing).
local function hideOwnTreatPrompts(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil then
		return
	end
	local function hide(child: Instance)
		if child:IsA("ProximityPrompt") and child:GetAttribute("Action") == "Treat" then
			child.Enabled = false
			-- the server turns it off while you are held and back on after: keep it off here
			child:GetPropertyChangedSignal("Enabled"):Connect(function()
				if child.Enabled then
					child.Enabled = false
				end
			end)
		end
	end
	for _, child in root:GetChildren() do
		hide(child)
	end
	root.ChildAdded:Connect(hide)
end

function InjuryController.Start()
	build()
	Net.On("Fx", onFx)
	RunService.RenderStepped:Connect(step)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(hideOwnTreatPrompts)
	if player.Character then
		task.spawn(hideOwnTreatPrompts, player.Character)
	end
end

return InjuryController
