local Define = require("Features/Hotkeys/Define")
local Notify = require("Utils/Notify")
local World = require("Features/World/World")
local Weather = require("Features/World/Weather")

local Toggle, Action = Define.Toggle, Define.Action

local function Random()
    World.Run(function()
        local entry = Weather.SetRandom()
        if not entry then return Notify.Error(L("notify.world.weatherfailed")) end
        Notify.Success(tip("notify.world.weatherset", { weather = "weather.states." .. entry.Key }))
    end)
end

local function Reset()
    World.Run(function()
        if not Weather.ResetWeather() then return Notify.Error(L("notify.world.weatherfailed")) end
        Notify.Info(L("notify.world.weatherreset"))
    end)
end

local WeatherHotkeys = {
    Toggle("Freeze", "weather.freeze", Weather, "Freeze"),
    Action("Random", "weather.random", Random, { Silent = true }),
    Action("Reset", "weather.reset", Reset, { Silent = true })
}

return WeatherHotkeys
