local Police = require("Utils/Police")

local NeverWanted = {
    Enabled = false
}

local OWNER = "NeverWanted"
local INTERVAL = 1

local s_Applied = false
local s_Next = 0

local function Enforce()
    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    Police.Limit(OWNER, 0, 0, true)
    if Police.GetLevel() > 0 then Police.Clear() end
end

function NeverWanted.Update()
    if s_Applied and Police.Owner() ~= OWNER then
        NeverWanted.Enabled = false
        s_Applied = false
    end

    if not NeverWanted.Enabled then
        if s_Applied then
            Police.Release(OWNER)
            s_Applied = false
        end
        return
    end

    if not s_Applied then
        if not Police.Limit(OWNER, 0, 0) then return end
        Police.Clear()
        s_Applied = true
        s_Next = os.clock() + INTERVAL
        return
    end

    Enforce()
end

function NeverWanted.Reset()
    s_Applied = false
end

function NeverWanted.Shutdown()
    if s_Applied then Police.Release(OWNER) end
    s_Applied = false
end

return NeverWanted
