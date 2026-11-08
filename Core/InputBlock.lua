local Input = require("Core/Input")
local State = require("Core/State")
local NavigationStyle = require("Navigation/NavigationStyle")
local Sheet = require("Panels/Sheet/Sheet")

local InputBlock = {
    Enabled = true,
    Extra = {
        Movement = false,
        MouseLook = false,
        MouseButtons = false,
        LeftStick = false,
        RightStick = false,
        FaceButtons = false,
        Bumpers = false,
        Triggers = false
    }
}

local VK_C = 0x43

InputBlock.Extras = {
    {
        Id = "Movement",
        Group = "keyboard",
        Keys = {
            Input.VK.W, Input.VK.A, Input.VK.S, Input.VK.D, Input.VK.Space, VK_C,
            Input.VK.Shift, Input.VK.LShift, Input.VK.RShift, Input.VK.Control, Input.VK.LControl, Input.VK.RControl
        }
    },
    { Id = "MouseLook", Group = "mouse", MouseMove = true },
    { Id = "MouseButtons", Group = "mouse", Mouse = { Input.Mouse.Left, Input.Mouse.Right } },
    { Id = "LeftStick", Group = "controller", Sticks = { Input.Stick.Left } },
    { Id = "RightStick", Group = "controller", Sticks = { Input.Stick.Right } },
    { Id = "FaceButtons", Group = "controller", Buttons = Input.Button.X + Input.Button.Y },
    { Id = "Bumpers", Group = "controller", Buttons = Input.Button.LeftShoulder + Input.Button.RightShoulder },
    { Id = "Triggers", Group = "controller", Buttons = Input.Button.LeftTrigger + Input.Button.RightTrigger }
}

local MENU_KEYS = {
    Input.VK.Up, Input.VK.Down, Input.VK.Left, Input.VK.Right,
    Input.VK.Numpad8, Input.VK.Numpad2, Input.VK.Numpad4, Input.VK.Numpad6, Input.VK.Numpad5, Input.VK.Numpad0,
    Input.VK.Return, Input.VK.Back, Input.VK.Delete
}

local MODIFIERS = {
    [Input.VK.Shift] = true, [Input.VK.Control] = true, [Input.VK.Menu] = true,
    [Input.VK.LShift] = true, [Input.VK.RShift] = true, [Input.VK.LControl] = true,
    [Input.VK.RControl] = true, [Input.VK.LMenu] = true, [Input.VK.RMenu] = true
}

local MENU_BUTTON_LIST = {
    Input.Button.DpadUp, Input.Button.DpadDown, Input.Button.DpadLeft, Input.Button.DpadRight,
    Input.Button.A, Input.Button.B, NavigationStyle.BindButton
}

local MENU_BUTTONS = 0
local MENU_KEY_SET = {}
local MENU_BUTTON_SET = {}

for _, vk in ipairs(MENU_KEYS) do MENU_KEY_SET[vk] = true end
for _, flag in ipairs(MENU_BUTTON_LIST) do
    MENU_BUTTONS = MENU_BUTTONS + flag
    MENU_BUTTON_SET[flag] = true
end

local ALL_BUTTONS = 0xFFFF
local REFRESH_INTERVAL = 0.1

local s_Active = false
local s_Mode = nil
local s_NextRefresh = 0
local s_Holds = {}
local s_HoldsChanged = false

function InputBlock.Hold(owner, spec)
    if s_Holds[owner] == spec then return end
    s_Holds[owner] = spec
    s_HoldsChanged = true
end

function InputBlock.Release(owner)
    if not s_Holds[owner] then return end
    s_Holds[owner] = nil
    s_HoldsChanged = true
end

function InputBlock.Holds()
    local owners = {}
    for owner in pairs(s_Holds) do table.insert(owners, owner) end
    table.sort(owners)
    return owners
end

function InputBlock.Describe(owner)
    local spec = s_Holds[owner]
    if not spec then return nil end

    local buttons = 0
    local remaining = spec.Buttons or 0
    while remaining > 0 do
        buttons = buttons + (remaining % 2)
        remaining = math.floor(remaining / 2)
    end

    return {
        Keys = #(spec.Keys or {}),
        Buttons = buttons,
        Sticks = #(spec.Sticks or {}),
        Mouse = #(spec.Mouse or {}) + (spec.Wheel and 1 or 0) + (spec.MouseMove and 1 or 0)
    }
end

function InputBlock.IsMenuKey(vk)
    return MENU_KEY_SET[vk] == true or vk == NavigationStyle.EditKey or vk == NavigationStyle.CursorToggleKey
        or vk == NavigationStyle.BindKey
