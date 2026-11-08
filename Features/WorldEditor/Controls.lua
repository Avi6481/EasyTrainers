local Input = require("Core/Input")
local State = require("Core/State")
local KeyBind = require("Widgets/KeyBind/KeyBind")

local Controls = {
    Binds = {}
}

local VK_C = 0x43
local VK_E = 0x45
local VK_F = 0x46
local VK_G = 0x47
local VK_H = 0x48
local VK_Q = 0x51
local VK_R = 0x52
local VK_T = 0x54
local VK_V = 0x56
local VK_X = 0x58
local VK_Y = 0x59
local VK_Z = 0x5A
local VK_1 = 0x31
local VK_2 = 0x32
local VK_3 = 0x33

Controls.Actions = {
    "Forward", "Back", "Left", "Right", "Up", "Down", "Fast", "Slow",
    "Select", "Context", "Rotate", "Ground", "NudgeForward", "NudgeBack", "NudgeLeft", "NudgeRight",
    "Copy", "Cut", "Paste", "Delete", "Detach", "Undo", "Redo"
}

Controls.Groups = {
    { Key = "camera", Actions = { "Forward", "Back", "Left", "Right", "Up", "Down", "Fast", "Slow" } },
    { Key = "editing", Actions = { "Select", "Context", "Rotate", "Ground", "NudgeForward", "NudgeBack", "NudgeLeft", "NudgeRight" } },
    { Key = "shortcuts", Actions = { "Copy", "Cut", "Paste", "Delete", "Detach", "Undo", "Redo" } }
}

Controls.Paused = false

local DEFAULTS = {
    Forward = { Keys = { Input.VK.W }, Buttons = {} },
    Back = { Keys = { Input.VK.S }, Buttons = {} },
    Left = { Keys = { Input.VK.A }, Buttons = {} },
    Right = { Keys = { Input.VK.D }, Buttons = {} },
    Up = { Keys = { VK_E }, Buttons = { Input.Button.RightShoulder } },
    Down = { Keys = { VK_Q }, Buttons = { Input.Button.LeftShoulder } },
    Fast = { Keys = { Input.VK.Shift }, Buttons = { Input.Button.LeftStick } },
    Slow = { Keys = { Input.VK.Menu }, Buttons = { Input.Button.RightStick } },
    Select = { Keys = { Input.VK.LButton }, Buttons = { Input.Button.RightTrigger } },
    Context = { Keys = { Input.VK.Control, Input.VK.LButton }, Buttons = { Input.Button.Y } },
    Rotate = { Keys = { Input.VK.RButton }, Buttons = { Input.Button.LeftTrigger } },
    Ground = { Keys = { Input.VK.Space }, Buttons = { Input.Button.X } },
    NudgeForward = { Keys = { Input.VK.Up }, Buttons = { Input.Button.DpadUp } },
    NudgeBack = { Keys = { Input.VK.Down }, Buttons = { Input.Button.DpadDown } },
    NudgeLeft = { Keys = { Input.VK.Left }, Buttons = { Input.Button.DpadLeft } },
    NudgeRight = { Keys = { Input.VK.Right }, Buttons = { Input.Button.DpadRight } },
    Copy = { Keys = { Input.VK.Control, VK_C }, Buttons = {} },
    Cut = { Keys = { Input.VK.Control, VK_X }, Buttons = {} },
    Paste = { Keys = { Input.VK.Control, VK_V }, Buttons = {} },
    Delete = { Keys = { Input.VK.Delete }, Buttons = {} },
    Detach = { Keys = { Input.VK.Back }, Buttons = {} },
    Undo = { Keys = { Input.VK.Control, VK_Z }, Buttons = {} },
    Redo = { Keys = { Input.VK.Control, VK_Y }, Buttons = {} }
}

local ALWAYS_KEYS = { VK_F, VK_R, Input.VK.Tab, VK_T, VK_G, VK_H, VK_1, VK_2, VK_3 }
local ALWAYS_BUTTONS = { Input.Button.A, Input.Button.B, Input.Button.X, Input.Button.Y }
local POPUP_KEYS = { Input.VK.Escape, Input.VK.Return }

local SIDES = {
    [Input.VK.Shift] = { Input.VK.LShift, Input.VK.RShift },
    [Input.VK.Control] = { Input.VK.LControl, Input.VK.RControl },
    [Input.VK.Menu] = { Input.VK.LMenu, Input.VK.RMenu }
}

local MOUSE_KEYS = {
    [Input.VK.LButton] = Input.Mouse.Left,
    [Input.VK.RButton] = Input.Mouse.Right,
    [Input.VK.MButton] = Input.Mouse.Middle
}

local MOUSE_NAMES = {
    [Input.VK.LButton] = "worldeditor.hud.keys.click",
    [Input.VK.RButton] = "worldeditor.hud.keys.rightclick",
    [Input.VK.MButton] = "worldeditor.hud.keys.middleclick"
}

