local Draw = { Alpha = 1 }

local function ApplyAlpha(color)
    if Draw.Alpha >= 0.999 then return color end
    local baseAlpha = math.floor(color / 0x1000000) % 0x100
    return (color % 0x1000000) + (math.floor(baseAlpha * Draw.Alpha) * 0x1000000)
end

function Draw.SetAlpha(alpha)
    Draw.Alpha = math.max(0, math.min(1, alpha or 1))
end

function Draw.RectFilled(drawList, x, y, width, height, color, rounding)
    ImGui.ImDrawListAddRectFilled(drawList, x, y, x + width, y + height, ApplyAlpha(color), rounding or 0)
end

function Draw.Rect(drawList, x, y, width, height, color, rounding, thickness)
    ImGui.ImDrawListAddRect(drawList, x, y, x + width, y + height, ApplyAlpha(color), rounding or 0, 0, thickness or 1)
end

function Draw.Line(drawList, x1, y1, x2, y2, color, thickness)
    ImGui.ImDrawListAddLine(drawList, x1, y1, x2, y2, ApplyAlpha(color), thickness or 1)
end

function Draw.Text(drawList, x, y, color, text, fontSize)
    if fontSize then
        ImGui.ImDrawListAddText(drawList, fontSize, x, y, ApplyAlpha(color), text or "")
    else
        ImGui.ImDrawListAddText(drawList, x, y, ApplyAlpha(color), text or "")
    end
end

function Draw.FitText(text, maximumWidth)
    text = tostring(text or "")
    if maximumWidth <= 0 then return "" end
    if ImGui.CalcTextSize(text) <= maximumWidth then return text end

    local fitted = ""
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if ImGui.CalcTextSize(fitted .. character .. "...") > maximumWidth then break end
        fitted = fitted .. character
    end
    return fitted .. "..."
end

function Draw.LeftAccent(drawList, x, y, height, color, rounding, thickness)
    local radius = math.max(0, math.min(rounding or 0, height * 0.5))
    local size = thickness or 3
    local rows = math.floor(radius)
    if rows == 0 then
        Draw.RectFilled(drawList, x, y, size, height, color, 0)
        return
    end

    Draw.RectFilled(drawList, x, y + rows, size, height - (rows * 2), color, 0)
    for row = 0, rows - 1 do
        local distance = radius - row - 0.5
        local inset = radius - math.sqrt(math.max(0, (radius * radius) - (distance * distance)))
        Draw.RectFilled(drawList, x + inset, y + row, size, 1, color, 0)
        Draw.RectFilled(drawList, x + inset, y + height - row - 1, size, 1, color, 0)
    end
end

return Draw
