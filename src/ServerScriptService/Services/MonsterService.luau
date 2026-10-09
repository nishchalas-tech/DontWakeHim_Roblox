--[[
	MonsterService.luau
	Server-authoritative Sleeping Man AI state machine & pathing engine.
	- AI decisions run on a throttled tick (not every frame).
	- Movement runs every Heartbeat along PathfindingService waypoints,
	  with straight-line fallback when no path is available.
	- The rig is a jointed R6-style model: limbs are animated procedurally
	  via Motor6D C0 offsets (breathing while sleeping, swing while walking),
	  and the monster physically gets up / lies down through pose tweens.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Utility = require(ReplicatedStorage.Shared.Utility)

local MonsterService = {}
local monsterState = Constants.MonsterState.SLEEPING
local monsterRig = nil
local homeCFrame = CFrame.new()    -- lying on the bed
local standCFrame = CFrame.new()   -- standing beside the bed
local targetNoisePosition = nil
local targetPlayer = nil
local stateTimer = 0
local aiTimer = 0
local monsterRemote = nil
local noiseServiceRef = nil
local interactionServiceRef = nil
local roundServiceRef = nil
local analyticsRef = nil

-- Pose / animation
local AI_TICK = 0.2            -- seconds between AI decisions
local PATH_MIN_INTERVAL = 0.8  -- seconds between path recomputes
local pose = "Lying"           -- "Lying" | "Standing" | "Transition"
local transition = nil         -- {from, to, t, dur, onDone}
local animTime = 0
local walkPhase = 0
local joints = {}              -- name -> Motor6D
local baseC0 = {}              -- name -> original C0
local headStirX = 0            -- current neck stir angles (radians)
local headStirZ = 0

-- Pathing
local activeWaypoints = nil
local waypointIndex = 2
local pathDirty = false
local lastPathRequest = -999
local pendingToken = 0

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- ---------------------------------------------------------------------------
-- Joint cache / procedural animation
-- ---------------------------------------------------------------------------
local function cacheJoints()
	joints = {}
	baseC0 = {}
	if not monsterRig then return end
	local torso = monsterRig:FindFirstChild("Torso")
	if not torso then return end

	local names = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
	for _, name in ipairs(names) do
		local j = torso:FindFirstChild(name)
		if j and j:IsA("Motor6D") then
			joints[name] = j
			baseC0[name] = j.C0
		end
	end
end

local function resetJoints()
	for name, j in pairs(joints) do
		j.C0 = baseC0[name]
	end
	headStirX = 0
	headStirZ = 0
end

local function animateSleeping(dt: number)
	animTime += dt
	local breath = math.sin(animTime * 1.3)

	-- Subtle breathing: shoulders rise/fall slightly, head bobs a touch.
	if joints["Left Shoulder"] then
		joints["Left Shoulder"].C0 = baseC0["Left Shoulder"] * CFrame.Angles(breath * math.rad(2.2), 0, 0)
	end
	if joints["Right Shoulder"] then
		joints["Right Shoulder"].C0 = baseC0["Right Shoulder"] * CFrame.Angles(breath * math.rad(2.2), 0, 0)
	end
	if joints["Neck"] then
		joints["Neck"].C0 = baseC0["Neck"] * CFrame.Angles(breath * math.rad(1.2) + headStirX, 0, headStirZ)
	end
end

local function animateMovement(dt: number, isMoving: boolean)
	if isMoving then
		walkPhase += dt * 9.0
		local swing = math.sin(walkPhase)
		local swingOpp = math.sin(walkPhase + math.pi)
		if joints["Left Shoulder"] then
			joints["Left Shoulder"].C0 = baseC0["Left Shoulder"] * CFrame.Angles(swing * math.rad(38), 0, 0)
		end
		if joints["Right Shoulder"] then
			joints["Right Shoulder"].C0 = baseC0["Right Shoulder"] * CFrame.Angles(swingOpp * math.rad(38), 0, 0)
		end
		if joints["Left Hip"] then
			joints["Left Hip"].C0 = baseC0["Left Hip"] * CFrame.Angles(swingOpp * math.rad(45), 0, 0)
		end
		if joints["Right Hip"] then
			joints["Right Hip"].C0 = baseC0["Right Hip"] * CFrame.Angles(swing * math.rad(45), 0, 0)
		end
	else
		-- Settle back to neutral stand
		walkPhase = 0
		for name, j in pairs(joints) do
			local base = baseC0[name]
			j.C0 = j.C0:Lerp(base, 0.15)
			if (j.C0.Position - base.Position).Magnitude < 0.002 then
				j.C0 = base
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Pose transitions (get up / lie down)
-- ---------------------------------------------------------------------------
local function startTransition(toCF: CFrame, duration: number, donePose: string, onDone: function?)
	if not monsterRig then return end
	resetJoints()
	transition = {
		from = monsterRig:GetPivot(),
		to = toCF,
		t = 0,
		dur = duration,
		donePose = donePose,
		onDone = onDone,
	}
	pose = "Transition"
end

local function advanceTransition(dt: number)
	transition.t += dt
	local alpha = math.clamp(transition.t / transition.dur, 0, 1)
	-- smooth ease in/out
	local eased = alpha * alpha * (3 - 2 * alpha)
	monsterRig:PivotTo(transition.from:Lerp(transition.to, eased))

	if alpha >= 1 then
		pose = transition.donePose
		local cb = transition.onDone
		transition = nil
		if cb then cb() end
	end
end

-- ---------------------------------------------------------------------------
-- Pathfinding (async compute, cached waypoints)
-- ---------------------------------------------------------------------------
local function requestPath(targetPos: Vector3)
	local now = os.clock()
	if now - lastPathRequest < PATH_MIN_INTERVAL then return end
	lastPathRequest = now
	pathDirty = false

	local fromPos = monsterRig:GetPivot().Position
	pendingToken += 1
	local token = pendingToken

	task.spawn(function()
		local ok, err = pcall(function()
			local path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = false,
				AgentCanClimb = false,
				WaypointSpacing = 4,
			})
			path:ComputeAsync(fromPos, targetPos)
			if token ~= pendingToken then return end
			if path.Status == Enum.PathStatus.Success then
				local wps = path:GetWaypoints()
				if #wps >= 2 then
					activeWaypoints = wps
					waypointIndex = 2
					return
				end
			end
			activeWaypoints = nil
		end)
		if not ok and token == pendingToken then
			activeWaypoints = nil -- straight-line fallback
		end
	end)
