local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Highlight = require("UI/Widgets/Core/Highlight")
local Navigation = require("UI/Navigation/Navigation")
local Style = require("UI/Style/Style")
local Surface = require("UI/Widgets/Surface/Surface")
local SurfaceStyle = require("UI/Widgets/Surface/SurfaceStyle")
local Widget = require("UI/Widgets/Core/Widget")

local ColorPicker = {
    Surface = Surface.Create("##EasyTrainerColorPicker"),
    Opened = false,
    OwnerId = nil,
    ChangedOwner = nil,
    Label = "",
    Value = nil,
    Current = 1,
}

local Channels = { "Red", "Green", "Blue", "Alpha" }

local function MouseInteraction(x, y, width, height)
    if not Navigation.State.MouseEnabled then return false, false end
    local mouseX, mouseY = ImGui.GetMousePos()
    local hovered = mouseX >= x and mouseX <= x + width and mouseY >= y and mouseY <= y + height
    return hovered, hovered and ImGui.IsMouseClicked(0)
end

local function PackedColor(ref)
    return ImGui.ColorConvertFloat4ToU32({
        (ref.Red or 0) / 255, (ref.Green or 0) / 255,
        (ref.Blue or 0) / 255, (ref.Alpha or 255) / 255,
    })
end

local function Change(amount)
    if not ColorPicker.Value then return end
    local channel = Channels[ColorPicker.Current]
    ColorPicker.Value[channel] = math.max(0, math.min(255, (ColorPicker.Value[channel] or 0) + amount))
    ColorPicker.ChangedOwner = ColorPicker.OwnerId
end

function ColorPicker.Initialize()
    Surface.Initialize(ColorPicker.Surface)
    ColorPicker.Opened = false
    ColorPicker.OwnerId = nil
    ColorPicker.ChangedOwner = nil
    ColorPicker.Value = nil
    ColorPicker.Current = 1
end

function ColorPicker.Open(ownerId, label, value)
    ColorPicker.Opened = true
    ColorPicker.OwnerId = ownerId
    ColorPicker.Label = label or "Color"
    ColorPicker.Value = value
    ColorPicker.Current = 1
    Surface.Open(ColorPicker.Surface)
    Navigation.State.EnterMode(Navigation.State.Mode.Color)
    Navigation.State.BlockMouseInput = true
end

function ColorPicker.Close()
    ColorPicker.Opened = false
    Surface.Close(ColorPicker.Surface)
    Navigation.State.LeaveMode()
end

function ColorPicker.IsOwner(ownerId)
    return ColorPicker.OwnerId == ownerId
        and (ColorPicker.Opened or ColorPicker.Surface.Alpha >= 0.01)
end

function ColorPicker.Update()
    if not ColorPicker.Opened then return end
    if Navigation.Input.UpPressed then ColorPicker.Current = ColorPicker.Current == 1 and 4 or ColorPicker.Current - 1 end
    if Navigation.Input.DownPressed then ColorPicker.Current = ColorPicker.Current == 4 and 1 or ColorPicker.Current + 1 end
    if Navigation.Input.LeftPressed then Change(-5) end
    if Navigation.Input.RightPressed then Change(5) end
    if Navigation.Input.BackPressed or Navigation.Input.SelectPressed then
        Navigation.Input.BackPressed = false
        Navigation.Input.SelectPressed = false
        ColorPicker.Close()
    end
end

function ColorPicker.Option(id, label, value, tip)
    local data = Widget.Begin(true)
    local changed = ColorPicker.ChangedOwner == id
    if changed then ColorPicker.ChangedOwner = nil end
    if not data.Visible then return changed, data end

    local clicked = Widget.Prepare(data, tip, id)
    local drawList = ImGui.GetWindowDrawList()
    local textY = data.Y + ((data.Height - ImGui.GetFontSize()) * 0.5)
    local swatchSize = data.Height - 10
    local swatchX = data.X + data.Width - swatchSize - 8
    Draw.Text(drawList, data.X + 8, textY, Style.Text, Draw.FitText(label, data.Width - 120))
    Draw.Text(drawList, swatchX - 18, textY, Style.Accent,
        ColorPicker.Opened and ColorPicker.OwnerId == id and "v" or ">")
    Draw.RectFilled(drawList, swatchX, data.Y + 5, swatchSize, swatchSize, PackedColor(value), 5)
    Draw.Rect(drawList, swatchX, data.Y + 5, swatchSize, swatchSize, Style.Border, 5, 1)

    if Widget.IsActivated(data, clicked) then
        ColorPicker.Open(id, label, value)
    end
    return changed, data
