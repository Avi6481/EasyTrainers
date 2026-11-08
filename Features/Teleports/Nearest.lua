local MapPins = require("Features/Teleports/MapPins")

local Nearest = {
    Default = "Ripperdoc",
    Types = MapPins.SectionIds("Vendors")
}

table.insert(Nearest.Types, "Apartments")

local s_Source = nil
local s_Available = {}

function Nearest.Valid(id)
    for _, value in ipairs(Nearest.Types) do
        if value == id then return true end
    end
    return false
end

function Nearest.Available()
    if s_Source == MapPins.Sections then return s_Available end

    s_Source = MapPins.Sections
    s_Available = {}
    for _, id in ipairs(Nearest.Types) do
        local section = MapPins.Sections[id]
        if section and section.Count > 0 then table.insert(s_Available, id) end
    end
    return s_Available
end

function Nearest.Find(id, position)
    local section = MapPins.Sections[id]
    if not section then return nil end

    local best, bestDistance = nil, math.huge
    for _, pin in ipairs(section.All) do
        local dx, dy, dz = pin.X - position.x, pin.Y - position.y, pin.Z - position.z
        local distance = (dx * dx) + (dy * dy) + (dz * dz)
        if distance < bestDistance then
            best = pin
            bestDistance = distance
        end
    end
    return best, section
end

return Nearest
