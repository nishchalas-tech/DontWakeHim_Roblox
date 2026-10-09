--[[
	UIController.luau
	Master User Interface Controller for DON'T WAKE HIM.
	Handles HUD updates, clue modal, result screen, jumpscare/spectator flow,
	and runtime-built Shop / Stats / Settings panels (no dead buttons).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Utility = require(ReplicatedStorage.Shared.Utility)

local UIController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local mainHUD = nil
local resultUI = nil

local noiseMeterText = nil
local noiseBarFill = nil
local objectiveCounterText = nil
local timerText = nil
local statusMessageText = nil

local audioCtrl = nil
local cameraCtrl = nil
local uiRemote = nil
local shopRemote = nil

local menuGui = nil
local shopPanel = nil
local statsPanel = nil
local settingsPanel = nil
local deathOverlay = nil

local ownedCosmetics = {}
local playerCoins = 0
local settingsState = {
	MusicVolume = Config.DataDefaults.Settings.MusicVolume,
	SFXVolume = Config.DataDefaults.Settings.SFXVolume,
	ReducedEffects = Config.DataDefaults.Settings.ReducedEffects,
}
local spectating = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function makeLabel(parent, name, text, size, position, textSize, color)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = position
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(235, 235, 240)
	lbl.TextSize = textSize or 16
	lbl.Font = Enum.Font.GothamBold
	lbl.TextWrapped = true
	lbl.Parent = parent
	return lbl
end

local function makeButton(parent, name, text, size, position)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.Position = position
	btn.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(240, 230, 190)
	btn.TextSize = 16
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent
	return btn
end

local function makePanel(screenGui, name, title)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0.5, 0, 0.62, 0)
	frame.Position = UDim2.new(0.25, 0, 0.19, 0)
	frame.BackgroundColor3 = Color3.fromRGB(18, 19, 26)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screenGui

	makeLabel(frame, "TitleLabel", title, UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 8), 24)

	local closeBtn = makeButton(frame, "CloseButton", "X", UDim2.new(0, 36, 0, 36), UDim2.new(1, -46, 0, 6))
	closeBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	closeBtn.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)

	return frame
end

local function hideAllPanels()
	if shopPanel then shopPanel.Visible = false end
	if statsPanel then statsPanel.Visible = false end
	if settingsPanel then settingsPanel.Visible = false end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function UIController.Init(remotesFolder: Folder, audio, camera)
	audioCtrl = audio
	cameraCtrl = camera

	-- Wait for GUI elements (they come from StarterGui on character spawn)
	mainHUD = playerGui:WaitForChild("MainHUD", 10)
	resultUI = playerGui:WaitForChild("ResultUI", 10)

	if mainHUD then
		noiseMeterText = mainHUD:FindFirstChild("NoiseLabel", true)
		noiseBarFill = mainHUD:FindFirstChild("NoiseBarFill", true)
		objectiveCounterText = mainHUD:FindFirstChild("ObjectiveLabel", true)
		timerText = mainHUD:FindFirstChild("TimerLabel", true)
		statusMessageText = mainHUD:FindFirstChild("StatusLabel", true)
		print("[UI] HUD found. TimerLabel:", timerText ~= nil, "NoiseLabel:", noiseMeterText ~= nil)
	else
		warn("[UI] MainHUD NOT found in PlayerGui!")
	end

	-- Connect Remote Events
	local roundRemote = remotesFolder:WaitForChild(Constants.RemoteNames.RoundEvent, 15)
	local noiseRemote = remotesFolder:WaitForChild(Constants.RemoteNames.NoiseEvent, 15)
	local objRemote = remotesFolder:WaitForChild(Constants.RemoteNames.ObjectiveEvent, 15)
	local monsterRemote = remotesFolder:WaitForChild(Constants.RemoteNames.MonsterEvent, 15)
	uiRemote = remotesFolder:WaitForChild(Constants.RemoteNames.UIEvent, 15)
	shopRemote = remotesFolder:WaitForChild(Constants.RemoteNames.ShopEvent, 15)

	if roundRemote then
		roundRemote.OnClientEvent:Connect(UIController.OnRoundEvent)
		print("[UI] Connected to RoundEvent")
	else
		warn("[UI] RoundEvent remote not found!")
	end

	if noiseRemote then
		noiseRemote.OnClientEvent:Connect(UIController.OnNoiseEvent)
	end

	if objRemote then
		objRemote.OnClientEvent:Connect(UIController.OnObjectiveEvent)
	end

	if monsterRemote then
		monsterRemote.OnClientEvent:Connect(UIController.OnMonsterEvent)
	end

	if uiRemote then
		uiRemote.OnClientEvent:Connect(UIController.OnUIEvent)
	end

	if shopRemote then
		shopRemote.OnClientEvent:Connect(UIController.OnShopEvent)
	end

	UIController.BuildMenuUI()
	UIController.BuildDeathOverlay()

	-- Mobile optimization
	if UserInputService.TouchEnabled then
		UIController.SetupMobileButtons()
	end

	-- Fetch persisted settings so volumes apply immediately
	if uiRemote then
		uiRemote:FireServer({ Action = "GetSettings" })
	end

	print("[UI] UIController initialized.")
