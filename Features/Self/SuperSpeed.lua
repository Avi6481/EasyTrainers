local Logger = require("Core/Logger")

local SuperSpeed = {
    Enabled = false,
    Speed = 2
}

local REASON = "EasyTrainerSuperSpeed"
local FOREVER = -1

local s_Applied = false

local function Apply(speed)
    local system = Game.GetTimeSystem()
    if not system then return false end

    if speed then
        system:SetTimeDilationOnLocalPlayerZero(CName.new(REASON), speed, FOREVER)
    else
        system:UnsetTimeDilationOnLocalPlayerZero(CName.new(REASON))
    end
    return true
end

function SuperSpeed.Update()
    local target = SuperSpeed.Enabled and SuperSpeed.Speed or false
    if target == s_Applied then return end
    if not Apply(target) then return end
    s_Applied = target
    Logger.Log("Super Speed " .. (target and (target .. "x") or "off"))
end

function SuperSpeed.Reset()
    s_Applied = false
end

function SuperSpeed.Shutdown()
    if s_Applied then Apply(false) end
    s_Applied = false
end

return SuperSpeed
