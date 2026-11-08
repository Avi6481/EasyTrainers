local Police = require("Utils/Police")

local WantedLevel = {
    Hold = false,
    Level = 1
}

local OWNER = "WantedLevel"

local s_Held = false
local s_Level = nil

function WantedLevel.Clear()
    WantedLevel.Hold = false
    if s_Held then Police.Release(OWNER) end
    s_Held = false
    Police.Clear()
end

local function UpdateHold()
    if s_Held and Police.Owner() ~= OWNER then
        WantedLevel.Hold = false
        s_Held = false
    end

    local target = WantedLevel.Hold and WantedLevel.Level or false
    if target == s_Held then return end

    if not target then
        Police.Release(OWNER)
        s_Held = false
        return
    end

    if not Police.Limit(OWNER, target, target) then return end
    Police.SetLevel(target)
    s_Held = target
end

function WantedLevel.Update()
    local changed = s_Level ~= nil and WantedLevel.Level ~= s_Level
    if changed and not WantedLevel.Hold then Police.SetLevel(WantedLevel.Level) end
    s_Level = WantedLevel.Level

    UpdateHold()
end

function WantedLevel.Reset()
    s_Held = false
    s_Level = nil
end

function WantedLevel.Shutdown()
    if s_Held then Police.Release(OWNER) end
    s_Held = false
end

return WantedLevel
