--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fish = require(script.Parent:WaitForChild("Fish"))
local Boost = require(script.Parent:WaitForChild("Boost"))
local Predation = require(script.Parent:WaitForChild("Predation"))

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

Boost.start()
Predation.start(aiFishes)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

print(`[Server] Slice D ready. Players start at size {Config.Player.InitialSize}.`)
