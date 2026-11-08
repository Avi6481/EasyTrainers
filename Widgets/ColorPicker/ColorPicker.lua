local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Submenu = require("Navigation/Submenu")
local Highlight = require("Widgets/Core/Highlight")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local Toggle = require("Widgets/Toggle/Toggle")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local InputText = require("Widgets/InputText/InputText")
local Break = require("Widgets/Break/Break")
local Button = require("Widgets/Button/Button")

local ColorPicker = {
    Style = {}
}

local CHANNEL = {
    Hue = 1,
    Saturation = 2,
    Brightness = 3,
    Opacity = 4
}

local HUE_SEGMENTS = 6

local PRESETS = {
    { 224, 85, 85 },
    { 240, 140, 60 },
    { 252, 238, 10 },
    { 92, 203, 95 },
    { 46, 196, 182 },
    { 74, 143, 216 },
    { 123, 97, 255 },
    { 214, 93, 177 },
    { 255, 255, 255 },
    { 30, 30, 30 }
}

local s_Editor = {
    Target = nil,
    Original = { R = 0, G = 0, B = 0, A = 1 },
    Hue = 0,
    Saturation = 0,
    Brightness = 0,
    Alpha = false,
    Dirty = false,
    Preset = 1,
    OnChange = nil
}

local s_DragId = nil

function ColorPicker.InitializeStyle()
    local style = ColorPicker.Style
    style.SwatchSize = 13
    style.SwatchRounding = 3
    style.TrackWidth = 132
    style.TrackHeight = 6
    style.ThumbRadius = 5.5
    style.ThumbBorder = 1.5
    style.PreviewHeight = 18
    style.PresetSize = 14
    style.PresetGap = 7
end

ColorPicker.InitializeStyle()

local function Byte(value)
    return math.floor((Animation.Clamp(value or 0, 0, 1) * 255) + 0.5)
end

local function ToU32(color)
    return Draw.RGBA(Byte(color.R), Byte(color.G), Byte(color.B), Byte(color.A or 1))
end

local function Copy(color)
    return { R = color.R, G = color.G, B = color.B, A = color.A }
end

local function Assign(target, source)
    target.R = source.R
    target.G = source.G
    target.B = source.B
    target.A = source.A
end

local function RgbToHsv(r, g, b)
    local maximum = math.max(r, g, b)
    local chroma = maximum - math.min(r, g, b)
    local saturation = maximum > 0 and (chroma / maximum) or 0
    if chroma <= 0 then return 0, saturation, maximum end

    local hue = 0
    if maximum == r then
        hue = ((g - b) / chroma) % 6
    elseif maximum == g then
        hue = ((b - r) / chroma) + 2
    else
        hue = ((r - g) / chroma) + 4
    end

    return hue / 6, saturation, maximum
end

local function HsvToRgb(h, s, v)
    if s <= 0 then return v, v, v end

    h = math.fmod(h, 1) * 6
    local sector = math.floor(h)
    local f = h - sector
    local p = v * (1 - s)
    local q = v * (1 - (s * f))
    local t = v * (1 - (s * (1 - f)))

    if sector == 0 then return v, t, p end
    if sector == 1 then return q, v, p end
    if sector == 2 then return p, v, t end
    if sector == 3 then return p, q, v end
    if sector == 4 then return t, p, v end
    return v, p, q
end

local function HsvColor(h, s, v)
    local r, g, b = HsvToRgb(h, s, v)
    return Draw.RGBA(Byte(r), Byte(g), Byte(b), 255)
end

function ColorPicker.ToHex(color, alpha)
    if alpha then
        return string.format("#%02X%02X%02X%02X", Byte(color.R), Byte(color.G), Byte(color.B), Byte(color.A or 1))
    end
    return string.format("#%02X%02X%02X", Byte(color.R), Byte(color.G), Byte(color.B))
end

function ColorPicker.FromHex(text, color)
    local hex = (tostring(text or ""):gsub("[# ]", ""))
    if hex:find("%X") then return false end
    if #hex ~= 6 and #hex ~= 8 then return false end

    color.R = tonumber(hex:sub(1, 2), 16) / 255
    color.G = tonumber(hex:sub(3, 4), 16) / 255
    color.B = tonumber(hex:sub(5, 6), 16) / 255
    if #hex == 8 then color.A = tonumber(hex:sub(7, 8), 16) / 255 end

    return true
