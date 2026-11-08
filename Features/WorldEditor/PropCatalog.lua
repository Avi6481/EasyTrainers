local Logger = require("Core/Logger")

local PropCatalog = {}

local DATA_MODULE = "Data/PropCatalog"
local SEARCH_LIMIT = 200

local s_Categories = nil
local s_All = nil
local s_ByHash = nil

local function Matches(text, words)
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

function PropCatalog.Load()
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

function PropCatalog.IsLoaded()
    return s_Categories ~= nil
end

function PropCatalog.GetCategories()
    return s_Categories or {}
end

function PropCatalog.Count()
    return s_All and #s_All or 0
end

function PropCatalog.FindByTemplateHash(hash)
    if not hash or hash == "" or not EasyEntityTools then return nil end
    PropCatalog.Load()
    if not s_ByHash then
        s_ByHash = {}
        for _, entry in ipairs(s_All) do
            if entry.Path:sub(-4):lower() == ".ent" then
                local ok, value = pcall(function() return EasyEntityTools.HashResourcePath(entry.Path) end)
                if ok and value and value ~= "" then s_ByHash[value] = entry end
            end
        end
    end
    return s_ByHash[hash]
end

function PropCatalog.Search(text)
    local results = {}
    if not s_All then return results end

    local words = {}
    for word in (text or ""):lower():gmatch("[^ ]+") do table.insert(words, word) end
    if #words == 0 then return results end

    for _, entry in ipairs(s_All) do
        if Matches(entry.Search, words) then
            table.insert(results, entry)
            if #results >= SEARCH_LIMIT then break end
        end
    end
    return results
end

return PropCatalog
