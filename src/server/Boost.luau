--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Boost = {}

local ACTIVE_UNTIL = Config.Boost.ActiveUntilAttr
local READY_AT = Config.Boost.ReadyAtAttr

local function now(): number
	return workspace:GetServerTimeNow()
end

local function applyWalkSpeedTo(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local activeUntil = player:GetAttribute(ACTIVE_UNTIL)
	local desired = Config.BaseWalkSpeed
	if typeof(activeUntil) == "number" and activeUntil > now() then
		desired = Config.BaseWalkSpeed * Config.Boost.Multiplier
	end

	if humanoid.WalkSpeed ~= desired then
		humanoid.WalkSpeed = desired
	end
end

local function tryStartBoost(player: Player)
	local t = now()
	local readyAt = player:GetAttribute(READY_AT)
	if typeof(readyAt) == "number" and readyAt > t then
		return
	end

	player:SetAttribute(ACTIVE_UNTIL, t + Config.Boost.Duration)
	player:SetAttribute(READY_AT, t + Config.Boost.Duration + Config.Boost.Cooldown)

	local character = player.Character
	if character then
		applyWalkSpeedTo(player, character)
	end
end

function Boost.start()
	Remotes.RequestBoost.OnServerEvent:Connect(function(player)
		tryStartBoost(player)
	end)

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				applyWalkSpeedTo(player, character)
			end
		end
	end)
end

return Boost
