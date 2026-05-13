--!strict

local BoostInput = require(script.Parent:WaitForChild("Boost"))
local Hud = require(script.Parent:WaitForChild("Hud"))

BoostInput.bind()
Hud.mount()
