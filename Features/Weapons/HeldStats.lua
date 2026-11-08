local StatModifiers = require("Utils/StatModifiers")
local Weapon = require("Utils/Weapon")

local HeldStats = {}

function HeldStats.Owners(name)
    local base = "Weapons." .. name
    return { Right = base .. ".Right", Left = base .. ".Left", Player = base .. ".Player" }
end

function HeldStats.Hand(owner, enabled, hand, build, ranged)
    local on = enabled and hand.StatsID ~= nil and (not ranged or hand.Ranged)
    StatModifiers.Sync(owner, on, hand.Key, hand.StatsID, build)
end

function HeldStats.Weapon(owners, enabled, build, ranged)
    HeldStats.Hand(owners.Right, enabled, Weapon.Right, build, ranged)
    HeldStats.Hand(owners.Left, enabled, Weapon.Left, build, ranged)
end

function HeldStats.Player(owners, enabled, player, build)
    StatModifiers.Sync(owners.Player, enabled, true, player:GetEntityID(), build)
end

return HeldStats
