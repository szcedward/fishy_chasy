--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Tier = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tier"))
local Fish = require(script.Parent:WaitForChild("Fish"))
local LevelService = require(script.Parent:WaitForChild("LevelService"))

local Predation = {}

local PHASE_ATTR = Config.Level.PhaseAttr
local PLAYING = Config.Phase.Playing

local NPRU = Config.Predation.NoPredationRewardUntilAttr
local SPAWN_PROTECTED_UNTIL = Config.Predation.SpawnProtectedUntilAttr
local SIZE_ATTRIBUTE = Fish.SIZE_ATTRIBUTE

local function now(): number
	return workspace:GetServerTimeNow()
end

function Predation.isPlayerInDebuff(player: Player): boolean
	local untilT = player:GetAttribute(NPRU)
	return typeof(untilT) == "number" and untilT > now()
end

local pendingDebuff: { [Player]: boolean } = {}

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- Spawn protection: AI cannot kill this player for the first N seconds
	player:SetAttribute(SPAWN_PROTECTED_UNTIL, now() + Config.Predation.SpawnProtectionSeconds)

	humanoid.Died:Connect(function()
		pendingDebuff[player] = true
	end)
	if pendingDebuff[player] then
		player:SetAttribute(NPRU, now() + Config.PredationDebuffSeconds)
		pendingDebuff[player] = nil
	end
end

