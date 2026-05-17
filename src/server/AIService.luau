--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fish = require(script.Parent:WaitForChild("Fish"))

local AIService = {}

local PHASE_ATTR = Config.Level.PhaseAttr
local PLAYING = Config.Phase.Playing
local SIZE_ATTR = Fish.SIZE_ATTRIBUTE
local AI = Config.AI

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Per-AI state (server only, no replication needed)
type AIState = {
	currentDir: Vector3,
	wanderDir: Vector3,
	wanderTimer: number,
	boostActiveUntil: number,
	boostReadyAt: number,
	boostPending: boolean,
	boostRollTimer: number,
	-- Cached references to visual child parts (Anchored, driven manually each frame)
	tail: BasePart?,
	finL: BasePart?,
	finR: BasePart?,
}

local aiStates: { [BasePart]: AIState } = {}

local function newState(): AIState
	local angle = math.random() * math.pi * 2
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return {
		currentDir = dir,
		wanderDir = dir,
		wanderTimer = AI.WanderMinSeconds + math.random() * (AI.WanderMaxSeconds - AI.WanderMinSeconds),
		boostActiveUntil = 0,
		boostReadyAt = 0,
		boostPending = false,
		boostRollTimer = AI.BoostRollMinSeconds + math.random() * (AI.BoostRollMaxSeconds - AI.BoostRollMinSeconds),
		tail = nil,
		finL = nil,
		finR = nil,
	}
end

local function getState(part: BasePart): AIState
	local s = aiStates[part]
	if not s then
		s = newState()
		-- Cache visual child parts once (created by Fish.createAI, always children of body)
		s.tail = part:FindFirstChild("FishTail") :: BasePart?
		s.finL = part:FindFirstChild("FinL") :: BasePart?
		s.finR = part:FindFirstChild("FinR") :: BasePart?
		aiStates[part] = s
	end
	return s
end

-- Desired movement direction: flee > chase > wander, with boundary steering override
local function computeDesiredDir(part: BasePart, state: AIState, dt: number, aiFishes: { BasePart }): Vector3
	local myPos = part.Position
	local mySize = part:GetAttribute(SIZE_ATTR)
	if typeof(mySize) ~= "number" then
		return state.wanderDir
	end

	-- Boundary: pull back toward center before anything else
	local center = AI.SpawnAreaCenter
	local dx = myPos.X - center.X
	local dz = myPos.Z - center.Z
	local distSq = dx * dx + dz * dz
	local boundary = AI.BoundarySteerRatio * AI.SpawnAreaRadius
	if distSq > boundary * boundary then
		local dist = math.sqrt(distSq)
		return Vector3.new(-dx / dist, 0, -dz / dist)
	end

	local fleeVec = Vector3.zero
	local fleeCount = 0
	local chasePos: Vector3? = nil
	local chaseDistSq = math.huge

	local function consider(pos: Vector3, size: number)
		local diffX = pos.X - myPos.X
		local diffZ = pos.Z - myPos.Z
		local distSqLocal = diffX * diffX + diffZ * diffZ
		if size > mySize and distSqLocal < AI.FleeRadius * AI.FleeRadius then
			local mag = math.sqrt(distSqLocal)
			if mag > 0.001 then
				fleeVec -= Vector3.new(diffX / mag, 0, diffZ / mag)
				fleeCount += 1
			end
		elseif size < mySize and distSqLocal < AI.ChaseRadius * AI.ChaseRadius then
			if distSqLocal < chaseDistSq then
				chaseDistSq = distSqLocal
				chasePos = pos
			end
		end
	end

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local s = player:GetAttribute(SIZE_ATTR)
		if hrp and typeof(s) == "number" then
			consider(hrp.Position, s)
		end
	end

	for _, other in aiFishes do
		if other == part then
			continue
		end
		local s = other:GetAttribute(SIZE_ATTR)
		if typeof(s) == "number" then
			consider(other.Position, s)
		end
	end

	if fleeCount > 0 then
		local flat = Vector3.new(fleeVec.X, 0, fleeVec.Z)
		if flat.Magnitude > 0.001 then
			return flat.Unit
		end
	end

	if chasePos then
		local diffX = chasePos.X - myPos.X
		local diffZ = chasePos.Z - myPos.Z
		local mag = math.sqrt(diffX * diffX + diffZ * diffZ)
		if mag > 0.001 then
			return Vector3.new(diffX / mag, 0, diffZ / mag)
		end
	end

	-- Wander: pick a new random direction when timer expires
	state.wanderTimer -= dt
	if state.wanderTimer <= 0 then
		local angle = math.random() * math.pi * 2
		state.wanderDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		state.wanderTimer = AI.WanderMinSeconds + math.random() * (AI.WanderMaxSeconds - AI.WanderMinSeconds)
	end
	return state.wanderDir
end

