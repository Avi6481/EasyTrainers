local Logger = require("Core/Logger")

local Input = {}

local s_Handler = nil
local s_LastDevice = "Keyboard"
local s_WarnedMissing = false
local s_NextDeviceCheck = 0

local DEVICE_CHECK_INTERVAL = 0.1

function Input.Initialize()
    s_Handler = EasyInputHandler and EasyInputHandler.new() or nil
    if s_Handler then
        Logger.Log("Input: EasyInputHandler initialized")
        pcall(function() if s_Handler.LogInputDiagnostics then s_Handler:LogInputDiagnostics() end end)
        return
    end

    if not s_WarnedMissing then
        Logger.Log("Input: failed to initialize EasyInputHandler, check the Redscript install")
        s_WarnedMissing = true
    end
end

local function Handler()
    if not s_Handler then Input.Initialize() end
    return s_Handler
end

local function Call(method, fallback, ...)
    local handler = Handler()
    if not handler then return fallback end
    return handler[method](handler, ...)
end

local s_Supported = {}

function Input.Supports(method)
    if s_Supported[method] ~= nil then return s_Supported[method] end
    local handler = Handler()
    if not handler then return false end

    local ok, found = pcall(function() return handler[method] ~= nil end)
    s_Supported[method] = ok and found
    return s_Supported[method]
end

function Input.GetMousePosition()
    if not Input.Supports("GetMouseX") then return nil end
    return Call("GetMouseX", 0), Call("GetMouseY", 0)
end

function Input.IsMouseButtonDown(button)
    if not Input.Supports("IsMouseButtonDown") then return nil end
    return Call("IsMouseButtonDown", false, button)
end

function Input.ConsumeMouseWheel()
    if not Input.Supports("ConsumeMouseWheel") then return 0 end
    return Call("ConsumeMouseWheel", 0)
end

function Input.BeginTextCapture()
    if Input.Supports("BeginTextCapture") then Call("BeginTextCapture", nil) end
end

function Input.EndTextCapture()
    if Input.Supports("EndTextCapture") then Call("EndTextCapture", nil) end
end

function Input.ConsumeTypedText()
    if not Input.Supports("ConsumeTypedText") then return nil end
    return Call("ConsumeTypedText", "")
end

function Input.UpdateDevice()
    local now = os.clock()
    if now < s_NextDeviceCheck then return s_LastDevice end
    s_NextDeviceCheck = now + DEVICE_CHECK_INTERVAL

    if Call("IsKeyboardActive", false) then
        s_LastDevice = "Keyboard"
    elseif Call("IsGamepadActive", false) then
        s_LastDevice = "Controller"
    end
    return s_LastDevice
end

function Input.IsController()
    return s_LastDevice == "Controller"
end

function Input.IsKeyboard()
    return s_LastDevice == "Keyboard"
end

Input.VK = {
    UP = 0x26,
    DOWN = 0x28,
    LEFT = 0x25,
    RIGHT = 0x27,
    ENTER = 0x0D,
    BACKSPACE = 0x08,
    DELETE = 0x2E,
    ESCAPE = 0x1B,
    TAB = 0x09,
    SHIFT = 0x10,
    CTRL = 0x11,
    ALT = 0x12,
    SPACE = 0x20,
    NUMPAD_MULTIPLY = 0x6A,
    NUMPAD_ADD = 0x6B,
    NUMPAD_SUBTRACT = 0x6D,
    NUMPAD_DECIMAL = 0x6E,
    NUMPAD_DIVIDE = 0x6F
}

for i = 0, 9 do Input.VK[tostring(i)] = 0x30 + i end
for c = 65, 90 do Input.VK[string.char(c)] = c end
for i = 1, 24 do Input.VK["F" .. i] = 0x70 + (i - 1) end
for i = 0, 9 do Input.VK["NUMPAD" .. i] = 0x60 + i end

Input.GP = {
    DPAD_UP = 0x0001,
    DPAD_DOWN = 0x0002,
    DPAD_LEFT = 0x0004,
    DPAD_RIGHT = 0x0008,
    START = 0x0010,
    BACK = 0x0020,
    LEFT_STICK = 0x0040,
    RIGHT_STICK = 0x0080,
    LEFT_BUMPER = 0x0100,
    RIGHT_BUMPER = 0x0200,
    LEFT_TRIGGER = 0x0400,
    RIGHT_TRIGGER = 0x0800,
    A = 0x1000,
    B = 0x2000,
    X = 0x4000,
    Y = 0x8000,
    GUIDE = 0x10000,
    TOUCHPAD = 0x20000,
    MISC = 0x40000
}

Input.GP_AXIS = {
    LEFT_X = 0,
    LEFT_Y = 1,
    RIGHT_X = 2,
    RIGHT_Y = 3,
    LEFT_TRIGGER = 4,
    RIGHT_TRIGGER = 5
}

function Input.IsKeyDown(vk)
    return Call("IsKeyPressed", false, vk)
end

function Input.GetPressedKey()
    return Call("GetPressedKey", 0)
end

function Input.IsButtonDown(button)
    return Call("IsGamepadButtonPressed", false, button)
end

function Input.GetPressedButton()
    return Call("GetPressedGamepadButton", 0)
end

Input.GamepadType = {
    None = 0,
    Xbox = 1,
    PlayStation4 = 2,
    PlayStation5 = 3,
    Switch = 4,
    Other = 5
}

function Input.IsGamepadConnected()
    return Call("IsGamepadConnected", false)
end

function Input.GetGamepadType()
    return Call("GetGamepadType", Input.GamepadType.None)
end

function Input.IsPlayStation()
    local gamepadType = Input.GetGamepadType()
    return gamepadType == Input.GamepadType.PlayStation4 or gamepadType == Input.GamepadType.PlayStation5
end

function Input.ShowCursor(enable)
    return Call("ShowCursor", false, enable)
end

function Input.IsCursorVisible()
    return Call("IsCursorVisible", false)
end

function Input.IsLeftStickDirection(direction)
    return Call("IsLeftStickDirection", false, direction)
end

function Input.IsRightStickDirection(direction)
    return Call("IsRightStickDirection", false, direction)
end

function Input.GetGamepadAxis(axis)
    return Call("GetGamepadAxis", 0, axis)
end

function Input.GetLeftTrigger()
    return Call("GetLeftTrigger", 0)
end

function Input.GetRightTrigger()
    return Call("GetRightTrigger", 0)
end

function Input.GetLeftTriggerNormalized()
    return Call("GetLeftTriggerNormalized", 0)
end

function Input.GetRightTriggerNormalized()
    return Call("GetRightTriggerNormalized", 0)
end

function Input.SetVibration(left, right)
    return Call("SetGamepadVibration", false, left, right)
end

return Input
