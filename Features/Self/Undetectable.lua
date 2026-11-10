local Logger = require("Core/Logger")

local Undetectable = {
    Enabled = false
}

local INTERVAL = 0.5

local s_Applied = false
local s_Next = 0

local function Apply(player, enabled)
    player:SetInvisible(enabled)
    player:UpdateVisibility()
end

function Undetectable.Update(player)
    if Undetectable.Enabled ~= s_Applied then
        Apply(player, Undetectable.Enabled)
        s_Applied = Undetectable.Enabled
        Logger.Log("Undetectable " .. (s_Applied and "on" or "off"))
        return
    end

    if not s_Applied then return end

    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    if not player:IsInvisible() then Apply(player, true) end
end

function Undetectable.Reset()
    s_Applied = false
end

function Undetectable.Shutdown(player)
    if s_Applied and player then Apply(player, false) end
    s_Applied = false
end

return Undetectable
