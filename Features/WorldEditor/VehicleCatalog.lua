local Catalog = require("Features/Vehicles/Catalog")

local VehicleCatalog = {}

local SEARCH_LIMIT = 100

local s_Version = nil
local s_Classes = {}
local s_All = {}

local function Matches(text, words)
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

local function Build()
    if s_Version == Catalog.Version then return end
    s_Version = Catalog.Version
    s_Classes, s_All = {}, {}

    local category = L("worldeditor.spawn.vehicles.label")
    local byClass = {}
    for _, vehicle in ipairs(Catalog.Browsable) do
        local entry = { Name = vehicle.Name, Category = category, Group = vehicle.Class, Record = vehicle.Id, Vehicle = vehicle }
        table.insert(s_All, entry)
        local class = byClass[vehicle.Class]
        if not class then
            class = { Name = vehicle.Class, Vehicles = {} }
            byClass[vehicle.Class] = class
        end
        table.insert(class.Vehicles, entry)
    end
    for _, name in ipairs(Catalog.CLASSES) do
        if byClass[name] then table.insert(s_Classes, byClass[name]) end
    end
end

function VehicleCatalog.Load()
    if not Catalog.Loaded then Catalog.Load() end
end

function VehicleCatalog.IsLoaded()
    return Catalog.Loaded
end

function VehicleCatalog.GetClasses()
    Build()
    return s_Classes
end

function VehicleCatalog.Count()
    Build()
    return #s_All
end

function VehicleCatalog.Search(text)
    local results = {}
    if not Catalog.Loaded then return results end
    Build()

    local words = {}
    for word in (text or ""):lower():gmatch("[^ ]+") do table.insert(words, word) end
    if #words == 0 then return results end

    for _, entry in ipairs(s_All) do
        if Matches(entry.Vehicle.Search, words) then
            table.insert(results, entry)
            if #results >= SEARCH_LIMIT then break end
        end
    end
    return results
end

return VehicleCatalog
