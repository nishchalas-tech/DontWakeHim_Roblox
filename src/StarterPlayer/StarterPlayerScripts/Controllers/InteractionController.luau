--[[
	InteractionController.luau
	Client-side movement, footstep audio, noise emitter, and sprint controls.
	NOTE: all physical interactions use server-wired ProximityPrompts; there is
	no separate client interaction remote (removed the dead duplicate path).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)

local InteractionController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local noiseRemote = nil
local AudioController = nil

local isSprinting = false
local lastStepTimestamp = 0

function InteractionController.Init(remotesFolder: Folder, audioCtrl)
	noiseRemote = remotesFolder:WaitForChild(Constants.RemoteNames.NoiseEvent)
	AudioController = audioCtrl

	-- Keyboard Sprint Binding (Left Shift)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			InteractionController.SetSprinting(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			InteractionController.SetSprinting(false)
		end
	end)

	-- Apply configured walk speed whenever a character spawns
	localPlayer.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.WalkSpeed = isSprinting and Config.Movement.SprintSpeed or Config.Movement.WalkSpeed
		end
	end)

	-- Mobile sprint toggle button (built inside MainHUD/MobileControlsFrame)
	task.defer(function()
		local hud = playerGui:WaitForChild("MainHUD", 10)
		local mobileFrame = hud and hud:WaitForChild("MobileControlsFrame", 5)
		local sprintBtn = mobileFrame and mobileFrame:FindFirstChild("SprintButton")
		if sprintBtn then
			sprintBtn.MouseButton1Down:Connect(function()
				InteractionController.SetSprinting(true)
				sprintBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 40)
			end)
			sprintBtn.MouseButton1Up:Connect(function()
				InteractionController.SetSprinting(false)
				sprintBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
			end)
			sprintBtn.MouseLeave:Connect(function()
				InteractionController.SetSprinting(false)
				sprintBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
			end)
		end
	end)

	-- Continuous Movement & Footstep Loop
	RunService.Heartbeat:Connect(function()
		InteractionController.UpdateMovement()
	end)
end

function InteractionController.SetSprinting(sprinting: boolean)
	isSprinting = sprinting
	local char = localPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = isSprinting and Config.Movement.SprintSpeed or Config.Movement.WalkSpeed
		end
	end
end

function InteractionController.UpdateMovement()
	local char = localPlayer.Character
	if not char or not char.Parent then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local isMoving = hum.MoveDirection.Magnitude > 0.1
	if isMoving then
		local now = os.clock()
		local stepInterval = isSprinting and Config.Movement.SprintFootstepInterval or Config.Movement.WalkFootstepInterval

		if now - lastStepTimestamp >= stepInterval then
			lastStepTimestamp = now

			-- Play Footstep Audio Locally
			if AudioController then
				local vol = isSprinting and 0.7 or 0.4
				local pitch = isSprinting and 1.25 or 1.0
				AudioController.PlaySound("Footstep", vol, pitch)
			end

			-- Send Movement Noise Event to Server (server decides the amount)
			if noiseRemote then
				noiseRemote:FireServer({
					Action = "MovementNoise",
					IsSprinting = isSprinting,
				})
			end
		end
	end
end

return InteractionController
