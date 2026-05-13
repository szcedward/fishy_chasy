--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hud = {}

local ACTIVE_UNTIL = Config.Boost.ActiveUntilAttr
local READY_AT = Config.Boost.ReadyAtAttr

local localPlayer = Players.LocalPlayer

function Hud.mount()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishHud"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "BoostStatus"
	frame.Size = UDim2.new(0, 200, 0, 50)
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -20, 1, -120)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "BOOST READY (F)"
	label.Parent = frame

	RunService.Heartbeat:Connect(function()
		local t = workspace:GetServerTimeNow()
		local activeUntil = localPlayer:GetAttribute(ACTIVE_UNTIL)
		local readyAt = localPlayer:GetAttribute(READY_AT)

		if typeof(activeUntil) == "number" and activeUntil > t then
			label.Text = string.format("BOOST %0.1fs", activeUntil - t)
			label.TextColor3 = Color3.fromRGB(120, 255, 160)
		elseif typeof(readyAt) == "number" and readyAt > t then
			label.Text = string.format("CD %0.1fs", readyAt - t)
			label.TextColor3 = Color3.fromRGB(200, 200, 200)
		else
			label.Text = "BOOST READY (F)"
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)
end

return Hud
