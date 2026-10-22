--!strict
--[[
	Surface treatments from Config/Surfaces, laid over a built station or train so hazards
	and obstacles read inside the lantern pool on a dim screen (docs/visibility). Paint only:
	thin non-colliding sleeves and strips welded to the part they cover, no lights.

	  station(model, archetype, seed): a lime-washed band low on every obstacle kind listed in
	    Surfaces.Limewash.kinds, each band's height and tone varied a little (brushed by hand),
	    darkened by the grade's grime (Surfaces.Grime). No longer called (2026-10-22): the white
	    bands read as clutter on every crate and cabinet (owner's phone screenshots; Prompt 6
	    removes the station path). Kept for the visibility harness until Prompt 6 lands.
	  train(model, origin): a pale lining along the foot and the waist of the platform side's lower
	    panels, and the brass there polished. Kept out of TrainBuilder (the exterior rework
	    owns it); TrainService and the harnesses call it after TrainBuilder.build. The lining
	    carries no Livery attribute, so a livery never repaints it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Surfaces = require(Shared.Config.Surfaces)
local Kit = require(Shared.Visual.Kit)
local Rng = require(Shared.Util.Rng)

local Limewash = {}

local KINDS: { [string]: boolean } = {}
for _, kind in Surfaces.Limewash.kinds do
	KINDS[kind] = true
end

local function shaded(rgb: { number }, factor: number): Color3
	return Kit.shade(Kit.rgb(rgb), factor)
end

-- The part's local axis closest to world up: 1 X, 2 Y, 3 Z; and how upright it is.
local function upAxis(cf: CFrame): (number, number)
	local dots = { math.abs(cf.RightVector.Y), math.abs(cf.UpVector.Y), math.abs(cf.LookVector.Y) }
	local best = 1
	for i = 2, 3 do
		if dots[i] > dots[best] then
			best = i
		end
	end
	return best, dots[best]
end

local function axisSize(size: Vector3, axis: number): number
	return if axis == 1 then size.X elseif axis == 2 then size.Y else size.Z
end

local function component(v: Vector3, axis: number): number
	return if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
end

-- How far each sibling's same-facing side faces stand proud of the host's sides (straps,
-- trims, flush walls and their bands), in the host's frame, near its foot.
local function proud(part: BasePart, siblings: { BasePart }, axis: number, reach: number): { number }
	local out = {}
	local half = part.Size / 2
	for _, other in siblings do
		if other == part then
			continue
		end
		local cf = part.CFrame:ToObjectSpace(other.CFrame)
		local h = other.Size / 2
		local r, u, b = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = Vector3.new(
			math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(b.X) * h.Z,
			math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(b.Y) * h.Z,
			math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(b.Z) * h.Z
		)
		local lo, hi = cf.Position - ext, cf.Position + ext
		-- only what overlaps the band's height
		local foot = -component(half, axis)
		if component(hi, axis) < foot or component(lo, axis) > foot + reach then
			continue
		end
		for side = 1, 3 do
			if side ~= axis then
				local edge = component(half, side)
				table.insert(out, component(hi, side) - edge)
				table.insert(out, -component(lo, side) - edge)
			end
		end
	end
	return out
end

-- Heights (world Y) of the sibling faces that could share a plane with a band's sole or top.
local function levels(siblings: { BasePart }, except: BasePart): { number }
	local out = {}
	for _, other in siblings do
		if other ~= except then
			local h = other.Size / 2
			local cf = other.CFrame
			local ext = math.abs(cf.RightVector.Y) * h.X
				+ math.abs(cf.UpVector.Y) * h.Y
				+ math.abs(cf.LookVector.Y) * h.Z
			table.insert(out, cf.Position.Y - ext)
			table.insert(out, cf.Position.Y + ext)
		end
	end
	return out
end

local function clearOf(value: number, planes: { number }): boolean
	for _, p in planes do
		if math.abs(value - p) < 0.013 then
			return false
		end
	end
	return true
end

-- The first band thickness whose faces share no plane with a sibling's (the audit's 0.01).
local CLEAR = { 0.06, 0.075, 0.09, 0.045, 0.105, 0.12, 0.135 }
local function clearThickness(planes: { number }): number?
	for _, t in CLEAR do
		local free = true
		for _, p in planes do
			if math.abs(t - p) < 0.013 then
				free = false
				break
			end
		end
		if free then
			return t
		end
	end
	return nil
end

local function sleeve(
	part: BasePart,
	height: number,
	color: Color3,
	siblings: { BasePart },
	lift: number
): BasePart?
	local spec = Surfaces.Limewash
	local axis, upright = upAxis(part.CFrame)
	if upright < 0.97 then
		return nil -- leaning or lying parts are left bare
	end
	local size = part.Size
	local tall = axisSize(size, axis)
	if tall < spec.minHeight then
		return nil
	end
	local h = if tall < spec.low then tall * 0.9 else math.min(height, tall * 0.9)
	local up = if axis == 1
		then part.CFrame.RightVector
		elseif axis == 2 then part.CFrame.UpVector
		else part.CFrame.LookVector
	local sign = if up.Y >= 0 then 1 else -1
	-- the band's centre: from the part's foot (lifted a hair, so its sole is never in the
	-- foot's plane nor a neighbouring band's) up h studs
	local foot = part.CFrame.Position - up * sign * (tall / 2)
	-- nudge the sole and the top off any sibling's horizontal faces
	local heights = levels(siblings, part)
	for _ = 1, 8 do
		if clearOf(foot.Y + lift, heights) and clearOf(foot.Y + lift + h, heights) then
			break
		end
		lift += 0.017
		h -= 0.011
	end
	local centre = foot + up * sign * (h / 2 + lift)
	local thickness = clearThickness(proud(part, siblings, axis, h + 0.1))
	if not thickness then
		return nil -- too crowded with trim to paint cleanly
	end
	local t = thickness * 2
	local band: BasePart
	local cylinder = part:IsA("Part") and (part :: Part).Shape == Enum.PartType.Cylinder
	if cylinder then
		if axis ~= 1 then
			return nil -- a cylinder lying on its side
		end
		band = Kit.cylinder(nil, h, math.min(size.Y, size.Z) + t, part.CFrame.Rotation + centre, color)
	elseif part:IsA("Part") and (part :: Part).Shape == Enum.PartType.Block then
		local s = if axis == 1
			then Vector3.new(h, size.Y + t, size.Z + t)
			elseif axis == 2 then Vector3.new(size.X + t, h, size.Z + t)
			else Vector3.new(size.X + t, size.Y + t, h)
		band = Kit.block(nil, s, part.CFrame.Rotation + centre, color)
	else
		return nil
	end
	band.Name = "Limewash"
	band.Material = Enum.Material.Plaster
	band.CanCollide = false
	band.CanQuery = false
	band.CastShadow = false
	band.Parent = part.Parent
	Kit.weld(band, part)
	return band
end

local function kindOf(name: string): string
	return (string.gsub(name, "_%d+$", ""))
end

-- A lime-washed band low on each listed obstacle. Returns how many bands it laid.
function Limewash.station(model: Model, archetype: string, seed: number): number
	local spec = Surfaces.Limewash
	local grime = Surfaces.Grime[archetype] or Surfaces.Grime.Default
	local rng = Rng.new(Rng.derive(seed, "limewash"))
	local count = 0
	for _, piece in model:GetChildren() do
		if not KINDS[kindOf(piece.Name)] then
			continue
		end
		-- one brush per object: its own height and tone
		local roll = rng:range(-1, 1)
		local tone = 1 - grime + spec.tone * rng:range(-1, 1)
		local color = shaded(spec.color, math.min(tone, 1))
		local parts = {}
		local siblings: { BasePart } = {}
		local lowest = math.huge
		for _, part in piece:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 0.99 then
				table.insert(siblings, part)
			end
		end
		for _, part in piece:GetDescendants() do
			if
				part:IsA("BasePart")
				and part.CanCollide
				and part.Transparency < 0.5
				and part.Material ~= Enum.Material.Neon
				and part.Name ~= "Limewash"
			then
				local axis = upAxis(part.CFrame)
				local bottom = part.CFrame.Position.Y - axisSize(part.Size, axis) / 2
				lowest = math.min(lowest, bottom)
				table.insert(parts, { part = part, bottom = bottom, tall = axisSize(part.Size, axis) })
			end
		end
		for _, entry in parts do
			-- only the parts standing on the object's foot take the band
			if entry.bottom <= lowest + 0.35 then
				local h = math.clamp(entry.tall * spec.share, spec.min, spec.max) * (1 + spec.jitter * roll)
				local lift = 0.02 + 0.015 * (count % 4) -- each band's sole and top in its own plane
				local band = sleeve(entry.part, h, color, siblings, lift)
				if band then
					table.insert(siblings, band) -- the next band keeps clear of this one too
					count += 1
				end
			end
		end
	end
	return count
end

-- The platform side (+Z in the train's frame, the side the station docks on): lining and
-- brass. `origin` is the frame TrainBuilder.build was given. Returns how many parts it added.
function Limewash.train(model: Model, origin: CFrame): number
	local spec = Surfaces.Train
	local lining = Kit.rgb(spec.lining)
	local brassFrom = Kit.rgb(spec.brassFrom)
	local function localBox(part: BasePart): (Vector3, Vector3)
		local cf = origin:ToObjectSpace(part.CFrame)
		local h = part.Size / 2
		local r, u, b = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = Vector3.new(
			math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(b.X) * h.Z,
			math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(b.Y) * h.Z,
			math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(b.Z) * h.Z
		)
		return cf.Position - ext, cf.Position + ext
	end
	local side = -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide and part.Size.Y >= 3 then
			local _, hi = localBox(part)
			side = math.max(side, hi.Z)
		end
	end
	local count = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "Lining" then
			continue
		end
		local lo, hi = localBox(part)
		if part.Color == brassFrom and hi.Z >= side - 0.1 then
			part.Color = Kit.rgb(spec.brass)
		end
		-- the lower body panels: collidable, standing on the floor, face flush with the side
		if
			part.CanCollide
			and math.abs(hi.Z - side) < 0.05
			and part.Material ~= Enum.Material.Glass
			and hi.Y - lo.Y >= 2
			and math.abs(lo.Y) < 0.05
		then
			local x = (lo.X + hi.X) / 2
			local bands =
				{ { y = lo.Y + spec.foot / 2, h = spec.foot }, { y = hi.Y - spec.waist / 2, h = spec.waist } }
			for _, band in bands do
				local strip = Kit.block(
					part.Parent,
					Vector3.new(hi.X - lo.X, band.h, spec.thickness),
					origin * CFrame.new(x, band.y, side + spec.thickness / 2 + 0.01),
					lining,
					{
						material = Enum.Material.SmoothPlastic,
						collide = false,
						shadow = false,
						name = "Lining",
					}
				)
				Kit.weld(strip, part)
				count += 1
			end
		end
	end
	return count
end

return Limewash
