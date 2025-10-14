--!strict
--services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Players = game:GetService("Players")
--packages
local Maid = require(script.Parent:WaitForChild("Maid"))
--modules
--types
type Maid = Maid.Maid

type Device = "Keyboard" | "Mobile" | "Console"
type InputEventType = "Toggle" | "Hold" | "Release"

export type CustomInputObject = {
	Disabled: boolean,
	IsActive: boolean,
	Debounce: boolean,

	LastInputActive: number,

	Device: Device,

	Keys: { Key },
	InputEventType: InputEventType,
	OnBeginCallback: (dt: number, delta: Vector3) -> (() -> ())?,
}
export type Key = Enum.KeyCode | Enum.UserInputType | "Touch" | "JoystickTouch1" | "JoystickTouch2"
export type InputManager = {
	__index: InputManager,

	_Maid: Maid,

	RegisteredInputs: { [string]: CustomInputObject },

	new: () -> InputManager,

	getDevice: () -> Device,

	Start: (InputManager) -> (),
	RegisterNewInput: (
		InputManager,

		inputName: string,
		platformType: Device,
		keys: { Key },
		inputEventType: InputEventType,
		onCallback: (dt: number, delta: Vector3) -> () -> ()
	) -> (),
	ToggleInput: (InputManager, inputName: string, toggle: boolean) -> (),
	--RegisterNewContextInput : (
	--	InputManager
	--) -> (),

	Destroy: (InputManager) -> (),
}
--constants
--remotes
--variables
--references
local player = Players.LocalPlayer
--local functions
--class
local manager: InputManager = {} :: any
manager.__index = manager

function createCustomInputObject(
	disabled: boolean,
	isActive: boolean,
	debounce: boolean,

	lastInputActive: number,

	device: Device,

	keys: { Enum.KeyCode | Enum.UserInputType },
	inputEventType: InputEventType,
	onBeginCallback: (dt: number, delta: Vector3) -> (() -> ())?
): CustomInputObject
	return {
		Disabled = disabled,
		IsActive = isActive,
		Debounce = debounce,

		Device = device,

		LastInputActive = lastInputActive,

		Keys = keys,
		InputEventType = inputEventType,
		OnBeginCallback = onBeginCallback,
	}
end

function manager.getDevice()
	local TouchEnabled = UserInputService.TouchEnabled
	local KeyboardEnabled = UserInputService.KeyboardEnabled
	local MouseEnabled = UserInputService.MouseEnabled
	local GamepadEnabled = UserInputService.GamepadEnabled

	if GamepadEnabled then
		return "Console"
	elseif TouchEnabled and not (KeyboardEnabled or MouseEnabled) then
		return "Mobile"
	else
		return "Keyboard"
	end
end

function manager.new()
	local self: InputManager = setmetatable({}, manager) :: any

	self._Maid = Maid.new()
	self.RegisteredInputs = {} :: { [string]: CustomInputObject }

	self:Start()

	return self
end

