--[[
	InteractionService.luau
	Server-authoritative interaction handler for doors, hiding spots, clues,
	and the UIEvent endpoints (stats / settings).
	Architecture: all physical interactions use server-wired ProximityPrompts
	(the old duplicate client InteractionEvent path was removed).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Utility = require(ReplicatedStorage.Shared.Utility)

local InteractionService = {}
local rateLimiter = Utility.CreateRateLimiter(Config.Security.RateLimitEventsPerSec)
local playerHidingState = {} -- userId -> hiding spot (Part or Model)
local uiRemote = nil
local roundServiceRef = nil
local dataServiceRef = nil
local noiseServiceRef = nil
local objectiveServiceRef = nil
local doorHomeCF = {} -- doorModel -> original closed CFrame of its Hinge

function InteractionService.Init(remotesFolder: Folder, noiseService, objectiveService, roundService, dataService)
	uiRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.UIEvent)
	roundServiceRef = roundService
	dataServiceRef = dataService
	noiseServiceRef = noiseService
	objectiveServiceRef = objectiveService

	-- UIEvent: client -> server requests (stats & settings)
	if uiRemote then
		uiRemote.OnServerEvent:Connect(function(player: Player, data: table)
			if type(data) ~= "table" then return end
			if not rateLimiter(player) then return end

			local action = data.Action
			if action == "GetStats" then
				local stats = dataServiceRef and dataServiceRef.GetData(player)
				uiRemote:FireClient(player, {
					Action = "Stats",
					Coins = stats and stats.Coins or 0,
					Escapes = stats and stats.Escapes or 0,
					Deaths = stats and stats.Deaths or 0,
					BestTime = stats and stats.BestTime,
				})
			elseif action == "GetSettings" then
				local stats = dataServiceRef and dataServiceRef.GetData(player)
				local s = (stats and stats.Settings) or Config.DataDefaults.Settings
				uiRemote:FireClient(player, {
					Action = "Settings",
					Settings = {
						MusicVolume = s.MusicVolume,
						SFXVolume = s.SFXVolume,
						ReducedEffects = s.ReducedEffects,
					},
				})
			elseif action == "SaveSettings" then
				-- Never trust client values: clamp and coerce everything.
				local incoming = data.Settings
				if type(incoming) == "table" and dataServiceRef then
					local d = dataServiceRef.GetData(player)
					if d then
						local function clampUnit(v, default)
							v = tonumber(v)
							if not v then return default end
							return math.clamp(v, 0, 1)
						end
						d.Settings = d.Settings or {}
						d.Settings.MusicVolume = clampUnit(incoming.MusicVolume, Config.DataDefaults.Settings.MusicVolume)
						d.Settings.SFXVolume = clampUnit(incoming.SFXVolume, Config.DataDefaults.Settings.SFXVolume)
						d.Settings.ReducedEffects = incoming.ReducedEffects == true
					end
				end
			end
		end)
	end

	-- Wire workspace ProximityPrompts for direct server handling
	InteractionService.WireWorkspacePrompts(noiseService, objectiveService, roundService)
end

local function canInteract(player: Player): boolean
	if not Utility.IsPlayerAlive(player) then return false end
	if roundServiceRef and roundServiceRef.GetState() ~= Constants.RoundState.ACTIVE then return false end
	return true
end

function InteractionService.WireWorkspacePrompts(noiseService, objectiveService, roundService)
	-- Bind doors (ProximityPrompt lives inside the Hinge part of each door Model)
	local interactables = workspace:FindFirstChild("Interactables")
	if interactables then
		for _, child in ipairs(interactables:GetChildren()) do
			local prompt = child:FindFirstChildOfClass("ProximityPrompt") or child:FindFirstChild("ProximityPrompt", true)
			if prompt then
				prompt.Triggered:Connect(function(player)
					if canInteract(player) then
						InteractionService.HandleDoor(player, child, noiseService)
					end
				end)
			end
		end
	end

	-- Bind hiding spots (prompt may be nested inside wardrobe panels)
	local hidingFolder = workspace:FindFirstChild("HidingSpots")
	if hidingFolder then
		for _, spot in ipairs(hidingFolder:GetChildren()) do
			local prompt = spot:FindFirstChildOfClass("ProximityPrompt") or spot:FindFirstChild("ProximityPrompt", true)
			if prompt then
				prompt.Triggered:Connect(function(player)
					if canInteract(player) then
						InteractionService.HandleHidingSpot(player, spot, roundService)
					end
				end)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Doors: server-validated toggle with smooth tween + door audio for everyone
-- ---------------------------------------------------------------------------
function InteractionService.HandleDoor(player: Player, doorInstance: Instance, noiseService)
	local doorModel = doorInstance:IsA("Model") and doorInstance or doorInstance.Parent
	if not doorModel then return end

	local isOpen = doorModel:GetAttribute("IsOpen") == true
	isOpen = not isOpen
	doorModel:SetAttribute("IsOpen", isOpen)

	local doorPos = doorInstance:IsA("Model") and doorModel:GetPivot().Position or doorInstance.Position

	local hinge = doorModel:FindFirstChild("Hinge") or doorModel.PrimaryPart or doorModel:FindFirstChildOfClass("BasePart")
	if hinge and hinge:IsA("BasePart") then
		-- Remember the factory-closed pose the first time we see this door.
		if doorHomeCF[doorModel] == nil then
			doorHomeCF[doorModel] = hinge.CFrame
		end
		local closedCF = doorHomeCF[doorModel]
		local targetCF = isOpen and (closedCF * CFrame.Angles(0, math.rad(-90), 0)) or closedCF

		TweenService:Create(hinge, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = targetCF,
		}):Play()
	end

	-- Door audio for every player (positional, cleaned up automatically)
	if uiRemote then
		uiRemote:FireAllClients({
			Action = "PlaySoundAt",
			Sound = "DoorOpen",
			Target = hinge,
			Volume = 0.8,
			Pitch = isOpen and 1.0 or 0.85,
		})
	end

	-- Emit noise burst for door interaction
	local svc = noiseService or noiseServiceRef
	if svc then
		svc.AddNoise(Config.Noise.Contributions.OpenDoor, doorPos)
	end
