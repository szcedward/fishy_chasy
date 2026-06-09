--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ShieldService = require(script.Parent:WaitForChild("ShieldService"))

local FoodService = {}

local PHASE_ATTR = Config.Level.PhaseAttr
local PLAYING = Config.Phase.Playing
local FOOD = Config.Food

local activeFood: BasePart? = nil
local respawnAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function pickSpawnPosition(): Vector3
	local center = FOOD.SpawnAreaCenter
	local outer = FOOD.SpawnAreaRadius
	local inner = FOOD.MinDistanceFromOrigin
	local angle = math.random() * math.pi * 2
	local r = inner + math.random() * (outer - inner)
	local y = center.Y + FOOD.PartSize.Y / 2
	return Vector3.new(center.X + math.cos(angle) * r, y, center.Z + math.sin(angle) * r)
end

local function destroyFood()
	if activeFood then
		activeFood:Destroy()
		activeFood = nil
	end
end

local function spawnFood()
	if activeFood then
		return
	end

	local part = Instance.new("Part")
	part.Name = "ShieldFood"
	part.Size = FOOD.PartSize
	part.Position = pickSpawnPosition()
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(120, 255, 180)
	part.Shape = Enum.PartType.Ball
	part.CastShadow = false
	part.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(140, 255, 200)
	light.Brightness = 1.2
	light.Range = 12
	light.Parent = part

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.15, 1.15, 1.15)
	mesh.Parent = part

	activeFood = part
end

local function tryPickup(player: Player, hrp: BasePart): boolean
	local food = activeFood
	if not food then
		return false
	end

	local delta = hrp.Position - food.Position
	if delta:Dot(delta) > FOOD.PickupRadius * FOOD.PickupRadius then
		return false
	end

	if ShieldService.addLayer(player) then
		destroyFood()
		respawnAt = now() + FOOD.RespawnSeconds
		return true
	end

	-- Already at max layers — food stays on the ground
	return false
end

function FoodService.start()
	RunService.Heartbeat:Connect(function()
		if workspace:GetAttribute(PHASE_ATTR) ~= PLAYING then
			return
		end

		if not activeFood and now() >= respawnAt then
			spawnFood()
		end

		local food = activeFood
		if not food then
			return
		end

		-- Gentle spin so food is easy to spot
		food.CFrame = CFrame.new(food.Position) * CFrame.Angles(0, now() * 1.5, 0)

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
			if hrp and tryPickup(player, hrp) then
				break
			end
		end
	end)
end

function FoodService.resetForSession()
	destroyFood()
	respawnAt = now() + FOOD.RespawnSeconds
end

return FoodService