end

-- ---------------------------------------------------------------------------
-- Server UI events (stats / settings)
-- ---------------------------------------------------------------------------
function UIController.OnUIEvent(data: table)
	if type(data) ~= "table" then return end

	if data.Action == "ShowClue" then
		UIController.ShowClueModal(data.Title, data.Text)
		if audioCtrl then
			audioCtrl.PlayOneShot("Clue", 0.6, 1.3)
		end
	elseif data.Action == "PlaySoundAt" then
		if audioCtrl then
			audioCtrl.PlaySoundAt(data.Sound, data.Target, data.Volume, data.Pitch)
		end
	elseif data.Action == "Stats" then
		UIController.RenderStats(data)
	elseif data.Action == "Settings" then
		if type(data.Settings) == "table" then
			for k, v in pairs(data.Settings) do
				settingsState[k] = v
			end
		end
		UIController.ApplyLocalSettings()
		UIController.RenderSettings()
	elseif data.Action == "SettingsSaved" then
		-- server confirmed sanitised values
	end
end

function UIController.OnShopEvent(data: table)
	if type(data) ~= "table" then return end

	if data.Action == "ShopData" or data.Action == "PurchaseResult" then
		if type(data.Owned) == "table" then
			ownedCosmetics = data.Owned
		end
		if type(data.Coins) == "number" then
			playerCoins = data.Coins
		end
		if shopPanel and shopPanel.Visible then
			UIController.RenderShop()
		end
		if statsPanel and statsPanel.Visible then
			UIController.RenderStats({})
		end
	end
end

-- ---------------------------------------------------------------------------
-- HUD: noise / objectives / timer / states
-- ---------------------------------------------------------------------------
function UIController.OnNoiseEvent(data: table)
	if data.Action == "UpdateNoise" or data.Action == "NoiseBurst" then
		local totalNoise = math.floor(data.TotalNoise or 0)
		local level = data.Level or "SAFE"

		if noiseMeterText then
			noiseMeterText.Text = string.format("NOISE: %d%% [%s]", totalNoise, level)
		end

		if noiseBarFill then
			-- Bar width proportional to noise level (max width 236px)
			noiseBarFill.Size = UDim2.new(0, math.floor(totalNoise / 100 * 236), 1, -4)
			if level == "SAFE" then
				noiseBarFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
			elseif level == "ALERT" then
				noiseBarFill.BackgroundColor3 = Color3.fromRGB(240, 200, 50)
			elseif level == "DANGER" then
				noiseBarFill.BackgroundColor3 = Color3.fromRGB(240, 120, 40)
			else -- WAKE
				noiseBarFill.BackgroundColor3 = Color3.fromRGB(240, 40, 40)
			end
		end
	end
end

