local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
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

function SidePanel.SubmitInfo(id, info, options)
    info = info or {}
    local rows = info.Rows or info.rows or {}
    local description = info.Description or info.description
    options = options or {}
    local width = options.Width or options.width or 300
    if not options.Height and not options.height then
        local descriptionHeight = 0
        if description and description ~= "" then
            local lineWidth, lines = 0, 1
            for word in tostring(description):gmatch("%S+") do
                local wordWidth = ImGui.CalcTextSize(word .. " ")
                if lineWidth > 0 and lineWidth + wordWidth > width - 28 then
                    lines, lineWidth = lines + 1, wordWidth
                else
                    lineWidth = lineWidth + wordWidth
                end
            end
            descriptionHeight = 24 + (lines * ImGui.GetTextLineHeight())
        end
        local needed = 68 + (#rows * 21) + descriptionHeight
        options.Height = math.max(110, math.min(Context.Bounds.Height, needed))
    end

    SidePanel.Submit(id, function()
        TextColored(Style.Accent, tostring(info.Eyebrow or info.eyebrow or "DATABASE ENTRY"))
        ImGui.Text(Draw.FitText(info.Title or info.title or "Unknown", width - 28))
        ImGui.Separator()
        for _, row in ipairs(rows) do
            local cursorX, cursorY = ImGui.GetCursorScreenPos()
            TextColored(Style.TextDisabled, tostring(row.Label or row.label or ""))
            ImGui.SetCursorScreenPos(cursorX + 96, cursorY)
            ImGui.Text(Draw.FitText(row.Value or row.value or "--", width - 124))
            ImGui.SetCursorScreenPos(cursorX, cursorY + ImGui.GetTextLineHeight() + 4)
        end
        if description and description ~= "" then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.PushTextWrapPos(width - 18)
            TextColored(Style.TextDisabled, tostring(description))
            ImGui.PopTextWrapPos()
        end
    end, options)
end

function SidePanel.GetSubmitted()
    return SidePanel.Submitted
end

function SidePanel.Draw()
    local bounds = Context.Bounds
    local screenWidth = GetDisplayResolution()
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
            state.DisplayHeight = Animation.Animate(state.DisplayHeight or math.min(120, state.Height),
                state.Height, 16, dt)
            local targetX = bounds.X + bounds.Width + 10
            if targetX + state.Width > screenWidth then targetX = bounds.X - state.Width - 10 end
            if state.X == nil then state.X = targetX + (targetX > bounds.X and 26 or -26) end
            state.X = Animation.Animate(state.X, targetX, 18, dt)
            local y = bounds.Y + ((state.Row or 0) * (state.DisplayHeight + 8))

            ImGui.SetNextWindowPos(state.X, y, ImGuiCond.Always)
            ImGui.SetNextWindowSize(state.Width, state.DisplayHeight, ImGuiCond.Always)
            ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, Layout.Rounding)
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, state.Alpha)
            ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
            ImGui.Begin("##EasyTrainerSidePanel" .. id, ImGuiWindowFlags.NoDecoration
                + ImGuiWindowFlags.NoSavedSettings + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
                + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse)
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
            ImGui.SetCursorScreenPos(x + 14, panelY + 12)
            if state.Draw then state.Draw() end
            ImGui.End()
            ImGui.PopStyleColor()
            ImGui.PopStyleVar(2)
        end
    end
    for _, id in ipairs(remove) do SidePanel.States[id] = nil end
end

return SidePanel
