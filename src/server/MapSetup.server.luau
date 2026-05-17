--!strict
-- MapSetup.server.luau
-- Turns the bare Baseplate into an underwater ocean-floor arena.
-- All decorative Parts are Anchored + CanCollide = false — zero gameplay impact.

local Lighting = game:GetService("Lighting")

-- ── Lighting & post-processing ────────────────────────────────────────────────

Lighting.Ambient = Color3.fromRGB(30, 80, 145)
Lighting.OutdoorAmbient = Color3.fromRGB(18, 60, 120)
Lighting.Brightness = 2
Lighting.ClockTime = 13
Lighting.FogColor = Color3.fromRGB(12, 68, 148)
Lighting.FogEnd = 290
Lighting.FogStart = 95
Lighting.ShadowSoftness = 0.35

-- Underwater haze
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.38
atmo.Offset = 0.05
atmo.Color = Color3.fromRGB(48, 118, 205)
atmo.Decay = Color3.fromRGB(8, 48, 100)
atmo.Glare = 0.08
atmo.Haze = 1.2
atmo.Parent = Lighting

-- Cool blue-green tint
local cc = Instance.new("ColorCorrectionEffect")
cc.Brightness = 0
cc.Contrast = 0.18
cc.Saturation = 0.3
cc.TintColor = Color3.fromRGB(210, 232, 255)
cc.Parent = Lighting

-- Makes neon coral and fish eyes pop
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.45
bloom.Size = 20
bloom.Threshold = 0.85
bloom.Parent = Lighting

-- Light shafts through the water surface above
local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.22
sunRays.Spread = 0.5
sunRays.Parent = Lighting

-- ── Ocean floor ───────────────────────────────────────────────────────────────

local baseplate = workspace:FindFirstChild("Baseplate") :: BasePart?
if baseplate then
	baseplate.Material = Enum.Material.SandyRock
	baseplate.Color = Color3.fromRGB(195, 175, 128)
end

-- Shimmering water surface high above — look up and you see the sea
local waterSurface = Instance.new("Part")
waterSurface.Name = "WaterSurface"
waterSurface.Size = Vector3.new(700, 1, 700)
waterSurface.Position = Vector3.new(0, 35, 0)
waterSurface.Color = Color3.fromRGB(55, 140, 225)
waterSurface.Material = Enum.Material.Neon
waterSurface.Transparency = 0.82
waterSurface.Anchored = true
waterSurface.CanCollide = false
waterSurface.CanTouch = false
waterSurface.CastShadow = false
waterSurface.Parent = workspace

-- ── Decoration helpers ────────────────────────────────────────────────────────

local decor = Instance.new("Folder")
decor.Name = "MapDecor"
decor.Parent = workspace

-- Isolated RNG with a fixed seed → same layout every server start
local rng = Random.new(12345)

local function rF(a: number, b: number): number
	return a + rng:NextNumber() * (b - a)
end
local function rI(a: number, b: number): number
	return rng:NextInteger(a, b)
end

-- Returns (x, z) uniformly spread inside an annular ring
local function annular(rMin: number, rMax: number): (number, number)
	local angle = rng:NextNumber() * math.pi * 2
	local r = rMin + math.sqrt(rng:NextNumber()) * (rMax - rMin)
	return r * math.cos(angle), r * math.sin(angle)
end

local function newPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = decor
	return p
end

-- ── Seaweed ───────────────────────────────────────────────────────────────────

local WEED_COLORS = {
	Color3.fromRGB(28, 138, 55),
	Color3.fromRGB(18, 110, 48),
	Color3.fromRGB(16, 98, 76),
	Color3.fromRGB(52, 158, 38),
}

