local Icons = require("Core/Icons")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Development = require("Features/Development/Development")
local Snapshot = require("Features/Development/Snapshot")
local Skills = require("Features/Development/Skills")
local SkillRewards = require("Features/Development/SkillRewards")

local SkillRewardsView = {}

local s_Menus = {}
local s_Entries = {}
local s_Badges = {}

local function SkillKey(skill)
    return "development.skills." .. skill.Id:lower() .. ".label"
end

local function Entry(skill, level)
    local list = s_Entries[skill.Id]
    if not list then
        list = {}
        s_Entries[skill.Id] = list
    end

    local entry = list[level]
    if entry then return entry end

    local label = tip("development.skillinfo.level", { level = level })
    entry = {
        Skill = skill,
        Level = level,
        Label = label,
        EarnedLabel = label .. "  " .. Icons.Get("Check"),
        Docs = {}
    }
    list[level] = entry
    return entry
end

local function Info(entry)
    local earned = (Snapshot.Skills[entry.Skill.Id] or 1) >= entry.Level
    local doc = entry.Docs[earned]
    if doc then return doc end

    local info = SkillRewards.BySkill[entry.Skill.Id]
    doc = {
        { Kind = "Eyebrow", Text = info.Name or L(SkillKey(entry.Skill)) },
        { Kind = "Title", Text = tip("development.skillrewards.levelname", { level = entry.Level }) },
        { Kind = "Separator" },
        {
            Kind = "Row",
            Label = L("development.skillrewards.status"),
            Value = L(earned and "development.skillrewards.earned" or "development.skillrewards.locked"),
            Tone = earned and "Strong" or "Soft"
        },
        { Kind = "Text", Text = info.Rewards[entry.Level] }
    }
    entry.Docs[earned] = doc
    return doc
end

local function View(skill)
    Development.Watch()

    local info = SkillRewards.BySkill[skill.Id]
    if not Snapshot.Ready or not info then
        Widgets.ValueRow(L("development.loading"), "")
        return
    end

    local level = Snapshot.Skills[skill.Id] or 1
    for _, target in ipairs(info.Levels) do
        local entry = Entry(skill, target)
        local earned = target <= level

        if Widgets.ValueRow(earned and entry.EarnedLabel or entry.Label, info.Plain[target], not earned) then
            Development.Queue(Skills.Raise, skill, target)
        end
        Widgets.Tip(L(earned and "development.skillrewards.earnedtip" or "development.skillrewards.tip"))
        Widgets.Info(Info, entry)
    end
end

function SkillRewardsView.Has(skill)
    local info = SkillRewards.BySkill[skill.Id]
    return info ~= nil and #info.Levels > 0
end

function SkillRewardsView.Badge(skill)
    local info = SkillRewards.BySkill[skill.Id]
    if not info then return nil end

    local level = Snapshot.Skills[skill.Id] or 1
    local cached = s_Badges[skill.Id]
    if cached and cached.Level == level then return cached.Text end

    local earned = 0
    for _, target in ipairs(info.Levels) do
        if target <= level then earned = earned + 1 end
    end

    local text = string.format("%d/%d", earned, #info.Levels)
    s_Badges[skill.Id] = { Level = level, Text = text }
    return text
end

function SkillRewardsView.Menu(skill)
    local menu = s_Menus[skill.Id]
    if menu then return menu end

    menu = Submenu.Create(SkillKey(skill), function() View(skill) end)
    s_Menus[skill.Id] = menu
    return menu
end

return SkillRewardsView
