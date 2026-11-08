local Logger = require("Core/Logger")
local StatModifiers = require("Utils/StatModifiers")

local Modifiers = {}

Modifiers.ExtraRam = require("Features/Modifiers/ExtraRam")
Modifiers.RamRegen = require("Features/Modifiers/RamRegen")
Modifiers.QuickhackCost = require("Features/Modifiers/QuickhackCost")
Modifiers.FasterUploads = require("Features/Modifiers/FasterUploads")
Modifiers.QuickhackSpread = require("Features/Modifiers/QuickhackSpread")
Modifiers.Cooldowns = require("Features/Modifiers/Cooldowns")
Modifiers.AirThrusters = require("Features/Modifiers/AirThrusters")
Modifiers.AirHover = require("Features/Modifiers/AirHover")
Modifiers.SandevistanDuration = require("Features/Modifiers/SandevistanDuration")
Modifiers.SandevistanTimeScale = require("Features/Modifiers/SandevistanTimeScale")
Modifiers.OpticalCamoDuration = require("Features/Modifiers/OpticalCamoDuration")
Modifiers.KerenzikovDuration = require("Features/Modifiers/KerenzikovDuration")
Modifiers.BerserkDuration = require("Features/Modifiers/BerserkDuration")
Modifiers.CarryCapacity = require("Features/Modifiers/CarryCapacity")
Modifiers.ExtraHealth = require("Features/Modifiers/ExtraHealth")
Modifiers.DodgeChance = require("Features/Modifiers/DodgeChance")
Modifiers.StrongerHeals = require("Features/Modifiers/StrongerHeals")
Modifiers.ElementalResistance = require("Features/Modifiers/ElementalResistance")
Modifiers.ExplosionResistance = require("Features/Modifiers/ExplosionResistance")
Modifiers.MeleeResistance = require("Features/Modifiers/MeleeResistance")
Modifiers.DetectionSpeed = require("Features/Modifiers/DetectionSpeed")
Modifiers.HealthRegen = require("Features/Modifiers/HealthRegen")
Modifiers.HealthBuffer = require("Features/Modifiers/HealthBuffer")
Modifiers.AllResistances = require("Features/Modifiers/AllResistances")

local FEATURES = {
    { "ExtraRam", Modifiers.ExtraRam, { "Enabled", "Amount" } },
    { "RamRegen", Modifiers.RamRegen, { "Enabled", "Multiplier" } },
    { "QuickhackCost", Modifiers.QuickhackCost, { "Enabled", "Percent" } },
    { "FasterUploads", Modifiers.FasterUploads, { "Enabled", "Percent" } },
    { "QuickhackSpread", Modifiers.QuickhackSpread, { "Enabled", "Amount" } },
    { "Cooldowns", Modifiers.Cooldowns, Modifiers.Cooldowns.Abilities },
    { "AirThrusters", Modifiers.AirThrusters, { "Enabled" } },
    { "AirHover", Modifiers.AirHover, { "Enabled" } },
    { "SandevistanDuration", Modifiers.SandevistanDuration, { "Enabled", "Multiplier" } },
    { "SandevistanTimeScale", Modifiers.SandevistanTimeScale, { "Enabled", "Multiplier" } },
    { "OpticalCamoDuration", Modifiers.OpticalCamoDuration, { "Enabled", "Multiplier" } },
    { "KerenzikovDuration", Modifiers.KerenzikovDuration, { "Enabled", "Multiplier" } },
    { "BerserkDuration", Modifiers.BerserkDuration, { "Enabled", "Multiplier" } },
    { "CarryCapacity", Modifiers.CarryCapacity, { "Enabled", "Amount" } },
    { "ExtraHealth", Modifiers.ExtraHealth, { "Enabled", "Amount" } },
    { "DodgeChance", Modifiers.DodgeChance, { "Enabled", "Percent" } },
    { "StrongerHeals", Modifiers.StrongerHeals, { "Enabled", "Percent" } },
    { "ElementalResistance", Modifiers.ElementalResistance, { "Enabled", "Percent" } },
    { "ExplosionResistance", Modifiers.ExplosionResistance, { "Enabled", "Percent" } },
    { "MeleeResistance", Modifiers.MeleeResistance, { "Enabled", "Percent" } },
    { "DetectionSpeed", Modifiers.DetectionSpeed, { "Enabled", "Percent" } },
    { "HealthRegen", Modifiers.HealthRegen, { "Enabled", "Rate" } },
    { "HealthBuffer", Modifiers.HealthBuffer, { "Enabled", "Amount" } },
    { "AllResistances", Modifiers.AllResistances, { "Enabled", "Percent" } }
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

function Modifiers.Bind(store)
    for _, entry in ipairs(FEATURES) do store:Bind("Modifiers." .. entry[1], entry[2], entry[3]) end
end

function Modifiers.Initialize()
    Each("Initialize")
end

function Modifiers.Update(player)
    Each("Update", player)
end

function Modifiers.Reset()
    Each("Reset")
    StatModifiers.RemoveAll()
end

function Modifiers.Shutdown(player)
    Each("Shutdown", player)
    StatModifiers.RemoveAll()
end

return Modifiers
