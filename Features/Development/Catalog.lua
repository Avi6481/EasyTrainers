local Dev = require("Features/Development/Dev")
local Logger = require("Core/Logger")
local GameText = require("Utils/GameText")

local Catalog = {
    Loaded = false,
    Perks = {},
    ByKey = {},
    ByAttribute = {}
}

local RELIC_MILESTONE_COST = 3

local COLUMNS = {
    Left = 1,
    Inbetween_Left = 2,
    Central = 3,
    Inbetween_Right = 4,
    Right = 5,
    Master = 6
}

local Text = GameText.Get

local function Fill(text, ui)
    return GameText.Fill(text, ui, UILocalizationDataPackage.FromNewPerkUIDataPackage)
end

local function Layout(name)
    local rest = name:match("^[^_]+_(.+)$") or name
    local column = COLUMNS[rest:match("^(Inbetween_%a+)")] or COLUMNS[rest:match("^(%a+)")] or COLUMNS.Central
    return column, rest:find("Milestone", 1, true) ~= nil
end

local function LevelList(record)
    local ok, list = pcall(function() return record:Levels() end)
    if ok and type(list) == "table" then return list end
    return {}
end

local function Describe(record, count)
    local base = Text(record:Loc_desc_key(), "")
    local descriptions = {}
    local levels = nil

    for index = 0, count - 1 do
        local level = record:GetLevelsItem(index)
        if not level then
            levels = levels or LevelList(record)
            level = levels[index + 1]
        end

        local text, ui = base, record:UiData()
        if level then
            text = Text(level:Loc_desc_key(), base)
            ui = level:UiData() or ui
        end
        descriptions[index + 1] = Fill(text, ui)
    end
    return descriptions
end

local function Build(record, attribute)
    local name = Game.NameToString(record:EnumName())
    local column, milestone = Layout(name)
    local tier = record:Tier()
    local count = math.max(1, record:GetLevelsCount())

    return {
        Type = record:Type(),
        Key = EnumInt(record:Type()),
        Id = name,
        Attribute = attribute,
        Name = Text(record:Loc_name_key(), record:EnumComment()),
        Descriptions = Describe(record, count),
        Required = tier and tier:RequiredAttributePoints() or 0,
        MaxLevel = count,
        Column = column,
        Milestone = milestone,
        Parents = {},
        ParentRecords = record,
        Children = {}
    }
end

local function Before(first, second)
    if first.Required ~= second.Required then return first.Required < second.Required end
    if first.Column ~= second.Column then return first.Column < second.Column end
    if first.Milestone ~= second.Milestone then return first.Milestone end
    return first.Id < second.Id
end

local function LinkParents()
    for _, perk in ipairs(Catalog.Perks) do
        local record = perk.ParentRecords
        for index = 0, record:GetRequiresPerksCount() - 1 do
            local parentRecord = record:GetRequiresPerksItem(index)
            local parent = parentRecord and Catalog.ByKey[EnumInt(parentRecord:Type())]
            if parent then
                table.insert(perk.Parents, parent)
                table.insert(parent.Children, perk)
            end
        end
        perk.ParentRecords = nil
    end
end

function Catalog.Load(data)
    Catalog.Perks = {}
    Catalog.ByKey = {}
    Catalog.ByAttribute = {}

    for _, attribute in ipairs(Dev.Attributes) do
        local dataType = Dev.AttributeData(attribute)
        data:UnlockFreeNewPerks(dataType)

        local record = RPGManager.GetAttributeDataRecord(dataType)
        local list = {}
        for index = 0, record:GetPerksCount() - 1 do
            local perkRecord = record:GetPerksItem(index)
            if perkRecord then
                local perk = Build(perkRecord, attribute)
                perk.Cost = (attribute.Relic and data:IsEspionageMilestonePerk(perk.Type)) and RELIC_MILESTONE_COST or 1
                table.insert(list, perk)
                table.insert(Catalog.Perks, perk)
                Catalog.ByKey[perk.Key] = perk
            end
        end

        table.sort(list, Before)
        Catalog.ByAttribute[attribute.Id] = list
    end

    LinkParents()
    Catalog.Loaded = true
    Logger.Log("Development: loaded " .. #Catalog.Perks .. " perks")
end

return Catalog
