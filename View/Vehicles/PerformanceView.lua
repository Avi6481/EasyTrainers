local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local Performance = require("Features/Vehicles/Performance")

local PerformanceView = {}

local MAX_NAME = 32

local s_Summaries = setmetatable({}, { __mode = "k" })

local function Entry(name, key, format)
    return { Name = name, Label = key .. ".label", Tip = key .. ".tip", Format = format }
end

local ENGINE = {
    Entry("EnginePower", "vehicles.performance.enginepower", "%.1fx"),
    Entry("TopSpeedBonus", "vehicles.performance.topspeed", "+%.0f km/h"),
    Entry("Acceleration", "vehicles.performance.acceleration", "+%.1f m/s²"),
    Entry("ShiftSpeed", "vehicles.performance.shiftspeed", "%.1fx")
}

local HANDLING = {
    Entry("FrontGrip", "vehicles.performance.frontgrip", "%.1fx"),
    Entry("RearGrip", "vehicles.performance.reargrip", "%.1fx"),
    Entry("SteeringLock", "vehicles.performance.steering", "%.2fx"),
    Entry("Downforce", "vehicles.performance.downforce", "%.0f m/s²")
}

local BRAKES = {
    Entry("Braking", "vehicles.performance.braking", "+%.0f m/s²"),
    Entry("Handbrake", "vehicles.performance.handbrake", "%.1fx")
}

local STAT_ROWS = {
    { Key = "TopSpeed", Label = "vehicles.performance.stats.topspeed", Format = "%.0f km/h" },
    { Key = "Torque", Label = "vehicles.performance.stats.torque", Format = "%.0f Nm" },
    { Key = "Mass", Label = "vehicles.performance.stats.mass", Format = "%.0f kg" },
    { Key = "Shift", Label = "vehicles.performance.stats.shift", Format = "%.2f s" },
    { Key = "FrontGrip", Label = "vehicles.performance.stats.frontgrip", Format = "%.2f" },
    { Key = "RearGrip", Label = "vehicles.performance.stats.reargrip", Format = "%.2f" },
    { Key = "Steering", Label = "vehicles.performance.stats.steering", Format = "%.0f°" },
    { Key = "Handbrake", Label = "vehicles.performance.stats.handbrake", Format = "%.0f Nm" }
}

local s_State = { Name = "" }
local s_Name = Ref.Field(s_State, "Name")
local s_Enabled = Ref.Field(Performance, "Enabled")
local s_AirControl = Ref.Field(Performance, "AirControl")
local s_Refs = {}
local s_Doc = nil
local s_DocStats = nil
local s_TuningDoc = nil
local s_TuningValues = {}

for name in pairs(Performance.Ranges) do s_Refs[name] = Ref.Field(Performance, name) end

local function Change(stock, tuned, format)
    if not stock then return nil end

    local text = string.format(format, stock)
    if not tuned or math.abs(tuned - stock) < 0.0001 then return text end
    return text .. "  >  " .. string.format(format, tuned)
end

local function BuildDoc(stats)
    local name = stats.Name
    if not name or name == "" then name = L("vehicles.performance.stats.vehicle") end

    local doc = {
        { Kind = "Eyebrow", Text = L(stats.Enabled and "vehicles.performance.stats.tuned" or "vehicles.performance.stats.stock") },
        { Kind = "Title", Text = name },
        { Kind = "Separator" }
    }
    for _, row in ipairs(STAT_ROWS) do
        local value = Change(stats.Stock[row.Key], stats[row.Key], row.Format)
        if value then table.insert(doc, { Kind = "Row", Label = L(row.Label), Value = value }) end
    end
    table.insert(doc, { Kind = "Text", Text = L("vehicles.performance.stats.note"), Tone = "Dim" })
    return doc
end

local GROUPS = { ENGINE, HANDLING, BRAKES }

local function TuningChanged()
    if s_TuningValues.Enabled ~= Performance.Enabled or s_TuningValues.AirControl ~= Performance.AirControl then return true end
    for _, group in ipairs(GROUPS) do
        for _, entry in ipairs(group) do
            if s_TuningValues[entry.Name] ~= Performance[entry.Name] then return true end
        end
    end
    return false
end

