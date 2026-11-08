local Dev = require("Features/Development/Dev")
local Notify = require("Utils/Notify")

local Skills = {}

local PROGRESSION = {
    Level = true,
    StreetCred = true
}

local function RaiseTo(data, skill, level)
    local proficiency = gamedataProficiencyType[skill.Type]
    level = math.min(data:GetProficiencyAbsoluteMaxLevel(proficiency), level)
    if level <= data:GetProficiencyLevel(proficiency) then return false end

    data:SetLevel(proficiency, level, telemetryLevelGainReason.Gameplay, false)
    return true
end

local function MaxWhere(predicate, doneKey)
    local data = Dev.Data()
    if not data then return end

    local raised = 0
    for _, skill in ipairs(Dev.Skills) do
        if predicate(skill) then
            local proficiency = gamedataProficiencyType[skill.Type]
            if RaiseTo(data, skill, data:GetProficiencyAbsoluteMaxLevel(proficiency)) then raised = raised + 1 end
        end
    end

    if raised == 0 then
        Notify.Info(L("notify.dev.alreadymax"))
        return
    end
    data:UpdateUIBB()
    Notify.Success(L(doneKey))
end

local function IsProgression(skill)
    return PROGRESSION[skill.Id] == true
end

local function IsSkill(skill)
    if PROGRESSION[skill.Id] then return false end
    return not skill.Relic or Dev.RelicUnlocked()
end

function Skills.Raise(skill, level)
    local data = Dev.Data()
    if not data then return end

    if RaiseTo(data, skill, level) then data:UpdateUIBB() end
end

function Skills.MaxLevelAndStreetCred()
    MaxWhere(IsProgression, "notify.dev.maxlevel")
end

function Skills.MaxAll()
    MaxWhere(IsSkill, "notify.dev.maxskills")
end

return Skills
