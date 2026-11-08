local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local Toggle = require("Widgets/Toggle/Toggle")

local ValueRow = {}

local MAX_VALUE_SHARE = 0.55

local function Fit(state, value, width, size)
    if state.FitValue ~= value or state.FitWidth ~= width or state.FitSize ~= size then
        state.FitValue = value
        state.FitWidth = width
        state.FitSize = size
        state.FitShown = Draw.FitText(value, width, size)
        state.FitShownWidth, state.FitShownHeight = Draw.TextSize(state.FitShown, size)
    end
    return state.FitShown, state.FitShownWidth, state.FitShownHeight
end

function ValueRow.Draw(label, value, action)
    action = action == true

    local data = Widget.Begin(label)
    local state = Row.Animate(data)
    if action then Widget.Bindable(data, label, Widget.Kinds.Action) end

    local padding = Scale.S(Layout.Padding)
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local rowRight = data.X + data.Width - padding
    local valueRight = rowRight - Toggle.ControlWidth() - Scale.S(SliderStyle.ValueGap)

    if not data.Visible and not data.Selected then return action and data.Activated end

    local shown, textWidth, textHeight = Fit(state, value, data.Width * MAX_VALUE_SHARE, valueSize)
    local valueX = valueRight - textWidth

    local gap = Scale.S(SliderStyle.ValueGap)
    local labelRight = valueX - gap
    if data.Selected then
        local hint = nil
        if action then hint = Highlight.SelectHint() end
        Highlight.SetHint(hint, rowRight - valueX + gap)
        labelRight = labelRight - Highlight.HintWidth(hint) - gap
    end

    if not data.Visible then return action and data.Activated end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, nil, labelRight)

    local centerY = data.Y + (data.Height * 0.5)
    local active = math.max(state.Select, state.Hover)
    local color = Animation.LerpColor(Style.TextDisabled, Style.TextSoft, active)
    Draw.Text(valueX, centerY - (textHeight * 0.5), color, shown, valueSize)

    return action and data.Activated
end

return ValueRow
