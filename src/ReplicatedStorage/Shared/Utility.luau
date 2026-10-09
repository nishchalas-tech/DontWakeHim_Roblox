--[[
	Utility.luau
	Helper routines for DON'T WAKE HIM.
--]]

local Utility = {}

function Utility.GetDistance(posA: Vector3, posB: Vector3): number
	return (posA - posB).Magnitude
end

function Utility.IsPlayerAlive(player: Player): boolean
	if not player or not player.Character then
		return false
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function Utility.CreateRateLimiter(maxPerSec: number)
	local requests = {}
	return function(player: Player): boolean
		local now = os.clock()
		local pId = player.UserId
		requests[pId] = requests[pId] or {}
		
		-- Prune old entries
		local valid = {}
		for _, t in ipairs(requests[pId]) do
			if now - t < 1.0 then
				table.insert(valid, t)
			end
		end
		
		if #valid >= maxPerSec then
			return false -- Rate limit exceeded
		end
		
		table.insert(valid, now)
		requests[pId] = valid
		return true
	end
end

function Utility.FormatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

return Utility
