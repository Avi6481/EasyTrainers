local ConfigManager = require("Config/OptionConfig")
local Self = require("Features/Self")

local function Toggle(id, ref, default, labelKey, keywords)
    return ConfigManager.DefineToggle(id, ref, default, {
        LabelKey = labelKey,
        Category = "self",
        Keywords = keywords,
    })
end

local function RegisterAllSelfOptions()
    local Enhancements = Self.StatModifiers.Enhancements
    local Cooldown = Self.StatModifiers.Cooldown
    local Stealth = Self.StatModifiers.Stealth

    ConfigManager.RegisterAll({
        Toggle("toggle.self.godmode", Self.GodMode.enabled, false, "self.godmode.label", { "health", "invincible" }),
        Toggle("toggle.self.invisibility", Self.Invisibility.enabled, false, "self.invisibility.label", { "hidden", "invisible" }),
        Toggle("toggle.self.superspeed", Self.SuperSpeed.enabled, false, "self.superspeed.label", { "movement", "run" }),
        Toggle("toggle.self.noclip", Self.NoClip.toggleNoClip, false, "self.noclip.label", { "fly", "collision" }),
        { Id = "number.self.noclip.speed", Kind = ConfigManager.Registry.Kind.Number,
            Ref = Self.NoClip.moveSpeed, Default = 1.5, Label = "Movement Speed", Category = "self" },
        { Id = "number.self.noclip.vertical", Kind = ConfigManager.Registry.Kind.Number,
            Ref = Self.NoClip.verticalSpeed, Default = 1.0, Label = "Vertical Speed", Category = "self" },
        { Id = "number.self.noclip.boost", Kind = ConfigManager.Registry.Kind.Number,
            Ref = Self.NoClip.boostMultiplier, Default = 2.5, Label = "Boost Multiplier", Category = "self" },
        { Id = "number.self.noclip.precision", Kind = ConfigManager.Registry.Kind.Number,
            Ref = Self.NoClip.precisionMultiplier, Default = 0.7, Label = "Precision Multiplier", Category = "self" },
        { Id = "number.self.noclip.deadzone", Kind = ConfigManager.Registry.Kind.Number,
            Ref = Self.NoClip.gamepadDeadzone, Default = 7849, Label = "Gamepad Deadzone", Category = "self" },
        Toggle("toggle.self.infinitejump", Self.InfiniteJumps.enabled, false, "self.infinitejump.label", { "movement", "jump" }),
        Toggle("toggle.self.infiniteairdash", Self.InfiniteAirDash.enabled, false, "self.infiniteairdash.label", { "movement", "dash" }),
        Toggle("toggle.self.airthrusters", Self.AirThrusterBoots.enabled, false, "modifiers.airthrusterboots.label", { "movement", "hover", "fly" }),
        Toggle("toggle.self.airhover", Self.AdvancedMobility.toggleAirHover, false, "modifiers.airhover.label", { "movement", "hover", "air" }),
        Toggle("toggle.self.neverwanted", Self.WantedLevel.tickNeverWanted, false, "self.neverwanted.label", { "wanted", "police" }),
        Toggle("toggle.self.quicksilver", Self.StatModifiers.Movement.toggleQuicksilver, false, "self.quicksilversandevistan.label", { "movement", "speed", "sandevistan" }),

        Toggle("toggle.self.refillhealth", Enhancements.toggleSetHealthFull, false, "self.refillhealth.label", { "health", "restore" }),
        Toggle("toggle.self.refillstamina", Enhancements.toggleSetStaminaFull, false, "modifiers.refillstamina.label", { "stamina", "restore" }),
        Toggle("toggle.self.refillmemory", Enhancements.toggleSetMemoryFull, false, "self.refillmemory.label", { "ram", "memory", "restore" }),
        Toggle("toggle.self.refilloxygen", Enhancements.toggleSetOxygenFull, false, "modifiers.refilloxygen.label", { "oxygen", "restore" }),
        Toggle("toggle.self.healthregen", Enhancements.toggleHealthRegen, false, "self.healthregen.label", { "health", "regeneration" }),
        Toggle("toggle.self.armorboost", Enhancements.toggleArmor, false, "self.armorboost.label", { "armor", "defense" }),
        Toggle("toggle.self.nofalldamage", Enhancements.toggleFallDamage, false, "self.nofalldamage.label", { "fall", "damage" }),
        Toggle("toggle.self.resistances", Enhancements.toggleResistances, false, "self.resistances.label", { "damage", "defense" }),
        Toggle("toggle.self.combatregen", Enhancements.toggleCombatRegen, false, "self.combatregen.label", { "health", "combat", "regeneration" }),
        Toggle("toggle.self.infiniteoxygen", Enhancements.toggleInfiniteOxygen, false, "modifiers.infiniteoxygen.label", { "oxygen", "underwater" }),
        Toggle("toggle.self.infinitestamina", Enhancements.toggleInfiniteStamina, false, "modifiers.infinitestamina.label", { "stamina", "movement" }),

        Toggle("toggle.self.nonthreat", Stealth.toggleDetection, false, "self.nonthreat.label", { "stealth", "detection", "enemy" }),
        Toggle("toggle.self.lowtrace", Stealth.toggleTrace, false, "self.lowtracerate.label", { "stealth", "trace", "quickhack" }),

        Toggle("toggle.self.cooldown.heal", Cooldown.toggleHeal, false, "modifiers.cooldownheal.label", { "heal", "cooldown" }),
        Toggle("toggle.self.cooldown.grenade", Cooldown.toggleGrenade, false, "modifiers.cooldowngrenade.label", { "grenade", "cooldown" }),
        Toggle("toggle.self.cooldown.projectile", Cooldown.toggleProjectile, false, "modifiers.cooldownprojectile.label", { "projectile", "launcher", "cooldown" }),
        Toggle("toggle.self.cooldown.cloak", Cooldown.toggleCloak, false, "modifiers.cooldowncloak.label", { "cloak", "cooldown" }),
        Toggle("toggle.self.cooldown.sande", Cooldown.toggleSande, false, "modifiers.cooldownsande.label", { "sandevistan", "cooldown" }),
        Toggle("toggle.self.cooldown.berserk", Cooldown.toggleBerserk, false, "modifiers.cooldownberserk.label", { "berserk", "cooldown" }),
        Toggle("toggle.self.cooldown.keren", Cooldown.toggleKeren, false, "modifiers.cooldownkeren.label", { "kerenzikov", "cooldown" }),
        Toggle("toggle.self.cooldown.overclock", Cooldown.toggleOverclock, false, "modifiers.cooldownoverclock.label", { "overclock", "cooldown" }),
        Toggle("toggle.self.cooldown.quickhack", Cooldown.toggleQuickhack, false, "modifiers.cooldownquickhacks.label", { "quickhack", "cooldown" }),
        Toggle("toggle.self.cooldown.hackcost", Cooldown.toggleHackCost, false, "modifiers.reducequickhackcost.label", { "quickhack", "ram", "cost" }),
        Toggle("toggle.self.cooldown.memoryregen", Cooldown.toggleMemoryRegen, false, "modifiers.memoryregen.label", { "ram", "memory", "regeneration" }),
    })
end

return RegisterAllSelfOptions
