local Button = {}

local Draw = require("UI/Core/Draw")
local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Widget = require("UI/Widgets/Core/Widget")
local ButtonStyle = require("UI/Widgets/Button/ButtonStyle")
local Style = require("UI/Style/Style")

function Button.Create(label, tip, action)
    return { Kind = "button", Label = label, Tip = tip or "", Action = action }
end

function Button.Draw(label, tip, rightText, id, valueControl)
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
    if rightText and rightText ~= "" then
        local valueWidth = ImGui.CalcTextSize(tostring(rightText))
        labelWidth = labelWidth - (valueControl and math.max(88, valueWidth + 52) or valueWidth) - 12
    end
    Draw.Text(drawList, labelX, textY, textColor, Draw.FitText(label, labelWidth))

    if rightText and rightText ~= "" then
        local display = tostring(rightText)
        local width = ImGui.CalcTextSize(display)
        local rightColor = Animation.LerpColor(Style.TextDisabled, Style.Accent, focus)
        if valueControl then
            local controlWidth = math.max(88, width + 52)
            local capsuleX = data.X + data.Width - ButtonStyle.Padding - controlWidth
            local capsuleY = data.Y + 4
            local capsuleHeight = data.Height - 8
            Draw.RectFilled(drawList, capsuleX, capsuleY, controlWidth, capsuleHeight,
                Style.BackgroundDark, 5)
            Draw.Rect(drawList, capsuleX, capsuleY, controlWidth, capsuleHeight,
                Animation.LerpColor(Style.Border, Style.Accent, focus), 5, 1)
            Draw.Line(drawList, capsuleX + 22, capsuleY + 3, capsuleX + 22,
                capsuleY + capsuleHeight - 3, Style.Border, 1)
            Draw.Line(drawList, capsuleX + controlWidth - 22, capsuleY + 3,
                capsuleX + controlWidth - 22, capsuleY + capsuleHeight - 3, Style.Border, 1)
            Draw.Text(drawList, capsuleX + 8, textY, rightColor, "<")
            Draw.Text(drawList, capsuleX + controlWidth - 15, textY, rightColor, ">")
            Draw.Text(drawList, capsuleX + ((controlWidth - width) * 0.5), textY, Style.Text, display)
            if clicked and data.Hovered then
                local mouseX = ImGui.GetMousePos()
                if mouseX <= capsuleX + 22 then
                    data.ValueDirection = -1
                elseif mouseX >= capsuleX + controlWidth - 22 then
                    data.ValueDirection = 1
                end
            end
        else
            local rightX = data.X + data.Width - ButtonStyle.Padding - width
            Draw.Text(drawList, rightX, textY, rightColor, display)
        end
    end

    return Widget.IsActivated(data, clicked), data
end

function Button.DrawValue(label, tip, value, id)
    return Button.Draw(label, tip, value, id, true)
end

return Button

