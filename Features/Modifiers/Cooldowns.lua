local StatPools = require("Utils/StatPools")
local StatModifiers = require("Utils/StatModifiers")

local Cooldowns = {
    Healing = false,
    Grenades = false,
    ProjectileLauncher = false,
    OpticalCamo = false,
    Sandevistan = false,
    Berserk = false,
    Kerenzikov = false,
    Overclock = false,
    Quickhacks = false
}

Cooldowns.Abilities = {
    "Healing", "Grenades", "ProjectileLauncher", "OpticalCamo", "Sandevistan",
    "Berserk", "Kerenzikov", "Overclock", "Quickhacks"
}

local INTERVAL = 0.25

local ABILITIES = {
    Healing = { Pool = "HealingItemsCharges" },
    Grenades = { Pool = "GrenadesCharges" },
    ProjectileLauncher = { Pool = "ProjectileLauncherCharges", Effects = { "BaseStatusEffect.ProjectileLauncherCooldown" } },
    OpticalCamo = {
        Pool = "OpticalCamoCharges", Below = 10,
        Stats = {
            { "OpticalCamoChargesDecayRateMult", "Additive", -1 },
            { "OpticalCamoRechargeDuration", "Multiplier", 0.01 }
        }
    },
    Sandevistan = {
        Pool = "SandevistanCharge", Below = 10, Effects = { "BaseStatusEffect.SandevistanCooldown" },
        Stats = {
            { "TimeDilationSandevistanDuration", "Multiplier", 1000 },
            { "SandevistanRechargeDuration", "Multiplier", 0.01 }
        }
    },
    Berserk = {
        Pool = "BerserkCharge", Below = 10, Effects = { "BaseStatusEffect.BerserkCooldown" },
        Stats = {
            { "BerserkChargesDecayRateMult", "Additive", -1 },
            { "BerserkRechargeDuration", "Multiplier", 0.01 }
        }
    },
    Kerenzikov = {
        Effects = { "BaseStatusEffect.KerenzikovCooldown" },
        Stats = { { "KerenzikovCooldownDuration", "Multiplier", 0.01 } }
    },
    Overclock = {
        Pool = "CyberdeckOverclock", Below = 10,
        Stats = {
            { "CyberdeckOverclockDecayRate", "Multiplier", 0.001 },
            { "CyberdeckOverclockCooldown", "Multiplier", 0.01 }
        }
    },
    Quickhacks = { Tag = "QuickHackCooldown" }
}

local s_Next = 0
local s_EffectIDs = {}
local s_Tags = {}

local function EffectID(name)
    local id = s_EffectIDs[name]
    if not id then
        id = TweakDBID.new(name)
        s_EffectIDs[name] = id
    end
    return id
end

local function Tag(name)
    local tag = s_Tags[name]
    if not tag then
        tag = CName.new(name)
        s_Tags[name] = tag
    end
    return tag
end

local function BuildStats(ability)
    return function()
        local entries = {}
        for _, stat in ipairs(ability.Stats) do
            table.insert(entries, { gamedataStatType[stat[1]], gameStatModifierType[stat[2]], stat[3] })
        end
        return entries
    end
end

local function SyncStats(player, key, enabled)
    local ability = ABILITIES[key]
    if not ability.Stats then return end
    if not ability.Build then ability.Build = BuildStats(ability) end
    StatModifiers.Sync("Cooldowns." .. key, enabled, 1, player:GetEntityID(), ability.Build)
end

local function RefillPool(ability)
    local pool = gamedataStatPoolType[ability.Pool]
    if not ability.Below then
        StatPools.Refill(pool)
        return
    end

    local value = StatPools.Get(pool)
    if value and value < ability.Below then StatPools.Set(pool, 100) end
end

local function Clear(player, effects, ability)
    if ability.Pool then RefillPool(ability) end

    for _, name in ipairs(ability.Effects or {}) do
        effects:RemoveStatusEffect(player:GetEntityID(), EffectID(name), 0)
    end

    if ability.Tag then StatusEffectHelper.RemoveStatusEffectsWithTag(player, Tag(ability.Tag), 0) end
end

function Cooldowns.Update(player)
    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    for _, key in ipairs(Cooldowns.Abilities) do
        SyncStats(player, key, Cooldowns[key])
    end

    local effects = Game.GetStatusEffectSystem()
    if not effects then return end

    for _, key in ipairs(Cooldowns.Abilities) do
        if Cooldowns[key] then Clear(player, effects, ABILITIES[key]) end
    end
end

return Cooldowns
