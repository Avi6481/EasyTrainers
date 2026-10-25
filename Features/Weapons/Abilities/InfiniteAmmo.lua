local StatusEffect = require("Utils/StatusEffect")
local StatModifiers = require("Utils/StatModifiers")
local Weapon = require("Utils/Weapon")
local Lifecycle = require("Core/Lifecycle")

local InfiniteAmmo = {}

InfiniteAmmo.Enabled = { value = false }

local EFFECT = "GameplayRestriction.InfiniteAmmo"
local OWNER = "InfiniteAmmo"
local CHECK_INTERVAL = 1.0
local LEFT_OWNER = { Name = "InfiniteAmmo.Left" }
local LEFT_MODIFIERS = { { gamedataStatType.NumShotsToFire, gameStatModifierType.Multiplier, 0 } }

local s_Applied = false
local s_NextCheck = 0

local function SyncLeft(enabled)
    local itemKey = enabled and Weapon.IsLeftRangedEquipped() and Weapon.GetLeftItemKey() or nil
    if not itemKey then
        StatModifiers.Sync(LEFT_OWNER, false)
        return
    end
    if StatModifiers.GetKey(LEFT_OWNER) == itemKey then return end

    local _, itemData = Weapon.GetEquippedLeftHand()
    local statsID = itemData and itemData:GetStatsObjectID() or nil
    if statsID then StatModifiers.Add(LEFT_OWNER, statsID, itemKey, LEFT_MODIFIERS) end
end

function InfiniteAmmo.Tick()
    SyncLeft(InfiniteAmmo.Enabled.value)

    if not InfiniteAmmo.Enabled.value then
        if s_Applied then
            StatusEffect.Set(EFFECT, false, OWNER)
            s_Applied = false
        end
        return
    end

    local now = os.clock()
    if s_Applied and now < s_NextCheck then return end
    s_NextCheck = now + CHECK_INTERVAL

    StatusEffect.Reapply(EFFECT, OWNER)
    s_Applied = true
end

Lifecycle.Register("InfiniteAmmo", {
    OnSessionEnd = function() s_Applied = false end
})

return InfiniteAmmo
