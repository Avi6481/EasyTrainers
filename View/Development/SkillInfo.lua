local Icons = require("Core/Icons")
local SkillRewards = require("Features/Development/SkillRewards")
local Snapshot = require("Features/Development/Snapshot")

local SkillInfo = {}

local NEXT_COUNT = 5
local EARNED_COUNT = 10

local s_Docs = {}

local function NextRewards(doc, info, level, max)
    local sample = tip("development.skillinfo.level", { level = max })
    local shown = 0

    for target = level + 1, max do
        local text = info.Rewards[target]
        if text then
            if shown == 0 then table.insert(doc, { Kind = "Heading", Text = L("development.skillinfo.next") }) end
            table.insert(doc, {
                Kind = "Entry",
                Label = tip("development.skillinfo.level", { level = target }),
                LabelSample = sample,
                Text = text
            })
            shown = shown + 1
            if shown == NEXT_COUNT then return end
        end
    end
end

local function Group(info, level)
    local counts = {}
    local order = {}

    for target = level, 2, -1 do
        local text = info.Rewards[target]
        if text then
            if not counts[text] then
                counts[text] = 0
                table.insert(order, text)
            end
            counts[text] = counts[text] + 1
        end
    end
    return order, counts
end

local function Earned(doc, info, level)
    local order, counts = Group(info, level)
    if #order == 0 then return end

    table.insert(doc, { Kind = "Heading", Text = L("development.skillinfo.earned") })
    for index, text in ipairs(order) do
        if index > EARNED_COUNT then
            table.insert(doc, { Kind = "Text", Text = tip("development.skillinfo.more", { count = #order - EARNED_COUNT }), Tone = "Soft" })
            return
        end

        local count = counts[text]
        table.insert(doc, {
            Kind = "Item",
            Icon = Icons.Get("Check"),
            IconTone = "Strong",
            Text = count > 1 and (text .. "  <Rich>x" .. count .. "</>") or text
        })
    end
end

local function Build(skill, level, max)
    local info = SkillRewards.BySkill[skill.Id]
    local kind = skill.Type:find("Skill$") and "development.skillinfo.skill" or "development.skillinfo.progression"
    local doc = {
        { Kind = "Eyebrow", Text = L(kind) },
        { Kind = "Title", Text = (info and info.Name) or L("development.skills." .. skill.Id:lower() .. ".label") },
        { Kind = "Separator" },
        { Kind = "Row", Label = L("development.skillinfo.max"), Value = tostring(max) }
    }
    if not info then return doc end

    if info.Description ~= "" then table.insert(doc, { Kind = "Text", Text = info.Description, Tone = "Soft" }) end
    NextRewards(doc, info, level, max)
    Earned(doc, info, level)
    return doc
end

function SkillInfo.Get(skill)
    local level = Snapshot.Skills[skill.Id] or 1
    local max = math.max(1, Snapshot.SkillMax[skill.Id] or 1)
    local signature = level + (max * 1000) + (SkillRewards.Loaded and 0.5 or 0)

    local cached = s_Docs[skill.Id]
    if cached and cached.Signature == signature then return cached.Doc end

    local doc = Build(skill, level, max)
    s_Docs[skill.Id] = { Signature = signature, Doc = doc }
    return doc
end

return SkillInfo
