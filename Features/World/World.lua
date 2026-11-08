local Logger = require("Core/Logger")

local World = {}

World.Time = require("Features/World/Time")
World.Weather = require("Features/World/Weather")
World.Facts = require("Features/World/Facts")

local FEATURES = {
    { "Time", World.Time, { "Freeze", "Sync", "DayEnabled", "DaySpeed", "NightEnabled", "NightSpeed", "LapseEnabled", "LapseSpeed", "SkipDays", "SkipStep" } },
    { "Weather", World.Weather, { "Freeze", "Blend" } },
    { "Facts", World.Facts, {} }
}

local WATCH_TIME = 1
local MAX_DELTA = 0.1

local s_Queue = {}
local s_WatchUntil = 0
local s_LastClock = nil
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

local function Each(stage, ...)
    for _, entry in ipairs(FEATURES) do
        local callback = entry[2][stage]
        if callback then Try(entry[1], callback, ...) end
    end
end

function World.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function World.Watching()
    return os.clock() < s_WatchUntil
end

function World.Run(action)
    table.insert(s_Queue, action)
end

local function RunQueue(player)
    local queue = s_Queue
    s_Queue = {}
    for _, action in ipairs(queue) do Try("World action", action, player) end
end

function World.Bind(store)
    for _, entry in ipairs(FEATURES) do
        if #entry[3] > 0 then store:Bind("World." .. entry[1], entry[2], entry[3]) end
    end
end

function World.Initialize()
end

function World.Update(player)
    local now = os.clock()
    local delta = s_LastClock and math.max(0, math.min(MAX_DELTA, now - s_LastClock)) or 0
    s_LastClock = now

    if #s_Queue > 0 then RunQueue(player) end
    Try("Time", World.Time.Update, player, delta)
    Try("Weather", World.Weather.Update)
    Try("Facts", World.Facts.Update, now)

    if not World.Watching() then return end
    Try("Time refresh", World.Time.Refresh)
    Try("Weather refresh", World.Weather.Refresh)
end

function World.Reset()
    s_Queue = {}
    s_LastClock = nil
    Each("Reset")
end

function World.Shutdown(player)
    s_Queue = {}
    Each("Shutdown", player)
end

return World
