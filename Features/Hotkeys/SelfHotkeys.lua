local Define = require("Features/Hotkeys/Define")
local Self = require("Features/Self/Self")

local Toggle, Slider, Action = Define.Toggle, Define.Slider, Define.Action

local SelfHotkeys = {
    Toggle("NoClip", "noclip.enabled", Self.NoClip),
    Toggle("GodMode", "self.godmode", Self.GodMode),
    Toggle("Undetectable", "self.undetectable", Self.Undetectable),
    Toggle("Invisibility", "self.invisibility", Self.Invisibility),
    Toggle("LowTrace", "self.lowtrace", Self.LowTrace),
    Action("LoseEnemies", "self.loseenemies", Self.LoseEnemies.Request, { Silent = true }),
    Toggle("InfiniteStamina", "self.infinitestamina", Self.InfiniteStamina),
    Toggle("InfiniteOxygen", "self.infiniteoxygen", Self.InfiniteOxygen),

    Slider("SuperSpeed", "self.superspeed", Self.SuperSpeed, "Speed", "%.1fx", { Break = "self.movement" }),
    Slider("RunSpeed", "self.runspeed", Self.RunSpeed, "Multiplier", "%.1fx"),
    Slider("JumpHeight", "self.jumpheight", Self.JumpHeight, "Multiplier", "%.1fx"),
    Toggle("InfiniteJumps", "self.infinitejumps", Self.InfiniteJumps),

    Toggle("NeverWanted", "self.neverwanted", Self.NeverWanted, nil, { Break = "self.wanted" }),
    Slider("WantedLevel", "self.wantedlevel", Self.WantedLevel, "Level", "%d", { Field = "Hold" }),
    Action("ClearWanted", "self.clearwanted", Self.WantedLevel.Clear),

    Action("FullRestore", "self.fullrestore", Self.FullRestore.Request, { Break = "self.health", Silent = true }),
    Action("ClearStatusEffects", "self.clearstatuseffects", Self.ClearStatusEffects.Request, { Silent = true }),
    Toggle("RefillHealth", "self.refillhealth", Self.RefillHealth),
    Toggle("CombatRegen", "self.combatregen", Self.CombatRegen),
    Toggle("NoFallDamage", "self.nofalldamage", Self.NoFallDamage),
    Slider("Armor", "self.armor", Self.Armor, "Amount", "%d"),

    Toggle("Quicksilver", "self.quicksilver", Self.Quicksilver, nil, { Break = "self.cyberware" }),
    Toggle("RefillRam", "self.refillram", Self.RefillRam)
}

return SelfHotkeys
