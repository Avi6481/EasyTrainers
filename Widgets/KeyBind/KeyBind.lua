local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local Toggle = require("Widgets/Toggle/Toggle")
local SliderStyle = require("Widgets/Slider/SliderStyle")

local KeyBind = {
    Style = {}
}

local FIRST_KEY = 0x03
local LAST_KEY = 0xFE
local ICON_SCALE = 0.62
local SEPARATOR = "|"

local KEY_NAMES = {
    [0x11] = "Ctrl", [0x10] = "Shift", [0x12] = "Alt",
    [0x26] = "Up", [0x28] = "Down", [0x25] = "Left", [0x27] = "Right",
    [0x0D] = "Enter", [0x1B] = "Esc", [0x08] = "Backspace", [0x20] = "Space", [0x09] = "Tab",
    [0x2E] = "Del", [0x2D] = "Ins", [0x24] = "Home", [0x23] = "End", [0x21] = "Page Up", [0x22] = "Page Down",
    [0x04] = "Middle Mouse", [0x05] = "Mouse 4", [0x06] = "Mouse 5"
}

local FALLBACK_NAMES = {
    [0x03] = "Break", [0x0C] = "Clear", [0x13] = "Pause", [0x14] = "Caps Lock", [0x2C] = "Print Screen", [0x5D] = "Menu",
    [0x6A] = "Num *", [0x6B] = "Num +", [0x6D] = "Num -", [0x6E] = "Num .", [0x6F] = "Num /",
    [0x90] = "Num Lock", [0x91] = "Scroll Lock",
    [0xBA] = ";", [0xBB] = "=", [0xBC] = ",", [0xBD] = "-", [0xBE] = ".", [0xBF] = "/",
    [0xC0] = "`", [0xDB] = "[", [0xDC] = "\\", [0xDD] = "]", [0xDE] = "'"
}

for code = 0x30, 0x39 do FALLBACK_NAMES[code] = string.char(code) end
for code = 0x41, 0x5A do FALLBACK_NAMES[code] = string.char(code) end

local BUTTONS = {
    { Flag = Input.Button.A, Name = "A" },
    { Flag = Input.Button.B, Name = "B" },
    { Flag = Input.Button.X, Name = "X" },
    { Flag = Input.Button.Y, Name = "Y" },
    { Flag = Input.Button.Back, Name = "View" },
    { Flag = Input.Button.Guide, Name = "Guide" },
    { Flag = Input.Button.Start, Name = "Menu" },
    { Flag = Input.Button.LeftStick, Name = "LS" },
    { Flag = Input.Button.RightStick, Name = "RS" },
    { Flag = Input.Button.LeftShoulder, Name = "LB" },
    { Flag = Input.Button.RightShoulder, Name = "RB" },
    { Flag = Input.Button.DpadUp, Name = "D-Pad Up" },
    { Flag = Input.Button.DpadDown, Name = "D-Pad Down" },
    { Flag = Input.Button.DpadLeft, Name = "D-Pad Left" },
    { Flag = Input.Button.DpadRight, Name = "D-Pad Right" },
    { Flag = Input.Button.LeftTrigger, Name = "LT" },
    { Flag = Input.Button.RightTrigger, Name = "RT" },
    { Flag = Input.Button.Touchpad, Name = "Touchpad" },
    { Flag = Input.Button.Misc, Name = "Share" }
}

local BUTTON_NAMES = {}
local BUTTON_ORDER = {}

for index, button in ipairs(BUTTONS) do
    BUTTON_NAMES[button.Flag] = button.Name
    BUTTON_ORDER[button.Flag] = index
end

KeyBind.Results = {
    Bound = "Bound",
    ClearedKeys = "ClearedKeys",
    ClearedButtons = "ClearedButtons",
    Cancelled = "Cancelled",
    TimedOut = "TimedOut"
}

local s_Capture = {}
local s_KeyNames = {}

function KeyBind.InitializeStyle()
    local style = KeyBind.Style
    style.Countdown = 3
    style.Timeout = 10

    style.KeyScale = 0.8
    style.KeyPaddingX = 5
    style.KeyPaddingY = 2
    style.KeyRounding = 4
    style.KeyGap = 4
