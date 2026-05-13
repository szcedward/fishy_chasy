--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fish = require(script.Parent:WaitForChild("Fish"))
local LevelGenerator = require(script.Parent:WaitForChild("LevelGenerator"))

local LevelService = {}

local aiFolder: Folder? = nil
local aiFishes: { BasePart } = {}

local SIZE = Fish.SIZE_ATTRIBUTE
local BONUS = Config.Level.BonusAttr
local FROZEN = Config.Level.FrozenAttr
local LANE = Config.Level.LaneAttr

local PHASE_ATTR = Config.Level.PhaseAttr
local LEVEL_ATTR = Config.Level.LevelNumberAttr
local TARGET_ATTR = Config.Level.TargetAttr
local ENDS_AT_ATTR = Config.Level.EndsAtAttr

local PHASE = Config.Phase
local LANES = Config.Lane

local rosterSet: { [Player]: boolean } = {}
local frozenSet: { [Player]: boolean } = {}
local catchUpSet: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getPhase(): string
	return workspace:GetAttribute(PHASE_ATTR) or PHASE.Waiting
end

local function setPhase(phase: string)
	workspace:SetAttribute(PHASE_ATTR, phase)
end

local function countSet(t: { [Player]: boolean }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function resetPlayerLevelState(player: Player)
	player:SetAttribute(BONUS, 0)
	player:SetAttribute(FROZEN, false)
end

local function resetPlayerSession(player: Player)
	player:SetAttribute(SIZE, Config.Player.InitialSize)
	resetPlayerLevelState(player)
end

local function computeSMin(): number
	local sMin: number? = nil
	for player in rosterSet do
		local s = player:GetAttribute(SIZE)
		if typeof(s) == "number" and (sMin == nil or s < sMin) then
			sMin = s
		end
	end
	return sMin or Config.Player.InitialSize
end

local function computeTarget(sMin: number): number
	return math.floor(sMin * Config.Level.TargetMultiplier)
end

local function computeTimer(level: number): number
	return Config.Level.TimerBase + level * Config.Level.TimerStep
end

local startLevel: (level: number) -> ()
local clearLevel: () -> ()
local failLevel: () -> ()

local function checkWinCondition()
	local rostered = countSet(rosterSet)
	if rostered == 0 then
		return
	end
	if countSet(frozenSet) < rostered then
		return
	end
	clearLevel()
end

local function rebuildAIForLevel(sMin: number, target: number)
	for _, part in aiFishes do
		part:Destroy()
	end
	table.clear(aiFishes)

	local folder = aiFolder
	if not folder then
		return
	end

	local sizes = LevelGenerator.generate(sMin, target)
	for _, size in sizes do
		local part = Fish.createAI(size)
		part.Parent = folder
		table.insert(aiFishes, part)
	end
end

function startLevel(level: number)
	table.clear(rosterSet)
	table.clear(frozenSet)
	table.clear(catchUpSet)

	for _, p in Players:GetPlayers() do
		rosterSet[p] = true
		p:SetAttribute(LANE, LANES.Rostered)
		resetPlayerLevelState(p)
	end

	local sMin = computeSMin()
	local target = computeTarget(sMin)
	local timer = computeTimer(level)
	local endsAt = now() + timer

	rebuildAIForLevel(sMin, target)

	workspace:SetAttribute(LEVEL_ATTR, level)
	workspace:SetAttribute(TARGET_ATTR, target)
	workspace:SetAttribute(ENDS_AT_ATTR, endsAt)
	setPhase(PHASE.Playing)

	print(
		`[LevelService] Start L{level} | S_min={sMin} target={target} timer={timer}s rostered={countSet(rosterSet)} ai={#aiFishes}`
	)
end

function clearLevel()
	local level = workspace:GetAttribute(LEVEL_ATTR) or 0
	setPhase(PHASE.Cleared)
	print(`[LevelService] Cleared L{level}.`)

	task.delay(Config.Level.ClearedDuration, function()
		if getPhase() ~= PHASE.Cleared then
			return
		end
		if #Players:GetPlayers() == 0 then
			setPhase(PHASE.Waiting)
			return
		end
		startLevel(level + 1)
	end)
end

function failLevel()
	local level = workspace:GetAttribute(LEVEL_ATTR) or 0
	setPhase(PHASE.Failed)
	print(`[LevelService] FAILED L{level}. Resetting session.`)

	task.delay(Config.Level.FailedDuration, function()
		if getPhase() ~= PHASE.Failed then
			return
		end
		for _, p in Players:GetPlayers() do
			resetPlayerSession(p)
		end
		if #Players:GetPlayers() == 0 then
			setPhase(PHASE.Waiting)
			return
		end
		startLevel(1)
	end)
end

function LevelService.applyEatReward(player: Player, eatenSize: number)
	if getPhase() ~= PHASE.Playing then
		return
	end

	local lane = player:GetAttribute(LANE)
	local size = player:GetAttribute(SIZE)
	if typeof(size) ~= "number" then
		return
	end

	if lane == LANES.CatchUp then
		player:SetAttribute(SIZE, size + eatenSize)
		return
	end

	if lane ~= LANES.Rostered then
		return
	end

	if player:GetAttribute(FROZEN) == true then
		local bonus = player:GetAttribute(BONUS)
		if typeof(bonus) ~= "number" then
			bonus = 0
		end
		player:SetAttribute(BONUS, bonus + eatenSize)
		return
	end

	local newSize = size + eatenSize
	player:SetAttribute(SIZE, newSize)
	local target = workspace:GetAttribute(TARGET_ATTR)
	if typeof(target) == "number" and newSize >= target then
		player:SetAttribute(FROZEN, true)
		frozenSet[player] = true
		checkWinCondition()
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(SIZE, Config.Player.InitialSize)
	resetPlayerLevelState(player)

	local phase = getPhase()
	if phase == PHASE.Playing then
		catchUpSet[player] = true
		player:SetAttribute(LANE, LANES.CatchUp)

		local minSize: number? = nil
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local s = p:GetAttribute(SIZE)
				if typeof(s) == "number" and (minSize == nil or s < minSize) then
					minSize = s
				end
			end
		end
		if minSize ~= nil then
			player:SetAttribute(SIZE, minSize)
		end
	elseif phase == PHASE.Waiting then
		player:SetAttribute(LANE, LANES.Waiting)
		startLevel(1)
	else
		player:SetAttribute(LANE, LANES.Waiting)
	end
end

local function onPlayerRemoving(player: Player)
	rosterSet[player] = nil
	frozenSet[player] = nil
	catchUpSet[player] = nil
	if getPhase() == PHASE.Playing then
		checkWinCondition()
	end
end

local function timerTick()
	RunService.Heartbeat:Connect(function()
		if getPhase() ~= PHASE.Playing then
			return
		end
		local endsAt = workspace:GetAttribute(ENDS_AT_ATTR)
		if typeof(endsAt) ~= "number" then
			return
		end
		if now() >= endsAt then
			failLevel()
		end
	end)
end

function LevelService.start(): { BasePart }
	local existing = workspace:FindFirstChild("AIFish")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "AIFish"
	folder.Parent = workspace
	aiFolder = folder
	table.clear(aiFishes)

	setPhase(PHASE.Waiting)
	workspace:SetAttribute(LEVEL_ATTR, 0)
	workspace:SetAttribute(TARGET_ATTR, 0)
	workspace:SetAttribute(ENDS_AT_ATTR, 0)

	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	timerTick()

	return aiFishes
end

return LevelService
