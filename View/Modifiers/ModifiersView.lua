local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Modifiers = require("Features/Modifiers/Modifiers")

local ModifiersView = {}

local COOLDOWN_KEYS = {
    Healing = "healing",
    Grenades = "grenades",
    ProjectileLauncher = "projectilelauncher",
    OpticalCamo = "opticalcamo",
    Sandevistan = "sandevistan",
    Berserk = "berserk",
    Kerenzikov = "kerenzikov",
    Overclock = "overclock",
    Quickhacks = "quickhacks"
}

local s_ExtraRam = Ref.Field(Modifiers.ExtraRam, "Amount")
local s_ExtraRamOn = Ref.Field(Modifiers.ExtraRam, "Enabled")
local s_RamRegen = Ref.Field(Modifiers.RamRegen, "Multiplier")
local s_RamRegenOn = Ref.Field(Modifiers.RamRegen, "Enabled")
local s_QuickhackCost = Ref.Field(Modifiers.QuickhackCost, "Percent")
local s_QuickhackCostOn = Ref.Field(Modifiers.QuickhackCost, "Enabled")
local s_AirThrusters = Ref.Field(Modifiers.AirThrusters, "Enabled")
local s_AirHover = Ref.Field(Modifiers.AirHover, "Enabled")
local s_SandevistanDuration = Ref.Field(Modifiers.SandevistanDuration, "Multiplier")
local s_SandevistanDurationOn = Ref.Field(Modifiers.SandevistanDuration, "Enabled")
local s_SandevistanTimeScale = Ref.Field(Modifiers.SandevistanTimeScale, "Multiplier")
local s_SandevistanTimeScaleOn = Ref.Field(Modifiers.SandevistanTimeScale, "Enabled")
local s_CarryCapacity = Ref.Field(Modifiers.CarryCapacity, "Amount")
local s_CarryCapacityOn = Ref.Field(Modifiers.CarryCapacity, "Enabled")
local s_ExtraHealth = Ref.Field(Modifiers.ExtraHealth, "Amount")
local s_ExtraHealthOn = Ref.Field(Modifiers.ExtraHealth, "Enabled")
local s_DodgeChance = Ref.Field(Modifiers.DodgeChance, "Percent")
local s_DodgeChanceOn = Ref.Field(Modifiers.DodgeChance, "Enabled")
local s_FasterUploads = Ref.Field(Modifiers.FasterUploads, "Percent")
local s_FasterUploadsOn = Ref.Field(Modifiers.FasterUploads, "Enabled")
local s_QuickhackSpread = Ref.Field(Modifiers.QuickhackSpread, "Amount")
local s_QuickhackSpreadOn = Ref.Field(Modifiers.QuickhackSpread, "Enabled")
local s_OpticalCamoDuration = Ref.Field(Modifiers.OpticalCamoDuration, "Multiplier")
local s_OpticalCamoDurationOn = Ref.Field(Modifiers.OpticalCamoDuration, "Enabled")
local s_KerenzikovDuration = Ref.Field(Modifiers.KerenzikovDuration, "Multiplier")
local s_KerenzikovDurationOn = Ref.Field(Modifiers.KerenzikovDuration, "Enabled")
local s_BerserkDuration = Ref.Field(Modifiers.BerserkDuration, "Multiplier")
local s_BerserkDurationOn = Ref.Field(Modifiers.BerserkDuration, "Enabled")
local s_StrongerHeals = Ref.Field(Modifiers.StrongerHeals, "Percent")
local s_StrongerHealsOn = Ref.Field(Modifiers.StrongerHeals, "Enabled")
local s_ElementalResistance = Ref.Field(Modifiers.ElementalResistance, "Percent")
local s_ElementalResistanceOn = Ref.Field(Modifiers.ElementalResistance, "Enabled")
local s_ExplosionResistance = Ref.Field(Modifiers.ExplosionResistance, "Percent")
local s_ExplosionResistanceOn = Ref.Field(Modifiers.ExplosionResistance, "Enabled")
local s_MeleeResistance = Ref.Field(Modifiers.MeleeResistance, "Percent")
local s_HealthRegen = Ref.Field(Modifiers.HealthRegen, "Rate")
local s_HealthRegenOn = Ref.Field(Modifiers.HealthRegen, "Enabled")
local s_HealthBuffer = Ref.Field(Modifiers.HealthBuffer, "Amount")
local s_HealthBufferOn = Ref.Field(Modifiers.HealthBuffer, "Enabled")
local s_AllResistances = Ref.Field(Modifiers.AllResistances, "Percent")
local s_AllResistancesOn = Ref.Field(Modifiers.AllResistances, "Enabled")
local s_MeleeResistanceOn = Ref.Field(Modifiers.MeleeResistance, "Enabled")
local s_DetectionSpeed = Ref.Field(Modifiers.DetectionSpeed, "Percent")
local s_DetectionSpeedOn = Ref.Field(Modifiers.DetectionSpeed, "Enabled")

