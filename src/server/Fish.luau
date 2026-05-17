--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Tier = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tier"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local Fish = {}

Fish.SIZE_ATTRIBUTE = "Size"
local SIZE_ATTRIBUTE = Fish.SIZE_ATTRIBUTE

-- ── Appearance constants ──────────────────────────────────────────────────────

-- Sphere SpecialMesh stretches: AI is elongated (predatory), player is rounder (cute)
local AI_MESH_SCALE = Vector3.new(1, 0.65, 1.8)
local PLAYER_MESH_SCALE = Vector3.new(1, 0.82, 1.3)

local PLAYER_BASE_SIZE = Vector3.new(3, 1.8, 4.2)
local PLAYER_COLOR = Color3.fromRGB(255, 210, 50) -- bright gold
local EYE_COLOR = Color3.fromRGB(0, 220, 255) -- neon cyan
local EYE_BASE_SIZE = Vector3.new(0.38, 0.38, 0.38)

-- Tail and fin position fractions (multiples of body Part size)
local TAIL_Z = 0.95 -- tail center behind body (body +Z = backward for the fish)
local FIN_X = 0.62 -- pectoral fin center outward from body center
local FIN_Z = 0.06 -- pectoral fin slightly forward of body center

-- ── Generic part helpers ──────────────────────────────────────────────────────

