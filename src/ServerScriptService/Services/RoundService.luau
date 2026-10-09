--[[
	RoundService.luau
	Server-authoritative round lifecycle controller for DON'T WAKE HIM.
	Fixed: timer broadcast throttled to 1/sec, race-condition-safe remote init.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Utility = require(ReplicatedStorage.Shared.Utility)

local RoundService = {}
local roundState = Constants.RoundState.LOBBY
local roundTimer = 0
local lastTimerBroadcast = -999  -- tracks last time we sent UpdateTimer so we throttle to 1/sec
local activePlayers = {}
local roundRemote = nil

local dataServiceRef = nil
local noiseServiceRef = nil
local objectiveServiceRef = nil
local monsterServiceRef = nil
local rewardServiceRef = nil
local analyticsServiceRef = nil
local interactionServiceRef = nil

local houseSpawns = {}
local lobbySpawns = {}

function RoundService.Init(remotesFolder: Folder, houseSpawnsFolder: Instance, lobbySpawnsFolder: Instance, services: table)
	roundRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.RoundEvent)

	if not roundRemote then
		warn("[ROUND] RoundEvent remote not found in Remotes folder!")
	end

	if houseSpawnsFolder then houseSpawns = houseSpawnsFolder:GetChildren() end
	if lobbySpawnsFolder then lobbySpawns = lobbySpawnsFolder:GetChildren() end

	dataServiceRef = services.DataService
	noiseServiceRef = services.NoiseService
	objectiveServiceRef = services.ObjectiveService
	monsterServiceRef = services.MonsterService
	rewardServiceRef = services.RewardService
	analyticsServiceRef = services.AnalyticsService
	interactionServiceRef = services.InteractionService

	-- Player join/leave connections
	Players.PlayerAdded:Connect(RoundService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(RoundService.OnPlayerRemoving)

	-- Catch players already present in game at boot
	for _, player in ipairs(Players:GetPlayers()) do
		RoundService.OnPlayerAdded(player)
	end

	-- Main Round Heartbeat Loop (each tick isolated: one frame error can
	-- never silently stall the state machine)
	RunService.Heartbeat:Connect(function(deltaTime)
		local ok, err = pcall(function()
			RoundService.Update(deltaTime)
		end)
		if not ok then
			warn("[ROUND] Update error:", err)
		end
	end)

	print("[ROUND] RoundService initialized. House spawns:", #houseSpawns, "Lobby spawns:", #lobbySpawns)
end

function RoundService.GetState(): string
	return roundState
end

function RoundService.SetState(newState: string)
	if roundState == newState then return end
	print("[ROUND] State:", roundState, "->", newState)
	roundState = newState
	roundTimer = 0
	lastTimerBroadcast = -999

	if roundRemote then
		roundRemote:FireAllClients({
			Action = "StateChanged",
			State = newState,
		})
	end
end

function RoundService.OnPlayerAdded(player: Player)
	if roundState == Constants.RoundState.LOBBY or roundState == Constants.RoundState.COUNTDOWN then
		activePlayers[player.UserId] = Constants.PlayerState.LOBBY
		print("[ROUND] Player added to lobby:", player.Name)
	else
		activePlayers[player.UserId] = Constants.PlayerState.SPECTATING
	end
end

function RoundService.OnPlayerRemoving(player: Player)
	activePlayers[player.UserId] = nil
	if roundState == Constants.RoundState.ACTIVE then
		if analyticsServiceRef then
			analyticsServiceRef.TrackEvent(Constants.AnalyticsEvents.PlayerLeftDuringRound, { Player = player.Name })
		end
		RoundService.CheckRoundEndConditions()
	end
end

function RoundService.Update(deltaTime: number)
	roundTimer = roundTimer + deltaTime

	if roundState == Constants.RoundState.LOBBY then
		local playerCount = #Players:GetPlayers()
		if playerCount >= Config.Round.MinPlayers then
			RoundService.SetState(Constants.RoundState.COUNTDOWN)
		end

	elseif roundState == Constants.RoundState.COUNTDOWN then
		local remaining = math.clamp(math.ceil(Config.Round.CountdownDuration - roundTimer), 0, Config.Round.CountdownDuration)
		RoundService.BroadcastTimerThrottled(remaining)

		if remaining <= 0 then
			local okSR, errSR = pcall(function()
				RoundService.StartRound()
			end)
			if not okSR then
				warn("[ROUND] StartRound FAILED:", errSR)
				-- Force the lifecycle forward so the timer never freezes
				RoundService.SetState(Constants.RoundState.ACTIVE)
			end
		end

	elseif roundState == Constants.RoundState.ACTIVE then
		local remaining = math.clamp(math.ceil(Config.Round.RoundDuration - roundTimer), 0, Config.Round.RoundDuration)
		RoundService.BroadcastTimerThrottled(remaining)

		if remaining <= 0 then
			if analyticsServiceRef then
				analyticsServiceRef.TrackEvent(Constants.AnalyticsEvents.RoundTimedOut, {
					Players = #Players:GetPlayers(),
				})
			end
			RoundService.EndRound(false, "Time Expired")
		end

	elseif roundState == Constants.RoundState.RESULTS then
		if roundTimer >= Config.Round.ResultsDuration then
			RoundService.ResetRound()
		end
	end
end

function RoundService.StartRound()
	RoundService.SetState(Constants.RoundState.STARTING)

	-- Resolve folders robustly (exact child first, then recursive fallback)
	local keySpawnsFolder = workspace:FindFirstChild("KeySpawns") or workspace:FindFirstChild("KeySpawns", true)
	local interactablesFolder = workspace:FindFirstChild("Interactables") or workspace:FindFirstChild("Interactables", true)

	if keySpawnsFolder and interactablesFolder then
		local okObj, errObj = pcall(objectiveServiceRef.SetupRoundObjectives, keySpawnsFolder, interactablesFolder)
		if okObj then
			print("[ROUND] Objective setup done. Active keys in world:", objectiveServiceRef.GetActiveKeyCount())
		else
			warn("[ROUND] SetupRoundObjectives FAILED:", errObj)
		end
	else
		warn("[ROUND] KeySpawns or Interactables folder missing in workspace!",
			"KeySpawns=", tostring(keySpawnsFolder), "Interactables=", tostring(interactablesFolder))
	end

	-- Each reset is isolated: a failure in one system must not prevent the
	-- round from reaching ACTIVE (timer, keys, and teleports keep working).
	local okNoise, errNoise = pcall(noiseServiceRef.ResetNoise)
	if not okNoise then warn("[ROUND] ResetNoise FAILED:", errNoise) end
	local okMonster, errMonster = pcall(monsterServiceRef.Reset)
	if not okMonster then warn("[ROUND] MonsterService.Reset FAILED:", errMonster) end
	if interactionServiceRef and interactionServiceRef.ResetHidingStates then
		local okHide, errHide = pcall(interactionServiceRef.ResetHidingStates)
		if not okHide then warn("[ROUND] ResetHidingStates FAILED:", errHide) end
	end

	-- Spawn active players inside house
	local playerList = Players:GetPlayers()
	activePlayers = {}

	for i, player in ipairs(playerList) do
		activePlayers[player.UserId] = Constants.PlayerState.PLAYING

		if player.Character and #houseSpawns > 0 then
			local spawnPoint = houseSpawns[((i - 1) % #houseSpawns) + 1]
			if spawnPoint then
				player.Character:PivotTo(spawnPoint.CFrame * CFrame.new(0, 4, 0))
			end
		end
	end

	print("[ROUND] Round started with", #playerList, "players.")
	for userId, state in pairs(activePlayers) do
		print("[ROUND] Player state:", userId, state)
	end
	if analyticsServiceRef then
		pcall(analyticsServiceRef.TrackEvent, Constants.AnalyticsEvents.RoundStarted, {
			Players = #playerList,
		})
	end
	-- Unconditional: the round must ALWAYS reach ACTIVE (timer starts ticking)
	RoundService.SetState(Constants.RoundState.ACTIVE)
	print("[ROUND] State is now ACTIVE — timer broadcasting, round playable.")
end

function RoundService.OnPlayerEscaped(player: Player)
	if activePlayers[player.UserId] ~= Constants.PlayerState.PLAYING then return end

	activePlayers[player.UserId] = Constants.PlayerState.ESCAPED
	pcall(function() dataServiceRef.IncrementEscapes(player, roundTimer) end)

	if analyticsServiceRef then
		analyticsServiceRef.TrackEvent(Constants.AnalyticsEvents.PlayerEscaped, {
			Player = player.Name,
			Time = roundTimer,
		})
	end

	if player.Character and #lobbySpawns > 0 then
		player.Character:PivotTo(lobbySpawns[1].CFrame * CFrame.new(0, 4, 0))
	end

	RoundService.CheckRoundEndConditions()
end

function RoundService.OnPlayerCaught(player: Player)
	if activePlayers[player.UserId] ~= Constants.PlayerState.PLAYING then return end

	activePlayers[player.UserId] = Constants.PlayerState.DEAD
	pcall(function() dataServiceRef.IncrementDeaths(player) end)

	if interactionServiceRef and interactionServiceRef.ClearHidingState then
		interactionServiceRef.ClearHidingState(player)
	end

	if analyticsServiceRef then
		analyticsServiceRef.TrackEvent(Constants.AnalyticsEvents.PlayerCaught, {
			Player = player.Name,
		})
	end

	if player.Character and #lobbySpawns > 0 then
		player.Character:PivotTo(lobbySpawns[1].CFrame * CFrame.new(0, 4, 0))
	end

	RoundService.CheckRoundEndConditions()
end

function RoundService.CheckRoundEndConditions()
	local playingCount = 0
	local escapedCount = 0

	for _, state in pairs(activePlayers) do
		if state == Constants.PlayerState.PLAYING then
			playingCount += 1
		elseif state == Constants.PlayerState.ESCAPED then
			escapedCount += 1
		end
	end

	if playingCount == 0 then
		if escapedCount > 0 then
			RoundService.EndRound(true, "Escaped!")
		else
			RoundService.EndRound(false, "All Players Caught")
		end
	end
end

function RoundService.EndRound(success: boolean, reason: string)
	if roundState == Constants.RoundState.ENDING or roundState == Constants.RoundState.RESULTS then return end
	RoundService.SetState(Constants.RoundState.ENDING)

	local timeRemaining = math.max(0, Config.Round.RoundDuration - roundTimer)
	local isClean = monsterServiceRef.GetState() == Constants.MonsterState.SLEEPING

	local resultsData = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local state = activePlayers[player.UserId]
		local escaped = (state == Constants.PlayerState.ESCAPED)
		local earnedCoins = 0
		pcall(function()
			local coins, _ = rewardServiceRef.CalculateRewards(player, escaped, timeRemaining, isClean)
			earnedCoins = coins or 0
			dataServiceRef.AddCoins(player, earnedCoins)
		end)
		resultsData[player.UserId] = {
			Escaped = escaped,
			CoinsEarned = earnedCoins,
		}
	end

	if roundRemote then
		roundRemote:FireAllClients({
			Action = "RoundResults",
			Success = success,
			Reason = reason,
			Results = resultsData,
			RoundTime = roundTimer,
			KeysCollected = objectiveServiceRef and objectiveServiceRef.GetCollectedCount and objectiveServiceRef.GetCollectedCount() or 0,
		})
	end

	if analyticsServiceRef then
		analyticsServiceRef.TrackEvent(Constants.AnalyticsEvents.RoundCompleted, {
			Success = success,
			Reason = reason,
			RoundTime = roundTimer,
		})
	end

	RoundService.SetState(Constants.RoundState.RESULTS)
end

function RoundService.ResetRound()
	RoundService.SetState(Constants.RoundState.RESETTING)

	objectiveServiceRef.Reset()
	monsterServiceRef.Reset()
	noiseServiceRef.ResetNoise()
	if interactionServiceRef then
		if interactionServiceRef.ResetDoors then
			interactionServiceRef.ResetDoors()
		end
		if interactionServiceRef.ResetHidingStates then
			interactionServiceRef.ResetHidingStates()
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		activePlayers[player.UserId] = Constants.PlayerState.LOBBY
		if player.Character and #lobbySpawns > 0 then
			player.Character:PivotTo(lobbySpawns[1].CFrame * CFrame.new(0, 4, 0))
		end
	end

	RoundService.SetState(Constants.RoundState.LOBBY)
end

function RoundService.SetPlayerState(player: Player, state: string)
	activePlayers[player.UserId] = state
end

function RoundService.GetPlayerState(player: Player): string
	return activePlayers[player.UserId] or Constants.PlayerState.LOBBY
end

-- Throttled timer broadcast: only fires once per second to avoid network flooding
function RoundService.BroadcastTimerThrottled(seconds: number)
	local now = os.clock()
	if now - lastTimerBroadcast < 0.9 then return end
	lastTimerBroadcast = now

	if roundRemote then
		roundRemote:FireAllClients({
			Action = "UpdateTimer",
			TimeRemaining = seconds,
			FormattedTime = Utility.FormatTime(seconds),
		})
	end
end

return RoundService
