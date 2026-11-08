local Logger = require("Core/Logger")
local StatModifiers = require("Utils/StatModifiers")
local Weapon = require("Utils/Weapon")
local Catalog = require("Features/Weapons/Catalog")
local Arsenal = require("Features/Weapons/Arsenal")

local Weapons = {}

Weapons.Controls = require("Features/Weapons/Controls")
Weapons.Ammo = require("Features/Weapons/Ammo")
Weapons.Management = require("Features/Weapons/Management")
Weapons.InfiniteAmmo = require("Features/Weapons/InfiniteAmmo")
Weapons.BottomlessMagazine = require("Features/Weapons/BottomlessMagazine")
Weapons.SpeedCola = require("Features/Weapons/SpeedCola")
Weapons.RapidFire = require("Features/Weapons/RapidFire")
Weapons.NoRecoil = require("Features/Weapons/NoRecoil")
Weapons.OneHitKills = require("Features/Weapons/OneHitKills")
Weapons.AlwaysCrit = require("Features/Weapons/AlwaysCrit")
Weapons.InsaneCritDamage = require("Features/Weapons/InsaneCritDamage")
Weapons.ShotgunSpray = require("Features/Weapons/ShotgunSpray")
Weapons.HigherRange = require("Features/Weapons/HigherRange")
Weapons.PenetrationRounds = require("Features/Weapons/PenetrationRounds")
Weapons.HipfireAccuracy = require("Features/Weapons/HipfireAccuracy")
Weapons.AdsAccuracy = require("Features/Weapons/AdsAccuracy")
Weapons.ForceGun = require("Features/Weapons/ForceGun")
Weapons.GravityGun = require("Features/Weapons/GravityGun")
Weapons.FlyingThunderGod = require("Features/Weapons/FlyingThunderGod")
Weapons.SmartBlade = require("Features/Weapons/SmartBlade")
Weapons.TeleportGun = require("Features/Weapons/TeleportGun")
Weapons.Blackwall = require("Features/Weapons/Blackwall")
Weapons.DualWield = require("Features/Weapons/DualWield")
Weapons.HighBlock = require("Features/Weapons/HighBlock")
Weapons.LowStaminaCost = require("Features/Weapons/LowStaminaCost")
Weapons.BladeCarnage = require("Features/Weapons/BladeCarnage")
Weapons.InfiniteCombo = require("Features/Weapons/InfiniteCombo")
Weapons.ExplosiveKnives = require("Features/Weapons/ExplosiveKnives")
Weapons.SmartFastLock = require("Features/Weapons/SmartFastLock")
Weapons.SmartWideLock = require("Features/Weapons/SmartWideLock")
Weapons.SmartExtraTargets = require("Features/Weapons/SmartExtraTargets")
Weapons.SmartPerfectAccuracy = require("Features/Weapons/SmartPerfectAccuracy")
Weapons.SmartFastProjectiles = require("Features/Weapons/SmartFastProjectiles")
Weapons.SmartLongRange = require("Features/Weapons/SmartLongRange")
Weapons.ExplosiveBullets = require("Features/Weapons/ExplosiveBullets")
Weapons.Tuning = require("Features/Weapons/Tuning")

local ENABLED = { "Enabled" }

local FEATURES = {
    { "InfiniteAmmo", Weapons.InfiniteAmmo, ENABLED },
    { "BottomlessMagazine", Weapons.BottomlessMagazine, ENABLED },
    { "SpeedCola", Weapons.SpeedCola, ENABLED },
    { "RapidFire", Weapons.RapidFire, ENABLED },
    { "NoRecoil", Weapons.NoRecoil, ENABLED },
    { "OneHitKills", Weapons.OneHitKills, ENABLED },
    { "AlwaysCrit", Weapons.AlwaysCrit, ENABLED },
    { "InsaneCritDamage", Weapons.InsaneCritDamage, ENABLED },
    { "ShotgunSpray", Weapons.ShotgunSpray, ENABLED },
    { "HigherRange", Weapons.HigherRange, ENABLED },
    { "PenetrationRounds", Weapons.PenetrationRounds, ENABLED },
    { "HipfireAccuracy", Weapons.HipfireAccuracy, ENABLED },
    { "AdsAccuracy", Weapons.AdsAccuracy, ENABLED },
    { "ForceGun", Weapons.ForceGun, { "Enabled", "Power" } },
    { "GravityGun", Weapons.GravityGun, { "Enabled", "Distance" } },
    { "FlyingThunderGod", Weapons.FlyingThunderGod, ENABLED },
    { "SmartBlade", Weapons.SmartBlade, ENABLED },
    { "TeleportGun", Weapons.TeleportGun, { "Enabled", "Range" } },
    { "Blackwall", Weapons.Blackwall, ENABLED },
    { "DualWield", Weapons.DualWield, ENABLED },
    { "HighBlock", Weapons.HighBlock, ENABLED },
    { "LowStaminaCost", Weapons.LowStaminaCost, ENABLED },
    { "BladeCarnage", Weapons.BladeCarnage, ENABLED },
    { "InfiniteCombo", Weapons.InfiniteCombo, ENABLED },
    { "ExplosiveKnives", Weapons.ExplosiveKnives, ENABLED },
    { "SmartFastLock", Weapons.SmartFastLock, ENABLED },
    { "SmartWideLock", Weapons.SmartWideLock, ENABLED },
    { "SmartExtraTargets", Weapons.SmartExtraTargets, ENABLED },
    { "SmartPerfectAccuracy", Weapons.SmartPerfectAccuracy, ENABLED },
    { "SmartFastProjectiles", Weapons.SmartFastProjectiles, ENABLED },
    { "SmartLongRange", Weapons.SmartLongRange, ENABLED },
    { "ExplosiveBullets", Weapons.ExplosiveBullets, { "Enabled", "Type", "Damage", "Rate", "Chance", "OnEnemies", "OnSurfaces" } }
}