local function makeLabel(adornee: BasePart, color: Color3, yOffset: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FishLabel"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 110, 0, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, yOffset, 0)
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextColor3 = color
	label.Text = "?"
	label.Parent = gui

	return gui
end

local function pickRandomPosition(yOffset: number): Vector3
	local center = Config.AI.SpawnAreaCenter
	local outer = Config.AI.SpawnAreaRadius
	local inner = Config.AI.MinDistanceFromOrigin
	local angle = math.random() * math.pi * 2
	local r = inner + math.random() * (outer - inner)
	return Vector3.new(center.X + math.cos(angle) * r, center.Y + yOffset, center.Z + math.sin(angle) * r)
end

-- Shared helper: flat oval fin Part (used for both tail and pectoral fins).
-- The Sphere SpecialMesh flattened in Y makes a convincing fin/paddle shape.
local function makeFinPart(name: string, size: Vector3, color: Color3, anchored: boolean): Part
	local fin = Instance.new("Part")
	fin.Name = name
	fin.Size = size
	fin.Color = color
	fin.Material = Enum.Material.SmoothPlastic
	fin.TopSurface = Enum.SurfaceType.Smooth
	fin.BottomSurface = Enum.SurfaceType.Smooth
	fin.Anchored = anchored
	fin.CanCollide = false
	fin.CanTouch = false

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	-- Scale: stretch X for width, flatten Y to a thin disc, keep Z shape
	mesh.Scale = Vector3.new(1.1, 0.55, 0.95)
	mesh.Parent = fin

	return fin
end

local function makeEyePart(): Part
	local eye = Instance.new("Part")
	eye.Name = "FishEye"
	eye.Size = EYE_BASE_SIZE
	eye.Color = EYE_COLOR
	eye.Material = Enum.Material.Neon
	eye.Anchored = false
	eye.CanCollide = false
	eye.CanTouch = false

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = eye

	return eye
end

-- Hide the default R15 humanoid so only our fish visual is visible
local function hideCharacterParts(character: Model)
	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
			local p = desc :: BasePart
			p.Transparency = 1
			p.CastShadow = false
			p.CanCollide = false
		elseif desc:IsA("Decal") then
			(desc :: Decal).Transparency = 1
		end
	end
end

-- ── AI fish ───────────────────────────────────────────────────────────────────

function Fish.createAI(size: number): BasePart
	local scale = Tier.scaleOf(size)
	local bs = Config.AI.PartSize * scale -- body (Part) size
	local color = Tier.colorOf(size)
	local yOffset = bs.Y * AI_MESH_SCALE.Y / 2

	-- Body (elongated sphere = predatory fish silhouette)
	local part = Instance.new("Part")
	part.Name = "AIFish"
	part.Size = bs
	part.Position = pickRandomPosition(yOffset)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute(SIZE_ATTRIBUTE, size)

	local bodyMesh = Instance.new("SpecialMesh")
	bodyMesh.MeshType = Enum.MeshType.Sphere
	bodyMesh.Scale = AI_MESH_SCALE
	bodyMesh.Parent = part

	-- Tail fin: flat oval disc at the back (clearly fish-shaped from above)
	-- Size: wide in X, very flat in Y, medium depth in Z
	local tail = makeFinPart("FishTail", Vector3.new(bs.X * 1.1, bs.Y * 0.1, bs.Z * 0.42), color, true)
	tail.CFrame = part.CFrame * CFrame.new(0, 0, bs.Z * TAIL_Z)
	tail.Parent = part -- child of body so destroyed together

	-- Left and right pectoral fins: fan out to the sides (visible from top-down)
	local finDarker = color:Lerp(Color3.fromRGB(0, 0, 0), 0.12)
	local finSize = Vector3.new(bs.X * 0.55, bs.Y * 0.07, bs.Z * 0.30)

	local finL = makeFinPart("FinL", finSize, finDarker, true)
	finL.CFrame = part.CFrame * CFrame.new(-bs.X * FIN_X, 0, -bs.Z * FIN_Z)
	finL.Parent = part

	local finR = makeFinPart("FinR", finSize, finDarker, true)
	finR.CFrame = part.CFrame * CFrame.new(bs.X * FIN_X, 0, -bs.Z * FIN_Z)
	finR.Parent = part

	-- Floating label
	local gui = makeLabel(part, Color3.fromRGB(255, 255, 255), yOffset + 1.2)
	gui.Parent = part

	local label = gui:FindFirstChild("Value") :: TextLabel
	local function refreshLabel()
		local s = part:GetAttribute(SIZE_ATTRIBUTE)
		if typeof(s) ~= "number" then
			return
		end
		label.Text = Tier.nameOf(s) .. "\n" .. Format.number(s)
	end
	refreshLabel()
	part:GetAttributeChangedSignal(SIZE_ATTRIBUTE):Connect(refreshLabel)

	return part
end

function Fish.relocateAI(part: BasePart)
	part.Position = pickRandomPosition(part.Size.Y * AI_MESH_SCALE.Y / 2)
end

-- ── Player fish ───────────────────────────────────────────────────────────────

function Fish.attachPlayerVisuals(player: Player, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Hide the default R15 humanoid appearance
	hideCharacterParts(character)

	-- Hide accessories / body parts added slightly after CharacterAdded
	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" and not desc:GetAttribute("FishVisual") then
			local p = desc :: BasePart
			p.Transparency = 1
			p.CastShadow = false
			p.CanCollide = false
		end
	end)

	-- Helper: attach part to HRP using old Weld (has C0/C1, so C0 can be updated for scaling)
	local function weldToHRP(part: BasePart, c0: CFrame): Weld
		part:SetAttribute("FishVisual", true)
		part.Anchored = false
		part.CFrame = hrp.CFrame * c0 -- pre-position to avoid one-frame glitch

		local w = Instance.new("Weld")
		w.Part0 = hrp
		w.Part1 = part
		w.C0 = c0
		w.C1 = CFrame.identity
		w.Parent = part
		part.Parent = character
		return w
	end

	-- ── Body ──────────────────────────────────────────────────────────────────
	local fishBody = Instance.new("Part")
	fishBody.Name = "PlayerFishBody"
	fishBody.Size = PLAYER_BASE_SIZE
	fishBody.Color = PLAYER_COLOR
	fishBody.Material = Enum.Material.SmoothPlastic
	fishBody.TopSurface = Enum.SurfaceType.Smooth
	fishBody.BottomSurface = Enum.SurfaceType.Smooth
	fishBody.CanCollide = false
	fishBody.CanTouch = false

	local bodyMesh = Instance.new("SpecialMesh")
	bodyMesh.MeshType = Enum.MeshType.Sphere
	bodyMesh.Scale = PLAYER_MESH_SCALE
	bodyMesh.Parent = fishBody

	local bodyWeld = weldToHRP(fishBody, CFrame.identity) -- centered on HRP

	-- ── Tail fin ─────────────────────────────────────────────────────────────
	local tailColor = PLAYER_COLOR:Lerp(Color3.fromRGB(200, 140, 0), 0.18)
	local fishTail = makeFinPart(
		"FishTail",
		Vector3.new(PLAYER_BASE_SIZE.X * 1.1, PLAYER_BASE_SIZE.Y * 0.1, PLAYER_BASE_SIZE.Z * 0.42),
		tailColor,
		false
	)
	local tailWeld = weldToHRP(fishTail, CFrame.new(0, 0, PLAYER_BASE_SIZE.Z * TAIL_Z))

	-- ── Pectoral fins ─────────────────────────────────────────────────────────
	local finColor = PLAYER_COLOR:Lerp(Color3.fromRGB(200, 140, 0), 0.12)
	local pFinSize = Vector3.new(PLAYER_BASE_SIZE.X * 0.55, PLAYER_BASE_SIZE.Y * 0.07, PLAYER_BASE_SIZE.Z * 0.30)

	local fishFinL = makeFinPart("FinL", pFinSize, finColor, false)
	local finLWeld = weldToHRP(fishFinL, CFrame.new(-PLAYER_BASE_SIZE.X * FIN_X, 0, -PLAYER_BASE_SIZE.Z * FIN_Z))

	local fishFinR = makeFinPart("FinR", pFinSize, finColor, false)
	local finRWeld = weldToHRP(fishFinR, CFrame.new(PLAYER_BASE_SIZE.X * FIN_X, 0, -PLAYER_BASE_SIZE.Z * FIN_Z))

	-- ── Eyes (neon cyan — distinct from all AI tier colors) ───────────────────
	local eyeL = makeEyePart()
	local eyeR = makeEyePart()
	-- Eyes sit at the front-top of the fish body (HRP -Z = forward for the player character)
	local eyeC0L = CFrame.new(-PLAYER_BASE_SIZE.X * 0.28, PLAYER_BASE_SIZE.Y * 0.22, -(PLAYER_BASE_SIZE.Z * PLAYER_MESH_SCALE.Z) * 0.44)
	local eyeC0R = CFrame.new(PLAYER_BASE_SIZE.X * 0.28, PLAYER_BASE_SIZE.Y * 0.22, -(PLAYER_BASE_SIZE.Z * PLAYER_MESH_SCALE.Z) * 0.44)
	local eyeLWeld = weldToHRP(eyeL, eyeC0L)
	local eyeRWeld = weldToHRP(eyeR, eyeC0R)

	-- ── White outline highlight — player fish always visible in a crowd ────────
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.92
	highlight.OutlineColor = Color3.fromRGB(255, 255, 220)
	highlight.OutlineTransparency = 0
	highlight.Parent = fishBody

	-- ── Floating label ────────────────────────────────────────────────────────
	local labelYOffset = PLAYER_BASE_SIZE.Y * PLAYER_MESH_SCALE.Y / 2 + 1.5
	local gui = makeLabel(fishBody, Color3.fromRGB(255, 220, 120), labelYOffset)
	gui.Parent = fishBody
	local label = gui:FindFirstChild("Value") :: TextLabel

	-- ── Refresh (runs on eat / freeze change) ─────────────────────────────────
	local function refresh()
		local size = player:GetAttribute(SIZE_ATTRIBUTE)
		if typeof(size) ~= "number" then
			return
		end
		local scale = Tier.scaleOf(size)
		local bs = PLAYER_BASE_SIZE * scale

		-- Label text
		local frozen = player:GetAttribute(Config.Level.FrozenAttr) == true
		local prefix = if frozen then "❄ " else ""
		label.Text = prefix .. Format.number(size) .. "\n" .. Tier.nameOf(size)

		-- Scale body
		fishBody.Size = bs

		-- Scale tail + reposition via Weld.C0
		fishTail.Size = Vector3.new(bs.X * 1.1, bs.Y * 0.1, bs.Z * 0.42)
		tailWeld.C0 = CFrame.new(0, 0, bs.Z * TAIL_Z)

		-- Scale pectoral fins + reposition
		local pfs = Vector3.new(bs.X * 0.55, bs.Y * 0.07, bs.Z * 0.30)
		fishFinL.Size = pfs
		fishFinR.Size = pfs
		finLWeld.C0 = CFrame.new(-bs.X * FIN_X, 0, -bs.Z * FIN_Z)
		finRWeld.C0 = CFrame.new(bs.X * FIN_X, 0, -bs.Z * FIN_Z)

		-- Scale eyes + reposition
		local eSz = EYE_BASE_SIZE * scale
		eyeL.Size = eSz
		eyeR.Size = eSz
		local eX = bs.X * 0.28
		local eY = bs.Y * 0.22
		local eZ = -(bs.Z * PLAYER_MESH_SCALE.Z) * 0.44
		eyeLWeld.C0 = CFrame.new(-eX, eY, eZ)
		eyeRWeld.C0 = CFrame.new(eX, eY, eZ)

		-- Keep label above the tallest visual point
		gui.StudsOffsetWorldSpace = Vector3.new(0, bs.Y * PLAYER_MESH_SCALE.Y / 2 + 1.5, 0)

		-- suppress unused-variable warning for bodyWeld
		local _ = bodyWeld
	end
	refresh()

	local connSize = player:GetAttributeChangedSignal(SIZE_ATTRIBUTE):Connect(refresh)
	local connFrozen = player:GetAttributeChangedSignal(Config.Level.FrozenAttr):Connect(refresh)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			connSize:Disconnect()
			connFrozen:Disconnect()
		end
	end)
end

return Fish
