--!strict

-- Client-side sound effects.
-- All sounds are played locally via SoundService so each client hears its own events.
--
-- SOUND IDs — swap these in the Roblox Toolbox (Models → Audio) if you want better sounds.
-- The ones below are free Roblox catalog audio that have been available for years.
-- If a sound is silent, open Studio → SoundService and check if the asset loaded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local IDS = {
	Eat = "rbxassetid://9117502460", -- satisfying pop / gulp
	Die = "rbxassetid://131070166", -- short negative sting
	LevelCleared = "rbxassetid://3051417649", -- upbeat chime
	LevelFailed = "rbxassetid://445596489", -- sad wah-wah
	Boost = "rbxassetid://154965962", -- whoosh
	FoodPickup = "rbxassetid://4612375802", -- bright pickup chime
	ShieldBreak = "rbxassetid://12222216", -- glassy pop
}

local VOLUMES = {
	Eat = 0.6,
	Die = 0.8,
	LevelCleared = 1.0,
	LevelFailed = 0.8,
	Boost = 0.7,
	FoodPickup = 0.75,
	ShieldBreak = 0.65,
}

local sounds: { [string]: Sound } = {}

local function makeSound(name: string): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = IDS[name]
	s.Volume = VOLUMES[name] or 0.7
	s.RollOffMaxDistance = 0
	s.Parent = SoundService
	sounds[name] = s
	return s
end

local function play(name: string)
	local s = sounds[name]
	if s then
		s:Play()
	end
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		play("Die")
	end)
end

function Sounds.mount()
	for name in IDS do
		makeSound(name)
	end

	local localPlayer = Players.LocalPlayer

	-- Eat: size attribute increased
	local lastSize = localPlayer:GetAttribute("Size") or 0
	localPlayer:GetAttributeChangedSignal("Size"):Connect(function()
		local newSize = localPlayer:GetAttribute("Size")
		if typeof(newSize) == "number" and newSize > lastSize then
			play("Eat")
		end
		if typeof(newSize) == "number" then
			lastSize = newSize
		end
	end)

	-- Boost: BoostActiveUntil set to a future time
	localPlayer:GetAttributeChangedSignal(Config.Boost.ActiveUntilAttr):Connect(function()
		local until_ = localPlayer:GetAttribute(Config.Boost.ActiveUntilAttr)
		if typeof(until_) == "number" and until_ > workspace:GetServerTimeNow() then
			play("Boost")
		end
	end)

	-- Shield layers: pickup vs break
	local lastShield = localPlayer:GetAttribute(Config.Shield.LayersAttr) or 0
	localPlayer:GetAttributeChangedSignal(Config.Shield.LayersAttr):Connect(function()
		local newShield = localPlayer:GetAttribute(Config.Shield.LayersAttr)
		if typeof(newShield) ~= "number" then
			return
		end
		local prev = if typeof(lastShield) == "number" then lastShield else 0
		if newShield > prev then
			play("FoodPickup")
		elseif newShield < prev and newShield >= 0 then
			local char = localPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				play("ShieldBreak")
			end
		end
		lastShield = newShield
	end)

	-- Level Cleared / Failed: Phase attribute on workspace
	local lastPhase = workspace:GetAttribute(Config.Level.PhaseAttr)
	workspace:GetAttributeChangedSignal(Config.Level.PhaseAttr):Connect(function()
		local phase = workspace:GetAttribute(Config.Level.PhaseAttr)
		if phase == Config.Phase.Cleared and lastPhase ~= Config.Phase.Cleared then
			play("LevelCleared")
		elseif phase == Config.Phase.Failed and lastPhase ~= Config.Phase.Failed then
			play("LevelFailed")
		end
		lastPhase = phase
	end)

	-- Death: watch current and future characters
	localPlayer.CharacterAdded:Connect(watchCharacter)
	if localPlayer.Character then
		watchCharacter(localPlayer.Character)
	end
end

return Sounds
