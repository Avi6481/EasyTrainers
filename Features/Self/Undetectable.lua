local Logger = require("Core/Logger")

local Undetectable = {
    Enabled = false
}

local s_Applied = false

local function Apply(player, enabled)
    player:SetInvisible(enabled)
    player:UpdateVisibility()
end

function Undetectable.Update(player)
    if Undetectable.Enabled == s_Applied then return end

    Apply(player, Undetectable.Enabled)
    s_Applied = Undetectable.Enabled
    Logger.Log("Undetectable " .. (s_Applied and "on" or "off"))
end

function Undetectable.Reset()
    s_Applied = false
end

function Undetectable.Shutdown(player)
    if s_Applied and player then Apply(player, false) end
    s_Applied = false
end

return Undetectable
