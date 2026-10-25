local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Inventory = require("Utils/Inventory")
local Weapons = require("Features/Weapons")
local WeaponItemsMenu = require("View/Weapons/WeaponsItemView")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Notification = require("UI/Panels/Notification/Notification")

local Modifiers = Weapons.StatModifiers

local AMMO_TYPES = {
    { id = "Ammo.HandgunAmmo", label = L("weaponsmenu.ammoitems.types.handgun") },
    { id = "Ammo.ShotgunAmmo", label = L("weaponsmenu.ammoitems.types.shotgun") },
    { id = "Ammo.RifleAmmo", label = L("weaponsmenu.ammoitems.types.rifle") },
    { id = "Ammo.SniperRifleAmmo", label = L("weaponsmenu.ammoitems.types.sniper") },
    { id = "Ammo.Special", label = L("weaponsmenu.ammoitems.types.special") }
}

local s_AddAmounts = {}
local s_RemoveAmounts = {}

for _, ammo in ipairs(AMMO_TYPES) do
    s_AddAmounts[ammo.id] = { step = 10, value = 50, min = 1, max = 999 }
    s_RemoveAmounts[ammo.id] = { step = 10, value = 10, min = 1, max = 999 }
end

local function ForEachAmmo(callback)
    for _, ammo in ipairs(AMMO_TYPES) do callback(ammo) end
end

local function AmmoItemsView()
    Buttons.Option(L("weaponsmenu.ammoitems.giveeach100.label"), tip("weaponsmenu.ammoitems.giveeach100.tip"), function()
        ForEachAmmo(function(ammo) Inventory.GiveItem(ammo.id, 100) end)
    end)
    Buttons.Option(L("weaponsmenu.ammoitems.removeeach25.label"), tip("weaponsmenu.ammoitems.removeeach25.tip"), function()
        ForEachAmmo(function(ammo) Inventory.RemoveItem(ammo.id, 25) end)
    end)

    Buttons.Break(L("weaponsmenu.ammoitems.addammo"))
    ForEachAmmo(function(ammo)
        Buttons.IntClick(ammo.label, s_AddAmounts[ammo.id], tip("weaponsmenu.ammoitems.addtip", { ammo = ammo.label }), function(value)
            Inventory.GiveItem(ammo.id, value)
        end)
    end)

    Buttons.Break(L("weaponsmenu.ammoitems.removeammo"))
    ForEachAmmo(function(ammo)
        Buttons.IntClick(ammo.label, s_RemoveAmounts[ammo.id], tip("weaponsmenu.ammoitems.removetip", { ammo = ammo.label }), function(value)
            Inventory.RemoveItem(ammo.id, value)
        end)
    end)
end

local AmmoItemsMenu = Submenu.Create("weaponsmenu.ammoitems.title", AmmoItemsView)

local Tuning = Weapons.WeaponTuning
local s_TuningPresetName = { value = "", capturing = false }

local function Change(stock, tuned, pattern)
    if not tuned then return "Unknown" end
    if not stock or math.abs(tuned - stock) < 0.01 then return string.format(pattern, tuned) end
    return string.format(pattern .. "  >  " .. pattern, stock, tuned)
end

local function SubmitWeaponStats()
    local stats = Tuning.GetStats()
    if not stats then return end

    local rows = {
        { Label = "Damage", Value = Change(stats.StockDamage, stats.Damage, "%.1f") },
        { Label = "DPS", Value = Change(stats.StockDPS, stats.DPS, "%.0f") },
        { Label = "Crit Chance", Value = Change(stats.StockCritChance, stats.CritChance, "%.0f%%") },
        { Label = "Crit Damage", Value = Change(stats.StockCritDamage, stats.CritDamage, "%.0f%%") }
    }
    if stats.Ranged then
        table.insert(rows, 2, { Label = "Fire Rate", Value = Change(stats.StockFireRate, stats.FireRate, "%.1f/s") })
        table.insert(rows, { Label = "Magazine", Value = Change(stats.StockMagazine, stats.Magazine, "%.0f") })
        table.insert(rows, { Label = "Reload", Value = Change(stats.StockReload, stats.Reload, "%.2f s") })
        table.insert(rows, { Label = "Range", Value = Change(stats.StockRange, stats.Range, "%.0f m") })
    end

    SidePanel.SubmitInfo("weapon-tuning", {
        Eyebrow = Tuning.Enabled.value and "WEAPON  /  TUNED" or "WEAPON  /  STOCK",
        Title = stats.Name,
        Rows = rows,
        Description = "Values on the right of the arrow are the tuned ones."
    }, { Width = 360 })
end

