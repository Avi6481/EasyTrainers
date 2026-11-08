local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local Tuning = require("Features/Weapons/Tuning")

local TuningView = {}

local MAX_NAME = 32

local s_Summaries = setmetatable({}, { __mode = "k" })

local function Entry(name, key, format)
    return { Name = name, Label = "weapons.tuning." .. key .. ".label", Tip = "weapons.tuning." .. key .. ".tip", Format = format }
end

local DAMAGE = {
    Entry("Damage", "damage", "%d%%"),
    Entry("CritChance", "critchance", "+%d%%"),
    Entry("CritDamage", "critdamage", "+%d%%"),
    Entry("HeadshotBonus", "headshot", "+%d%%")
}

local FIRING = {
    Entry("FireRate", "firerate", "%d%%"),
    Entry("ExtraPellets", "pellets", "+%d"),
    Entry("ExtraMagazine", "magazine", "+%d"),
    Entry("ReloadSpeed", "reload", "%d%%")
}

local ACCURACY = {
    Entry("Recoil", "recoil", "%d%%"),
    Entry("Spread", "spread", "%d%%"),
    Entry("Range", "range", "%d%%")
}

local GROUPS = { DAMAGE, FIRING, ACCURACY }

local STAT_ROWS = {
    { Key = "Damage", Label = "weapons.tuning.stats.damage", Format = "%.1f" },
    { Key = "FireRate", Label = "weapons.tuning.stats.firerate", Format = "%.1f/s", Ranged = true },
    { Key = "DPS", Label = "weapons.tuning.stats.dps", Format = "%.0f" },
    { Key = "CritChance", Label = "weapons.tuning.stats.critchance", Format = "%.0f%%" },
    { Key = "CritDamage", Label = "weapons.tuning.stats.critdamage", Format = "%.0f%%" },
    { Key = "Magazine", Label = "weapons.tuning.stats.magazine", Format = "%.0f", Ranged = true },
    { Key = "Reload", Label = "weapons.tuning.stats.reload", Format = "%.2f s", Ranged = true },
    { Key = "Range", Label = "weapons.tuning.stats.range", Format = "%.0f m", Ranged = true }
}

local s_State = { Name = "" }
local s_Name = Ref.Field(s_State, "Name")
local s_Enabled = Ref.Field(Tuning, "Enabled")
local s_Refs = {}
local s_Doc = nil
local s_DocStats = nil
local s_TuningDoc = nil
local s_TuningValues = {}

for name in pairs(Tuning.Ranges) do s_Refs[name] = Ref.Field(Tuning, name) end

local function Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function Change(stock, tuned, format)
    if not tuned then return nil end

    local text = string.format(format, tuned)
    if not stock or math.abs(tuned - stock) < 0.01 then return text end
    return string.format(format, stock) .. "  >  " .. text
end

local function AddStatRow(doc, stats, row)
    if row.Ranged and not stats.Ranged then return end

    local value = Change(stats.Stock[row.Key], stats[row.Key], row.Format)
    if value then table.insert(doc, { Kind = "Row", Label = L(row.Label), Value = value }) end
end

local function Eyebrow(enabled)
    return { Kind = "Eyebrow", Text = L(enabled and "weapons.tuning.stats.tuned" or "weapons.tuning.stats.stock") }
end

local function BuildDoc(stats)
    local name = stats.Name
    if not name or name == "" then name = L("weapons.tuning.stats.weapon") end

    local doc = {
        Eyebrow(stats.Enabled),
        { Kind = "Title", Text = name },
        { Kind = "Separator" }
    }
    for _, row in ipairs(STAT_ROWS) do AddStatRow(doc, stats, row) end
    table.insert(doc, { Kind = "Text", Text = L("weapons.tuning.stats.note"), Tone = "Dim" })
    return doc
end

local function TuningChanged()
    if s_TuningValues.Enabled ~= Tuning.Enabled then return true end
    for _, group in ipairs(GROUPS) do
        for _, entry in ipairs(group) do
            if s_TuningValues[entry.Name] ~= Tuning[entry.Name] then return true end
        end
    end
    return false
end

