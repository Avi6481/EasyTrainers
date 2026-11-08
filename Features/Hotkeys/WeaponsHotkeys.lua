local Define = require("Features/Hotkeys/Define")
local Weapons = require("Features/Weapons/Weapons")

local Toggle, Action = Define.Toggle, Define.Action

local function Restock()
    Weapons.Run(Weapons.Ammo.Restock)
end

local function Manage(action)
    return function() Weapons.Run(Weapons.Management[action]) end
end

local WeaponsHotkeys = {
    Toggle("ExplosiveBullets", "weapons.explosivebullets", Weapons.ExplosiveBullets),
    Toggle("Tuning", "weapons.tuning.enabled", Weapons.Tuning),
    Action("Restock", "weapons.ammo.giveeach", Restock, { Silent = true }),
    Action("Raygun", "weapons.raygun", Manage("GiveRaygun"), { Silent = true }),
    Action("GiveWall", "weapons.givewall", Manage("GiveWall"), { Silent = true }),
    Action("GiveIconic", "weapons.giveiconic", Manage("GiveIconic"), { Silent = true }),

    Toggle("InfiniteAmmo", "weapons.infiniteammo", Weapons.InfiniteAmmo, nil, { Break = "weapons.ammo.label" }),
    Toggle("BottomlessMagazine", "weapons.bottomlessmagazine", Weapons.BottomlessMagazine),
    Toggle("SpeedCola", "weapons.speedcola", Weapons.SpeedCola),
    Toggle("RapidFire", "weapons.rapidfire", Weapons.RapidFire),
    Toggle("NoRecoil", "weapons.norecoil", Weapons.NoRecoil),

    Toggle("OneHitKills", "weapons.onehitkills", Weapons.OneHitKills, nil, { Break = "weapons.damage" }),
    Toggle("AlwaysCrit", "weapons.alwayscrit", Weapons.AlwaysCrit),
    Toggle("InsaneCritDamage", "weapons.insanecritdamage", Weapons.InsaneCritDamage),
    Toggle("ShotgunSpray", "weapons.shotgunspray", Weapons.ShotgunSpray),

    Toggle("HigherRange", "weapons.higherrange", Weapons.HigherRange, nil, { Break = "weapons.accuracy" }),
    Toggle("PenetrationRounds", "weapons.penetrationrounds", Weapons.PenetrationRounds),
    Toggle("HipfireAccuracy", "weapons.hipfireaccuracy", Weapons.HipfireAccuracy),
    Toggle("AdsAccuracy", "weapons.adsaccuracy", Weapons.AdsAccuracy),

    Toggle("ForceGun", "weapons.forcegun", Weapons.ForceGun, nil, { Break = "weapons.special" }),
    Toggle("GravityGun", "weapons.gravitygun", Weapons.GravityGun),
    Toggle("FlyingThunderGod", "weapons.flyingthundergod", Weapons.FlyingThunderGod),
    Toggle("SmartBlade", "weapons.smartblade", Weapons.SmartBlade),
    Toggle("TeleportGun", "weapons.teleportgun", Weapons.TeleportGun),
    Toggle("Blackwall", "weapons.blackwall", Weapons.Blackwall),
    Toggle("DualWield", "weapons.dualwield", Weapons.DualWield),

    Toggle("HighBlock", "weapons.highblock", Weapons.HighBlock, nil, { Break = "weapons.melee" }),
    Toggle("LowStaminaCost", "weapons.lowstaminacost", Weapons.LowStaminaCost),
    Toggle("BladeCarnage", "weapons.bladecarnage", Weapons.BladeCarnage),
    Toggle("InfiniteCombo", "weapons.infinitecombo", Weapons.InfiniteCombo),
    Toggle("ExplosiveKnives", "weapons.explosiveknives", Weapons.ExplosiveKnives),

    Toggle("SmartFastLock", "weapons.smartfastlock", Weapons.SmartFastLock, nil, { Break = "weapons.smart" }),
    Toggle("SmartWideLock", "weapons.smartwidelock", Weapons.SmartWideLock),
    Toggle("SmartExtraTargets", "weapons.smartextratargets", Weapons.SmartExtraTargets),
    Toggle("SmartPerfectAccuracy", "weapons.smartperfectaccuracy", Weapons.SmartPerfectAccuracy),
    Toggle("SmartFastProjectiles", "weapons.smartfastprojectiles", Weapons.SmartFastProjectiles),
    Toggle("SmartLongRange", "weapons.smartlongrange", Weapons.SmartLongRange)
}

return WeaponsHotkeys
