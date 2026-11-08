local Landing = {}

local SAFE_SPEED = -100000
local LIMITS = { "HardLandingFallingSpeed", "VeryHardLandingFallingSpeed", "DeathLandingFallingSpeed" }

local s_Holds = {}
local s_Limits = nil

local function Lift(stateContext)
    if next(s_Holds) == nil then return end
    for _, limit in ipairs(s_Limits) do stateContext:SetPermanentFloatParameter(limit, SAFE_SPEED, true) end
end

function Landing.Initialize()
    if s_Limits then return end

    s_Limits = {}
    for _, name in ipairs(LIMITS) do table.insert(s_Limits, CName.new(name)) end
    ObserveBefore("LocomotionAirEvents", "OnUpdate", function(_, _, stateContext) Lift(stateContext) end)
end

function Landing.Hold(owner, active)
    s_Holds[owner] = active and true or nil
end

return Landing