end

function ColorPicker.Draw()
    if not ColorPicker.Opened and ColorPicker.Surface.Alpha < 0.01 then
        ColorPicker.OwnerId = nil
        ColorPicker.Value = nil
        return
    end
    if not ColorPicker.Value then return end

    local width, rowHeight = 300, 36
    local height = 48 + (#Channels * rowHeight) + 42
    if not Surface.Begin(ColorPicker.Surface, width, height) then
        ColorPicker.OwnerId = nil
        ColorPicker.Value = nil
        return
    end

    local drawList = ImGui.GetWindowDrawList()
    local x = ColorPicker.Surface.X + SurfaceStyle.Padding
    local y = ColorPicker.Surface.Y + SurfaceStyle.Padding
    local contentWidth = width - (SurfaceStyle.Padding * 2)
    Draw.Text(drawList, x, y, Style.TextDisabled, Draw.FitText(ColorPicker.Label, contentWidth - 54))
    Draw.RectFilled(drawList, x + contentWidth - 38, y - 3, 38, 22, PackedColor(ColorPicker.Value), 5)
    Draw.Rect(drawList, x + contentWidth - 38, y - 3, 38, 22, Style.Border, 5, 1)
    Draw.Line(drawList, x, y + 29, x + contentWidth, y + 29, Style.Border, 1)

    local listY = y + 38
    for index, channel in ipairs(Channels) do
        local rowY = listY + ((index - 1) * rowHeight)
        local hovered, clicked = MouseInteraction(x, rowY, contentWidth, rowHeight)
        if hovered then ColorPicker.Current = index end
        if index == ColorPicker.Current then
            Draw.RectFilled(drawList, x, rowY, contentWidth, rowHeight,
                Animation.WithAlpha(Style.Accent, 0.20), SurfaceStyle.Rounding)
            Draw.LeftAccent(drawList, x, rowY, rowHeight, Style.Accent, SurfaceStyle.Rounding, 3)
        end

        local value = ColorPicker.Value[channel] or 0
        local barX, barY, barWidth = x + 70, rowY + 13, contentWidth - 112
        Draw.Text(drawList, x + 9, rowY + 10, Style.Text, channel)
        Draw.RectFilled(drawList, barX, barY, barWidth, 10, Style.BackgroundDark, 5)
        Draw.RectFilled(drawList, barX, barY, barWidth * (value / 255), 10, Style.Accent, 5)
        Draw.Rect(drawList, barX, barY, barWidth, 10, Style.Border, 5, 1)
        Draw.Text(drawList, x + contentWidth - 31, rowY + 10, Style.TextDisabled, tostring(value))
        if clicked then
            local mouseX = ImGui.GetMousePos()
            ColorPicker.Value[channel] = math.floor(math.max(0, math.min(1, (mouseX - barX) / barWidth)) * 255)
            ColorPicker.ChangedOwner = ColorPicker.OwnerId
        end
    end

    local footerY = listY + (#Channels * rowHeight) + 9
    Draw.Line(drawList, x, footerY - 4, x + contentWidth, footerY - 4, Style.Border, 1)
    Draw.Text(drawList, x, footerY + 5, Style.TextDisabled, "LEFT / RIGHT  ADJUST")
    local close = "SELECT / BACK  CLOSE"
    Draw.Text(drawList, x + contentWidth - ImGui.CalcTextSize(close), footerY + 5, Style.TextDisabled, close)
    Surface.End(ColorPicker.Surface)
end

return ColorPicker
