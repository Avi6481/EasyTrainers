local Weapons = require("Features/Weapons")
local Weapon = require("Utils/Weapon")
local WeaponTick = {}

local modifierEntries = {
    { feature = Weapons.StatModifiers.NoReloading, enabled = Weapons.StatModifiers.NoReloading.toggleNoReloading },
    { feature = Weapons.StatModifiers.FastReload, enabled = Weapons.StatModifiers.FastReload.toggleFastReload },
    { feature = Weapons.StatModifiers.NoRecoil, enabled = Weapons.StatModifiers.NoRecoil.toggleNoRecoil },
    { feature = Weapons.StatModifiers.RapidFire, enabled = Weapons.StatModifiers.RapidFire.toggleRapidFire },
    { feature = Weapons.StatModifiers.ShotgunSpray, enabled = Weapons.StatModifiers.ShotgunSpray.toggleShotgunSpray },
    { feature = Weapons.StatModifiers.AlwaysCrit, enabled = Weapons.StatModifiers.AlwaysCrit.toggleAlwaysCrit },
    { feature = Weapons.StatModifiers.InsaneCritDmg, enabled = Weapons.StatModifiers.InsaneCritDmg.toggleInsaneCritDmg },
    { feature = Weapons.StatModifiers.HighBlock, enabled = Weapons.StatModifiers.HighBlock.toggleHighBlock },
    { feature = Weapons.StatModifiers.LowStaminaCost, enabled = Weapons.StatModifiers.LowStaminaCost.toggleLowStaminaCost },
    { feature = Weapons.StatModifiers.BladeCarnage, enabled = Weapons.StatModifiers.BladeCarnage.toggleBladeCarnage },
    { feature = Weapons.StatModifiers.InfiniteCombo, enabled = Weapons.StatModifiers.InfiniteCombo.toggleInfiniteCombo },
    { feature = Weapons.StatModifiers.SmartFastLock, enabled = Weapons.StatModifiers.SmartFastLock.toggleFastLock },
    { feature = Weapons.StatModifiers.SmartWideLock, enabled = Weapons.StatModifiers.SmartWideLock.toggleWideLock },
    { feature = Weapons.StatModifiers.SmartExtraTargets, enabled = Weapons.StatModifiers.SmartExtraTargets.toggleExtraTargets },
    { feature = Weapons.StatModifiers.SmartPerfectAcc, enabled = Weapons.StatModifiers.SmartPerfectAcc.togglePerfectAcc },
    { feature = Weapons.StatModifiers.UnlimitedRange, enabled = Weapons.StatModifiers.UnlimitedRange.toggleUnlimitedRange },
    { feature = Weapons.StatModifiers.PenetrationRounds, enabled = Weapons.StatModifiers.PenetrationRounds.togglePenetrationRounds },
    { feature = Weapons.StatModifiers.HipfireAccuracy, enabled = Weapons.StatModifiers.HipfireAccuracy.toggleHipfireAccuracy },
    { feature = Weapons.StatModifiers.AdsAccuracy, enabled = Weapons.StatModifiers.AdsAccuracy.toggleAdsAccuracy },
}

local refreshQueue = {}
local refreshIndex = 1

local function QueueEnabledModifierRefreshes()
    refreshQueue = {}
    refreshIndex = 1

    for _, entry in ipairs(modifierEntries) do
        if entry.enabled.value then
            table.insert(refreshQueue, entry.feature)
        end
    end
end

local function TickStatModifiers(deltaTime)
    if Weapon.HasChanged() then
        QueueEnabledModifierRefreshes()
    end

    local queuedModifier = refreshQueue[refreshIndex]
    if queuedModifier then
        -- One modifier family per update prevents all enabled stat changes from
        -- landing in the same game frame during a weapon switch.
        Weapon.MarkChanged()
        queuedModifier.Tick(deltaTime)
        refreshIndex = refreshIndex + 1
        return
    end

    refreshQueue = {}
    refreshIndex = 1
    for _, entry in ipairs(modifierEntries) do
        entry.feature.Tick(deltaTime)
    end
end

function WeaponTick.TickHandler(deltaTime)
    Weapon.Tick(deltaTime)
    Weapons.GravityGun.Tick()
    Weapons.TeleportShot.Tick()
    Weapons.InfiniteAmmo.Tick()
    Weapons.ForceGun.Tick(deltaTime)
    Weapons.ExplosiveBullets.Tick()
    TickStatModifiers(deltaTime)
    Weapon.EndFrame()
end

function WeaponTick.HandleProjectileHit(self, eventData)
    Weapons.FlyingThunderGod.Tick(eventData)
    Weapons.ExplosiveKnives.Tick(eventData)
    Weapons.SmartBlade.Tick(self)
end

return WeaponTick
