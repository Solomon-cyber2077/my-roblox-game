--!strict
--[[
	Limb loss on the client (Config/Injury; the server's InjuryService and HollowService judge
	everything). Only presentation and input lives here:

	  the torn arm   on ArmTorn, every client builds a cosmetic copy of that arm (with the
	                 wearer's shirt) that swings out and falls; no collision, no queries, no
	                 touch, no gameplay meaning. At most Limbs.MaxPerClient at once (the oldest
	                 goes first), at rest by SettleSeconds, gone by RemoveSeconds.
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
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Injury)
local Difficulty = require(Shared.Config.Difficulty)
local Registry = require(script.Parent.Parent.Registry)
local CrewPoses = require(script.Parent.Parent.Animation.CrewPoses)

local Net = require(script.Parent.Parent.Net)
local Overlay = require(script.Parent.Parent.UI.Overlay)
local Theme = require(script.Parent.Parent.UI.Theme)
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
	local at = serverNow()
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
