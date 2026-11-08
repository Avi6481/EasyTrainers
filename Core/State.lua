local Input = require("Core/Input")
local Scale = require("Style/Scale")

local State = {}

State.Devices = {
    Mouse = "Mouse",
    Keyboard = "Keyboard",
    Controller = "Controller"
}

local EDGE_MARGIN = 8

local DEFAULT_TOGGLE = {
    Keys = { Input.VK.F4 },
    Buttons = { Input.Button.RightShoulder, Input.Button.DpadRight }
}

local s_CursorShown = false

function State.Initialize()
    State.Menu = {
        Open = false,
        Cursor = false,
        Typing = false,
        Moving = false,
        Resizing = false,
        X = 100,
        Y = 100,
        Width = 420,
        Height = 600,
        MinWidth = 300,
        MinHeight = 360,
        GrabOffsetX = 0,
        GrabOffsetY = 0
    }

    State.Device = {
        Device = State.Devices.Keyboard,
        UsingMouse = false,
        UsingKeyboard = false,
        UsingController = false,
        ControllerConnected = false,
        Forced = false,
        ForcedDevice = State.Devices.Keyboard
    }

    State.Hotkeys = {
        ToggleMenu = { Keys = { Input.VK.F4 }, Buttons = { Input.Button.RightShoulder, Input.Button.DpadRight } }
    }

    State.Time = { Delta = 0, Time = 0, Frame = 0 }
    State.OverlayOpen = false
    State.PopupCursor = false
end

State.Initialize()

local function MouseUsed()
    if State.Menu.Cursor and Input.MouseMoved() then return true end
    if Input.MouseWheel() ~= 0 then return true end
    return Input.MousePressed(Input.Mouse.Left) or Input.MousePressed(Input.Mouse.Right)
end

local function UpdateDevice()
    local device = State.Device
    device.ControllerConnected = Input.ControllerConnected()
    device.UsingMouse = MouseUsed()
    device.UsingKeyboard = Input.KeyboardActive()
    device.UsingController = Input.ControllerActive()

    if device.Forced then
        device.Device = device.ForcedDevice
    elseif device.UsingController then
        device.Device = State.Devices.Controller
    elseif device.UsingKeyboard then
        device.Device = State.Devices.Keyboard
    elseif device.UsingMouse then
        device.Device = State.Devices.Mouse
    end
end

function State.ToggleBinding()
    local binding = State.Hotkeys.ToggleMenu
    if type(binding) ~= "table" or type(binding.Keys) ~= "table" or type(binding.Buttons) ~= "table" then return DEFAULT_TOGGLE end
    if #binding.Keys == 0 and #binding.Buttons == 0 then return DEFAULT_TOGGLE end
    return binding
end

local function ComboPressed(codes, down, pressed)
    if #codes == 0 then return false end

    local fresh = false
    for _, code in ipairs(codes) do
        if not down(code) then return false end
        if pressed(code) then fresh = true end
    end
    return fresh
end

function State.BindingPressed(binding)
    if type(binding) ~= "table" or type(binding.Keys) ~= "table" or type(binding.Buttons) ~= "table" then return false end
    return ComboPressed(binding.Keys, Input.KeyDown, Input.KeyPressed)
        or ComboPressed(binding.Buttons, Input.ButtonDown, Input.ButtonPressed)
end

local function TogglePressed()
    if State.Menu.Typing then return false end
    return State.BindingPressed(State.ToggleBinding())
end

