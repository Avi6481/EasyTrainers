local Break = {}

local Draw = require("UI/Core/Draw")
local Context = require("UI/Core/Context")
local Widget = require("UI/Widgets/Core/Widget")
local BreakStyle = require("UI/Widgets/Break/BreakStyle")
local Style = require("UI/Style/Style")

function Break.Create(label, alignment)
    return { Kind = "break", Label = label or "", Alignment = alignment or "left" }
end

function Break.Draw(label, alignment)
    if Context.OptionCount == 0 then return nil end
    local data = Widget.Begin(false)
    if not data.Visible then return data end

    local drawList = ImGui.GetWindowDrawList()
    local text = tostring(label or "")
    local textY = Widget.GetTextY(data)
    local textWidth = ImGui.CalcTextSize(text)
    local textX = data.X + BreakStyle.Padding

    if alignment == "center" then
        textX = data.X + ((data.Width - textWidth) * 0.5)
    elseif alignment == "right" then
        textX = data.X + data.Width - BreakStyle.Padding - textWidth
    end

    local lineY = data.Y + (data.Height * 0.5)
    if text == "" then
        Draw.Line(drawList, data.X + BreakStyle.Padding, lineY,
            data.X + data.Width - BreakStyle.Padding, lineY, Style.Border, 1)
    elseif alignment == "center" then
        Draw.Line(drawList, data.X + BreakStyle.Padding, lineY, textX - 10, lineY, Style.Border, 1)
        Draw.Line(drawList, textX + textWidth + 10, lineY,
            data.X + data.Width - BreakStyle.Padding, lineY, Style.Border, 1)
        Draw.Text(drawList, textX, textY, Style.TextDisabled, text)
    elseif alignment == "right" then
        Draw.Line(drawList, data.X + BreakStyle.Padding, lineY, textX - 10, lineY, Style.Border, 1)
        Draw.Text(drawList, textX, textY, Style.TextDisabled, text)
    else
        Draw.Text(drawList, textX, textY, Style.TextDisabled, text)
        Draw.Line(drawList, textX + textWidth + 10, lineY,
            data.X + data.Width - BreakStyle.Padding, lineY, Style.Border, 1)
    end
    return data
end

return Break

