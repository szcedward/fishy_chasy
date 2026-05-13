--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local LevelGenerator = {}

local MAX_CHAIN_STEPS = 64

local function buildChain(sMin: number, target: number, maxAi: number): { number }
	local chain: { number } = {}
	local playerSize = sMin
	for _ = 1, MAX_CHAIN_STEPS do
		if playerSize >= target then
			break
		end
		local nextS = math.min(playerSize, maxAi)
		if nextS < 1 then
			break
		end
		table.insert(chain, nextS)
		playerSize += nextS
	end
	return chain
end

local function sampleLogUniform(maxAi: number): number
	local r = math.random()
	local logMax = math.log(maxAi + 1)
	return math.max(1, math.floor(math.exp(r * logMax)))
end

function LevelGenerator.generate(sMin: number, target: number): { number }
	local safeTarget = math.max(2, target)
	local safeSMin = math.max(1, sMin)
	local maxAi = math.max(1, math.floor(safeTarget * Config.AI.MaxAISizeRatio))

	local chain = buildChain(safeSMin, safeTarget, maxAi)

	local sum = 0
	for _, v in chain do
		sum += v
	end
	local avg = if #chain > 0 then sum / #chain else math.max(1, maxAi / 2)
	local quota = math.max(
		Config.AI.MinQuota,
		math.ceil((safeTarget / math.max(1, avg)) * Config.AI.QuotaMultiplier)
	)

	local list: { number } = {}
	for _, v in chain do
		table.insert(list, v)
	end
	while #list < quota do
		table.insert(list, sampleLogUniform(maxAi))
	end

	return list
end

return LevelGenerator
