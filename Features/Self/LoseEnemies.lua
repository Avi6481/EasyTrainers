local Notify = require("Utils/Notify")

local LoseEnemies = {}

local MEMORY_WIPE = "BaseStatusEffect.MemoryWipeExitCombat"

local s_Pending = false

function LoseEnemies.Request()
    s_Pending = true
end

local function Run(player)
    local tracker = player:GetTargetTrackerComponent()
    local effects = Game.GetStatusEffectSystem()
    if not tracker or not effects then return 0 end

    local wipe = TweakDBID.new(MEMORY_WIPE)
    local count = 0
    for _, threat in ipairs(tracker:GetHostileThreats(false)) do
        local enemy = threat.entity
        if enemy and effects:ApplyStatusEffect(enemy:GetEntityID(), wipe) then count = count + 1 end
    end
    return count
end

function LoseEnemies.Update(player)
    if not s_Pending then return end
    s_Pending = false

    local count = Run(player)
    if count > 0 then
        Notify.Success(tip("notify.self.lost", { count = count }))
    else
        Notify.Info(L("notify.self.noenemies"))
    end
end

function LoseEnemies.Reset()
    s_Pending = false
end

return LoseEnemies