end

local function followMovement(dt: number, moveTarget: Vector3, speed: number)
	local goal = moveTarget

	if activeWaypoints and waypointIndex <= #activeWaypoints then
		local wp = activeWaypoints[waypointIndex]
		goal = wp.Position
		local mPos = monsterRig:GetPivot().Position
		if horizontalDistance(mPos, goal) < 3 then
			waypointIndex += 1
			if waypointIndex <= #activeWaypoints then
				goal = activeWaypoints[waypointIndex].Position
			else
				activeWaypoints = nil
				goal = moveTarget
			end
		end
	end

	MonsterService.MoveToward(goal, speed, dt)
end

-- ---------------------------------------------------------------------------
-- Init / state
-- ---------------------------------------------------------------------------
function MonsterService.Init(remotesFolder: Folder, monsterModel: Model, noiseService, interactionService, roundService, analyticsService)
	monsterRemote = remotesFolder:FindFirstChild(Constants.RemoteNames.MonsterEvent)
	monsterRig = monsterModel
	homeCFrame = monsterModel and monsterModel:GetPivot() or CFrame.new()
	noiseServiceRef = noiseService
	interactionServiceRef = interactionService
	roundServiceRef = roundService
	analyticsRef = analyticsService

	-- Standing spot: beside the bed, facing the bedroom door.
	local hp = homeCFrame.Position
	standCFrame = CFrame.lookAt(Vector3.new(hp.X, 2, hp.Z - 7), Vector3.new(hp.X + 18, 2, hp.Z - 5))

	-- The rig is physics-driven by PivotTo only: disable humanoid upright
	-- control so the lying pose is never fought with.
	if monsterModel then
		local hum = monsterModel:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum.PlatformStand = true
				hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
				hum:ChangeState(Enum.HumanoidStateType.Physics)
				hum.BreakJointsOnDeath = false
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				hum.NameDisplayDistance = 0
			end)
		end
	end

	cacheJoints()
	pose = "Lying"

	-- Register self with noise service
	noiseService.MonsterService = MonsterService

	-- Monster Loop: runs every frame (glue/animation), decisions throttled
	RunService.Heartbeat:Connect(function(deltaTime)
		MonsterService.UpdateAI(deltaTime)
	end)

	print("[MONSTER] MonsterService initialized. AI tick:", AI_TICK, "s")
