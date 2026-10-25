local OptionConfig = require("Config/OptionConfig")
local Self = require("Features/Self")

local function Toggle(id, ref, labelKey, keywords)
    return OptionConfig.DefineToggle(id, ref, false, {
        LabelKey = labelKey,
        Category = "self",
        Keywords = keywords
    })
end

local function Number(id, ref, default, label)
    return { Id = id, Kind = OptionConfig.Registry.Kind.Number, Ref = ref, Default = default, Label = label, Category = "self" }
end

local function RegisterAllSelfOptions()
    local Modifiers = Self.StatModifiers
    local Enhancements = Modifiers.Enhancements
    local Cooldown = Modifiers.Cooldown
    local Stealth = Modifiers.Stealth

    OptionConfig.RegisterAll({
        Toggle("toggle.self.godmode", Self.GodMode.Enabled, "self.godmode.label", { "health", "invincible" }),
        Toggle("toggle.self.invisibility", Self.Invisibility.Enabled, "self.invisibility.label", { "hidden", "invisible" }),
        Toggle("toggle.self.superspeed", Self.SuperSpeed.Enabled, "self.superspeed.label", { "movement", "run" }),
        Toggle("toggle.self.noclip", Self.NoClip.Enabled, "self.noclip.label", { "fly", "collision" }),
        Number("number.self.noclip.speed", Self.NoClip.MoveSpeed, 1.5, "Movement Speed"),
        Number("number.self.noclip.vertical", Self.NoClip.VerticalSpeed, 1.0, "Vertical Speed"),
        Number("number.self.noclip.boost", Self.NoClip.BoostMultiplier, 2.5, "Boost Multiplier"),
        Number("number.self.noclip.precision", Self.NoClip.PrecisionMultiplier, 0.7, "Precision Multiplier"),
        Number("number.self.noclip.deadzone", Self.NoClip.GamepadDeadzone, 7849, "Gamepad Deadzone"),
        Number("number.self.speedmultiplier", Modifiers.Movement.SpeedMultiplier, 5.0, "Player Speed Multiplier"),
        Number("number.self.jumpmultiplier", Modifiers.Movement.JumpMultiplier, 3.0, "Jump Height Multiplier"),
        Number("number.self.sandevistanscale", Modifiers.Movement.SandevistanTimeScale, 0.1, "Sandevistan Time Scale"),
        Number("number.self.sandevistanduration", Modifiers.Movement.SandevistanDuration, 2.5, "Sandevistan Duration"),
        Number("number.self.carrycapacity", Modifiers.Utility.CarryCapacity, 360, "Carry Capacity"),
        Number("number.self.memorystat", Enhancements.MemoryStat, 20.0, "Memory Stat"),
        Toggle("toggle.self.infinitejump", Self.InfiniteJumps.Enabled, "self.infinitejump.label", { "movement", "jump" }),
        Toggle("toggle.self.infiniteairdash", Self.InfiniteAirDash.Enabled, "self.infiniteairdash.label", { "movement", "dash" }),
        Toggle("toggle.self.airthrusters", Self.AirThrusterBoots.Enabled, "modifiers.airthrusterboots.label", { "movement", "hover", "fly" }),
        Toggle("toggle.self.airhover", Self.AdvancedMobility.AirHover, "modifiers.airhover.label", { "movement", "hover", "air" }),
        Toggle("toggle.self.neverwanted", Self.WantedLevel.NeverWanted, "self.neverwanted.label", { "wanted", "police" }),
        OptionConfig.DefineButton("button.self.clearwanted", Self.WantedLevel.Clear, {
            LabelKey = "self.clearwanted.label", TipKey = "self.clearwanted.tip", Category = "self", Keywords = { "wanted", "police", "heat" }
        }),
        Toggle("toggle.self.quicksilver", Modifiers.Movement.Quicksilver, "self.quicksilversandevistan.label", { "movement", "speed", "sandevistan" }),

        Toggle("toggle.self.refillhealth", Enhancements.RefillHealth, "self.refillhealth.label", { "health", "restore" }),
        Toggle("toggle.self.refillstamina", Enhancements.RefillStamina, "modifiers.refillstamina.label", { "stamina", "restore" }),
        Toggle("toggle.self.refillmemory", Enhancements.RefillMemory, "self.refillmemory.label", { "ram", "memory", "restore" }),
        Toggle("toggle.self.refilloxygen", Enhancements.RefillOxygen, "modifiers.refilloxygen.label", { "oxygen", "restore" }),
        Toggle("toggle.self.healthregen", Enhancements.HealthRegen, "self.healthregen.label", { "health", "regeneration" }),
        Toggle("toggle.self.armorboost", Enhancements.Armor, "self.armorboost.label", { "armor", "defense" }),
        Toggle("toggle.self.nofalldamage", Enhancements.NoFallDamage, "self.nofalldamage.label", { "fall", "damage" }),
        Toggle("toggle.self.resistances", Enhancements.Resistances, "self.resistances.label", { "damage", "defense" }),
        Toggle("toggle.self.combatregen", Enhancements.CombatRegen, "self.combatregen.label", { "health", "combat", "regeneration" }),
        Toggle("toggle.self.infiniteoxygen", Enhancements.InfiniteOxygen, "modifiers.infiniteoxygen.label", { "oxygen", "underwater" }),
        Toggle("toggle.self.infinitestamina", Enhancements.InfiniteStamina, "modifiers.infinitestamina.label", { "stamina", "movement" }),

        Toggle("toggle.self.nonthreat", Stealth.NonThreat, "self.nonthreat.label", { "stealth", "detection", "enemy" }),
        Toggle("toggle.self.lowtrace", Stealth.LowTrace, "self.lowtracerate.label", { "stealth", "trace", "quickhack" }),

        Toggle("toggle.self.cooldown.heal", Cooldown.Heal, "modifiers.cooldownheal.label", { "heal", "cooldown" }),
        Toggle("toggle.self.cooldown.grenade", Cooldown.Grenade, "modifiers.cooldowngrenade.label", { "grenade", "cooldown" }),
        Toggle("toggle.self.cooldown.projectile", Cooldown.Projectile, "modifiers.cooldownprojectile.label", { "projectile", "launcher", "cooldown" }),
        Toggle("toggle.self.cooldown.cloak", Cooldown.Cloak, "modifiers.cooldowncloak.label", { "cloak", "cooldown" }),
        Toggle("toggle.self.cooldown.sande", Cooldown.Sandevistan, "modifiers.cooldownsande.label", { "sandevistan", "cooldown" }),
        Toggle("toggle.self.cooldown.berserk", Cooldown.Berserk, "modifiers.cooldownberserk.label", { "berserk", "cooldown" }),
        Toggle("toggle.self.cooldown.keren", Cooldown.Kerenzikov, "modifiers.cooldownkeren.label", { "kerenzikov", "cooldown" }),
        Toggle("toggle.self.cooldown.overclock", Cooldown.Overclock, "modifiers.cooldownoverclock.label", { "overclock", "cooldown" }),
        Toggle("toggle.self.cooldown.quickhack", Cooldown.Quickhack, "modifiers.cooldownquickhacks.label", { "quickhack", "cooldown" }),
        Toggle("toggle.self.cooldown.hackcost", Cooldown.HackCost, "modifiers.reducequickhackcost.label", { "quickhack", "ram", "cost" }),
        Toggle("toggle.self.cooldown.memoryregen", Cooldown.MemoryRegen, "modifiers.memoryregen.label", { "ram", "memory", "regeneration" })
    })
end

return RegisterAllSelfOptions
