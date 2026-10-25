local Logger = require("Core/Logger")
local Notification = require("UI/Panels/Notification/Notification")

local WorldTime = {}

WorldTime.DaySpeed = { value = 2.0, min = 1.0, max = 10.0, step = 0.5, enabled = false }
WorldTime.NightSpeed = { value = 2.0, min = 1.0, max = 10.0, step = 0.5, enabled = false }
WorldTime.FreezeTime = { value = false }
WorldTime.TimeLapse = { value = false }
WorldTime.SyncToSystemClock = { value = false }
WorldTime.TimeLapseMultiplier = { value = 2, min = 1, max = 64, step = 1.0 }

local SECONDS_PER_DAY = 86400
local FREEZE_INTERVAL = 0.25
local SYNC_INTERVAL = 0.5
local LAPSE_INTERVAL = 0.1
local FAST_INTERVAL = 0.1
local SKIP_INTERVAL = 0.05
local SOURCE = "EasyTrainerWorldTime"
local SCENE_TIER_LIMIT = 3
local TRANSITION_TIME = 2.5
local TRANSITION_INTERVAL = 0.03

local s_Frozen = nil
local s_FreezeElapsed = 0
local s_SyncElapsed = 0
local s_LapseElapsed = 0
local s_FastElapsed = 0
local s_Skip = nil
local s_Transition = nil

local function GetTimeSystem()
    local ok, system = pcall(Game.GetTimeSystem)
    return ok and system or nil
end

local function SplitSeconds(totalSeconds)
    return math.floor((totalSeconds / 3600) % 24), math.floor((totalSeconds % 3600) / 60), math.floor(totalSeconds % 60)
end

function WorldTime.GetTime()
    local system = GetTimeSystem()
    local ok, gameTime = pcall(function() return system:GetGameTime() end)
    if not system or not ok or not gameTime then return { hours = 0, minutes = 0, seconds = 0 } end

    return {
        hours = gameTime:Hours(),
        minutes = gameTime:Minutes(),
        seconds = gameTime:Seconds(),
        raw = gameTime
    }
end

local function SecondsOfDay()
    local now = WorldTime.GetTime()
    return now.hours * 3600 + now.minutes * 60 + now.seconds
end

function WorldTime.SetGameTime(hours, minutes, seconds)
    local system = GetTimeSystem()
    if not system then return false end
    return pcall(function() system:SetGameTimeByHMS(hours, minutes, seconds, SOURCE) end)
end

local function ApplyTime(hours, minutes, seconds, label)
    if WorldTime.FreezeTime.value then
        WorldTime.FreezeTime.value = false
        Notification.Info(string.format("Time set to %s and disabled Freeze Time", label))
    end

    if WorldTime.SyncToSystemClock.value then
        WorldTime.SyncToSystemClock.value = false
        Notification.Info("System clock sync disabled to apply custom time")
    end

    local from = SecondsOfDay()
    local target = hours * 3600 + minutes * 60 + seconds
    if target <= from then target = target + SECONDS_PER_DAY end
    s_Transition = { From = from, Target = target, Elapsed = 0, Tick = 0 }
end

function WorldTime.SetExclusiveMode(keep, enabled)
    if not enabled then return end
    if keep ~= WorldTime.FreezeTime then WorldTime.FreezeTime.value = false end
    if keep ~= WorldTime.SyncToSystemClock then WorldTime.SyncToSystemClock.value = false end
    if keep ~= WorldTime.TimeLapse then WorldTime.TimeLapse.value = false end
    WorldTime.DaySpeed.enabled = false
    WorldTime.NightSpeed.enabled = false
end

function WorldTime.SetTimeMorning() ApplyTime(6, 0, 0, "Morning (6:00)") end
function WorldTime.SetTimeNoon() ApplyTime(12, 0, 0, "Noon (12:00)") end
function WorldTime.SetTimeAfternoon() ApplyTime(15, 0, 0, "Afternoon (15:00)") end
function WorldTime.SetTimeEvening() ApplyTime(18, 0, 0, "Evening (18:00)") end
function WorldTime.SetTimeNight() ApplyTime(22, 0, 0, "Night (22:00)") end

function WorldTime.SkipDays(days, step)
    local system = GetTimeSystem()
    if not system then return end

    days = math.max(1, days or 1)
    local start = system:GetGameTime():Seconds()
    s_Skip = {
        Current = start,
        Target = start + days * SECONDS_PER_DAY,
        Step = step or 500,
        Elapsed = 0,
        Days = days
    }
end

local function Every(elapsed, deltaTime, interval)
    elapsed = elapsed + deltaTime
    if elapsed < interval then return elapsed, false end
    return 0, true
end

