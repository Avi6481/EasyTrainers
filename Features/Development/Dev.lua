local Dev = {}

Dev.MIN_ATTRIBUTE = 3
Dev.MAX_ATTRIBUTE = 20

Dev.Points = {
    { Id = "Perk", Type = "Primary", Max = 200 },
    { Id = "Attribute", Type = "Attribute", Max = 200 },
    { Id = "Relic", Type = "Espionage", Max = 30, Relic = true }
}

Dev.Attributes = {
    { Id = "Body", Data = "BodyAttributeData", Stat = "Strength" },
    { Id = "Reflexes", Data = "ReflexesAttributeData", Stat = "Reflexes" },
    { Id = "TechnicalAbility", Data = "TechnicalAbilityAttributeData", Stat = "TechnicalAbility" },
    { Id = "Cool", Data = "CoolAttributeData", Stat = "Cool" },
    { Id = "Intelligence", Data = "IntelligenceAttributeData", Stat = "Intelligence" },
    { Id = "Relic", Data = "EspionageAttributeData", Stat = "Espionage", Relic = true }
}

Dev.Skills = {
    { Id = "Level", Type = "Level" },
    { Id = "StreetCred", Type = "StreetCred" },
    { Id = "Solo", Type = "StrengthSkill" },
    { Id = "Shinobi", Type = "ReflexesSkill" },
    { Id = "Engineer", Type = "TechnicalAbilitySkill" },
    { Id = "Headhunter", Type = "CoolSkill" },
    { Id = "Netrunner", Type = "IntelligenceSkill" },
    { Id = "Relic", Type = "Espionage", Relic = true }
}

local RELIC_FACT = "ep1_tree_unlocked"

function Dev.Data()
    local player = Game.GetPlayer()
    if not player then return nil, nil end
    return PlayerDevelopmentSystem.GetData(player), player
end

function Dev.AttributeData(attribute)
    return gamedataAttributeDataType[attribute.Data]
end

function Dev.PointType(point)
    return gamedataDevelopmentPointType[point.Type]
end

function Dev.RelicUnlocked()
    return Game.GetQuestsSystem():GetFact(CName.new(RELIC_FACT)) > 0
end

return Dev
