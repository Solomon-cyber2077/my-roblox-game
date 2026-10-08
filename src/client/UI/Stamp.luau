--!strict
--[[
	A voter's rubber stamp: a round ink mark holding their headshot (fetched once and cached)
	or, until it arrives, their initials. The local player's stamp is larger and ringed.
	Stamp.land slams one down (scale 1.8 -> 1 in about 0.12 s) at its own seeded angle.
	Host-agnostic: the ballot uses it today, the station board and summary can too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TicketModel = require(ReplicatedStorage.Shared.Logic.TicketModel)

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Stamp = {}

local INK = Color3.fromRGB(38, 58, 120)
local SIZE = 34
local MINE_SIZE = 42
local LAND_SECONDS = 0.12
local LAND_FROM = 1.8
local MAX_TILT = 14 -- degrees either way

local headshots: { [number]: string } = {}
local pending: { [number]: { ImageLabel } } = {}

-- Fills `image` with the user's headshot, from the cache or once it has been fetched.
local function headshot(userId: number, image: ImageLabel)
	local cached = headshots[userId]
	if cached then
		image.Image = cached
		return
	end
	local waiting = pending[userId]
	if waiting then
		table.insert(waiting, image)
		return
	end
	pending[userId] = { image }
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		local list: { ImageLabel } = pending[userId] or {}
		pending[userId] = nil
		if ok and type(content) == "string" then
			headshots[userId] = content
			for _, waiter in list do
				if waiter.Parent then
					waiter.Image = content
				end
			end
		end
	end)
end

local function initials(name: string?): string
	if name == nil or name == "" then
		return "?"
	end
	local first = string.match(name, "%a") or string.sub(name, 1, 1)
	local second = string.match(name, "[%l%d][_%s]*(%u)") or ""
	return string.upper(first .. second)
end

export type Props = { key: string, name: string?, mine: boolean?, Position: UDim2?, ZIndex: number? }

function Stamp.new(props: Props): Frame
	local size = if props.mine then MINE_SIZE else SIZE
	local z = props.ZIndex or 6
	local mark = Ui.new("Frame", {
		Name = `Stamp_{props.key}`,
		Size = UDim2.fromOffset(size, size),
		Position = props.Position or UDim2.new(),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = (TicketModel.hash(props.key) * 2 - 1) * MAX_TILT,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = z,
	})
	Ui.corner(size // 2).Parent = mark
	Ui.stroke(INK, 2, 0.15).Parent = mark
	local letters = Ui.text({
		Name = "Initials",
		Text = initials(props.name),
		Font = Font.new("rbxasset://fonts/families/Arvo.json", Enum.FontWeight.Bold),
		TextSize = if props.mine then 16 else 13,
		Color = INK,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	letters.ZIndex = z + 1
	letters.Parent = mark
	local photo = Ui.new("ImageLabel", {
		Name = "Headshot",
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ImageColor3 = Color3.fromRGB(150, 165, 215), -- inked over, like the rest of the stamp
		ImageTransparency = 0.15,
		ZIndex = z + 2,
		Parent = mark,
	})
	Ui.corner(size // 2).Parent = photo
	photo:GetPropertyChangedSignal("Image"):Connect(function()
		letters.Visible = photo.Image == ""
	end)
	local userId = tonumber(props.key)
	if userId and userId > 0 then
		headshot(userId, photo)
	end
	if props.mine then
		local ring = Ui.new("Frame", {
			Name = "Ring",
			Size = UDim2.new(1, 8, 1, 8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = mark,
		})
		Ui.corner((size + 8) // 2).Parent = ring
		Ui.stroke(Theme.Color.brass, 2, 0).Parent = ring
	end
	Ui.new("UIScale", { Name = "Land", Parent = mark })
	return mark
end

-- Slams the stamp down: big and faint to its size and full ink.
function Stamp.land(mark: Frame)
	local scale = mark:FindFirstChild("Land") :: UIScale?
	if scale == nil then
		return
	end
	scale.Scale = LAND_FROM
	mark.BackgroundTransparency = 1
	local info = TweenInfo.new(LAND_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Ui.tween(scale, { Scale = 1 }, info)
	Ui.tween(mark, { BackgroundTransparency = 0.82 }, info)
end

return Stamp
