local Logger = require("Core/Logger")
local Dependencies = require("Core/Dependencies")

local Input = {}

Input.Button = {
    DpadUp = 0x0001,
    DpadDown = 0x0002,
    DpadLeft = 0x0004,
    DpadRight = 0x0008,
    Start = 0x0010,
    Back = 0x0020,
    LeftStick = 0x0040,
    RightStick = 0x0080,
    LeftShoulder = 0x0100,
    RightShoulder = 0x0200,
    LeftTrigger = 0x0400,
    RightTrigger = 0x0800,
    A = 0x1000,
    B = 0x2000,
    X = 0x4000,
    Y = 0x8000,
    Guide = 0x10000,
    Touchpad = 0x20000,
    Misc = 0x40000
}

Input.Axis = {
    LeftX = 0,
    LeftY = 1,
    RightX = 2,
    RightY = 3,
    LeftTrigger = 4,
    RightTrigger = 5
}

Input.Mouse = {
    Left = 0,
    Right = 1,
    Middle = 2
}

Input.Stick = {
    Left = 0,
    Right = 1
}

Input.BlockStatus = {
    Off = 0,
    Keyboard = 1,
    Controller = 2,
    Both = 3
}

Input.VK = {
    LButton = 0x01,
    RButton = 0x02,
    MButton = 0x04,
    Back = 0x08,
    Tab = 0x09,
    Return = 0x0D,
    Shift = 0x10,
    Control = 0x11,
    Menu = 0x12,
    Escape = 0x1B,
    Space = 0x20,
    Left = 0x25,
    Up = 0x26,
    Right = 0x27,
    Down = 0x28,
    Delete = 0x2E,
    A = 0x41,
    B = 0x42,
    D = 0x44,
    S = 0x53,
    W = 0x57,
    Numpad0 = 0x60,
    Numpad2 = 0x62,
    Numpad4 = 0x64,
    Numpad5 = 0x65,
    Numpad6 = 0x66,
    Numpad8 = 0x68,
    F1 = 0x70,
    F2 = 0x71,
    F3 = 0x72,
    F4 = 0x73,
    LShift = 0xA0,
    RShift = 0xA1,
    LControl = 0xA2,
    RControl = 0xA3,
    LMenu = 0xA4,
    RMenu = 0xA5,
    LWin = 0x5B,
    RWin = 0x5C
}

local CHARACTERS = {
    [0x20] = { " ", " " },
    [0x30] = { "0", ")" }, [0x31] = { "1", "!" }, [0x32] = { "2", "@" }, [0x33] = { "3", "#" }, [0x34] = { "4", "$" },
    [0x35] = { "5", "%" }, [0x36] = { "6", "^" }, [0x37] = { "7", "&" }, [0x38] = { "8", "*" }, [0x39] = { "9", "(" },
    [0x60] = { "0", "0" }, [0x61] = { "1", "1" }, [0x62] = { "2", "2" }, [0x63] = { "3", "3" }, [0x64] = { "4", "4" },
    [0x65] = { "5", "5" }, [0x66] = { "6", "6" }, [0x67] = { "7", "7" }, [0x68] = { "8", "8" }, [0x69] = { "9", "9" },
    [0x6A] = { "*", "*" }, [0x6B] = { "+", "+" }, [0x6D] = { "-", "-" }, [0x6E] = { ".", "." }, [0x6F] = { "/", "/" },
    [0xBA] = { ";", ":" }, [0xBB] = { "=", "+" }, [0xBC] = { ",", "<" }, [0xBD] = { "-", "_" }, [0xBE] = { ".", ">" },
    [0xBF] = { "/", "?" }, [0xC0] = { "`", "~" }, [0xDB] = { "[", "{" }, [0xDC] = { "\\", "|" }, [0xDD] = { "]", "}" },
    [0xDE] = { "'", "\"" }
}

for code = 0x41, 0x5A do
    CHARACTERS[code] = { string.char(code + 32), string.char(code) }
end

local BUTTON_LIST = {}
for _, flag in pairs(Input.Button) do table.insert(BUTTON_LIST, flag) end

local STICK_DEADZONE = 7849
local STICK_RANGE = 32767

local s_Handler = nil
local s_Warned = false
local s_Methods = {}

local s_Keys = {}
local s_PrevKeys = {}
local s_Buttons = 0
local s_PrevButtons = 0
local s_StickX, s_StickY = 0, 0
local s_Mouse = {}
local s_PrevMouse = {}