end

KeyBind.InitializeStyle()

local function Skipped(key)
    if key == Input.VK.LButton or key == Input.VK.RButton or key == Input.VK.LWin or key == Input.VK.RWin then return true end
    return key >= Input.VK.LShift and key <= Input.VK.RMenu
end

function KeyBind.KeyName(vk)
    if vk >= 0x70 and vk <= 0x87 then return string.format("F%d", vk - 0x6F) end
    if vk >= 0x60 and vk <= 0x69 then return string.format("Num %d", vk - 0x60) end
    if KEY_NAMES[vk] then return KEY_NAMES[vk] end

    if s_KeyNames[vk] == nil then s_KeyNames[vk] = Input.KeyName(vk) or false end
    if s_KeyNames[vk] then return s_KeyNames[vk] end

    return FALLBACK_NAMES[vk] or string.format("Key %d", vk)
end

function KeyBind.ButtonName(flag)
    return BUTTON_NAMES[flag] or "?"
end

local function Join(codes, name)
    local parts = {}
    for _, code in ipairs(codes or {}) do table.insert(parts, name(code)) end
    return table.concat(parts, " + ")
end

function KeyBind.FormatBinding(binding)
    local keys = Join(binding.Keys, KeyBind.KeyName)
    local buttons = Join(binding.Buttons, KeyBind.ButtonName)

    if keys ~= "" and buttons ~= "" then return keys .. " | " .. buttons end
    if keys == "" and buttons == "" then return "None" end
    return keys == "" and buttons or keys
end

function KeyBind.IsCapturing()
    return s_Capture.Id ~= nil
end

function KeyBind.CaptureId()
    return s_Capture.Id
end

local function StopCapture()
    s_Capture = {}
    Navigation.State.Editing = false
    State.SetTyping(false)
end

KeyBind.Cancel = StopCapture

local function StartCapture(id)
    s_Capture = {
        Id = id,
        Start = State.Time.Time,
        HeldKeys = {},
        HeldButtons = {},
        IgnoredKeys = {},
        IgnoredButtons = {},
        Armed = false,
        WasAnyDown = false,
        Clear = 0
    }

    Navigation.State.Editing = true
    State.SetTyping(true)
end

KeyBind.Begin = StartCapture

local function DownKeys()
    local down = {}
    for _, key in ipairs(Input.PressedKeys()) do
        local code = tonumber(key)
        if code and code >= FIRST_KEY and code <= LAST_KEY and not Skipped(code) then down[code] = true end
    end
    return down
end

local function SnapshotHeld(down)
    for key in pairs(down) do s_Capture.IgnoredKeys[key] = true end

    for _, flag in ipairs(Input.ButtonList()) do
        if Input.ButtonDown(flag) then s_Capture.IgnoredButtons[flag] = true end
    end
end

local function Track(held, ignored, code, down)
    if ignored[code] then
        if not down then ignored[code] = nil end
        return
    end

    if down then held[code] = true end
end

local function TrackHeld(down)
    local capture = s_Capture

    for key in pairs(capture.IgnoredKeys) do
        if not down[key] then Track(capture.HeldKeys, capture.IgnoredKeys, key, false) end
    end

    for key in pairs(down) do Track(capture.HeldKeys, capture.IgnoredKeys, key, true) end

    for _, flag in ipairs(Input.ButtonList()) do
        Track(capture.HeldButtons, capture.IgnoredButtons, flag, Input.ButtonDown(flag))
    end
end

local function AnyHeldDown(down)
    for key in pairs(s_Capture.HeldKeys) do
        if down[key] then return true end
    end

    for flag in pairs(s_Capture.HeldButtons) do
        if Input.ButtonDown(flag) then return true end
    end

    return false
end

local function ButtonOrder(flag)
    return BUTTON_ORDER[flag] or (1000 + flag)
end

local function SortedKeys(set)
    local list = {}
    for code in pairs(set) do table.insert(list, code) end
    table.sort(list)
    return list