end

local function SyncHsv()
    local color = s_Editor.Target
    local hue, saturation, brightness = RgbToHsv(color.R, color.G, color.B)

    if brightness > 0.001 and saturation > 0.001 then s_Editor.Hue = hue end
    if brightness > 0.001 then s_Editor.Saturation = saturation end
    s_Editor.Brightness = brightness
end

local function Changed()
    s_Editor.Dirty = true
    if s_Editor.OnChange then s_Editor.OnChange(s_Editor.Target) end
end

local function ApplyHsv()
    local color = s_Editor.Target
    color.R, color.G, color.B = HsvToRgb(s_Editor.Hue, s_Editor.Saturation, s_Editor.Brightness)
    Changed()
end

local function ChannelColor(channel, t)
    if channel == CHANNEL.Hue then return HsvColor(t, 1, 1) end
    if channel == CHANNEL.Saturation then return HsvColor(s_Editor.Hue, t, s_Editor.Brightness) end
    if channel == CHANNEL.Brightness then return HsvColor(s_Editor.Hue, s_Editor.Saturation, t) end

    local color = s_Editor.Target
    return Draw.RGBA(Byte(color.R), Byte(color.G), Byte(color.B), Byte(t))
end

local function DrawChannelTrack(channel, x, y, width, height)
    local radius = height * 0.5
    local left = x + radius
    local right = x + width - radius

    if channel == CHANNEL.Opacity then Draw.RectFilled(x, y, width, height, Style.Border, radius) end

    if channel == CHANNEL.Hue then
        local span = (right - left) / HUE_SEGMENTS
        for index = 0, HUE_SEGMENTS - 1 do
            local from = ChannelColor(channel, index / HUE_SEGMENTS)
            local to = ChannelColor(channel, (index + 1) / HUE_SEGMENTS)
            Draw.Gradient(left + (span * index), y, span + 0.5, height, from, to, to, from)
        end
    else
        local from = ChannelColor(channel, 0)
        local to = ChannelColor(channel, 1)
        Draw.Gradient(left, y, right - left, height, from, to, to, from)
    end

    Draw.CircleFilled(left, y + radius, radius, ChannelColor(channel, 0))
    Draw.CircleFilled(right, y + radius, radius, ChannelColor(channel, 1))
end

local function AdjustHint()
    local device = State.Device.Device
    local arrows = Icons.Get("ArrowLeft") .. " " .. Icons.Get("ArrowRight")

    if device == State.Devices.Controller then return HighlightStyle.ShowControllerHint and arrows or nil end
    if device == State.Devices.Keyboard then return HighlightStyle.ShowKeyboardHint and arrows or nil end
    if not HighlightStyle.ShowMouseHint then return nil end
    return State.Menu.Cursor and "Drag" or "Shift + Wheel"
end