local function TuningPresetsView()
    Buttons.Text("Save Current Tuning", s_TuningPresetName, "Name the current weapon tuning and save it as a preset.", function(value)
        Notification.Success("Saved " .. Tuning.Presets.Save(value), 2)
        s_TuningPresetName.value = ""
    end)

    local presets = Tuning.Presets.List()
    if #presets == 0 then return end

    Buttons.Break("Saved Presets")
    for index, preset in ipairs(presets) do
        Buttons.Option(preset.Name, "Load this weapon tuning preset.", function()
            Notification.Info("Loaded " .. Tuning.Presets.Apply(index), 2)
        end)
    end

    Buttons.Break("Delete")
    for index, preset in ipairs(presets) do
        Buttons.OptionExtended(preset.Name, "", "DELETE", "Remove this weapon tuning preset.", function()
            Notification.Info("Deleted " .. Tuning.Presets.Delete(index), 2)
        end)
    end
end

local TuningPresetsMenu = Submenu.Create("Tuning Presets", TuningPresetsView)

local function TuningView()
    Buttons.Submenu("Tuning Presets", TuningPresetsMenu, "Save and load your own weapon tuning setups.")
    Buttons.Break("")
    Buttons.Toggle("Weapon Tuning", Tuning.Enabled, "Apply the tuning below to the weapon in your hands. Turning it off restores stock stats.")
    Buttons.Option("Reset to Stock", "Set every tuning value back to stock.", Tuning.ResetValues)

    Buttons.Break("Damage")
    Buttons.Int("Damage", Tuning.Damage, "Damage per hit, where 100% is stock.")
    Buttons.Int("Crit Chance Bonus", Tuning.CritChance, "Critical hit chance added on top of the weapon's own.")
    Buttons.Int("Crit Damage Bonus", Tuning.CritDamage, "Critical damage added on top of the weapon's own.")
    Buttons.Int("Headshot Bonus", Tuning.HeadshotBonus, "Extra headshot damage.")

    Buttons.Break("Firing")
    Buttons.Int("Fire Rate", Tuning.FireRate, "Shots per second, where 100% is stock.")
    Buttons.Int("Extra Pellets", Tuning.ExtraPellets, "Projectiles added to every shot.")
    Buttons.Int("Extra Magazine", Tuning.ExtraMagazine, "Rounds added to the magazine.")
    Buttons.Int("Reload Speed", Tuning.ReloadSpeed, "How fast reloads finish, where 100% is stock.")

    Buttons.Break("Accuracy")
    Buttons.Int("Recoil", Tuning.Recoil, "Recoil kick, where 100% is stock and 0% is none.")
    Buttons.Int("Spread", Tuning.Spread, "Bullet spread, where 100% is stock and 0% is a laser.")
    Buttons.Int("Range", Tuning.Range, "Effective and maximum range, where 100% is stock.")

    SubmitWeaponStats()
end

local TuningMenu = Submenu.Create("Weapon Tuning", TuningView)

local BLACKWALL_TIP = "Blackwall powers from the Phantom Liberty ending. Look at an NPC and press B (default hotkey) to fry them with the Blackwall. Works with a gun out, holstered, or mid-fight."

local function ExplosiveBulletsView()
    local Explosive = Weapons.ExplosiveBullets
    Buttons.Toggle(L("weaponsmenu.explosivebullets.label"), Explosive.Enabled, tip("weaponsmenu.explosivebullets.tip"))

    Buttons.Break("Explosion Type")
    Buttons.Radio("Explosion Type", Explosive.Type, Explosive.TypeOptions, "Which explosion each bullet sets off where it lands.")

    Buttons.Break("Settings")
    Buttons.Int("Damage Bonus", Explosive.Damage, "Extra explosion damage on top of the base blast. Also boosts your grenades while on.")
    Buttons.Int("Explosions Per Second", Explosive.Rate, "Cap on how many explosions can go off each second. Lower it for full-auto guns if the game stutters.")
    Buttons.Int("Explosion Chance", Explosive.Chance, "Chance for each shot to explode.")
    Buttons.Toggle("Explode on Enemies", Explosive.OnEnemies, "Explode at the exact spot a bullet hits an NPC.")
    Buttons.Toggle("Explode on Surfaces", Explosive.OnSurfaces, "Explode where a bullet hits walls, floors, and cars.")
end

local ExplosiveBulletsMenu = Submenu.Create("weaponsmenu.explosivebullets.label", ExplosiveBulletsView)

local function ModifierToggle(key, ref)
    Buttons.Toggle(L("weaponsmenu." .. key .. ".label"), ref, tip("weaponsmenu." .. key .. ".tip"))
end

