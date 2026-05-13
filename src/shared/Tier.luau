--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Tier = {}

function Tier.tierOf(size: number): number
	local t = 1
	for i, bound in Config.Tiers.Bounds do
		if size >= bound then
			t = i
		else
			break
		end
	end
	return t
end

function Tier.scaleOf(size: number): number
	local t = Tier.tierOf(size)
	return 1 + (t - 1) * Config.Tiers.ScalePerStep
end

function Tier.colorOf(size: number): Color3
	local t = Tier.tierOf(size)
	return Config.Tiers.Colors[t] or Config.Tiers.Colors[#Config.Tiers.Colors]
end

function Tier.nameOf(size: number): string
	local t = Tier.tierOf(size)
	return Config.Tiers.Names[t] or "?"
end

return Tier