end

function MonsterService.GetState(): string
	return monsterState
end

function MonsterService.SetState(newState: string)
	if monsterState == newState then return end
	monsterState = newState
	stateTimer = 0

	if monsterRemote then
		monsterRemote:FireAllClients({
			Action = "StateChanged",
			State = newState,
			Position = monsterRig and monsterRig:GetPivot().Position or Vector3.new(),
		})
	end

	if analyticsRef then
		if newState == Constants.MonsterState.WAKING then
			analyticsRef.TrackEvent(Constants.AnalyticsEvents.MonsterWoke)
		elseif newState == Constants.MonsterState.CHASING then
			analyticsRef.TrackEvent(Constants.AnalyticsEvents.ChaseStarted)
		end
	end
end

function MonsterService.OnNoiseEmitted(noiseLevel: number, noisePosition: Vector3?)
	if monsterState == Constants.MonsterState.SLEEPING then
		if noiseLevel >= Config.Noise.Thresholds.WakeMin then
			MonsterService.SetState(Constants.MonsterState.WAKING)
			targetNoisePosition = noisePosition
		elseif noiseLevel >= Config.Noise.Thresholds.AlertMax then
			MonsterService.SetState(Constants.MonsterState.DISTURBED)
			targetNoisePosition = noisePosition
		end
	elseif monsterState == Constants.MonsterState.DISTURBED then
		if noiseLevel >= Config.Noise.Thresholds.WakeMin or noiseLevel >= Config.Noise.Thresholds.DangerMax then
			MonsterService.SetState(Constants.MonsterState.WAKING)
			targetNoisePosition = noisePosition or targetNoisePosition
		end
	elseif monsterState == Constants.MonsterState.SEARCHING then
		if noisePosition then
			targetNoisePosition = noisePosition
			pathDirty = true
		end
	elseif monsterState == Constants.MonsterState.CHASING then
		if noisePosition then
			pathDirty = true
		end
	end
end

-- ---------------------------------------------------------------------------
-- Per-frame orchestrator (glue + animation + throttled decisions)
-- ---------------------------------------------------------------------------
function MonsterService.UpdateAI(deltaTime: number)
	if not monsterRig then return end

	-- Pose transitions always run first (get up / lie down)
	if transition then
		advanceTransition(deltaTime)
		return
	end

	if monsterState == Constants.MonsterState.SLEEPING then
		if pose == "Lying" then
			monsterRig:PivotTo(homeCFrame) -- keep the unanchored rig glued to the bed
			animateSleeping(deltaTime)
		end
		return
	end

	stateTimer = stateTimer + deltaTime
	aiTimer = aiTimer + deltaTime

	if monsterState == Constants.MonsterState.DISTURBED then
		-- Still lying: keep breathing while the tick stirs the head.
		animateSleeping(deltaTime)
		if aiTimer >= AI_TICK then
			aiTimer = aiTimer - AI_TICK
			MonsterService.RunStateTick()
		end
		return
	end

	-- WAKING may begin lying down; the tick starts the get-up transition.
	if pose ~= "Standing" then
		if pose == "Lying" then
			animateSleeping(deltaTime)
		end
		if monsterState == Constants.MonsterState.WAKING and aiTimer >= AI_TICK then
			aiTimer = aiTimer - AI_TICK
			MonsterService.RunStateTick()
		end
		return
	end

	local isMoving = (monsterState == Constants.MonsterState.SEARCHING or monsterState == Constants.MonsterState.CHASING)
		and targetNoisePosition ~= nil
	animateMovement(deltaTime, isMoving)

	if aiTimer >= AI_TICK then
		aiTimer = aiTimer - AI_TICK
		MonsterService.RunStateTick()
	end

	-- Continuous movement every frame (smooth, not stepped)
	local moveTarget = nil
	local speed = Config.Monster.WalkSpeed
	if monsterState == Constants.MonsterState.SEARCHING then
		moveTarget = targetNoisePosition
	elseif monsterState == Constants.MonsterState.CHASING then
		moveTarget = MonsterService.GetTargetPosition()
		speed = Config.Monster.ChaseSpeed
	end

	if moveTarget then
		followMovement(deltaTime, moveTarget, speed)
	end