local s_Held = {}
local s_Pressed = {}
local s_Spec = nil
local s_PopupSpec = nil

local function Copy(binding)
    local copy = { Keys = {}, Buttons = {} }
    for index, key in ipairs(binding.Keys) do copy.Keys[index] = key end
    for index, button in ipairs(binding.Buttons) do copy.Buttons[index] = button end
    return copy
end

local function Valid(binding)
    return type(binding) == "table" and type(binding.Keys) == "table" and type(binding.Buttons) == "table"
end

function Controls.Fill()
    if type(Controls.Binds) ~= "table" then Controls.Binds = {} end
    for action in pairs(Controls.Binds) do
        if not DEFAULTS[action] then Controls.Binds[action] = nil end
    end
    for _, action in ipairs(Controls.Actions) do
        if not Valid(Controls.Binds[action]) then Controls.Binds[action] = Copy(DEFAULTS[action]) end
    end
    s_Spec = nil
end

function Controls.Reset()
    for _, action in ipairs(Controls.Actions) do Controls.Binds[action] = Copy(DEFAULTS[action]) end
    s_Spec = nil
end

function Controls.Changed()
    s_Spec = nil
end

Controls.Fill()

local function KeyDown(vk)
    if MOUSE_KEYS[vk] then return Input.MouseDown(MOUSE_KEYS[vk]) end
    return Input.KeyDown(vk)
end

local function Down(codes, check)
    if #codes == 0 then return false end
    for _, code in ipairs(codes) do
        if not check(code) then return false end
    end
    return true
end

function Controls.Blocked()
    return Controls.Paused or State.OverlayOpen or State.Menu.Typing or KeyBind.IsCapturing()
end

function Controls.Update()
    local blocked = Controls.Blocked()
    for _, action in ipairs(Controls.Actions) do
        local binding = Controls.Binds[action]
        local held = not blocked and (Down(binding.Keys, KeyDown) or Down(binding.Buttons, Input.ButtonDown))
        s_Pressed[action] = held and not s_Held[action]
        s_Held[action] = held
    end
end

function Controls.Held(action)
    return s_Held[action] == true
end

function Controls.Pressed(action)
    return s_Pressed[action] == true
end

function Controls.Clear()
    s_Held = {}
    s_Pressed = {}
end

function Controls.Binding(action)
    return Controls.Binds[action] or DEFAULTS[action]
end

local function KeyName(vk)
    if MOUSE_NAMES[vk] then return L(MOUSE_NAMES[vk]) end
    return KeyBind.KeyName(vk)
end

function Controls.KeyText(action)
    local binding = Controls.Binding(action)
    if #binding.Keys == 0 then return nil end
    local parts = {}
    for _, vk in ipairs(binding.Keys) do table.insert(parts, KeyName(vk)) end
    return table.concat(parts, "+")
end

function Controls.PadText(action)
    local binding = Controls.Binding(action)
    if #binding.Buttons == 0 then return nil end
    local parts = {}
    for _, flag in ipairs(binding.Buttons) do table.insert(parts, KeyBind.ButtonName(flag)) end
    return table.concat(parts, " + ")
end

function Controls.Text(action, controller)
    if controller then return Controls.PadText(action) or "?" end
    return Controls.KeyText(action) or "?"
end

local function BuildSpec(popup)
    local keys, seenKeys = {}, {}
    local mouse, seenMouse = {}, {}
    local buttons, seenButtons = 0, {}

    local function AddKey(vk)
        if seenKeys[vk] or seenMouse[vk] then return end
        if MOUSE_KEYS[vk] then
            seenMouse[vk] = true
            table.insert(mouse, MOUSE_KEYS[vk])
            return
        end
        seenKeys[vk] = true
        table.insert(keys, vk)
        for _, side in ipairs(SIDES[vk] or {}) do AddKey(side) end
    end

    local function AddButton(flag)
        if seenButtons[flag] then return end
        seenButtons[flag] = true
        buttons = buttons + flag
    end

    for _, vk in ipairs(ALWAYS_KEYS) do AddKey(vk) end
    for _, flag in ipairs(ALWAYS_BUTTONS) do AddButton(flag) end
    for _, action in ipairs(Controls.Actions) do
        local binding = Controls.Binds[action]
        for _, vk in ipairs(binding.Keys) do AddKey(vk) end
        for _, flag in ipairs(binding.Buttons) do AddButton(flag) end
    end
    if popup then
        for _, vk in ipairs(POPUP_KEYS) do AddKey(vk) end
    end

    return { Keys = keys, Buttons = buttons, Sticks = { Input.Stick.Left, Input.Stick.Right }, Wheel = true, Mouse = mouse, MouseMove = popup }
end

function Controls.BlockSpec(popup)
    if not s_Spec then
        s_Spec = BuildSpec(false)
        s_PopupSpec = BuildSpec(true)
    end
    return popup and s_PopupSpec or s_Spec
end

return Controls
