local Define = require("Features/Hotkeys/Define")
local Modifiers = require("Features/Modifiers/Modifiers")

local Toggle, Slider = Define.Toggle, Define.Slider

local COOLDOWN = "hotkeys.names.cooldown"

local ModifiersHotkeys = {
    Slider("ExtraRam", "modifiers.extraram", Modifiers.ExtraRam, "Amount", "+%d"),
    Slider("RamRegen", "modifiers.ramregen", Modifiers.RamRegen, "Multiplier", "%.1fx"),
    Slider("QuickhackCost", "modifiers.quickhackcost", Modifiers.QuickhackCost, "Percent", "-%d%%"),
    Slider("FasterUploads", "modifiers.fasteruploads", Modifiers.FasterUploads, "Percent", "%d%%"),
    Slider("QuickhackSpread", "modifiers.quickhackspread", Modifiers.QuickhackSpread, "Amount", "+%d"),

    Toggle("HealingCooldown", "modifiers.healing", Modifiers.Cooldowns, "Healing", { Break = "modifiers.cooldowns", Pattern = COOLDOWN }),
    Toggle("GrenadesCooldown", "modifiers.grenades", Modifiers.Cooldowns, "Grenades", { Pattern = COOLDOWN }),
    Toggle("ProjectileLauncherCooldown", "modifiers.projectilelauncher", Modifiers.Cooldowns, "ProjectileLauncher", { Pattern = COOLDOWN }),
    Toggle("OpticalCamoCooldown", "modifiers.opticalcamo", Modifiers.Cooldowns, "OpticalCamo", { Pattern = COOLDOWN }),
    Toggle("SandevistanCooldown", "modifiers.sandevistan", Modifiers.Cooldowns, "Sandevistan", { Pattern = COOLDOWN }),
    Toggle("BerserkCooldown", "modifiers.berserk", Modifiers.Cooldowns, "Berserk", { Pattern = COOLDOWN }),
    Toggle("KerenzikovCooldown", "modifiers.kerenzikov", Modifiers.Cooldowns, "Kerenzikov", { Pattern = COOLDOWN }),
    Toggle("OverclockCooldown", "modifiers.overclock", Modifiers.Cooldowns, "Overclock", { Pattern = COOLDOWN }),
    Toggle("QuickhacksCooldown", "modifiers.quickhacks", Modifiers.Cooldowns, "Quickhacks", { Pattern = COOLDOWN }),

    Toggle("AirThrusters", "modifiers.airthrusters", Modifiers.AirThrusters, nil, { Break = "modifiers.cyberware" }),
    Toggle("AirHover", "modifiers.airhover", Modifiers.AirHover),
    Slider("SandevistanDuration", "modifiers.sandevistanduration", Modifiers.SandevistanDuration, "Multiplier", "%.1fx"),
    Slider("SandevistanTimeScale", "modifiers.sandevistantimescale", Modifiers.SandevistanTimeScale, "Multiplier", "%.1fx"),
    Slider("OpticalCamoDuration", "modifiers.opticalcamoduration", Modifiers.OpticalCamoDuration, "Multiplier", "%.1fx"),
    Slider("KerenzikovDuration", "modifiers.kerenzikovduration", Modifiers.KerenzikovDuration, "Multiplier", "%.1fx"),
    Slider("BerserkDuration", "modifiers.berserkduration", Modifiers.BerserkDuration, "Multiplier", "%.1fx"),

    Slider("CarryCapacity", "modifiers.carrycapacity", Modifiers.CarryCapacity, "Amount", "+%d", { Break = "modifiers.body" }),
    Slider("ExtraHealth", "modifiers.extrahealth", Modifiers.ExtraHealth, "Amount", "+%d"),
    Slider("HealthRegen", "modifiers.healthregen", Modifiers.HealthRegen, "Rate", "%d/s"),
    Slider("HealthBuffer", "modifiers.healthbuffer", Modifiers.HealthBuffer, "Amount", "+%d"),
    Slider("DodgeChance", "modifiers.dodgechance", Modifiers.DodgeChance, "Percent", "%d%%"),
    Slider("StrongerHeals", "modifiers.strongerheals", Modifiers.StrongerHeals, "Percent", "+%d%%"),
    Slider("AllResistances", "modifiers.allresistances", Modifiers.AllResistances, "Percent", "%d%%"),
    Slider("ElementalResistance", "modifiers.elementalresistance", Modifiers.ElementalResistance, "Percent", "%d%%"),
    Slider("ExplosionResistance", "modifiers.explosionresistance", Modifiers.ExplosionResistance, "Percent", "%d%%"),
    Slider("MeleeResistance", "modifiers.meleeresistance", Modifiers.MeleeResistance, "Percent", "%d%%"),
    Slider("DetectionSpeed", "modifiers.detectionspeed", Modifiers.DetectionSpeed, "Percent", "%d%%")
}

return ModifiersHotkeys
