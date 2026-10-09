--[[
	DataService.luau
	Server-authoritative DataStore persistence manager for player stats and settings.
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
local playerData = {}
local dataStore = nil

-- Attempt safely getting DataStore (handles Studio disabled datastore)
pcall(function()
	dataStore = DataStoreService:GetDataStore("DontWakeHim_PlayerData_v1")
end)

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		DataService.LoadData(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		DataService.SaveData(player)
		playerData[player.UserId] = nil
	end)
end

function DataService.LoadData(player: Player)
	local userId = player.UserId
	local defaultData = {
		Coins = Config.DataDefaults.Coins,
		Escapes = Config.DataDefaults.Escapes,
		Deaths = Config.DataDefaults.Deaths,
		BestTime = Config.DataDefaults.BestTime,
		Cosmetics = Config.DataDefaults.Cosmetics,
		Settings = Config.DataDefaults.Settings,
	}
	
	if not dataStore then
		playerData[userId] = defaultData
		return defaultData
	end
	
	local key = "Player_" .. userId
	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)
	
	if success and result and type(result) == "table" then
		-- Merge saved data with defaults for version safety
		for k, v in pairs(defaultData) do
			if result[k] == nil then
				result[k] = v
			end
		end
		playerData[userId] = result
	else
		playerData[userId] = defaultData
	end
	
	return playerData[userId]
end

function DataService.GetData(player: Player)
	if not playerData[player.UserId] then
		return DataService.LoadData(player)
	end
	return playerData[player.UserId]
end

function DataService.SaveData(player: Player)
	local userId = player.UserId
	local data = playerData[userId]
	if not data or not dataStore then
		return false
	end
	
	local key = "Player_" .. userId
	local attempts = 0
	local success = false
	
	while attempts < 3 and not success do
		attempts = attempts + 1
		success = pcall(function()
			dataStore:SetAsync(key, data)
		end)
		if not success then
			task.wait(1)
		end
	end
	
	return success
end

function DataService.AddCoins(player: Player, amount: number)
	local data = DataService.GetData(player)
	if data and amount > 0 then
		data.Coins = data.Coins + math.floor(amount)
	end
end

function DataService.IncrementEscapes(player: Player, timeTaken: number)
	local data = DataService.GetData(player)
	if data then
		data.Escapes = data.Escapes + 1
		if not data.BestTime or timeTaken < data.BestTime then
			data.BestTime = math.floor(timeTaken)
		end
	end
end

function DataService.IncrementDeaths(player: Player)
	local data = DataService.GetData(player)
	if data then
		data.Deaths = data.Deaths + 1
	end
end

return DataService
