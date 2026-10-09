--[[
	NoiseService.luau
	Server-authoritative noise management system for DON'T WAKE HIM.
	The server decides every noise value: client requests are rate-limited,
	validated, and amounts come from Config — never from raw client data.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Utility = require(ReplicatedStorage.Shared.Utility)

local NoiseService = {}
local currentNoise = 0
local lastNoiseTimestamp = 0
local noiseEventRemote = nil
local rateLimiter = Utility.CreateRateLimiter(Config.Security.RateLimitEventsPerSec)
local roundServiceRef = nil

function NoiseService.SetRoundService(roundService)
	roundServiceRef = roundService
end

local function roundIsActive(): boolean
	if not roundServiceRef then return true end
	return roundServiceRef.GetState() == Constants.RoundState.ACTIVE
end

function NoiseService.Init(remotesFolder: Folder)
	noiseEventRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.NoiseEvent)

	-- Listen for movement and action noise events from clients
	if noiseEventRemote then
		noiseEventRemote.OnServerEvent:Connect(function(player: Player, data: table)
			if type(data) ~= "table" then return end
			if not rateLimiter(player) then return end -- reject remote spam
			if not roundIsActive() then return end    -- no lobby noise feeding the monster

			-- Server only accepts noise from living, present characters
			local char = player.Character
			if not char or not Utility.IsPlayerAlive(player) then return end
			local pos = (char.PrimaryPart or char:GetPivot()).Position

			local action = data.Action
			if action == "MovementNoise" then
				-- Amount is chosen entirely by the server from Config.
				local isSprinting = data.IsSprinting == true
				local amount = isSprinting and Config.Noise.Contributions.Sprint or Config.Noise.Contributions.Walk
				NoiseService.AddNoise(amount, pos)
			elseif action == "ActionNoise" then
				-- Malformed/excessive client amounts are clamped to the
				-- loudest possible configured contribution.
				local amount = tonumber(data.Amount) or 0
				amount = math.clamp(amount, 0, Config.Noise.Contributions.LoudEvent)
				if amount > 0 then
					NoiseService.AddNoise(amount, pos)
				end
			end
		end)
	end

	-- Noise Decay Loop
	RunService.Heartbeat:Connect(function(deltaTime)
		if currentNoise > 0 and (os.clock() - lastNoiseTimestamp) > Config.Noise.DecayDelayAfterNoise then
			local decayAmount = Config.Noise.DecayRatePerSecond * deltaTime
			NoiseService.SetNoise(math.max(0, currentNoise - decayAmount))
		end
	end)
end

function NoiseService.GetNoise(): number
	return currentNoise
end

function NoiseService.GetLevel(): string
	if currentNoise >= Config.Noise.Thresholds.WakeMin then
		return Constants.NoiseLevel.WAKE
	elseif currentNoise >= Config.Noise.Thresholds.DangerMax then
		return Constants.NoiseLevel.DANGER
	elseif currentNoise >= Config.Noise.Thresholds.AlertMax then
		return Constants.NoiseLevel.ALERT
	else
		return Constants.NoiseLevel.SAFE
	end
end

function NoiseService.SetNoise(amount: number)
	local clamped = math.clamp(amount, 0, Config.Noise.MaxNoise)
	if math.abs(clamped - currentNoise) > 0.01 then
		currentNoise = clamped
		NoiseService.Broadcast()
	end
end

function NoiseService.AddNoise(amount: number, sourcePosition: Vector3?)
	if amount <= 0 then return end
	lastNoiseTimestamp = os.clock()
	NoiseService.SetNoise(currentNoise + amount)

	if noiseEventRemote then
		noiseEventRemote:FireAllClients({
			Action = "NoiseBurst",
			Amount = amount,
			TotalNoise = currentNoise,
			Level = NoiseService.GetLevel(),
			Position = sourcePosition,
		})
	end

	-- Notify MonsterService if monster is active
	local MonsterService = NoiseService.MonsterService
	if MonsterService then
		MonsterService.OnNoiseEmitted(currentNoise, sourcePosition)
	end
end

function NoiseService.ResetNoise()
	currentNoise = 0
	lastNoiseTimestamp = 0
	NoiseService.Broadcast()
end

function NoiseService.Broadcast()
	if noiseEventRemote then
		noiseEventRemote:FireAllClients({
			Action = "UpdateNoise",
			TotalNoise = currentNoise,
			Level = NoiseService.GetLevel(),
		})
	end
end

return NoiseService
