--!nonstrict
--[[
	PhotoCommand: one step instead of ~40 calls for monster screenshots.

	  - finds OPEN ground in front of the player (no roof overhead, nothing solid
	    in the footprint, clear line of sight) so nothing spawns inside a building
	  - spawns one of each kind in a row, faces them at the player, freezes them
	  - floats a name label over each so Stalker/Crawler can't be mixed up
	  - returns a TEXT report (positions, clearance, frozen state) - often enough
	    proof on its own, zero image tokens

	Wire it once (server, e.g. in your dev-commands script):

		local PhotoCommand = require(path.to.PhotoCommand)
		PhotoCommand.bindChat({
			kinds = { "Stalker", "Crawler" },            -- every Hollow kind you want in the shot
			spawn = function(kind, cframe)               -- YOUR spawner; must return the Model
				return HollowService.spawnHollow(kind, cframe)
			end,
			-- freeze = function(model) ... end,          -- optional: also stop your AI here
		})

	Then in Studio chat:  /photo   and   /photo clear
	bindChat does nothing outside Studio.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PhotoCommand = {}

local RIG_NAME = "PhotoRig"
local CLEAR_HEIGHT = 7
local FOOTPRINT = Vector3.new(5, CLEAR_HEIGHT, 5)

local function excluded()
	local list = {}
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	local rig = Workspace:FindFirstChild(RIG_NAME)
	if rig then
		table.insert(list, rig)
	end
	return list
end

local function rayParams()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = excluded()
	return rp
end

local function overlapParams()
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = excluded()
	return op
end

-- ground point if (x,z) is open flat ground, else nil + reason
local function groundIfOpen(pos, refY, rp, op)
	local hit = Workspace:Raycast(Vector3.new(pos.X, refY + 8, pos.Z), Vector3.new(0, -40, 0), rp)
	if not hit then
		return nil, "no ground"
	end
	if hit.Normal.Y < 0.9 then
		return nil, "slope"
	end
	local ground = hit.Position

	local roof = Workspace:Raycast(ground + Vector3.new(0, CLEAR_HEIGHT, 0), Vector3.new(0, 40, 0), rp)
	if roof and roof.Instance.CanCollide then
		return nil, "roof overhead (" .. roof.Instance:GetFullName() .. ")"
	end

	local box = CFrame.new(ground + Vector3.new(0, CLEAR_HEIGHT / 2 + 0.3, 0))
	for _, part in Workspace:GetPartBoundsInBox(box, FOOTPRINT, op) do
		if part.CanCollide then
			return nil, "blocked by " .. part:GetFullName()
		end
	end
	return ground
end

local function findRow(root, count, spacing)
	local rp, op = rayParams(), overlapParams()
	local origin = root.Position
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local eye = origin + Vector3.new(0, 3, 0)

	for _, dist in { 18, 26, 36, 48 } do
		for _, deg in { 0, 25, -25, 50, -50, 90, -90, 135, -135, 180 } do
			local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(forward)
			local right = dir:Cross(Vector3.yAxis)
			local center = origin + dir * dist
			local spots, ok = {}, true
			for i = 1, count do
				local offset = (i - (count + 1) / 2) * spacing
				local ground = groundIfOpen(center + right * offset, origin.Y, rp, op)
				if not ground then
					ok = false
					break
				end
				-- camera/player must actually see the slot
				local los = Workspace:Raycast(eye, (ground + Vector3.new(0, 3, 0)) - eye, rp)
				if los and los.Instance.CanCollide then
					ok = false
					break
				end
				table.insert(spots, ground)
			end
			if ok then
				return spots, origin, center
			end
		end
	end
	return nil
end

local function defaultFreeze(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Humanoid") then
			d.WalkSpeed = 0
			d.JumpPower = 0
		end
	end
	model:SetAttribute("PhotoFrozen", true)
end

local function label(model, text)
	local adornee = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not adornee then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PhotoLabel"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(120, 28)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Color3.new(0, 0, 0)
	tl.BackgroundTransparency = 0.3
	tl.TextColor3 = Color3.new(1, 1, 0)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Text = text
	tl.Parent = gui
	gui.Parent = adornee
end

function PhotoCommand.clear()
	local rig = Workspace:FindFirstChild(RIG_NAME)
	if rig then
		rig:Destroy()
	end
end

function PhotoCommand.run(player, opts)
	assert(opts and opts.kinds and opts.spawn, "PhotoCommand.run needs opts.kinds and opts.spawn")
	PhotoCommand.clear()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "photo: player has no character yet"
	end

	local spots, origin, center = findRow(root, #opts.kinds, opts.spacing or 9)
	if not spots then
		return "photo: no open ground within 48 studs (roofs/walls everywhere) - walk to a clearing and retry"
	end

	local rig = Instance.new("Folder")
	rig.Name = RIG_NAME
	rig.Parent = Workspace

	local report = { `photo: row of {#opts.kinds} centered {center.X // 1},{center.Y // 1},{center.Z // 1}, all slots verified open` }
	for i, kind in opts.kinds do
		local spot = spots[i]
		local face = CFrame.lookAt(spot, Vector3.new(origin.X, spot.Y, origin.Z))
		local model = opts.spawn(kind, face)
		if not model then
			table.insert(report, `- {kind}: spawn returned nil`)
		else
			model.Parent = rig
			model:PivotTo(face)
			-- sit the model's bottom on the ground
			local bbox, size = model:GetBoundingBox()
			local lift = spot.Y - (bbox.Position.Y - size.Y / 2)
			model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
			;(opts.freeze or defaultFreeze)(model)
			label(model, kind)
			local p = model:GetPivot().Position
			table.insert(
				report,
				`- {kind}: at {p.X // 1},{p.Y // 1},{p.Z // 1} size {size.X // 0.1 / 10}x{size.Y // 0.1 / 10}x{size.Z // 0.1 / 10} frozen=true`
			)
		end
	end

	-- face the row so the default camera sees it
	root.CFrame = CFrame.lookAt(origin, Vector3.new(center.X, origin.Y, center.Z))

	local text = table.concat(report, "\n")
	print(text)
	return text
end

function PhotoCommand.bindChat(opts)
	if not RunService:IsStudio() then
		return
	end
	local function hook(player)
		player.Chatted:Connect(function(msg)
			local m = msg:lower()
			if m == "/photo" then
				PhotoCommand.run(player, opts)
			elseif m == "/photo clear" then
				PhotoCommand.clear()
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return PhotoCommand
