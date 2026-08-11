local ConfigManager = require("Config/OptionConfig")
local Weapons = require("Features/Weapons")

local function Toggle(id, ref, labelKey, keywords)
    return ConfigManager.DefineToggle(id, ref, false, {
        LabelKey = labelKey,
        Category = "weapon",
        Keywords = keywords,
    })
end

local function RegisterAllWeaponOptions()
    local Modifiers = Weapons.StatModifiers

    ConfigManager.RegisterAll({
        Toggle("toggle.weapon.infiniteammo", Weapons.InfiniteAmmo.enabled, "weaponsmenu.infiniteammo.label", { "ammo", "bullets" }),
        Toggle("toggle.weapon.forcegun", Weapons.ForceGun.enabled, "weaponsmenu.forcegun.label", { "force", "physics" }),
        Toggle("toggle.weapon.flyingthundergod", Weapons.FlyingThunderGod.enabled, "weaponsmenu.flyingthundergod.label", { "teleport", "knife" }),
        Toggle("toggle.weapon.gravitygun", Weapons.GravityGun.enabled, "weaponsmenu.gravitygun.label", { "gravity", "physics" }),
        Toggle("toggle.weapon.smartbladereturn", Weapons.SmartBlade.enabled, "weaponsmenu.smartbladereturn.label", { "knife", "return" }),
        Toggle("toggle.weapon.teleygun", Weapons.TeleportShot.enabled, "weaponsmenu.teleygun.label", { "teleport", "shot" }),
        Toggle("toggle.weapon.explosivebullets", Weapons.ExplosiveBullets.enabled, "weaponsmenu.explosivebullets.label", { "explosion", "ammo" }),
        Toggle("toggle.weapon.explosiveknives", Weapons.ExplosiveKnives.enabled, "weaponsmenu.explosiveknives.label", { "explosion", "knife" }),

        Toggle("toggle.weapon.noreload", Modifiers.NoReloading.toggleNoReloading, "weaponsmenu.noreload.label", { "reload", "magazine" }),
        Toggle("toggle.weapon.speedcola", Modifiers.FastReload.toggleFastReload, "weaponsmenu.speedcola.label", { "reload", "speed" }),
        Toggle("toggle.weapon.norecoil", Modifiers.NoRecoil.toggleNoRecoil, "weaponsmenu.norecoil.label", { "recoil", "accuracy" }),
        Toggle("toggle.weapon.rapidfire", Modifiers.RapidFire.toggleRapidFire, "weaponsmenu.rapidfire.label", { "fire rate", "speed" }),
        Toggle("toggle.weapon.shotgunspray", Modifiers.ShotgunSpray.toggleShotgunSpray, "weaponsmenu.shotgunspray.label", { "shotgun", "pellets" }),
        Toggle("toggle.weapon.alwayscrit", Modifiers.AlwaysCrit.toggleAlwaysCrit, "weaponsmenu.alwayscrit.label", { "critical", "damage" }),
        Toggle("toggle.weapon.insanecritdmg", Modifiers.InsaneCritDmg.toggleInsaneCritDmg, "weaponsmenu.insanecritdmg.label", { "critical", "damage" }),

        Toggle("toggle.weapon.melee_highblock", Modifiers.HighBlock.toggleHighBlock, "weaponsmenu.melee_highblock.label", { "melee", "block" }),
        Toggle("toggle.weapon.melee_lowstamina", Modifiers.LowStaminaCost.toggleLowStaminaCost, "weaponsmenu.melee_lowstamina.label", { "melee", "stamina" }),
        Toggle("toggle.weapon.melee_bladecarnage", Modifiers.BladeCarnage.toggleBladeCarnage, "weaponsmenu.melee_bladecarnage.label", { "melee", "blade", "damage" }),
        Toggle("toggle.weapon.melee_infinitecombo", Modifiers.InfiniteCombo.toggleInfiniteCombo, "weaponsmenu.melee_infinitecombo.label", { "melee", "combo" }),

        Toggle("toggle.weapon.smart_fastlock", Modifiers.SmartFastLock.toggleFastLock, "weaponsmenu.smart_fastlock.label", { "smart", "target", "lock" }),
        Toggle("toggle.weapon.smart_widelock", Modifiers.SmartWideLock.toggleWideLock, "weaponsmenu.smart_widelock.label", { "smart", "target", "angle" }),
        Toggle("toggle.weapon.smart_extratargets", Modifiers.SmartExtraTargets.toggleExtraTargets, "weaponsmenu.smart_extratargets.label", { "smart", "target", "multiple" }),
        Toggle("toggle.weapon.smart_perfectacc", Modifiers.SmartPerfectAcc.togglePerfectAcc, "weaponsmenu.smart_perfectacc.label", { "smart", "accuracy" }),

        Toggle("toggle.weapon.unlimitedrange", Modifiers.UnlimitedRange.toggleUnlimitedRange, "weaponsmenu.unlimitedrange.label", { "range", "distance" }),
        Toggle("toggle.weapon.penetrationrounds", Modifiers.PenetrationRounds.togglePenetrationRounds, "weaponsmenu.penetrationrounds.label", { "wall", "penetration", "ammo" }),
        Toggle("toggle.weapon.hipfireaccuracy", Modifiers.HipfireAccuracy.toggleHipfireAccuracy, "weaponsmenu.hipfireaccuracy.label", { "hip fire", "accuracy" }),
        Toggle("toggle.weapon.adsaccuracy", Modifiers.AdsAccuracy.toggleAdsAccuracy, "weaponsmenu.adsaccuracy.label", { "aim", "sights", "accuracy" }),
    })
end

return RegisterAllWeaponOptions
