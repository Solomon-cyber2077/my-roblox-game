--!strict
--[[
	The Outfitter (cosmetic shop).

	Flow: category tab -> item grid -> preview + action. The action button always
	says exactly what will happen: BUY 600, EQUIP, EQUIPPED, RANK 15, EARN IT
	(milestone and charter items show their unlock path), ROBUX 149, or COMING
	SOON for paid items whose product id is not bound yet. Purchases are
	confirmed by the server (Fx "Purchased"); failures arrive as notifications.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Catalog = require(Shared.Logic.Catalog)
local Rank = require(Shared.Logic.Rank)
local Format = require(Shared.Util.Format)
local CosmeticModels = require(Shared.Visual.CosmeticModels)
local Kit = require(Shared.Visual.Kit)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Outfitter = {}

local modal: Modal.Modal
local selectedCategory = "Lantern"
local selectedId: string? = nil

local function today(): number
	return Catalog.dayNumber(os.time())
end

function Outfitter.mount(gui: ScreenGui)
	local State = Registry.StateController
	modal = Modal.new(gui, "Outfitter", Vector2.new(860, 560))

	local balance = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 20,
		Color = Theme.Color.ink,
		Position = UDim2.new(1, -116, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(220, 52),
		XAlign = Enum.TextXAlignment.Right,
	})
	balance.ZIndex = 34
	balance.Parent = modal.header

	local tabs = Ui.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, ZIndex = 32, Parent = modal.body }
	)
	Ui.list(Enum.FillDirection.Horizontal, 8).Parent = tabs

	local grid = Ui.new("ScrollingFrame", {
		Size = UDim2.new(0.58, 0, 1, -48),
		Position = UDim2.fromOffset(0, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
		Parent = modal.body,
	})
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 96),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local preview = Ui.new("Frame", {
		Size = UDim2.new(0.4, 0, 1, -48),
		Position = UDim2.new(1, 0, 0, 48),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Color.steelLight,
		BackgroundTransparency = 0.2,
		ZIndex = 32,
		Parent = modal.body,
	})
	Ui.corner().Parent = preview
	local viewport = Ui.new("ViewportFrame", {
		Size = UDim2.new(1, -20, 0, 190),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.Color.steel,
		BackgroundTransparency = 0.2,
		Ambient = Color3.fromRGB(120, 112, 104),
		LightColor = Color3.fromRGB(255, 232, 200),
		LightDirection = Vector3.new(-1, -1, -0.8),
		ZIndex = 33,
		Parent = preview,
	})
	Ui.corner().Parent = viewport
	local previewName = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 22,
		Position = UDim2.fromOffset(14, 210),
		Size = UDim2.new(1, -28, 0, 26),
	})
	previewName.ZIndex = 33
	previewName.Parent = preview
	local previewRarity = Ui.text({
		Text = "",
		Font = Theme.Font.bodyBold,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 236),
		Size = UDim2.new(1, -28, 0, 16),
	})
	previewRarity.ZIndex = 33
	previewRarity.Parent = preview
	local previewDesc = Ui.text({
		Text = "",
		TextSize = 15,
		Color = Theme.Color.textDim,
		Position = UDim2.fromOffset(14, 258),
		Size = UDim2.new(1, -28, 0, 60),
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
	})
	previewDesc.ZIndex = 33
	previewDesc.Parent = preview
	local previewUnlock = Ui.text({
		Text = "",
		Font = Theme.Font.type,
		TextSize = 14,
		Color = Theme.Color.brassLight,
		Position = UDim2.fromOffset(14, 318),
		Size = UDim2.new(1, -28, 0, 18),
	})
	previewUnlock.ZIndex = 33
	previewUnlock.Parent = preview
	local action = Ui.button("", "Primary", nil, {
		Size = UDim2.new(1, -28, 0, 44),
		Position = UDim2.new(0, 14, 1, -14),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 20,
	})
	action.ZIndex = 34
	action.Parent = preview

	local spin = 0
	local previewModel: Model? = nil
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local function setPreview(def: Cosmetics.CosmeticDef)
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
		for _, child in viewport:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local look = def.look
		local model: Model? = nil
		if def.category == "Lantern" then
			model = CosmeticModels.lantern(look, CFrame.new(0, 0.9, 0))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 4.2), Vector3.new(0, 0.2, 0))
		elseif def.category == "Headwear" then
			local holder = Kit.model("Head")
			local head = Kit.block(
				holder,
				Vector3.new(1.2, 1.2, 1.2),
				CFrame.new(0, -0.6, 0),
				Color3.fromRGB(204, 170, 140),
				{ collide = false }
			)
			local _ = head
			local hat = CosmeticModels.headwear(look, CFrame.new())
			if hat then
				hat.Parent = holder
			end
			model = holder
			camera.CFrame = CFrame.lookAt(Vector3.new(2.6, 1.2, -3.4), Vector3.new(0, 0, 0))
		else
			-- Trails and liveries preview as colour swatches.
			local colors: { Color3 } = {}
			if def.category == "Trail" then
				if look.color then
					table.insert(colors, Kit.rgb(look.color))
					table.insert(colors, Kit.rgb(look.color2))
				end
			else
				for _, key in { "body", "trim", "roof", "accent" } do
					table.insert(colors, Kit.rgb(look[key]))
				end
			end
			for i, color in colors do
				local swatch = Ui.new("Frame", {
					Size = UDim2.new(1 / math.max(#colors, 1), -8, 1, -20),
					Position = UDim2.new((i - 1) / math.max(#colors, 1), 4, 0, 10),
					BackgroundColor3 = color,
					ZIndex = 34,
					Parent = viewport,
				})
				Ui.corner().Parent = swatch
			end
		end
		if model then
			model.Parent = viewport
			previewModel = model
		end
	end

	local function actionFor(
		def: Cosmetics.CosmeticDef,
		profile: { [string]: any }
	): (string, string, (() -> ())?)
		local owned = profile.owned or {}
		local equipped = profile.equipped or {}
		if Catalog.isOwned(owned, def.id) then
			if equipped[def.category] == def.id then
				return "EQUIPPED", "Secondary", nil
			end
			return "EQUIP", "Primary", function()
				Net.Fire("ShopEquip", def.id)
			end
		end
		if def.brass then
			local rank = Rank.fromXp(profile.xp or 0)
			local check, price = Catalog.canBuyWithBrass(owned, profile.brass or 0, rank, def.id, today())
			if check == "Rank" then
				return `CREW RANK {def.rank}`, "Secondary", nil
			end
			return `BUY · {Format.thousands(price or def.brass)}`,
				if check == "Ok" then "Primary" else "Secondary",
				if check == "Ok"
					then function()
						Net.Fire("ShopPurchase", def.id)
					end
					else nil
		end
		if def.robux then
			local productId = def.robux.productId
			if productId then
				return `ROBUX · {def.robux.price}`,
					"Primary",
					function()
						MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
					end
			end
			return "COMING SOON", "Secondary", nil
		end
		if def.gamePass then
			local passId = def.gamePass.id
			if passId then
				return `ROBUX · {def.gamePass.price}`,
					"Primary",
					function()
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passId)
					end
			end
			return "COMING SOON", "Secondary", nil
		end
		return "EARN IT", "Secondary", nil
	end

	local actionConnection: RBXScriptConnection? = nil

	local function renderPreview()
		local profile = State.GetPrivate({ "profile" }) or {}
		local def = Cosmetics.ById[selectedId or ""]
		if def == nil then
			return
		end
		setPreview(def)
		previewName.Text = string.upper(def.name)
		previewRarity.Text = string.upper(def.rarity)
		previewRarity.TextColor3 = Theme.Rarity[def.rarity]
		previewDesc.Text = def.description
		previewUnlock.Text = if Catalog.isOwned(profile.owned or {}, def.id)
			then "In your locker"
			else Catalog.unlockText(def)
		local text, style, onClick = actionFor(def, profile)
		action.Text = text
		action.BackgroundColor3 = if style == "Primary" then Theme.Color.brass else Theme.Color.steelLine
		action.TextColor3 = if style == "Primary" then Theme.Color.ink else Theme.Color.white
		Ui.setButtonEnabled(action, onClick ~= nil)
		if actionConnection then
			actionConnection:Disconnect()
		end
		if onClick then
			actionConnection = action.Activated:Connect(onClick)
		end
	end

	local function renderGrid()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local profile = State.GetPrivate({ "profile" }) or {}
		balance.Text = `{Format.thousands(profile.brass or 0)} BRASS`
		local specials = Catalog.dailySpecials(today())
		local items = {}
		for _, def in Cosmetics.List do
			if def.category == selectedCategory then
				table.insert(items, def)
			end
		end
		table.sort(items, function(a, b)
			local ra, rb = Cosmetics.RarityOrder[a.rarity], Cosmetics.RarityOrder[b.rarity]
			if ra ~= rb then
				return ra < rb
			end
			return a.name < b.name
		end)
		if
			selectedId == nil
			or Cosmetics.ById[selectedId] == nil
			or Cosmetics.ById[selectedId].category ~= selectedCategory
		then
			selectedId = if items[1] then items[1].id else nil
		end
		for i, def in items do
			local owned = Catalog.isOwned(profile.owned or {}, def.id)
			local equipped = (profile.equipped or {})[def.category] == def.id
			local cardButton = Ui.new("TextButton", {
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = if def.id == selectedId then Theme.Color.brassLight else Theme.Color.paper,
				LayoutOrder = i,
				ZIndex = 33,
				Parent = grid,
			})
			Ui.corner().Parent = cardButton
			Ui.new("Frame", {
				Size = UDim2.new(1, 0, 0, 5),
				BackgroundColor3 = Theme.Rarity[def.rarity],
				BorderSizePixel = 0,
				ZIndex = 34,
				Parent = cardButton,
			})
			local title = Ui.text({
				Text = def.name,
				Font = Theme.Font.display,
				TextSize = 16,
				Color = Theme.Color.ink,
				Position = UDim2.fromOffset(10, 12),
				Size = UDim2.new(1, -20, 0, 20),
			})
			title.TextTruncate = Enum.TextTruncate.AtEnd
			title.ZIndex = 34
			title.Parent = cardButton
			local tagText, tagColor
			if equipped then
				tagText, tagColor = "EQUIPPED", Theme.Color.go
			elseif owned then
				tagText, tagColor = "OWNED", Theme.Color.inkSoft
			elseif def.brass then
				local price = Catalog.brassPrice(def.id, today()) or def.brass
				tagText = `{Format.thousands(price)} BRASS`
				tagColor = Theme.Color.ink
				if table.find(specials, def.id) then
					tagText = `TODAY {Format.thousands(price)}`
					tagColor = Theme.Color.signal
				end
			elseif def.robux or def.gamePass then
				tagText, tagColor = "ROBUX", Theme.Color.ink
			else
				tagText, tagColor = "EARNED", Theme.Color.inkSoft
			end
			local tag = Ui.text({
				Text = tagText,
				Font = Theme.Font.bodyBold,
				TextSize = 13,
				Color = tagColor,
				Position = UDim2.new(0, 10, 1, -26),
				Size = UDim2.new(1, -20, 0, 18),
			})
			tag.ZIndex = 34
			tag.Parent = cardButton
			local rarity = Ui.text({
				Text = string.upper(def.rarity),
				Font = Theme.Font.body,
				TextSize = 12,
				Color = Theme.Color.inkSoft,
				Position = UDim2.fromOffset(10, 34),
				Size = UDim2.new(1, -20, 0, 14),
			})
			rarity.ZIndex = 34
			rarity.Parent = cardButton
			cardButton.Activated:Connect(function()
				selectedId = def.id
				renderGrid()
			end)
		end
		renderPreview()
	end

	local function renderTabs()
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for i, category in Cosmetics.Categories do
			local tab = Ui.button(
				string.upper(category),
				if category == selectedCategory then "Paper" else "Secondary",
				function()
					selectedCategory = category
					selectedId = nil
					renderTabs()
					renderGrid()
				end,
				{ Size = UDim2.fromOffset(120, 34), LayoutOrder = i, TextSize = 16 }
			)
			tab.ZIndex = 34
			tab.Parent = tabs
		end
	end

	modal.onOpen = function()
		renderTabs()
		renderGrid()
	end
	State.Observe("private", { "profile" }, function()
		if modal:isOpen() then
			renderGrid()
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		if modal:isOpen() and previewModel and previewModel.PrimaryPart then
			spin += dt * 0.8
			previewModel:PivotTo(CFrame.new(previewModel:GetPivot().Position) * CFrame.Angles(0, spin, 0))
		end
	end)
end

function Outfitter.open()
	modal:open()
end

return Outfitter
