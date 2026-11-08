local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local Toggle = require("Widgets/Toggle/Toggle")

local Radio = {}

local CHECK_SCALE = 0.62
local CHECK_SPEED = 14
local LABEL_BOOST = 0.6

function Radio.Draw(label, ref, value)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local changed = false
    if data.Activated and ref.Value ~= value then
        ref.Value = value
        changed = true
    end

    local chosen = ref.Value == value
    local on = Row.Value(state, "Radio", chosen and 1 or 0, CHECK_SPEED)

    if data.Selected then
        local hint = nil
        if not chosen then hint = Highlight.SelectHint() end
        Highlight.SetHint(hint, Toggle.ControlWidth())
    end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, on * LABEL_BOOST)

    if on < 0.01 then return changed end

    local rowRight = data.X + data.Width - Scale.S(Layout.Padding)
    local columnCenter = rowRight - (Toggle.ControlWidth() * 0.5)
    local centerY = data.Y + (data.Height * 0.5)

    local icon = Icons.Get("Check")
    local size = Scale.FontSize() * CHECK_SCALE * Animation.Lerp(0.6, 1, Animation.EaseOut(on))
    local iconWidth, iconHeight = Draw.TextSize(icon, size)
    Draw.Text(columnCenter - (iconWidth * 0.5), centerY - (iconHeight * 0.5), Draw.ScaleAlpha(Style.Accent, on), icon, size)

    return changed
end

function Radio.List(ref, items)
    local changed = false

    for index, item in ipairs(items) do
        changed = Radio.Draw(item, ref, index) or changed
    end

    return changed
end

return Radio
