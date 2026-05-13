--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fish = require(script.Parent:WaitForChild("Fish"))

local SIZE_ATTRIBUTE = Fish.SIZE_ATTRIBUTE

local aiFolder = Instance.new("Folder")
aiFolder.Name = "AIFish"
aiFolder.Parent = workspace

local aiFishes: { BasePart } = {}
for _, size in Config.AI.InitialSizes do
	local part = Fish.createAI(size)
	part.Parent = aiFolder
	table.insert(aiFishes, part)
end
print(`[Server] Spawned {#aiFishes} AI fish.`)

local function applyBaseSpeed(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.BaseWalkSpeed
end

local function onCharacterAdded(player: Player, character: Model)
	applyBaseSpeed(character)
	Fish.attachPlayerVisuals(player, character)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(SIZE_ATTRIBUTE, Config.Player.InitialSize)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

local tickInterval = 1 / Config.Predation.TickHz
local accumulator = 0
local contactRadiusSq = Config.Predation.ContactRadius * Config.Predation.ContactRadius

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

print(`[Server] Slice B ready. Players start at size {Config.Player.InitialSize}.`)
