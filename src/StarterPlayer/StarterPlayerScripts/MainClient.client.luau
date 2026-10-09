--[[
	MainClient.client.luau
	Master Client entry point script for DON'T WAKE HIM.
--]]

local StarterPlayerScripts = script.Parent
local ClientController = require(StarterPlayerScripts.Controllers.ClientController)

ClientController.Init()
