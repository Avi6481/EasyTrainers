local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local WorldWeather = require("Features/World/WorldWeather")

local OPTION_KEYS = {
    "worldweather.options.sunny",
    "worldweather.options.lightclouds",
    "worldweather.options.cloudy",
    "worldweather.options.heavyclouds",
    "worldweather.options.fog",
    "worldweather.options.rain",
    "worldweather.options.toxicrain",
    "worldweather.options.pollution",
    "worldweather.options.sandstorm",
    "worldweather.options.deebblue",
    "worldweather.options.lightRain",
    "worldweather.options.squatmorning",
    "worldweather.options.cloudymorning",
    "worldweather.options.rainnight",
    "worldweather.options.cloudscourier"
}

local s_Selected = { index = 1 }
local s_Transition = { value = 1, min = 1, max = 60, step = 1 }

local function CurrentIndex(current)
    for index, state in ipairs(WorldWeather.States) do
        if state == current then return index end
    end
    return 1
end

local function Pretty(state)
    return (state:gsub("^24h_weather_", ""):gsub("_", " "):gsub("(%a)(%w*)", function(first, rest) return first:upper() .. rest end))
end

local function AllStatesView()
    local states = WorldWeather.GetAllStates()
    if #states == 0 then
        Buttons.Option("No Weather States Found", "The EasyTrainerUtility plugin could not read the weather list in this session.", function() end)
        return
    end

    local current = WorldWeather.GetCurrentWeather()
    for _, state in ipairs(states) do
        Buttons.OptionExtended(Pretty(state), "", state == current and "ACTIVE" or "", "Switch to the " .. state .. " weather state.", function()
            WorldWeather.SetWeather(state, s_Transition.value)
        end)
    end
end

local AllStatesMenu = Submenu.Create("All Weather States", AllStatesView)

local function WeatherView()
    local current = WorldWeather.GetCurrentWeather()
    s_Selected.index = CurrentIndex(current)

    Buttons.Submenu("All Weather States", AllStatesMenu, "Every weather state the game has, including quest-only ones.")

    Buttons.Break("")
    Buttons.OptionExtended(L("worldweather.current.label"), "", current, L("worldweather.current.tip"))
    Buttons.Toggle(L("worldweather.freeze.label"), WorldWeather.Freeze, L("worldweather.freeze.tip"))
    Buttons.Option(L("worldweather.random.label"), L("worldweather.random.tip"), WorldWeather.SetRandomWeather)
    Buttons.Option(L("worldweather.reset.label"), L("worldweather.reset.tip"), WorldWeather.ResetWeather)
    Buttons.Int(L("worldweather.transitionduration.label"), s_Transition, L("worldweather.transitionduration.tip"))

    Buttons.Break(L("worldweather.weathertypebreak.label"))
    Buttons.Radio(L("worldweather.weathertype.label"), s_Selected, OPTION_KEYS, L("worldweather.weathertype.tip"), function(index)
        WorldWeather.SetWeather(WorldWeather.States[index], s_Transition.value)
    end)
end

return Submenu.Create("worldweather.title", WeatherView)
