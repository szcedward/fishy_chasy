--!strict
-- OBB overlap helpers for fish bodies in the XZ plane (shared by Predation, ShieldService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Tier = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tier"))

local FishCollision = {}

-- Visual half-extents at Tier scale = 1 (derived from Fish.luau body constants)
FishCollision.AI_HALF_L = Config.AI.PartSize.Z * 1.8 / 2
FishCollision.AI_HALF_W = Config.AI.PartSize.X / 2
FishCollision.PLR_HALF_L = 4.2 * 1.3 / 2
FishCollision.PLR_HALF_W = 3.0 / 2

local function perp2D(fwd: Vector3): Vector3
	return Vector3.new(-fwd.Z, 0, fwd.X)
end

function FishCollision.halfExtentsForPlayer(size: number): (number, number)
	local scale = Tier.scaleOf(size)
	return FishCollision.PLR_HALF_L * scale, FishCollision.PLR_HALF_W * scale
end

function FishCollision.halfExtentsForAI(size: number): (number, number)
	local scale = Tier.scaleOf(size)
	return FishCollision.AI_HALF_L * scale, FishCollision.AI_HALF_W * scale
end

-- 2-D SAT for two oriented rectangles in the XZ plane.
function FishCollision.fishTouching(
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

	local function separated(axis: Vector3): boolean
		local proj = math.abs(d:Dot(axis))
		local e1 = hl1 * math.abs(fwd1:Dot(axis)) + hw1 * math.abs(rw1:Dot(axis))
		local e2 = hl2 * math.abs(fwd2:Dot(axis)) + hw2 * math.abs(rw2:Dot(axis))
		return proj > e1 + e2
	end

	return not (separated(fwd1) or separated(rw1) or separated(fwd2) or separated(rw2))
end

return FishCollision
