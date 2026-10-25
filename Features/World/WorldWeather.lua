local Logger = require("Core/Logger")
local Lifecycle = require("Core/Lifecycle")

local WorldWeather = {}

WorldWeather.Freeze = { value = false }

WorldWeather.States = {
    "24h_weather_sunny",
    "24h_weather_light_clouds",
    "24h_weather_cloudy",
    "24h_weather_heavy_clouds",
    "24h_weather_fog",
    "24h_weather_rain",
    "24h_weather_toxic_rain",
    "24h_weather_pollution",
    "24h_weather_sandstorm",
    "q302_deeb_blue",
    "q302_light_rain",
    "q302_squat_morning",
    "q306_epilogue_cloudy_morning",
    "q306_rainy_night",
    "sa_courier_clouds"
}

local CHECK_INTERVAL = 1.0
local ENFORCE_BLEND = 5

local s_Locked = nil
local s_Enforced = false
local s_NextCheck = 0

local function HasNative()
    return EasyWeather ~= nil and EasyWeather.SetWeather ~= nil
end

function WorldWeather.IsAvailable()
    return HasNative()
end

function WorldWeather.GetCurrentWeather()
    if HasNative() then
        local ok, state = pcall(EasyWeather.GetWeatherState)
        return ok and state and state.value ~= "" and state.value or "Unknown"
    end

    local system = Game.GetWeatherSystem()
    local ok, state = pcall(function() return system:GetWeatherState() end)
    return ok and state and tostring(state.name.value) or "Unknown"
end

function WorldWeather.SetWeather(state, blendSeconds)
    blendSeconds = blendSeconds or 1
    local ok = false
    if HasNative() then
        ok = pcall(EasyWeather.SetWeather, CName.new(state), blendSeconds, 1)
    else
        ok = pcall(function() Game.GetWeatherSystem():SetWeather(state, blendSeconds, 1) end)
    end
    Logger.Log(string.format("WorldWeather: set %s (%ds)%s", state, blendSeconds, ok and "" or " failed, EasyTrainerUtility weather is missing"))
end

local s_AllStates = nil

function WorldWeather.GetAllStates()
    if s_AllStates and #s_AllStates > 0 then return s_AllStates end
    s_AllStates = {}
    if not HasNative() then return s_AllStates end

    local ok, states = pcall(EasyWeather.GetWeatherStates)
    if not ok or type(states) ~= "table" then return s_AllStates end
    for _, state in ipairs(states) do
        local name = state and state.value or nil
        if name and name ~= "" then table.insert(s_AllStates, name) end
    end
    table.sort(s_AllStates)
    return s_AllStates
end

function WorldWeather.SetRandomWeather()
    WorldWeather.SetWeather(WorldWeather.States[math.random(1, #WorldWeather.States)])
end

function WorldWeather.ResetWeather()
    if HasNative() then
        pcall(EasyWeather.ResetWeather, true)
    else
        pcall(function() Game.GetWeatherSystem():ResetWeather(true) end)
    end
    Logger.Log("WorldWeather: reset weather")
end

local function Release()
    if s_Enforced then WorldWeather.ResetWeather() end
    s_Locked = nil
    s_Enforced = false
end

function WorldWeather.Update()
    if not WorldWeather.Freeze.value then
        if s_Locked then Release() end
        return
    end

    if not s_Locked then s_Locked = WorldWeather.GetCurrentWeather() end

    local now = os.clock()
    if now < s_NextCheck then return end
    s_NextCheck = now + CHECK_INTERVAL

    if WorldWeather.GetCurrentWeather() ~= s_Locked then
        WorldWeather.SetWeather(s_Locked, ENFORCE_BLEND)
        s_Enforced = true
    end
end

Lifecycle.Register("WorldWeather", {
    OnSessionEnd = function()
        s_Locked = nil
        s_Enforced = false
    end,
    OnShutdown = Release
})

return WorldWeather
