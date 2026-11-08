local Dev = require("Features/Development/Dev")
local Catalog = require("Features/Development/Catalog")
local Money = require("Features/Development/Money")

local Snapshot = {
    Ready = false,
    RelicUnlocked = false,
    Levels = {},
    Attributes = {},
    Points = {},
    Money = 0,
    Skills = {},
    SkillMax = {},
    Owned = {}
}

function Snapshot.Refresh(data, player)
    for _, attribute in ipairs(Dev.Attributes) do
        Snapshot.Attributes[attribute.Id] = data:GetAttributePoints(Dev.AttributeData(attribute))
        Snapshot.Owned[attribute.Id] = 0
    end

    for _, perk in ipairs(Catalog.Perks) do
        local level = data:IsNewPerkBought(perk.Type)
        Snapshot.Levels[perk.Key] = level
        if level > 0 then
            local id = perk.Attribute.Id
            Snapshot.Owned[id] = Snapshot.Owned[id] + 1
        end
    end

    for _, point in ipairs(Dev.Points) do
        Snapshot.Points[point.Id] = data:GetDevPoints(Dev.PointType(point))
    end

    for _, skill in ipairs(Dev.Skills) do
        local proficiency = gamedataProficiencyType[skill.Type]
        Snapshot.Skills[skill.Id] = data:GetProficiencyLevel(proficiency)
        Snapshot.SkillMax[skill.Id] = data:GetProficiencyAbsoluteMaxLevel(proficiency)
    end

    Snapshot.Money = Money.Get(player)
    Snapshot.RelicUnlocked = Dev.RelicUnlocked()
    Snapshot.Ready = true
end

function Snapshot.Clear()
    Snapshot.Ready = false
end

function Snapshot.Level(perk)
    return Snapshot.Levels[perk.Key] or 0
end

function Snapshot.Locked(perk)
    if perk.Attribute.Relic then return false end
    return (Snapshot.Attributes[perk.Attribute.Id] or 0) < perk.Required
end

return Snapshot