end

local function SortedButtons(set)
    local list = {}
    for flag in pairs(set) do table.insert(list, flag) end
    table.sort(list, function(first, second) return ButtonOrder(first) < ButtonOrder(second) end)
    return list
end

local function Assign(list, codes)
    for index = #list, 1, -1 do list[index] = nil end
    for _, code in ipairs(codes) do table.insert(list, code) end
end

local function UpdateCapture(binding)
    local style = KeyBind.Style
    local capture = s_Capture
    local elapsed = State.Time.Time - capture.Start

    if elapsed < style.Countdown then return end

    local down = DownKeys()
    if not capture.Armed then
        SnapshotHeld(down)
        capture.Armed = true
    end

    if Input.KeyDown(Input.VK.Escape) then
        StopCapture()
        return KeyBind.Results.Cancelled
    end

    if elapsed - style.Countdown > style.Timeout then
        StopCapture()
        return KeyBind.Results.TimedOut
    end

    local deleteDown = Input.KeyDown(Input.VK.Delete)
    local viewDown = Input.ButtonDown(Input.Button.Back)
    if deleteDown then capture.Clear = 1 end
    if viewDown then capture.Clear = 2 end

    if capture.Clear ~= 0 then
        if deleteDown or viewDown then return end

        local result = KeyBind.Results.ClearedKeys
        if capture.Clear == 1 then
            Assign(binding.Keys, {})
        else
            Assign(binding.Buttons, {})
            result = KeyBind.Results.ClearedButtons
        end

        StopCapture()
        return result
    end

    TrackHeld(down)

    local anyDown = AnyHeldDown(down)
    if capture.WasAnyDown and not anyDown then
        if next(capture.HeldKeys) then Assign(binding.Keys, SortedKeys(capture.HeldKeys)) end
        if next(capture.HeldButtons) then Assign(binding.Buttons, SortedButtons(capture.HeldButtons)) end

        StopCapture()
        return KeyBind.Results.Bound
    end

    capture.WasAnyDown = anyDown
end

function KeyBind.Update(binding)
    binding.Keys = binding.Keys or {}
    binding.Buttons = binding.Buttons or {}
    return UpdateCapture(binding)
end

function KeyBind.Countdown()
    local style = KeyBind.Style
    local elapsed = State.Time.Time - (s_Capture.Start or State.Time.Time)
    if elapsed < style.Countdown then return true, math.ceil(style.Countdown - elapsed) end
    return false, math.max(0, math.ceil(style.Timeout - (elapsed - style.Countdown)))
end

local function KeycapWidth(name, size)
    local width = Draw.TextSize(name, size)
    if name == SEPARATOR then return width end
    return width + Scale.S(KeyBind.Style.KeyPaddingX * 2)
end

function KeyBind.KeycapsWidth(names)
    local size = Scale.FontSize() * KeyBind.Style.KeyScale
    local gap = Scale.S(KeyBind.Style.KeyGap)

    local total = 0
    for index, name in ipairs(names) do
        total = total + KeycapWidth(name, size) + (index > 1 and gap or 0)
    end
    return total
end

function KeyBind.DrawKeycaps(names, right, centerY, border, textColor)
    local style = KeyBind.Style
    local size = Scale.FontSize() * style.KeyScale
    local padX = Scale.S(style.KeyPaddingX)
    local padY = Scale.S(style.KeyPaddingY)
    local gap = Scale.S(style.KeyGap)
    local _, lineHeight = Draw.TextSize("Ag", size)
    local boxHeight = lineHeight + (padY * 2)
    local rounding = Scale.S(style.KeyRounding)

    local x = right - KeyBind.KeycapsWidth(names)

    for _, name in ipairs(names) do
        local _, textHeight = Draw.TextSize(name, size)
        local width = KeycapWidth(name, size)
        local textY = centerY - (textHeight * 0.5)

        if name == SEPARATOR then
            Draw.Text(x, textY, Style.TextDisabled, name, size)
        else
            Draw.Rect(x, centerY - (boxHeight * 0.5), width, boxHeight, border, rounding)
            Draw.Text(x + padX, textY, textColor, name, size)
        end

        x = x + width + gap
    end
