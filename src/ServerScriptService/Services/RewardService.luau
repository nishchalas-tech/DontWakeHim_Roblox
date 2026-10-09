--[[
	RewardService.luau
	Calculates and distributes server-authoritative round rewards.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local RewardService = {}

function RewardService.CalculateRewards(player: Player, escaped: boolean, timeRemaining: number, isCleanRound: boolean)
	local totalCoins = 0
	local breakdown = {
		EscapeReward = 0,
		TimeBonus = 0,
		CleanBonus = 0,
		ParticipationReward = 0,
	}
	
	if escaped then
		breakdown.EscapeReward = Config.Rewards.EscapeCoins
		breakdown.TimeBonus = math.floor(timeRemaining * Config.Rewards.TimeBonusCoinsPerSec)
		if isCleanRound then
			breakdown.CleanBonus = Config.Rewards.CleanBonusCoins
		end
		totalCoins = breakdown.EscapeReward + breakdown.TimeBonus + breakdown.CleanBonus
	else
		breakdown.ParticipationReward = Config.Rewards.ParticipationCoins
		totalCoins = breakdown.ParticipationReward
	end
	
	return totalCoins, breakdown
end

return RewardService
