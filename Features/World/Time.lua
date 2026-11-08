local Notify = require("Utils/Notify")

local Time = {
    Freeze = false,
    Sync = false,
    DayEnabled = false,
    DaySpeed = 2,
    NightEnabled = false,
    NightSpeed = 2,
    LapseEnabled = false,
    LapseSpeed = 2,
    SkipDays = 1,
    SkipStep = 500,
    Now = { Hours = 0, Minutes = 0, Seconds = 0 }
}

Time.Presets = {
    { Key = "morning", Hours = 6 },
    { Key = "noon", Hours = 12 },
    { Key = "afternoon", Hours = 15 },
    { Key = "evening", Hours = 18 },
    { Key = "night", Hours = 22 }
}

local DAY = 86400
local HALF_DAY = 43200
local FREEZE_LIMIT = DAY - 30
local FREEZE_INTERVAL = 0.25
local SYNC_INTERVAL = 0.5
local LAPSE_INTERVAL = 0.1
local FAST_INTERVAL = 0.1
local SKIP_INTERVAL = 0.05
local SOURCE = "EasyTrainerWorldTime"
local SCENE_TIER_LIMIT = 3
local TRANSITION_TIME = 2.5
local TRANSITION_INTERVAL = 0.03

local MODES = { Freeze = true, Sync = true, LapseEnabled = true }
local SPEEDS = { DayEnabled = true, NightEnabled = true }

local s_Frozen = nil
local s_FreezeElapsed = 0
local s_SyncElapsed = 0
local s_LapseElapsed = 0
local s_FastElapsed = 0
local s_Skip = nil
local s_Transition = nil
local s_Clock = nil
local s_Preset = nil
local s_SkipDays = nil

local function ReadTime()
    local gameTime = Game.GetTimeSystem():GetGameTime()
    return gameTime:Hours(), gameTime:Minutes(), gameTime:Seconds()
end

local function SecondsOfDay()
    local hours, minutes, seconds = ReadTime()
    return (hours * 3600) + (minutes * 60) + seconds
end

local function SetSeconds(total)
    total = math.max(0, math.floor(total))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    Game.GetTimeSystem():SetGameTimeByHMS(hours, minutes, total % 60, SOURCE)
end

local function SetClock(target)
    if target + HALF_DAY < SecondsOfDay() then target = target + DAY end
    SetSeconds(target)
end

local function Format(total)
    total = total % DAY
    return string.format("%02d:%02d", math.floor(total / 3600), math.floor((total % 3600) / 60))
end

function Time.Set(key, value)
    Time[key] = value
    if not value then return end

    for mode in pairs(MODES) do
        if mode ~= key then Time[mode] = false end
    end
    if not MODES[key] then return end

    for speed in pairs(SPEEDS) do Time[speed] = false end
end

function Time.SetClock(hours, minutes, seconds)
    s_Clock = (hours * 3600) + (minutes * 60) + seconds
    Time.Now.Hours = hours
    Time.Now.Minutes = minutes
    Time.Now.Seconds = seconds
end

function Time.Clock()
    return Time.Now.Hours, Time.Now.Minutes, Time.Now.Seconds
end

function Time.Preset(hours)
    s_Preset = hours * 3600
end

function Time.Skip()
    s_SkipDays = math.max(1, Time.SkipDays)
end

function Time.Refresh()
    if s_Clock then return end
    Time.Now.Hours, Time.Now.Minutes, Time.Now.Seconds = ReadTime()
end

local function ApplyClock()
    local target = s_Clock
    s_Clock = nil

    if Time.Sync then
        Time.Sync = false
        Notify.Info(L("notify.world.syncoff"))
    end
    if s_Frozen then s_Frozen = math.min(target, FREEZE_LIMIT) end
    SetClock(target)
end

local function ApplyPreset()
    local target = s_Preset
    s_Preset = nil

    if Time.Freeze then
        Time.Freeze = false
        Notify.Info(tip("notify.world.freezeoff", { time = Format(target) }))
    end
    if Time.Sync then
        Time.Sync = false
        Notify.Info(L("notify.world.syncoff"))
    end

    local from = SecondsOfDay()
    if target <= from then target = target + DAY end
    s_Transition = { Distance = target - from, Target = target % DAY, Applied = 0, Elapsed = 0, Tick = 0 }
end

local function ApplySkip()
    local days = s_SkipDays
    s_SkipDays = nil

    if Time.Freeze or Time.Sync then
        Time.Freeze = false
        Time.Sync = false
        Notify.Info(L("notify.world.skipheld"))
    end
    s_Skip = { Remaining = days * DAY, Days = days, Elapsed = 0 }
end

local function Every(elapsed, delta, interval)
    elapsed = elapsed + delta
    if elapsed < interval then return elapsed, false end
    return 0, true
end

local function Ease(progress)
    if progress < 0.5 then return 2 * progress * progress end
    return 1 - (((-2 * progress) + 2) ^ 2) / 2
