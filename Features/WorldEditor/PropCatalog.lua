local Logger = require("Core/Logger")

local PropCatalog = {}

local DATA_MODULE = "Assets/Props/PropCatalog"
local SEARCH_LIMIT = 200

local s_Categories = nil
local s_All = nil

local function Load()
    if s_Categories then return end
    s_Categories, s_All = {}, {}

    local ok, rows = pcall(require, DATA_MODULE)
    if not ok or type(rows) ~= "table" then
        Logger.Log("PropCatalog: failed to load " .. DATA_MODULE .. " (" .. tostring(rows) .. ")")
        return
    end

    local categoryIndex = {}
    for _, row in ipairs(rows) do
        local entry = { Name = row[1], Category = row[2], Group = row[3], Path = row[4], Search = (row[1] .. " " .. row[3]):lower() }
        table.insert(s_All, entry)

        local category = categoryIndex[entry.Category]
        if not category then
            category = { Name = entry.Category, Groups = {}, GroupIndex = {}, Count = 0 }
            categoryIndex[entry.Category] = category
            table.insert(s_Categories, category)
        end

        local group = category.GroupIndex[entry.Group]
        if not group then
            group = { Name = entry.Group, Props = {} }
            category.GroupIndex[entry.Group] = group
            table.insert(category.Groups, group)
        end
        table.insert(group.Props, entry)
        category.Count = category.Count + 1
    end

    local byName = function(a, b) return a.Name < b.Name end
    table.sort(s_Categories, byName)
    for _, category in ipairs(s_Categories) do
        table.sort(category.Groups, byName)
        for _, group in ipairs(category.Groups) do table.sort(group.Props, byName) end
    end
    Logger.Log(string.format("PropCatalog: loaded %d props in %d categories", #s_All, #s_Categories))
end

function PropCatalog.GetCategories()
    Load()
    return s_Categories
end

function PropCatalog.Count()
    Load()
    return #s_All
end

function PropCatalog.Search(text)
    Load()
    local results = {}
    local needle = (text or ""):lower()
    if needle == "" then return results end

    for _, entry in ipairs(s_All) do
        if entry.Search:find(needle, 1, true) then
            table.insert(results, entry)
            if #results >= SEARCH_LIMIT then break end
        end
    end
    return results
end

return PropCatalog