end

function InteractionService.ResetDoors()
	for doorModel, homeCF in pairs(doorHomeCF) do
		if doorModel.Parent then
			doorModel:SetAttribute("IsOpen", false)
			local hinge = doorModel:FindFirstChild("Hinge")
			if hinge and hinge:IsA("BasePart") then
				hinge.CFrame = homeCF
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Hiding spots
-- ---------------------------------------------------------------------------
local function spotPivot(spot: Instance): CFrame
	if spot:IsA("Model") then
		return spot:GetPivot()
	end
	return spot.CFrame
end

function InteractionService.HandleHidingSpot(player: Player, hidingSpot: Instance, roundService)
	local rs = roundService or roundServiceRef
	local userId = player.UserId
	local currentSpot = playerHidingState[userId]

	if currentSpot then
		-- Exit hiding spot
		playerHidingState[userId] = nil
		if rs and rs.GetPlayerState(player) == Constants.PlayerState.HIDING then
			rs.SetPlayerState(player, Constants.PlayerState.PLAYING)
		end
		local char = player.Character
		if char then
			local exitMarker = currentSpot:FindFirstChild("ExitMarker")
			if exitMarker then
				-- Drop-in exit: pivot 3 studs above the marker so the player
				-- lands cleanly on the floor instead of inside it.
				char:PivotTo(exitMarker.CFrame * CFrame.new(0, 3, 0))
			else
				char:PivotTo(spotPivot(currentSpot) * CFrame.new(0, 0, 4))
			end
		end
	else
		-- Enter hiding spot: only living players actively in the round
		if not hidingSpot then return end
		if rs and rs.GetPlayerState(player) ~= Constants.PlayerState.PLAYING then return end

		playerHidingState[userId] = hidingSpot
		if rs then
			rs.SetPlayerState(player, Constants.PlayerState.HIDING)
		end
		local char = player.Character
		if char then
			char:PivotTo(spotPivot(hidingSpot))
		end
	end
end

-- ---------------------------------------------------------------------------
-- Clues
-- ---------------------------------------------------------------------------
function InteractionService.HandleReadClue(player: Player, clueInstance: Instance)
	if not canInteract(player) then return end

	local text = clueInstance:GetAttribute("ClueText") or "Keep quiet! The monster hears every step."
	local title = clueInstance:GetAttribute("ClueTitle") or "Scrawled Note"

	if uiRemote then
		uiRemote:FireClient(player, {
			Action = "ShowClue",
			Title = title,
			Text = text,
		})
	end
end

function InteractionService.IsPlayerHiding(player: Player): boolean
	return playerHidingState[player.UserId] ~= nil
end

function InteractionService.ClearHidingState(player: Player)
	playerHidingState[player.UserId] = nil
end

function InteractionService.ResetHidingStates()
	playerHidingState = {}
end

return InteractionService