end

function KeyBind.Names(keys, buttons)
    local names = {}
    for _, key in ipairs(keys) do table.insert(names, KeyBind.KeyName(key)) end
    if #keys > 0 and #buttons > 0 then table.insert(names, SEPARATOR) end
    for _, flag in ipairs(buttons) do table.insert(names, KeyBind.ButtonName(flag)) end
    return names
end

function KeyBind.HeldNames()
    return KeyBind.Names(SortedKeys(s_Capture.HeldKeys or {}), SortedButtons(s_Capture.HeldButtons or {}))
end

local function StatusText()
    local counting, seconds = KeyBind.Countdown()
    if counting then return string.format("Binding in %d", seconds) end
    return string.format("Press a key, Del clears (%d)", seconds)
end

function KeyBind.Draw(label, binding)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    binding.Keys = binding.Keys or {}
    binding.Buttons = binding.Buttons or {}

    local before = KeyBind.FormatBinding(binding)
    local capturing = s_Capture.Id == data.Id

    if capturing then
        if not data.Selected then
            StopCapture()
        else
            UpdateCapture(binding)
        end
    elseif data.Activated and not KeyBind.IsCapturing() then
        StartCapture(data.Id)
    end

    capturing = s_Capture.Id == data.Id
    local changed = KeyBind.FormatBinding(binding) ~= before

    local slider = SliderStyle
    local controlWidth = Toggle.ControlWidth()
    local padding = Scale.S(Layout.Padding)
    local rowRight = data.X + data.Width - padding
    local valueRight = rowRight - controlWidth - Scale.S(slider.ValueGap)
    local centerY = data.Y + (data.Height * 0.5)
    local valueSize = Scale.FontSize() * slider.ValueScale

    local status = capturing and StatusText() or ""
    local names = nil
    if capturing then
        names = KeyBind.Names(SortedKeys(s_Capture.HeldKeys), SortedButtons(s_Capture.HeldButtons))
    else
        names = KeyBind.Names(binding.Keys, binding.Buttons)
    end

    local valueWidth = 0
    if #names > 0 then
        valueWidth = KeyBind.KeycapsWidth(names)
    else
        valueWidth = Draw.TextSize(capturing and status or "None", valueSize)
    end

    local valueLeft = valueRight - valueWidth

    if data.Selected and not capturing then
        Highlight.SetHint(Highlight.SelectHint(), rowRight - valueLeft + Scale.S(slider.ValueGap))
    end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    local active = math.max(state.Select, state.Hover)
    local textColor = Animation.LerpColor(Style.TextSoft, Style.Text, active)
    local pulse = 0.55 + (0.45 * ((math.sin(State.Time.Time * 6) + 1) * 0.5))

    if capturing and #names == 0 then
        local width, height = Draw.TextSize(status, valueSize)
        Draw.Text(valueRight - width, centerY - (height * 0.5), Draw.WithAlpha(Style.Accent, pulse), status, valueSize)
    elseif #names == 0 then
        local width, height = Draw.TextSize("None", valueSize)
        Draw.Text(valueRight - width, centerY - (height * 0.5), Style.TextDisabled, "None", valueSize)
    else
        KeyBind.DrawKeycaps(names, valueRight, centerY, capturing and Style.Accent or Style.Border, textColor)
    end

    local iconSize = Scale.FontSize() * ICON_SCALE
    local icon = Icons.Get("Keyboard")
    local iconWidth, iconHeight = Draw.TextSize(icon, iconSize)
    local columnCenter = rowRight - (controlWidth * 0.5)
    local iconColor = capturing and Style.Accent or Animation.LerpColor(Style.TextDisabled, Style.Text, active * 0.6)
    Draw.Text(columnCenter - (iconWidth * 0.5), centerY - (iconHeight * 0.5), iconColor, icon, iconSize)

    return changed
end

return KeyBind
