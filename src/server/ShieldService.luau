--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FishCollision = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishCollision"))
local Fish = require(script.Parent:WaitForChild("Fish"))

local ShieldService = {}

local LAYERS_ATTR = Config.Shield.LayersAttr
local BLOCKING_ATTR = Config.Shield.BlockedEncounterAttr
local MAX_LAYERS = Config.Shield.MaxLayers
local SIZE_ATTR = Fish.SIZE_ATTRIBUTE

-- Server-only: player was in a shield-blocked encounter last tick
local blockingEncounter: { [Player]: boolean } = {}

local function getLayers(player: Player): number
	local v = player:GetAttribute(LAYERS_ATTR)
	if typeof(v) == "number" then
		return math.clamp(math.floor(v), 0, MAX_LAYERS)
	end
	return 0
end

local function setLayers(player: Player, layers: number)
	player:SetAttribute(LAYERS_ATTR, math.clamp(layers, 0, MAX_LAYERS))
end

local function setBlocking(player: Player, blocking: boolean)
	player:SetAttribute(BLOCKING_ATTR, blocking)
end

function ShieldService.getLayers(player: Player): number
	return getLayers(player)
end

function ShieldService.addLayer(player: Player): boolean
	local current = getLayers(player)
	if current >= MAX_LAYERS then
		return false
	end
	setLayers(player, current + 1)
	return true
end

function ShieldService.clearLayers(player: Player)
	setLayers(player, 0)
	blockingEncounter[player] = nil
	setBlocking(player, false)
end

-- True when a strictly larger fish is overlapping this player (same OBB as predation).
local function isInThreatContact(player: Player, hrp: BasePart, playerSize: number, aiFishes: { BasePart }): boolean
	local hl, hw = FishCollision.halfExtentsForPlayer(playerSize)
	local pos = hrp.Position
	local fwd = hrp.CFrame.LookVector

	for _, ai in aiFishes do
		local aiSize = ai:GetAttribute(SIZE_ATTR)
		if typeof(aiSize) == "number" and aiSize > playerSize then
			local ahl, ahw = FishCollision.halfExtentsForAI(aiSize)
			if FishCollision.fishTouching(pos, fwd, hl, hw, ai.Position, ai.CFrame.LookVector, ahl, ahw) then
				return true
			end
		end
	end

	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local otherSize = other:GetAttribute(SIZE_ATTR)
		if typeof(otherSize) ~= "number" or otherSize <= playerSize then
			continue
		end
		local char = other.Character
		if not char then
			continue
		end
		local otherHrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not otherHrp then
			continue
		end
		local ohl, ohw = FishCollision.halfExtentsForPlayer(otherSize)
		if FishCollision.fishTouching(pos, fwd, hl, hw, otherHrp.Position, otherHrp.CFrame.LookVector, ohl, ohw) then
			return true
		end
	end

	return false
end

-- During predation: victim survives if they have shield layers while overlapping a larger threat.
function ShieldService.canBlockDeath(player: Player): boolean
	return getLayers(player) > 0
end

-- Call once per predation tick after bite resolution.
function ShieldService.tickEncounters(players: { Player }, aiFishes: { BasePart })
	for _, player in players do
		local character = player.Character
		if not character then
			blockingEncounter[player] = nil
			setBlocking(player, false)
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			blockingEncounter[player] = nil
			setBlocking(player, false)
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local playerSize = player:GetAttribute(SIZE_ATTR)
		if not hrp or typeof(playerSize) ~= "number" then
			continue
		end

		local layers = getLayers(player)
		local inContact = isInThreatContact(player, hrp, playerSize, aiFishes)
		local wasBlocking = blockingEncounter[player] == true

		if inContact and layers > 0 then
			blockingEncounter[player] = true
			setBlocking(player, true)
		elseif wasBlocking and not inContact then
			-- Escaped the encounter: consume exactly one shield layer
			setLayers(player, layers - 1)
			blockingEncounter[player] = nil
			setBlocking(player, false)
		elseif not inContact then
			blockingEncounter[player] = nil
			setBlocking(player, false)
		end
	end
end

function ShieldService.start()
	local function onPlayerAdded(player: Player)
		if player:GetAttribute(LAYERS_ATTR) == nil then
			setLayers(player, 0)
		end
		setBlocking(player, false)

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				ShieldService.clearLayers(player)
			end)
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		blockingEncounter[player] = nil
	end)
end

return ShieldService
