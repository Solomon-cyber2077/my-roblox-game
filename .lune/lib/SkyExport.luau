--[[
	Turns the client's sky into JSON for tools/preview: the Lighting, Atmosphere,
	Clouds and grade values a Scenery/Sky state sets (as AtmosphereController applies
	them), and every enabled BillboardGui on the Scenery/Heavens rig as a tree of
	frames the viewer rasterizes.
]]

local SkyExport = {}

local function rgb(color: any): { number }
	return {
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5),
	}
end

local function round(x: number): number
	return math.floor(x * 10000 + 0.5) / 10000
end

-- The values AtmosphereController.apply writes for a finished state (Sky.finish).
function SkyExport.state(state: any, wind: any, latitude: number): { [string]: any }
	return {
		clock = state.clock,
		latitude = latitude,
		brightness = state.brightness,
		exposure = state.exposure,
		ambient = rgb(state.ambient),
		outdoor = rgb(state.outdoor),
		shiftTop = rgb(state.shift),
		atmosphere = {
			density = state.density,
			offset = 0.25,
			color = rgb(state.air),
			decay = rgb(state.decay),
			glare = state.glare,
			haze = state.haze,
		},
		clouds = {
			cover = state.cover,
			density = state.cloudDensity,
			color = rgb(state.clouds),
			wind = { wind.X, wind.Z },
		},
		stars = state.stars,
		moonSize = 0,
		sunSize = 14,
		rays = state.rays,
		bloom = { intensity = 0.85, size = 30, threshold = 1.05 },
		grades = {
			{ contrast = 0.14 },
			{
				saturation = state.saturation,
				contrast = state.contrast,
				tint = rgb(state.tint),
				brightness = state.lift,
			},
		},
		lightning = state.flash,
		flashColor = rgb(state.flashColor),
	}
end

local function sequenceColors(sequence: any): { { number } }
	local out = {}
	for _, key in sequence.Keypoints do
		local c = rgb(key.Value)
		table.insert(out, { round(key.Time), c[1], c[2], c[3] })
	end
	return out
end

local function sequenceNumbers(sequence: any): { { number } }
	local out = {}
	for _, key in sequence.Keypoints do
		table.insert(out, { round(key.Time), round(key.Value) })
	end
	return out
end

local function udim2(u: any): { number }
	return { round(u.X.Scale), u.X.Offset, round(u.Y.Scale), u.Y.Offset }
end

local function exportNode(node: any): { [string]: any }?
	local out: { [string]: any } = {
		c = node.ClassName,
		s = udim2(node.Size),
		p = udim2(node.Position),
		a = { node.AnchorPoint.X, node.AnchorPoint.Y },
		r = round(node.Rotation),
		bc = rgb(node.BackgroundColor3),
		bt = round(node.BackgroundTransparency),
		z = node.ZIndex,
		k = node.ClipsDescendants,
	}
	local children = {}
	for _, child in node:GetChildren() do
		if child:IsA("UICorner") then
			out.corner = { child.CornerRadius.Scale, child.CornerRadius.Offset }
		elseif child:IsA("UIGradient") and child.Enabled then
			out.grad = {
				c = sequenceColors(child.Color),
				tr = sequenceNumbers(child.Transparency),
				r = child.Rotation,
				o = { round(child.Offset.X), round(child.Offset.Y) },
			}
		elseif child:IsA("GuiObject") and child.Visible then
			local exported = exportNode(child)
			if exported then
				table.insert(children, exported)
			end
		end
	end
	if #children > 0 then
		out.ch = children
	elseif node.BackgroundTransparency >= 0.999 then
		return nil -- nothing to draw
	end
	return out
end

local RESOLUTION: { [string]: number } = { Moon = 1024, Bolt = 1024 }

-- Every enabled BillboardGui hanging on the rig's anchor, with its direction and size.
function SkyExport.heavens(rig: any): { { [string]: any } }
	local out = {}
	for _, attachment in rig.anchor:GetChildren() do
		local gui = attachment:FindFirstChildOfClass("BillboardGui")
		if gui and gui.Enabled then
			local children = {}
			for _, child in gui:GetChildren() do
				if child:IsA("GuiObject") and child.Visible then
					local exported = exportNode(child)
					if exported then
						table.insert(children, exported)
					end
				end
			end
			local position = attachment.Position
			local name = gui.Name
			table.insert(out, {
				name = name,
				dir = { position.Unit.X, position.Unit.Y, position.Unit.Z },
				dist = position.Magnitude,
				brightness = gui.Brightness,
				res = RESOLUTION[name] or (if string.sub(name, 1, 4) == "Glow" then 512 else 640),
				gui = { size = { gui.Size.X.Scale, gui.Size.Y.Scale }, ch = children },
			})
		end
	end
	return out
end

return SkyExport
