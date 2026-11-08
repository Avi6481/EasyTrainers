local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Scale = require("Style/Scale")
local ControlsHudStyle = require("Panels/ControlsHud/ControlsHudStyle")

local ControlsHud = {}

local s_Controls = nil
local s_BindHint = false
local s_BindKey = "F3"
local s_BindButton = "Y"

local function WithBind(list, key)
    local copy = {}
    for _, control in ipairs(list) do table.insert(copy, control) end
    table.insert(copy, { Key = key, Icon = "", Label = "Bind" })
    return copy
end

local function BuildControls()
    local controls = {
        Keyboard = {
            { Key = "", Icon = Icons.Get("ArrowUp") .. " " .. Icons.Get("ArrowDown"), Label = "Move" },
            { Key = "Enter", Icon = "", Label = "Select" },
            { Key = "Backspace", Icon = "", Label = "Back" },
            { Key = "X", Icon = "", Label = "Mouse" },
            { Key = "F4", Icon = "", Label = "Close" }
        },
        Controller = {
            { Key = "D-Pad", Icon = "", Label = "Move" },
            { Key = "A", Icon = "", Label = "Select" },
            { Key = "B", Icon = "", Label = "Back" },
            { Key = "RB +", Icon = Icons.Get("ArrowRight"), Label = "Close" }
        },
        Mouse = {
            { Key = "Wheel", Icon = "", Label = "Move" },
            { Key = "Left Click", Icon = "", Label = "Select" },
            { Key = "Right Click", Icon = "", Label = "Back" },
            { Key = "X", Icon = "", Label = "Cursor" }
        },
        Cursor = {
            { Key = "Click", Icon = "", Label = "Select" },
            { Key = "Right Click", Icon = "", Label = "Back" },
            { Key = "Wheel", Icon = "", Label = "Move" },
            { Key = "X", Icon = "", Label = "Hide Cursor" }
        }
    }

    controls.KeyboardBind = WithBind(controls.Keyboard, s_BindKey)
    controls.ControllerBind = WithBind(controls.Controller, s_BindButton)
    controls.MouseBind = WithBind(controls.Mouse, s_BindKey)
    controls.CursorBind = WithBind(controls.Cursor, s_BindKey)
    return controls
end

function ControlsHud.SetBindKeys(key, button)
    s_BindKey = key
    s_BindButton = button
    s_Controls = nil
end

function ControlsHud.SetBindHint(shown)
    s_BindHint = shown == true and Input.IsAvailable()
end

local function CurrentControls()
    s_Controls = s_Controls or BuildControls()

    local device = State.Device.Device
    local bind = s_BindHint
    if device == State.Devices.Keyboard then return bind and s_Controls.KeyboardBind or s_Controls.Keyboard end
    if device == State.Devices.Controller then return bind and s_Controls.ControllerBind or s_Controls.Controller end
    if State.Menu.Cursor then return bind and s_Controls.CursorBind or s_Controls.Cursor end
    return bind and s_Controls.MouseBind or s_Controls.Mouse
end

local function CurrentSizes()
    local fontSize = Scale.FontSize()
    local sizes = {
        Key = fontSize * ControlsHudStyle.KeyScale,
        Icon = fontSize * ControlsHudStyle.IconScale,
        Label = fontSize * ControlsHudStyle.LabelScale,
        PadX = Scale.S(ControlsHudStyle.KeyPaddingX),
        PadY = Scale.S(ControlsHudStyle.KeyPaddingY),
        IconGap = Scale.S(ControlsHudStyle.IconSpacing),
        KeySpacing = Scale.S(ControlsHudStyle.KeySpacing),
        ItemSpacing = Scale.S(ControlsHudStyle.ItemSpacing)
    }

    local _, keyHeight = Draw.TextSize("Ag", sizes.Key)
    sizes.BoxHeight = keyHeight + (sizes.PadY * 2)
    return sizes
end