-- Probabilistic AI boost trigger with reaction delay (PRD §10.2 AI rules)
local function tryBoost(part: BasePart, state: AIState)
	if state.boostPending or state.boostReadyAt > now() then
		return
	end
	local myPos = part.Position
	local mySize = part:GetAttribute(SIZE_ATTR)
	if typeof(mySize) ~= "number" then
		return
	end

	local threatened = false
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local s = player:GetAttribute(SIZE_ATTR)
		if hrp and typeof(s) == "number" and s > mySize then
			local diff = hrp.Position - myPos
			if diff:Dot(diff) < AI.BoostPanicRadius * AI.BoostPanicRadius then
				threatened = true
				break
			end
		end
	end

	local chance = AI.BoostBaseProbability + (if threatened then AI.BoostPanicProbability else 0)
	if math.random() > chance then
		return
	end

	-- Humanize: random reaction delay before boost activates
	state.boostPending = true
	local delay = AI.BoostReactionDelayMin + math.random() * (AI.BoostReactionDelayMax - AI.BoostReactionDelayMin)
	task.delay(delay, function()
		local s2 = aiStates[part]
		if not s2 or not part.Parent then
			return
		end
		s2.boostPending = false
		local t = now()
		s2.boostActiveUntil = t + Config.Boost.Duration
		s2.boostReadyAt = t + Config.Boost.Duration + Config.Boost.Cooldown
	end)
end

-- AI vs AI predation: strictly larger eats smaller → relocate the smaller (1:1 respawn, no size gain)
local function checkAIvsAI(aiFishes: { BasePart })
	for i = 1, #aiFishes - 1 do
		for j = i + 1, #aiFishes do
			local a, b = aiFishes[i], aiFishes[j]
			local aSize = a:GetAttribute(SIZE_ATTR)
			local bSize = b:GetAttribute(SIZE_ATTR)
			if typeof(aSize) ~= "number" or typeof(bSize) ~= "number" or aSize == bSize then
				continue
			end
			local r = a.Size.X * 0.5 + b.Size.X * 0.5
			local diff = a.Position - b.Position
			if diff:Dot(diff) < r * r then
				if aSize > bSize then
					Fish.relocateAI(b)
				else
					Fish.relocateAI(a)
				end
			end
		end
	end
end

function AIService.start(aiFishes: { BasePart })
	local aiAIAccum = 0
	local AI_AI_INTERVAL = 1 / 10

	RunService.Heartbeat:Connect(function(dt)
		if workspace:GetAttribute(PHASE_ATTR) ~= PLAYING then
			return
		end

		-- Lazy cleanup: remove states for parts that have been destroyed
		for part in aiStates do
			if not part.Parent then
				aiStates[part] = nil
			end
		end

		aiAIAccum += dt
		if aiAIAccum >= AI_AI_INTERVAL then
			aiAIAccum = 0
			checkAIvsAI(aiFishes)
		end

		local t = now()
		for _, part in aiFishes do
			local state = getState(part)

			-- Per-AI boost roll on its own staggered timer
			state.boostRollTimer -= dt
			if state.boostRollTimer <= 0 then
				state.boostRollTimer = AI.BoostRollMinSeconds
					+ math.random() * (AI.BoostRollMaxSeconds - AI.BoostRollMinSeconds)
				tryBoost(part, state)
			end

			-- Smooth direction toward desired (turn rate: ~4 rad/s)
			local desired = computeDesiredDir(part, state, dt, aiFishes)
			local blended = state.currentDir:Lerp(desired, math.min(1, dt * 4))
			if blended.Magnitude > 0.001 then
				state.currentDir = blended.Unit
			end

		local speed = if state.boostActiveUntil > t then AI.Speed * Config.Boost.Multiplier else AI.Speed
		local newPos = part.Position + state.currentDir * speed * dt

		-- Keep fixed Y, hard-clamp to arena circle
		newPos = Vector3.new(newPos.X, part.Position.Y, newPos.Z)
		local cx = newPos.X - AI.SpawnAreaCenter.X
		local cz = newPos.Z - AI.SpawnAreaCenter.Z
		local cdSq = cx * cx + cz * cz
		if cdSq > AI.SpawnAreaRadius * AI.SpawnAreaRadius then
			local cd = math.sqrt(cdSq)
			newPos = Vector3.new(
				AI.SpawnAreaCenter.X + cx / cd * AI.SpawnAreaRadius,
				newPos.Y,
				AI.SpawnAreaCenter.Z + cz / cd * AI.SpawnAreaRadius
			)
		end

		-- Rotate fish to face its movement direction so the elongated mesh looks right
		local dir = state.currentDir
		if dir.Magnitude > 0.001 then
			part.CFrame = CFrame.lookAt(newPos, newPos + dir)
		else
			part.CFrame = CFrame.new(newPos)
		end

		-- Drive visual fin/tail parts to follow body rotation (all Anchored, children of body)
		local bX = part.Size.X
		local bZ = part.Size.Z
		if state.tail then
			state.tail.CFrame = part.CFrame * CFrame.new(0, 0, bZ * 0.95)
		end
		if state.finL then
			state.finL.CFrame = part.CFrame * CFrame.new(-bX * 0.62, 0, -bZ * 0.06)
		end
		if state.finR then
			state.finR.CFrame = part.CFrame * CFrame.new(bX * 0.62, 0, -bZ * 0.06)
		end
		end
	end)
end

return AIService
