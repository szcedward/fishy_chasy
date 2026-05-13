--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hud = {}

local ACTIVE_UNTIL = Config.Boost.ActiveUntilAttr
local READY_AT = Config.Boost.ReadyAtAttr
local NPRU = Config.Predation.NoPredationRewardUntilAttr

local localPlayer = Players.LocalPlayer

local function makePanel(parent: Instance, name: string, height: number, yPx: number): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0, 200, 0, height)
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -20, 1, yPx)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = parent

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
	label.Text = ""
	label.Parent = frame

	return frame, label
end

function Hud.mount()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishHud"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local boostFrame, boostLabel = makePanel(gui, "BoostStatus", 50, -120)
	boostLabel.Text = "BOOST READY (F)"

	local debuffFrame, debuffLabel = makePanel(gui, "DebuffStatus", 30, -180)
	debuffFrame.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
	debuffLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
	debuffFrame.Visible = false

	RunService.Heartbeat:Connect(function()
		local t = workspace:GetServerTimeNow()

		local activeUntil = localPlayer:GetAttribute(ACTIVE_UNTIL)
		local readyAt = localPlayer:GetAttribute(READY_AT)
		if typeof(activeUntil) == "number" and activeUntil > t then
			boostLabel.Text = string.format("BOOST %0.1fs", activeUntil - t)
			boostLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
		elseif typeof(readyAt) == "number" and readyAt > t then
			boostLabel.Text = string.format("CD %0.1fs", readyAt - t)
			boostLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		else
			boostLabel.Text = "BOOST READY (F)"
			boostLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end

		local npru = localPlayer:GetAttribute(NPRU)
		if typeof(npru) == "number" and npru > t then
			debuffFrame.Visible = true
			debuffLabel.Text = string.format("NO REWARD %0.1fs", npru - t)
		else
			debuffFrame.Visible = false
		end
	end)
end

return Hud
