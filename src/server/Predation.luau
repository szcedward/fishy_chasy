--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FishCollision = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishCollision"))
local Tier = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tier"))
local Fish = require(script.Parent:WaitForChild("Fish"))
local LevelService = require(script.Parent:WaitForChild("LevelService"))
local ShieldService = require(script.Parent:WaitForChild("ShieldService"))

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
		if ShieldService.canBlockDeath(player) then
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

	if ShieldService.canBlockDeath(victim) then
		return
	end

	if not Predation.isPlayerInDebuff(victim) then
		LevelService.applyEatReward(eater, victimSize)
	end
	victimHum.Health = 0
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
			local hl, hw = FishCollision.halfExtentsForPlayer(playerSize)
			local playerFwd = hrp.CFrame.LookVector

			for _, ai in aiFishes do
				local aiSize = ai:GetAttribute(SIZE_ATTRIBUTE)
				if typeof(aiSize) ~= "number" then
					continue
				end
				local ahl, ahw = FishCollision.halfExtentsForAI(aiSize)
				if FishCollision.fishTouching(
					hrp.Position,
					playerFwd,
					hl,
					hw,
					ai.Position,
					ai.CFrame.LookVector,
					ahl,
					ahw
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

				local ahl, ahw = FishCollision.halfExtentsForPlayer(aSize)
				local bhl, bhw = FishCollision.halfExtentsForPlayer(bSize)
				if FishCollision.fishTouching(
					aHrp.Position,
					aHrp.CFrame.LookVector,
					ahl,
					ahw,
					bHrp.Position,
					bHrp.CFrame.LookVector,
					bhl,
					bhw
				) then
					resolvePlayerBite(a, aHum, b, bHum)
				end
			end
		end

		ShieldService.tickEncounters(players, aiFishes)
	end)
end

function Predation.start(aiFishes: { BasePart })
	startPredationTick(aiFishes)
	startPlayerLifecycleHandlers()
end

return Predation
