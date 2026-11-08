local Draw = require("Core/Draw")
local Logger = require("Core/Logger")
local Style = require("Style/Style")

local MapView = {}

local FILE = "Assets/Map/NightCity.png"
local MIN_X, MAX_X = -7300, 6300
local MIN_Y, MAX_Y = -7500, 4800
local FOCUS_SPAN = 900
local MIN_SPAN = 500
local MAX_SPAN = math.min(MAX_X - MIN_X, MAX_Y - MIN_Y)
local PADDING = 250
local DOT_LIMIT = 1500

local PIN = Draw.RGBA(255, 80, 80, 255)
local PLAYER = Draw.RGBA(255, 210, 74, 255)
local DOT = Draw.RGBA(120, 200, 230, 210)
local OUTLINE = Draw.RGBA(0, 0, 0, 255)

local s_Texture = nil

local function Texture()
    if s_Texture ~= nil then return s_Texture or nil end

    local texture, err = ImGui.LoadTexture(FILE)
    s_Texture = texture or false
    if not texture then Logger.Log("Map: " .. tostring(err or ("couldn't load " .. FILE))) end
    return texture
end

local function Clamp(view)
    local half = view.Span / 2
    view.X = math.max(MIN_X + half, math.min(MAX_X - half, view.X))
    view.Y = math.max(MIN_Y + half, math.min(MAX_Y - half, view.Y))
    return view
end

function MapView.Fit(focus, points)
    if focus then return Clamp({ X = focus.X, Y = focus.Y, Span = FOCUS_SPAN }) end

    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for _, point in ipairs(points or {}) do
        minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
        minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
    end
    if minX == math.huge then return Clamp({ X = (MIN_X + MAX_X) / 2, Y = (MIN_Y + MAX_Y) / 2, Span = MAX_SPAN }) end

    local span = math.max(maxX - minX, maxY - minY) + (PADDING * 2)
    return Clamp({ X = (minX + maxX) / 2, Y = (minY + maxY) / 2, Span = math.max(MIN_SPAN, math.min(MAX_SPAN, span)) })
end

local function Image(x, y, size, view)
    local texture = Texture()
    if not texture then
        Draw.RectFilled(x, y, size, size, Style.BackgroundDark, 0)
        return
    end

    local width, height = MAX_X - MIN_X, MAX_Y - MIN_Y
    local left, top = view.X - (view.Span / 2), view.Y + (view.Span / 2)
    ImGui.SetCursorScreenPos(x, y)
    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, Draw.GetAlpha())
    ImGui.Image(texture, ImVec2.new(size, size),
        ImVec2.new((left - MIN_X) / width, (MAX_Y - top) / height),
        ImVec2.new((left + view.Span - MIN_X) / width, (MAX_Y - top + view.Span) / height))
    ImGui.PopStyleVar(1)
end

local function Marker(sx, sy, radius, color)
    Draw.CircleFilled(sx, sy, radius + 1.5, OUTLINE)
    Draw.CircleFilled(sx, sy, radius, color)
end

function MapView.Draw(x, y, size, map)
    local view = map.View
    Image(x, y, size, view)

    local scale = size / view.Span
    local left, top = view.X - (view.Span / 2), view.Y + (view.Span / 2)

    Draw.PushClip(x, y, size, size)
    local drawn = 0
    for _, point in ipairs(map.Points or {}) do
        local sx, sy = x + ((point.X - left) * scale), y + ((top - point.Y) * scale)
        if sx >= x and sx <= x + size and sy >= y and sy <= y + size then
            Draw.CircleFilled(sx, sy, 2.5, DOT)
            drawn = drawn + 1
            if drawn >= DOT_LIMIT then break end
        end
    end

    local player = map.Player
    if player and player.Known then
        Marker(x + ((player.X - left) * scale), y + ((top - player.Y) * scale), 4.5, PLAYER)
    end

    if map.Focus then
        local sx, sy = x + ((map.Focus.X - left) * scale), y + ((top - map.Focus.Y) * scale)
        Draw.TriangleFilled(sx - 6, sy - 12, sx + 6, sy - 12, sx, sy, OUTLINE)
        Marker(sx, sy - 14, 5.5, PIN)
        Draw.TriangleFilled(sx - 4.5, sy - 12, sx + 4.5, sy - 12, sx, sy - 2, PIN)
    end
    Draw.PopClip()

    Draw.Rect(x, y, size, size, Style.Border, 0, nil, 1)
end

return MapView
