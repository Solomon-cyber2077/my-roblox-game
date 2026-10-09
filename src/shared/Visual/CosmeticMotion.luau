--!strict

local CosmeticMotion = {}
local lightBases: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local flameBases: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

local function lerpColor(a: Color3, b: Color3, alpha: number): Color3
	return a:Lerp(b, math.clamp(alpha, 0, 1))
end

function CosmeticMotion.bind(root: Instance): (number) -> ()
	local lights: { { light: Light, base: number, speed: number, amount: number } } = {}
	local cycles: { { part: BasePart, a: Color3, b: Color3, lights: { Light } } } = {}
	local flames: { { part: BasePart, base: number } } = {}

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Light") and descendant.Name == "Glow" then
			lightBases[descendant] = lightBases[descendant] or descendant.Brightness
			local parent = descendant.Parent
			local speed = if parent then parent:GetAttribute("FlickerSpeed") else nil
			local amount = if parent then parent:GetAttribute("FlickerAmount") else nil
			table.insert(lights, {
				light = descendant,
				base = lightBases[descendant] or descendant.Brightness,
				speed = if typeof(speed) == "number" then speed else 5,
				amount = if typeof(amount) == "number" then amount else 0.08,
			})
		elseif descendant:IsA("BasePart") then
			local a = descendant:GetAttribute("CycleA")
			local b = descendant:GetAttribute("CycleB")
			if typeof(a) == "Color3" and typeof(b) == "Color3" then
				local partLights: { Light } = {}
				for _, child in descendant:GetChildren() do
					if child:IsA("Light") then
						table.insert(partLights, child)
					end
				end
				table.insert(cycles, { part = descendant, a = a, b = b, lights = partLights })
			end
			if descendant.Name == "Flame" then
				flameBases[descendant] = flameBases[descendant] or descendant.Transparency
				table.insert(flames, { part = descendant, base = flameBases[descendant] })
			end
		end
	end

	return function(time: number)
		for _, entry in lights do
			local wave = math.sin(time * entry.speed * 6.283)
			entry.light.Brightness = entry.base * (1 + wave * entry.amount)
		end
		for _, entry in cycles do
			local alpha = (math.sin(time * 0.1 * 6.283) + 1) * 0.5
			local color = lerpColor(entry.a, entry.b, alpha)
			entry.part.Color = color
			for _, light in entry.lights do
				light.Color = color
			end
		end
		for _, entry in flames do
			entry.part.Transparency = math.clamp(entry.base + math.sin(time * 9) * 0.06, 0, 1)
		end
	end
end

return table.freeze(CosmeticMotion)
