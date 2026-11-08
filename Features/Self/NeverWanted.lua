local Police = require("Utils/Police")

local NeverWanted = {
    Enabled = false
}

local OWNER = "NeverWanted"

local s_Applied = false

function NeverWanted.Update()
    if s_Applied and Police.Owner() ~= OWNER then
        NeverWanted.Enabled = false
        s_Applied = false
    end

    if NeverWanted.Enabled == s_Applied then return end

    if not NeverWanted.Enabled then
        Police.Release(OWNER)
        s_Applied = false
        return
    end

    if not Police.Limit(OWNER, 0, 0) then return end
    Police.Clear()
    s_Applied = true
end

function NeverWanted.Reset()
    s_Applied = false
end

function NeverWanted.Shutdown()
    if s_Applied then Police.Release(OWNER) end
    s_Applied = false
end

return NeverWanted
