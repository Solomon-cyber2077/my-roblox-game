-- Exercise the actual server service with a small, deterministic engine boundary.
-- Geometry and poses remain the real builders; network, time and physics queries are simulated.
local roblox = require("@lune/roblox")
local Loader = require("./Loader")

local function run(): string
	local shared, server = Loader.roots.Shared, Loader.roots.Server
	local tuning = Loader.requireNode(shared.Config.Tuning)
	local difficulty = Loader.requireNode(shared.Logic.DifficultyModel)
	local stations = Loader.requireNode(shared.Config.Stations)
	local layout = Loader.requireNode(shared.Logic.LayoutGen)
	local params = difficulty.params(0.3, stations.List.Halt, 2, nil)
	local plan = layout.generate("Halt", 21, 1)
	local clock = 100
	local space = roblox.Instance.new("Workspace")
	local callbacks = {}
	local prompts = {}
	local loops = {}
	local events = {}
	local checks = 0
	-- Lune stores CFrame but does not derive BasePart.Position; proxy that engine property.
	local wrapped, raw = {}, {}
	local function wrap(instance)
		if typeof(instance) ~= "Instance" then
			return instance
		end
		if wrapped[instance] then
			return wrapped[instance]
		end
		local proxy
		proxy = setmetatable({}, {
			__index = function(_, key)
				if key == "Position" and instance:IsA("BasePart") then
					return instance.CFrame.Position
				end
				local value = instance[key]
				if type(value) == "function" then
					return function(_, ...)
						local args = table.pack(...)
						for i = 1, args.n do
							args[i] = raw[args[i]] or args[i]
						end
						return wrap(value(instance, table.unpack(args, 1, args.n)))
					end
				end
				return wrap(value)
			end,
			__newindex = function(_, key, value)
				instance[key] = raw[value] or value
			end,
		})
		wrapped[instance], raw[proxy] = proxy, instance
		return proxy
	end
	local function check(ok: boolean, message: string)
		assert(ok, message)
		checks += 1
	end
	local function signal(callback)
		return {
			Connect = function(_, fn)
				if callback then
					callback(fn)
				end
				return { Disconnect = function() end }
			end,
		}
	end
	local function body()
		local model = roblox.Instance.new("Model")
		local root = roblox.Instance.new("Part")
		root.Name, root.Size = "HumanoidRootPart", roblox.Vector3.new(2, 2, 1)
		root.CFrame = roblox.CFrame.new(0, 3, 80)
		root.Parent = model
		local leg = roblox.Instance.new("Part")
		leg.Name, leg.Size, leg.Parent = "Left Leg", roblox.Vector3.new(1, 2, 1), model
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Health, humanoid.MaxHealth = 100, 100
		humanoid.Parent = model
		model.Parent = space
		return wrap(model), wrap(root), wrap(humanoid)
	end
	local character, root, humanoid = body()
	local allyCharacter, allyRoot = body()
	local victim =
		{ Name = "Victim", DisplayName = "Victim", UserId = 1, Character = character, Parent = space }
	local ally =
		{ Name = "Ally", DisplayName = "Ally", UserId = 2, Character = allyCharacter, Parent = space }
	local players = { PlayerRemoving = signal() }
	function players:GetPlayers()
		return { victim, ally }
	end
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return clock
	end)
	roblox.implementMethod("Workspace", "GetPartBoundsInBox", function()
		return {}
	end)
	roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction)
		if direction.Y < -6 then
			return { Position = roblox.Vector3.new(origin.X, 0, origin.Z), Normal = roblox.Vector3.yAxis }
		end
		return nil
	end)
	roblox.implementMethod("Humanoid", "MoveTo", function() end)
	roblox.implementMethod("Humanoid", "TakeDamage", function(self, amount)
		self.Health = math.max(self.Health - amount, 0)
	end)
	local registry = {
		DevService = {
			IsGod = function()
				return false
			end,
		},
		CrewService = {
			IsAlive = function(player)
				return player.Character:FindFirstChildOfClass("Humanoid").Health > 0
			end,
			IsAboard = function()
				return false
			end,
			AlivePlayers = function()
				return { victim }
			end,
		},
	}
	local net = {
		Handle = function(name, fn)
			callbacks[name] = fn
		end,
		Fire = function(...)
			table.insert(events, { ... })
		end,
		FireAll = function(...)
			table.insert(events, { ... })
		end,
	}
	local station = {
		Cleared = signal(),
		Plan = function()
			return plan
		end,
		Info = function()
			return { startedAt = clock }
		end,
		ToLocal = function(point)
			return point
		end,
		ToWorld = function(x, y, z)
			return roblox.Vector3.new(x, y, z)
		end,
		IsCollapsed = function()
			return false
		end,
	}
	local service = Loader.loadFile("src/server/Services/HollowService.luau", server.Services.HollowService, {
		game = {
			GetService = function(_, name)
				if name == "Workspace" then
					return space
				end
				if name == "Players" then
					return players
				end
				if name == "ReplicatedStorage" then
					return { Shared = shared }
				end
				return {}
			end,
		},
		require = function(node)
			if node == server.Builders.HollowBuilder then
				local builder = Loader.requireNode(node)
				return {
					rootHeight = builder.rootHeight,
					build = function(...)
						local model, monsterHumanoid = builder.build(...)
						return wrap(model), wrap(monsterHumanoid)
					end,
				}
			end
			if node == shared.Util.Safe then
				return {
					call = function(_, fn, ...)
						return fn(...)
					end,
				}
			end
			if node == server.Registry then
				return registry
			end
			if node == server.Services.NetService then
				return net
			end
			if node == server.Services.StationService then
				return station
			end
			return Loader.requireNode(node)
		end,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		os = {
			clock = function()
				return clock
			end,
		},
		task = {
			spawn = function(fn)
				table.insert(loops, coroutine.create(fn))
			end,
			wait = function()
				coroutine.yield()
				return 1 / tuning.Hollow.ThinkHz
			end,
		},
		Instance = {
			new = function(class)
				if class ~= "ProximityPrompt" then
					return wrap(roblox.Instance.new(class))
				end
				local prompt = {
					Destroy = function(self)
						self.destroyed = true
					end,
					SetAttribute = function() end,
				}
				prompt.Triggered = signal(function(fn)
					prompt.trigger = fn
				end)
				table.insert(prompts, prompt)
				return prompt
			end,
		},
	})
	service.Init()
	service.Start()
	service.Configure(params)
	check(#loops == 1, "one server thinking loop")
	local function tick(seconds: number)
		clock += seconds
		local ok, err = coroutine.resume(loops[1])
		assert(ok, err)
	end
	tick(0) -- enter the loop's first wait
	local function seize(kind: string)
		humanoid.Health = 100
		root.CFrame = roblox.CFrame.new(0, 3, 80)
		check(service.DevGrab(victim, kind), `could not seize with {kind}`)
		check(service.IsHeld(victim) and root.Anchored, "grab must immobilize its victim")
		return prompts[#prompts]
	end
	for _, kind in { "Stalker", "Crawler", "Brute" } do
		local prompt = seize(kind)
		allyRoot.CFrame = roblox.CFrame.new(1000, 3, 0)
		prompt.trigger(ally)
		check((character:GetAttribute("GrabEscape") or 0) == 0, "distant helper must not pry")
		allyRoot.CFrame = root.CFrame
		prompt.trigger(ally)
		local once = character:GetAttribute("GrabEscape")
		prompt.trigger(ally)
		check(character:GetAttribute("GrabEscape") == once, "helper spam must be limited")
		for _ = 1, 30 do
			callbacks.Struggle(victim)
		end
		check(not service.IsHeld(victim) and not root.Anchored, "struggle must release both state and body")
		check(
			character:GetAttribute("GrabStyle") == nil and character:GetAttribute("GrabOutcome") == "Escaped",
			"escape attributes"
		)
		check(
			root.CFrame.UpVector.Y > 0.99 and root.Position.Y >= 3,
			"escape must stand the victim above ground"
		)
		check(prompt.destroyed == true, "rescue prompt must be removed")
		service.Clear()
		service.Configure(params)
	end
	-- One attacker must rotate through its three holds rather than repeating its favourite.
	seize("Stalker")
	local styles = {}
	for attempt = 1, 3 do
		local style = character:GetAttribute("GrabStyle")
		check(style ~= nil and not styles[style], "a repeated attacker must vary its holds")
		styles[style] = true
		for _ = 1, 30 do
			callbacks.Struggle(victim)
		end
		if attempt < 3 then
			root.CFrame = roblox.CFrame.new(0, 3, 80)
			tick(tuning.Grab.Grace + 1)
			tick(1)
		end
	end
	service.Clear()
	service.Configure(params)
	local rescue = seize("Brute")
	for _ = 1, 12 do
		if not service.IsHeld(victim) then
			break
		end
		allyRoot.CFrame = root.CFrame
		clock += tuning.Grab.PryInterval + 0.01
		rescue.trigger(ally)
		tick(0.08)
	end
	check(not service.IsHeld(victim) and not root.Anchored, "a nearby crewmate can complete a rescue")
	service.Clear()
	service.Configure(params)
	seize("Crawler")
	service.Stun(root.Position, 30, 2)
	check(not service.IsHeld(victim) and not root.Anchored, "flash releases the grab")
	check(character:GetAttribute("GrabOutcome") == "Flash", "flash outcome")
	service.Clear()
	service.Configure(params)
	seize("Brute")
	humanoid.Health = 0
	tick(0.1)
	tick(3)
	check(not service.IsHeld(victim) and not root.Anchored, "a dead victim must eventually fall free")
	service.Clear()
	service.Configure(params)
	seize("Stalker")
	local replacement = body()
	victim.Character = replacement
	tick(0.1)
	check(not service.IsHeld(victim) and not root.Anchored, "respawning must release the old character")
	service.Clear()
	check(#events > 0, "grab outcomes must be sent to clients")
	space:Destroy()
	return `server grab lifecycle: {checks} checks (struggle, rescue distance/rate, flash, death, respawn)`
end

return run
