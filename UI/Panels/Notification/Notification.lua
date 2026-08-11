local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local Notification = { Queue = {}, NextId = 1, LastRenderAt = nil }

Notification.Position = {
    Auto = "auto", TopLeft = "top_left", TopCenter = "top_center", TopRight = "top_right",
    BottomLeft = "bottom_left", BottomCenter = "bottom_center", BottomRight = "bottom_right",
}

local KindColors = {
    info = Style.Accent,
    success = 0xFF8BD964,
    warning = 0xFF57C8FF,
    error = 0xFF7A66FF,
}

local function TextColored(color, text)
    local value = ImGui.ColorConvertU32ToFloat4(color)
    ImGui.TextColored(value[1], value[2], value[3], value[4], text)
end

local function NormalizePosition(position)
    return tostring(position or "auto"):gsub("(%l)(%u)", "%1_%2"):lower()
end

local function ResolveAutoPosition()
    local bounds = Context.Bounds
    local screenWidth, screenHeight = GetDisplayResolution()
    local onLeft = bounds.X + (bounds.Width * 0.5) < screenWidth * 0.5
    local onTop = bounds.Y + (bounds.Height * 0.5) < screenHeight * 0.5
    if onTop then return onLeft and "top_right" or "top_left" end
    return onLeft and "bottom_right" or "bottom_left"
end

function Notification.Push(text, options)
    options = options or {}
    local position = NormalizePosition(options.Position or options.position)
    if position == "auto" then position = ResolveAutoPosition() end
    local value = tostring(text or "")
    if value == "" then return nil end

    local entry = {
        Id = Notification.NextId,
        Text = value,
        Kind = tostring(options.Kind or options.kind or "info"):lower(),
        Duration = math.max(0.5, options.Duration or options.duration or 3),
        Position = position,
        CreatedAt = os.clock(),
        Alpha = 0,
        Slide = 1,
        Writer = Animation.CreateTypewriter(),
    }
    Animation.SetText(entry.Writer, value)
    Notification.NextId = Notification.NextId + 1
    table.insert(Notification.Queue, entry)
    return entry.Id
end

function Notification.Info(text, duration, position)
    return Notification.Push(text, { Kind = "info", Duration = duration, Position = position })
end

function Notification.Success(text, duration, position)
    return Notification.Push(text, { Kind = "success", Duration = duration, Position = position })
end

function Notification.Warning(text, duration, position)
    return Notification.Push(text, { Kind = "warning", Duration = duration, Position = position })
end

function Notification.Error(text, duration, position)
    return Notification.Push(text, { Kind = "error", Duration = duration, Position = position })
end

function Notification.Remove(id)
    for index, entry in ipairs(Notification.Queue) do
        if entry.Id == id then table.remove(Notification.Queue, index) return true end
    end
    return false
end

function Notification.Initialize()
    Notification.Queue = {}
    Notification.NextId = 1
    Notification.LastRenderAt = nil
end

local function EstimateHeight(text, width)
    local lineWidth, lines = 0, 1
    for word in text:gmatch("%S+") do
        local wordWidth = ImGui.CalcTextSize(word .. " ")
        if lineWidth > 0 and lineWidth + wordWidth > width then
            lines, lineWidth = lines + 1, wordWidth
        else
            lineWidth = lineWidth + wordWidth
        end
    end
    return math.max(62, (lines * ImGui.GetTextLineHeight()) + 42)
end

local function GetPosition(position, width, height, offset, slide)
    local screenWidth, screenHeight = GetDisplayResolution()
    local padding = 16
    local x = position:find("right", 1, true) and screenWidth - width - padding or padding
    if position:find("center", 1, true) then x = (screenWidth - width) * 0.5 end
    if position:find("left", 1, true) then x = x - (slide * 28) end
    if position:find("right", 1, true) then x = x + (slide * 28) end
    local y = position:find("bottom", 1, true)
        and screenHeight - height - padding - offset or padding + offset
    return x, y
end

function Notification.Render()
    local now, width = os.clock(), 320
    local dt = Notification.LastRenderAt and math.min(0.1, now - Notification.LastRenderAt) or (1 / 60)
    Notification.LastRenderAt = now
    local offsets = {}

    for index = #Notification.Queue, 1, -1 do
        local entry = Notification.Queue[index]
        local elapsed = now - entry.CreatedAt
        local remainingTime = entry.Duration - elapsed
        local target = remainingTime > 0.22 and 1 or 0
        entry.Alpha = Animation.Animate(entry.Alpha, target, 15, dt)
        entry.Slide = Animation.Animate(entry.Slide, target == 1 and 0 or 1, 17, dt)
        Animation.UpdateTypewriter(entry.Writer, dt, 64)

        if remainingTime <= 0 and entry.Alpha < 0.02 then
            table.remove(Notification.Queue, index)
        else
            local height = EstimateHeight(entry.Text, width - 28)
            local offset = offsets[entry.Position] or 0
            local x, y = GetPosition(entry.Position, width, height, offset, entry.Slide)
            local progress = math.max(0, math.min(1, remainingTime / entry.Duration))
            local accent = KindColors[entry.Kind] or Style.Accent

            ImGui.SetNextWindowPos(x, y, ImGuiCond.Always)
            ImGui.SetNextWindowSize(width, height, ImGuiCond.Always)
            ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, Layout.Rounding)
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, entry.Alpha)
            ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
            ImGui.Begin("##EasyTrainerNotification" .. entry.Id, ImGuiWindowFlags.NoDecoration
                + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoSavedSettings)
            local drawList = ImGui.GetWindowDrawList()
            Draw.RectFilled(drawList, x + 2, y + 2, width - 4, height - 4,
                Animation.WithAlpha(Style.Shadow, entry.Alpha), Layout.Rounding)
            Draw.RectFilled(drawList, x + 1, y + 1, width - 2, height - 2,
                Animation.WithAlpha(Style.BackgroundLight, entry.Alpha), Layout.Rounding)
            Draw.LeftAccent(drawList, x + 1, y + 1, height - 2,
                Animation.WithAlpha(accent, entry.Alpha), Layout.Rounding, 3)
            Draw.Rect(drawList, x + 1, y + 1, width - 2, height - 2,
                Animation.WithAlpha(Style.Border, entry.Alpha), Layout.Rounding, 1)
            Draw.RectFilled(drawList, x + 8, y + height - 5, (width - 16) * progress, 2,
                Animation.WithAlpha(accent, entry.Alpha), 1)
            ImGui.SetCursorScreenPos(x + 16, y + 10)
            TextColored(accent, entry.Kind:upper())
            ImGui.SetCursorScreenPos(x + 16, y + 28)
            ImGui.PushTextWrapPos(width - 14)
            TextColored(Style.Text, entry.Writer.Displayed)
            ImGui.PopTextWrapPos()
            ImGui.End()
            ImGui.PopStyleColor()
            ImGui.PopStyleVar(2)
            offsets[entry.Position] = offset + height + 8
        end
    end
end

return Notification