local s_MouseX, s_MouseY = 0, 0
local s_PrevMouseX, s_PrevMouseY = 0, 0
local s_Wheel = 0
local s_Text = ""
local s_Capturing = false
local s_NativeText = false

local s_KeyboardActive = false
local s_ControllerActive = false
local s_ControllerConnected = false
local s_NextDeviceCheck = 0

local function Handler()
    if s_Handler or s_Warned then return s_Handler end
    if not Dependencies.InputHandler() or not Dependencies.Redscript() then
        s_Warned = true
        return nil
    end

    local ok, handler = pcall(function() return EasyInputHandler.new() end)
    if ok and handler then
        s_Handler = handler
    else
        s_Warned = true
        Logger.Error("EasyInputHandler couldn't be created: " .. tostring(handler))
    end
    return s_Handler
end

local function Method(name)
    local method = s_Methods[name]
    if method ~= nil then return method end

    local handler = Handler()
    if not handler then return false end

    local ok, found = pcall(function() return handler[name] end)
    s_Methods[name] = ok and found or false
    return s_Methods[name]
end

local function Supports(name)
    return Method(name) ~= false
end

local function Call(name, fallback, ...)
    local method = Method(name)
    if not method then return fallback end
    return method(s_Handler, ...)
end

function Input.Initialize()
    Handler()
    s_NativeText = Supports("ConsumeTypedText") and Supports("BeginTextCapture")
end

function Input.IsAvailable()
    return Handler() ~= nil
end

local function ReadKey(vk)
    return Call("IsKeyPressed", false, vk) == true
end

local function ReadMouse(button)
    if not Handler() then return ImGui.IsMouseDown(button) end
    if Supports("IsMouseButtonDown") then return Call("IsMouseButtonDown", false, button) == true end
    if button == Input.Mouse.Left then return ReadKey(Input.VK.LButton) end
    if button == Input.Mouse.Right then return ReadKey(Input.VK.RButton) end
    return ReadKey(Input.VK.MButton)
end

local function KeyText(shift)
    local text = ""
    for vk, characters in pairs(CHARACTERS) do
        if s_Keys[vk] and not s_PrevKeys[vk] then text = text .. characters[shift and 2 or 1] end
    end
    return text
end

local function FallbackText()
    local control = s_Keys[Input.VK.Control]
    local text = ""

    if Input.KeyPressed(Input.VK.Back) then text = text .. string.char(control and 127 or 8) end
    if Input.KeyPressed(Input.VK.Return) then text = text .. string.char(13) end
    if Input.KeyPressed(Input.VK.Escape) then text = text .. string.char(27) end

    if control then
        if Input.KeyPressed(0x56) then text = text .. string.char(22) end
        return text
    end

    return text .. KeyText(s_Keys[Input.VK.Shift])
end

local function HasFlag(mask, flag)
    return math.floor(mask / flag) % 2 == 1
end

local function DeadZone(value)
    if math.abs(value) < STICK_DEADZONE then return 0 end
    return value
end

local function UpdateController()
    s_PrevButtons = s_Buttons
    s_Buttons = Call("GetPressedGamepadButton", 0) or 0
    s_StickX = DeadZone(Call("GetGamepadAxis", 0, Input.Axis.LeftX) or 0)
    s_StickY = DeadZone(Call("GetGamepadAxis", 0, Input.Axis.LeftY) or 0)
end

local function UpdateDevice(now)
    if now < s_NextDeviceCheck then return end
    s_NextDeviceCheck = now + 0.1
    s_KeyboardActive = Call("IsKeyboardActive", false) == true
    s_ControllerActive = s_Buttons ~= 0
    s_ControllerConnected = Call("IsGamepadConnected", false) == true
end

function Input.Update(now)
    for vk in pairs(s_Keys) do
        s_PrevKeys[vk] = s_Keys[vk]
        s_Keys[vk] = ReadKey(vk)
    end

    UpdateController()

    for _, button in pairs(Input.Mouse) do
        s_PrevMouse[button] = s_Mouse[button] or false
        s_Mouse[button] = ReadMouse(button)
    end

    s_PrevMouseX, s_PrevMouseY = s_MouseX, s_MouseY
    if Supports("GetMouseX") then
        s_MouseX, s_MouseY = Call("GetMouseX", 0), Call("GetMouseY", 0)
    else
        s_MouseX, s_MouseY = ImGui.GetMousePos()
    end

    s_Wheel = Call("ConsumeMouseWheel", 0) or 0

    s_Text = ""
    if s_Capturing then
        if s_NativeText then
            s_Text = Call("ConsumeTypedText", "") or ""
        else
            s_Text = FallbackText()
        end
    end

    UpdateDevice(now or 0)