local function TuningDoc()
    if s_TuningDoc and not TuningChanged() then return s_TuningDoc end

    s_TuningValues = { Enabled = Performance.Enabled, AirControl = Performance.AirControl }
    s_TuningDoc = {
        { Kind = "Eyebrow", Text = L(Performance.Enabled and "vehicles.performance.stats.tuned" or "vehicles.performance.stats.stock") },
        { Kind = "Title", Text = L("vehicles.performance.stats.yours") },
        { Kind = "Separator" }
    }
    for _, group in ipairs(GROUPS) do
        for _, entry in ipairs(group) do
            local value = Performance[entry.Name]
            s_TuningValues[entry.Name] = value
            table.insert(s_TuningDoc, { Kind = "Row", Label = L(entry.Label), Value = string.format(entry.Format, value) })
        end
    end
    table.insert(s_TuningDoc, {
        Kind = "Row",
        Label = L("vehicles.performance.aircontrol.label"),
        Value = L(Performance.AirControl and "vehicles.performance.stats.on" or "vehicles.performance.stats.off")
    })
    table.insert(s_TuningDoc, { Kind = "Text", Text = L("vehicles.performance.stats.drive"), Tone = "Dim" })
    return s_TuningDoc
end

local function StatsDoc()
    local stats = Performance.GetStats()
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
        local range = Performance.Ranges[entry.Name]
        Widgets.SliderFloat(L(entry.Label), s_Refs[entry.Name], range.Min, range.Max, range.Step, entry.Format)
        Describe(entry.Tip)
    end
end

local function Summary(preset)
    local summary = s_Summaries[preset]
    if summary then return summary end

    local values = type(preset.Values) == "table" and preset.Values or {}
    summary = tip("vehicles.performance.presets.summary", {
        power = string.format("%.1f", tonumber(values.EnginePower) or 1),
        grip = string.format("%.1f", tonumber(values.RearGrip) or 1)
    })
    s_Summaries[preset] = summary
    return summary
end

local function PresetsView()
    if Widgets.InputText(L("vehicles.performance.presets.save.label"), s_Name, MAX_NAME, L("vehicles.performance.presets.save.placeholder")) then
        local name = Performance.SavePreset(s_State.Name)
        s_State.Name = ""
        Notify.Success(tip("notify.performance.saved", { name = name }))
    end
    Widgets.Tip(L("vehicles.performance.presets.save.tip"))

    local presets = Performance.Presets
    if #presets == 0 then
        Widgets.ValueRow(L("vehicles.performance.presets.none"), "")
        return
    end

    Widgets.Break(L("vehicles.performance.presets.saved"))
    for _, preset in ipairs(presets) do
        if Widgets.Preset(tostring(preset.Name), nil, Summary(preset)) then
            Performance.LoadPreset(preset)
            Notify.Success(tip("notify.performance.loaded", { name = tostring(preset.Name) }))
        end
        Widgets.Tip(L("vehicles.performance.presets.load.tip"))
    end

    Widgets.Break(L("vehicles.performance.presets.delete"))
    local removed = nil
    for _, preset in ipairs(presets) do
        if Widgets.HoldButton(tostring(preset.Name)) then removed = preset end
        Widgets.Tip(L("vehicles.performance.presets.remove.tip"))
    end
    if removed then
        Performance.DeletePreset(removed)
        Notify.Info(tip("notify.performance.deleted", { name = tostring(removed.Name) }))
    end
end

local PresetsMenu = Submenu.Create("vehicles.performance.presets.label", PresetsView)

local function View()
    Performance.Watch()

    Widgets.SubmenuButton(L("vehicles.performance.presets.label"), PresetsMenu)
    Describe("vehicles.performance.presets.tip")
    Widgets.Toggle(L("vehicles.performance.enabled.label"), s_Enabled)
    Describe("vehicles.performance.enabled.tip")
    if Widgets.HoldButton(L("vehicles.performance.reset.label")) then Performance.ResetValues() end
    Describe("vehicles.performance.reset.tip")

    Widgets.Break(L("vehicles.performance.engine"))
    Sliders(ENGINE)

    Widgets.Break(L("vehicles.performance.handling"))
    Sliders(HANDLING)
    Widgets.Toggle(L("vehicles.performance.aircontrol.label"), s_AirControl)
    Describe("vehicles.performance.aircontrol.tip")

    Widgets.Break(L("vehicles.performance.brakes"))
    Sliders(BRAKES)
end

PerformanceView.Menu = Submenu.Create("vehicles.performance.label", View)

return PerformanceView
