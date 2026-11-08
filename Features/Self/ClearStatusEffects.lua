local Notify = require("Utils/Notify")

local ClearStatusEffects = {}

local AILMENTS = {
    "Bleeding", "Blind", "Burning", "Crippled", "Deafened", "EMP", "Electrocuted",
    "Exhausted", "Overheat", "Pain", "Poisoned", "Stunned", "Wounded"
}

local s_Pending = false

function ClearStatusEffects.Request()
    s_Pending = true
end

local function Run(player)
    local effects = Game.GetStatusEffectSystem()
    if not effects then return 0 end

    local entityID = player:GetEntityID()
    local count = 0
    for _, ailment in ipairs(AILMENTS) do
        if effects:RemoveAllStatusEffectOfType(entityID, gamedataStatusEffectType[ailment]) then count = count + 1 end
    end
    return count
end

function ClearStatusEffects.Update(player)
    if not s_Pending then return end
    s_Pending = false

    local count = Run(player)
    if count > 0 then
        Notify.Success(tip("notify.self.cleared", { count = count }))
    else
        Notify.Info(L("notify.self.nothingtoclear"))
    end
end

function ClearStatusEffects.Reset()
    s_Pending = false
end

return ClearStatusEffects
