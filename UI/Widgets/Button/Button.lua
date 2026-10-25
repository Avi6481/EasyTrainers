local Button = {}

local Draw = require("UI/Core/Draw")
local Icons = require("UI/Style/Icons")
local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Widget = require("UI/Widgets/Core/Widget")
local ButtonStyle = require("UI/Widgets/Button/ButtonStyle")
local Style = require("UI/Style/Style")
local Mouse = require("Core/Mouse")

function Button.Create(label, tip, action)
    return { Kind = "button", Label = label, Tip = tip or "", Action = action }
end

local SLIDER_WIDTH = 170
local SLIDER_ARROW = 16
local TRACK_HEIGHT = 2
local KNOB_SIZE = 8

local function DrawSlider(drawList, data, display, ratio, focus, clicked, textY)
    local controlWidth = math.min(SLIDER_WIDTH, data.Width * 0.48)
    local right = data.X + data.Width - ButtonStyle.Padding
    local left = right - controlWidth
    local arrowColor = Animation.LerpColor(Style.Border, Style.Accent, focus)

    Draw.Text(drawList, left, textY, arrowColor, Icons.Back)
    Draw.Text(drawList, right - ImGui.CalcTextSize(Icons.Submenu), textY, arrowColor, Icons.Submenu)

    local trackLeft, trackRight = left + SLIDER_ARROW, right - SLIDER_ARROW
    local trackWidth = trackRight - trackLeft
    local valueWidth = ImGui.CalcTextSize(display)
    local hasTrack = ratio ~= nil
    local valueY = hasTrack and textY - 3 or textY
    Draw.Text(drawList, trackLeft + (trackWidth - valueWidth) * 0.5, valueY, Style.Text, display)

    if hasTrack then
        local trackY = data.Y + data.Height - 8
        local fill = trackWidth * math.max(0, math.min(1, ratio))
        Draw.RectFilled(drawList, trackLeft, trackY, trackWidth, TRACK_HEIGHT, Style.Border, 1)
        Draw.RectFilled(drawList, trackLeft, trackY, fill, TRACK_HEIGHT, Animation.LerpColor(Style.TextDisabled, Style.Accent, 0.5 + focus * 0.5), 1)
        Draw.RectFilled(drawList, trackLeft + fill - KNOB_SIZE * 0.5, trackY - (KNOB_SIZE - TRACK_HEIGHT) * 0.5, KNOB_SIZE, KNOB_SIZE,
            Animation.LerpColor(Style.TextDisabled, Style.Text, focus), KNOB_SIZE * 0.5)
    end

    if not clicked or not data.Hovered then return controlWidth end
    local mouseX = Mouse.GetPosition()
    if mouseX <= trackLeft then
        data.ValueDirection = -1
    elseif mouseX >= trackRight then
        data.ValueDirection = 1
    elseif hasTrack and mouseX >= left then
        data.ValueRatio = (mouseX - trackLeft) / trackWidth
    end
    return controlWidth
end

function Button.Draw(label, tip, rightText, id, valueControl, ratio)
    local data = Widget.Begin(true)
    if not data.Visible then return false, data end

    local clicked = Widget.Prepare(data, tip, id or label)
    local drawList = ImGui.GetWindowDrawList()
    local textY = Widget.GetTextY(data)
    local focus = Animation.Value("button:" .. tostring(id or label),
        (data.Selected or data.Hovered) and 1 or 0, 18, Context.DeltaTime, 0)
    local textColor = Animation.LerpColor(Style.TextDisabled, Style.Text, 0.72 + (focus * 0.28))
    local labelX = data.X + ButtonStyle.Padding + (focus * 2)
    local labelWidth = data.Width - (ButtonStyle.Padding * 2)
    local display = rightText and tostring(rightText) or ""

    if display ~= "" then
        if valueControl then
            labelWidth = labelWidth - DrawSlider(drawList, data, display, ratio, focus, clicked, textY) - 12
        else
            local width = ImGui.CalcTextSize(display)
            labelWidth = labelWidth - width - 12
            Draw.Text(drawList, data.X + data.Width - ButtonStyle.Padding - width, textY,
                Animation.LerpColor(Style.TextDisabled, Style.Accent, focus), display)
        end
    end
    Draw.Text(drawList, labelX, textY, textColor, Draw.FitText(label, labelWidth))

    return Widget.IsActivated(data, clicked), data
end

function Button.DrawValue(label, tip, value, id, ratio)
    return Button.Draw(label, tip, value, id, true, ratio)
end

return Button
