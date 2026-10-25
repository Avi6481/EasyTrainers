local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Icons = require("UI/Core/Icons")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local SidePanel = { Submitted = {}, States = {} }

local function TextColored(color, text)
    local value = ImGui.ColorConvertU32ToFloat4(color)
    ImGui.TextColored(value[1], value[2], value[3], value[4], text)
end

function SidePanel.Initialize()
    SidePanel.Submitted = {}
    SidePanel.States = {}
end

function SidePanel.BeginFrame()
    SidePanel.Submitted = {}
end

local PADDING = 14
local LABEL_WIDTH = 96
local SCREEN_MARGIN = 16

function SidePanel.Submit(id, draw, options)
    options = options or {}
    SidePanel.Submitted[tostring(id)] = {
        Id = tostring(id),
        Draw = draw,
        Width = math.max(280, options.Width or options.width or options.MinWidth or options.minWidth or 300),
        Height = math.max(100, options.Height or options.height or 220),
        Column = options.Column or options.column or 0,
        Row = options.Row or options.row or 0,
    }
end

local function Wrapped(color, text, width)
    ImGui.PushTextWrapPos(width - PADDING)
    if color then TextColored(color, text) else ImGui.Text(text) end
    ImGui.PopTextWrapPos()
end

local function NextLine(x)
    local _, y = ImGui.GetCursorScreenPos()
    ImGui.SetCursorScreenPos(x, y)
end

local function DrawRow(label, value, width)
    local x, y = ImGui.GetCursorScreenPos()
    local right = x + width - (PADDING * 2)
    local valueWidth = ImGui.CalcTextSize(value)

    TextColored(Style.TextDisabled, label)
    if x + LABEL_WIDTH + valueWidth <= right then
        ImGui.SetCursorScreenPos(right - valueWidth, y)
        ImGui.Text(value)
    else
        NextLine(x)
        Wrapped(nil, value, width)
    end
    NextLine(x)
end

local ICON_MAX_HEIGHT = 110

local function DrawIcon(recordID, width, maxHeight)
    local x, y = ImGui.GetCursorScreenPos()
    local iconWidth = Icons.GetSize(recordID, width - (PADDING * 2), maxHeight)
    if not iconWidth then return end
    ImGui.SetCursorScreenPos(x + ((width - (PADDING * 2)) - iconWidth) / 2, y + 4)
    if Icons.Draw(recordID, width - (PADDING * 2), maxHeight) then ImGui.Spacing() end
    NextLine(x)
end

function SidePanel.SubmitInfo(id, info, options)
    info = info or {}
    options = options or {}
    local rows = info.Rows or info.rows or {}
    local description = info.Description or info.description
    local width = options.Width or options.width or 300

    SidePanel.Submit(id, function()
        local x = ImGui.GetCursorScreenPos()
        TextColored(Style.Accent, tostring(info.Eyebrow or info.eyebrow or "DATABASE ENTRY"))
        NextLine(x)
        Wrapped(nil, tostring(info.Title or info.title or "Unknown"), width)
        NextLine(x)
        ImGui.Separator()
        NextLine(x)
        if info.Icon then DrawIcon(info.Icon, width, info.IconHeight or ICON_MAX_HEIGHT) end
        for _, row in ipairs(rows) do
            DrawRow(tostring(row.Label or row.label or ""), tostring(row.Value or row.value or "--"), width)
        end
        if description and description ~= "" then
            ImGui.Spacing()
            NextLine(x)
            ImGui.Separator()
            NextLine(x)
            Wrapped(Style.TextDisabled, tostring(description), width)
        end
    end, options)
end

local SWATCH_HEIGHT = 46

local function DrawSwatch(swatch, width)
    local x, y = ImGui.GetCursorScreenPos()
    local swatchWidth = width - (PADDING * 2)
    local drawList = ImGui.GetWindowDrawList()
    Draw.RectFilled(drawList, x, y, swatchWidth, SWATCH_HEIGHT, swatch.Color, Layout.Rounding)
    Draw.Rect(drawList, x, y, swatchWidth, SWATCH_HEIGHT, Style.Border, Layout.Rounding, 1)
    ImGui.Dummy(swatchWidth, SWATCH_HEIGHT)
    NextLine(x)
    DrawRow(tostring(swatch.Label or ""), tostring(swatch.Value or ""), width)