function UIController.OnObjectiveEvent(data: table)
	if data.Action == "UpdateObjectives" then
		local collected = data.Collected or 0
		local total = data.Total or 3
		if objectiveCounterText then
			objectiveCounterText.Text = string.format("KEYS: %d/%d", collected, total)
			print("[UI] KEYS HUD updated ->", objectiveCounterText.Text)
		end
	elseif data.Action == "ExitUnlocked" then
		if statusMessageText then
			statusMessageText.Text = "EXIT UNLOCKED! Run to the red door!"
			statusMessageText.TextColor3 = Color3.fromRGB(80, 255, 120)
			task.delay(5, function()
				if statusMessageText and statusMessageText.Text:find("EXIT UNLOCKED") then
					statusMessageText.Text = "Stay quiet. Don't wake him."
					statusMessageText.TextColor3 = Color3.fromRGB(245, 215, 100)
				end
			end)
		end
	end
end

function UIController.OnRoundEvent(data: table)
	if data.Action == "UpdateTimer" then
		if timerText then
			timerText.Text = data.FormattedTime or "00:00"
			print("[UI] Timer ->", timerText.Text)
		end
	elseif data.Action == "StateChanged" then
		local state = data.State
		print("[UI] Round state received:", state)
		if statusMessageText then
			if state == "COUNTDOWN" then
				statusMessageText.Text = "Round starting soon..."
				statusMessageText.TextColor3 = Color3.fromRGB(240, 240, 100)
			elseif state == "ACTIVE" then
				statusMessageText.Text = "Stay quiet. Don't wake him."
				statusMessageText.TextColor3 = Color3.fromRGB(245, 215, 100)
			elseif state == "ENDING" or state == "RESULTS" then
				statusMessageText.Text = "Round finished."
				statusMessageText.TextColor3 = Color3.fromRGB(200, 200, 200)
			elseif state == "LOBBY" then
				statusMessageText.Text = "Waiting for round to start..."
				statusMessageText.TextColor3 = Color3.fromRGB(180, 180, 200)
			end
		end

		-- Round lifecycle UI resets (no stale UI across rounds)
		if state == "ACTIVE" or state == "LOBBY" then
			UIController.HideDeathOverlay()
			UIController.StopSpectating()
			if resultUI then resultUI.Enabled = false end
			hideAllPanels()
		end
	elseif data.Action == "RoundResults" then
		UIController.ShowResults(data)
	end
end

function UIController.OnMonsterEvent(data: table)
	if data.Action == "StateChanged" then
		local state = data.State
		if statusMessageText then
			if state == "DISTURBED" then
				statusMessageText.Text = "He stirred... stay still!"
				statusMessageText.TextColor3 = Color3.fromRGB(240, 200, 50)
			elseif state == "WAKING" then
				statusMessageText.Text = "HE IS WAKING UP!"
				statusMessageText.TextColor3 = Color3.fromRGB(240, 60, 60)
			elseif state == "SEARCHING" then
				statusMessageText.Text = "He is searching the house..."
				statusMessageText.TextColor3 = Color3.fromRGB(240, 160, 60)
			elseif state == "CHASING" then
				statusMessageText.Text = "RUN! HE IS CHASING YOU!"
				statusMessageText.TextColor3 = Color3.fromRGB(255, 0, 0)
			elseif state == "SLEEPING" then
				statusMessageText.Text = "Stay quiet. Don't wake him."
				statusMessageText.TextColor3 = Color3.fromRGB(245, 215, 100)
			end
		end

		-- Monster audio reactions
		if audioCtrl then
			if state == "SLEEPING" then
				audioCtrl.SetChaseState(false)
				audioCtrl.SetSnoring(true)
			elseif state == "DISTURBED" then
				audioCtrl.SetSnoring(false)
				audioCtrl.PlayOneShot("MonsterGrowl", 0.45, 0.9)
			elseif state == "WAKING" then
				audioCtrl.SetSnoring(false)
				audioCtrl.PlayOneShot("MonsterGrowl", 0.8, 1.05)
			elseif state == "SEARCHING" then
				audioCtrl.SetSnoring(false)
				audioCtrl.SetChaseState(false)
			elseif state == "CHASING" then
				audioCtrl.SetSnoring(false)
				audioCtrl.SetChaseState(true)
			end
		end

	elseif data.Action == "Jumpscare" then
		UIController.OnCaught(data)
	end
