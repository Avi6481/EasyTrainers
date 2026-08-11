local Toggle = {}

local Draw = require("UI/Core/Draw")
local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Widget = require("UI/Widgets/Core/Widget")
local ToggleStyle = require("UI/Widgets/Toggle/ToggleStyle")
local Style = require("UI/Style/Style")

function Toggle.Create(label, valueRef, tip, action)
    return { Kind = "toggle", Label = label, Value = valueRef, Tip = tip or "", Action = action }
end

function Toggle.Draw(label, valueRef, tip, id)
    local data = Widget.Begin(true)
    if not data.Visible then return false, data end

    local clicked = Widget.Prepare(data, tip, id or label)
    local activated = Widget.IsActivated(data, clicked)
    if activated then valueRef.value = not valueRef.value end

    local drawList = ImGui.GetWindowDrawList()
    local textY = Widget.GetTextY(data)
    Draw.Text(drawList, data.X + ToggleStyle.Padding, textY, Style.Text, label)

    local size = ToggleStyle.Size
    local boxX = data.X + data.Width - ToggleStyle.Padding - size
    local boxY = data.Y + ((data.Height - size) * 0.5)
    local amount = Animation.Value("toggle:" .. tostring(id or label), valueRef.value and 1 or 0,
        20, Context.DeltaTime, valueRef.value and 1 or 0)
    Draw.Rect(drawList, boxX, boxY, size, size,
        Animation.LerpColor(Style.Border, Style.Accent, amount), ToggleStyle.Rounding, 1)
    if amount > 0.01 then
        local fillSize = (size - (ToggleStyle.Inset * 2)) * amount
        local fillX = boxX + ((size - fillSize) * 0.5)
        local fillY = boxY + ((size - fillSize) * 0.5)
        Draw.RectFilled(drawList, fillX, fillY, fillSize, fillSize,
            Animation.WithAlpha(Style.Accent, amount), ToggleStyle.Rounding)
    end

    return activated, data
end

return Toggle

