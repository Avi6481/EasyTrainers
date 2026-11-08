local Logger = require("Core/Logger")

local Locations = {
    Loaded = false,
    All = {},
    Creators = {}
}

local FILE = "Data/Locations.json"

local function Read()
    local file = io.open(FILE, "r")
    if not file then return nil end

    local text = file:read("*a")
    file:close()
    return json.decode(text)
end

local function Build(entry, creator)
    local location = {
        Name = tostring(entry.name or ""),
        Category = tostring(entry.category or ""),
        District = tostring(entry.district or ""),
        Area = tostring(entry.area or ""),
        Place = entry.place and tostring(entry.place) or nil,
        Creator = creator,
        X = tonumber(entry.x) or 0,
        Y = tonumber(entry.y) or 0,
        Z = tonumber(entry.z) or 0
    }
    location.Search = table.concat({ location.Name, location.Area, location.District, location.Category }, " "):lower()
    return location
end

local function AddCreator(data)
    local creator = { Name = tostring(data.name or ""), Categories = {} }
    local byName = {}

    for _, entry in ipairs(data.locations or {}) do
        local location = Build(entry, creator.Name)
        table.insert(Locations.All, location)

        local category = byName[location.Category]
        if not category then
            category = { Name = location.Category, Creator = creator.Name, Locations = {} }
            byName[location.Category] = category
            table.insert(creator.Categories, category)
        end
        table.insert(category.Locations, location)
    end

    table.insert(Locations.Creators, creator)
end

function Locations.Load()
    Locations.Loaded = true
    Locations.All = {}
    Locations.Creators = {}

    local data = Read()
    if not data or type(data.creators) ~= "table" then
        Logger.Log("Teleports: couldn't read " .. FILE)
        return
    end

    for _, creator in ipairs(data.creators) do AddCreator(creator) end
    Logger.Log("Teleports: loaded " .. #Locations.All .. " locations from " .. #Locations.Creators .. " creators")
end

return Locations