end

-- ---------------------------------------------------------------------------
-- Death / spectator pipeline
-- ---------------------------------------------------------------------------
function UIController.BuildDeathOverlay()
	if deathOverlay then return end
	deathOverlay = Instance.new("ScreenGui")
	deathOverlay.Name = "DeathOverlay"
	deathOverlay.ResetOnSpawn = false
	deathOverlay.Enabled = false
	deathOverlay.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "DeathFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	frame.Parent = deathOverlay

	makeLabel(frame, "DeathTitle", "YOU WERE CAUGHT", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 0.28, 0), 40, Color3.fromRGB(255, 60, 60))
	makeLabel(frame, "DeathSub", "Spectating the survivors...", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.42, 0), 22, Color3.fromRGB(220, 220, 230))
end

function UIController.ShowDeathOverlay()
	UIController.BuildDeathOverlay()
	if deathOverlay then deathOverlay.Enabled = true end
end

function UIController.HideDeathOverlay()
	if deathOverlay then deathOverlay.Enabled = false end
end

function UIController.OnCaught(data: table)
	if audioCtrl then
		audioCtrl.PlayJumpscare()
	end
	if cameraCtrl and (not settingsState.ReducedEffects) then
		cameraCtrl.TriggerJumpscare(data.Position)
	end

	UIController.ShowDeathOverlay()

	task.delay(1.8, function()
		if deathOverlay and deathOverlay.Enabled then
			UIController.BeginSpectating()
		end
	end)
end

function UIController.BeginSpectating()
	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				target = p
				break
			end
		end
	end

	if cameraCtrl then
		cameraCtrl.SetSpectatorTarget(target)
	end
	spectating = true

	-- Keep spectating a living player while the overlay is up.
	task.spawn(function()
		while spectating do
			task.wait(3)
			if not spectating then break end
			local current = target
			if current then
				local hum = current.Character and current.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					continue
				end
			end
			-- Re-pick a living player (or drop to custom camera)
			local newTarget = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= localPlayer then
					local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						newTarget = p
						break
					end
				end
			end
			target = newTarget
			if cameraCtrl then
				cameraCtrl.SetSpectatorTarget(newTarget)
			end
		end
	end)
end

function UIController.StopSpectating()
	spectating = false
	if cameraCtrl then
		cameraCtrl.SetSpectatorTarget(nil)
	end
end

-- ---------------------------------------------------------------------------
-- Clue modal
-- ---------------------------------------------------------------------------
function UIController.ShowClueModal(title: string, text: string)
	local clueGui = playerGui:FindFirstChild("ClueModal")
	if not clueGui then
		clueGui = Instance.new("ScreenGui")
		clueGui.Name = "ClueModal"
		clueGui.ResetOnSpawn = false
		clueGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		clueGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Name = "ClueFrame"
		frame.Size = UDim2.new(0, 420, 0, 220)
		frame.Position = UDim2.new(0.5, -210, 0.5, -110)
		frame.BackgroundColor3 = Color3.fromRGB(240, 230, 200)
		frame.BorderSizePixel = 0
		frame.Parent = clueGui

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "TitleLabel"
		titleLbl.Size = UDim2.new(1, -20, 0, 40)
		titleLbl.Position = UDim2.new(0, 10, 0, 10)
		titleLbl.BackgroundTransparency = 1
		titleLbl.TextColor3 = Color3.fromRGB(60, 40, 20)
		titleLbl.TextSize = 22
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = frame

		local textLbl = Instance.new("TextLabel")
		textLbl.Name = "BodyLabel"
		textLbl.Size = UDim2.new(1, -30, 1, -70)
		textLbl.Position = UDim2.new(0, 15, 0, 55)
		textLbl.BackgroundTransparency = 1
		textLbl.TextColor3 = Color3.fromRGB(40, 30, 20)
		textLbl.TextSize = 18
		textLbl.TextWrapped = true
		textLbl.TextXAlignment = Enum.TextXAlignment.Left
		textLbl.Font = Enum.Font.Gotham
		textLbl.Parent = frame

		local closeBtn = Instance.new("TextButton")
		closeBtn.Name = "CloseButton"
		closeBtn.Size = UDim2.new(0, 80, 0, 32)
		closeBtn.Position = UDim2.new(1, -90, 1, -42)
		closeBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 30)
		closeBtn.BorderSizePixel = 0
		closeBtn.Text = "Close"
		closeBtn.TextColor3 = Color3.fromRGB(240, 235, 220)
		closeBtn.TextSize = 16
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.Parent = frame
		closeBtn.MouseButton1Click:Connect(function()
			clueGui.Enabled = false
		end)
	end

	clueGui.Enabled = true
	local frame = clueGui:FindFirstChild("ClueFrame")
	if frame then
		local tLbl = frame:FindFirstChild("TitleLabel")
		local bLbl = frame:FindFirstChild("BodyLabel")
		if tLbl then tLbl.Text = title or "Note" end
		if bLbl then bLbl.Text = text or "" end
	end

	task.delay(8, function()
		if clueGui then clueGui.Enabled = false end
	end)
