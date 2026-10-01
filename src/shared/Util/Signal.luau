--!strict
--[[
	Typed signal for in-process events between services or controllers.
	Handlers run on reused coroutines, so a yielding handler never blocks Fire.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local freeRunner: thread? = nil

local function acquireRunnerAndCall(handler: (...any) -> (), ...: any)
	local runner = freeRunner
	freeRunner = nil
	handler(...)
	freeRunner = runner
end

local function runEventHandlers(...: any)
	acquireRunnerAndCall(...)
	while true do
		acquireRunnerAndCall(coroutine.yield())
	end
end

local Signal = {}
Signal.__index = Signal

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal.Connect(self: any, handler: (...any) -> ()): Connection
	local connection = setmetatable({ Connected = true, _signal = self, _fn = handler }, ConnectionClass)
	table.insert(self._handlers, connection)
	return (connection :: any) :: Connection
end

function Signal.Once(self: any, handler: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire(self: any, ...: any)
	-- Snapshot so handlers that disconnect during Fire do not skip neighbours.
	local handlers: { any } = table.clone(self._handlers)
	for _, connection in handlers do
		if connection.Connected then
			if freeRunner == nil then
				freeRunner = coroutine.create(runEventHandlers)
			end
			task.spawn(freeRunner :: thread, connection._fn, ...)
		end
	end
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
