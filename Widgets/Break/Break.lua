local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local BreakStyle = require("Widgets/Break/BreakStyle")

local Break = {}

Break.Align = {
    Left = "Left",
    Center = "Center",
    Right = "Right"
}

function Break.Draw(text, align)
    align = align or Break.Align.Left

    local index = Navigation.NextBreak()
    local content = Navigation.Content()

    local y = Navigation.RowY(index)
    local height = Scale.S(Layout.OptionHeight)
    if y + height <= content.Y or y >= content.Y + content.Height then return end

    local padding = Scale.S(Layout.Padding)
    local left = content.X + padding
    local right = content.X + content.Width - padding
    local size = Scale.FontSize() * BreakStyle.TextScale
    local centerY = y + (height * 0.5) + Scale.S(BreakStyle.OffsetY)

    local lineColor = Draw.ScaleAlpha(Style.Border, BreakStyle.LineAlpha)
    local gap = Scale.S(BreakStyle.LineGap)

    local label = tostring(text or "")

    if label == "" then
        if BreakStyle.ShowLine then Draw.Line(left, centerY, right, centerY, lineColor, 1) end
        return
    end

    local textWidth, textHeight = Draw.TextSize(label, size)

    local textX = left
    if align == Break.Align.Center then
        textX = left + ((right - left - textWidth) * 0.5)
    elseif align == Break.Align.Right then
        textX = right - textWidth
    end

    Draw.Text(textX, centerY - (textHeight * 0.5), Style.TextDisabled, label, size)

    if not BreakStyle.ShowLine then return end

    if align ~= Break.Align.Left and textX - gap > left then
        Draw.Line(left, centerY, textX - gap, centerY, lineColor, 1)
    end

    if align ~= Break.Align.Right and textX + textWidth + gap < right then
        Draw.Line(textX + textWidth + gap, centerY, right, centerY, lineColor, 1)
    end
end

return Break
