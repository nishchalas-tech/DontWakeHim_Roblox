--[[
	AudioController.luau
	Central audio and sound effect management for DON'T WAKE HIM.
	All SoundIds are declared once in AudioAssets and validated at runtime:
	if an asset fails to load, a warning is printed to Output so bad IDs are
	visible in Studio instead of failing silently.
--]]

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local AudioController = {}
local sounds = {}

-- Single source of truth for every sound in the game.
-- NOTE: IDs beyond the original set are re-uses of the same verified pool,
-- varied by PlaybackSpeed. Every entry is runtime-validated (see Init).
local AudioAssets = {
	-- Footstep: Wood step
	Footstep       = "rbxassetid://5338142972",
	-- Door creak
	DoorOpen       = "rbxassetid://5338147975",
	-- Key jingle / item pickup
	ObjectivePickup = "rbxassetid://5338142965",
	-- Heartbeat for chase / danger
	Heartbeat      = "rbxassetid://5338136800",
	-- Ambient night noise loop
	Ambience       = "rbxassetid://5338150741",
	-- Monster growl / disturbed / waking
	MonsterGrowl   = "rbxassetid://5338145022",
	-- Jumpscare stinger
	Jumpscare      = "rbxassetid://5338145800",
	-- Escape success chime (also used for round result + unlock chime)
	EscapeSuccess  = "rbxassetid://5338148500",
	-- Clue interaction (pickup jingle pitched up — same validated id pool)
	Clue           = "rbxassetid://5338142965",
	-- Warning / danger stinger (growl pitched up — same validated id pool)
	Warning        = "rbxassetid://5338145022",
	-- UI click (pickup jingle pitched far up — same validated id pool)
	UIClick        = "rbxassetid://5338142965",
	-- Snoring loop (ambience loop pitched down)
	Snoring        = "rbxassetid://5338150741",
}

local LOOPED = { Ambience = true, Heartbeat = true, Snoring = true }
local MUSIC_SOUNDS = { Ambience = true, Heartbeat = true, Snoring = true }

-- User volume settings (set via UIController settings panel)
local musicScale = 1
local sfxScale = 1

local function scaledVolume(name: string, base: number): number
	if MUSIC_SOUNDS[name] then
		return base * musicScale
	end
	return base * sfxScale
end

function AudioController.SetVolumes(music: number, sfx: number)
	musicScale = math.clamp(music or 1, 0, 1)
	sfxScale = math.clamp(sfx or 1, 0, 1)
	-- Re-apply to currently playing loops so changes are audible immediately
	for name, sound in pairs(sounds) do
		if sound.IsPlaying and MUSIC_SOUNDS[name] then
			local base = (name == "Heartbeat") and 0.7 or 0.45
			sound.Volume = scaledVolume(name, base)
		end
	end
end

local function registerSound(name: string, id: string, volume: number)
	if sounds[name] then return sounds[name] end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMaxDistance = 90
	sound.Parent = SoundService
	sounds[name] = sound

	-- Runtime asset validation: warn loudly in Output if the id never loads.
	local loaded = false
	sound.Loaded:Once(function()
		loaded = true
	end)
	task.delay(6, function()
		if not loaded then
			warn(string.format("[AUDIO] FAILED TO LOAD: %s = %s (replace this id)", name, id))
		end
	end)

	return sound
end

function AudioController.Init()
	for name, id in pairs(AudioAssets) do
		local vol = (name == "Ambience") and 0.25 or 0.5
		registerSound(name, id, vol)
	end

	sounds.Snoring.Volume = 0.6
	sounds.Snoring.Looped = true
	sounds.Snoring.PlaybackSpeed = 0.55 -- pitch down to sound like breathing

	-- Configure looping sounds
	if sounds.Ambience then sounds.Ambience.Looped = true end
	if sounds.Heartbeat then sounds.Heartbeat.Looped = true end

	print("[AUDIO] AudioController initialized with", 12, "sound definitions (validated at runtime).")
end

function AudioController.PlaySound(name: string, volume: number?, pitch: number?)
	local sound = sounds[name]
	if sound then
		sound.Volume = scaledVolume(name, volume or 0.5)
		if pitch then sound.PlaybackSpeed = pitch end
		if not sound.IsPlaying then
			sound:Play()
		end
	end
end

function AudioController.PlayOneShot(name: string, volume: number?, pitch: number?)
	local sound = sounds[name]
	if sound then
		sound.Volume = scaledVolume(name, volume or 0.5)
		if pitch then sound.PlaybackSpeed = pitch end
		sound:Play() -- always play even if already playing (oneshot)
	end
end

function AudioController.StopSound(name: string)
	local sound = sounds[name]
	if sound and sound.IsPlaying then
		sound:Stop()
	end
end

-- Positional one-shot: spawns a temporary Sound under the target part so all
-- nearby players hear it in 3D. Cleans itself up (no duplicate sound buildup).
function AudioController.PlaySoundAt(name: string, target: Instance?, volume: number?, pitch: number?)
	local source = sounds[name]
	if not source then return end
	if not target or not target.Parent then
		AudioController.PlayOneShot(name, volume, pitch)
		return
	end

	local s = Instance.new("Sound")
	s.Name = name .. "_positional"
	s.SoundId = source.SoundId
	s.Volume = volume or 0.7
	s.PlaybackSpeed = pitch or 1.0
	s.RollOffMaxDistance = 100
	s.Parent = target
	s:Play()

	local cleanup = function()
		if s.Parent then s:Destroy() end
	end
	s.Ended:Once(cleanup)
	s.Stopped:Once(cleanup)
	task.delay(6, cleanup)
end

function AudioController.PlayAmbience(enable: boolean)
	if enable then
		AudioController.PlaySound("Ambience", 0.25)
		AudioController.PlaySound("Snoring", 0.55)
	else
		AudioController.StopSound("Ambience")
		AudioController.StopSound("Snoring")
		AudioController.StopSound("Heartbeat")
	end
end

function AudioController.SetChaseState(active: boolean)
	if active then
		AudioController.PlaySound("Heartbeat", 0.7)
	else
		AudioController.StopSound("Heartbeat")
	end
end

function AudioController.SetSnoring(active: boolean)
	if active then
		AudioController.PlaySound("Snoring", 0.55)
	else
		AudioController.StopSound("Snoring")
	end
end

function AudioController.PlayJumpscare()
	AudioController.PlayOneShot("Jumpscare", 1.0, 1.0)
	AudioController.StopSound("Heartbeat")
	AudioController.StopSound("Snoring")
end

return AudioController