end

local function Track(vk)
    if s_Keys[vk] == nil then
        local down = ReadKey(vk)
        s_Keys[vk] = down
        s_PrevKeys[vk] = down
    end
end

function Input.KeyDown(vk)
    Track(vk)
    return s_Keys[vk] == true
end

function Input.KeyPressed(vk)
    Track(vk)
    return s_Keys[vk] == true and not s_PrevKeys[vk]
end

function Input.KeyReleased(vk)
    Track(vk)
    return s_Keys[vk] ~= true and s_PrevKeys[vk] == true
end

function Input.PressedKeys()
    local pressed = Call("GetPressedKeys", nil)
    if type(pressed) ~= "table" then return {} end
    return pressed
end

function Input.KeyName(vk)
    local name = Call("GetKeyName", nil, vk)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

function Input.ButtonDown(button)
    return HasFlag(s_Buttons, button)
end

function Input.ButtonPressed(button)
    return HasFlag(s_Buttons, button) and not HasFlag(s_PrevButtons, button)
end

function Input.ButtonReleased(button)
    return not HasFlag(s_Buttons, button) and HasFlag(s_PrevButtons, button)
end

function Input.ButtonName(button)
    local name = Call("GetGamepadButtonName", nil, button)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

function Input.ButtonList()
    return BUTTON_LIST
end

function Input.LeftStick()
    return s_StickX / STICK_RANGE, s_StickY / STICK_RANGE
end

function Input.AxisValue(axis)
    local value = Call("GetGamepadAxis", 0, axis) or 0
    return math.max(-1, math.min(1, value / 32767))
end

function Input.MouseDown(button)
    return s_Mouse[button] == true
end

function Input.MousePressed(button)
    return s_Mouse[button] == true and not s_PrevMouse[button]
end

function Input.MouseReleased(button)
    return s_Mouse[button] ~= true and s_PrevMouse[button] == true
end

function Input.MousePos()
    return s_MouseX, s_MouseY
end

function Input.MouseMoved()
    return s_MouseX ~= s_PrevMouseX or s_MouseY ~= s_PrevMouseY
end

function Input.MouseWheel()
    return s_Wheel
end

function Input.MouseIn(x, y, w, h)
    return s_MouseX >= x and s_MouseX < x + w and s_MouseY >= y and s_MouseY < y + h
end

function Input.BeginText()
    if s_Capturing then return end
    s_Capturing = true
    if s_NativeText then
        Call("BeginTextCapture", nil)
        Call("ConsumeTypedText", "")
        return
    end

    for vk in pairs(CHARACTERS) do Track(vk) end
    for _, vk in ipairs({ Input.VK.Back, Input.VK.Return, Input.VK.Escape, Input.VK.Shift, Input.VK.Control, 0x56 }) do Track(vk) end
end

function Input.EndText()
    if not s_Capturing then return end
    s_Capturing = false
    if s_NativeText then Call("EndTextCapture", nil) end
end

function Input.TypedText()
    return s_Text
end

function Input.ShowCursor(visible)
    Call("ShowCursor", false, visible == true)
end

function Input.BlockKey(vk)
    Call("BlockKey", nil, vk)
end

function Input.BlockAllKeys()
    Call("BlockAllKeys", nil)
end

function Input.BlockMouseButton(button)
    Call("BlockMouseButton", nil, button)
end

function Input.BlockMouseWheel()
    Call("BlockMouseWheel", nil)
end

function Input.BlockMouseMove()
    Call("BlockMouseMove", nil)
end

function Input.BlockButtons(buttons)
    Call("BlockGamepadButtons", nil, buttons)
end

function Input.BlockStick(stick)
    Call("BlockGamepadStick", nil, stick)
end

function Input.ClearBlocks()
    Call("ClearInputBlocks", nil)
end

function Input.GetBlockStatus()
    return Call("GetInputBlockStatus", Input.BlockStatus.Off) or Input.BlockStatus.Off
end

function Input.KeyboardActive()
    return s_KeyboardActive
end

function Input.ControllerActive()
    return s_ControllerActive
end

function Input.ControllerConnected()
    return s_ControllerConnected
end

return Input
