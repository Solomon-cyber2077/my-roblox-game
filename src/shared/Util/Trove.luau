--!strict
--[[
	Collects everything a feature creates so one Clean() call releases it:
	instances, connections, threads, callbacks, and objects with Destroy/Disconnect.
]]

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable({} :: { _items: { any } }, Trove))

function Trove.new(): Trove
	return setmetatable({ _items = {} }, Trove)
end

function Trove.Add<T>(self: Trove, item: T): T
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	return self:Add(signal:Connect(handler))
end

-- Child trove whose lifetime ends with this one; useful for per-phase cleanup.
function Trove.Extend(self: Trove): Trove
	return self:Add(Trove.new())
end

local function release(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if type(item.Clean) == "function" then
			item:Clean()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove.Clean(self: Trove)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		release(items[i])
	end
end

Trove.Destroy = Trove.Clean

return Trove