end

function MonsterService.GetTargetPosition(): Vector3?
	if not targetPlayer then return nil end
	local char = targetPlayer.Character
	if not char then return nil end
	local p = char.PrimaryPart or char:GetPivot()
	return p.Position
end

-- ---------------------------------------------------------------------------
-- Throttled AI decisions
-- ---------------------------------------------------------------------------
function MonsterService.RunStateTick()
	local monsterPos = monsterRig:GetPivot().Position

	if monsterState == Constants.MonsterState.DISTURBED then
		-- Stir: turn the head toward the noise source (still lying down)
		if targetNoisePosition and joints["Neck"] then
			local dn = targetNoisePosition - monsterPos
			local targetX = math.clamp(math.rad(dn.Z * 2.5), math.rad(-30), math.rad(30))
			local targetZ = math.clamp(math.rad(-dn.X * 2.5), math.rad(-30), math.rad(30))
			headStirX = headStirX + (targetX - headStirX) * 0.25
			headStirZ = headStirZ + (targetZ - headStirZ) * 0.25
		end

		if stateTimer >= Config.Monster.StateDurations.DisturbedNotice then
			-- Back to sleep if nothing else happened
			headStirX, headStirZ = 0, 0
			MonsterService.SetState(Constants.MonsterState.SLEEPING)
		end

	elseif monsterState == Constants.MonsterState.WAKING then
		-- Get up on the first tick of waking
		if pose == "Lying" then
			startTransition(standCFrame, 1.0, "Standing", function()
				print("[MONSTER] Awake and on his feet.")
			end)
			return
		end

		if stateTimer >= Config.Monster.StateDurations.WakingDelay and pose == "Standing" then
			MonsterService.SetState(Constants.MonsterState.SEARCHING)
			pathDirty = true
		end

	elseif monsterState == Constants.MonsterState.SEARCHING then
		if not targetNoisePosition then
			MonsterService.ReturnHome()
			return
		end

		if pathDirty or activeWaypoints == nil then
			requestPath(targetNoisePosition)
		end

		local dist = horizontalDistance(monsterPos, targetNoisePosition)
		if dist < 4.0 or stateTimer >= Config.Monster.StateDurations.SearchDuration then
			-- Check for visible players before returning to sleep
			local spotted = MonsterService.ScanForPlayers()
			if not spotted then
				MonsterService.ReturnHome()
			end
		end

	elseif monsterState == Constants.MonsterState.CHASING then
		-- Validate target
		if not targetPlayer or not Utility.IsPlayerAlive(targetPlayer) then
			targetPlayer = nil
			MonsterService.SetState(Constants.MonsterState.SEARCHING)
			pathDirty = true
			return
		end

		local isHiding = interactionServiceRef and interactionServiceRef.IsPlayerHiding(targetPlayer)
		local pPos = MonsterService.GetTargetPosition()
		if not pPos then
			targetPlayer = nil
			MonsterService.SetState(Constants.MonsterState.SEARCHING)
			return
		end

		local dist = horizontalDistance(monsterPos, pPos)
		if isHiding and dist > Config.Monster.CatchDistance then
			-- Lost them behind the wardrobe
			targetPlayer = nil
			MonsterService.SetState(Constants.MonsterState.SEARCHING)
			pathDirty = true
			return
		end

		-- Re-path to the moving target regularly
		if pathDirty or (os.clock() - lastPathRequest) > 0.75 then
			requestPath(pPos)
		end

		if dist <= Config.Monster.CatchDistance then
			MonsterService.CatchPlayer(targetPlayer)
		end
	end

	-- Continuous scan for nearby visible players while active
	if monsterState == Constants.MonsterState.SEARCHING or monsterState == Constants.MonsterState.CHASING then
		MonsterService.ScanForPlayers()
	end
