local Distances = require("Features/Teleports/Distances")

local Listing = {}

Listing.Sorts = { "Closest", "Name", "Default" }

local s_Filtered = setmetatable({}, { __mode = "k" })
local s_Sorted = setmetatable({}, { __mode = "k" })
local s_Names = setmetatable({}, { __mode = "k" })

local function NameKey(item)
    local name = item.Name or ""
    local cached = s_Names[item]
    if cached and cached.Name == name then return cached.Key end

    cached = { Name = name, Key = name:lower() }
    s_Names[item] = cached
    return cached.Key
end

local function Nearer(first, second)
    return Distances.Get(first) < Distances.Get(second)
end

local function Named(first, second)
    return NameKey(first) < NameKey(second)
end

local function AreaKey(area)
    if not area or area == "" then return nil end
    return area:lower()
end

function Listing.Filter(list, district, area)
    if not district or district == "" then return list end

    local areaKey = AreaKey(area)
    local cached = s_Filtered[list]
    if cached and cached.District == district and cached.Area == areaKey and cached.Count == #list then return cached.Items end

    local items = {}
    for _, item in ipairs(list) do
        if item.District == district and (not areaKey or AreaKey(item.Area) == areaKey) then table.insert(items, item) end
    end
    s_Filtered[list] = { District = district, Area = areaKey, Count = #list, Items = items }
    return items
end

local function Fill(cached, list)
    local items = cached.Items
    for index, item in ipairs(list) do items[index] = item end
    for index = #items, #list + 1, -1 do items[index] = nil end
end

function Listing.Sort(list, sort, live)
    if sort ~= "Closest" and sort ~= "Name" then return list end

    local version = sort == "Closest" and Distances.Version or 0
    local cached = s_Sorted[list]
    if not live and cached and cached.Sort == sort and cached.Version == version and cached.Count == #list then
        return cached.Items
    end

    cached = cached or { Items = {} }
    cached.Sort = sort
    cached.Version = version
    cached.Count = #list
    s_Sorted[list] = cached

    Fill(cached, list)
    table.sort(cached.Items, sort == "Closest" and Nearer or Named)
    return cached.Items
end

function Listing.Districts(lists)
    local seen = {}
    local names = {}
    for _, list in ipairs(lists) do
        for _, item in ipairs(list) do
            local district = item.District
            if district and district ~= "" and not seen[district] then
                seen[district] = true
                table.insert(names, district)
            end
        end
    end
    table.sort(names)
    return names
end

function Listing.Areas(lists, district)
    local seen = {}
    local names = {}
    if not district or district == "" then return names end

    for _, list in ipairs(lists) do
        for _, item in ipairs(list) do
            local key = item.District == district and AreaKey(item.Area)
            if key and not seen[key] then
                seen[key] = true
                table.insert(names, item.Area)
            end
        end
    end
    table.sort(names, function(first, second) return first:lower() < second:lower() end)
    return names
end

function Listing.SameArea(first, second)
    return AreaKey(first) == AreaKey(second)
end

return Listing
