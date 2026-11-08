local Distances = {
    Version = 0
}

local MOVED = 1

local s_Values = setmetatable({}, { __mode = "k" })
local s_Texts = setmetatable({}, { __mode = "k" })
local s_LastX = nil
local s_LastY = nil
local s_LastZ = nil

local function Format(distance)
    if distance >= 1000 then return string.format("%.1f km", distance / 1000) end
    return string.format("%d m", math.floor(distance))
end

local function Moved(position)
    if not s_LastX then return true end
    local dx, dy, dz = position.x - s_LastX, position.y - s_LastY, position.z - s_LastZ
    return (dx * dx) + (dy * dy) + (dz * dz) >= MOVED * MOVED
end

local function Measure(list, x, y, z)
    for _, item in ipairs(list) do
        local dx, dy, dz = item.X - x, item.Y - y, item.Z - z
        s_Values[item] = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    end
end

function Distances.Update(position, lists, force)
    if not force and not Moved(position) then return end

    s_LastX, s_LastY, s_LastZ = position.x, position.y, position.z
    for _, list in ipairs(lists) do Measure(list, s_LastX, s_LastY, s_LastZ) end
    Distances.Version = Distances.Version + 1
end

function Distances.Get(item)
    return s_Values[item] or math.huge
end

function Distances.Text(item)
    local distance = s_Values[item]
    if not distance then return item.Tag or "" end

    local cached = s_Texts[item]
    if cached and math.abs(cached.Distance - distance) < 1 then return cached.Text end

    local text = Format(distance)
    if item.Tag then text = item.Tag .. "  " .. text end
    s_Texts[item] = { Distance = distance, Text = text }
    return text
end

function Distances.Reset()
    s_LastX, s_LastY, s_LastZ = nil, nil, nil
end

return Distances
