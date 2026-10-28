--!strict

local Shared = script.Parent.Parent
local Config = require(Shared.Config.CrewClothing)
local Rules = {}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function positiveInteger(n: any): boolean
	return finite(n) and n > 0 and n % 1 == 0
end

local R6_LIMBS: { [string]: boolean } = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

function Rules.available(recipe: Config.Recipe?): boolean
	if recipe == nil or not recipe.validated then
		return false
	end
	if not positiveInteger(recipe.shirt) or not positiveInteger(recipe.pants) then
		return false
	end
	if not positiveInteger(recipe.wornShirt) or not positiveInteger(recipe.wornPants) then
		return false
	end
	if type(recipe.accessories) ~= "table" then
		return false
	end
	if #recipe.accessories > Config.MaxAccessories then
		return false
	end
	local triangles = 0
	for _, accessory in recipe.accessories do
		if accessory.yaw ~= nil and not finite(accessory.yaw) then
			return false
		end
		if not positiveInteger(accessory.mesh) or not positiveInteger(accessory.texture) then
			return false
		end
		if not R6_LIMBS[accessory.limb] or #accessory.size ~= 3 or #accessory.offset ~= 3 then
			return false
		end
		for _, n in accessory.size do
			if not finite(n) or n <= 0 then
				return false
			end
		end
		for _, n in accessory.offset do
			if not finite(n) then
				return false
			end
		end
		if not positiveInteger(accessory.triangles) then
			return false
		end
		triangles += accessory.triangles
	end
	return triangles <= Config.MaxTriangles
end

function Rules.canWear(id: string, owned: { [string]: boolean }?): boolean
	if not Config.Enabled then
		return false
	end
	local recipe = Config.ById[id]
	if not Rules.available(recipe) then
		return false
	end
	return recipe.starter or (owned ~= nil and owned[id] == true)
end

function Rules.resolve(id: any, owned: { [string]: boolean }?): string?
	if type(id) == "string" and Rules.canWear(id, owned) then
		return id
	end
	for _, recipe in Config.List do
		if recipe.starter and Rules.canWear(recipe.id, owned) then
			return recipe.id
		end
	end
	return nil
end

function Rules.migrate(profile: any): any
	if type(profile) ~= "table" then
		return profile
	end
	if type(profile.equipped) ~= "table" then
		profile.equipped = {}
	end
	local chosen = profile.equipped.Uniform
	if type(chosen) == "string" then
		local recipe = Config.ById[chosen]
		if
			recipe == nil
			or (not recipe.starter and not (type(profile.owned) == "table" and profile.owned[chosen] == true))
		then
			profile.equipped.Uniform = Config.Default
		end
	else
		profile.equipped.Uniform = Config.Default
	end
	return profile
end

function Rules.wearAt(stop: number, phase: string): boolean
	return positiveInteger(stop)
		and positiveInteger(Config.WearStop)
		and stop >= Config.WearStop
		and (
			phase == "Junction"
			or phase == "Cruise"
			or phase == "Arrival"
			or phase == "Dwell"
			or phase == "LastCall"
			or phase == "Departure"
			or phase == "Terminus"
		)
end

function Rules.wear(stop: number, phase: string): boolean
	return Config.WearEnabled and Rules.wearAt(stop, phase)
end

return Rules
