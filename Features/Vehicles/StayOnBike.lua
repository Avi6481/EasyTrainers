local StayOnBike = {
    Enabled = false
}

local function KnockOff(_, stateContext, scriptInterface, wrapped)
    local knocked = wrapped(stateContext, scriptInterface)
    if knocked and StayOnBike.Enabled then return false end
    return knocked
end

function StayOnBike.Initialize()
    Override("CollisionExitingDecisions", "EnterCondition", KnockOff)
end

return StayOnBike