end

function SidePanel.SubmitSwatches(id, info, options)
    info = info or {}
    options = options or {}
    local width = options.Width or options.width or 300

    SidePanel.Submit(id, function()
        local x = ImGui.GetCursorScreenPos()
        TextColored(Style.Accent, tostring(info.Eyebrow or "COLOR SWATCH"))
        NextLine(x)
        Wrapped(nil, tostring(info.Title or "Colors"), width)
        NextLine(x)
        ImGui.Separator()
        NextLine(x)
        for _, swatch in ipairs(info.Swatches or {}) do
            ImGui.Spacing()
            NextLine(x)
            DrawSwatch(swatch, width)
        end
    end, options)
end

function SidePanel.GetSubmitted()
    return SidePanel.Submitted
end

function SidePanel.Draw()
    local bounds = Context.Bounds
    local screenWidth, screenHeight = GetDisplayResolution()
    local dt = Context.DeltaTime

    for id, state in pairs(SidePanel.States) do state.Alive = false end
    for id, panel in pairs(SidePanel.Submitted) do
        local state = SidePanel.States[id] or { Alpha = 0, X = nil }
        for key, value in pairs(panel) do state[key] = value end
        state.Alive = true
        SidePanel.States[id] = state
    end

    local remove = {}
    for id, state in pairs(SidePanel.States) do
        local targetAlpha = state.Alive and 1 or 0
        state.Alpha = Animation.Animate(state.Alpha, targetAlpha, 14, dt)
        if not state.Alive and state.Alpha < 0.01 then
            table.insert(remove, id)
        else
            local y = bounds.Y + ((state.Row or 0) * ((state.DisplayHeight or state.Height) + 8))
            local targetHeight = math.min(state.MeasuredHeight or state.Height, screenHeight - y - SCREEN_MARGIN)
            state.DisplayHeight = Animation.Animate(state.DisplayHeight or math.min(120, targetHeight), targetHeight, 16, dt)
            local targetX = bounds.X + bounds.Width + 10
            if targetX + state.Width > screenWidth then targetX = bounds.X - state.Width - 10 end
            if state.X == nil then state.X = targetX + (targetX > bounds.X and 26 or -26) end
            state.X = Animation.Animate(state.X, targetX, 18, dt)

            ImGui.SetNextWindowPos(state.X, y, ImGuiCond.Always)
            ImGui.SetNextWindowSize(state.Width, state.DisplayHeight, ImGuiCond.Always)
            ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, Layout.Rounding)
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, state.Alpha)
            ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
            ImGui.Begin("##EasyTrainerSidePanel" .. id, ImGuiWindowFlags.NoDecoration
                + ImGuiWindowFlags.NoSavedSettings + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
                + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse)
            Layout.ApplyFontScale()
            local x, panelY = ImGui.GetWindowPos()
            local drawList = ImGui.GetWindowDrawList()
            Draw.RectFilled(drawList, x + 2, panelY + 2, state.Width - 4, state.DisplayHeight - 4,
                Animation.WithAlpha(Style.Shadow, state.Alpha), Layout.Rounding)
            Draw.RectFilled(drawList, x + 1, panelY + 1, state.Width - 2, state.DisplayHeight - 2,
                Animation.WithAlpha(Style.BackgroundLight, state.Alpha), Layout.Rounding)
            Draw.LeftAccent(drawList, x + 1, panelY + 1, state.DisplayHeight - 2,
                Animation.WithAlpha(Style.Accent, state.Alpha), Layout.Rounding, 3)
            Draw.Rect(drawList, x + 1, panelY + 1, state.Width - 2, state.DisplayHeight - 2,
                Animation.WithAlpha(Style.Border, state.Alpha), Layout.Rounding, 1)
            ImGui.SetCursorScreenPos(x + PADDING, panelY + 12)
            if state.Draw then state.Draw() end
            local _, contentBottom = ImGui.GetCursorScreenPos()
            state.MeasuredHeight = math.max(100, contentBottom - panelY + 8)
            ImGui.End()
            ImGui.PopStyleColor()
            ImGui.PopStyleVar(2)
        end
    end
    for _, id in ipairs(remove) do SidePanel.States[id] = nil end
end

return SidePanel
