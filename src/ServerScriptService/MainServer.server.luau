--[[
	MainServer.server.luau
	Master Server entry point for DON'T WAKE HIM.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Constants = require(ReplicatedStorage.Shared.Constants)

-- Ensure Remotes Folder exists
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Create missing RemoteEvents if needed
for _, remoteName in pairs(Constants.RemoteNames) do
	if not remotesFolder:FindFirstChild(remoteName) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotesFolder
	end
end

-- Load Services
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services.DataService)
local AnalyticsService = require(Services.AnalyticsService)
local RewardService = require(Services.RewardService)
local MonetizationService = require(Services.MonetizationService)
local NoiseService = require(Services.NoiseService)
local InteractionService = require(Services.InteractionService)
local ObjectiveService = require(Services.ObjectiveService)
local MonsterService = require(Services.MonsterService)
local RoundService = require(Services.RoundService)

-- Boot marker: proves in Play-mode Output that MainServer reached execution.
print("[SERVER] Boot: module requires OK. Initializing services...")

-- Round lifecycle must survive any single service failing to init:
-- each Init is isolated, failures are loud, RoundService.Init always runs.
local function safeInit(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[SERVER] INIT FAILED: " .. name .. " -> " .. tostring(err))
	end
	return ok
end

-- Initialize DataService
safeInit("DataService", function()
	DataService.Init()
end)

-- Initialize Noise Service
safeInit("NoiseService", function()
	NoiseService.Init(remotesFolder)
end)

-- Get Workspace Nodes safely
local house = workspace:WaitForChild("House", 10) or workspace:FindFirstChild("House")
local houseSpawns = house and house:WaitForChild("SpawnPoints", 5) or workspace:FindFirstChild("SpawnPoints", true)
local lobby = workspace:WaitForChild("Lobby", 10) or workspace:FindFirstChild("Lobby")
local lobbySpawns = lobby and lobby:WaitForChild("SpawnPoints", 5) or workspace:FindFirstChild("SpawnPoints", true)
local monsterRig = house and house:WaitForChild("SleepingMan", 5) or workspace:FindFirstChild("SleepingMan", true)

-- Initialize Core Services
safeInit("ObjectiveService", function()
	ObjectiveService.Init(remotesFolder, RoundService, AnalyticsService)
end)
safeInit("MonsterService", function()
	MonsterService.Init(remotesFolder, monsterRig, NoiseService, InteractionService, RoundService, AnalyticsService)
end)
safeInit("InteractionService", function()
	InteractionService.Init(remotesFolder, NoiseService, ObjectiveService, RoundService, DataService)
end)
safeInit("MonetizationService", function()
	MonetizationService.Init(remotesFolder, DataService, AnalyticsService)
end)

-- Initialize Round Lifecycle Controller
safeInit("RoundService", function()
	RoundService.Init(remotesFolder, houseSpawns, lobbySpawns, {
		DataService = DataService,
		AnalyticsService = AnalyticsService,
		RewardService = RewardService,
		MonetizationService = MonetizationService,
		NoiseService = NoiseService,
		InteractionService = InteractionService,
		ObjectiveService = ObjectiveService,
		MonsterService = MonsterService,
	})
end)

-- Noise gating: only accept player noise while a round is ACTIVE
NoiseService.SetRoundService(RoundService)

print("[SERVER] DON'T WAKE HIM master server services initialized cleanly.")
