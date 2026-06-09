--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fish = require(script.Parent:WaitForChild("Fish"))
local Boost = require(script.Parent:WaitForChild("Boost"))
local LevelService = require(script.Parent:WaitForChild("LevelService"))
local Predation = require(script.Parent:WaitForChild("Predation"))
local AIService = require(script.Parent:WaitForChild("AIService"))
local ShieldService = require(script.Parent:WaitForChild("ShieldService"))
local FoodService = require(script.Parent:WaitForChild("FoodService"))

local function applyBaseSpeed(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.BaseWalkSpeed
end

local function onCharacterAdded(player: Player, character: Model)
	applyBaseSpeed(character)
	Fish.attachPlayerVisuals(player, character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local aiFishes = LevelService.start()
ShieldService.start()
FoodService.start()
Boost.start()
Predation.start(aiFishes)
AIService.start(aiFishes)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

print("[Server] Ready. Food + shield systems active.")
