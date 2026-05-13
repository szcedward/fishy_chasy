--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local BoostInput = {}

local ACTION_NAME = "FishBoost"

function BoostInput.bind()
	local function handle(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
		if inputState == Enum.UserInputState.Begin then
			Remotes.RequestBoost:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindAction(ACTION_NAME, handle, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION_NAME, "BOOST")
end

return BoostInput