end

function MonsterService.ScanForPlayers(): boolean
	if not monsterRig then return false end
	local monsterPos = monsterRig:GetPivot().Position

	for _, player in ipairs(Players:GetPlayers()) do
		if Utility.IsPlayerAlive(player) then
			local isHiding = interactionServiceRef and interactionServiceRef.IsPlayerHiding(player)
			local char = player.Character
			local pPos = (char.PrimaryPart or char:GetPivot()).Position
			local dist = Utility.GetDistance(monsterPos, pPos)

			local effectiveRadius = Config.Monster.DetectionRadius
			if isHiding then
				effectiveRadius = effectiveRadius * Config.Monster.HidingDetectionMultiplier
			end

			if dist <= effectiveRadius then
				-- A hiding player right next to him is discovered (he is
				-- standing at the wardrobe); otherwise the wardrobe blocks LOS.
				if isHiding and dist <= Config.Monster.CatchDistance then
					targetPlayer = player
					MonsterService.SetState(Constants.MonsterState.CHASING)
					return true
				end

				-- Line of sight check (walls block vision)
				local direction = (pPos - monsterPos).Unit
				local ray = Ray.new(monsterPos + Vector3.new(0, 2, 0), direction * dist)
				local ignoreList = { monsterRig, char }
				local hitPart = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)

				if not hitPart then
					-- Clear line of sight!
					targetPlayer = player
					MonsterService.SetState(Constants.MonsterState.CHASING)
					pathDirty = true
					return true
				end
			end
		end
	end
	return false
end

function MonsterService.MoveToward(targetPos: Vector3, speed: number, deltaTime: number)
	local currentCF = monsterRig:GetPivot()
	local currentPos = currentCF.Position
	local dir = (targetPos - currentPos)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)

	if flatDir.Magnitude > 0.5 then
		local moveStep = flatDir.Unit * speed * deltaTime
		local newPos = currentPos + moveStep
		local lookCF = CFrame.lookAt(newPos, newPos + flatDir.Unit)
		monsterRig:PivotTo(lookCF)
	end
end

function MonsterService.CatchPlayer(player: Player)
	if not player then return end

	-- Trigger Jumpscare on Client (with monster position for camera aim)
	if monsterRemote then
		monsterRemote:FireClient(player, {
			Action = "Jumpscare",
			Position = monsterRig and monsterRig:GetPivot().Position or Vector3.new(),
		})
	end

	-- Clear any stale hiding state for the caught player
	if interactionServiceRef and interactionServiceRef.ClearHidingState then
		interactionServiceRef.ClearHidingState(player)
	end

	-- Notify RoundService of player catch/death
	if roundServiceRef then
		roundServiceRef.OnPlayerCaught(player)
	end

	targetPlayer = nil
	activeWaypoints = nil
	MonsterService.SetState(Constants.MonsterState.SEARCHING)
	pathDirty = true
end

function MonsterService.ReturnHome()
	targetNoisePosition = nil
	targetPlayer = nil
	activeWaypoints = nil

	if monsterRig and pose ~= "Lying" then
		-- Lie back down smoothly; state reports SLEEPING right away.
		MonsterService.SetState(Constants.MonsterState.SLEEPING)
		startTransition(homeCFrame, 0.9, "Lying", function()
			resetJoints()
		end)
	else
		if monsterRig then
			monsterRig:PivotTo(homeCFrame)
		end
		MonsterService.SetState(Constants.MonsterState.SLEEPING)
	end
end

function MonsterService.Reset()
	transition = nil
	activeWaypoints = nil
	targetNoisePosition = nil
	targetPlayer = nil
	stateTimer = 0
	aiTimer = 0
	walkPhase = 0
	monsterState = Constants.MonsterState.SLEEPING
	pose = "Lying"
	pathDirty = false
	resetJoints()
	if monsterRig then
		monsterRig:PivotTo(homeCFrame)
	end
end

return MonsterService
