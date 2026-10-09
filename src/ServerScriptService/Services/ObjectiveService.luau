--[[
	ObjectiveService.luau
	Server-authoritative objective spawn, key collection, clues, and exit unlock engine.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Utility = require(ReplicatedStorage.Shared.Utility)

local ObjectiveService = {}
local activeObjectives = {} -- Map of Model/Part -> ObjectiveId
local collectedCount = 0
local objectiveRemote = nil
local uiRemote = nil
local exitUnlocked = false
local analyticsRef = nil

function ObjectiveService.Init(remotesFolder: Folder, roundService, analyticsService)
	objectiveRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.ObjectiveEvent)
	uiRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.UIEvent)
	ObjectiveService.RoundService = roundService
	analyticsRef = analyticsService

	-- Wire Exit Door ProximityPrompt (server validated: alive + round active)
	local exitDoor = workspace:FindFirstChild("Exit") and workspace.Exit:FindFirstChild("ExitDoor")
	if exitDoor then
		local prompt = exitDoor:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if not Utility.IsPlayerAlive(player) then return end
				if roundService and roundService.GetState() ~= Constants.RoundState.ACTIVE then return end
				ObjectiveService.TryEscape(player)
			end)
		end
	end
end

function ObjectiveService.SetupRoundObjectives(keySpawnsFolder: Instance, interactablesFolder: Instance)
	activeObjectives = {}
	collectedCount = 0
	exitUnlocked = false
	
	-- Clear existing keys
	for _, child in ipairs(interactablesFolder:GetChildren()) do
		if child.Name:sub(1, 13) == "ObjectiveKey_" then
			child:Destroy()
		end
	end
	
	-- Resolve spawn folder robustly (exact match first, then recursive fallback)
	if not keySpawnsFolder or #keySpawnsFolder:GetChildren() < Config.Objectives.TotalRequired then
		local fallback = workspace:FindFirstChild("KeySpawns", true)
		if fallback then keySpawnsFolder = fallback end
	end

	local spawnPoints = keySpawnsFolder:GetChildren()
	if #spawnPoints < Config.Objectives.TotalRequired then
		warn("[OBJECTIVE] Not enough key spawn points! Found:", #spawnPoints, " folder:", tostring(keySpawnsFolder))
		return
	end
	print("[OBJECTIVE] Using", #spawnPoints, "key spawn points from", keySpawnsFolder:GetFullName())
	
	-- Shuffle and pick 3 distinct locations
	local availableIndices = {}
	for i = 1, #spawnPoints do
		table.insert(availableIndices, i)
	end
	
	local selectedPoints = {}
	for i = 1, Config.Objectives.TotalRequired do
		local idx = math.random(1, #availableIndices)
		local pointIndex = table.remove(availableIndices, idx)
		table.insert(selectedPoints, spawnPoints[pointIndex])
	end
	
	-- Create key interactables at selected points
	for i, spawnPoint in ipairs(selectedPoints) do
		local keyPart = Instance.new("Part")
		keyPart.Name = "ObjectiveKey_" .. i
		keyPart.Size = Vector3.new(1.4, 0.5, 2.0)
		keyPart.Color = Color3.fromRGB(245, 205, 50)
		keyPart.Material = Enum.Material.Neon -- readable even in dark rooms
		keyPart.CFrame = spawnPoint.CFrame * CFrame.new(0, 0.4, 0)
		keyPart.Anchored = true
		keyPart.CanCollide = false
		keyPart.Parent = interactablesFolder
		
		-- Visual Highlight box
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 220, 80)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.4
		highlight.OutlineTransparency = 0.1
		highlight.Parent = keyPart
		
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = Config.Objectives.ObjectiveNames[i] or ("Key #" .. i)
		prompt.ActionText = "Pick Up Key"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = Config.Objectives.InteractionDistance
		prompt.Enabled = true
		-- Show the prompt even if the camera views the key edge-on or the key
		-- sits slightly behind a furniture rim; pickup is still server-validated.
		prompt.RequiresLineOfSight = false
		prompt.Parent = keyPart

		prompt.Triggered:Connect(function(player)
			ObjectiveService.TryCollectObjective(player, keyPart)
		end)

		print(string.format("[OBJECTIVE] Spawned %s at %s parent=%s prompt(Enabled=%s MaxDist=%s Action='%s' Object='%s')",
			keyPart.Name, tostring(keyPart.CFrame.Position), keyPart.Parent.Name,
			tostring(prompt.Enabled), tostring(prompt.MaxActivationDistance),
			prompt.ActionText, prompt.ObjectText))
		
		activeObjectives[keyPart] = {
			Id = i,
			Name = prompt.ObjectText,
			Collected = false,
		}
	end
	
	ObjectiveService.SetupRoundClues(interactablesFolder)

	-- Self-report: one line per key + totals so Play-mode Output proves
	-- exactly what exists in Workspace during the round.
	for _, line in ipairs(ObjectiveService.GetKeyReport()) do
		print(line)
	end
	ObjectiveService.BroadcastProgress()
end

function ObjectiveService.SetupRoundClues(interactablesFolder: Instance)
	-- Clear old clues
	for _, child in ipairs(interactablesFolder:GetChildren()) do
		if child.Name:sub(1, 9) == "ClueNote_" then
			child:Destroy()
		end
	end
	
	local clueSpawnsFolder = workspace:FindFirstChild("ClueSpawns")
	local cluePoints = clueSpawnsFolder and clueSpawnsFolder:GetChildren() or {}
	
	for i, clueDef in ipairs(Config.Clues) do
		if i <= #cluePoints then
			local spawnPoint = cluePoints[i]
			local notePart = Instance.new("Part")
			notePart.Name = "ClueNote_" .. i
			notePart.Size = Vector3.new(1.5, 0.1, 2.0)
			notePart.Color = Color3.fromRGB(235, 225, 200)
			notePart.Material = Enum.Material.SmoothPlastic
			notePart.CFrame = spawnPoint.CFrame * CFrame.new(0, 0.1, 0)
			notePart.Anchored = true
			notePart.CanCollide = false
			notePart.Parent = interactablesFolder
			
			notePart:SetAttribute("ClueTitle", clueDef.Title)
			notePart:SetAttribute("ClueText", clueDef.Text)
			
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = clueDef.Title
			prompt.ActionText = "Read Note"
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = Config.Objectives.InteractionDistance
			prompt.Enabled = true
			prompt.RequiresLineOfSight = false
			prompt.Parent = notePart
			
			local InteractionService = require(game:GetService("ServerScriptService").Services.InteractionService)
			prompt.Triggered:Connect(function(player)
				InteractionService.HandleReadClue(player, notePart)
			end)
		end
	end
end

function ObjectiveService.TryCollectObjective(player: Player, keyPart: Instance)
	-- Server validation: living, in-round player only
	if not Utility.IsPlayerAlive(player) then
		warn("[OBJECTIVE] Pickup rejected (not alive):", player.Name)
		return false
	end
	local rs = ObjectiveService.RoundService
	if not rs or rs.GetState() ~= Constants.RoundState.ACTIVE then
		warn("[OBJECTIVE] Pickup rejected (round not ACTIVE):", player.Name, rs and rs.GetState() or "no RoundService")
		return false
	end
	if rs.GetPlayerState(player) ~= Constants.PlayerState.PLAYING then
		warn("[OBJECTIVE] Pickup rejected (player state):", player.Name, rs.GetPlayerState(player))
		return false
	end

	local objData = activeObjectives[keyPart]
	if not objData or objData.Collected then
		warn("[OBJECTIVE] Pickup rejected (unknown/already collected):", player.Name, tostring(keyPart))
		return false
	end
	
	objData.Collected = true
	collectedCount = collectedCount + 1
	print("[OBJECTIVE] Key collected:", player.Name, keyPart.Name, "->", collectedCount .. "/" .. Config.Objectives.TotalRequired)
	
	-- Hide & disable key part
	keyPart.Transparency = 1
	local highlight = keyPart:FindFirstChildOfClass("Highlight")
	if highlight then highlight.Enabled = false end
	local prompt = keyPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt.Enabled = false end

	-- Pickup audio for every player (positional, auto-cleanup)
	if uiRemote then
		uiRemote:FireAllClients({
			Action = "PlaySoundAt",
			Sound = "ObjectivePickup",
			Target = keyPart,
			Volume = 0.7,
		})
	end
	if analyticsRef then
		analyticsRef.TrackEvent(Constants.AnalyticsEvents.ObjectiveCollected, {
			Player = player.Name,
			Keys = collectedCount,
		})
	end
	
	ObjectiveService.BroadcastProgress()
	
	if collectedCount >= Config.Objectives.TotalRequired then
		exitUnlocked = true
		ObjectiveService.UnlockExit()
	end
	
	return true
end

function ObjectiveService.TryEscape(player: Player)
	if not exitUnlocked then return false, "Exit Locked" end
	if not Utility.IsPlayerAlive(player) then return false, "Not Alive" end
	if ObjectiveService.RoundService then
		ObjectiveService.RoundService.OnPlayerEscaped(player)
	end
	return true
end

function ObjectiveService.IsExitUnlocked(): boolean
	return exitUnlocked
end

function ObjectiveService.GetCollectedCount(): number
	return collectedCount
end

function ObjectiveService.GetActiveKeyCount(): number
	local n = 0
	local interactables = workspace:FindFirstChild("Interactables")
	if interactables then
		for _, child in ipairs(interactables:GetChildren()) do
			if child.Name:sub(1, 13) == "ObjectiveKey_" then
				n += 1
			end
		end
	end
	return n
end

-- Live diagnostic report (run from Studio's Command Bar during Play):
--   require(game.ServerScriptService.Services.ObjectiveService).GetKeyReport()
-- Returns one line per runtime key with position, visibility props, and the
-- full ProximityPrompt configuration, plus exit/unlock status.
function ObjectiveService.GetKeyReport(): {string}
	local lines = {}
	local interactables = workspace:FindFirstChild("Interactables")
	local count = 0
	if interactables then
		for _, child in ipairs(interactables:GetChildren()) do
			if child.Name:sub(1, 13) == "ObjectiveKey_" then
				count += 1
				local prompt = child:FindFirstChildOfClass("ProximityPrompt")
				local promptText
				if prompt then
					promptText = string.format("Enabled=%s MaxDist=%s Action='%s' Object='%s' LOSRequired=%s",
						tostring(prompt.Enabled), tostring(prompt.MaxActivationDistance),
						prompt.ActionText, prompt.ObjectText, tostring(prompt.RequiresLineOfSight))
				else
					promptText = "MISSING"
				end
				local highlight = child:FindFirstChildOfClass("Highlight")
				table.insert(lines, string.format(
					"[KEY REPORT] %s | path=%s | pos=%s | transparency=%s | size=%s | canCollide=%s | parent=%s | highlight=%s | prompt: %s",
					child.Name, child:GetFullName(), tostring(child.Position),
					tostring(child.Transparency), tostring(child.Size),
					tostring(child.CanCollide), child.Parent and child.Parent.Name or "nil",
					tostring(highlight ~= nil), promptText))
			end
		end
	end

	local exitLine = "[KEY REPORT] exit door prompt: "
	local exitModel = workspace:FindFirstChild("Exit")
	local exitDoor = exitModel and exitModel:FindFirstChild("ExitDoor")
	local exitPrompt = exitDoor and exitDoor:FindFirstChildOfClass("ProximityPrompt")
	if exitPrompt then
		exitLine = exitLine .. string.format("Enabled=%s Action='%s' Object='%s'",
			tostring(exitPrompt.Enabled), exitPrompt.ActionText, exitPrompt.ObjectText)
	else
		exitLine = exitLine .. "MISSING"
	end
	table.insert(lines, exitLine)

	table.insert(lines, string.format(
		"[KEY REPORT] keys in world=%d | collected=%d/%d | exitUnlocked=%s",
		count, collectedCount, Config.Objectives.TotalRequired, tostring(exitUnlocked)))
	return lines
end

function ObjectiveService.UnlockExit()
	print("[OBJECTIVE] EXIT UNLOCKED — all", Config.Objectives.TotalRequired, "keys collected.")
	-- Update Exit Door Keypad visual status
	local exitModel = workspace:FindFirstChild("Exit")
	if exitModel then
		local lockLed = exitModel:FindFirstChild("LockLed")
		if lockLed then
			lockLed.Color = Color3.fromRGB(40, 240, 60) -- Green when unlocked
		end
		local exitDoor = exitModel:FindFirstChild("ExitDoor")
		if exitDoor then
			local prompt = exitDoor:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ActionText = "Escape Now!"
				prompt.ObjectText = "Unlocked Front Exit"
			end
		end
	end

	if objectiveRemote then
		objectiveRemote:FireAllClients({
			Action = "ExitUnlocked",
		})
	end

	-- Unlock chime for every player
	if uiRemote then
		uiRemote:FireAllClients({
			Action = "PlaySoundAt",
			Sound = "ObjectivePickup",
			Target = exitModel and exitModel:FindFirstChild("ExitDoor"),
			Volume = 0.9,
			Pitch = 0.75,
		})
	end
end

function ObjectiveService.BroadcastProgress()
	if objectiveRemote then
		objectiveRemote:FireAllClients({
			Action = "UpdateObjectives",
			Collected = collectedCount,
			Total = Config.Objectives.TotalRequired,
			ExitUnlocked = exitUnlocked,
		})
	end
end

function ObjectiveService.Reset()
	activeObjectives = {}
	collectedCount = 0
	exitUnlocked = false

	-- Destroy leftover runtime objects so rounds never inherit old keys/clues
	local interactables = workspace:FindFirstChild("Interactables")
	if interactables then
		for _, child in ipairs(interactables:GetChildren()) do
			if child.Name:sub(1, 13) == "ObjectiveKey_" or child.Name:sub(1, 9) == "ClueNote_" then
				child:Destroy()
			end
		end
	end
	
	-- Reset Exit Door Keypad visual status to red
	local exitModel = workspace:FindFirstChild("Exit")
	if exitModel then
		local lockLed = exitModel:FindFirstChild("LockLed")
		if lockLed then
			lockLed.Color = Color3.fromRGB(240, 30, 30) -- Red when locked
		end
		local exitDoor = exitModel:FindFirstChild("ExitDoor")
		if exitDoor then
			local prompt = exitDoor:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ActionText = "Unlock & Escape (Requires 3 Keys)"
				prompt.ObjectText = "Heavy Front Exit Door"
			end
		end
	end

	ObjectiveService.BroadcastProgress()
end

return ObjectiveService
