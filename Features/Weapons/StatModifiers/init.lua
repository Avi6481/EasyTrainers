local StatModifiers = require("Utils/StatModifiers")
local Weapon = require("Utils/Weapon")

local WeaponModifiers = {}

local ADD = gameStatModifierType.Additive
local MULTIPLY = gameStatModifierType.Multiplier

local KIND = {
    Any = "Any",
    Ranged = "Ranged",
    Melee = "Melee"
}

local function Define(name, kind, modifiers)
    local definition = { Name = "Weapon." .. name, Kind = kind, Modifiers = modifiers, Enabled = { value = false } }
    definition.Left = { Name = definition.Name .. ".Left" }
    WeaponModifiers[name] = definition
    return definition
end

WeaponModifiers.Definitions = {
    Define("NoReloading", KIND.Ranged, { { gamedataStatType.NumShotsToFire, MULTIPLY, 0 } }),
    Define("FastReload", KIND.Ranged, {
        { gamedataStatType.ReloadTimeBase, MULTIPLY, 0.2 },
        { gamedataStatType.ReloadEndTime, MULTIPLY, 0.1 },
        { gamedataStatType.EmptyReloadTime, MULTIPLY, 0.2 },
        { gamedataStatType.EmptyReloadEndTime, MULTIPLY, 0.1 }
    }),
    Define("NoRecoil", KIND.Ranged, {
        { gamedataStatType.RecoilKickMin, MULTIPLY, 0 },
        { gamedataStatType.RecoilKickMax, MULTIPLY, 0 },
        { gamedataStatType.RecoilUseDifferentStatsInADS, MULTIPLY, 0 }
    }),
    Define("RapidFire", KIND.Ranged, { { gamedataStatType.CycleTime, MULTIPLY, 0.1 } }),
    Define("ShotgunSpray", KIND.Ranged, { { gamedataStatType.ProjectilesPerShot, ADD, 15 } }),
    Define("AlwaysCrit", KIND.Any, { { gamedataStatType.CritChance, ADD, 100 } }),
    Define("InsaneCritDmg", KIND.Any, { { gamedataStatType.CritDamage, ADD, 100000 } }),
    Define("HighBlock", KIND.Melee, { { gamedataStatType.BlockFactor, MULTIPLY, 100 } }),
    Define("LowStaminaCost", KIND.Melee, { { gamedataStatType.StaminaCostReduction, ADD, -2 } }),
    Define("BladeCarnage", KIND.Melee, { { gamedataStatType.HitDismembermentFactor, ADD, 10000 } }),
    Define("InfiniteCombo", KIND.Melee, { { gamedataStatType.CanMeleeInfinitelyCombo, ADD, 1 } }),
    Define("SmartFastLock", KIND.Ranged, {
        { gamedataStatType.SmartGunAdsTimeToLock, MULTIPLY, 0.1 },
        { gamedataStatType.SmartGunHipTimeToLock, MULTIPLY, 0.05 }
    }),
    Define("SmartWideLock", KIND.Ranged, {
        { gamedataStatType.SmartGunAdsLockingAnglePitch, ADD, 1 },
        { gamedataStatType.SmartGunAdsLockingAngleYaw, ADD, 1 },
        { gamedataStatType.SmartGunAdsTargetableAnglePitch, ADD, 1 },
        { gamedataStatType.SmartGunAdsTargetableAngleYaw, ADD, 1 },
        { gamedataStatType.SmartGunHipLockingAnglePitch, ADD, 1 },
        { gamedataStatType.SmartGunHipLockingAngleYaw, ADD, 1 },
        { gamedataStatType.SmartGunHipTargetableAnglePitch, ADD, 1 },
        { gamedataStatType.SmartGunHipTargetableAngleYaw, ADD, 1 }
    }),
    Define("SmartExtraTargets", KIND.Ranged, {
        { gamedataStatType.SmartGunMaxLockedPointsPerTarget, ADD, 2 },
        { gamedataStatType.SmartGunAdsMaxLockedTargets, ADD, 15 },
        { gamedataStatType.SmartGunHipMaxLockedTargets, ADD, 15 }
    }),
    Define("SmartPerfectAcc", KIND.Ranged, {
        { gamedataStatType.SmartGunHitProbability, ADD, 1 },
        { gamedataStatType.SmartGunStartingAccuracy, ADD, 1 },
        { gamedataStatType.SmartGunMissDelay, MULTIPLY, 0 },
        { gamedataStatType.SmartGunMissRadius, MULTIPLY, 0 }
    }),
    Define("UnlimitedRange", KIND.Ranged, {
        { gamedataStatType.EffectiveRange, MULTIPLY, 200 },
        { gamedataStatType.MaximumRange, MULTIPLY, 200 }
    }),
    Define("PenetrationRounds", KIND.Ranged, {
        { gamedataStatType.TechPierceEnabled, ADD, 1 },
        { gamedataStatType.CanWeaponIgnoreArmor, ADD, 1 }
    }),
    Define("HipfireAccuracy", KIND.Ranged, {
        { gamedataStatType.SpreadMinX, MULTIPLY, 0.05 },
        { gamedataStatType.SpreadMinY, MULTIPLY, 0.05 },
        { gamedataStatType.SpreadMaxX, MULTIPLY, 0.05 },
        { gamedataStatType.SpreadMaxY, MULTIPLY, 0.05 }
    }),
    Define("AdsAccuracy", KIND.Ranged, {
        { gamedataStatType.SpreadAdsMinX, MULTIPLY, 0.05 },
        { gamedataStatType.SpreadAdsMinY, MULTIPLY, 0.05 },
        { gamedataStatType.SpreadAdsMaxX, MULTIPLY, 0.05 },
        { gamedataStatType.SpreadAdsMaxY, MULTIPLY, 0.05 }
    })
}

