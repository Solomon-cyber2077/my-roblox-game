--!strict
--[[
	The Outfitter. Brass purchases and equipping go through Logic/Catalog checks.
	Robux purchases use developer products with idempotent receipts: a receipt is
	only reported granted after the profile holding it has been saved.

	Product and game pass ids are bound in Config/Cosmetics after publishing; until
	then those items show as "Coming soon" and no prompt is possible.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Tuning = require(Shared.Config.Tuning)
local Catalog = require(Shared.Logic.Catalog)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)

local ShopService = {}

local productToItem: { [number]: string } = {}
local passToItem: { [number]: string } = {}

local function canShop(player: Player): boolean
	return DataService.GetProfile(player) ~= nil and not Registry.CrewService.IsAlive(player)
end

local function grant(player: Player, itemId: string)
	DataService.Update(player, function(p)
		p.owned[itemId] = true
	end)
	NetService.Fire("Fx", player, "Purchased", { id = itemId })
end

local function trimReceipts(receipts: { [string]: number })
	local list: { { id: string, at: number } } = {}
	for id, at in receipts do
		table.insert(list, { id = id, at = at })
	end
	if #list <= Tuning.Data.ReceiptHistory then
		return
	end
	table.sort(list, function(a, b)
		return a.at < b.at
	end)
	for i = 1, #list - Tuning.Data.ReceiptHistory do
		receipts[list[i].id] = nil
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.WaitForProfile(player, 15)
	if profile == nil or not DataService.IsOnline(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if profile.receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local itemId = productToItem[receipt.ProductId]
	if itemId == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.Update(player, function(p)
		p.owned[itemId] = true
		p.receipts[purchaseId] = os.time()
		trimReceipts(p.receipts)
	end)
	if not DataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	NetService.Fire("Fx", player, "Purchased", { id = itemId })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function syncGamePasses(player: Player)
	for passId, itemId in passToItem do
		local ok, owns =
			pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and owns then
			local profile = DataService.GetProfile(player)
			if profile and not profile.owned[itemId] then
				DataService.Update(player, function(p)
					p.owned[itemId] = true
				end)
			end
		end
	end
end

function ShopService.Init()
	for _, def in Cosmetics.List do
		if def.robux and def.robux.productId then
			productToItem[def.robux.productId] = def.id
		end
		if def.gamePass and def.gamePass.id then
			passToItem[def.gamePass.id] = def.id
		end
	end
end

function ShopService.Start()
	NetService.Handle("ShopPurchase", function(player, itemId: string)
		local profile = DataService.GetProfile(player)
		if profile == nil then
			return
		end
		if Catalog.devUnlocked(player.UserId, RunService:IsStudio()) then
			return
		end
		local day = Catalog.dayNumber(os.time())
		local check, price =
			Catalog.canBuyWithBrass(profile.owned, profile.brass, DataService.Rank(player), itemId, day)
		if check ~= "Ok" or price == nil then
			local messages = {
				Brass = "Not enough Brass yet. Finish runs to earn more.",
				Rank = `Reach Crew Rank {(Cosmetics.ById[itemId] or {} :: any).rank or 1} to buy this.`,
				Owned = "You already own that.",
				NotForBrass = "That item is earned another way.",
			}
			NetService.Fire("Notify", player, "Warning", messages[check] or "That item is unavailable.")
			return
		end
		DataService.Update(player, function(p)
			p.brass -= price
			p.owned[itemId] = true
		end)
		NetService.Fire("Fx", player, "Purchased", { id = itemId, price = price })
	end, canShop)

	NetService.Handle("ShopEquip", function(player, itemId: string)
		local profile = DataService.GetProfile(player)
		local def = Cosmetics.ById[itemId]
		local isDev = Catalog.devUnlocked(player.UserId, RunService:IsStudio())
		if profile == nil or def == nil or Cosmetics.Defaults[def.category] == nil then
			return
		end
		if not Catalog.canUse(profile.owned, itemId, player.UserId, RunService:IsStudio()) then
			return
		end
		if isDev then
			player:SetAttribute("DevCosmetic_" .. def.category, itemId)
		else
			DataService.Update(player, function(p)
				p.equipped[def.category] = itemId
			end)
		end
		if def.category == "Livery" then
			Registry.CosmeticService.RefreshLivery()
		else
			Registry.CosmeticService.Apply(player)
		end
	end, function(player)
		return DataService.GetProfile(player) ~= nil
	end)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local itemId = passToItem[passId]
		if purchased and itemId then
			grant(player, itemId)
		end
	end)
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(syncGamePasses, player)
	end)
end

return ShopService
