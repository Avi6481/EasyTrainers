local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local MeterStyle = require("Widgets/Meter/MeterStyle")
local Toggle = require("Widgets/Toggle/Toggle")

local Meter = {}

local LOCK_ICON_SCALE = 0.62

local function RowRight(data)
    return data.X + data.Width - Scale.S(Layout.Padding)
end

function Meter.Draw(label, value, min, max, format)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local target = 0
    if max > min then target = Animation.Clamp((value - min) / (max - min), 0, 1) end
    local fill = Row.Value(state, "Meter", target, MeterStyle.FillSpeed)

    local text = string.format(format or "%.0f", value)

    local valueSize = Scale.FontSize() * MeterStyle.ValueScale
    local width = Scale.S(MeterStyle.Width)
    local height = Scale.S(MeterStyle.Height)
    local barX = RowRight(data) - width
    local textWidth, textHeight = Draw.TextSize(text, valueSize)
    local textX = barX - Scale.S(MeterStyle.ValueGap) - textWidth

    if data.Selected then Highlight.SetHint(nil) end

    if not data.Visible then return data.Activated end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    local centerY = data.Y + (data.Height * 0.5)
    local active = math.max(state.Select, state.Hover)
    local textColor = Animation.LerpColor(Style.TextSoft, Style.Text, active)
    Draw.Text(textX, centerY - (textHeight * 0.5), textColor, text, valueSize)

    local segments = math.max(1, math.floor(MeterStyle.Segments))
    local gap = Scale.S(MeterStyle.SegmentGap)
    local segmentWidth = (width - (gap * (segments - 1))) / segments
    local barY = centerY - (height * 0.5)
    local rounding = Scale.S(MeterStyle.Rounding)

    for index = 0, segments - 1 do
        local x = barX + (index * (segmentWidth + gap))
        Draw.RectFilled(x, barY, segmentWidth, height, MeterStyle.Empty, rounding)

        local amount = Animation.Clamp((fill * segments) - index, 0, 1)
        if amount > 0.01 then Draw.RectFilled(x, barY, segmentWidth * amount, height, Style.Accent, rounding) end
    end

    return data.Activated
end

function Meter.LevelPips(label, ref, maxLevel, locked)
    local pips = MeterStyle.Pips
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    maxLevel = math.max(1, math.floor(maxLevel or 1))
    local before = ref.Value or 0
    local level = before

    if not locked then
        if data.Activated then level = level >= maxLevel and 0 or level + 1 end

        local adjust = data.Selected and Navigation.State.Adjust or 0
        if adjust ~= 0 then level = Animation.Clamp(level + (adjust > 0 and 1 or -1), 0, maxLevel) end
    end

    level = Animation.Clamp(level, 0, maxLevel)
    ref.Value = level
    local changed = level ~= before

    local radius = Scale.S(pips.Radius)
    local gap = Scale.S(pips.Gap)
    local pipsWidth = (maxLevel * radius * 2) + ((maxLevel - 1) * gap)
    local rowRight = RowRight(data)
    local controlWidth = Toggle.ControlWidth()
    local pipsRight = rowRight - controlWidth - Scale.S(MeterStyle.ValueGap)
    local pipsX = pipsRight - pipsWidth

    if data.Selected then
        Highlight.SetHint(locked and "Locked" or Highlight.SelectHint(), rowRight - pipsX + Scale.S(MeterStyle.ValueGap))
    end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, (not locked and level > 0) and 0.5 or 0)

    local centerY = data.Y + (data.Height * 0.5)
    local alpha = locked and pips.LockedAlpha or 1
    local accent = Draw.ScaleAlpha(Style.Accent, alpha)
    local empty = Draw.ScaleAlpha(pips.Empty, alpha)
    local step = (radius * 2) + gap

    for index = 0, maxLevel - 1 do
        local centerX = pipsX + radius + (index * step)
        local filled = Row.Value(state, index, index < level and 1 or 0, pips.FillSpeed)

        Draw.Circle(centerX, centerY, radius, Animation.LerpColor(empty, accent, filled), Scale.S(pips.RingThickness))
        if filled > 0.01 then Draw.CircleFilled(centerX, centerY, radius * filled, accent) end
    end

    if not locked then return changed end

    local size = Scale.FontSize() * LOCK_ICON_SCALE
    local icon = Icons.Get("Lock")
    local iconWidth, iconHeight = Draw.TextSize(icon, size)
    local columnCenter = rowRight - (controlWidth * 0.5)
    Draw.Text(columnCenter - (iconWidth * 0.5), centerY - (iconHeight * 0.5), Style.TextDisabled, icon, size)

    return changed
end

return Meter
