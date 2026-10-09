--[[
	ClientController.luau
	Central client initialization module for DON'T WAKE HIM.
	FIXED: script.Parent is the Controllers folder itself, so sibling modules
	are resolved directly from it (previously it looked for a nested
	"Controllers.Controllers" path, which is nil and crashed client boot).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ClientController is a direct child of the "Controllers" folder.
local controllersFolder = script.Parent

local InteractionController = require(controllersFolder:WaitForChild("InteractionController"))
local CameraController = require(controllersFolder:WaitForChild("CameraController"))
local AudioController = require(controllersFolder:WaitForChild("AudioController"))
local UIController = require(controllersFolder:WaitForChild("UIController"))

local ClientController = {}

function ClientController.Init()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

	AudioController.Init()
	CameraController.Init()
	InteractionController.Init(remotesFolder, AudioController)
	UIController.Init(remotesFolder, AudioController, CameraController)

	AudioController.PlayAmbience(true)

	print("[CLIENT] DON'T WAKE HIM client controllers initialized.")
end

return ClientController
