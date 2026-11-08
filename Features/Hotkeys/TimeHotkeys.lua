local Define = require("Features/Hotkeys/Define")
local Time = require("Features/World/Time")

local Toggle, Slider, Action = Define.Toggle, Define.Slider, Define.Action

local SET_TIME = "hotkeys.names.settime"

local function Mode(key)
    return function(value) Time.Set(key, value) end
end

local function Preset(hours)
    return function() Time.Preset(hours) end
end

local TimeHotkeys = {
    Toggle("Freeze", "time.freeze", Time, "Freeze", { Set = Mode("Freeze") }),
    Toggle("Sync", "time.sync", Time, "Sync", { Set = Mode("Sync") }),
    Slider("DaySpeed", "time.dayspeed", Time, "DaySpeed", "%.1fx", { Field = "DayEnabled", Set = Mode("DayEnabled") }),
    Slider("NightSpeed", "time.nightspeed", Time, "NightSpeed", "%.1fx", { Field = "NightEnabled", Set = Mode("NightEnabled") }),
    Slider("Lapse", "time.lapse", Time, "LapseSpeed", "%dx", { Field = "LapseEnabled", Set = Mode("LapseEnabled") }),
    Action("SkipDays", "time.skipdays", Time.Skip)
}

for index, preset in ipairs(Time.Presets) do
    local name = preset.Key:sub(1, 1):upper() .. preset.Key:sub(2)
    table.insert(TimeHotkeys, Action(name, "time." .. preset.Key, Preset(preset.Hours), {
        Break = index == 1 and "time.presets" or nil,
        Pattern = SET_TIME
    }))
end

return TimeHotkeys
