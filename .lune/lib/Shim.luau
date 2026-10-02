--[[
	Lets the game's builders run under Lune: puts Lune's Roblox datatypes into the
	module loader's globals, plus a small shim for the few engine globals the
	builders touch (game:GetService("ReplicatedStorage"), Random, warn,
	Humanoid:SetStateEnabled).

	Install it before loading any client or server module (globals are copied
	into a module's environment when it loads).
]]

local roblox = require("@lune/roblox")

local Loader = require("./Loader")

local Shim = {}

local installed = false

--[[
	Lune's CFrame.lookAt (and CFrame.new(position, target)) come out with the wrong
	basis, so the builders get them from here instead, following Roblox: the look
	vector toward the target, right = look x up, up = right x look.
]]
local RealCFrame = roblox.CFrame
local function lookAt(at: any, target: any, up: any?): any
	local look = (target - at).Unit
	local right = look:Cross(up or roblox.Vector3.yAxis)
	if right.Magnitude < 1e-6 then
		-- straight up or down: any perpendicular will do
		right = look:Cross(roblox.Vector3.zAxis)
	end
	right = right.Unit
	return RealCFrame.fromMatrix(at, right, right:Cross(look).Unit, -look)
end

function Shim.install()
	if installed then
		return
	end
	installed = true
	local Rng = Loader.requireNode(Loader.roots.Shared.Util.Rng)
	local env = Loader.env
	for _, name in
		{
			"Instance",
			"Vector3",
			"Vector2",
			"CFrame",
			"Color3",
			"Enum",
			"NumberSequence",
			"NumberSequenceKeypoint",
			"ColorSequence",
			"ColorSequenceKeypoint",
			"NumberRange",
			"UDim",
			"UDim2",
			"Font",
			"BrickColor",
			"PhysicalProperties",
		}
	do
		env[name] = (roblox :: any)[name]
	end
	env.CFrame = setmetatable({
		lookAt = lookAt,
		new = function(...)
			local a, b = ...
			if select("#", ...) == 2 and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
				return lookAt(a, b)
			end
			return RealCFrame.new(...)
		end,
	}, { __index = RealCFrame })

	local RandomShim = {}
	RandomShim.__index = RandomShim
	function RandomShim.new(seed: number?)
		return setmetatable({ rng = Rng.new(seed or 0) }, RandomShim)
	end
	function RandomShim.NextNumber(self: any, lo: number?, hi: number?): number
		local x = self.rng:next()
		if lo ~= nil and hi ~= nil then
			return lo + x * (hi - lo)
		end
		return x
	end
	function RandomShim.NextInteger(self: any, lo: number, hi: number): number
		return self.rng:int(lo, hi)
	end
	env.Random = RandomShim
	env.warn = function(...)
		print("[warn]", ...)
	end
	env.game = {
		GetService = function(_, name: string)
			if name == "ReplicatedStorage" then
				return { Shared = Loader.roots.Shared }
			end
			error(`the Lune shim has no service {name}`)
		end,
	}
	roblox.implementMethod("Humanoid", "SetStateEnabled", function() end)
end

return Shim
