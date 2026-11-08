local Logger = require("Core/Logger")
local Police = require("Utils/Police")
local StatModifiers = require("Utils/StatModifiers")

local Self = {}

Self.GodMode = require("Features/Self/GodMode")
Self.Undetectable = require("Features/Self/Undetectable")
Self.Invisibility = require("Features/Self/Invisibility")
Self.LowTrace = require("Features/Self/LowTrace")
Self.LoseEnemies = require("Features/Self/LoseEnemies")
Self.InfiniteStamina = require("Features/Self/InfiniteStamina")
Self.InfiniteOxygen = require("Features/Self/InfiniteOxygen")
Self.SuperSpeed = require("Features/Self/SuperSpeed")
Self.RunSpeed = require("Features/Self/RunSpeed")
Self.JumpHeight = require("Features/Self/JumpHeight")
Self.InfiniteJumps = require("Features/Self/InfiniteJumps")
Self.NoClip = require("Features/Self/NoClip")
Self.NeverWanted = require("Features/Self/NeverWanted")
Self.WantedLevel = require("Features/Self/WantedLevel")
Self.FullRestore = require("Features/Self/FullRestore")
Self.ClearStatusEffects = require("Features/Self/ClearStatusEffects")
Self.RefillHealth = require("Features/Self/RefillHealth")
Self.CombatRegen = require("Features/Self/CombatRegen")
Self.NoFallDamage = require("Features/Self/NoFallDamage")
Self.Armor = require("Features/Self/Armor")
Self.Quicksilver = require("Features/Self/Quicksilver")
Self.RefillRam = require("Features/Self/RefillRam")

local FEATURES = {
    { "GodMode", Self.GodMode, { "Enabled" } },
    { "Undetectable", Self.Undetectable, { "Enabled" } },
    { "Invisibility", Self.Invisibility, { "Enabled" } },
    { "LowTrace", Self.LowTrace, { "Enabled" } },
    { "LoseEnemies", Self.LoseEnemies, {} },
    { "InfiniteStamina", Self.InfiniteStamina, { "Enabled" } },
    { "InfiniteOxygen", Self.InfiniteOxygen, { "Enabled" } },
    { "SuperSpeed", Self.SuperSpeed, { "Enabled", "Speed" } },
    { "RunSpeed", Self.RunSpeed, { "Enabled", "Multiplier" } },
    { "JumpHeight", Self.JumpHeight, { "Enabled", "Multiplier" } },
    { "InfiniteJumps", Self.InfiniteJumps, { "Enabled" } },
    { "NoClip", Self.NoClip, { "Speed", "Boost", "FollowCamera", "Controls" } },
    { "NeverWanted", Self.NeverWanted, { "Enabled" } },
    { "WantedLevel", Self.WantedLevel, { "Hold", "Level" } },
    { "FullRestore", Self.FullRestore, {} },
    { "ClearStatusEffects", Self.ClearStatusEffects, {} },
    { "RefillHealth", Self.RefillHealth, { "Enabled" } },
    { "CombatRegen", Self.CombatRegen, { "Enabled" } },
    { "NoFallDamage", Self.NoFallDamage, { "Enabled" } },
    { "Armor", Self.Armor, { "Enabled", "Amount" } },
    { "Quicksilver", Self.Quicksilver, { "Enabled" } },
    { "RefillRam", Self.RefillRam, { "Enabled" } }
}

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

function Self.Bind(store)
    for _, entry in ipairs(FEATURES) do
        if #entry[3] > 0 then store:Bind("Self." .. entry[1], entry[2], entry[3]) end
    end
end

function Self.Initialize()
    Each("Initialize")
end

function Self.Update(player)
    Each("Update", player)
end

function Self.Reset()
    Each("Reset")
    StatModifiers.RemoveAll()
    Police.Forget()
end

function Self.Shutdown(player)
    Each("Shutdown", player)
    StatModifiers.RemoveAll()
end

return Self
