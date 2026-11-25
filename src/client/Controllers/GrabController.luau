--!strict
--[[
	Your side of a grab (Config/Grabs). While a Hollow holds you (the GrabStyle attribute
	the server puts on your character):

	  * the struggle plate (UI/Struggle) names what it is doing to you, shows the hold
	    weakening as you win skill checks (GrabEscape) and its clock running down
	    (GrabFinishAt), both from the server
	  * the server sends each skill check (Fx SkillCheck: Logic/SkillCheck); its marker
	    crosses the bar on the server clock. Space, gamepad A or a tap on the keycap is your
	    one press for it, read the moment the key goes down: that server time goes with the
	    SkillCheck remote (the server judges that instant, within a latency tolerance), the
	    verdict shows at once by the same rule (the server's replaces it), the keycap punching down, a
	    jolt of the camera, and your body thrashing harder (CharacterAnimator reads
	    Struggle()). Space and A never jump while it has you (this binding sinks them and
	    MovementController zeroes the jump; both give it back when the hold ends)
	  * the view is dragged round toward the thing's face, every bite jolts it and pulses
	    the screen red, and your heart pounds
	  * when you tear free (or a flash makes it let go) you are thrown clear
	  * the screen carries your nerves (UI/Trauma): a tunnel that tightens and throbs with your
	    heart while it has you, dark veins cracking in at every bite, then the adrenaline rush
	    after you tear free; dying in its grip shuts the tunnel

	While it has you, your own look and turn are frozen: the server pins your anchored root
	to the hold every tick, and shift lock or AutoRotate turning it locally made the body
	spin and tilt against that pin, with the camera swinging along. So the camera goes
	Scriptable (this module drags it to the thing's face), AutoRotate and shift lock are off
	and the mouse is freed. `unlock` puts it all back and is safe to run any number of times;
	it runs however the grab ends (the attribute clears, you die or respawn, the run ends, or
	the K unstick key).

	Your own "Pull free" prompt is the crew's, not yours: it is hidden on this client.
	The grab remake (Tuning.GrabLook, Logic/GrabLook; off by default): for the Stalker and the Stoker the
	screen is the Hollow's own (UI/Trauma look), the heartbeat is gone, the world muffles under the Hollow's
	own sound in your ear, and each hold moves the camera its own way: lifted by the throat you look up at it
	from under its arm; pressed into its ribs the view is crushed in close and lurches at each squeeze;
	dragged by the ankle you are low to the ground looking back the way you came; the Stoker's lift raises
	you as the ground falls away, his slam drops you hard in a puff of ash, and his reach-in hauls you in
	short hard jolts. Each grab also rolls a variant (the dark's lean, how fast it closes, a shudder, a slow
	roll or sparse kicks), never the one the grab before had.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Audio = require(Shared.Config.Audio)
local Difficulty = require(Shared.Config.Difficulty)
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)
local RunRules = require(Shared.Logic.RunRules)
local SkillCheck = require(Shared.Logic.SkillCheck)
local Grab = require(Shared.Logic.Grab)
local GrabLook = require(Shared.Logic.GrabLook)

local FrameTime = require(script.Parent.Parent.FrameTime)
local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Overlay = require(script.Parent.Parent.UI.Overlay)
local Struggle = require(script.Parent.Parent.UI.Struggle)
local Theme = require(script.Parent.Parent.UI.Theme)
local Trauma = require(script.Parent.Parent.UI.Trauma)

local GrabController = {}

local ACTION = "LTO_Struggle"
local LOOK_STEP = "LTO_GrabLook"
local MIN_EYE_DISTANCE = 6 -- studs: the frozen view never sits inside your own head
local held = false
local struggle = 0 -- 0..1 how hard you have been fighting lately
local escapeShown = 0
local heartAt = 0
local gaspAt = 0 -- the rush's next gasp for breath
local check: SkillCheck.Check? = nil -- the check on screen now
local pressed = false -- its one press has gone to the server
local finishFrom = 0 -- server times the grab's clock runs between
local finishAt = 0
local inputWatch: RBXScriptConnection? = nil
-- the grab remake (nil look: today's grab)
local lookKind: string? = nil
local lookMove: string? = nil
local variant: GrabLook.Variant? = nil
local lastKey: number? = nil -- the last grab's variant: the next never repeats it
local moveAt = 0
local kick = 0 -- 0..1 a bite's lurch (the ribs' squeeze, the reach-in's jolt), falling away fast
local swayKick = 0 -- the "Kick" variant's sparse jolts
local swayKickAt = 0
local swayKickDir = Vector3.zero
local lookRng = Random.new()
local CLOSE_LOOP = "GrabClose"
-- hurt inside the Stalker's cold grab: a frozen wine instead of blood red, for the wound edges and the bite
-- flash, so the hurt still reads but does not clash with the cold (owner 2026-11-22)
local FROZEN_BLOOD = Color3.fromRGB(58, 14, 36)
local FROZEN_FLASH = Color3.fromRGB(98, 30, 64)
local toneToken = 0 -- the latest grab's wound tone; a later grab's tone is never undone by an earlier one
local watching: RBXScriptConnection? = nil
local dying: RBXScriptConnection? = nil

-- What the grab took away, kept to give back (nil while nothing is locked).
type Saved = { humanoid: Humanoid?, autoRotate: boolean }
local saved: Saved? = nil
local eyeOffset = Vector3.new(0, 4, 10)
local faceLight: Attachment? = nil -- the Stoker's face light while he holds you (Tuning.BruteRemake.FaceLight)

local function audio(cue: string, gain: number?, pitch: number?)
	if Registry.AudioController then
		Registry.AudioController.Play(cue, nil, gain, pitch)
	end
end

-- Runs one step of a lock/unlock so a failure there never stops the rest; warns with its name.
local function safely(name: string, step: () -> ())
	local ok, err: any = pcall(step)
	if not ok then
		warn(`GrabController: {name} failed: {err}`)
	end
end

local function character(): Model?
	return Players.LocalPlayer.Character
end

-- Your one press for the check on screen.
local function press()
	local current = check
	if not held or current == nil or pressed then
		return
	end
	pressed = true
	-- the instant the key went down, on the clock that draws the marker (a tap arrives late)
	local at = Workspace:GetServerTimeNow() - SkillCheck.frameLead(FrameTime.get())
	if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		at -= Difficulty.SkillCheck.TouchLead
	end
	Net.Fire("SkillCheck", current.id, at)
	Struggle.result(SkillCheck.judge(current, at, 0))
	struggle = math.min(struggle + 0.3, 1)
	Struggle.punch()
	Registry.CameraController.Shake(0.12)
	audio("Winded", 0.35, 0.8 + math.random() * 0.3)
end

local function onAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		press()
	end
	-- the jump key must not jump (nor anything else) while it has you
	return Enum.ContextActionResult.Sink
end

-- The Hollow that has you, and where its face is.
local function holderHead(model: Model): Vector3?
	local link = model:FindFirstChild("GrabbedBy")
	local hollow = if link and link:IsA("ObjectValue") then link.Value else nil
	if hollow and hollow:IsA("Model") then
		local head = hollow:FindFirstChild("Head") :: BasePart?
		if head then
			return head.Position
		end
	end
	return nil
end

-- A faint cool light in front of the Stoker's face, on your screen only, so his hollow sockets read
-- from the grab camera. Gone when the grab ends.
local function lightFace(model: Model, kind: string)
	local def = Tuning.BruteRemake.FaceLight
	if kind ~= "Brute" or not Tuning.BruteRemake.Enabled or not def.Enabled or faceLight then
		return
	end
	local link = model:FindFirstChild("GrabbedBy")
	local hollow = if link and link:IsA("ObjectValue") then link.Value else nil
	local head = hollow and hollow:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local spot = Instance.new("Attachment")
	spot.Name = "GrabFaceLight"
	spot.Position = Vector3.new(0, 0, -def.Ahead)
	local light = Instance.new("PointLight")
	light.Range = def.Range
	light.Brightness = def.Brightness
	light.Color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	light.Shadows = false
	light.Parent = spot
	spot.Parent = head
	faceLight = spot
end

local function unlightFace()
	if faceLight then
		faceLight:Destroy()
		faceLight = nil
	end
end

local function hidePry(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		for _, prompt in root:GetChildren() do
			if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("Action") == "Pry" then
				prompt.Enabled = false
			end
		end
	end
end

-- Freezes your own look and turn for the grab: Scriptable camera, no AutoRotate. (Shift lock is
-- already off: MovementController sinks Shift, and DevEnableMouseLock is server-only.)
local function tierName(): string
	return GrabLook.tier(Players.LocalPlayer:GetAttribute("GraphicsQuality"))
end

-- The hold's camera move and the variant's sway (the grab remake): the eye and the point it looks at,
-- reshaped, and a roll in radians. Today's grab passes straight through.
local function shaped(eye: Vector3, target: Vector3, body: BasePart, dt: number): (Vector3, Vector3, number)
	local v = variant
	if lookMove == nil or v == nil then
		return eye, target, 0
	end
	local since = os.clock() - moveAt
	local ease = GrabLook.close(since, v.speed)
	local sway = Tuning.GrabLook.Tiers[tierName()].sway
	kick *= math.exp(-dt * 6)
	local roll = 0
	if lookMove == "Lifted" then
		-- up off your feet by the throat: you look up at it from under its arm, a choking tremor
		eye += (target - eye) * 0.3 * ease - Vector3.yAxis * 1.6 * ease
		roll = math.rad(4) * math.sin(since * 1.3) * ease
	elseif lookMove == "Pressed" then
		-- crushed into its ribs: the view pressed close, lurching in at every squeeze
		eye = eye:Lerp(target, 0.28 * ease + 0.12 * kick)
	elseif lookMove == "Dragged" then
		-- hauled by the ankle: low to the ground, looking back the way you came, scraping
		local back = body.Position - target
		back = Vector3.new(back.X, 0, back.Z)
		back = if back.Magnitude > 0.1 then back.Unit else -body.CFrame.LookVector
		-- the eye sits just past your trailing head, so your own body is behind it
		eye = eye:Lerp(body.Position + back * 2.2 + Vector3.yAxis * 1.1, ease)
		target = target:Lerp(body.Position + back * 30 + Vector3.yAxis * 1.5, ease)
		eye += Vector3.yAxis * math.noise(since * 9, 1.3) * 0.14 * sway + Vector3.yAxis * 0.25 * kick
	elseif lookMove == "Rise" then
		-- lifted: you rise with his hand and the ground falls away under you
		eye += Vector3.yAxis * 2.2 * ease
		target = target:Lerp(body.Position - Vector3.yAxis * 8, 0.28 * ease)
	elseif lookMove == "Drop" then
		-- slammed: one hard drop, then low
		local k = math.exp(-since * 9)
		eye += Vector3.yAxis * (3 * k - 0.8 * (1 - k))
	elseif lookMove == "Jolts" then
		-- hauled through the opening in short hard jolts
		eye += (target - eye).Unit * 0.9 * kick
	end
	if v.sway == "Shudder" then
		eye += Vector3.new(math.noise(since * 14, 2.1), math.noise(since * 14, 3.7), 0) * 0.07 * sway
	elseif v.sway == "Roll" then
		roll += math.rad(3) * math.sin(since * 0.9) * sway
	else
		swayKick *= math.exp(-dt * 8)
		if os.clock() >= swayKickAt then
			swayKickAt = os.clock() + lookRng:NextNumber(0.9, 1.8)
			swayKick = 1
			swayKickDir = Vector3.new(lookRng:NextNumber(-1, 1), lookRng:NextNumber(-0.6, 0.6), 0)
		end
		eye += swayKickDir * 0.25 * swayKick * sway
	end
	return eye, target, roll
end

-- The colour of the flash round the screen at the seize and at each bite: today's dark red, or with the
-- grab remake the Hollow's own (a cold grey-blue for the Stalker, a burnt ember for the Stoker). The seize
-- can arrive before the hold starts, so the look is read from the GrabKind already on your character.
local function pulseColor(): Color3
	local own = character()
	local kind = own and own:GetAttribute("GrabKind") :: string?
	local look = lookKind
		or (if kind then GrabLook.look(kind, Tuning.GrabLook.Enabled, Tuning.BruteRemake.Enabled) else nil)
	if look == "Cold" then
		return FROZEN_FLASH
	elseif look == "Heat" then
		return Color3.fromRGB(68, 36, 22) -- dark burnt soot: the edge ring keeps this colour through the hold (owner 2026-11-22: "too warm")
	end
	return Theme.Color.signalDark
end

-- The Hollow's own sound in your ear while it holds you (the grab remake); stopped with nil.
local function closeSound(kind: string?)
	local audioCtl = Registry.AudioController
	if audioCtl == nil then
		return
	end
	audioCtl.StopLoop(CLOSE_LOOP)
	if kind == nil then
		return
	end
	local cue = if kind == "Cold" then "HollowBreath" else "FireboxRoar"
	audioCtl.Loop(CLOSE_LOOP, cue, SoundService)
	local sound = audioCtl.LoopSound(CLOSE_LOOP)
	if sound then
		sound.Volume *= Tuning.GrabLook.CloseVolume
		sound.PlaybackSpeed = if kind == "Cold" then 0.82 else 0.46
	end
end

local function lock(model: Model)
	if saved then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	saved = {
		humanoid = humanoid,
		autoRotate = if humanoid then humanoid.AutoRotate else true,
	}
	if humanoid then
		humanoid.AutoRotate = false
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local camera = Workspace.CurrentCamera
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local offset = camera.CFrame.Position - root.Position
		eyeOffset = if offset.Magnitude >= MIN_EYE_DISTANCE
			then offset
			else (-root.CFrame.LookVector + Vector3.yAxis * 0.4).Unit * MIN_EYE_DISTANCE * 1.5
	end
	camera.CameraType = Enum.CameraType.Scriptable
	-- after CameraController's unshake (Camera - 1) and before its feel (Camera + 1)
	RunService:BindToRenderStep(LOOK_STEP, Enum.RenderPriority.Camera.Value, function(dt: number)
		local own = character()
		local body = own and own:FindFirstChild("HumanoidRootPart") :: BasePart?
		if own == nil or body == nil then
			return
		end
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable -- a phase change's camera reset must not hand it back
		local eye = body.Position + eyeOffset
		-- the view is dragged round to its face
		local target = holderHead(own) or body.Position
		local roll
		eye, target, roll = shaped(eye, target, body, dt)
		local want = CFrame.lookAt(eye, target) * CFrame.Angles(0, 0, roll)
		local turn = (cam.CFrame - cam.CFrame.Position):Lerp(want - want.Position, 1 - math.exp(-dt * 2.4))
		cam.CFrame = CFrame.new(eye) * turn
		cam.Focus = CFrame.new(target)
	end)
end

-- Gives back everything `lock` took. Safe to run twice, or with nothing locked.
local function unlock()
	RunService:UnbindFromRenderStep(LOOK_STEP)
	local was = saved
	saved = nil
	local player = Players.LocalPlayer
	if was then
		safely("restore AutoRotate", function()
			local humanoid = was.humanoid
			if humanoid and humanoid.Parent then
				humanoid.AutoRotate = was.autoRotate
			end
		end)
	end
	safely("reset camera", function()
		local trainCam = Registry.TrainCamController
		local camera = Workspace.CurrentCamera
		if camera.CameraType == Enum.CameraType.Scriptable and not (trainCam and trainCam.Active()) then
			camera.CameraType = Enum.CameraType.Custom
			local own = player.Character
			local humanoid = own and own:FindFirstChildOfClass("Humanoid")
			if humanoid and Registry.CameraController.SpectateTarget() == nil then
				camera.CameraSubject = humanoid
			end
		end
	end)
	safely("free mouse", function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		Registry.CameraController.Focus(nil)
	end)
end

local function begin(model: Model, style: string)
	local def = Grabs.ById[style]
	local kind = (model:GetAttribute("GrabKind") :: string?) or "Stalker"
	local fresh = not held -- false: the hold changed while it has you (the Stoker's lift to his slam)
	held = true
	struggle = 0.6
	escapeShown = 0
	check = nil
	pressed = false
	finishFrom = Workspace:GetServerTimeNow()
	finishAt = (model:GetAttribute("GrabFinishAt") :: number?) or finishFrom
	Trauma.seize()
	safely("look", function()
		local look = GrabLook.look(kind, Tuning.GrabLook.Enabled, Tuning.BruteRemake.Enabled)
		if look and (fresh or variant == nil) then
			local rolled = GrabLook.roll(lastKey, function(n: number): number
				return lookRng:NextInteger(1, n)
			end)
			variant = rolled
			lastKey = rolled.key
		end
		local wasMove = lookMove
		lookKind = look
		lookMove = if look then GrabLook.move(style) else nil
		if lookMove ~= wasMove then
			moveAt = os.clock()
		end
		Trauma.look(look, lookMove, if look then variant else nil, tierName())
		if fresh then
			-- by the end of the hold, or sooner: unanswered bites can end it long before its clock
			Trauma.seepFor(math.min(0.8 * (finishAt - finishFrom), 4.5))
		end
		toneToken += 1
		Overlay.woundTone(if look == "Cold" then FROZEN_BLOOD else nil)
		if Registry.AudioController then
			Registry.AudioController.GrabMuffle(look ~= nil, lookMove == "Lifted")
		end
		if fresh or look == nil then
			closeSound(look)
		end
		if lookMove == "Drop" then
			Trauma.puff()
			Registry.CameraController.Shake(1.1)
			audio("StokerDrag1", 0.9, 0.9)
		end
	end)
	local crew = Registry.StateController.Get({ "crew" }) or {}
	Struggle.show(
		if def then def.name else "IT HAS YOU",
		kind,
		RunRules.hasLivingCrewmate(crew, Session.userKey)
	)
	ContextActionService:BindActionAtPriority(
		ACTION,
		onAction,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	if inputWatch then
		inputWatch:Disconnect()
	end
	inputWatch = UserInputService.LastInputTypeChanged:Connect(function()
		Struggle.refreshKey()
	end)
	safely("lock", function()
		lock(model)
	end)
	hidePry(model)
	safely("face light", function()
		lightFace(model, kind)
	end)
	task.delay(0.1, function()
		if held then
			hidePry(model)
			safely("face light", function()
				lightFace(model, kind)
			end)
		end
	end)
end

local function finish(model: Model)
	safely("face light", unlightFace)
	if lookKind or lookMove then
		lookKind, lookMove, variant = nil, nil, nil
		-- the frozen wine fades back to blood once the screen has cleared (after the death tunnel if it got you)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local token = toneToken
		task.delay(if humanoid and humanoid.Health > 0 then 1.5 else 7, function()
			if token == toneToken and not held then
				Overlay.woundTone(nil)
			end
		end)
		safely("look sound", function()
			closeSound(nil)
			if Registry.AudioController then
				Registry.AudioController.GrabMuffle(false)
			end
		end)
	end
	if not held then
		safely("unlock", unlock)
		return
	end
	held = false
	check = nil
	ContextActionService:UnbindAction(ACTION)
	if inputWatch then
		inputWatch:Disconnect()
		inputWatch = nil
	end
	safely("hide struggle", Struggle.hide)
	safely("unlock", unlock)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0
	if alive then
		Trauma.release(true)
		gaspAt = os.clock() + 0.3
	else
		Trauma.died()
	end
end

local function watch(model: Model)
	if watching then
		watching:Disconnect()
	end
	if dying then
		dying:Disconnect()
		dying = nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- dead in its grip: the hold may linger on the body, but the controls come back
		dying = humanoid.Died:Connect(function()
			finish(model)
		end)
	end
	watching = model:GetAttributeChangedSignal("GrabStyle"):Connect(function()
		if model ~= Players.LocalPlayer.Character then
			return
		end
		local style = model:GetAttribute("GrabStyle") :: string?
		if style then
			begin(model, style)
		else
			finish(model)
		end
	end)
	local style = model:GetAttribute("GrabStyle") :: string?
	if style then
		begin(model, style)
	end
end

function GrabController.Init() end

function GrabController.Start()
	local ui = Registry.UIController.Gui()
	Trauma.mount(ui)
	Struggle.mount(ui, press)
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(function(model)
		finish(model)
		if watching then
			watching:Disconnect()
			watching = nil
		end
	end)
	player.CharacterAdded:Connect(function(model)
		if held then
			held = false
			ContextActionService:UnbindAction(ACTION)
			safely("hide struggle", Struggle.hide)
		end
		-- a failed unlock must never stop the new body being watched
		safely("unlock on respawn", unlock)
		Trauma.clear()
		model:WaitForChild("Humanoid", 10)
		watch(model)
	end)
	if player.Character then
		watch(player.Character)
	end
	-- the run ending (or any phase change) while held must never leave you locked
	Registry.StateController.Observe("public", { "run", "phase" }, function()
		local model = character()
		if held and (model == nil or model:GetAttribute("GrabStyle") == nil or not Session.isRunActive()) then
			if model then
				finish(model)
			else
				held = false
				ContextActionService:UnbindAction(ACTION)
				safely("hide struggle", Struggle.hide)
				safely("unlock", unlock)
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		struggle *= math.exp(-dt * 2.2)
		if not held then
			-- the rush after tearing free: gasps that slow as it ebbs
			local rush = Trauma.rush()
			if rush > 0.25 and os.clock() >= gaspAt then
				gaspAt = os.clock() + 1.1 + 1.4 * (1 - rush)
				-- lighter and higher than before (owner, 11-10: the panting after escaping was deep and raspy)
				audio("Winded", 0.18 + 0.22 * rush, 1.08 + math.random() * 0.1)
			end
			return
		end
		local model = character()
		if model == nil then
			return
		end
		-- a missed attribute change still lets you go
		if model:GetAttribute("GrabStyle") == nil then
			finish(model)
			return
		end
		local now = Workspace:GetServerTimeNow()
		local escape = (model:GetAttribute("GrabEscape") :: number?) or 0
		escapeShown += (escape - escapeShown) * math.min(dt * 12, 1)
		Struggle.set(escapeShown, now)
		finishAt = (model:GetAttribute("GrabFinishAt") :: number?) or finishAt
		Struggle.clock((finishAt - now) / math.max(finishAt - finishFrom, 0.1))
		-- the needle runs on the server clock; once its turn is over the check waits for the verdict
		local current = check
		local angle = if current then SkillCheck.angleAt(current, now) else nil
		Struggle.needle(if angle and angle >= 0 and angle <= 360 then angle else nil)
		if current then
			Struggle.zone(SkillCheck.zoneStartAt(current, now), current.zoneWidth, current.greatWidth)
		end
		-- the Stoker's pin: the check fades out over its second stage (Logic/Grab.pinFade)
		local fadeFrom = model:GetAttribute("PinFadeFrom") :: number?
		local fadeTo = model:GetAttribute("PinFadeTo") :: number?
		Struggle.fade(if fadeFrom and fadeTo then Grab.pinFade(now, fadeFrom, fadeTo) else 0)
		-- your heart, quickening as the hold wears you down
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local life = if humanoid then humanoid.Health / math.max(humanoid.MaxHealth, 1) else 1
		-- the grab remake has no heartbeat (owner 2026-11-22: the heartbeat is redundant)
		if lookKind == nil and os.clock() >= heartAt then
			heartAt = os.clock() + 0.42 + 0.35 * life
			audio("Heartbeat", 0.9, 1)
			Registry.CameraController.Pulse(0.6)
			Trauma.beat(1)
		end
	end)
end

-- How hard you are fighting right now, 0..1 (your body thrashes with it).
function GrabController.Struggle(): number
	return if held then struggle else 0
end

function GrabController.IsHeld(): boolean
	return held
end

-- The K unstick key: if nothing holds you, give back any look, turn or mouse state a grab kept.
function GrabController.Unstick()
	if not held then
		unlock()
	end
end

-- A bite, squeeze or yank landed on you (Fx from HollowService): `damage` taken by it.
function GrabController.Bite(damage: number?)
	local strength = math.clamp((damage or 8) / 14, 0.45, 1)
	Overlay.pulse(pulseColor(), 0.9, 0.7)
	Registry.CameraController.Shake(0.45 + 0.4 * strength)
	Trauma.hit(strength)
	audio("Hit", 0.75, 0.85)
	if lookMove == "Pressed" then
		Trauma.squeeze()
		kick = 1
	elseif lookMove == "Jolts" then
		kick = 1
		Registry.CameraController.Shake(0.4)
	elseif lookMove == "Dragged" then
		kick = 1
		audio("StokerDragGrit", 0.5, 1.35) -- dragged over the grit
	end
end

-- The Stoker pinned you (his lift turned into a pin on a missed press).
function GrabController.Pinned()
	Registry.CameraController.Shake(1.2)
	Trauma.pinned()
end

-- The shovel is coming down on you, alone (Config/Grabs crush): you see it rise and fall, and the screen
-- goes black the instant it lands (the crunch is heard, nothing is shown).
function GrabController.Crushed(landsIn: number)
	-- black just before the blade lands, so the blow is never seen; in the black it is felt where it lands,
	-- in the chest: a hard jolt down, a body thud and the breath knocked out, under the crunch everyone near
	-- hears (FxController)
	task.delay(math.max(landsIn - Tuning.Grab.Crush.BlackLead, 0), function()
		Trauma.blackout()
	end)
	task.delay(landsIn, function()
		Registry.CameraController.Shake(1.2)
		audio("LimbThud", 1, 0.85)
		audio("Winded", 0.9, 0.7)
	end)
end

-- It just seized you.
function GrabController.Seized()
	Overlay.pulse(pulseColor(), 1, 1.1)
	Registry.CameraController.Shake(1)
	audio("Hit", 1, 0.7)
end

-- The server's next skill check for you (Fx SkillCheck).
function GrabController.Check(data: SkillCheck.Check)
	if not held or type(data) ~= "table" then
		return
	end
	check = data
	pressed = false
	Struggle.zone(data.zoneStart, data.zoneWidth, data.greatWidth)
	audio("WarnTick", 0.8, 1.2)
end

-- The server's verdict on a check (Fx SkillResult).
function GrabController.Result(data: { id: number, result: string, progress: number })
	if not held or type(data) ~= "table" then
		return
	end
	if check and check.id == data.id then
		check = nil
		Struggle.clearCheck()
	end
	Struggle.result(data.result)
	if data.result == "Miss" then
		Registry.CameraController.Shake(0.35)
		audio("Hit", 0.4, 1.3)
	else
		-- a hit: a small bell tick (owner's pick, 11-09; the click until Config/Audio has SkillHit)
		-- and the bar's flash
		local great = data.result == "Great"
		if (Audio :: any).SkillHit then
			audio("SkillHit", if great then 1 else 0.8, if great then 1.12 else 1)
		else
			audio("Click", 0.8, if great then 1.4 else 1.1)
		end
		Struggle.hit(great)
	end
end

-- A crewmate is tearing at it.
function GrabController.Pried(name: string)
	Struggle.helped(name)
end

-- Thrown clear as the hold breaks: the push lands once the server lets your body go.
function GrabController.Thrown(knockback: Vector3)
	task.spawn(function()
		local model = character()
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root == nil then
			return
		end
		local deadline = os.clock() + 0.6
		while root.Anchored and os.clock() < deadline do
			RunService.Heartbeat:Wait()
		end
		if not root.Anchored then
			root.AssemblyLinearVelocity += knockback
		end
	end)
end

return GrabController
