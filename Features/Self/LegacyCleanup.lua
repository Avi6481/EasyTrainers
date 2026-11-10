local Logger = require("Core/Logger")

local LegacyCleanup = {}

local LEGACY_TAG = "EasyTrainer.StatusEffect"
local DELAY = 3

local s_Tag = nil
local s_Done = false
local s_StartAt = nil

local function SameID(first, second)
    if not first or not second then return false end
    local ok, same = pcall(function() return first.hash == second.hash and first.length == second.length end)
    return ok and same
end

local function Clean(player)
    local system = Game.GetStatusEffectSystem()
    if not system then return 0 end

    s_Tag = s_Tag or TweakDBID.new(LEGACY_TAG)
    local id = player:GetEntityID()
    local removed = 0
    for _, effect in ipairs(StatusEffectHelper.GetAppliedEffects(player) or {}) do
        if SameID(effect:GetInstigatorStaticDataID(), s_Tag) then
            local record = effect:GetRecord()
            if record then
                system:RemoveStatusEffect(id, record:GetID(), 0)
                removed = removed + 1
                Logger.Log("LegacyCleanup: removed " .. tostring(record:GetID()) .. " left in the save by EasyTrainer 2.3")
            end
        end
    end
    return removed
end

function LegacyCleanup.Update(player)
    if s_Done then return end

    local now = os.clock()
    if not s_StartAt then s_StartAt = now + DELAY end
    if now < s_StartAt then return end

    s_Done = true
    local removed = Clean(player)
    if removed > 0 then Logger.Log(string.format("LegacyCleanup: cleared %d old status effects", removed)) end
end

function LegacyCleanup.Reset()
    s_Done = false
    s_StartAt = nil
end

return LegacyCleanup