local function ChannelRow(label, owner, key, channel)
    local style = ColorPicker.Style
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local padding = Scale.S(Layout.Padding)
    local rowRight = data.X + data.Width - padding
    local trackWidth = Scale.S(style.TrackWidth)
    local trackHeight = Scale.S(style.TrackHeight)
    local trackX = rowRight - trackWidth
    local radius = trackHeight * 0.5
    local centerY = data.Y + (data.Height * 0.5)

    local value = owner[key]
    local changed = false
    local step = channel == CHANNEL.Hue and (1 / 360) or 0.01

    local adjust = data.Selected and Navigation.State.Adjust or 0
    if adjust ~= 0 then
        local nextValue = Animation.Clamp(value + (adjust * step), 0, 1)
        changed = nextValue ~= value
        value = nextValue
    end

    local mouseX = Input.MousePos()
    if State.Menu.Cursor and data.Hovered and Input.MousePressed(Input.Mouse.Left) and mouseX >= trackX - Scale.S(style.ThumbRadius) then
        s_DragId = data.Id
    end

    if s_DragId == data.Id then
        if not Input.MouseDown(Input.Mouse.Left) then
            s_DragId = nil
        else
            local nextValue = Animation.Clamp((mouseX - trackX - radius) / math.max(1, trackWidth - (radius * 2)), 0, 1)
            changed = changed or nextValue ~= value
            value = nextValue
        end
    end

    owner[key] = value

    local text = nil
    if channel == CHANNEL.Hue then
        text = string.format("%d\194\176", math.floor((value * 360) + 0.5))
    else
        text = string.format("%d%%", math.floor((value * 100) + 0.5))
    end

    local slider = SliderStyle
    local valueSize = Scale.FontSize() * slider.ValueScale
    local gap = Scale.S(slider.ValueGap)
    local textWidth, textHeight = Draw.TextSize(text, valueSize)
    local textX = trackX - gap - textWidth

    if data.Selected then Highlight.SetHint(AdjustHint(), rowRight - textX + gap) end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    local active = math.max(state.Select, state.Hover)
    local textColor = Animation.LerpColor(Style.TextSoft, Style.Text, active)
    Draw.Text(textX, centerY - (textHeight * 0.5), textColor, text, valueSize)

    DrawChannelTrack(channel, trackX, centerY - radius, trackWidth, trackHeight)

    local thumbX = trackX + radius + (value * (trackWidth - (radius * 2)))
    local thumb = Scale.S(style.ThumbRadius) * Animation.Lerp(1, 1.15, state.Select)
    Draw.CircleFilled(thumbX, centerY, thumb, Draw.Opaque(ChannelColor(channel, value)))
    Draw.Circle(thumbX, centerY, thumb, Style.Text, Scale.S(style.ThumbBorder))

    return changed
end

local function PreviewRow()
    local style = ColorPicker.Style
    local index = Navigation.NextBreak()
    local content = Navigation.Content()

    local y = Navigation.RowY(index)
    local height = Scale.S(Layout.OptionHeight)
    if y + height <= content.Y or y >= content.Y + content.Height then return end

    local padding = Scale.S(Layout.Padding)
    local left = content.X + padding
    local right = content.X + content.Width - padding
    local barHeight = Scale.S(style.PreviewHeight)
    local barY = y + ((height - barHeight) * 0.5)
    local split = left + ((right - left) * 0.22)
    local rounding = Scale.S(style.SwatchRounding)

    Draw.RectFilled(left, barY, split - left, barHeight, ToU32(s_Editor.Original), rounding, Draw.Corners.Left)
    Draw.RectFilled(split, barY, right - split, barHeight, ToU32(s_Editor.Target), rounding, Draw.Corners.Right)
    Draw.Rect(left, barY, right - left, barHeight, Style.Border, rounding)
end

local function ApplyPreset(index)
    local preset = PRESETS[index]
    local color = s_Editor.Target

    color.R = preset[1] / 255
    color.G = preset[2] / 255
    color.B = preset[3] / 255

    SyncHsv()
    Changed()
end

local function PresetRow()
    local style = ColorPicker.Style
    local data = Widget.Begin("Quick Colors")
    local state = Row.Animate(data)

    local count = #PRESETS
    local padding = Scale.S(Layout.Padding)
    local rowRight = data.X + data.Width - padding
    local size = Scale.S(style.PresetSize)
    local gap = Scale.S(style.PresetGap)
    local startX = rowRight - ((count * size) + ((count - 1) * gap))
    local centerY = data.Y + (data.Height * 0.5)

    local adjust = data.Selected and Navigation.State.Adjust or 0
    if adjust ~= 0 then s_Editor.Preset = Animation.Clamp(s_Editor.Preset + (adjust > 0 and 1 or -1), 1, count) end

    if data.Clicked then
        local mouseX = Input.MousePos()
        local hit = math.floor((mouseX - startX) / (size + gap)) + 1
        if hit >= 1 and hit <= count then
            s_Editor.Preset = hit
            ApplyPreset(hit)
        end
    elseif data.Activated then
        ApplyPreset(s_Editor.Preset)
    end

    if data.Selected then Highlight.SetHint(Highlight.SelectHint(), rowRight - startX + gap) end

    if not data.Visible then return end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, "Quick Colors")

    local rounding = Scale.S(style.SwatchRounding)
    local top = centerY - (size * 0.5)
    for index, preset in ipairs(PRESETS) do
        local x = startX + ((index - 1) * (size + gap))
        Draw.RectFilled(x, top, size, size, Draw.RGBA(preset[1], preset[2], preset[3], 255), rounding)
        Draw.Rect(x, top, size, size, Style.Border, rounding)

        if data.Selected and index == s_Editor.Preset then
            local ring = Scale.S(3)
            Draw.Rect(x - ring, top - ring, size + (ring * 2), size + (ring * 2), Style.Text, rounding + ring, 0, Scale.S(1.5))
        end
    end