end

local function TickTransition(delta)
    if not s_Transition then return false end

    s_Transition.Elapsed = s_Transition.Elapsed + delta
    s_Transition.Tick = s_Transition.Tick + delta
    local progress = math.min(1, s_Transition.Elapsed / TRANSITION_TIME)
    if progress < 1 and s_Transition.Tick < TRANSITION_INTERVAL then return true end
    s_Transition.Tick = 0

    if progress >= 1 then
        SetClock(s_Transition.Target)
        s_Transition = nil
        return true
    end

    local offset = s_Transition.Distance * Ease(progress)
    SetSeconds(SecondsOfDay() + offset - s_Transition.Applied)
    s_Transition.Applied = offset
    return true
end

local function TickFreeze(delta)
    if not Time.Freeze then
        s_Frozen = nil
        s_FreezeElapsed = 0
        return false
    end

    if not s_Frozen then s_Frozen = math.min(SecondsOfDay(), FREEZE_LIMIT) end

    local ready
    s_FreezeElapsed, ready = Every(s_FreezeElapsed, delta, FREEZE_INTERVAL)
    if ready then SetClock(s_Frozen) end
    return true
end

local function TickSync(delta)
    if not Time.Sync then
        s_SyncElapsed = 0
        return
    end

    local ready
    s_SyncElapsed, ready = Every(s_SyncElapsed, delta, SYNC_INTERVAL)
    if not ready then return end

    local now = os.date("*t")
    SetClock((now.hour * 3600) + (now.min * 60) + now.sec)
end

local function TickSkip(delta)
    if not s_Skip then return end

    s_Skip.Elapsed = s_Skip.Elapsed + delta
    if s_Skip.Elapsed < SKIP_INTERVAL then return end
    s_Skip.Elapsed = 0

    local step = math.min(math.max(1, Time.SkipStep), s_Skip.Remaining)
    SetSeconds(SecondsOfDay() + step)
    s_Skip.Remaining = s_Skip.Remaining - step
    if s_Skip.Remaining > 0 then return end

    Notify.Success(tip("notify.world.skipped", { count = s_Skip.Days }))
    s_Skip = nil
end

local function TickFastTime(delta)
    if not Time.DayEnabled and not Time.NightEnabled then return end

    local ready
    s_FastElapsed, ready = Every(s_FastElapsed, delta, FAST_INTERVAL)
    if not ready then return end

    local now = SecondsOfDay()
    local hours = math.floor(now / 3600)
    local day = hours >= 6 and hours < 18
    if day and not Time.DayEnabled then return end
    if not day and not Time.NightEnabled then return end

    local speed = day and Time.DaySpeed or Time.NightSpeed
    SetSeconds(now + (10 * speed))
end

local function TickTimeLapse(delta)
    if not Time.LapseEnabled then return end

    s_LapseElapsed = s_LapseElapsed + delta
    if s_LapseElapsed < LAPSE_INTERVAL then return end

    local elapsed = s_LapseElapsed
    s_LapseElapsed = 0
    SetSeconds(SecondsOfDay() + (elapsed * Time.LapseSpeed * 60))
end

local function GameControlsTime(player)
    local blackboard = player:GetPlayerStateMachineBlackboard()
    if blackboard and blackboard:GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel) >= SCENE_TIER_LIMIT then return true end

    local workspot = Game.GetWorkspotSystem()
    return workspot ~= nil and workspot:IsActorInWorkspot(player)
end

local function Requested()
    return s_Clock ~= nil or s_Preset ~= nil or s_SkipDays ~= nil
end

local function Active()
    return Time.Freeze or Time.Sync or Time.LapseEnabled or Time.DayEnabled or Time.NightEnabled
        or s_Skip ~= nil or s_Transition ~= nil or Requested()
end

local function Blocked()
    if Requested() then Notify.Warning(L("notify.world.scenetime")) end
    s_Frozen = nil
    s_Transition = nil
    s_Clock = nil
    s_Preset = nil
    s_SkipDays = nil
end

function Time.Update(player, delta)
    if not Active() then return end

    if GameControlsTime(player) then
        Blocked()
        return
    end

    if s_Clock then ApplyClock() end
    if s_Preset then ApplyPreset() end
    if s_SkipDays then ApplySkip() end
    if TickTransition(delta) then return end
    if TickFreeze(delta) then return end

    TickSync(delta)
    TickSkip(delta)
    TickFastTime(delta)
    TickTimeLapse(delta)
end

function Time.Reset()
    s_Frozen = nil
    s_Skip = nil
    s_Transition = nil
    s_Clock = nil
    s_Preset = nil
    s_SkipDays = nil
    s_FreezeElapsed = 0
    s_SyncElapsed = 0
    s_LapseElapsed = 0
    s_FastElapsed = 0
end

function Time.Shutdown()
    Time.Reset()
end

return Time
