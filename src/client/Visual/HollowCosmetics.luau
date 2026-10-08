--!strict
-- Local dressing only. HollowAnimator owns the update loop and every joint write.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local GrimeLevel = require(Shared.Logic.GrimeLevel)
local C = Tuning.HollowCosmetics
local I = CFrame.identity

type Stain = { part: BasePart, color: Color3, threshold: number }
type Effect = {
	emitter: ParticleEmitter,
	enabled: boolean,
	rate: number,
	color: ColorSequence,
	owned: boolean,
	role: string,
}
export type Handle = {
	model: Model,
	root: BasePart,
	objects: { Instance },
	connections: { RBXScriptConnection },
	stains: { Stain },
	effects: { Effect },
	light: PointLight?,
	eyes: { BasePart },
	built: boolean,
	destroyed: boolean,
	near: boolean,
	grime: number,
	seed: number,
	parts: number,
}
local Cosmetics = {}

local function color(name: string, tint: number): Color3
	local rgb = (C.Colors :: { [string]: { number } })[name]
	return Color3.fromRGB(rgb[1] * tint, rgb[2] * tint, rgb[3] * tint)
end

local function keep(h: Handle, object: Instance)
	table.insert(h.objects, object)
end

local function part(
	h: Handle,
	parent: BasePart,
	size: Vector3,
	offset: CFrame,
	shade: Color3,
	scale: number,
	wedge: boolean?
): BasePart
	assert(h.parts < C.MaxParts, "Hollow cosmetic part budget")
	h.parts += 1
	local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	p.Name = "CosmeticDetail"
	p.Size = size * scale
	p.CFrame = parent.CFrame * offset
	p.Color = shade
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = h.model
	keep(h, p)
	return p
end

local function stain(
	h: Handle,
	parent: BasePart,
	size: Vector3,
	at: CFrame,
	shade: Color3,
	scale: number,
	threshold: number,
	wedge: boolean?
)
	local p = part(h, parent, size, at, shade, scale, wedge)
	p.Transparency = 1
	table.insert(h.stains, { part = p, color = shade, threshold = threshold })
end

local function effect(
	h: Handle,
	parent: BasePart,
	role: string,
	existing: string?,
	shade: Color3,
	position: Vector3
)
	local found = if existing then parent:FindFirstChild(existing) else nil
	local emitter: ParticleEmitter
	local owned = not (found and found:IsA("ParticleEmitter"))
	if found and found:IsA("ParticleEmitter") then
		emitter = found
	else
		local attachment = Instance.new("Attachment")
		attachment.Name = "Cosmetic" .. role
		attachment.Position = position
		attachment.Parent = parent
		keep(h, attachment)
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Cosmetic" .. role
		emitter.Texture = C.Texture
		emitter.Color = ColorSequence.new(shade)
		emitter.Lifetime = NumberRange.new(C.Lifetime * 0.6, C.Lifetime)
		emitter.Speed = NumberRange.new(0.2, 0.7)
		emitter.SpreadAngle = Vector2.new(12, 12)
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 0.5) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
		if role == "drip" then
			emitter.EmissionDirection = Enum.NormalId.Bottom
			emitter.Acceleration = Vector3.new(0, -5, 0)
			emitter.Size = NumberSequence.new(0.065)
			emitter.Transparency = NumberSequence.new(0.2, 1)
		end
		emitter.Enabled = false
		emitter.Parent = attachment
	end
	table.insert(h.effects, {
		emitter = emitter,
		enabled = emitter.Enabled,
		rate = emitter.Rate,
		color = emitter.Color,
		owned = owned,
		role = role,
	})
	if role == "drip" then
		emitter.Color = ColorSequence.new(shade)
	end
	emitter.Enabled = false
	emitter:Clear()
end

