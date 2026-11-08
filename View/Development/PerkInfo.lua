local Icons = require("Core/Icons")
local Snapshot = require("Features/Development/Snapshot")

local PerkInfo = {}

local s_Docs = {}

local function Maxed(perk)
    return Snapshot.Level(perk) >= perk.MaxLevel
end

local function Met(perk)
    return perk.Attribute.Relic or (Snapshot.Attributes[perk.Attribute.Id] or 0) >= perk.Required
end

local function Signature(perk)
    local value = (Snapshot.Level(perk) * 2) + (Met(perk) and 1 or 0)
    local bit = 64

    for _, parent in ipairs(perk.Parents) do
        if Maxed(parent) then value = value + bit end
        bit = bit * 2
    end
    for _, child in ipairs(perk.Children) do
        if Snapshot.Level(child) > 0 then value = value + bit end
        bit = bit * 2
    end
    return value
end

local function AttributeKey(perk)
    return "development.attributes." .. perk.Attribute.Id:lower() .. ".label"
end

local function Same(descriptions)
    for index = 2, #descriptions do
        if descriptions[index] ~= descriptions[1] then return false end
    end
    return true
end

local function Cost(perk)
    local key = perk.Attribute.Relic and "development.info.relicpoint" or "development.info.perkpoint"
    if perk.Cost > 1 then key = key .. "s" end
    return tip(key, { count = perk.Cost })
end

local function Header(doc, perk)
    local kind = perk.Milestone and "development.info.milestone" or "development.info.perk"
    table.insert(doc, { Kind = "Eyebrow", Text = tip("development.info.eyebrow", { attribute = AttributeKey(perk), kind = kind }) })
    table.insert(doc, { Kind = "Title", Text = perk.Name })
    table.insert(doc, { Kind = "Separator" })

    if not perk.Attribute.Relic and perk.Required > 0 then
        table.insert(doc, {
            Kind = "Row",
            Label = L("development.info.requires"),
            Value = tip("development.info.requirement", { attribute = AttributeKey(perk), level = perk.Required }),
            Tone = Met(perk) and "Text" or "Warn"
        })
    end

    local costLabel = perk.MaxLevel > 1 and "development.info.costperlevel" or "development.info.cost"
    table.insert(doc, { Kind = "Row", Label = L(costLabel), Value = Cost(perk) })
end

local function Levels(doc, perk)
    local level = Snapshot.Level(perk)

    if perk.MaxLevel == 1 or Same(perk.Descriptions) then
        table.insert(doc, { Kind = "Heading", Text = L("development.info.effect"), Tone = level > 0 and "Strong" or "Soft" })
        table.insert(doc, { Kind = "Text", Text = perk.Descriptions[1] or "" })
        return
    end

    for index, text in ipairs(perk.Descriptions) do
        local owned = index <= level
        table.insert(doc, { Kind = "Heading", Text = tip("development.info.level", { level = index }), Tone = owned and "Strong" or "Soft" })
        table.insert(doc, { Kind = "Text", Text = text, Tone = owned and "Text" or "Soft" })
    end
end

local function Links(doc, heading, perks, done, doneIcon, openIcon)
    if #perks == 0 then return end

    table.insert(doc, { Kind = "Heading", Text = L(heading) })
    for _, perk in ipairs(perks) do
        local finished = done(perk)
        table.insert(doc, {
            Kind = "Item",
            Text = perk.Name,
            Icon = Icons.Get(finished and doneIcon or openIcon),
            IconTone = finished and "Strong" or "Dim",
            Tone = finished and "Text" or "Soft"
        })
    end
end

local function Owned(perk)
    return Snapshot.Level(perk) > 0
end

local function Build(perk)
    local doc = {}
    Header(doc, perk)
    Levels(doc, perk)
    Links(doc, "development.info.needs", perk.Parents, Maxed, "Check", "Lock")
    Links(doc, "development.info.unlocks", perk.Children, Owned, "Check", "ArrowRight")
    return doc
end

function PerkInfo.Get(perk)
    local signature = Signature(perk)
    local cached = s_Docs[perk.Key]
    if cached and cached.Signature == signature then return cached.Doc end

    local doc = Build(perk)
    s_Docs[perk.Key] = { Signature = signature, Doc = doc }
    return doc
end

return PerkInfo
