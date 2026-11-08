local HeldStats = require("Features/Weapons/HeldStats")
local Weapon = require("Utils/Weapon")

local InfiniteAmmo = {
    Enabled = false
}

local CHECK = 1
local OWNERS = HeldStats.Owners("InfiniteAmmo")

local s_Applied = false
local s_NextCheck = 0

local function LeftStats()
    return { { gamedataStatType.NumShotsToFire, gameStatModifierType.Multiplier, 0 } }
end

local function GameOwns(player)
    if not player then return false end
    local ok, owns = pcall(function() return StatusEffectSystem.ObjectHasStatusEffectWithTag(player, CName.new("InfiniteAmmo")) end)
    return ok and owns == true
end

local function Release(player)
    if not s_Applied then return end
    s_Applied = false
    if GameOwns(player) then return end

    local manager = Game.GetInventoryManager()
    if manager then manager:RemoveEquipmentStateFlag(gameEEquipmentManagerState.InfiniteAmmo) end
end

function InfiniteAmmo.Update(player, now)
    HeldStats.Hand(OWNERS.Left, InfiniteAmmo.Enabled, Weapon.Left, LeftStats, true)
    if not InfiniteAmmo.Enabled then return Release(player) end
    if s_Applied and now < s_NextCheck then return end
    s_NextCheck = now + CHECK

    local manager = Game.GetInventoryManager()
    if not manager then return end
    if not manager:HasEquipmentStateFlag(gameEEquipmentManagerState.InfiniteAmmo) then
        manager:AddEquipmentStateFlag(gameEEquipmentManagerState.InfiniteAmmo)
    end
    s_Applied = true
end

function InfiniteAmmo.Reset()
    pcall(Release, nil)
    s_Applied = false
    s_NextCheck = 0
end

function InfiniteAmmo.Shutdown(player)
    Release(player)
end

return InfiniteAmmo
