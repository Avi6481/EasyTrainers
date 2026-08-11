local Logger = require("Core/Logger")
local Event = require("Core/Event")

local FreezeQuestTimer = {}

FreezeQuestTimer.toggleFreezeQuestTimer = { value = false }

function FreezeQuestTimer.HandleCountdownTimer(_, _)
    if not FreezeQuestTimer.toggleFreezeQuestTimer.value then return end

    local timerDef = GetAllBlackboardDefs().UI_HUDCountdownTimer
    local blackboardSystem = Game.GetBlackboardSystem()
    local delaySystem = Game.GetDelaySystem()
    if not (timerDef and blackboardSystem and delaySystem) then return end
    local timerBB = blackboardSystem:Get(timerDef)
    if not timerBB then return end

    local missionTimer = FromVariant(timerBB:GetVariant(timerDef.TimerID))
    if missionTimer then
        delaySystem:CancelTick(missionTimer)
        timerBB:SetFloat(timerDef.Progress, 599.0, true)
    end
end

return FreezeQuestTimer
