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

local Preset = {}

local CHIP_SHARE = 0.46
local CHIP_GAP = 5
local CHIP_ROUNDING = 3

local function Packed(color)
    if not color.Packed then
        color.Packed = Draw.RGBA(
            math.floor((color.R * 255) + 0.5),
            math.floor((color.G * 255) + 0.5),
            math.floor((color.B * 255) + 0.5),
            255
        )
    end
    return color.Packed
end

local function ChipsWidth(count, size)
    if count == 0 then return 0 end
    return (count * size) + ((count - 1) * Scale.S(CHIP_GAP))
end

local function DrawChips(swatches, right, centerY, size, active)
    local x = right - ChipsWidth(#swatches, size)
    local rounding = Scale.S(CHIP_ROUNDING)
    local border = Animation.LerpColor(Style.Border, Style.TextSoft, active)
    for _, color in ipairs(swatches) do
        Draw.RectFilled(x, centerY - (size * 0.5), size, size, Packed(color), rounding)
        Draw.Rect(x, centerY - (size * 0.5), size, size, border, rounding, nil, 1)
        x = x + size + Scale.S(CHIP_GAP)
    end
end

function Preset.Draw(label, swatches, value)
    swatches = swatches or {}
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local gap = Scale.S(SliderStyle.ValueGap)
    local rowRight = data.X + data.Width - Scale.S(Layout.Padding)
    local right = rowRight - Toggle.ControlWidth() - gap
    local chip = data.Height * CHIP_SHARE
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local valueWidth, valueHeight = 0, 0
    if value and value ~= "" then valueWidth, valueHeight = Draw.TextSize(value, valueSize) end

    local contentWidth = ChipsWidth(#swatches, chip) + ((valueWidth > 0 and #swatches > 0) and gap or 0) + valueWidth
    local left = right - contentWidth
    local labelRight = left - gap
    if data.Selected then
        local hint = Highlight.SelectHint()
        Highlight.SetHint(hint, rowRight - left + gap)
        labelRight = labelRight - Highlight.HintWidth(hint) - gap
    end

    if not data.Visible then return data.Activated end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, nil, labelRight)

    local centerY = data.Y + (data.Height * 0.5)
    local active = math.max(state.Select, state.Hover)
    if valueWidth > 0 then
        Draw.Text(left, centerY - (valueHeight * 0.5), Animation.LerpColor(Style.TextDisabled, Style.TextSoft, active), value, valueSize)
    end
    DrawChips(swatches, right, centerY, chip, active)

    return data.Activated
end

return Preset
