local Weapons = require("Features/Weapons")
local Weapon = require("Utils/Weapon")
local AimHelpers = require("Features/Weapons/Abilities/AimHelpers")

local WeaponTick = {}

function WeaponTick.TickHandler()
    Weapons.GravityGun.Tick()
    Weapons.TeleportShot.Tick()
    Weapons.InfiniteAmmo.Tick()
    Weapons.ForceGun.Tick()
    Weapons.ExplosiveBullets.Tick()
    Weapons.BlackwallForce.Tick()

    local modifiersActive = Weapons.StatModifiers.IsActive()
    local tuningActive = Weapons.WeaponTuning.IsActive()
    if not modifiersActive and not tuningActive then return end

    Weapon.Tick()
    if modifiersActive then Weapons.StatModifiers.Tick() end
    if tuningActive then Weapons.WeaponTuning.Tick() end
end

function WeaponTick.HandleShot()
    Weapons.ExplosiveBullets.OnShot()
end

function WeaponTick.HandleHit(hitEvent)
    Weapons.ExplosiveBullets.OnHit(hitEvent)
end

function WeaponTick.HandleProjectileHit(projectile, eventData)
    if not AimHelpers.IsFromPlayer(projectile) then return end
    Weapons.FlyingThunderGod.OnProjectileHit(eventData)
    Weapons.ExplosiveKnives.OnProjectileHit(eventData)
    Weapons.SmartBlade.OnProjectileHit(projectile)
end

return WeaponTick