local function build(h: Handle)
	if h.built or h.destroyed then
		return
	end
	local model = h.model
	local seed = model:GetAttribute("Seed")
	local kind = model:GetAttribute("Kind")
	if typeof(seed) ~= "number" or (kind ~= "Stalker" and kind ~= "Crawler") then
		return
	end
	local head = model:FindFirstChild("Head")
	local jaw = model:FindFirstChild("Jaw")
	local chest = model:FindFirstChild("Chest")
	if
		not (
			head
			and head:IsA("BasePart")
			and jaw
			and jaw:IsA("BasePart")
			and chest
			and chest:IsA("BasePart")
		)
	then
		return
	end
	-- Existing crawler emitters can replicate after their parent parts.
	if kind == "Crawler" and (not jaw:FindFirstChild("Breath") or not h.root:FindFirstChild("Dust")) then
		return
	end
	if kind == "Stalker" and (not jaw:FindFirstChild("Drip") or not h.root:FindFirstChild("FootMist")) then
		return
	end
	h.built = true
	h.seed = seed
	local v = GrimeLevel.variation(seed)
	local bone, red, grime = color("Bone", v.tint), color("Blood", v.tint), color("Grime", v.tint)
	local front = -head.Size.Z / 2 - 0.025
	for _, side in { -1, 1 } do
		local eye = part(
			h,
			head,
			Vector3.new(0.09, 0.09, 0.065),
			CFrame.new(side * head.Size.X * 0.24, head.Size.Y * 0.08, front),
			color("Eye", 1),
			v.scale
		)
		eye.Material = Enum.Material.Neon
		table.insert(h.eyes, eye)
	end
	local light = Instance.new("PointLight")
	light.Name = "CosmeticEyeGlow"
	light.Color = color("Eye", 1)
	light.Range = C.LightRange
	light.Shadows = false
	light.Enabled = false
	light.Parent = h.eyes[1]
	h.light = light
	for i = 1, 3 do
		stain(
			h,
			jaw,
			Vector3.new(0.12, 0.13 + i * 0.02, 0.035),
			CFrame.new((i - 2) * jaw.Size.X * 0.27, 0, -jaw.Size.Z / 2 - 0.018),
			red,
			v.scale,
			(i - 1) * 0.28
		)
	end
	for i = 1, 2 do
		stain(
			h,
			head,
			Vector3.new(0.025, 0.22, 0.035),
			CFrame.new(head.Size.X * 0.33, head.Size.Y * (0.24 + i * 0.09), front)
				* CFrame.Angles(0, 0, i * 0.4),
			color("Crack", v.tint),
			v.scale,
			0,
			true
		)
	end
	for i = 1, 6 do
		stain(
			h,
			chest,
			Vector3.new(0.48, 0.10, 0.045),
			CFrame.new(
				if i % 2 == 0 then 0.27 else -0.27,
				chest.Size.Y * (0.32 - math.ceil(i / 2) * 0.18),
				-chest.Size.Z / 2 - 0.035
			),
			grime,
			v.scale,
			(i - 1) * 0.13
		)
	end
	if kind == "Crawler" then
		-- Local head coordinates follow its existing inverted neck; no joint edits.
		for i = 1, 6 do
			part(
				h,
				head,
				Vector3.new(0.18, 0.42 + (i % 3) * 0.08, 0.2),
				CFrame.new((i - 3.5) * 0.19, head.Size.Y * 0.39, 0.2) * CFrame.Angles(0.2, 0, (i - 3) * 0.12),
				color("Hair", v.tint),
				v.scale,
				true
			)
		end
	else
		for i = 1, 4 do
			part(
				h,
				chest,
				Vector3.new(0.19, 0.32, 0.035),
				CFrame.new(
					if i % 2 == 0 then 0.69 else -0.69,
					-chest.Size.Y * 0.30 + math.floor(i / 3) * 0.46,
					-chest.Size.Z / 2 - 0.06
				) * CFrame.Angles(0, 0, i * 0.3),
				bone,
				v.scale,
				true
			)
		end
		for _, side in { -1, 1 } do
			part(
				h,
				chest,
				Vector3.new(0.22, 0.39, 0.045),
				CFrame.new(side * 0.66, -chest.Size.Y / 2, -chest.Size.Z / 2 - 0.07),
				color("Coat", v.tint),
				v.scale,
				true
			)
		end
		local badge = part(
			h,
			chest,
			Vector3.new(0.24, 0.29, 0.055),
			CFrame.new(-0.55, 0.7, -chest.Size.Z / 2 - 0.07),
			color("Brass", v.tint),
			v.scale
		)
		badge.Material = Enum.Material.Metal
		for i = 1, 3 do
			part(
				h,
				chest,
				Vector3.new(0.08, 0.08, 0.055),
				CFrame.new(0.36, 0.55 - i * 0.3, -chest.Size.Z / 2 - 0.07),
				color("Brass", v.tint),
				v.scale
			)
		end
		part(
			h,
			chest,
			Vector3.new(0.19, 0.37, 0.03),
			CFrame.new(0.61, 0.36, -chest.Size.Z / 2 - 0.075) * CFrame.Angles(0, 0, -0.18),
			color("Paper", v.tint),
			v.scale
		)
	end
	-- One rigid accessory at the shoulder, welded only to Chest (never across joints).
	local anchor = CFrame.new(chest.Size.X / 2 + 0.03, chest.Size.Y * 0.34, 0)
	local iron = color("Iron", v.tint)
	if v.accessory == 1 then
		part(h, chest, Vector3.new(0.12, 0.72, 0.12), anchor * CFrame.Angles(0, 0, -0.5), iron, v.scale)
		part(
			h,
			chest,
			Vector3.new(0.25, 0.07, 0.20),
			anchor * CFrame.Angles(0, 0, -0.5) * CFrame.new(0, 0.38, 0),
			iron,
			v.scale
		)
	elseif v.accessory == 2 then
		for i = 1, 3 do
			part(
				h,
				chest,
				Vector3.new(0.08, 0.35, 0.08),
				anchor * CFrame.new((i - 2) * 0.16, -0.3, 0) * CFrame.Angles(0, 0, (i - 2) * 0.2),
				iron,
				v.scale
			)
		end
		part(h, chest, Vector3.new(0.44, 0.09, 0.28), anchor * CFrame.new(0, -0.51, 0), iron, v.scale)
	else
		for i = 1, 3 do
			local link = anchor * CFrame.new(0, -i * 0.22, 0) * CFrame.Angles(0, (i % 2) * math.pi / 2, 0.25)
			for _, side in { -1, 1 } do
				part(
					h,
					chest,
					Vector3.new(0.055, 0.24, 0.055),
					link * CFrame.new(side * 0.10, 0, 0),
					iron,
					v.scale
				)
				part(
					h,
					chest,
					Vector3.new(0.20, 0.055, 0.055),
					link * CFrame.new(0, side * 0.12, 0),
					iron,
					v.scale
				)
			end
		end
	end
	effect(h, jaw, "drip", "Drip", red, Vector3.new(0, -jaw.Size.Y / 2, -jaw.Size.Z / 2))
	effect(h, jaw, "breath", "Breath", color("Mist", 1), Vector3.new(0, 0, -jaw.Size.Z / 2))
	effect(h, chest, "smoke", nil, grime, Vector3.new(0, 0, -chest.Size.Z / 2))
	if kind == "Stalker" then
		-- Retire the old high-rate foot mist locally; restore it on teardown.
		effect(h, h.root, "retired", "FootMist", grime, Vector3.zero)
	end
	if kind == "Crawler" then
		effect(h, h.root, "dust", "Dust", grime, Vector3.zero)
	end