local function WeaponsView()
    Buttons.Submenu(L("weaponsmenu.weaponitems.label"), WeaponItemsMenu, tip("weaponsmenu.weaponitems.tip"))
    Buttons.Submenu(L("weaponsmenu.ammomanager.label"), AmmoItemsMenu, tip("weaponsmenu.ammomanager.tip"))
    Buttons.Submenu("Weapon Tuning", TuningMenu, "Tune damage, fire rate, reload, recoil, and more on the weapon in your hands.")
    Buttons.Submenu(L("weaponsmenu.explosivebullets.label"), ExplosiveBulletsMenu, tip("weaponsmenu.explosivebullets.tip"))
    Buttons.Break("")
    ModifierToggle("infiniteammo", Weapons.InfiniteAmmo.Enabled)
    ModifierToggle("norecoil", Modifiers.NoRecoil.Enabled)
    ModifierToggle("speedcola", Modifiers.FastReload.Enabled)
    ModifierToggle("noreload", Modifiers.NoReloading.Enabled)
    ModifierToggle("rapidfire", Modifiers.RapidFire.Enabled)

    Buttons.Break(L("weaponsmenu.critandspray.label"))
    ModifierToggle("alwayscrit", Modifiers.AlwaysCrit.Enabled)
    ModifierToggle("insanecritdmg", Modifiers.InsaneCritDmg.Enabled)
    ModifierToggle("shotgunspray", Modifiers.ShotgunSpray.Enabled)

    Buttons.Break(L("weaponsmenu.accuracyrange.label"))
    ModifierToggle("unlimitedrange", Modifiers.UnlimitedRange.Enabled)
    ModifierToggle("penetrationrounds", Modifiers.PenetrationRounds.Enabled)
    ModifierToggle("hipfireaccuracy", Modifiers.HipfireAccuracy.Enabled)
    ModifierToggle("adsaccuracy", Modifiers.AdsAccuracy.Enabled)

    Buttons.Break(L("weaponsmenu.specialweapons.label"))
    ModifierToggle("forcegun", Weapons.ForceGun.Enabled)
    ModifierToggle("gravitygun", Weapons.GravityGun.Enabled)
    ModifierToggle("flyingthundergod", Weapons.FlyingThunderGod.Enabled)
    ModifierToggle("smartbladereturn", Weapons.SmartBlade.Enabled)
    ModifierToggle("teleygun", Weapons.TeleportShot.Enabled)
    Buttons.Toggle("Blackwall", Weapons.BlackwallForce.Enabled, BLACKWALL_TIP)
    if Weapons.BlackwallForce.Enabled.value then
        Buttons.Bind("Blackwall Key", Weapons.BlackwallForce.Action, "Blackwalls the NPC you're looking at. Default: B. Also in Settings > Hotkeys.")
    end
    Buttons.Toggle("Dual Wield Anything", Weapons.DualWieldAnything.Enabled, "Lets any gun go in the left hand, no perk needed. Assign it from the inventory like dual pistols. Expect broken animations.")


    Buttons.Break(L("weaponsmenu.melee.label"))
    ModifierToggle("melee_highblock", Modifiers.HighBlock.Enabled)
    ModifierToggle("melee_lowstamina", Modifiers.LowStaminaCost.Enabled)
    ModifierToggle("melee_bladecarnage", Modifiers.BladeCarnage.Enabled)
    ModifierToggle("melee_infinitecombo", Modifiers.InfiniteCombo.Enabled)
    ModifierToggle("explosiveknives", Weapons.ExplosiveKnives.Enabled)

    Buttons.Break(L("weaponsmenu.smartweapons.label"))
    ModifierToggle("smart_fastlock", Modifiers.SmartFastLock.Enabled)
    ModifierToggle("smart_widelock", Modifiers.SmartWideLock.Enabled)
    ModifierToggle("smart_extratargets", Modifiers.SmartExtraTargets.Enabled)
    ModifierToggle("smart_perfectacc", Modifiers.SmartPerfectAcc.Enabled)

    Buttons.Break(L("weaponsmenu.weaponmanagement.label"))
    Buttons.Option(L("weaponsmenu.giveallwallweapons.label"), tip("weaponsmenu.giveallwallweapons.tip"), Weapons.WeaponActions.GiveAllWallWeapons)
    Buttons.Option(L("weaponsmenu.givealliconicweapons.label"), tip("weaponsmenu.givealliconicweapons.tip"), Weapons.WeaponActions.GiveAllIconicWeapons)
    Buttons.Option(L("weaponsmenu.removeallweapons.label"), tip("weaponsmenu.removeallweapons.tip"), function()
        Weapons.WeaponActions.RemoveAllWeapons()
    end)
end

return Submenu.Create("weaponsmenu.title", WeaponsView)
