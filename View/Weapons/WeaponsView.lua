local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Weapons = require("Features/Weapons/Weapons")
local WeaponSettingsView = require("View/Weapons/WeaponSettingsView")
local WeaponItemsView = require("View/Weapons/WeaponItemsView")
local AmmoView = require("View/Weapons/AmmoView")
local TuningView = require("View/Weapons/TuningView")
local ExplosiveBulletsView = require("View/Weapons/ExplosiveBulletsView")

local WeaponsView = {}

local KEY = "weapons."

local s_Refs = {}

local function Enabled(name)
    local ref = s_Refs[name]
    if not ref then
        ref = Ref.Field(Weapons[name], "Enabled")
        s_Refs[name] = ref
    end
    return ref
end

local function Link(key, menu)
    Widgets.SubmenuButton(L(KEY .. key .. ".label"), menu)
    Widgets.Tip(L(KEY .. key .. ".tip"))
end

local function Toggle(key, name)
    Widgets.Toggle(L(KEY .. key .. ".label"), Enabled(name))
    Widgets.Tip(L(KEY .. key .. ".tip"))
end

local function Manage(key, action, hold)
    local label = L(KEY .. key .. ".label")
    local pressed
    if hold then
        pressed = Widgets.HoldButton(label)
    else
        pressed = Widgets.Button(label)
    end
    Widgets.Tip(L(KEY .. key .. ".tip"))
    if pressed then Weapons.Run(action) end
end

local function Links()
    Link("settings", WeaponSettingsView.Menu)
    Link("weaponitems", WeaponItemsView.Menu)
    Link("ammo", AmmoView.Menu)
    Widgets.SubmenuButton(L("weapons.tuning.label"), TuningView.Menu)
    Widgets.Tip(L("weapons.tuning.tip"))
    Link("explosivebullets", ExplosiveBulletsView.Menu)
end

local function Ammo()
    Toggle("infiniteammo", "InfiniteAmmo")
    Toggle("bottomlessmagazine", "BottomlessMagazine")
    Toggle("speedcola", "SpeedCola")
    Toggle("rapidfire", "RapidFire")
    Toggle("norecoil", "NoRecoil")
end

local function Damage()
    Widgets.Break(L(KEY .. "damage"))
    Toggle("onehitkills", "OneHitKills")
    Toggle("alwayscrit", "AlwaysCrit")
    Toggle("insanecritdamage", "InsaneCritDamage")
    Toggle("shotgunspray", "ShotgunSpray")
end

local function Accuracy()
    Widgets.Break(L(KEY .. "accuracy"))
    Toggle("higherrange", "HigherRange")
    Toggle("penetrationrounds", "PenetrationRounds")
    Toggle("hipfireaccuracy", "HipfireAccuracy")
    Toggle("adsaccuracy", "AdsAccuracy")
end

local function Special()
    Widgets.Break(L(KEY .. "special"))
    Toggle("forcegun", "ForceGun")
    Toggle("gravitygun", "GravityGun")
    Toggle("flyingthundergod", "FlyingThunderGod")
    Toggle("smartblade", "SmartBlade")
    Toggle("teleportgun", "TeleportGun")
    Toggle("blackwall", "Blackwall")
    Toggle("dualwield", "DualWield")
end

local function Melee()
    Widgets.Break(L(KEY .. "melee"))
    Toggle("highblock", "HighBlock")
    Toggle("lowstaminacost", "LowStaminaCost")
    Toggle("bladecarnage", "BladeCarnage")
    Toggle("infinitecombo", "InfiniteCombo")
    Toggle("explosiveknives", "ExplosiveKnives")
end

local function Smart()
    Widgets.Break(L(KEY .. "smart"))
    Toggle("smartfastlock", "SmartFastLock")
    Toggle("smartwidelock", "SmartWideLock")
    Toggle("smartextratargets", "SmartExtraTargets")
    Toggle("smartperfectaccuracy", "SmartPerfectAccuracy")
    Toggle("smartfastprojectiles", "SmartFastProjectiles")
    Toggle("smartlongrange", "SmartLongRange")
end

local function Management()
    local manage = Weapons.Management
    Widgets.Break(L(KEY .. "management"))
    Manage("raygun", manage.GiveRaygun)
    for _, special in ipairs(manage.Specials) do
        local pressed = Widgets.Button(tip(KEY .. "special.label", { name = manage.SpecialName(special) }))
        Widgets.Tip(L(KEY .. "special." .. special.Key))
        if pressed then Weapons.Run(manage.GiveSpecial(special)) end
    end
    Manage("givewall", manage.GiveWall)
    Manage("giveiconic", manage.GiveIconic)
    Manage("removeall", manage.RemoveAll, true)
end

local function View()
    Weapons.Watch()

    Links()
    Widgets.Break("")
    Ammo()
    Damage()
    Accuracy()
    Special()
    Melee()
    Smart()
    Management()
end

WeaponsView.Menu = Submenu.Create("weapons.title", View)

return WeaponsView