end

function Cosmetics.attach(model: Model, root: BasePart): Handle
	local h: Handle = {
		model = model,
		root = root,
		objects = {},
		connections = {},
		stains = {},
		effects = {},
		eyes = {},
		light = nil,
		built = false,
		destroyed = false,
		near = false,
		grime = -1,
		seed = 0,
		parts = 0,
	}
	local function retry()
		build(h)
	end
	table.insert(h.connections, model.DescendantAdded:Connect(retry))
	table.insert(h.connections, model:GetAttributeChangedSignal("Seed"):Connect(retry))
	table.insert(h.connections, model:GetAttributeChangedSignal("Kind"):Connect(retry))
	build(h)
	return h
end

function Cosmetics.update(h: Handle, position: Vector3?, grime: number, state: string, speed: number)
	if not h.built or h.destroyed then
		return
	end
	local near = position ~= nil and (h.root.Position - position).Magnitude <= C.Distance
	if grime ~= h.grime then
		h.grime = grime
		for _, s in h.stains do
			s.part.Color = s.color:Lerp(Color3.new(0, 0, 0), grime * 0.25)
			s.part.Transparency = if grime < s.threshold then 1 else 0.8 - grime * 0.65
		end
	end
	local alert = state == "Hunt" or state == "Windup" or state == "Grab" or state == "Recover"
	if h.light then
		h.light.Enabled = near
		h.light.Brightness = if alert then C.EyeAlert else C.EyeDim
	end
	for _, eye in h.eyes do
		eye.Transparency = if alert then 0 else 0.55
	end
	for _, e in h.effects do
		local rate = if e.role == "retired"
			then 0
			elseif e.role == "drip" then C.DripClean + (C.DripDirty - C.DripClean) * grime
			elseif e.role == "dust" then (if speed > C.DustSpeed then C.DustRate else 0)
			elseif e.role == "breath" then C.BreathRate
			else C.SmokeRate
		e.emitter.Rate = if near then rate else 0
		e.emitter.Enabled = near and rate > 0
		if not near and h.near then
			e.emitter:Clear()
		end
	end
	h.near = near
end

function Cosmetics.offsets(
	h: Handle,
	clock: number,
	state: string,
	speed: number,
	stunned: boolean
): (CFrame, CFrame)
	if not h.built or not h.near or state ~= "Prowl" or speed > C.IdleSpeed or stunned then
		return I, I
	end
	local step = math.floor(clock / C.StepTime) + h.seed
	-- Held, small offsets, always composed onto the animator's fresh base pose.
	local pulse = if step % 19 < 3 then math.sin(step * 2.7) else 0
	return CFrame.Angles(pulse * C.NeckAngle, pulse * C.NeckAngle, 0),
		CFrame.Angles(math.abs(pulse) * C.JawAngle, 0, 0)
end

function Cosmetics.destroy(h: Handle)
	if h.destroyed then
		return
	end
	h.destroyed = true
	for _, connection in h.connections do
		connection:Disconnect()
	end
	for _, e in h.effects do
		if not e.owned and e.emitter.Parent then
			e.emitter.Enabled = e.enabled
			e.emitter.Rate = e.rate
			e.emitter.Color = e.color
		end
	end
	for _, object in h.objects do
		object:Destroy()
	end
end

return Cosmetics
