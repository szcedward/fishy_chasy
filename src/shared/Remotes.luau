--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if IS_SERVER then
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	else
		return parent:WaitForChild(name) :: Folder
	end
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if IS_SERVER then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = parent
		return r
	else
		return parent:WaitForChild(name) :: RemoteEvent
	end
end

local folder = ensureFolder(ReplicatedStorage, "Remotes")

local Remotes = {
	RequestBoost = ensureRemoteEvent(folder, "RequestBoost"),
}

return Remotes
