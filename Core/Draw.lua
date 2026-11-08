local Draw = {}

Draw.Corners = {
    All = 0,
    TopLeft = 16,
    TopRight = 32,
    BottomLeft = 64,
    BottomRight = 128,
    Top = 48,
    Bottom = 192,
    Left = 80,
    Right = 160
}

local s_List = nil
local s_Alpha = 1
local s_FlagsSupported = nil
local s_ClipDepth = 0

function Draw.RGBA(r, g, b, a)
    return ((a or 255) * 0x1000000) + (b * 0x10000) + (g * 0x100) + r
end

function Draw.Alpha(color)
    return math.floor(color / 0x1000000) % 256
end

function Draw.Channels(color)
    return color % 256, math.floor(color / 0x100) % 256, math.floor(color / 0x10000) % 256, Draw.Alpha(color)
end

function Draw.ToColorTable(color, target)
    local r, g, b, a = Draw.Channels(color)
    target = target or {}
    target.R, target.G, target.B, target.A = r / 255, g / 255, b / 255, a / 255
    return target
end

function Draw.FromColorTable(color)
    local function Byte(value)
        return math.floor(math.max(0, math.min(1, value or 1)) * 255 + 0.5)
    end
    return Draw.RGBA(Byte(color.R), Byte(color.G), Byte(color.B), Byte(color.A))
end

function Draw.ScaleAlpha(color, scale)
    local alpha = math.floor(Draw.Alpha(color) * math.max(0, math.min(1, scale)))
    return (color % 0x1000000) + (alpha * 0x1000000)
end

function Draw.WithAlpha(color, alpha)
    local value = math.floor(math.max(0, math.min(1, alpha)) * 255)
    return (color % 0x1000000) + (value * 0x1000000)
end

function Draw.Opaque(color)
    return (color % 0x1000000) + (255 * 0x1000000)
end

local function Fade(color)
    if s_Alpha >= 0.999 then return color end
    return Draw.ScaleAlpha(color, s_Alpha)
end

function Draw.Refresh()
    s_List = ImGui.GetWindowDrawList()
end

function Draw.SetAlpha(alpha)
    s_Alpha = math.max(0, math.min(1, alpha or 1))
end

function Draw.GetAlpha()
    return s_Alpha
end

function Draw.PushClip(x, y, w, h)
    ImGui.PushClipRect(x, y, x + math.max(0, w), y + math.max(0, h), true)
    s_ClipDepth = s_ClipDepth + 1
end

function Draw.PopClip()
    if s_ClipDepth <= 0 then return end
    ImGui.PopClipRect()
    s_ClipDepth = s_ClipDepth - 1
end

function Draw.UnwindClips()
    while s_ClipDepth > 0 do Draw.PopClip() end
end

local WINDOW_FLAGS = ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoMove
    + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoSavedSettings + ImGuiWindowFlags.NoScrollbar
    + ImGuiWindowFlags.NoScrollWithMouse + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoBringToFrontOnFocus

function Draw.BeginWindow(name, x, y, w, h)
    ImGui.SetNextWindowPos(x, y, ImGuiCond.Always)
    ImGui.SetNextWindowSize(math.max(1, w), math.max(1, h), ImGuiCond.Always)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)

    if not ImGui.Begin(name, WINDOW_FLAGS) then return false end

    Draw.Refresh()
    ImGui.PushClipRect(x, y, x + w, y + h, false)
    s_ClipDepth = s_ClipDepth + 1
    return true
end

function Draw.EndWindow()
    Draw.UnwindClips()
    ImGui.End()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(1)
end