end

local function EditorView()
    if not s_Editor.Target then return end

    PreviewRow()

    local changed = ChannelRow("Hue", s_Editor, "Hue", CHANNEL.Hue)
    changed = ChannelRow("Saturation", s_Editor, "Saturation", CHANNEL.Saturation) or changed
    changed = ChannelRow("Brightness", s_Editor, "Brightness", CHANNEL.Brightness) or changed
    if changed then ApplyHsv() end

    if s_Editor.Alpha and ChannelRow("Opacity", s_Editor.Target, "A", CHANNEL.Opacity) then Changed() end

    local hex = { Value = ColorPicker.ToHex(s_Editor.Target, s_Editor.Alpha) }
    if InputText.Draw("Hex", hex, s_Editor.Alpha and 9 or 7) then
        local parsed = Copy(s_Editor.Target)
        if ColorPicker.FromHex(hex.Value, parsed) then
            if not s_Editor.Alpha then parsed.A = s_Editor.Target.A end
            Assign(s_Editor.Target, parsed)
            SyncHsv()
            Changed()
        end
    end

    Break.Draw("", "Left")
    PresetRow()

    if Button.Draw("Revert") then
        Assign(s_Editor.Target, s_Editor.Original)
        SyncHsv()
        Changed()
    end
end

local function OpenEditor(label, color, alpha, onChange)
    if color.A == nil then color.A = 1 end

    s_Editor.Target = color
    s_Editor.Original = Copy(color)
    s_Editor.Alpha = alpha and true or false
    s_Editor.Dirty = false
    s_Editor.OnChange = onChange
    s_Editor.Hue = 0
    s_Editor.Saturation = 0
    SyncHsv()

    Submenu.Open(Submenu.Create(label, EditorView))
end

function ColorPicker.Draw(label, color, alpha, onChange)
    local style = ColorPicker.Style
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local changed = false
    if s_Editor.Target == color and s_Editor.Dirty then
        s_Editor.Dirty = false
        changed = true
    end

    if data.Activated then OpenEditor(label, color, alpha, onChange) end

    local slider = SliderStyle
    local controlWidth = Toggle.ControlWidth()
    local padding = Scale.S(Layout.Padding)
    local valueSize = Scale.FontSize() * slider.ValueScale
    local rowRight = data.X + data.Width - padding
    local columnCenter = rowRight - (controlWidth * 0.5)
    local valueRight = rowRight - controlWidth - Scale.S(slider.ValueGap)
    local centerY = data.Y + (data.Height * 0.5)

    local hex = ColorPicker.ToHex(color, alpha)
    local textWidth, textHeight = Draw.TextSize(hex, valueSize)
    local valueX = valueRight - textWidth

    if data.Selected then Highlight.SetHint(Highlight.SelectHint(), rowRight - valueX + Scale.S(slider.ValueGap)) end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    local active = math.max(state.Select, state.Hover)
    local textColor = Animation.LerpColor(Style.TextSoft, Style.Text, active)
    Draw.Text(valueX, centerY - (textHeight * 0.5), textColor, hex, valueSize)

    local size = Scale.S(style.SwatchSize)
    local rounding = Scale.S(style.SwatchRounding)
    local swatchX = columnCenter - (size * 0.5)
    local swatchY = centerY - (size * 0.5)
    Draw.RectFilled(swatchX, swatchY, size, size, ToU32(color), rounding)
    Draw.Rect(swatchX, swatchY, size, size, Style.Border, rounding)

    return changed
end

return ColorPicker
