--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fish = require(script.Parent:WaitForChild("Fish"))

local Predation = {}

local NPRU = Config.Predation.NoPredationRewardUntilAttr
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

local function resolveBite(player: Player, humanoid: Humanoid, ai: BasePart)
	local playerSize = player:GetAttribute(SIZE_ATTRIBUTE)
	local aiSize = ai:GetAttribute(SIZE_ATTRIBUTE)
	if typeof(playerSize) ~= "number" or typeof(aiSize) ~= "number" then
		return
	end

	if playerSize >= aiSize then
		player:SetAttribute(SIZE_ATTRIBUTE, playerSize + aiSize)
		Fish.relocateAI(ai)
	else
		humanoid.Health = 0
	end
end

local function startPredationTick(aiFishes: { BasePart })
	local tickInterval = 1 / Config.Predation.TickHz
	local accumulator = 0
	local contactRadiusSq = Config.Predation.ContactRadius * Config.Predation.ContactRadius

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < tickInterval then
			return
		end
		accumulator = 0

		for _, player in Players:GetPlayers() do
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

			for _, ai in aiFishes do
				local delta = hrp.Position - ai.Position
				if delta:Dot(delta) < contactRadiusSq then
					resolveBite(player, humanoid, ai)
					if humanoid.Health <= 0 then
						break
					end
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
