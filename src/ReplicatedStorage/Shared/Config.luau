--[[
	Config.luau
	Centralized configuration for DON'T WAKE HIM.
	All tunable gameplay parameters are declared here.
--]]

local Config = {}

-- Round Lifecycle
Config.Round = {
	MinPlayers = 1,
	MaxPlayers = 3,
	CountdownDuration = 10, -- Seconds before round starts
	RoundDuration = 240, -- 4 minutes
	ResultsDuration = 8, -- Seconds result screen stays visible
	IntermissionDuration = 5, -- Time in lobby before next countdown
}

-- Movement Speeds
Config.Movement = {
	WalkSpeed = 14,
	SprintSpeed = 22,
	WalkFootstepInterval = 0.45, -- Seconds between walk footsteps
	SprintFootstepInterval = 0.28, -- Seconds between sprint footsteps
}

-- Noise System (0 to 100)
Config.Noise = {
	MaxNoise = 100,
	DecayRatePerSecond = 5.0, -- Noise reduction per second when quiet
	DecayDelayAfterNoise = 1.0, -- Delay before decay resumes after action
	
	Thresholds = {
		SafeMax = 39,    -- 0-39 SAFE
		AlertMax = 69,   -- 40-69 ALERT
		DangerMax = 89,  -- 70-89 DANGER
		WakeMin = 90,    -- 90-100 WAKE
	},
	
	Contributions = {
		Walk = 1,        -- Periodic +1 while walking
		Run = 3,         -- Periodic +3 while running
		Sprint = 5,      -- Periodic +5 while sprinting
		OpenDoor = 2,    -- Burst +2 on door toggle
		DropItem = 10,   -- Burst +10 on dropping heavy item
		LoudEvent = 20,  -- Major burst +20 (e.g. tripping object)
	},
}

-- Sleeping Man AI
Config.Monster = {
	WalkSpeed = 10,
	ChaseSpeed = 17,
	DetectionRadius = 38, -- Max distance monster can hear/see
	DirectVisionAngle = 65, -- Degrees field of view angle
	
	StateDurations = {
		DisturbedNotice = 3.0, -- Seconds in DISTURBED before returning to sleep if quiet
		WakingDelay = 2.0,     -- Seconds in WAKING reaction window before SEARCHING
		SearchDuration = 7.0,  -- Seconds searching last noise location before returning to sleep
		ChaseLostTimeout = 4.0, -- Seconds out of line-of-sight before dropping chase to SEARCHING
	},
	
	HidingDetectionMultiplier = 0.1, -- Reduced detection multiplier when player is inside hiding spot (90% reduction)
	CatchDistance = 3.5, -- Touch distance for jumpscare/kill trigger
}

-- Objectives & Exit
Config.Objectives = {
	TotalRequired = 3,
	ObjectiveNames = { "Rusty Brass Key", "Master Bedroom Key", "Front Door Keycard" },
	InteractionDistance = 8.5,
}

-- Clues Pool
Config.Clues = {
	{ Title = "Dusty Note", Text = "I left one of the spare keys near the kitchen sink..." },
	{ Title = "Torn Journal Page", Text = "He locks his bedroom door at night. Check the hallway table." },
	{ Title = "Scribbled Paper", Text = "Look around the living room coffee table for clues." },
	{ Title = "Warning Note", Text = "DON'T MAKE NOISE! He wakes up if the noise meter reaches WAKE level!" },
}

-- Rewards & Progression
Config.Rewards = {
	EscapeCoins = 100,
	TimeBonusCoinsPerSec = 0.5, -- Additional coins per remaining second
	CleanBonusCoins = 50, -- Bonus if monster never reached WAKING/CHASING state
	ParticipationCoins = 15, -- Given to caught/spectating players on round end
}

-- DataStore Defaults
Config.DataDefaults = {
	Coins = 0,
	Escapes = 0,
	Deaths = 0,
	BestTime = nil, -- In seconds (lower is better)
	Cosmetics = {
		Flashlight = "Default",
		MonsterSkin = "Default",
		DeathEffect = "Default",
		Title = "Survivor",
	},
	Settings = {
		MusicVolume = 0.8,
		SFXVolume = 1.0,
		ReducedEffects = false,
	},
}

-- Shop & Cosmetics Catalog
Config.ShopCatalog = {
	Flashlights = {
		{ Id = "Flashlight_Default", Name = "Standard Light", Price = 0, Category = "Flashlight" },
		{ Id = "Flashlight_Crimson", Name = "Crimson Lantern", Price = 150, Category = "Flashlight" },
		{ Id = "Flashlight_UV", Name = "UV Nightlight", Price = 300, Category = "Flashlight" },
	},
	Titles = {
		{ Id = "Title_Survivor", Name = "Survivor", Price = 0, Category = "Title" },
		{ Id = "Title_Ghost", Name = "Silent Ghost", Price = 200, Category = "Title" },
		{ Id = "Title_Fearless", Name = "Fearless", Price = 400, Category = "Title" },
	},
}

-- Security & Anti-Exploit
Config.Security = {
	MaxInteractionDistance = 12.0,
	RateLimitEventsPerSec = 15,
}

return Config
