local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Dev = require("Features/Development/Dev")
local Development = require("Features/Development/Development")
local Snapshot = require("Features/Development/Snapshot")
local Skills = require("Features/Development/Skills")
local SkillInfo = require("View/Development/SkillInfo")
local SkillRewardsView = require("View/Development/SkillRewardsView")

local SkillsView = {}

local s_Values = {}
local s_Refs = {}

for _, skill in ipairs(Dev.Skills) do
    s_Values[skill.Id] = { Value = 1 }
    s_Refs[skill.Id] = Ref.Field(s_Values[skill.Id], "Value")
end

local function SkillSlider(skill)
    local key = "development.skills." .. skill.Id:lower()
    local current = Snapshot.Skills[skill.Id] or 1
    local ref = s_Refs[skill.Id]
    s_Values[skill.Id].Value = current

    if Widgets.SliderInt(L(key .. ".label"), ref, 1, math.max(1, Snapshot.SkillMax[skill.Id] or 1), 1, "%d") and ref.Value > current then
        Development.Queue(Skills.Raise, skill, ref.Value)
    end
    Widgets.Tip(L(key .. ".tip"))
    Widgets.Info(SkillInfo.Get, skill)
end

local function Visible(skill)
    return not skill.Relic or Snapshot.RelicUnlocked
end

local function RewardLinks()
    local first = true
    for _, skill in ipairs(Dev.Skills) do
        if Visible(skill) and SkillRewardsView.Has(skill) then
            if first then
                Widgets.Break(L("development.skillrewards.title"))
                first = false
            end
            Widgets.SubmenuButton(L("development.skills." .. skill.Id:lower() .. ".label"), SkillRewardsView.Menu(skill), SkillRewardsView.Badge(skill))
            Widgets.Tip(L("development.skillrewards.linktip"))
        end
    end
end

local function View()
    Development.Watch()
    if not Snapshot.Ready then
        Widgets.ValueRow(L("development.loading"), "")
        return
    end

    for _, skill in ipairs(Dev.Skills) do
        if Visible(skill) then SkillSlider(skill) end
    end

    if Widgets.HoldButton(L("development.maxlevel.label")) then Development.Queue(Skills.MaxLevelAndStreetCred) end
    Widgets.Tip(L("development.maxlevel.tip"))

    if Widgets.HoldButton(L("development.maxskills.label")) then Development.Queue(Skills.MaxAll) end
    Widgets.Tip(L("development.maxskills.tip"))

    RewardLinks()
end

SkillsView.Menu = Submenu.Create("development.skills.title", View)

return SkillsView
