--[[
	CameraController.luau
	Atmospheric camera management, jumpscare camera shake, and spectator view.
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CameraController = {}
local camera = workspace.CurrentCamera
local isJumpscaring = false
local jumpscareTimer = 0
local spectatorTarget = nil
local reducedEffects = false

function CameraController.SetReducedEffects(enabled: boolean)
	reducedEffects = enabled == true
end

function CameraController.Init()
	RunService.RenderStepped:Connect(function(deltaTime)
		if isJumpscaring then
			jumpscareTimer = jumpscareTimer + deltaTime
			if not reducedEffects then
				local shakeX = (math.random() - 0.5) * 0.8
				local shakeY = (math.random() - 0.5) * 0.8
				camera.CFrame = camera.CFrame * CFrame.Angles(shakeX, shakeY, 0)
			end

			if jumpscareTimer >= 1.5 then
				isJumpscaring = false
			end
		elseif spectatorTarget and spectatorTarget.Character and spectatorTarget.Character.PrimaryPart then
			camera.CameraType = Enum.CameraType.Scriptable
			local targetPos = spectatorTarget.Character.PrimaryPart.Position
			camera.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 8), targetPos)
		end
	end)
end

function CameraController.TriggerJumpscare(monsterPosition: Vector3?)
	isJumpscaring = true
	jumpscareTimer = 0
	if monsterPosition then
		camera.CFrame = CFrame.lookAt(camera.CFrame.Position, monsterPosition + Vector3.new(0, 3, 0))
	end
end

function CameraController.SetSpectatorTarget(player: Player?)
	spectatorTarget = player
	if not player then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return CameraController