end

-- ---------------------------------------------------------------------------
-- Round results
-- ---------------------------------------------------------------------------
function UIController.ShowResults(data: table)
	if not resultUI then return end
	resultUI.Enabled = true

	local titleLabel = resultUI:FindFirstChild("ResultTitleLabel", true)
	local reasonLabel = resultUI:FindFirstChild("ResultReasonLabel", true)
	local coinsLabel = resultUI:FindFirstChild("CoinsEarnedLabel", true)

	local myResult = data.Results and data.Results[localPlayer.UserId]

	if titleLabel then
		titleLabel.Text = data.Success and "ESCAPED!" or "GAME OVER"
		titleLabel.TextColor3 = data.Success and Color3.fromRGB(80, 240, 100) or Color3.fromRGB(240, 50, 50)
	end

	if reasonLabel then
		local extra = ""
		if data.RoundTime then
			extra = string.format("\nRound time: %s   Keys: %d/3", Utility.FormatTime(data.RoundTime), data.KeysCollected or 0)
		end
		reasonLabel.Text = (data.Reason or "") .. extra
	end

	if coinsLabel then
		coinsLabel.Text = myResult and string.format("Coins Earned: +%d", myResult.CoinsEarned or 0) or "Coins Earned: +0"
	end

	if audioCtrl then
		if data.Success then
			audioCtrl.PlayOneShot("EscapeSuccess", 0.8, 1.0)
		else
			audioCtrl.PlayOneShot("Warning", 0.5, 0.75)
		end
	end

	task.delay(8, function()
		if resultUI then resultUI.Enabled = false end
	end)
end

-- ---------------------------------------------------------------------------
-- Menu: Shop / Stats / Settings (runtime-built, fully wired)
-- ---------------------------------------------------------------------------
function UIController.BuildMenuUI()
	if menuGui then return end
	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "MenuGui"
	menuGui.ResetOnSpawn = false
	menuGui.Parent = playerGui

	local buttons = Instance.new("Frame")
	buttons.Name = "MenuButtons"
	buttons.Size = UDim2.new(0, 110, 0, 138)
	buttons.Position = UDim2.new(1, -120, 0.02, 0)
	buttons.BackgroundTransparency = 1
	buttons.Parent = menuGui

	local shopBtn = makeButton(buttons, "ShopButton", "SHOP", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 0))
	local statsBtn = makeButton(buttons, "StatsButton", "STATS", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 48))
	local settingsBtn = makeButton(buttons, "SettingsButton", "SETTINGS", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 96))

	shopPanel = makePanel(menuGui, "ShopPanel", "COSMETIC SHOP")
	statsPanel = makePanel(menuGui, "StatsPanel", "YOUR STATS")
	settingsPanel = makePanel(menuGui, "SettingsPanel", "SETTINGS")

	shopBtn.MouseButton1Click:Connect(function()
		local opening = not shopPanel.Visible
		hideAllPanels()
		if opening then
			shopPanel.Visible = true
			if shopRemote then
				shopRemote:FireServer({ Action = "OpenShop" })
			end
			UIController.RenderShop()
		end
		if audioCtrl then audioCtrl.PlayOneShot("UIClick", 0.3, 1.6) end
	end)

	statsBtn.MouseButton1Click:Connect(function()
		local opening = not statsPanel.Visible
		hideAllPanels()
		if opening then
			statsPanel.Visible = true
			if uiRemote then uiRemote:FireServer({ Action = "GetStats" }) end
		end
		if audioCtrl then audioCtrl.PlayOneShot("UIClick", 0.3, 1.6) end
	end)

	settingsBtn.MouseButton1Click:Connect(function()
		local opening = not settingsPanel.Visible
		hideAllPanels()
		if opening then
			settingsPanel.Visible = true
			if uiRemote then uiRemote:FireServer({ Action = "GetSettings" }) end
			UIController.RenderSettings()
		end
		if audioCtrl then audioCtrl.PlayOneShot("UIClick", 0.3, 1.6) end
	end)