end

function InputBlock.IsMenuButton(flag)
    return MENU_BUTTON_SET[flag] == true
end

function InputBlock.ExtraIds()
    local ids = {}
    for _, extra in ipairs(InputBlock.Extras) do table.insert(ids, extra.Id) end
    return ids
end

function InputBlock.ResetExtras()
    for _, extra in ipairs(InputBlock.Extras) do InputBlock.Extra[extra.Id] = false end
end

local function BlockToggle()
    local binding = State.ToggleBinding()
    for _, vk in ipairs(binding.Keys) do
        if not MODIFIERS[vk] then Input.BlockKey(vk) end
    end

    local buttons = 0
    for _, flag in ipairs(binding.Buttons) do buttons = buttons + flag end
    if buttons > 0 then Input.BlockButtons(buttons) end
end

local function BlockKeys()
    if State.Menu.Typing then
        Input.BlockAllKeys()
        return
    end

    for _, vk in ipairs(MENU_KEYS) do Input.BlockKey(vk) end
    Input.BlockKey(NavigationStyle.EditKey)
    Input.BlockKey(NavigationStyle.CursorToggleKey)
    Input.BlockKey(NavigationStyle.BindKey)
    if Sheet.SheetOpen() then Input.BlockKey(Input.VK.Escape) end
end

local function BlockController()
    if State.Menu.Typing then
        Input.BlockButtons(ALL_BUTTONS)
        Input.BlockStick(Input.Stick.Left)
        Input.BlockStick(Input.Stick.Right)
        return
    end

    Input.BlockButtons(MENU_BUTTONS)
end

local function BlockMouse()
    local cursor = State.Menu.Cursor
    if NavigationStyle.MouseWheelNavigation then Input.BlockMouseWheel() end
    if cursor or NavigationStyle.CursorlessClicks then Input.BlockMouseButton(Input.Mouse.Left) end
    if cursor or NavigationStyle.RightClickBack then Input.BlockMouseButton(Input.Mouse.Right) end
    if cursor then Input.BlockMouseMove() end
end

local function BlockSpec(spec)
    for _, vk in ipairs(spec.Keys or {}) do Input.BlockKey(vk) end
    if spec.Buttons and spec.Buttons > 0 then Input.BlockButtons(spec.Buttons) end
    for _, stick in ipairs(spec.Sticks or {}) do Input.BlockStick(stick) end
    for _, button in ipairs(spec.Mouse or {}) do Input.BlockMouseButton(button) end
    if spec.Wheel then Input.BlockMouseWheel() end
    if spec.MouseMove then Input.BlockMouseMove() end
end

local function BlockHolds()
    for _, spec in pairs(s_Holds) do BlockSpec(spec) end
end

local function BlockExtras()
    for _, extra in ipairs(InputBlock.Extras) do
        if InputBlock.Extra[extra.Id] then BlockSpec(extra) end
    end
end

local function ExtraMask()
    local mask = 0
    local bit = 1
    for _, extra in ipairs(InputBlock.Extras) do
        if InputBlock.Extra[extra.Id] then mask = mask + bit end
        bit = bit * 2
    end
    return mask
end

local function Mode(menuOpen)
    if not menuOpen then return 0 end

    local menu = State.Menu
    return 1 + (menu.Typing and 2 or 0) + (menu.Cursor and 4 or 0) + (Sheet.SheetOpen() and 8 or 0) + (ExtraMask() * 16)
end

local function Clear()
    if s_Active then Input.ClearBlocks() end
    s_Active = false
    s_Mode = nil
end

function InputBlock.Update()
    local available = not State.OverlayOpen and Input.IsAvailable()
    local menuOpen = available and InputBlock.Enabled and State.Menu.Open
    local holding = available and next(s_Holds) ~= nil
    if not menuOpen and not holding then
        Clear()
        s_HoldsChanged = false
        return
    end

    local mode = Mode(menuOpen)
    local now = os.clock()
    if mode == s_Mode and not s_HoldsChanged and now < s_NextRefresh then return end

    if mode ~= s_Mode or s_HoldsChanged then Clear() end
    s_Active = true
    s_Mode = mode
    s_HoldsChanged = false
    s_NextRefresh = now + REFRESH_INTERVAL

    if menuOpen then
        BlockKeys()
        BlockController()
        BlockToggle()
        BlockMouse()
        BlockExtras()
    end
    BlockHolds()
end

function InputBlock.Shutdown()
    s_Holds = {}
    Clear()
end

return InputBlock
