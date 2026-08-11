local ConfigManager = require("Config/OptionConfig")

local WorldTime = require("Features/World").WorldTime
local WorldWeather = require("Features/World").WorldWeather
local Toggle = ConfigManager.DefineToggle

local function RegisterAllWorldOptions()
    ConfigManager.RegisterAll({
        Toggle("toggle.world.freezeTime", WorldTime.toggleFreezeTime, false, {
            LabelKey = "worldtime.freezetime.label", TipKey = "worldtime.freezetime.tip",
            Keywords = { "clock", "pause" },
        }),
        Toggle("toggle.world.timeLapse", WorldTime.toggleTimeLapse, false, {
            LabelKey = "worldtime.enabletimelapse.label", TipKey = "worldtime.enabletimelapse.tip",
            Keywords = { "clock", "speed" },
        }),
        Toggle("toggle.world.syncSystemClock", WorldTime.toggleSyncToSystemClock, false, {
            LabelKey = "worldtime.synctopc.label", TipKey = "worldtime.synctopc.tip",
            Keywords = { "clock", "computer", "real time" },
        }),
        Toggle("toggle.world.freezeWeather", WorldWeather.freezeWeather, false, {
            LabelKey = "worldweather.freeze.label", TipKey = "worldweather.freeze.tip",
            Keywords = { "climate", "rain", "sun" },
        }),
        { Id = "number.world.timeLapseMultiplier", Kind = ConfigManager.Registry.Kind.Number,
            Ref = WorldTime.timeLapseMultiplier, Default = 2, Label = "Time Lapse Multiplier", Category = "world" },
        { Id = "number.world.daySpeed", Kind = ConfigManager.Registry.Kind.Number,
            Ref = WorldTime.daySpeedMultiplier, Default = 2.0, Label = "Day Speed", Category = "world" },
        { Id = "number.world.nightSpeed", Kind = ConfigManager.Registry.Kind.Number,
            Ref = WorldTime.nightSpeedMultiplier, Default = 2.0, Label = "Night Speed", Category = "world" },
    })
end


return RegisterAllWorldOptions