local s_Cooldowns = {}
for _, ability in ipairs(Modifiers.Cooldowns.Abilities) do
    s_Cooldowns[ability] = Ref.Field(Modifiers.Cooldowns, ability)
end

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function SliderFloat(key, ref, min, max, step, format, enabled)
    Widgets.SliderFloat(L(key .. ".label"), ref, min, max, step, format, enabled)
    Widgets.Tip(L(key .. ".tip"))
end

local function SliderInt(key, ref, min, max, step, format, enabled)
    Widgets.SliderInt(L(key .. ".label"), ref, min, max, step, format, enabled)
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    SliderInt("modifiers.extraram", s_ExtraRam, 1, 250, 1, "+%d", s_ExtraRamOn)
    SliderFloat("modifiers.ramregen", s_RamRegen, 1.5, 10, 0.5, "%.1fx", s_RamRegenOn)
    SliderInt("modifiers.quickhackcost", s_QuickhackCost, 10, 100, 10, "-%d%%", s_QuickhackCostOn)
    SliderInt("modifiers.fasteruploads", s_FasterUploads, 10, 100, 10, "%d%%", s_FasterUploadsOn)
    SliderInt("modifiers.quickhackspread", s_QuickhackSpread, 1, 10, 1, "+%d", s_QuickhackSpreadOn)

    Widgets.Break(L("modifiers.cooldowns"))
    for _, ability in ipairs(Modifiers.Cooldowns.Abilities) do
        Toggle("modifiers." .. COOLDOWN_KEYS[ability], s_Cooldowns[ability])
    end

    Widgets.Break(L("modifiers.cyberware"))
    Toggle("modifiers.airthrusters", s_AirThrusters)
    Toggle("modifiers.airhover", s_AirHover)
    SliderFloat("modifiers.sandevistanduration", s_SandevistanDuration, 1.5, 10, 0.5, "%.1fx", s_SandevistanDurationOn)
    SliderFloat("modifiers.sandevistantimescale", s_SandevistanTimeScale, 0.1, 0.9, 0.1, "%.1fx", s_SandevistanTimeScaleOn)
    SliderFloat("modifiers.opticalcamoduration", s_OpticalCamoDuration, 1.5, 10, 0.5, "%.1fx", s_OpticalCamoDurationOn)
    SliderFloat("modifiers.kerenzikovduration", s_KerenzikovDuration, 1.5, 10, 0.5, "%.1fx", s_KerenzikovDurationOn)
    SliderFloat("modifiers.berserkduration", s_BerserkDuration, 1.5, 10, 0.5, "%.1fx", s_BerserkDurationOn)

    Widgets.Break(L("modifiers.body"))
    SliderInt("modifiers.carrycapacity", s_CarryCapacity, 100, 5000, 100, "+%d", s_CarryCapacityOn)
    SliderInt("modifiers.extrahealth", s_ExtraHealth, 100, 5000, 100, "+%d", s_ExtraHealthOn)
    SliderInt("modifiers.healthregen", s_HealthRegen, 1, 50, 1, "%d/s", s_HealthRegenOn)
    SliderInt("modifiers.healthbuffer", s_HealthBuffer, 50, 2000, 50, "+%d", s_HealthBufferOn)
    SliderInt("modifiers.dodgechance", s_DodgeChance, 10, 100, 10, "%d%%", s_DodgeChanceOn)
    SliderInt("modifiers.strongerheals", s_StrongerHeals, 25, 300, 25, "+%d%%", s_StrongerHealsOn)
    SliderInt("modifiers.allresistances", s_AllResistances, 10, 100, 10, "%d%%", s_AllResistancesOn)
    SliderInt("modifiers.elementalresistance", s_ElementalResistance, 10, 100, 10, "%d%%", s_ElementalResistanceOn)
    SliderInt("modifiers.explosionresistance", s_ExplosionResistance, 10, 100, 10, "%d%%", s_ExplosionResistanceOn)
    SliderInt("modifiers.meleeresistance", s_MeleeResistance, 10, 100, 10, "%d%%", s_MeleeResistanceOn)
    SliderInt("modifiers.detectionspeed", s_DetectionSpeed, 10, 90, 10, "%d%%", s_DetectionSpeedOn)
end

ModifiersView.Menu = Submenu.Create("modifiers.title", View)

return ModifiersView
