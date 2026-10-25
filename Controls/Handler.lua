local Logger = require("Core/Logger")
local State = require("Controls/State")
local Bindings = require("Controls/Bindings")
local Restrictions = require("Controls/Restrictions")
local Cursor = require("Controls/Cursor")
local OptionConfig = require("Config/OptionConfig")

local Handler = {
    Defaults = {
        ScrollDelayBase = 200,
        ScrollMinDelay = 30,
        AccelThreshold = 1250,
        AccelStep = 20
    }
}

Handler.ScrollDelayBase = Handler.Defaults.ScrollDelayBase
Handler.ScrollMinDelay = Handler.Defaults.ScrollMinDelay
Handler.AccelThreshold = Handler.Defaults.AccelThreshold
Handler.AccelStep = Handler.Defaults.AccelStep

local REPEATING_ACTIONS = {
    { Action = "UP", Flag = "UpPressed" },
    { Action = "DOWN", Flag = "DownPressed" },
    { Action = "LEFT", Flag = "LeftPressed" },
    { Action = "RIGHT", Flag = "RightPressed" }
}

local SINGLE_ACTIONS = {
    { Action = "SELECT", Flag = "SelectPressed" },
    { Action = "BACK", Flag = "BackPressed" },
    { Action = "MISC", Flag = "MiscPressed" }
}

local s_Initialized = false
local s_HoldStart = {}
local s_LastTick = {}
local s_Delay = {}

function Handler.ResetDefaults()
    for key, value in pairs(Handler.Defaults) do Handler[key] = value end
end

local function ReleaseRepeat(action)
    s_HoldStart[action] = 0
    s_Delay[action] = Handler.ScrollDelayBase
end

local function NextDelay(action, now)
    if (s_HoldStart[action] or 0) == 0 then s_HoldStart[action] = now end
    if now - s_HoldStart[action] <= Handler.AccelThreshold then return Handler.ScrollDelayBase end
    return math.max(Handler.ScrollMinDelay, (s_Delay[action] or Handler.ScrollDelayBase) - Handler.AccelStep)
end

local function Ready(action, now, delay)
    return now - (s_LastTick[action] or 0) > delay
end

local function UpdateRepeating(entry, now)
    if not Bindings.IsActionDown(entry.Action) then
        ReleaseRepeat(entry.Action)
        return
    end

    if not Ready(entry.Action, now, s_Delay[entry.Action] or Handler.ScrollDelayBase) then return end
    State[entry.Flag] = true
    s_LastTick[entry.Action] = now
    s_Delay[entry.Action] = NextDelay(entry.Action, now)
end

local function UpdateSingle(action, now, onPressed)
    if not Bindings.IsActionDown(action) or not Ready(action, now, Handler.ScrollDelayBase) then return end
    s_LastTick[action] = now
    onPressed()
end

function Handler.Update()
    local now = os.clock() * 1000
    State.ClearPresses()

    Restrictions.Update()
    Cursor.Update()

    if not s_Initialized then
        State.InitializeTracking()
        s_Initialized = true
    end

    if State.BindingKey then return end

    if OptionConfig.Registry.UpdateHotkeys() then OptionConfig.Save() end

    UpdateSingle("TOGGLE", now, function()
        State.ToggleMenu()
        Logger.Log("Controls: menu toggled " .. tostring(State.MenuOpen))
    end)

    if not State.MenuOpen then
        for _, entry in ipairs(REPEATING_ACTIONS) do ReleaseRepeat(entry.Action) end
        return
    end

    if State.TypingEnabled then
        s_LastTick.SELECT, s_LastTick.BACK = now, now
        return
    end

    for _, entry in ipairs(REPEATING_ACTIONS) do UpdateRepeating(entry, now) end
    for _, entry in ipairs(SINGLE_ACTIONS) do
        UpdateSingle(entry.Action, now, function() State[entry.Flag] = true end)
    end
    UpdateSingle("TOGGLE_MOUSE", now, State.ToggleMouse)
end

return Handler
