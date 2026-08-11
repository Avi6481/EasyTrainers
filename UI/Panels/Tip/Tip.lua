local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local Tip = {
    SubmittedText = nil,
    SubmittedSource = nil,
    Writer = Animation.CreateTypewriter(),
    Alpha = 0,
    MissingTime = 0,
}

local function TextColored(color, text)
    local value = ImGui.ColorConvertU32ToFloat4(color)
    ImGui.TextColored(value[1], value[2], value[3], value[4], text)
end

local function EstimateHeight(text, width)
    local lines = 0
    for rawLine in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local lineWidth = 0
        lines = lines + 1
        for word in rawLine:gmatch("%S+") do
            local wordWidth = ImGui.CalcTextSize(word .. " ")
            if lineWidth > 0 and lineWidth + wordWidth > width then
                lines = lines + 1
                lineWidth = wordWidth
            else
                lineWidth = lineWidth + wordWidth
            end
        end
    end
    return math.max(38, (lines * ImGui.GetTextLineHeight()) + 26)
end

function Tip.Initialize()
    Tip.SubmittedText = nil
    Tip.SubmittedSource = nil
    Tip.Writer = Animation.CreateTypewriter()
    Tip.Alpha = 0
    Tip.MissingTime = 0
end

function Tip.BeginFrame()
    Tip.SubmittedText = nil
    Tip.SubmittedSource = nil
end

function Tip.Set(text, source)
    text = tostring(text or "")
    if text == "" then return end
    Tip.SubmittedText = text
    Tip.SubmittedSource = source
end

function Tip.Clear(source)
    if source == nil or source == Tip.SubmittedSource then
        Tip.SubmittedText = nil
        Tip.SubmittedSource = nil
    end
end

function Tip.Draw()
    local dt = Context.DeltaTime
    if Tip.SubmittedText then
        Animation.SetText(Tip.Writer, Tip.SubmittedText)
        Tip.MissingTime = 0
    else
        Tip.MissingTime = Tip.MissingTime + dt
    end

    local target = (Tip.SubmittedText or (Tip.Writer.Current ~= "" and Tip.MissingTime < 0.18)) and 1 or 0
    Tip.Alpha = Animation.Animate(Tip.Alpha, target, 14, dt)
    if Tip.Alpha < 0.01 then
        if target == 0 then Tip.Writer = Animation.CreateTypewriter() end
        return
    end

    Animation.UpdateTypewriter(Tip.Writer, dt, 52)
    local displayed = Tip.Writer.Displayed
    if Animation.CursorVisible(Tip.Writer) then displayed = displayed .. "|" end

    local bounds = Context.Bounds
    local gap, padding = 8, 12
    local height = EstimateHeight(Tip.Writer.Current, bounds.Width - (padding * 2))
    local _, screenHeight = GetDisplayResolution()
    local y = bounds.Y + bounds.Height + gap
    if y + height > screenHeight then y = bounds.Y - height - gap end

    ImGui.SetNextWindowPos(bounds.X, y, ImGuiCond.Always)
    ImGui.SetNextWindowSize(bounds.Width, height, ImGuiCond.Always)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, Layout.Rounding)
    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, Tip.Alpha)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.Begin("##EasyTrainerTip", ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoInputs
        + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        + ImGuiWindowFlags.NoSavedSettings)

    local x, windowY = ImGui.GetWindowPos()
    local drawList = ImGui.GetWindowDrawList()
    Draw.RectFilled(drawList, x + 2, windowY + 2, bounds.Width - 4, height - 4,
        Animation.WithAlpha(Style.Shadow, Tip.Alpha), Layout.Rounding)
    Draw.RectFilled(drawList, x + 1, windowY + 1, bounds.Width - 2, height - 2,
        Animation.WithAlpha(Style.BackgroundLight, Tip.Alpha), Layout.Rounding)
    Draw.LeftAccent(drawList, x + 1, windowY + 1, height - 2,
        Animation.WithAlpha(Style.Accent, Tip.Alpha), Layout.Rounding, 3)
    ImGui.SetCursorScreenPos(x + padding, windowY + 11)
    ImGui.PushTextWrapPos(bounds.Width - padding)
    TextColored(Style.TextDisabled, displayed)
    ImGui.PopTextWrapPos()
    ImGui.End()
    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)
end

return Tip