end

function UIController.RenderShop()
	if not shopPanel then return end

	local coinsLbl = shopPanel:FindFirstChild("CoinsLabel")
	if not coinsLbl then
		coinsLbl = makeLabel(shopPanel, "CoinsLabel", "", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 46), 18, Color3.fromRGB(245, 215, 100))
	end
	coinsLbl.Text = string.format("Coins: %d", playerCoins)

	local listFrame = shopPanel:FindFirstChild("ListFrame")
	if listFrame then listFrame:Destroy() end
	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "ListFrame"
	listFrame.Size = UDim2.new(1, -20, 1, -90)
	listFrame.Position = UDim2.new(0, 10, 0, 78)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = shopPanel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	local row = 0
	for categoryName, items in pairs(Config.ShopCatalog) do
		for _, item in ipairs(items) do
			row += 1
			local rowFrame = Instance.new("Frame")
			rowFrame.Name = "Row_" .. item.Id
			rowFrame.Size = UDim2.new(1, -6, 0, 44)
			rowFrame.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
			rowFrame.BorderSizePixel = 0
			rowFrame.LayoutOrder = row
			rowFrame.Parent = listFrame

			local isOwned = (ownedCosmetics[categoryName] == item.Id)
			makeLabel(rowFrame, "ItemLabel",
				string.format("%s  —  %d coins%s", item.Name, item.Price, isOwned and "  [OWNED]" or ""),
				UDim2.new(1, -110, 1, 0), UDim2.new(0, 8, 0, 0), 15)

			local buyBtn = makeButton(rowFrame, "BuyButton", isOwned and "EQUIP" or "BUY", UDim2.new(0, 92, 1, -8), UDim2.new(1, -100, 0, 4))
			buyBtn.MouseButton1Click:Connect(function()
				if shopRemote then
					shopRemote:FireServer({
						Action = "Buy",
						Category = categoryName,
						Id = item.Id,
					})
				end
			end)
		end
	end
end

function UIController.RenderStats(data: table)
	if not statsPanel then return end
	local values = {
		{ "Coins", data.Coins or playerCoins or 0 },
		{ "Escapes", data.Escapes or 0 },
		{ "Deaths", data.Deaths or 0 },
		{ "Best Time", data.BestTime and Utility.FormatTime(data.BestTime) or "—" },
	}
	for i, pair in ipairs(values) do
		local lbl = statsPanel:FindFirstChild("Stat_" .. pair[1])
		if not lbl then
			lbl = makeLabel(statsPanel, "Stat_" .. pair[1], "", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 50 + (i - 1) * 34), 20)
		end
		lbl.Text = string.format("%s: %s", pair[1], tostring(pair[2]))
	end
end

