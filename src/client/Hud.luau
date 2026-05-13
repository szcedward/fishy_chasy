--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hud = {}

local ACTIVE_UNTIL = Config.Boost.ActiveUntilAttr
local READY_AT = Config.Boost.ReadyAtAttr
local NPRU = Config.Predation.NoPredationRewardUntilAttr

local PHASE_ATTR = Config.Level.PhaseAttr
local LEVEL_ATTR = Config.Level.LevelNumberAttr
local TARGET_ATTR = Config.Level.TargetAttr
local ENDS_AT_ATTR = Config.Level.EndsAtAttr
local LANE_ATTR = Config.Level.LaneAttr
local FROZEN_ATTR = Config.Level.FrozenAttr
local BONUS_ATTR = Config.Level.BonusAttr
local SIZE_ATTR = "Size"

local PHASE = Config.Phase
local LANES = Config.Lane

local localPlayer = Players.LocalPlayer

local function rounded(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeBottomRightPanel(parent: Instance, name: string, height: number, yPx: number): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0, 200, 0, height)
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -20, 1, yPx)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = parent
	rounded(frame, 8)

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
	gui.IgnoreGuiInset = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local topPanel = Instance.new("Frame")
	topPanel.Name = "LevelInfo"
	topPanel.Size = UDim2.new(0, 540, 0, 50)
	topPanel.AnchorPoint = Vector2.new(0.5, 0)
	topPanel.Position = UDim2.new(0.5, 0, 0, 12)
	topPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	topPanel.BackgroundTransparency = 0.4
	topPanel.BorderSizePixel = 0
	topPanel.Parent = gui
	rounded(topPanel, 10)

	local topLabel = Instance.new("TextLabel")
	topLabel.Name = "Value"
	topLabel.Size = UDim2.fromScale(1, 1)
	topLabel.BackgroundTransparency = 1
	topLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	topLabel.Font = Enum.Font.GothamBold
	topLabel.TextScaled = true
	topLabel.Text = "Waiting..."
	topLabel.Parent = topPanel

	local lanePanel = Instance.new("Frame")
	lanePanel.Name = "LaneBadge"
	lanePanel.Size = UDim2.new(0, 160, 0, 32)
	lanePanel.AnchorPoint = Vector2.new(1, 0)
	lanePanel.Position = UDim2.new(1, -20, 0, 12)
	lanePanel.BackgroundColor3 = Color3.fromRGB(40, 100, 60)
	lanePanel.BackgroundTransparency = 0.2
	lanePanel.BorderSizePixel = 0
	lanePanel.Parent = gui
	rounded(lanePanel, 8)

	local laneLabel = Instance.new("TextLabel")
	laneLabel.Size = UDim2.fromScale(1, 1)
	laneLabel.BackgroundTransparency = 1
	laneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	laneLabel.Font = Enum.Font.GothamBold
	laneLabel.TextScaled = true
	laneLabel.Text = ""
	laneLabel.Parent = lanePanel

	local overlay = Instance.new("Frame")
	overlay.Name = "PhaseBanner"
	overlay.Size = UDim2.new(0, 480, 0, 56)
	overlay.AnchorPoint = Vector2.new(0.5, 0)
	overlay.Position = UDim2.new(0.5, 0, 0, 72)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = gui
	rounded(overlay, 10)

	local overlayLabel = Instance.new("TextLabel")
	overlayLabel.Size = UDim2.fromScale(1, 1)
	overlayLabel.BackgroundTransparency = 1
	overlayLabel.Font = Enum.Font.GothamBold
	overlayLabel.TextScaled = true
	overlayLabel.Text = ""
	overlayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	overlayLabel.Parent = overlay

	local boostFrame, boostLabel = makeBottomRightPanel(gui, "BoostStatus", 50, -120)
	boostLabel.Text = "BOOST READY (F)"

	local debuffFrame, debuffLabel = makeBottomRightPanel(gui, "DebuffStatus", 30, -180)
	debuffFrame.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
	debuffLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
	debuffFrame.Visible = false

	local function laneVisual(lane: string?): (string, Color3)
		if lane == LANES.CatchUp then
			return "CATCH-UP", Color3.fromRGB(180, 120, 40)
		elseif lane == LANES.Rostered then
			return "ROSTERED", Color3.fromRGB(40, 110, 60)
		else
			return "WAITING", Color3.fromRGB(60, 60, 60)
		end
	end

	RunService.Heartbeat:Connect(function()
		local t = workspace:GetServerTimeNow()

		local phase = workspace:GetAttribute(PHASE_ATTR) or PHASE.Waiting
		local level = workspace:GetAttribute(LEVEL_ATTR) or 0
		local target = workspace:GetAttribute(TARGET_ATTR) or 0
		local endsAt = workspace:GetAttribute(ENDS_AT_ATTR) or 0
		local size = localPlayer:GetAttribute(SIZE_ATTR) or 0
		local bonus = localPlayer:GetAttribute(BONUS_ATTR) or 0
		local frozen = localPlayer:GetAttribute(FROZEN_ATTR) == true
		local lane = localPlayer:GetAttribute(LANE_ATTR)

		if phase == PHASE.Playing then
			local remaining = math.max(0, endsAt - t)
			local sizeText = if frozen then string.format("❄ %d", size) else tostring(size)
			local bonusText = if bonus > 0 then string.format(" | BONUS %d", bonus) else ""
			topLabel.Text = string.format("L%d  TARGET %d  %0.0fs  |  YOU %s%s", level, target, remaining, sizeText, bonusText)
			overlay.Visible = false
		elseif phase == PHASE.Cleared then
			topLabel.Text = string.format("L%d  TARGET %d  |  YOU %d (BONUS %d)", level, target, size, bonus)
			overlay.Visible = true
			overlayLabel.Text = string.format("LEVEL %d CLEARED!", level)
			overlayLabel.TextColor3 = Color3.fromRGB(160, 255, 180)
		elseif phase == PHASE.Failed then
			topLabel.Text = "SESSION FAILED — RESETTING"
			overlay.Visible = true
			overlayLabel.Text = string.format("SESSION FAILED (L%d)", level)
			overlayLabel.TextColor3 = Color3.fromRGB(255, 160, 160)
		else
			topLabel.Text = "Waiting for players..."
			overlay.Visible = false
		end

		local laneText, laneColor = laneVisual(lane)
		laneLabel.Text = laneText
		lanePanel.BackgroundColor3 = laneColor

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
