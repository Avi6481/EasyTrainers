local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")
local Catalog = require("Features/Development/Catalog")
local Snapshot = require("Features/Development/Snapshot")
local SkillRewards = require("Features/Development/SkillRewards")
local PerkFilter = require("Features/Development/PerkFilter")

local Development = {
    ForceBuy = true
}

local REFRESH_INTERVAL = 0.5
local WATCH_TIME = 1

local s_Queue = {}
local s_WatchUntil = 0
local s_NextRefresh = 0
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

function Development.Watch()
    local now = os.clock()
    if now > s_WatchUntil then Notify.Warning(L("notify.dev.save"), 6) end
    s_WatchUntil = now + WATCH_TIME
end

function Development.Queue(action, ...)
    table.insert(s_Queue, { Action = action, Args = { n = select("#", ...), ... } })
end

local function RunQueue()
    local queue = s_Queue
    s_Queue = {}

    for _, entry in ipairs(queue) do
        Try("Development action", entry.Action, unpack(entry.Args, 1, entry.Args.n))
    end
    return #queue > 0
end

function Development.Bind(store)
    store:Bind("Development", Development, { "ForceBuy" })
    store:Bind("Development.PerkFilter", PerkFilter, { "Mode" })
end

function Development.Initialize()
end

function Development.Update(player)
    local now = os.clock()
    if now >= s_WatchUntil and #s_Queue == 0 then return end

    local data = PlayerDevelopmentSystem.GetData(player)
    if not data then return end

    if not Catalog.Loaded and not Try("Development catalog", Catalog.Load, data) then return end
    if not SkillRewards.Loaded then Try("Skill rewards", SkillRewards.Load) end

    local acted = RunQueue()
    if acted or now >= s_NextRefresh then
        s_NextRefresh = now + REFRESH_INTERVAL
        Try("Development refresh", Snapshot.Refresh, data, player)
    end
end

function Development.Reset()
    s_Queue = {}
    Snapshot.Clear()
end

function Development.Shutdown()
    s_Queue = {}
end

return Development
