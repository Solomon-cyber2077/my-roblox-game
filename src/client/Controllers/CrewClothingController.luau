--!strict

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.CrewClothing)
local Rules = require(Shared.Logic.CrewClothing)
local Safe = require(Shared.Util.Safe)

local CrewClothingController = {}

local phase = ""
local stop = 0
local tokens: { [Model]: number } = {}
local connections: { [Model]: { RBXScriptConnection } } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local refreshers: { [Model]: () -> () } = {}

local function asset(id: number): string
	return `rbxassetid://{id}`
end

local function clear(model: Model)
	local list = connections[model]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
	end
	connections[model] = nil
	refreshers[model] = nil
	tokens[model] = nil
end

local function apply(model: Model, recipe: Config.Recipe, worn: boolean)
	if model:FindFirstChild("CrewUniform") == nil or model:GetAttribute("CrewUniformId") ~= recipe.id then
		return
	end
	local shirt = model:FindFirstChild("CrewUniformShirt")
	local pants = model:FindFirstChild("CrewUniformPants")
	if shirt == nil or not shirt:IsA("Shirt") or pants == nil or not pants:IsA("Pants") then
		return
	end
	local shirtId = if worn then recipe.wornShirt else recipe.shirt
	local pantsId = if worn then recipe.wornPants else recipe.pants
	if shirtId <= 0 or pantsId <= 0 then
		return
	end
	shirt.ShirtTemplate = asset(shirtId)
	pants.PantsTemplate = asset(pantsId)
end

local function watch(model: Model)
	local token = (tokens[model] or 0) + 1
	clear(model)
	tokens[model] = token
	local list: { RBXScriptConnection } = {}
	connections[model] = list
	local loaded = false
	local loading = false
	local function refresh()
		local id = model:GetAttribute("CrewUniformId")
		local recipe = if type(id) == "string" then Config.ById[id] else nil
		if recipe == nil or recipe.shirt <= 0 or recipe.pants <= 0 then
			return
		end
		if loaded then
			apply(model, recipe, Rules.wear(stop, phase))
			return
		end
		if loading then
			return
		end
		loading = true
		task.defer(function()
			Safe.call("CrewClothingPreload", function()
				local success = true
				ContentProvider:PreloadAsync({
					asset(recipe.shirt),
					asset(recipe.pants),
					asset(recipe.wornShirt),
					asset(recipe.wornPants),
				}, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then
						success = false
					end
				end)
				if success and tokens[model] == token and model.Parent ~= nil then
					loaded = true
					apply(model, recipe, Rules.wear(stop, phase))
				end
			end)
			loading = false
		end)
	end
	refreshers[model] = refresh
	table.insert(
		list,
		model:GetAttributeChangedSignal("CrewUniformId"):Connect(function()
			watch(model)
		end)
	)
	table.insert(
		list,
		model.ChildAdded:Connect(function(child)
			if
				child.Name == "CrewUniform"
				or child.Name == "CrewUniformShirt"
				or child.Name == "CrewUniformPants"
			then
				refresh()
			end
		end)
	)
	refresh()
end

local function watchPlayer(player: Player)
	local list: { RBXScriptConnection } = {}
	playerConnections[player] = list
	table.insert(list, player.CharacterAdded:Connect(watch))
	table.insert(list, player.CharacterRemoving:Connect(clear))
	if player.Character then
		watch(player.Character)
	end
end

local function refreshLoaded()
	for model, refresh in refreshers do
		if model.Parent ~= nil then
			refresh()
		end
	end
end

function CrewClothingController.Init() end

function CrewClothingController.Start()
	if not Config.Enabled or not Config.WearEnabled then
		return
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local list = playerConnections[player]
		if list then
			for _, connection in list do
				connection:Disconnect()
			end
		end
		playerConnections[player] = nil
		if player.Character then
			clear(player.Character)
		end
	end)
	local state = require(script.Parent.StateController)
	state.Observe("public", { "run", "phase" }, function(value)
		phase = if type(value) == "string" then value else ""
		refreshLoaded()
	end)
	state.Observe("public", { "run", "stationsCleared" }, function(value)
		stop = if type(value) == "number" then value else 0
		refreshLoaded()
	end)
end

return CrewClothingController
