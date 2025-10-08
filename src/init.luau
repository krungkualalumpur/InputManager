--!strict
--services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
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
	Keys: { Key },
	InputEventType: InputEventType,
	OnBeginCallback: () -> (() -> ())?,
}
export type Key = Enum.KeyCode | Enum.UserInputType | "Touch"
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
		onCallback: () -> () -> ()
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
--local functions
--class
local manager: InputManager = {} :: any
manager.__index = manager

function createCustomInputObject(
	disabled: boolean,
	isActive: boolean,
	keys: { Enum.KeyCode | Enum.UserInputType },
	inputEventType: InputEventType,
	onBeginCallback: () -> (() -> ())?
): CustomInputObject
	return {
		Disabled = disabled,
		IsActive = isActive,
		Keys = keys,
		InputEventType = inputEventType,
		OnBeginCallback = onBeginCallback,
	}
end

manager.RegisteredInputs = {} :: { [string]: CustomInputObject }

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

	self:Start()

	return self
end

function manager:Start()
	local db = false
	local isTouching = false
	local isInGpe = false
	--local isPressingAll = false
	local pressedInputsInOrder: { [number]: { CustomInput: Key, Timestamp: number, IsPressing: boolean } } = {}

	local function getPressedInputInfo(
		customInput: Enum.KeyCode | Enum.UserInputType | "Touch"
	): { CustomInput: Key, Timestamp: number, IsPressing: boolean }?
		for _, v in pairs(pressedInputsInOrder) do
			if customInput == v.CustomInput then
				return v
			end
		end
		return nil
	end

	self._Maid:GiveTask(RunService.Heartbeat:Connect(function()
		for _, input in pairs(manager.RegisteredInputs) do
			local _isPressingAll = not isInGpe and #input.Keys > 0

			for _, key: Key in pairs(input.Keys :: any) do
				local pressedInputInfo = getPressedInputInfo(key)

				if
					typeof(key) == "EnumItem"
					and (
						(key:IsA("KeyCode") and not UserInputService:IsKeyDown(key))
						or (key:IsA("UserInputType") and not UserInputService:IsMouseButtonPressed(key))
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
					if v.IsPressing then
						table.insert(filteredActives, v)
					end
				end

				table.sort(filteredActives, function(a, b)
					return a.Timestamp < b.Timestamp
				end)

				for k, v in pairs(filteredActives) do
					local isPressed = false

					for k2, v2 in pairs(input.Keys) do
						if (k == k2) and v.CustomInput == v2 then
							isPressed = true
							break
						end
					end

					if isPressed == false then
						_isPressingAll = false
						break
					end
				end

				if _isPressingAll == true then
					input.IsActive = _isPressingAll
				end
			end

			if input.Disabled == false and input.IsActive then
				if input.InputEventType == "Toggle" then
					input.IsActive = false
					if db == false then
						db = true
						input.OnBeginCallback()
					end
					if _isPressingAll == false then
						db = false
					end
				elseif input.InputEventType == "Hold" then
					local cleanup = input.OnBeginCallback()

					if not _isPressingAll then
						input.IsActive = false
						if cleanup then
							cleanup()
						end
					end
					db = false
				elseif input.InputEventType == "Release" then
					if input.IsActive == true and _isPressingAll == false then
						input.IsActive = false

						input.OnBeginCallback()
					end
					db = false
				end
			else
				db = false
			end
		end
	end))

	self._Maid:GiveTask(UserInputService.InputBegan:Connect(function(_, gpe)
		isInGpe = gpe
	end))
	self._Maid:GiveTask(UserInputService.InputEnded:Connect(function(_, gpe)
		isInGpe = gpe
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
	platformType: Device,
	keys: Key | { [number]: Key },
	inputEventType: InputEventType,
	onCallback: () -> () -> ()?
)
	assert(not self.RegisteredInputs[inputName], "Name already registered!")

	self.RegisteredInputs[inputName] = createCustomInputObject(
		false,
		false,
		if typeof(keys) ~= "table" then { keys } else keys,
		inputEventType,
		onCallback or function()
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
