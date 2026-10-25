local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Style = require("UI/Style/Style")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Logger = require("Core/Logger")

local TeleportMap = {}

local MAP = require("Assets/Map/NightCity")
local SIZE = 352
local PANEL_WIDTH = SIZE + 28
local FOCUS_SPAN = 800
local MIN_SPAN = 450
local MAX_SPAN = math.min(MAP.MaxX - MAP.MinX, MAP.MaxY - MAP.MinY)
local ZOOM_SPEED = 7
local DOT_LIMIT = 1500

local PIN = 0xFF5050FF
local PLAYER = 0xFF4AD2FF
local DOT = 0xC8E6C878
local OUTLINE = 0xFF000000

local s_Texture = nil
local s_View = nil
local s_Fit = { X = -800, Y = -500, Span = 9000 }
local s_Points = {}
local s_Caption = ""
local s_Focus = nil
local s_FocusFrame = -1

local function Texture()
    if s_Texture ~= nil then return s_Texture or nil end
    local texture, err = ImGui.LoadTexture(MAP.File)
    s_Texture = texture or false
    if not texture then Logger.Log("TeleportMap: " .. tostring(err or "failed to load " .. MAP.File)) end
    return texture
end

local function Percentile(sorted, fraction)
    return sorted[math.max(1, math.min(#sorted, math.floor(#sorted * fraction + 0.5)))]
end

local function Clamp(view)
    local half = view.Span / 2
    view.X = math.max(MAP.MinX + half, math.min(MAP.MaxX - half, view.X))
    view.Y = math.max(MAP.MinY + half, math.min(MAP.MaxY - half, view.Y))
    return view
end

function TeleportMap.SetPoints(locations, caption)
    s_Points, s_Caption = {}, caption or ""
    local xs, ys = {}, {}
    for _, location in ipairs(locations or {}) do
        local position = location.position or location
        if position and position.x and position.y and position.x >= MAP.MinX and position.x <= MAP.MaxX and position.y >= MAP.MinY and position.y <= MAP.MaxY then
            table.insert(s_Points, position)
            table.insert(xs, position.x)
            table.insert(ys, position.y)
        end
    end
    if #xs == 0 then return end

    table.sort(xs)
    table.sort(ys)
    local trim = #xs >= 20 and 0.04 or 0
    local minX, maxX = Percentile(xs, trim), Percentile(xs, 1 - trim)
    local minY, maxY = Percentile(ys, trim), Percentile(ys, 1 - trim)
    local span = math.max(MIN_SPAN, math.min(MAX_SPAN, math.max(maxX - minX, maxY - minY) * 1.2 + 250))
    s_Fit = Clamp({ X = (minX + maxX) / 2, Y = (minY + maxY) / 2, Span = span })
end

function TeleportMap.Focus(position, label)
    if not position then return end
    s_Focus = { X = position.x, Y = position.y, Label = label }
    s_FocusFrame = Context.Frame
end

local function Target()
    if s_Focus and s_FocusFrame >= Context.Frame - 1 then
        return Clamp({ X = s_Focus.X, Y = s_Focus.Y, Span = FOCUS_SPAN })
    end
    return s_Fit
end

local function UpdateView()
    local target = Target()
    if not s_View then
        s_View = { X = target.X, Y = target.Y, Span = target.Span }
        return
    end
    local dt = Context.DeltaTime
    s_View.Span = Animation.Animate(s_View.Span, target.Span, ZOOM_SPEED, dt)
    s_View.X = Animation.Animate(s_View.X, target.X, ZOOM_SPEED, dt)
    s_View.Y = Animation.Animate(s_View.Y, target.Y, ZOOM_SPEED, dt)
    Clamp(s_View)
end

local function PlayerPosition()
    local ok, position = pcall(function() return Game.GetPlayer():GetWorldPosition() end)
    return ok and position or nil
end

local function FormatSpan(span)
    if span >= 1000 then return string.format("%.1f km across", span / 1000) end
    return string.format("%d m across", math.floor(span))
end

local function DrawMap()
    UpdateView()
    local x, y = ImGui.GetCursorScreenPos()
    local left, top = s_View.X - s_View.Span / 2, s_View.Y + s_View.Span / 2
    local width, height = MAP.MaxX - MAP.MinX, MAP.MaxY - MAP.MinY

    local texture = Texture()
    if texture then
        ImGui.Image(texture, ImVec2.new(SIZE, SIZE),
            ImVec2.new((left - MAP.MinX) / width, (MAP.MaxY - top) / height),
            ImVec2.new((left + s_View.Span - MAP.MinX) / width, (MAP.MaxY - top + s_View.Span) / height))
    else
        ImGui.Dummy(SIZE, SIZE)
    end

    local drawList = ImGui.GetWindowDrawList()
    local scale = SIZE / s_View.Span
    local function Screen(wx, wy)
        return x + (wx - left) * scale, y + (top - wy) * scale
    end

    ImGui.PushClipRect(x, y, x + SIZE, y + SIZE, true)
    local drawn = 0
    for _, position in ipairs(s_Points) do
        local sx, sy = Screen(position.x, position.y)
        if sx >= x and sx <= x + SIZE and sy >= y and sy <= y + SIZE then
            ImGui.ImDrawListAddCircleFilled(drawList, sx, sy, 2, DOT)
            drawn = drawn + 1
            if drawn >= DOT_LIMIT then break end
        end
    end

    local player = PlayerPosition()
    if player then
        local sx, sy = Screen(player.x, player.y)
        ImGui.ImDrawListAddCircleFilled(drawList, sx, sy, 6, OUTLINE)
        ImGui.ImDrawListAddCircleFilled(drawList, sx, sy, 4.5, PLAYER)
    end

    if s_Focus and s_FocusFrame >= Context.Frame - 1 then
        local sx, sy = Screen(s_Focus.X, s_Focus.Y)
        ImGui.ImDrawListAddTriangleFilled(drawList, sx - 6, sy - 12, sx + 6, sy - 12, sx, sy, OUTLINE)
        ImGui.ImDrawListAddCircleFilled(drawList, sx, sy - 14, 7, OUTLINE)
        ImGui.ImDrawListAddCircleFilled(drawList, sx, sy - 14, 5.5, PIN)
        ImGui.ImDrawListAddTriangleFilled(drawList, sx - 4.5, sy - 12, sx + 4.5, sy - 12, sx, sy - 2, PIN)
    end
    ImGui.PopClipRect()

    Draw.Rect(drawList, x, y, SIZE, SIZE, Style.Border, 0, 1)
    ImGui.SetCursorScreenPos(x, y + SIZE + 6)
    local caption = (s_Focus and s_FocusFrame >= Context.Frame - 1 and s_Focus.Label) or s_Caption
    ImGui.Text(caption ~= "" and caption or "Night City")
    ImGui.SetCursorScreenPos(x, select(2, ImGui.GetCursorScreenPos()))
    local value = ImGui.ColorConvertU32ToFloat4(Style.TextDisabled)
    ImGui.TextColored(value[1], value[2], value[3], value[4], FormatSpan(s_View.Span))
end

function TeleportMap.Submit()
    SidePanel.Submit("teleport-map", DrawMap, { Width = PANEL_WIDTH, Height = SIZE + 70 })
end

return TeleportMap