local function RoundedPart(x, y, w, h, color, rounding, flags)
    local top = flags == Draw.Corners.Top
    local bottom = flags == Draw.Corners.Bottom
    local left = flags == Draw.Corners.Left
    local right = flags == Draw.Corners.Right

    if top then
        Draw.PushClip(x, y, w, h)
        ImGui.ImDrawListAddRectFilled(s_List, x, y, x + w, y + h + rounding, color, rounding)
        Draw.PopClip()
    elseif bottom then
        Draw.PushClip(x, y, w, h)
        ImGui.ImDrawListAddRectFilled(s_List, x, y - rounding, x + w, y + h, color, rounding)
        Draw.PopClip()
    elseif left then
        Draw.PushClip(x, y, w, h)
        ImGui.ImDrawListAddRectFilled(s_List, x, y, x + w + rounding, y + h, color, rounding)
        Draw.PopClip()
    elseif right then
        Draw.PushClip(x, y, w, h)
        ImGui.ImDrawListAddRectFilled(s_List, x - rounding, y, x + w, y + h, color, rounding)
        Draw.PopClip()
    else
        ImGui.ImDrawListAddRectFilled(s_List, x, y, x + w, y + h, color, rounding)
    end
end

function Draw.RectFilled(x, y, w, h, color, rounding, flags)
    if w <= 0 or h <= 0 then return end
    rounding = rounding or 0
    color = Fade(color)

    if not flags or flags == 0 or rounding <= 0 then
        ImGui.ImDrawListAddRectFilled(s_List, x, y, x + w, y + h, color, rounding)
        return
    end

    if s_FlagsSupported == nil then
        s_FlagsSupported = pcall(ImGui.ImDrawListAddRectFilled, s_List, x, y, x + w, y + h, color, rounding, flags)
        if s_FlagsSupported then return end
    end

    if s_FlagsSupported then
        ImGui.ImDrawListAddRectFilled(s_List, x, y, x + w, y + h, color, rounding, flags)
        return
    end

    RoundedPart(x, y, w, h, color, rounding, flags)
end

function Draw.Rect(x, y, w, h, color, rounding, flags, thickness)
    thickness = thickness or 1
    local inset = thickness * 0.5
    ImGui.ImDrawListAddRect(s_List, x + inset, y + inset, x + w - inset, y + h - inset, Fade(color), math.max(0, (rounding or 0) - inset), flags or 0, thickness)
end

function Draw.Gradient(x, y, w, h, topLeft, topRight, bottomRight, bottomLeft)
    if w <= 0 or h <= 0 then return end
    ImGui.ImDrawListAddRectFilledMultiColor(s_List, x, y, x + w, y + h, Fade(topLeft), Fade(topRight), Fade(bottomRight), Fade(bottomLeft))
end

function Draw.LeftAccent(x, y, h, color, rounding, thickness)
    thickness = thickness or 3
    local radius = math.max(0, math.min(rounding or 0, h * 0.5))
    local rows = math.floor(radius)
    if rows == 0 then
        Draw.RectFilled(x, y, thickness, h, color)
        return
    end

    Draw.RectFilled(x, y + rows, thickness, h - (rows * 2), color)
    for row = 0, rows - 1 do
        local distance = radius - row - 0.5
        local inset = radius - math.sqrt(math.max(0, (radius * radius) - (distance * distance)))
        Draw.RectFilled(x + inset, y + row, thickness, 1, color)
        Draw.RectFilled(x + inset, y + h - row - 1, thickness, 1, color)
    end
end

function Draw.Line(x1, y1, x2, y2, color, thickness)
    ImGui.ImDrawListAddLine(s_List, x1, y1, x2, y2, Fade(color), thickness or 1)
end

function Draw.Circle(x, y, radius, color, thickness)
    if radius <= 0 then return end
    ImGui.ImDrawListAddCircle(s_List, x, y, radius, Fade(color), 0, thickness or 1)
end

function Draw.CircleFilled(x, y, radius, color)
    if radius <= 0 then return end
    ImGui.ImDrawListAddCircleFilled(s_List, x, y, radius, Fade(color))
end