local function MeasureControl(control, sizes)
    local item = { Item = control, KeyWidth = 0, IconWidth = 0 }
    if control.Key ~= "" then item.KeyWidth = Draw.TextSize(control.Key, sizes.Key) end
    if control.Icon ~= "" then item.IconWidth = Draw.TextSize(control.Icon, sizes.Icon) end

    local gap = (item.KeyWidth > 0 and item.IconWidth > 0) and sizes.IconGap or 0
    item.BoxWidth = item.KeyWidth + gap + item.IconWidth + (sizes.PadX * 2)

    item.LabelWidth, item.LabelHeight = Draw.TextSize(control.Label, sizes.Label)
    item.Width = item.BoxWidth + sizes.KeySpacing + item.LabelWidth
    return item
end

local function Measure(controls, sizes, available)
    local fitted = {}
    local total = 0

    for _, control in ipairs(controls) do
        local item = MeasureControl(control, sizes)
        local nextTotal = total + (#fitted == 0 and 0 or sizes.ItemSpacing) + item.Width
        if nextTotal > available then break end

        total = nextTotal
        table.insert(fitted, item)
    end

    return fitted
end

local function HudPosition(height)
    local menu = State.Menu
    local gap = Scale.S(ControlsHudStyle.Gap)
    local _, screenHeight = GetDisplayResolution()

    local below = menu.Y + menu.Height + gap
    if below + height <= screenHeight - gap then return menu.X, below end

    return menu.X, menu.Y - gap - height
end

local function DrawKeycap(item, sizes, x, centerY)
    local control = item.Item
    local boxY = centerY - (sizes.BoxHeight * 0.5)

    Draw.Rect(x, boxY, item.BoxWidth, sizes.BoxHeight, Style.Border, Scale.S(ControlsHudStyle.KeyRounding))

    local cursor = x + sizes.PadX

    if item.KeyWidth > 0 then
        local _, keyHeight = Draw.TextSize(control.Key, sizes.Key)
        Draw.Text(cursor, centerY - (keyHeight * 0.5), Style.Text, control.Key, sizes.Key)
        cursor = cursor + item.KeyWidth + (item.IconWidth > 0 and sizes.IconGap or 0)
    end

    if item.IconWidth > 0 then
        local _, iconHeight = Draw.TextSize(control.Icon, sizes.Icon)
        Draw.Text(cursor, centerY - (iconHeight * 0.5), Style.Text, control.Icon, sizes.Icon)
    end
end

local function DrawItems(x, y, width, height)
    local sizes = CurrentSizes()
    local padding = Scale.S(ControlsHudStyle.Padding)
    local items = Measure(CurrentControls(), sizes, width - (padding * 2))
    if #items == 0 then return end

    local total = sizes.ItemSpacing * (#items - 1)
    for _, item in ipairs(items) do total = total + item.Width end

    local cursor = x + ((width - total) * 0.5)
    local centerY = y + (height * 0.5)

    for _, item in ipairs(items) do
        DrawKeycap(item, sizes, cursor, centerY)

        local labelX = cursor + item.BoxWidth + sizes.KeySpacing
        Draw.Text(labelX, centerY - (item.LabelHeight * 0.5), Style.TextDisabled, item.Item.Label, sizes.Label)

        cursor = cursor + item.Width + sizes.ItemSpacing
    end
end

local function DrawHud(x, y, width, height)
    Draw.RectFilled(x, y, width, height, Style.Background, Scale.S(ControlsHudStyle.Rounding))
    DrawItems(x, y, width, height)
end

function ControlsHud.Below()
    if not ControlsHudStyle.Enabled then return 0 end

    local height = Scale.S(ControlsHudStyle.Height)
    local _, y = HudPosition(height)
    if y < State.Menu.Y then return 0 end

    return height + Scale.S(ControlsHudStyle.Gap)
end

function ControlsHud.Above()
    if not ControlsHudStyle.Enabled then return 0 end

    local height = Scale.S(ControlsHudStyle.Height)
    local _, y = HudPosition(height)
    if y >= State.Menu.Y then return 0 end

    return height + Scale.S(ControlsHudStyle.Gap)
end

function ControlsHud.Draw()
    if not ControlsHudStyle.Enabled then return end

    local width = State.Menu.Width
    local height = Scale.S(ControlsHudStyle.Height)
    local x, y = HudPosition(height)

    local ok, err = true, nil
    if Draw.BeginWindow("##EasyTrainerControls", x, y, width, height) then
        ok, err = pcall(DrawHud, x, y, width, height)
    end
    Draw.EndWindow()

    if not ok then error(err, 0) end
end

return ControlsHud
