--!strict

local BoostInput = require(script.Parent:WaitForChild("Boost"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

BoostInput.bind()
Hud.mount()
Sounds.mount()