function Draw.Arc(x, y, radius, startAngle, endAngle, color, thickness)
    local span = endAngle - startAngle
    if math.abs(span) < 0.001 or radius <= 0 then return end

    local segments = math.max(6, math.floor(math.abs(span) * radius * 0.6))
    local faded = Fade(color)
    local previousX = x + (math.cos(startAngle) * radius)
    local previousY = y + (math.sin(startAngle) * radius)

    for index = 1, segments do
        local angle = startAngle + (span * (index / segments))
        local nextX = x + (math.cos(angle) * radius)
        local nextY = y + (math.sin(angle) * radius)
        ImGui.ImDrawListAddLine(s_List, previousX, previousY, nextX, nextY, faded, thickness or 1)
        previousX, previousY = nextX, nextY
    end
end

function Draw.TriangleFilled(ax, ay, bx, by, cx, cy, color)
    ImGui.ImDrawListAddTriangleFilled(s_List, ax, ay, bx, by, cx, cy, Fade(color))
end

function Draw.Chevron(cx, cy, size, direction, color, thickness)
    local half = size * 0.5
    local ax, ay, tx, ty, bx, by

    if direction == "Left" then
        ax, ay, tx, ty, bx, by = cx + half, cy - size, cx - half, cy, cx + half, cy + size
    elseif direction == "Up" then
        ax, ay, tx, ty, bx, by = cx - size, cy + half, cx, cy - half, cx + size, cy + half
    elseif direction == "Down" then
        ax, ay, tx, ty, bx, by = cx - size, cy - half, cx, cy + half, cx + size, cy - half
    else
        ax, ay, tx, ty, bx, by = cx - half, cy - size, cx + half, cy, cx - half, cy + size
    end

    Draw.Line(ax, ay, tx, ty, color, thickness)
    Draw.Line(tx, ty, bx, by, color, thickness)
end

function Draw.TextSize(text, size)
    text = tostring(text or "")
    local base = ImGui.GetFontSize()
    if base <= 0 then return 0, 0 end

    local width, height = ImGui.CalcTextSize(text)
    local scale = (size or base) / base
    return width * scale, height * scale
end

function Draw.Text(x, y, color, text, size)
    text = tostring(text or "")
    if text == "" then return end
    ImGui.ImDrawListAddText(s_List, size or ImGui.GetFontSize(), x, y, Fade(color), text)
end

function Draw.TextCentered(x, y, w, h, color, text, size)
    local width, height = Draw.TextSize(text, size)
    Draw.Text(x + ((w - width) * 0.5), y + ((h - height) * 0.5), color, text, size)
end

local function SplitLongWord(word, width, size, lines)
    local current = ""
    for character in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if current ~= "" and Draw.TextSize(current .. character, size) > width then
            table.insert(lines, current)
            current = character
        else
            current = current .. character
        end
    end
    return current
end

function Draw.WrapLines(text, width, size)
    local lines = {}
    for paragraph in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local current = ""
        for word in paragraph:gmatch("%S+") do
            local candidate = current == "" and word or (current .. " " .. word)
            if Draw.TextSize(candidate, size) <= width then
                current = candidate
            elseif current == "" then
                current = SplitLongWord(word, width, size, lines)
            else
                table.insert(lines, current)
                if Draw.TextSize(word, size) > width then
                    current = SplitLongWord(word, width, size, lines)
                else
                    current = word
                end
            end
        end
        table.insert(lines, current)
    end
    return lines
end

function Draw.WrapHeight(text, width, size)
    local _, lineHeight = Draw.TextSize("Ag", size)
    return #Draw.WrapLines(text, width, size) * lineHeight
end

function Draw.TextWrapped(x, y, width, color, text, size)
    local _, lineHeight = Draw.TextSize("Ag", size)
    for index, line in ipairs(Draw.WrapLines(text, width, size)) do
        Draw.Text(x, y + ((index - 1) * lineHeight), color, line, size)
    end
end

function Draw.FitText(text, maxWidth, size)
    text = tostring(text or "")
    if maxWidth <= 0 then return "" end
    if Draw.TextSize(text, size) <= maxWidth then return text end

    local fitted = ""
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if Draw.TextSize(fitted .. character .. "...", size) > maxWidth then break end
        fitted = fitted .. character
    end
    return fitted .. "..."
end

return Draw
