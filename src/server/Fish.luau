--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Tier = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tier"))

local Fish = {}

Fish.SIZE_ATTRIBUTE = "Size"
local SIZE_ATTRIBUTE = Fish.SIZE_ATTRIBUTE

local SCALE_PROPERTIES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }

local function makeLabel(adornee: BasePart, color: Color3, yOffset: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FishLabel"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 80, 0, 24)
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
	local x = center.X + math.cos(angle) * r
	local z = center.Z + math.sin(angle) * r
	return Vector3.new(x, center.Y + yOffset, z)
end

local function applyHumanoidScale(humanoid: Humanoid, scale: number)
	for _, propName in SCALE_PROPERTIES do
		local v = humanoid:FindFirstChild(propName)
		if v and v:IsA("NumberValue") then
			v.Value = scale
		end
	end
end

function Fish.createAI(size: number): BasePart
	local scale = Tier.scaleOf(size)
	local partSize = Config.AI.PartSize * scale

	local part = Instance.new("Part")
	part.Name = "AIFish"
	part.Size = partSize
	part.Position = pickRandomPosition(partSize.Y / 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Tier.colorOf(size)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute(SIZE_ATTRIBUTE, size)

	local gui = makeLabel(part, Color3.fromRGB(255, 255, 255), partSize.Y / 2 + 1)
	gui.Parent = part

	local label = gui:WaitForChild("Value") :: TextLabel
	label.Text = tostring(size)
	part:GetAttributeChangedSignal(SIZE_ATTRIBUTE):Connect(function()
		local newSize = part:GetAttribute(SIZE_ATTRIBUTE)
		if typeof(newSize) == "number" then
			label.Text = tostring(newSize)
		end
	end)

	return part
end

function Fish.relocateAI(part: BasePart)
	part.Position = pickRandomPosition(part.Size.Y / 2)
end

function Fish.attachPlayerVisuals(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart

	local existing = head:FindFirstChild("FishLabel")
	if existing then
		existing:Destroy()
	end

	local gui = makeLabel(head, Color3.fromRGB(255, 220, 120), 1.5)
	gui.Parent = head

	local label = gui:WaitForChild("Value") :: TextLabel
	local function refresh()
		local size = player:GetAttribute(SIZE_ATTRIBUTE)
		if typeof(size) ~= "number" then
			return
		end
		label.Text = tostring(size)
		applyHumanoidScale(humanoid, Tier.scaleOf(size))
	end
	refresh()

	local conn = player:GetAttributeChangedSignal(SIZE_ATTRIBUTE):Connect(refresh)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			conn:Disconnect()
		end
	end)
end

return Fish
