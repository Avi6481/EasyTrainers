local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local World = require("Features/World/World")
local Time = require("Features/World/Time")

local TimeView = {}

local KEY = "time."

local s_Clock = { Hours = 0, Minutes = 0, Seconds = 0 }
local s_Hour = Ref.Field(s_Clock, "Hours")
local s_Minute = Ref.Field(s_Clock, "Minutes")
local s_Second = Ref.Field(s_Clock, "Seconds")
local s_SkipDays = Ref.Field(Time, "SkipDays")
local s_SkipStep = Ref.Field(Time, "SkipStep")
local s_DaySpeed = Ref.Field(Time, "DaySpeed")
local s_NightSpeed = Ref.Field(Time, "NightSpeed")
local s_LapseSpeed = Ref.Field(Time, "LapseSpeed")
local s_Modes = {}
local s_Shown = { Signature = -1, Text24 = "", Text12 = "" }
local s_PresetTimes = {}

local function Mode(key)
    local ref = s_Modes[key]
    if not ref then
        ref = Ref.New(function() return Time[key] end, function(value) Time.Set(key, value) end)
        s_Modes[key] = ref
    end
    return ref
end

local function Format12(hours, minutes, seconds)
    local hour12 = hours % 12
    if hour12 == 0 then hour12 = 12 end
    return string.format("%02d:%02d:%02d %s", hour12, minutes, seconds, hours < 12 and "AM" or "PM")
end

local function Shown(hours, minutes, seconds)
    local signature = (hours * 3600) + (minutes * 60) + seconds
    if s_Shown.Signature ~= signature then
        s_Shown.Signature = signature
        s_Shown.Text24 = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        s_Shown.Text12 = Format12(hours, minutes, seconds)
    end
    return s_Shown
end

local function PresetTime(hours)
    local text = s_PresetTimes[hours]
    if not text then
        text = string.format("%02d:00", hours)
        s_PresetTimes[hours] = text
    end
    return text
end

local function Toggle(key, mode)
    Widgets.Toggle(L(KEY .. key .. ".label"), Mode(mode))
    Widgets.Tip(L(KEY .. key .. ".tip"))
end

local function Current()
    local shown = Shown(Time.Clock())
    Widgets.ValueRow(L(KEY .. "current24.label"), shown.Text24)
    Widgets.Tip(L(KEY .. "current24.tip"))
    Widgets.ValueRow(L(KEY .. "current12.label"), shown.Text12)
    Widgets.Tip(L(KEY .. "current12.tip"))
end

local function SetTime()
    Widgets.Break(L(KEY .. "settime"))
    s_Clock.Hours, s_Clock.Minutes, s_Clock.Seconds = Time.Clock()

    local changed = Widgets.SliderInt(L(KEY .. "hour.label"), s_Hour, 0, 23, 1, "%02d")
    if Widgets.Selected() then Widgets.Tip(tip(KEY .. "hour.tip", { time = Format12(s_Clock.Hours, 0, 0) })) end
    changed = Widgets.SliderInt(L(KEY .. "minute.label"), s_Minute, 0, 59, 1, "%02d") or changed
    Widgets.Tip(L(KEY .. "minute.tip"))
    changed = Widgets.SliderInt(L(KEY .. "second.label"), s_Second, 0, 59, 1, "%02d") or changed
    Widgets.Tip(L(KEY .. "second.tip"))

    if changed then Time.SetClock(s_Clock.Hours, s_Clock.Minutes, s_Clock.Seconds) end
end

local function Presets()
    Widgets.Break(L(KEY .. "presets"))
    for _, preset in ipairs(Time.Presets) do
        if Widgets.ValueRow(L(KEY .. preset.Key .. ".label"), PresetTime(preset.Hours), true) then Time.Preset(preset.Hours) end
        Widgets.Tip(L(KEY .. preset.Key .. ".tip"))
    end
end

local function Skip()
    Widgets.Break(L(KEY .. "skip"))
    if Widgets.NumberActionInt(L(KEY .. "skipdays.label"), s_SkipDays, 1, 100, 1, "%d") then Time.Skip() end
    Widgets.Tip(L(KEY .. "skipdays.tip"))
    Widgets.SliderInt(L(KEY .. "skipspeed.label"), s_SkipStep, 100, 5000, 100, "%d")
    Widgets.Tip(L(KEY .. "skipspeed.tip"))
end

local function Speed()
    Widgets.Break(L(KEY .. "speed"))
    Toggle("freeze", "Freeze")
    Toggle("sync", "Sync")
    Widgets.SliderFloat(L(KEY .. "dayspeed.label"), s_DaySpeed, 1, 10, 0.5, "%.1fx", Mode("DayEnabled"))
    Widgets.Tip(L(KEY .. "dayspeed.tip"))
    Widgets.SliderFloat(L(KEY .. "nightspeed.label"), s_NightSpeed, 1, 10, 0.5, "%.1fx", Mode("NightEnabled"))
    Widgets.Tip(L(KEY .. "nightspeed.tip"))
    Widgets.SliderInt(L(KEY .. "lapse.label"), s_LapseSpeed, 1, 64, 1, "%dx", Mode("LapseEnabled"))
    Widgets.Tip(L(KEY .. "lapse.tip"))
end

local function View()
    World.Watch()

    Current()
    SetTime()
    Presets()
    Skip()
    Speed()
end

TimeView.Menu = Submenu.Create("time.title", View)

return TimeView