function UIController.RenderSettings()
	if not settingsPanel then return end

	local rows = {
		{ key = "MusicVolume", label = "Music Volume", min = 0, max = 1, step = 0.1 },
		{ key = "SFXVolume", label = "SFX Volume", min = 0, max = 1, step = 0.1 },
	}

	for i, def in ipairs(rows) do
		local rowName = "Setting_" .. def.key
		local row = settingsPanel:FindFirstChild(rowName)
		if not row then
			row = Instance.new("Frame")
			row.Name = rowName
			row.Size = UDim2.new(1, -20, 0, 44)
			row.Position = UDim2.new(0, 10, 0, 50 + (i - 1) * 50)
			row.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
			row.BorderSizePixel = 0
			row.Parent = settingsPanel

			makeLabel(row, "RowLabel", def.label, UDim2.new(0.45, 0, 1, 0), UDim2.new(0, 8, 0, 0), 16)

			local minus = makeButton(row, "MinusBtn", "-", UDim2.new(0, 40, 1, -8), UDim2.new(0.5, 0, 0, 4))
			minus.MouseButton1Click:Connect(function()
				settingsState[def.key] = math.max(def.min, math.round((settingsState[def.key] - def.step) * 10) / 10)
				UIController.CommitSettings()
			end)

			local plus = makeButton(row, "PlusBtn", "+", UDim2.new(0, 40, 1, -8), UDim2.new(0.62, 0, 0, 4))
			plus.MouseButton1Click:Connect(function()
				settingsState[def.key] = math.min(def.max, math.round((settingsState[def.key] + def.step) * 10) / 10)
				UIController.CommitSettings()
			end)
		end

		local valueLbl = row:FindFirstChild("ValueLabel")
		if not valueLbl then
			valueLbl = makeLabel(row, "ValueLabel", "", UDim2.new(0, 60, 1, 0), UDim2.new(0.78, 0, 0, 0), 16, Color3.fromRGB(245, 215, 100))
		end
		valueLbl.Text = string.format("%d%%", math.floor(settingsState[def.key] * 100 + 0.5))
	end

	-- Reduced flashing toggle
	local toggName = "Setting_ReducedEffects"
	local togg = settingsPanel:FindFirstChild(toggName)
	if not togg then
		togg = Instance.new("Frame")
		togg.Name = toggName
		togg.Size = UDim2.new(1, -20, 0, 44)
		togg.Position = UDim2.new(0, 10, 0, 150)
		togg.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
		togg.BorderSizePixel = 0
		togg.Parent = settingsPanel

		makeLabel(togg, "RowLabel", "Reduced Flashing", UDim2.new(0.55, 0, 1, 0), UDim2.new(0, 8, 0, 0), 16)

		local toggleBtn = makeButton(togg, "ToggleBtn", "?", UDim2.new(0, 90, 1, -8), UDim2.new(1, -98, 0, 4))
		toggleBtn.MouseButton1Click:Connect(function()
			settingsState.ReducedEffects = not settingsState.ReducedEffects
			UIController.CommitSettings()
		end)
	end
	local toggleBtn = togg:FindFirstChild("ToggleBtn")
	if toggleBtn then
		toggleBtn.Text = settingsState.ReducedEffects and "ON" or "OFF"
		toggleBtn.BackgroundColor3 = settingsState.ReducedEffects
			and Color3.fromRGB(40, 110, 60) or Color3.fromRGB(35, 38, 50)
	end
end

function UIController.CommitSettings()
	UIController.ApplyLocalSettings()
	UIController.RenderSettings()
	if uiRemote then
		uiRemote:FireServer({ Action = "SaveSettings", Settings = {
			MusicVolume = settingsState.MusicVolume,
			SFXVolume = settingsState.SFXVolume,
			ReducedEffects = settingsState.ReducedEffects,
		} })
	end
end

function UIController.ApplyLocalSettings()
	if audioCtrl and audioCtrl.SetVolumes then
		audioCtrl.SetVolumes(settingsState.MusicVolume, settingsState.SFXVolume)
	end
	if cameraCtrl and cameraCtrl.SetReducedEffects then
		cameraCtrl.SetReducedEffects(settingsState.ReducedEffects == true)
	end
end

function UIController.SetupMobileButtons()
	local mobileControlsFrame = mainHUD and mainHUD:FindFirstChild("MobileControlsFrame")
	if mobileControlsFrame then
		mobileControlsFrame.Visible = true
	end
end

return UIController
