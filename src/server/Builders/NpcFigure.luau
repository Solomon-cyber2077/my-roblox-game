--!strict
--[[
	A resident of the train (Config/Npcs), dressed from the shared period kit
	(Builders/OutfitKit) at `cframe`: feet on y = 0, facing the frame's -Z. Anchored and
	still; the body and skirt collide so the crew walk round them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Npcs = require(ReplicatedStorage.Shared.Config.Npcs)
local OutfitKit = require(script.Parent.OutfitKit)

export type Figure = { model: Model, body: BasePart }

local NpcFigure = {}

function NpcFigure.build(def: Npcs.NpcDef, cframe: CFrame, parent: Instance): Figure
	local figure = OutfitKit.figure(parent, cframe, def.look :: Npcs.Look, { armR = 30 })
	figure.model.Name = `Npc_{def.id}`
	return { model = figure.model, body = figure.body }
end

return NpcFigure