function manager:Start()
	local deltaV3 = Vector3.new()
	local mouse = player:GetMouse()

	local isTouching = false
	local isJoystick1, isJoystick2 = false, false
	local isInGpe = false
	--local isPressingAll = false
	local pressedInputsInOrder: { [number]: { CustomInput: Key, Timestamp: number, IsPressing: boolean } } = {}

	local mousePosV30 = Vector3.new(mouse.X, mouse.Y, 0)

	local function getPressedInputInfo(customInput: Key): { CustomInput: Key, Timestamp: number, IsPressing: boolean }?
		for _, v in pairs(pressedInputsInOrder) do
			if customInput == v.CustomInput then
				return v
			end
		end
		return nil
	end

	self._Maid:GiveTask(RunService.Heartbeat:Connect(function()
		for _, input in pairs(self.RegisteredInputs) do
			local _isPressingAll = if self.getDevice() == input.Device
				then ((if self.getDevice() == "Console" then true else not isInGpe) and #input.Keys > 0)
				else false

			for _, key: Key in pairs(input.Keys :: any) do
				local pressedInputInfo = getPressedInputInfo(key)
				if
					typeof(key) == "EnumItem"
					and (
						(
							key:IsA("KeyCode")
							and (
								not UserInputService:IsKeyDown(key)
								and not UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, key)
							)
						) or (key:IsA("UserInputType") and not UserInputService:IsMouseButtonPressed(key))
					)
				then --check #1
					_isPressingAll = false

					if pressedInputInfo then
						pressedInputInfo.IsPressing = false
					end
				elseif (typeof(key) == "string" and key == "Touch") and not isTouching then --check #2
					_isPressingAll = false

					if pressedInputInfo then
						pressedInputInfo.IsPressing = false
					end
				elseif (typeof(key) == "string" and key == "JoystickTouch1") and not isJoystick1 then --check #2
					_isPressingAll = false

					if pressedInputInfo then
						pressedInputInfo.IsPressing = false
					end
				elseif (typeof(key) == "string" and key == "JoystickTouch2") and not isJoystick2 then --check #2
					_isPressingAll = false

					if pressedInputInfo then
						pressedInputInfo.IsPressing = false
					end
				else
					local _pressedInputInfo: any
					if not pressedInputInfo then
						_pressedInputInfo = {
							CustomInput = key :: any,
							Timestamp = tick(),
							IsPressing = false,
						}
						table.insert(pressedInputsInOrder, _pressedInputInfo)
					else
						_pressedInputInfo = pressedInputInfo
					end

					if not _pressedInputInfo.IsPressing then
						_pressedInputInfo.IsPressing = true
						_pressedInputInfo.Timestamp = tick()
					end
				end
			end

			if _isPressingAll == true then
				local filteredActives = {}

				for _, v in pairs(pressedInputsInOrder) do
					if v.IsPressing and table.find(input.Keys, v.CustomInput) then
						table.insert(filteredActives, v)
					end
				end

				table.sort(filteredActives, function(a, b)
					return a.Timestamp < b.Timestamp
				end)

				for k, v in pairs(input.Keys) do
					local isPressed = false

					for k2, v2 in pairs(filteredActives) do
						if (k == k2) and v == v2.CustomInput then
							isPressed = true
							break
						end
					end

					if isPressed == false then
						_isPressingAll = false
						break
					end
				end

				-- if _isPressingAll == true then
				-- 	input.IsActive = _isPressingAll
				-- end
			end

			input.IsActive = _isPressingAll -- new

			-- if input.Keys[1] == Enum.KeyCode.D then
			-- 	print(input)
			-- end

			if input.Disabled == false then
				if input.InputEventType == "Toggle" then
					-- input.IsActive = false
					if input.Debounce == false and input.IsActive then
						input.Debounce = true
						input.LastInputActive = tick()
						input.OnBeginCallback(0, deltaV3)
					elseif input.IsActive == false then
						input.Debounce = false
					end
				elseif input.InputEventType == "Hold" then
					local lastInputActive = if input.IsActive and input.Debounce then tick() else input.LastInputActive

					local _deltaV3 = if input.IsActive and input.Debounce
						then deltaV3
						else (if (
								(
									UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
									or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
								) or isTouching
							)
							then (Vector3.new(mouse.X, mouse.Y, 0) - mousePosV30)
							else deltaV3)

					local cleanup = if input.IsActive or (not input.IsActive and not input.Debounce)
						then input.OnBeginCallback(tick() - lastInputActive, _deltaV3)
						else nil

					if input.IsActive then
						input.Debounce = false

						input.LastInputActive = tick()
						mousePosV30 = Vector3.new(mouse.X, mouse.Y, 0)
					elseif not input.Debounce then
						input.Debounce = true
						if cleanup then
							cleanup()
						end

						input.LastInputActive = tick()
						mousePosV30 = Vector3.new(mouse.X, mouse.Y, 0)
					end
					-- input.Debounce = false
				elseif input.InputEventType == "Release" then
					if input.IsActive then
						if input.Debounce == true then
							input.LastInputActive = tick()
						end

						input.Debounce = false
					elseif input.Debounce == false then
						input.OnBeginCallback(tick() - input.LastInputActive, deltaV3)

						input.Debounce = true
					end
					-- input.Debounce = false
				end
			end
		end
	end))

	self._Maid:GiveTask(UserInputService.InputBegan:Connect(function(_, gpe)
		isInGpe = gpe
		deltaV3 = Vector3.new()
	end))
	self._Maid:GiveTask(UserInputService.InputChanged:Connect(function(input, gpe)
		deltaV3 = input.Delta
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			isJoystick1 = true
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			isJoystick2 = true
		end
	end))
	self._Maid:GiveTask(UserInputService.InputEnded:Connect(function(input, gpe)
		isInGpe = gpe
		deltaV3 = Vector3.new()
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			isJoystick1 = false
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			isJoystick2 = false
		end
	end))

	self._Maid:GiveTask(UserInputService.TouchStarted:Connect(function()
		isTouching = true
	end))

	self._Maid:GiveTask(UserInputService.TouchEnded:Connect(function()
		isTouching = false
	end))
end

function manager:RegisterNewInput(
	inputName: string,
	deviceType: Device,
	keys: Key | { [number]: Key },
	inputEventType: InputEventType,
	onCallback: (dt: number, delta: Vector3) -> () -> ()?
)
	assert(not self.RegisteredInputs[inputName], "Name already registered!")

	self.RegisteredInputs[inputName] = createCustomInputObject(
		false,
		false,
		if inputEventType == "Release" or inputEventType == "Hold" then true else false,
		0,
		deviceType,
		if typeof(keys) ~= "table" then { keys } else keys,
		inputEventType,
		onCallback or function(dt: number, delta: Vector3)
			return
		end
	)
end

function manager:ToggleInput(inputName: string, toggle: boolean)
	local customInput = self.RegisteredInputs[inputName]
	assert(customInput, "Bad input name!")

	customInput.Disabled = toggle
end
--function manager:RegisterNewContextInput()

--end

function manager:Destroy()
	self._Maid:Destroy()

	local t = self :: any
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(self, nil)
	return nil
end

return manager
