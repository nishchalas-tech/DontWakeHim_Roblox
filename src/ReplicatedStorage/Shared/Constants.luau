--[[
	Constants.luau
	Enums, states, and constants for DON'T WAKE HIM.
--]]

local Constants = {}

Constants.RoundState = {
	LOBBY = "LOBBY",
	COUNTDOWN = "COUNTDOWN",
	STARTING = "STARTING",
	ACTIVE = "ACTIVE",
	ENDING = "ENDING",
	RESULTS = "RESULTS",
	RESETTING = "RESETTING",
}

Constants.MonsterState = {
	SLEEPING = "SLEEPING",
	DISTURBED = "DISTURBED",
	WAKING = "WAKING",
	SEARCHING = "SEARCHING",
	CHASING = "CHASING",
}

Constants.PlayerState = {
	LOBBY = "LOBBY",
	PLAYING = "PLAYING",
	HIDING = "HIDING",
	ESCAPED = "ESCAPED",
	DEAD = "DEAD",
	SPECTATING = "SPECTATING",
}

Constants.NoiseLevel = {
	SAFE = "SAFE",
	ALERT = "ALERT",
	DANGER = "DANGER",
	WAKE = "WAKE",
}

Constants.InteractionType = {
	KEY = "KEY",
	DOOR = "DOOR",
	EXIT = "EXIT",
	HIDING_SPOT = "HIDING_SPOT",
	LOUD_OBJECT = "LOUD_OBJECT",
}

-- RemoteEvents and their direction (both sides verified in code):
--   RoundEvent      SERVER -> CLIENT (state, timer, results)
--   ObjectiveEvent  SERVER -> CLIENT (key progress, exit unlocked)
--   NoiseEvent      CLIENT -> SERVER (movement/action noise) ; SERVER -> CLIENT (meter updates)
--   MonsterEvent    SERVER -> CLIENT (state changes, jumpscare)
--   UIEvent         CLIENT -> SERVER (GetStats/GetSettings/SaveSettings) ; SERVER -> CLIENT (clues, sounds, data)
--   ShopEvent       CLIENT -> SERVER (OpenShop/Buy) ; SERVER -> CLIENT (ShopData/PurchaseResult)
Constants.RemoteNames = {
	RoundEvent = "RoundEvent",
	ObjectiveEvent = "ObjectiveEvent",
	NoiseEvent = "NoiseEvent",
	MonsterEvent = "MonsterEvent",
	UIEvent = "UIEvent",
	ShopEvent = "ShopEvent",
}

Constants.AnalyticsEvents = {
	RoundStarted = "RoundStarted",
	RoundCompleted = "RoundCompleted",
	PlayerEscaped = "PlayerEscaped",
	PlayerCaught = "PlayerCaught",
	ObjectiveCollected = "ObjectiveCollected",
	MonsterWoke = "MonsterWoke",
	ChaseStarted = "ChaseStarted",
	RoundTimedOut = "RoundTimedOut",
	ShopOpened = "ShopOpened",
	CosmeticPurchased = "CosmeticPurchased",
	PlayerDied = "PlayerDied",
	PlayerLeftDuringRound = "PlayerLeftDuringRound",
}

return Constants