local function Matches(kind)
    if kind == KIND.Ranged then return Weapon.IsRangedEquipped() end
    if kind == KIND.Melee then return Weapon.IsMeleeEquipped() end
    return true
end

local function DesiredKey(definition, itemKey)
    if not definition.Enabled.value or not itemKey or not Matches(definition.Kind) then return nil end
    return itemKey
end

local function DesiredLeftKey(definition, itemKey)
    if not definition.Enabled.value or not itemKey or definition.Kind == KIND.Melee then return nil end
    if not Weapon.IsLeftRangedEquipped() then return nil end
    return itemKey
end

local function SyncHand(owner, desired, getItem, modifiers)
    if desired == StatModifiers.GetKey(owner) then return false end

    if desired then
        local _, itemData = getItem()
        local statsID = itemData and itemData:GetStatsObjectID() or nil
        if statsID then StatModifiers.Add(owner, statsID, desired, modifiers) end
    else
        StatModifiers.Remove(owner)
    end
    return true
end

local function BuildModifiers(definition)
    return definition.Modifiers
end

function WeaponModifiers.IsActive()
    for _, definition in ipairs(WeaponModifiers.Definitions) do
        if definition.Enabled.value or StatModifiers.IsApplied(definition) or StatModifiers.IsApplied(definition.Left) then return true end
    end
    return false
end

function WeaponModifiers.Tick()
    local itemKey = Weapon.GetCurrentItemKey()
    local leftKey = Weapon.GetLeftItemKey()

    for _, definition in ipairs(WeaponModifiers.Definitions) do
        if SyncHand(definition, DesiredKey(definition, itemKey), Weapon.GetEquippedRightHand, BuildModifiers(definition)) then return end
        if SyncHand(definition.Left, DesiredLeftKey(definition, leftKey), Weapon.GetEquippedLeftHand, BuildModifiers(definition)) then return end
    end
end

return WeaponModifiers
