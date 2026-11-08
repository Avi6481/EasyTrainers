local Logger = require("Core/Logger")

local Weather = {
    Freeze = false,
    Blend = 1,
    Current = "",
    Forced = false
}

Weather.States = {
    { Name = "24h_weather_sunny", Key = "sunny" },
    { Name = "24h_weather_light_clouds", Key = "lightclouds" },
    { Name = "24h_weather_cloudy", Key = "cloudy" },
    { Name = "24h_weather_heavy_clouds", Key = "heavyclouds" },
    { Name = "24h_weather_fog", Key = "fog" },
    { Name = "24h_weather_rain", Key = "rain" },
    { Name = "24h_weather_toxic_rain", Key = "toxicrain" },
    { Name = "24h_weather_pollution", Key = "pollution" },
    { Name = "24h_weather_sandstorm", Key = "sandstorm" },
    { Name = "q302_deeb_blue", Key = "deebblue" },
    { Name = "q302_light_rain", Key = "lightrain" },
    { Name = "q302_squat_morning", Key = "squatmorning" },
    { Name = "q306_epilogue_cloudy_morning", Key = "cloudymorning" },
    { Name = "q306_rainy_night", Key = "rainynight" },
    { Name = "sa_courier_clouds", Key = "courierclouds" }
}

local CHECK_INTERVAL = 1
local ENFORCE_BLEND = 5
local PRIORITY = 1

local s_Locked = nil
local s_NextCheck = 0
local s_AllStates = nil

local function Native()
    return EasyWeather ~= nil and EasyWeather.SetWeather ~= nil
end

local function ReadNative()
    local state = EasyWeather.GetWeatherState()
    return state and state.value or ""
end

local function ReadSystem()
    local state = Game.GetWeatherSystem():GetWeatherState()
    return state and tostring(state.name.value) or ""
end

local function ReadState()
    local ok, state = pcall(Native() and ReadNative or ReadSystem)
    if ok and state then return state end
    return ""
end

function Weather.Set(state, blend)
    blend = blend or Weather.Blend

    local ok, result
    if Native() then
        ok, result = pcall(EasyWeather.SetWeather, CName.new(state), blend, PRIORITY)
    else
        ok, result = pcall(function() return Game.GetWeatherSystem():SetWeather(state, blend, PRIORITY) end)
    end

    local applied = ok and result ~= false
    if applied then
        Weather.Forced = true
        Weather.Current = state
    end
    Logger.Log(string.format("Weather: set %s (%ds)%s", state, blend, applied and "" or " failed"))
    return applied
end

function Weather.SetRandom()
    local entry = Weather.States[math.random(1, #Weather.States)]
    if Weather.Set(entry.Name) then return entry end
    return nil
end

local function Release(force)
    local ok, result
    if Native() then
        ok, result = pcall(EasyWeather.ResetWeather, force)
    else
        ok, result = pcall(function() return Game.GetWeatherSystem():ResetWeather(force) end)
    end

    local released = ok and result ~= false
    if released then Weather.Forced = false end
    Logger.Log("Weather: released" .. (released and "" or " failed"))
    return released
end

function Weather.ResetWeather()
    s_Locked = nil
    local ok = Release(true)
    Weather.Refresh()
    return ok
end

local function LoadAllStates()
    if not Native() then return end

    local ok, states = pcall(EasyWeather.GetWeatherStates)
    if not ok or type(states) ~= "table" or #states == 0 then return end

    local names = {}
    for _, state in ipairs(states) do
        local name = state and state.value or nil
        if name and name ~= "" then table.insert(names, name) end
    end
    table.sort(names)
    s_AllStates = names
end

function Weather.AllStates()
    return s_AllStates or {}
end

function Weather.Refresh()
    Weather.Current = ReadState()
    if not s_AllStates then LoadAllStates() end
end

function Weather.Update()
    if not Weather.Freeze then
        if not s_Locked then return end
        s_Locked = nil
        if Weather.Forced then Release(false) end
        return
    end

    if not s_Locked then
        local state = ReadState()
        if state ~= "" then s_Locked = state end
        return
    end

    local now = os.clock()
    if now < s_NextCheck then return end
    s_NextCheck = now + CHECK_INTERVAL

    if ReadState() ~= s_Locked then Weather.Set(s_Locked, ENFORCE_BLEND) end
end

function Weather.Reset()
    s_Locked = nil
    if Weather.Forced then Release(false) end
end

function Weather.Shutdown()
    s_Locked = nil
    if Weather.Forced then Release(false) end
end

return Weather