local function makeSeaweed(x: number, z: number)
	local h = rF(4, 9)
	local p = newPart()
	p.Size = Vector3.new(0.55, h, 0.55)
	p.Color = WEED_COLORS[rI(1, #WEED_COLORS)]
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.new(x, h / 2, z)
		* CFrame.Angles(rF(-0.2, 0.2), rng:NextNumber() * math.pi * 2, rF(-0.2, 0.2))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = p
end

-- ── Coral ─────────────────────────────────────────────────────────────────────

local CORAL_COLORS = {
	Color3.fromRGB(255, 88, 118), -- hot pink
	Color3.fromRGB(255, 148, 42), -- orange
	Color3.fromRGB(200, 72, 215), -- purple
	Color3.fromRGB(255, 218, 65), -- yellow
	Color3.fromRGB(60, 215, 235), -- cyan
}

local function makeCoral(cx: number, cz: number)
	local color = CORAL_COLORS[rI(1, #CORAL_COLORS)]
	local n = rI(3, 6)
	for i = 1, n do
		local angle = (i / n) * math.pi * 2 + rF(-0.4, 0.4)
		local spread = rF(0.2, 1.5)
		local h = rF(1.5, 3.2)
		local p = newPart()
		p.Size = Vector3.new(0.85, h, 0.85)
		p.Color = color
		p.Material = Enum.Material.Neon -- slight glow, like real fluorescent coral
		p.CFrame = CFrame.new(cx + math.cos(angle) * spread, h / 2, cz + math.sin(angle) * spread)
			* CFrame.Angles(rF(-0.3, 0.3), rng:NextNumber() * math.pi * 2, rF(-0.3, 0.3))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(0.72, 1.35, 0.72)
		mesh.Parent = p
	end
end

-- ── Rocks ─────────────────────────────────────────────────────────────────────

local ROCK_COLORS = {
	Color3.fromRGB(102, 110, 120),
	Color3.fromRGB(130, 124, 112),
	Color3.fromRGB(86, 96, 106),
	Color3.fromRGB(148, 140, 126),
}

local function makeRock(x: number, z: number, scale: number)
	local rw = scale * rF(0.75, 1.25)
	local rh = scale * rF(0.32, 0.58)
	local rd = scale * rF(0.68, 1.22)
	local p = newPart()
	p.Size = Vector3.new(rw, rh, rd)
	p.Color = ROCK_COLORS[rI(1, #ROCK_COLORS)]
	p.Material = Enum.Material.SmoothRock
	p.CFrame = CFrame.new(x, rh / 2, z)
		* CFrame.Angles(rF(-0.14, 0.14), rng:NextNumber() * math.pi * 2, rF(-0.1, 0.1))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.58, 0.9)
	mesh.Parent = p
end

-- ── Arena boundary: glowing coral pillars at r = 81 ──────────────────────────
-- They form a ring you can see from anywhere in the play area

local PILLAR_COLORS = {
	Color3.fromRGB(178, 152, 232), -- lavender
	Color3.fromRGB(202, 118, 222), -- pink-purple
	Color3.fromRGB(138, 178, 238), -- periwinkle
}

for i = 1, 24 do
	local angle = (i / 24) * math.pi * 2
	local px = math.cos(angle) * 81
	local pz = math.sin(angle) * 81
	local h = rF(5.5, 9.5)
	local p = newPart()
	p.Size = Vector3.new(1.9, h, 1.9)
	p.Color = PILLAR_COLORS[((i - 1) % #PILLAR_COLORS) + 1]
	p.Material = Enum.Material.Neon
	p.CFrame = CFrame.new(px, h / 2, pz)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.62, 1.65, 0.62)
	mesh.Parent = p
end

-- ── Scatter decorations ───────────────────────────────────────────────────────
-- Mid ring (r 26-64): light scatter — don't clutter the gameplay core
for _ = 1, 30 do
	local x, z = annular(26, 64)
	makeSeaweed(x, z)
end

for _ = 1, 18 do
	local x, z = annular(20, 64)
	makeRock(x, z, rF(2.5, 5.5))
end

for _ = 1, 14 do
	local x, z = annular(22, 64)
	makeCoral(x, z)
end

-- Outer ring (r 64-80): denser, reinforces the arena boundary
for _ = 1, 38 do
	local x, z = annular(64, 80)
	if rng:NextNumber() < 0.55 then
		makeSeaweed(x, z)
	else
		makeRock(x, z, rF(2, 4.5))
	end
end

for _ = 1, 20 do
	local x, z = annular(64, 80)
	makeCoral(x, z)
end
