--!strict
-- Client side of the networking contract in Shared.Net.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)

local Net = {}

local function event(name: string): RemoteEvent
	assert(Remotes.List[name], `unknown remote {name}`)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Fire(name: string, ...: any)
	event(name):FireServer(...)
end

function Net.On(name: string, handler: (...any) -> ()): RBXScriptConnection
	return event(name).OnClientEvent:Connect(handler)
end

return Net
