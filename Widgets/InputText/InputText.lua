local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local TextField = require("Widgets/Core/TextField")
local Widget = require("Widgets/Core/Widget")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local Toggle = require("Widgets/Toggle/Toggle")

local InputText = {}

local MAX_VALUE_SHARE = 0.5
local EDIT_START = 0.42
local ICON_SCALE = 0.62

local function Printable(character)
    local byte = character:byte(1)
    return byte >= 32 and byte < 127
end

function InputText.Draw(label, ref, maxLength, placeholder, filter)
    maxLength = maxLength or 64
    placeholder = placeholder or "Empty"

    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local value = ref.Value or ""
    local changed = false
    local editing = TextField.Active(data.Id)

    if editing then
        if not data.Selected then
            TextField.End()
        else
            local result = TextField.Update()

            if result == TextField.Result.Confirmed then
                local text = TextField.Text()
                changed = text ~= value
                value = text
                ref.Value = text
                TextField.End()
            elseif result == TextField.Result.Cancelled then
                TextField.End()
            end
        end
    elseif data.Activated or (data.Selected and Navigation.State.EditPressed) then
        TextField.Begin(data.Id, value, maxLength, filter or Printable)
    end

    editing = TextField.Active(data.Id)

    local padding = Scale.S(Layout.Padding)
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local controlWidth = Toggle.ControlWidth()
    local rowRight = data.X + data.Width - padding
    local columnCenter = rowRight - (controlWidth * 0.5)
    local valueRight = rowRight - controlWidth - Scale.S(SliderStyle.ValueGap)
    local centerY = data.Y + (data.Height * 0.5)

    local empty = value == ""
    local shown = Draw.FitText(empty and placeholder or value, data.Width * MAX_VALUE_SHARE, valueSize)
    local textWidth, textHeight = Draw.TextSize(shown, valueSize)
    local valueX = valueRight - textWidth
    local editX = data.X + (data.Width * EDIT_START)

    local gap = Scale.S(SliderStyle.ValueGap)
    local left = editing and editX or valueX
    local labelRight = left - gap
    if data.Selected then
        local hint = editing and "Enter" or Highlight.SelectHint()
        Highlight.SetHint(hint, rowRight - left + gap)
        labelRight = labelRight - Highlight.HintWidth(hint) - gap
    end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, nil, labelRight)

    if editing then
        TextField.DrawBox(editX, centerY, rowRight - editX, valueSize, placeholder)
        return changed
    end

    local active = math.max(state.Select, state.Hover)
    local textColor = Style.TextDisabled
    if not empty then textColor = Animation.LerpColor(Style.TextSoft, Style.Text, active) end
    Draw.Text(valueX, centerY - (textHeight * 0.5), textColor, shown, valueSize)

    local icon = Icons.Get("Pencil")
    local iconSize = Scale.FontSize() * ICON_SCALE
    local iconWidth, iconHeight = Draw.TextSize(icon, iconSize)
    local iconColor = Animation.LerpColor(Style.TextDisabled, Style.Text, active * 0.6)
    Draw.Text(columnCenter - (iconWidth * 0.5), centerY - (iconHeight * 0.5), iconColor, icon, iconSize)

    return changed
end

return InputText
