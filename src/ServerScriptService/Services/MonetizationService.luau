--[[
	MonetizationService.luau
	Cosmetics and shop catalog manager.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)

local MonetizationService = {}
local shopRemote = nil
local dataServiceRef = nil
local analyticsRef = nil

-- Server-side ShopEvent handler (CLIENT -> SERVER: OpenShop / Buy;
-- SERVER -> CLIENT: ShopData / PurchaseResult). All purchases are validated
-- here against DataStore-backed coins — no client-side currency, no Robux.
function MonetizationService.Init(remotesFolder: Folder, dataService, analyticsService)
	dataServiceRef = dataService
	analyticsRef = analyticsService
	shopRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.ShopEvent)
	if not shopRemote then
		warn("[SHOP] ShopEvent remote not found!")
		return
	end

	shopRemote.OnServerEvent:Connect(function(player: Player, data: table)
		if type(data) ~= "table" then return end
		local action = data.Action

		if action == "OpenShop" then
			if analyticsRef then
				analyticsRef.TrackEvent(Constants.AnalyticsEvents.ShopOpened, { Player = player.Name })
			end
			shopRemote:FireClient(player, {
				Action = "ShopData",
				Coins = MonetizationService.GetCoins(player),
				Owned = dataServiceRef and dataServiceRef.GetData(player) and dataServiceRef.GetData(player).Cosmetics or {},
			})

		elseif action == "Buy" then
			local category = data.Category
			local itemId = data.Id
			if type(category) ~= "string" or type(itemId) ~= "string" then return end

			local success, message, newCoins = MonetizationService.PurchaseCosmetic(player, category, itemId, dataServiceRef)
			if success and analyticsRef then
				analyticsRef.TrackEvent(Constants.AnalyticsEvents.CosmeticPurchased, {
					Player = player.Name,
					Category = category,
					Id = itemId,
				})
			end
			shopRemote:FireClient(player, {
				Action = "PurchaseResult",
				Success = success,
				Message = message,
				Coins = newCoins or MonetizationService.GetCoins(player),
				Owned = dataServiceRef and dataServiceRef.GetData(player) and dataServiceRef.GetData(player).Cosmetics or {},
			})
		end
	end)

	print("[SHOP] MonetizationService initialized (cosmetic-only, server-validated).")
end

function MonetizationService.GetCoins(player: Player): number
	if not dataServiceRef then return 0 end
	local data = dataServiceRef.GetData(player)
	return data and data.Coins or 0
end

function MonetizationService.GetCatalog()
	return Config.ShopCatalog
end

function MonetizationService.PurchaseCosmetic(player: Player, itemCategory: string, itemId: string, dataService)
	local data = dataService.GetData(player)
	if not data then return false, "No Data" end
	
	local catalogCategory = Config.ShopCatalog[itemCategory]
	if not catalogCategory then return false, "Invalid Category" end
	
	local targetItem = nil
	for _, item in ipairs(catalogCategory) do
		if item.Id == itemId then
			targetItem = item
			break
		end
	end
	
	if not targetItem then return false, "Item Not Found" end
	
	if data.Coins < targetItem.Price then
		return false, "Insufficient Coins"
	end
	
	-- Deduct coins and record ownership
	data.Coins = data.Coins - targetItem.Price
	data.Cosmetics[itemCategory] = targetItem.Id
	
	return true, "Success", data.Coins
end

return MonetizationService
