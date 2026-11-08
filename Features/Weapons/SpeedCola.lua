local StatModifiers = require("Utils/StatModifiers")
local HeldStats = require("Features/Weapons/HeldStats")
local Weapon = require("Utils/Weapon")

local SpeedCola = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SpeedCola")
local OBJECT_OWNERS = { Right = "Weapons.SpeedCola.RightObject", Left = "Weapons.SpeedCola.LeftObject" }
local PLAYER_BONUS = 0.75

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.ReloadTimeBase, multiply, 0.2 },
        { stat.ReloadEndTime, multiply, 0.1 },
        { stat.EmptyReloadTime, multiply, 0.2 },
        { stat.EmptyReloadEndTime, multiply, 0.1 }
    }
end

local function ObjectStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.ReloadTime, multiply, 0.2 },
        { stat.ReloadEndTime, multiply, 0.1 },
        { stat.EmptyReloadTime, multiply, 0.2 },
        { stat.EmptyReloadEndTime, multiply, 0.1 }
    }
end

local function PlayerStats()
    return { { gamedataStatType.ReloadSpeedPercentBonus, gameStatModifierType.Additive, PLAYER_BONUS } }
end

local function Object(owner, hand)
    local on = SpeedCola.Enabled and hand.Ranged and hand.Item ~= nil
    local id = on and hand.Item:GetEntityID() or nil
    StatModifiers.Sync(owner, on and id ~= nil, hand.Key, id, ObjectStats)
end

function SpeedCola.Update(player)
    HeldStats.Weapon(OWNERS, SpeedCola.Enabled, WeaponStats, true)
    HeldStats.Player(OWNERS, SpeedCola.Enabled, player, PlayerStats)
    Object(OBJECT_OWNERS.Right, Weapon.Right)
    Object(OBJECT_OWNERS.Left, Weapon.Left)
end

return SpeedCola
