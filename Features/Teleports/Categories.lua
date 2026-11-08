local MapPins = require("Features/Teleports/MapPins")
local Locations = require("Features/Teleports/Locations")

local Categories = {}

local GROUPS = { "Locations", "Vendors", "Activities" }
local EMPTY = {}

local s_ChoiceSections = nil
local s_ChoiceCreators = nil
local s_Choices = { "" }
local s_Known = {}
local s_Extra = {}

local s_Spots = {}
local s_Names = {}
local s_Loose = {}
local s_Groups = {}
local s_ByName = {}

local function Add(choices, seen, name)
    if not name or name == "" or seen[name] then return end
    seen[name] = true
    table.insert(choices, name)
end

local function BuildChoices()
    s_ChoiceSections = MapPins.Sections
    s_ChoiceCreators = Locations.Creators
    s_Choices = { "" }
    s_Known = {}
    s_Extra = {}

    for _, group in ipairs(GROUPS) do
        for _, id in ipairs(MapPins.SectionIds(group)) do
            local section = MapPins.Sections[id]
            if section then Add(s_Choices, s_Known, section.Label) end
        end
    end
    for _, creator in ipairs(Locations.Creators) do
        for _, category in ipairs(creator.Categories) do Add(s_Choices, s_Known, category.Name) end
    end
end

function Categories.Choices(current)
    if s_ChoiceSections ~= MapPins.Sections or s_ChoiceCreators ~= Locations.Creators then BuildChoices() end
    if not current or current == "" or s_Known[current] then return s_Choices end

    local extra = s_Extra[current]
    if extra then return extra end

    extra = {}
    for index, name in ipairs(s_Choices) do extra[index] = name end
    table.insert(extra, current)
    s_Extra[current] = extra
    return extra
end

local function Changed(custom)
    if #custom ~= #s_Spots then return true end
    for index, spot in ipairs(custom) do
        if s_Spots[index] ~= spot or s_Names[index] ~= (spot.Category or "") then return true end
    end
    return false
end

local function Rebuild(custom)
    s_Spots = {}
    s_Names = {}
    s_Loose = {}
    s_Groups = {}
    s_ByName = {}

    for index, spot in ipairs(custom) do
        local name = spot.Category or ""
        s_Spots[index] = spot
        s_Names[index] = name

        if name == "" then
            table.insert(s_Loose, spot)
        else
            local group = s_ByName[name]
            if not group then
                group = { Name = name, Spots = {} }
                s_ByName[name] = group
                table.insert(s_Groups, group)
            end
            table.insert(group.Spots, spot)
        end
    end
    table.sort(s_Groups, function(first, second) return first.Name:lower() < second.Name:lower() end)
end

function Categories.Group(custom)
    if Changed(custom) then Rebuild(custom) end
    return s_Loose, s_Groups
end

function Categories.Spots(custom, name)
    Categories.Group(custom)
    local group = s_ByName[name]
    return group and group.Spots or EMPTY
end

return Categories
