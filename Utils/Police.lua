local Logger = require("Core/Logger")

local Police = {}

local SOURCE = "EasyTrainer"
local MAX_LEVEL = 5

local s_Owner = nil

local function System()
    local container = Game.GetScriptableSystemsContainer()
    return container and container:Get("PreventionSystem") or nil
end

local function Instruction(instruction, level)
    local system = System()
    if not system then return false end

    local request = PreventionConsoleInstructionRequest.new()
    request.instruction = instruction
    if level then request.heatStage = EPreventionHeatStage["Heat_" .. level] end
    system:QueueRequest(request)
    return true
end

local function Limiter(min, max, reset)
    local system = System()
    if not system then return false end

    local request = SetHeatLevelLimiter.new()
    request.m_HeatLevelMin = min
    request.m_HeatLevelMax = max
    request.m_HeatLevelReset = reset
    request.source = CName.new(SOURCE)
    system:QueueRequest(request)
    return true
end

function Police.GetLevel()
    local system = System()
    return system and system:GetHeatStageAsInt() or 0
end

function Police.Clear()
    Logger.Log("Police: clearing wanted level")
    return Instruction(EPreventionSystemInstruction.Safe)
end

function Police.SetLevel(level)
    level = math.max(0, math.min(MAX_LEVEL, math.floor(level)))
    if level == 0 then return Police.Clear() end
    Logger.Log("Police: wanted level " .. level)
    return Instruction(EPreventionSystemInstruction.Active, level)
end

function Police.Limit(owner, min, max, quiet)
    if not Limiter(min, max, false) then return false end
    s_Owner = owner
    if not quiet then Logger.Log(string.format("Police: heat held between %d and %d for %s", min, max, owner)) end
    return true
end

function Police.Release(owner)
    if s_Owner ~= owner then return false end
    s_Owner = nil
    Logger.Log("Police: heat limit released by " .. owner)
    return Limiter(0, MAX_LEVEL, true)
end

function Police.Owner()
    return s_Owner
end

function Police.Forget()
    s_Owner = nil
end

return Police