function State.ClampToScreen()
    local screenWidth, screenHeight = GetDisplayResolution()
    if not screenWidth or screenWidth <= 0 or screenHeight <= 0 then return end

    local menu = State.Menu
    local minWidth = Scale.S(menu.MinWidth)
    local minHeight = Scale.S(menu.MinHeight)
    local maxWidth = math.max(minWidth, screenWidth - (EDGE_MARGIN * 2))
    local maxHeight = math.max(minHeight, screenHeight - (EDGE_MARGIN * 2))

    menu.Width = math.max(minWidth, math.min(maxWidth, menu.Width))
    menu.Height = math.max(minHeight, math.min(maxHeight, menu.Height))
    menu.X = math.max(EDGE_MARGIN, math.min(math.max(EDGE_MARGIN, screenWidth - menu.Width - EDGE_MARGIN), menu.X))
    menu.Y = math.max(EDGE_MARGIN, math.min(math.max(EDGE_MARGIN, screenHeight - menu.Height - EDGE_MARGIN), menu.Y))
end

function State.Rescale(ratio)
    local menu = State.Menu
    menu.X = menu.X * ratio
    menu.Y = menu.Y * ratio
    menu.Width = menu.Width * ratio
    menu.Height = menu.Height * ratio
end

local function SyncCursor()
    local visible = ((State.Menu.Open and State.Menu.Cursor) or State.PopupCursor) and not State.OverlayOpen
    if visible == s_CursorShown then return end
    s_CursorShown = visible
    Input.ShowCursor(visible)
end

function State.Update(delta)
    State.Time.Delta = delta
    State.Time.Time = State.Time.Time + delta
    State.Time.Frame = State.Time.Frame + 1

    if not Input.IsAvailable() then
        State.Menu.Open = State.OverlayOpen
        State.Menu.Cursor = State.OverlayOpen
        State.Device.Device = State.Devices.Mouse
    else
        UpdateDevice()
        if TogglePressed() then State.Toggle() end
    end

    if not Input.MouseDown(Input.Mouse.Left) then
        State.Menu.Moving = false
        State.Menu.Resizing = false
    end

    State.ClampToScreen()
    SyncCursor()
end

function State.Open()
    State.Menu.Open = true
end

function State.Close()
    State.Menu.Open = false
    State.Menu.Moving = false
    State.Menu.Resizing = false
end

function State.Toggle()
    if State.Menu.Open then
        State.Close()
        return
    end
    State.Open()
end

function State.SetTyping(typing)
    State.Menu.Typing = typing == true
end

function State.IsTyping()
    return State.Menu.Typing
end

function State.SetCursor(enabled)
    State.Menu.Cursor = enabled == true
    if enabled then return end
    State.Menu.Moving = false
    State.Menu.Resizing = false
end

function State.IsBusy()
    return State.Menu.Moving or State.Menu.Resizing
end

local function StartDrag(x, y, w, h)
    return Input.MousePressed(Input.Mouse.Left) and Input.MouseIn(x, y, w, h)
end

function State.UpdateMove(x, y, w, h)
    local menu = State.Menu
    if not menu.Open or not menu.Cursor or menu.Resizing then return end

    local mouseX, mouseY = Input.MousePos()
    if not menu.Moving and StartDrag(x, y, w, h) then
        menu.Moving = true
        menu.GrabOffsetX = mouseX - menu.X
        menu.GrabOffsetY = mouseY - menu.Y
    end

    if not menu.Moving then return end
    menu.X = mouseX - menu.GrabOffsetX
    menu.Y = mouseY - menu.GrabOffsetY
    State.ClampToScreen()
end

function State.UpdateResize(x, y, w, h)
    local menu = State.Menu
    if not menu.Open or not menu.Cursor or menu.Moving then return end

    local mouseX, mouseY = Input.MousePos()
    if not menu.Resizing and StartDrag(x, y, w, h) then
        menu.Resizing = true
        menu.GrabOffsetX = (menu.X + menu.Width) - mouseX
        menu.GrabOffsetY = (menu.Y + menu.Height) - mouseY
    end

    if not menu.Resizing then return end
    menu.Width = (mouseX + menu.GrabOffsetX) - menu.X
    menu.Height = (mouseY + menu.GrabOffsetY) - menu.Y
    State.ClampToScreen()
end

function State.Shutdown()
    if s_CursorShown then Input.ShowCursor(false) end
    s_CursorShown = false
end

return State
