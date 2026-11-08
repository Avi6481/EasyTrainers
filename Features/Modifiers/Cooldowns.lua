local StatPools = require("Utils/StatPools")

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
    OpticalCamo = { Pool = "OpticalCamoCharges" },
    Sandevistan = { Pool = "SandevistanCharge", Effects = { "BaseStatusEffect.SandevistanCooldown" } },
    Berserk = { Pool = "BerserkCharge", Effects = { "BaseStatusEffect.BerserkCooldown" } },
    Kerenzikov = { Effects = { "BaseStatusEffect.KerenzikovCooldown" } },
    Overclock = { Pool = "CyberdeckOverclock" },
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

local function Clear(player, effects, ability)
    if ability.Pool then StatPools.Refill(gamedataStatPoolType[ability.Pool]) end

    for _, name in ipairs(ability.Effects or {}) do
        effects:RemoveStatusEffect(player:GetEntityID(), EffectID(name), 0)
    end

    if ability.Tag then StatusEffectHelper.RemoveStatusEffectsWithTag(player, Tag(ability.Tag), 0) end
end

function Cooldowns.Update(player)
    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    local effects = Game.GetStatusEffectSystem()
    if not effects then return end

    for _, key in ipairs(Cooldowns.Abilities) do
        if Cooldowns[key] then Clear(player, effects, ABILITIES[key]) end
    end
end

return Cooldowns