local WATCH_TIME = 1

local s_Queue = {}
local s_WatchUntil = 0
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

local function Each(stage, ...)
    for _, entry in ipairs(FEATURES) do
        local callback = entry[2][stage]
        if callback then Try(entry[1], callback, ...) end
    end
end

function Weapons.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function Weapons.Watching()
    return os.clock() < s_WatchUntil
end

function Weapons.Run(action)
    table.insert(s_Queue, action)
end

local function Shot()
    Weapons.ExplosiveBullets.OnShot()
    Weapons.ForceGun.OnShot()
    Weapons.GravityGun.OnShot()
end

local function Hit(target, hitEvent)
    if not hitEvent then return end
    Weapons.ExplosiveBullets.OnHit(hitEvent)
    Weapons.OneHitKills.OnHit(target, hitEvent)
end

local function Thrown()
    return Weapons.FlyingThunderGod.Enabled or Weapons.ExplosiveKnives.Enabled or Weapons.SmartBlade.Enabled
end

local function ProjectileHit(projectile, eventData)
    if not Thrown() or not projectile or not eventData then return end

    local instigator = projectile:GetInstigator()
    if not instigator or not instigator:IsPlayer() then return end

    Weapons.FlyingThunderGod.OnProjectileHit(eventData)
    Weapons.ExplosiveKnives.OnProjectileHit(eventData)
    Weapons.SmartBlade.OnProjectileHit(projectile)
end

function Weapons.Bind(store)
    for _, entry in ipairs(FEATURES) do store:Bind("Weapons." .. entry[1], entry[2], entry[3]) end
    store:Bind("Weapons.Controls", Weapons.Controls, { "Binds" })
    store:Bind("Weapons.Items", Arsenal, { "Quantity" })
    store:Bind("Weapons.Ammo", Weapons.Ammo, { "AddAmounts", "RemoveAmounts" })
    store:Bind("Weapons.Tuning", Weapons.Tuning, {
        "Enabled", "Damage", "FireRate", "ReloadSpeed", "ExtraMagazine", "Recoil", "Spread", "Range",
        "CritChance", "CritDamage", "HeadshotBonus", "ExtraPellets", "Presets"
    })
    Weapons.Controls.Fill()
end

function Weapons.Initialize()
    Observe("PlayerPuppet", "OnAction", function(_, action) Try("Weapon input", Weapon.Action, action) end)
    Observe("ShootEvents", "OnEnter", function() Try("Weapon shot", Shot) end)
    Observe("ScriptedPuppet", "OnHit", function(target, hitEvent) Try("Weapon hit", Hit, target, hitEvent) end)
    Observe("BaseProjectile", "ProjectileHit", function(projectile, eventData) Try("Thrown weapon", ProjectileHit, projectile, eventData) end)
    Each("Initialize")
end

local function RunQueue(player)
    local queue = s_Queue
    s_Queue = {}
    for _, action in ipairs(queue) do Try("Weapon action", action, player) end
end

function Weapons.Update(player)
    local now = os.clock()
    Try("Held weapon", Weapon.Update, player, now)
    if #s_Queue > 0 then RunQueue(player) end
    if Weapons.Blackwall.Enabled then Try("Weapon controls", Weapons.Controls.Update) end
    Each("Update", player, now)
    if Weapons.Tuning.Active() then Try("Weapon tuning", Weapons.Tuning.Update, player, now) end

    if not Weapons.Watching() then return end
    if not Catalog.Loaded then Try("Weapon catalog", Catalog.Load) end
    Try("Weapon arsenal", Arsenal.Update, player, now)
end

function Weapons.Reset()
    s_Queue = {}
    Each("Reset")
    Try("Weapon tuning", Weapons.Tuning.Reset)
    Try("Weapon arsenal", Arsenal.Reset)
    StatModifiers.RemoveAll()
    Weapon.Reset()
end

function Weapons.Shutdown(player)
    s_Queue = {}
    Each("Shutdown", player)
    Try("Weapon tuning", Weapons.Tuning.Shutdown)
    StatModifiers.RemoveAll()
end

return Weapons