local function setupPlayerDebuff(player: Player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		setupCharacter(player, player.Character)
	end
end

local function startPlayerLifecycleHandlers()
	for _, player in Players:GetPlayers() do
		setupPlayerDebuff(player)
	end
	Players.PlayerAdded:Connect(setupPlayerDebuff)
	Players.PlayerRemoving:Connect(function(player)
		pendingDebuff[player] = nil
	end)
end

local function resolveAIBite(player: Player, humanoid: Humanoid, ai: BasePart)
	local playerSize = player:GetAttribute(SIZE_ATTRIBUTE)
	local aiSize = ai:GetAttribute(SIZE_ATTRIBUTE)
	if typeof(playerSize) ~= "number" or typeof(aiSize) ~= "number" then
		return
	end

	if playerSize >= aiSize then
		LevelService.applyEatReward(player, aiSize)
		Fish.relocateAI(ai)
	else
		local protectedUntil = player:GetAttribute(SPAWN_PROTECTED_UNTIL)
		if typeof(protectedUntil) == "number" and protectedUntil > now() then
			return
		end
		humanoid.Health = 0
	end
end

local function resolvePlayerBite(a: Player, aHum: Humanoid, b: Player, bHum: Humanoid)
	local aSize = a:GetAttribute(SIZE_ATTRIBUTE)
	local bSize = b:GetAttribute(SIZE_ATTRIBUTE)
	if typeof(aSize) ~= "number" or typeof(bSize) ~= "number" then
		return
	end
	if aSize == bSize then
		return
	end

	local eater: Player, victim: Player, victimHum: Humanoid, victimSize: number
	if aSize > bSize then
		eater = a
		victim, victimHum, victimSize = b, bHum, bSize
	else
		eater = b
		victim, victimHum, victimSize = a, aHum, aSize
	end

	if not Predation.isPlayerInDebuff(victim) then
		LevelService.applyEatReward(eater, victimSize)
	end
	victimHum.Health = 0
end

-- Visual half-extents at Tier scale = 1 (derived from Fish.luau body constants):
--   AI  body: PartSize(4,2,4) × MeshScale(1,0.65,1.8) → halfLen=3.6  halfWid=2.0
--   PLR body: Base(3,1.8,4.2)× MeshScale(1,0.82,1.3)  → halfLen=2.73 halfWid=1.5
local AI_HALF_L = Config.AI.PartSize.Z * 1.8 / 2 -- 3.6
local AI_HALF_W = Config.AI.PartSize.X / 2 -- 2.0
local PLR_HALF_L = 4.2 * 1.3 / 2 -- 2.73
local PLR_HALF_W = 3.0 / 2 -- 1.5

-- In-XZ-plane unit vector perpendicular to fwd.
local function perp2D(fwd: Vector3): Vector3
	return Vector3.new(-fwd.Z, 0, fwd.X)
end

-- 2-D Separating Axis Theorem for two oriented rectangles in the XZ plane.
-- hl = half-length (along fwd),  hw = half-width (perpendicular to fwd).
-- Tests exactly 4 face-normal axes — O(1), no sqrt, exact result.
local function fishTouching(
	c1: Vector3,
	fwd1: Vector3,
	hl1: number,
	hw1: number,
	c2: Vector3,
	fwd2: Vector3,
	hl2: number,
	hw2: number
): boolean
	local rw1 = perp2D(fwd1)
	local rw2 = perp2D(fwd2)
	local d = c2 - c1

	-- Project both OBBs onto `axis`; separated → no contact on this axis
	local function separated(axis: Vector3): boolean
		local proj = math.abs(d:Dot(axis))
		local e1 = hl1 * math.abs(fwd1:Dot(axis)) + hw1 * math.abs(rw1:Dot(axis))
		local e2 = hl2 * math.abs(fwd2:Dot(axis)) + hw2 * math.abs(rw2:Dot(axis))
		return proj > e1 + e2
	end

	-- Overlapping iff NOT separated on any of the four face-normal axes
	return not (separated(fwd1) or separated(rw1) or separated(fwd2) or separated(rw2))
end

local function startPredationTick(aiFishes: { BasePart })
	local tickInterval = 1 / Config.Predation.TickHz
	local accumulator = 0

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < tickInterval then
			return
		end
		accumulator = 0

		if workspace:GetAttribute(PHASE_ATTR) ~= PLAYING then
			return
		end

		local players = Players:GetPlayers()

		for _, player in players do
			local character = player.Character
			if not character then
				continue
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				continue
			end
			local playerSize = player:GetAttribute(SIZE_ATTRIBUTE)
			if typeof(playerSize) ~= "number" then
				continue
			end
			local ps = Tier.scaleOf(playerSize)
			local playerFwd = hrp.CFrame.LookVector

			for _, ai in aiFishes do
				local aiSize = ai:GetAttribute(SIZE_ATTRIBUTE)
				if typeof(aiSize) ~= "number" then
					continue
				end
				local as = Tier.scaleOf(aiSize)
				if fishTouching(
					hrp.Position,
					playerFwd,
					PLR_HALF_L * ps,
					PLR_HALF_W * ps,
					ai.Position,
					ai.CFrame.LookVector,
					AI_HALF_L * as,
					AI_HALF_W * as
				) then
					resolveAIBite(player, humanoid, ai)
					if humanoid.Health <= 0 then
						break
					end
				end
			end
		end

		for i = 1, #players - 1 do
			for j = i + 1, #players do
				local a, b = players[i], players[j]
				local aChar, bChar = a.Character, b.Character
				if not aChar or not bChar then
					continue
				end
				local aHum = aChar:FindFirstChildOfClass("Humanoid")
				local bHum = bChar:FindFirstChildOfClass("Humanoid")
				if not aHum or aHum.Health <= 0 or not bHum or bHum.Health <= 0 then
					continue
				end
				local aHrp = aChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				local bHrp = bChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not aHrp or not bHrp then
					continue
				end
				local aSize = a:GetAttribute(SIZE_ATTRIBUTE)
				local bSize = b:GetAttribute(SIZE_ATTRIBUTE)
				if typeof(aSize) ~= "number" or typeof(bSize) ~= "number" then
					continue
				end

				local as2, bs2 = Tier.scaleOf(aSize), Tier.scaleOf(bSize)
				if fishTouching(
					aHrp.Position,
					aHrp.CFrame.LookVector,
					PLR_HALF_L * as2,
					PLR_HALF_W * as2,
					bHrp.Position,
					bHrp.CFrame.LookVector,
					PLR_HALF_L * bs2,
					PLR_HALF_W * bs2
				) then
					resolvePlayerBite(a, aHum, b, bHum)
				end
			end
		end
	end)
end

function Predation.start(aiFishes: { BasePart })
	startPredationTick(aiFishes)
	startPlayerLifecycleHandlers()
end

return Predation
