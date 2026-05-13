--!strict

local Greeter = {}

function Greeter.greet(who: string): string
	return `Hello, {who}! (from ReplicatedStorage.Shared.Greeter)`
end

return Greeter
