--!strict

local Config = {}

Config.BaseWalkSpeed = 22

Config.Boost = {
	Duration = 5,
	Cooldown = 10,
	Multiplier = 2,
	ActiveUntilAttr = "BoostActiveUntil",
	ReadyAtAttr = "BoostReadyAt",
}

Config.PredationDebuffSeconds = 10

Config.Player = {
	InitialSize = 10,
}

Config.AI = {
	PartSize = Vector3.new(4, 2, 4),
	SpawnAreaCenter = Vector3.new(0, 2, 0),
	SpawnAreaRadius = 80,
	MinDistanceFromOrigin = 20,

	MinQuota = 8,
	MaxAISizeRatio = 0.8,
	QuotaMultiplier = 1.5,

	Speed = 16,
	ChaseRadius = 30,
	FleeRadius = 35,
	WanderMinSeconds = 2,
	WanderMaxSeconds = 5,
	BoundarySteerRatio = 0.85,

	BoostRollMinSeconds = 1,
	BoostRollMaxSeconds = 2,
	BoostBaseProbability = 0.05,
	BoostPanicProbability = 0.15,
	BoostPanicRadius = 35,
	BoostReactionDelayMin = 0.2,
	BoostReactionDelayMax = 0.8,
}

Config.Predation = {
	TickHz = 60,
	ContactRadius = 4,
	NoPredationRewardUntilAttr = "NoPredationRewardUntil",
	SpawnProtectionSeconds = 3,
	SpawnProtectedUntilAttr = "SpawnProtectedUntil",
}

Config.Level = {
	TargetMultiplier = 5,
	TimerBase = 90,
	TimerStep = 15,
	ClearedDuration = 4,
	FailedDuration = 8,

	LaneAttr = "Lane",
	FrozenAttr = "Frozen",
	BonusAttr = "Bonus",

	PhaseAttr = "Phase",
	LevelNumberAttr = "LevelNumber",
	TargetAttr = "LevelTarget",
	EndsAtAttr = "LevelEndsAt",
}

Config.Lane = {
	Rostered = "Rostered",
	CatchUp = "CatchUp",
	Waiting = "Waiting",
}

Config.Phase = {
	Waiting = "Waiting",
	Playing = "Playing",
	Cleared = "Cleared",
	Failed = "Failed",
}

Config.Tiers = {
	Bounds = { 1, 50, 500, 5000, 50000, 500000, 5000000, 50000000 },
	Names = { "小鱼级", "中鱼级", "大鱼级", "巨鱼级", "鲨鱼级", "鲸鱼级", "海怪级", "传说级" },
	Colors = {
		Color3.fromRGB(160, 230, 170),
		Color3.fromRGB(80, 200, 100),
		Color3.fromRGB(80, 150, 230),
		Color3.fromRGB(170, 100, 220),
		Color3.fromRGB(240, 160, 60),
		Color3.fromRGB(230, 80, 80),
		Color3.fromRGB(150, 30, 30),
		Color3.fromRGB(80, 0, 80),
	},
	ScalePerStep = 0.5,
}

return Config
