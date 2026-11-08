local Dev = require("Features/Development/Dev")
local GameText = require("Utils/GameText")
local Logger = require("Core/Logger")

local SkillRewards = {
    Loaded = false,
    BySkill = {}
}

local FIRST_REWARD = 1

local function Reward(bonus)
    local ui = bonus and bonus:UiData()
    if not ui then return nil end

    local text = GameText.FromName(ui:Loc_name_key(), "")
    if text == "" then return nil end
    return GameText.Fill(text, ui, UILocalizationDataPackage.FromPassiveUIDataPackage)
end

local function Load(skill)
    local record = RPGManager.GetProficiencyRecord(gamedataProficiencyType[skill.Type])
    if not record then return nil end

    local rewards = {}
    local plain = {}
    local levels = {}
    for index = FIRST_REWARD, record:GetPassiveBonusesCount() - 1 do
        local text = Reward(record:GetPassiveBonusesItem(index))
        if text then
            rewards[index + 1] = text
            plain[index + 1] = (text:gsub("<[^>]*>", ""):gsub("{[^}]*}", ""):gsub("%s+", " "))
            table.insert(levels, index + 1)
        end
    end

    return {
        Name = GameText.Get(record:Loc_name_key(), nil),
        Description = GameText.Get(record:Loc_desc_key(), ""),
        Rewards = rewards,
        Plain = plain,
        Levels = levels
    }
end

function SkillRewards.Load()
    SkillRewards.Loaded = true
    SkillRewards.BySkill = {}

    for _, skill in ipairs(Dev.Skills) do
        SkillRewards.BySkill[skill.Id] = Load(skill)
    end
    Logger.Log("Development: loaded skill rewards")
end

return SkillRewards
