--!strict
--[[
	A resident of the train (Config/Npcs), built from primitives at `cframe`: feet on
	y = 0, facing the frame's -Z. Anchored and still; the skirt and coat collide so the
	crew walk round them, everything else is decor. Faces that touch are given distinct
	planes, as elsewhere in the train.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Npcs = require(ReplicatedStorage.Shared.Config.Npcs)
local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

export type Figure = { model: Model, body: BasePart }

local NpcFigure = {}

local M = Enum.Material
local DECOR: Kit.Options = { collide = false, shadow = false }

function NpcFigure.build(def: Npcs.NpcDef, cframe: CFrame, parent: Instance): Figure
	local look = def.look :: Npcs.Look
	local model = Kit.model(`Npc_{def.id}`, parent)
	local skin, hair, coat, trim, legs =
		Kit.rgb(look.skin), Kit.rgb(look.hair), Kit.rgb(look.coat), Kit.rgb(look.trim), Kit.rgb(look.legs)
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local function decor(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		local part = Kit.block(model, size, cf, color, DECOR)
		part.Material = material or M.SmoothPlastic
		return part
	end

	-- shoes, a long skirt and a waistcoat over a high collar
	for _, x in { -0.36, 0.36 } do
		decor(Vector3.new(0.5, 0.3, 0.72), at(x, 0.15, -0.12), Color3.fromRGB(30, 26, 24), M.Leather)
	end
	Kit.block(model, Vector3.new(1.6, 2.2, 1.0), at(0, 1.3, 0), legs, { material = M.Fabric, name = "Skirt" })
	local body = Kit.block(
		model,
		Vector3.new(1.8, 1.7, 0.9),
		at(0, 3.2, 0),
		coat,
		{ material = M.Fabric, name = "Body" }
	)
	decor(Vector3.new(1.84, 0.16, 0.94), at(0, 2.42, 0), trim, M.Metal) -- belt
	for i = 0, 2 do
		Kit.ball(model, 0.13, at(0, 3.75 - i * 0.4, -0.47), trim, DECOR)
	end
	decor(Vector3.new(0.6, 0.3, 0.6), at(0, 4.18, 0), skin) -- neck
	decor(Vector3.new(0.9, 0.18, 0.72), at(0, 4.13, 0), Color3.fromRGB(226, 220, 204), M.Fabric) -- collar

	-- arms, the right hand holding the ticket punch, a ledger under the left
	for _, side in { -1, 1 } do
		decor(Vector3.new(0.5, 1.55, 0.6), at(side * 1.16, 3.2, 0), coat, M.Fabric)
		Kit.ball(model, 0.46, at(side * 1.16, 2.3, -0.05), skin, DECOR)
	end
	decor(Vector3.new(0.34, 0.22, 0.5), at(1.16, 2.3, -0.42), trim, M.Metal) -- the punch
	decor(Vector3.new(0.22, 1.0, 0.78), at(-1.5, 3.0, 0), Color3.fromRGB(96, 38, 34), M.Leather) -- ledger

	-- head, a grey bun and a clerk's green eyeshade
	local head = Kit.ball(model, 1.15, at(0, 4.85, 0), skin, DECOR)
	head.Name = "Head"
	for _, x in { -0.22, 0.22 } do
		decor(Vector3.new(0.12, 0.14, 0.06), at(x, 4.92, -0.55), Color3.fromRGB(34, 28, 26))
	end
	Kit.ball(model, 0.62, at(0, 5.05, 0.58), hair, DECOR)
	decor(Vector3.new(1.2, 0.3, 1.0), at(0, 5.33, 0.05), hair, M.Fabric) -- hair under the band
	if look.hat == "Visor" then
		decor(Vector3.new(1.26, 0.16, 1.06), at(0, 5.4, 0.05), trim, M.Metal) -- band
		local shade = decor(
			Vector3.new(1.1, 0.06, 0.62),
			at(0, 5.36, -0.78) * Kit.angles(-14, 0, 0),
			Color3.fromRGB(40, 120, 84),
			M.Glass
		)
		shade.Transparency = 0.25
	end
	model.PrimaryPart = body
	return { model = model, body = body }
end

return NpcFigure