local function TickFreeze(deltaTime)
    if not WorldTime.FreezeTime.value then
        s_Frozen = nil
        s_FreezeElapsed = 0
        return false
    end

    if not s_Frozen then
        local now = WorldTime.GetTime()
        s_Frozen = { now.hours, now.minutes, now.seconds }
    end

    local ready
    s_FreezeElapsed, ready = Every(s_FreezeElapsed, deltaTime, FREEZE_INTERVAL)
    if ready then WorldTime.SetGameTime(s_Frozen[1], s_Frozen[2], s_Frozen[3]) end
    return true
end

local function TickSync(deltaTime)
    if not WorldTime.SyncToSystemClock.value then
        s_SyncElapsed = 0
        return
    end

    local ready
    s_SyncElapsed, ready = Every(s_SyncElapsed, deltaTime, SYNC_INTERVAL)
    if not ready then return end

    local now = os.date("*t")
    WorldTime.SetGameTime(now.hour, now.min, now.sec)
end

local function TickSkip(deltaTime)
    if not s_Skip then return end

    s_Skip.Elapsed = s_Skip.Elapsed + deltaTime
    if s_Skip.Elapsed < SKIP_INTERVAL then return end
    s_Skip.Elapsed = 0
    s_Skip.Current = s_Skip.Current + s_Skip.Step

    if s_Skip.Current >= s_Skip.Target then
        Logger.Log(string.format("WorldTime: skipped %d day(s)", s_Skip.Days))
        Notification.Info(string.format("Skipped %d day(s)", s_Skip.Days))
        s_Skip = nil
        return
    end

    WorldTime.SetGameTime(SplitSeconds(s_Skip.Current))
end

local function Ease(progress)
    return progress < 0.5 and 2 * progress * progress or 1 - ((-2 * progress + 2) ^ 2) / 2
end

local function TickTransition(deltaTime)
    if not s_Transition then return false end

    s_Transition.Elapsed = s_Transition.Elapsed + deltaTime
    s_Transition.Tick = s_Transition.Tick + deltaTime
    local progress = math.min(1, s_Transition.Elapsed / TRANSITION_TIME)
    if progress < 1 and s_Transition.Tick < TRANSITION_INTERVAL then return true end
    s_Transition.Tick = 0

    local current = s_Transition.From + (s_Transition.Target - s_Transition.From) * Ease(progress)
    WorldTime.SetGameTime(SplitSeconds(current))
    if progress >= 1 then s_Transition = nil end
    return true
end

local function TickFastTime(deltaTime)
    if not WorldTime.DaySpeed.enabled and not WorldTime.NightSpeed.enabled then return end

    local ready
    s_FastElapsed, ready = Every(s_FastElapsed, deltaTime, FAST_INTERVAL)
    if not ready then return end

    local hours = WorldTime.GetTime().hours
    local isDay = hours >= 6 and hours < 18
    local speed = isDay and WorldTime.DaySpeed or WorldTime.NightSpeed
    if not speed.enabled then return end

    WorldTime.SetGameTime(SplitSeconds(SecondsOfDay() + 10 * speed.value))
end

local function TickTimeLapse(deltaTime)
    if not WorldTime.TimeLapse.value then return end

    s_LapseElapsed = s_LapseElapsed + deltaTime
    if s_LapseElapsed < LAPSE_INTERVAL then return end

    local elapsed = s_LapseElapsed
    s_LapseElapsed = 0
    WorldTime.SetGameTime(SplitSeconds(SecondsOfDay() + elapsed * WorldTime.TimeLapseMultiplier.value * 60))
end

local function IsGameControllingTime()
    local player = Game.GetPlayer()
    if not player then return true end

    local blackboard = player:GetPlayerStateMachineBlackboard()
    if blackboard and blackboard:GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel) >= SCENE_TIER_LIMIT then return true end

    local workspot = Game.GetWorkspotSystem()
    return workspot ~= nil and workspot:IsActorInWorkspot(player)
end

local function IsAnyTimeFeatureActive()
    return WorldTime.FreezeTime.value or WorldTime.SyncToSystemClock.value or WorldTime.TimeLapse.value
        or WorldTime.DaySpeed.enabled or WorldTime.NightSpeed.enabled or s_Skip ~= nil or s_Transition ~= nil
end

function WorldTime.Update(deltaTime)
    deltaTime = deltaTime or 0
    if not IsAnyTimeFeatureActive() then return end

    if IsGameControllingTime() then
        s_Frozen = nil
        s_Transition = nil
        return
    end

    if TickTransition(deltaTime) then return end
    if TickFreeze(deltaTime) then return end

    TickSync(deltaTime)
    TickSkip(deltaTime)
    TickFastTime(deltaTime)
    TickTimeLapse(deltaTime)
end

return WorldTime
