local Logger = require("Core/Logger")

local Invisibility = {
    Enabled = false
}

local EFFECT = "BaseStatusEffect.OpticalCamoPlayerBuffLegendary"
local HOLD_TIME = 3
local REFRESH_INTERVAL = 0.25

local s_Effect = nil
local s_Applied = false
local s_Cleanup = false
local s_NextRefresh = 0

local function EffectID()
    s_Effect = s_Effect or TweakDBID.new(EFFECT)
    return s_Effect
end

local function Apply(player)
    local system = Game.GetStatusEffectSystem()
    if not system then return end

    local id = player:GetEntityID()
    if system:HasStatusEffect(id, EffectID()) then
        system:SetStatusEffectRemainingDuration(id, EffectID(), HOLD_TIME)
        return
    end
    system:ApplyStatusEffect(id, EffectID(), player:GetRecordID(), id, 1, Vector4.new(0, 0, 0, 0), false)
end

local function Remove(player)
    local system = Game.GetStatusEffectSystem()
    if not system or not player then return end

    local id = player:GetEntityID()
    if system:HasStatusEffect(id, EffectID()) then system:RemoveStatusEffect(id, EffectID()) end
end

function Invisibility.Update(player)
    if not Invisibility.Enabled then
        if s_Applied or s_Cleanup then
            Remove(player)
            s_Applied = false
            s_Cleanup = false
            Logger.Log("Invisibility off")
        end
        return
    end

    local now = os.clock()
    if s_Applied and now < s_NextRefresh then return end
    s_NextRefresh = now + REFRESH_INTERVAL

    Apply(player)
    if not s_Applied then Logger.Log("Invisibility on") end
    s_Applied = true
    s_Cleanup = false
end

function Invisibility.Reset()
    s_Cleanup = s_Cleanup or s_Applied
    s_Applied = false
    s_NextRefresh = 0
end

function Invisibility.Shutdown(player)
    if s_Applied or s_Cleanup then Remove(player) end
    s_Applied = false
    s_Cleanup = false
end

return Invisibility