local function TuningDoc()
    if s_TuningDoc and not TuningChanged() then return s_TuningDoc end

    s_TuningValues = { Enabled = Tuning.Enabled }
    s_TuningDoc = {
        Eyebrow(Tuning.Enabled),
        { Kind = "Title", Text = L("weapons.tuning.stats.yours") },
        { Kind = "Separator" }
    }
    for _, group in ipairs(GROUPS) do
        for _, entry in ipairs(group) do
            local value = Tuning[entry.Name]
            s_TuningValues[entry.Name] = value
            table.insert(s_TuningDoc, { Kind = "Row", Label = L(entry.Label), Value = string.format(entry.Format, Round(value)) })
        end
    end
    table.insert(s_TuningDoc, { Kind = "Text", Text = L("weapons.tuning.stats.hold"), Tone = "Dim" })
    return s_TuningDoc
end

local function StatsDoc()
    local stats = Tuning.Stats()
    if not stats then return TuningDoc() end

    if stats ~= s_DocStats then
        s_DocStats = stats
        s_Doc = BuildDoc(stats)
    end
    return s_Doc
end

local function Describe(key)
    Widgets.Tip(L(key))
    Widgets.Info(StatsDoc)
end

local function Sliders(entries)
    for _, entry in ipairs(entries) do
        local range = Tuning.Ranges[entry.Name]
        Widgets.SliderInt(L(entry.Label), s_Refs[entry.Name], range.Min, range.Max, range.Step, entry.Format)
        Describe(entry.Tip)
    end
end

local function Summary(preset)
    local summary = s_Summaries[preset]
    if summary then return summary end

    local values = type(preset.Values) == "table" and preset.Values or {}
    summary = tip("weapons.tuning.presets.summary", {
        damage = string.format("%d", Round(values.Damage or 100)),
        firerate = string.format("%d", Round(values.FireRate or 100))
    })
    s_Summaries[preset] = summary
    return summary
end

local function PresetsView()
    if Widgets.InputText(L("weapons.tuning.presets.save.label"), s_Name, MAX_NAME, L("weapons.tuning.presets.save.placeholder")) then
        local name = Tuning.SavePreset(s_State.Name)
        s_State.Name = ""
        Notify.Success(tip("notify.weapons.tuning.saved", { name = name }))
    end
    Widgets.Tip(L("weapons.tuning.presets.save.tip"))

    local presets = Tuning.Presets
    if #presets == 0 then
        Widgets.ValueRow(L("weapons.tuning.presets.none"), "")
        return
    end

    Widgets.Break(L("weapons.tuning.presets.saved"))
    for _, preset in ipairs(presets) do
        if Widgets.Preset(tostring(preset.Name), nil, Summary(preset)) then
            Tuning.LoadPreset(preset)
            Notify.Success(tip("notify.weapons.tuning.loaded", { name = tostring(preset.Name) }))
        end
        Widgets.Tip(L("weapons.tuning.presets.load.tip"))
    end

    Widgets.Break(L("weapons.tuning.presets.delete"))
    local removed = nil
    for _, preset in ipairs(presets) do
        if Widgets.HoldButton(tostring(preset.Name)) then removed = preset end
        Widgets.Tip(L("weapons.tuning.presets.remove.tip"))
    end
    if removed then
        Tuning.DeletePreset(removed)
        Notify.Info(tip("notify.weapons.tuning.deleted", { name = tostring(removed.Name) }))
    end
end

local PresetsMenu = Submenu.Create("weapons.tuning.presets.label", PresetsView)

local function View()
    Tuning.Watch()

    Widgets.SubmenuButton(L("weapons.tuning.presets.label"), PresetsMenu)
    Describe("weapons.tuning.presets.tip")
    Widgets.Break("")
    Widgets.Toggle(L("weapons.tuning.enabled.label"), s_Enabled)
    Describe("weapons.tuning.enabled.tip")
    if Widgets.HoldButton(L("weapons.tuning.reset.label")) then Tuning.ResetValues() end
    Describe("weapons.tuning.reset.tip")

    Widgets.Break(L("weapons.tuning.groups.damage"))
    Sliders(DAMAGE)

    Widgets.Break(L("weapons.tuning.groups.firing"))
    Sliders(FIRING)

    Widgets.Break(L("weapons.tuning.groups.accuracy"))
    Sliders(ACCURACY)
end

TuningView.Menu = Submenu.Create("weapons.tuning.label", View)

return TuningView
