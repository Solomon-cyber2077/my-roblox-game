--!strict

-- Input observation for the lobby-idle feature. This module never sinks input
-- and has no heartbeat; the owner polls IsHeld/IsBlocked from its own loop.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LobbyIdleInput = {}

export type Options = {
	StickDeadzone: number,
	MouseThreshold: number,
}

export type Observer = {
	IsHeld: (self: Observer) -> boolean,
	IsBlocked: (self: Observer) -> boolean,
	Destroy: (self: Observer) -> (),
}

-- Only these are held between InputBegan and InputEnded (a Focus begin never ends).
local HOLDABLE: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isGamepad(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.Gamepad1
		or inputType == Enum.UserInputType.Gamepad2
		or inputType == Enum.UserInputType.Gamepad3
		or inputType == Enum.UserInputType.Gamepad4
		or inputType == Enum.UserInputType.Gamepad5
		or inputType == Enum.UserInputType.Gamepad6
		or inputType == Enum.UserInputType.Gamepad7
		or inputType == Enum.UserInputType.Gamepad8
end

function LobbyIdleInput.new(onActivity: () -> (), options: Options): Observer
	assert(
		finite(options.StickDeadzone) and options.StickDeadzone >= 0 and options.StickDeadzone < 1,
		"invalid stick deadzone"
	)
	assert(finite(options.MouseThreshold) and options.MouseThreshold > 0, "invalid mouse threshold")

	local alive = true
	local focused = true
	local held: { [InputObject]: boolean } = {}
	local touchHeld: { [InputObject]: boolean } = {}
	local connections: { RBXScriptConnection } = {}

	local function activity()
		if alive then
			onActivity()
		end
	end

	local function began(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			activity()
			return
		end
		if isGamepad(input.UserInputType) then
			activity()
			return
		end
		if
			input.KeyCode == Enum.KeyCode.Thumbstick1
			or input.KeyCode == Enum.KeyCode.Thumbstick2
			or input.KeyCode == Enum.KeyCode.ButtonL2
			or input.KeyCode == Enum.KeyCode.ButtonR2
		then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			touchHeld[input] = true
		elseif HOLDABLE[input.UserInputType] then
			held[input] = true
		end
		activity()
	end

	local function changed(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if input.Delta.Magnitude >= options.MouseThreshold then
				activity()
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if input.Position.Z ~= 0 then
				activity()
			end
			return
		end
		if
			input.KeyCode == Enum.KeyCode.Thumbstick1
			or input.KeyCode == Enum.KeyCode.Thumbstick2
			or input.KeyCode == Enum.KeyCode.ButtonL2
			or input.KeyCode == Enum.KeyCode.ButtonR2
		then
			if input.Position.Magnitude > options.StickDeadzone then
				activity()
			end
		end
	end

	local function ended(input: InputObject)
		held[input] = nil
		touchHeld[input] = nil
		activity()
	end

	local function focusLost()
		focused = false
		table.clear(held)
		table.clear(touchHeld)
		activity()
	end

	local function focusGained()
		focused = true
		activity()
	end

	table.insert(connections, UserInputService.InputBegan:Connect(began))
	table.insert(connections, UserInputService.InputChanged:Connect(changed))
	table.insert(connections, UserInputService.InputEnded:Connect(ended))
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(focusLost))
	table.insert(connections, UserInputService.WindowFocused:Connect(focusGained))
	table.insert(connections, GuiService.MenuOpened:Connect(activity))
	table.insert(connections, GuiService.MenuClosed:Connect(activity))

	local observer = {} :: Observer
	function observer:IsHeld(): boolean
		if not alive or not focused then
			return false
		end
		if next(held) ~= nil or next(touchHeld) ~= nil then
			return true
		end
		if #UserInputService:GetKeysPressed() > 0 or #UserInputService:GetMouseButtonsPressed() > 0 then
			return true
		end
		for _, gamepad in UserInputService:GetConnectedGamepads() do
			for _, state in UserInputService:GetGamepadState(gamepad) do
				if
					state.KeyCode == Enum.KeyCode.Thumbstick1
					or state.KeyCode == Enum.KeyCode.Thumbstick2
					or state.KeyCode == Enum.KeyCode.ButtonL2
					or state.KeyCode == Enum.KeyCode.ButtonR2
				then
					if state.Position.Magnitude > options.StickDeadzone then
						return true
					end
				elseif
					state.UserInputState == Enum.UserInputState.Begin
					or state.UserInputState == Enum.UserInputState.Change
				then
					return true
				end
			end
		end
		return false
	end

	function observer:IsBlocked(): boolean
		if not alive or not focused then
			return true
		end
		return GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
	end

	function observer:Destroy()
		if not alive then
			return
		end
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		table.clear(held)
		table.clear(touchHeld)
	end

	return observer
end

return LobbyIdleInput
