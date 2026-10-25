local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Prevention = require("Utils/Prevention")
local Self = require("Features/Self")

local Movement = Self.StatModifiers.Movement
local Enhancements = Self.StatModifiers.Enhancements
local Stealth = Self.StatModifiers.Stealth

local function NoClipView()
    Buttons.Toggle(L("self.noclip.label"), Self.NoClip.Enabled, tip("self.noclip.tip"))

    Buttons.Break("Movement")
    Buttons.Float("Movement Speed", Self.NoClip.MoveSpeed, "Horizontal No Clip movement speed.")
    Buttons.Float("Vertical Speed", Self.NoClip.VerticalSpeed, "Speed used when ascending or descending.")
    Buttons.Float("Boost Multiplier", Self.NoClip.BoostMultiplier, "Speed multiplier while holding the boost control.")
    Buttons.Float("Precision Multiplier", Self.NoClip.PrecisionMultiplier, "Normal movement multiplier for precise positioning.")
    Buttons.Int("Gamepad Deadzone", Self.NoClip.GamepadDeadzone, "Minimum stick movement accepted by No Clip.")

    Buttons.Break("Controls")
    Buttons.Bind("Move Forward", "NOCLIP_FORWARD", "Keyboard control used to move forward.")
    Buttons.Bind("Move Backward", "NOCLIP_BACKWARD", "Keyboard control used to move backward.")
    Buttons.Bind("Strafe Left", "NOCLIP_LEFT", "Keyboard control used to move left.")
    Buttons.Bind("Strafe Right", "NOCLIP_RIGHT", "Keyboard control used to move right.")
    Buttons.Bind("Ascend", "NOCLIP_UP", "Keyboard or controller control used to move upward.")
    Buttons.Bind("Descend", "NOCLIP_DOWN", "Keyboard or controller control used to move downward.")
    Buttons.Bind("Speed Boost", "NOCLIP_BOOST", "Keyboard or controller control used for boosted movement.")
end

local NoClipMenu = Submenu.Create("self.noclip.label", NoClipView)

local function SelfView()
    Buttons.Submenu(L("self.noclip.label"), NoClipMenu, tip("self.noclip.tip"))
    Buttons.Break("")
    Buttons.Toggle(L("self.godmode.label"), Self.GodMode.Enabled, tip("self.godmode.tip"))
    Buttons.Toggle(L("self.invisibility.label"), Self.Invisibility.Enabled, tip("self.invisibility.tip"))
    Buttons.Toggle(L("self.superspeed.label"), Self.SuperSpeed.Enabled, tip("self.superspeed.tip"))
    Buttons.Float(L("self.playerspeedmultiplier.label"), Movement.SpeedMultiplier, tip("self.playerspeedmultiplier.tip"))
    Buttons.Float(L("self.jumpheightmultiplier.label"), Movement.JumpMultiplier, tip("self.jumpheightmultiplier.tip"))
    Buttons.Toggle(L("self.quicksilversandevistan.label"), Movement.Quicksilver, tip("self.quicksilversandevistan.tip"))
    Buttons.Toggle(L("self.infinitejump.label"), Self.InfiniteJumps.Enabled, tip("self.infinitejump.tip"))

    Buttons.Break(L("self.wanted.label"))
    Buttons.Toggle(L("self.neverwanted.label"), Self.WantedLevel.NeverWanted, tip("self.neverwanted.tip"))
    Buttons.Int(L("self.wantedlevel.label"), Self.WantedLevel.HeldLevel, tip("self.wantedlevel.tip"), function(value)
        if not Self.WantedLevel.HeldLevel.enabled then Prevention.SetWantedLevel(value or 0) end
    end)
    Buttons.Option(L("self.clearwanted.label"), tip("self.clearwanted.tip"), Self.WantedLevel.Clear)

    Buttons.Break(L("self.healthdefense.label"))
    Buttons.Toggle(L("self.refillhealth.label"), Enhancements.RefillHealth, tip("self.refillhealth.tip"))
    Buttons.Toggle(L("self.healthregen.label"), Enhancements.HealthRegen, tip("self.healthregen.tip"))
    Buttons.Toggle(L("self.armorboost.label"), Enhancements.Armor, tip("self.armorboost.tip"))
    Buttons.Toggle(L("self.resistances.label"), Enhancements.Resistances, tip("self.resistances.tip"))
    Buttons.Toggle(L("self.combatregen.label"), Enhancements.CombatRegen, tip("self.combatregen.tip"))
    Buttons.Toggle(L("self.nofalldamage.label"), Enhancements.NoFallDamage, tip("self.nofalldamage.tip"))

    Buttons.Break(L("self.stealthhacking.label"))
    Buttons.Toggle(L("self.nonthreat.label"), Stealth.NonThreat, tip("self.nonthreat.tip"))
    Buttons.Toggle(L("self.lowtracerate.label"), Stealth.LowTrace, tip("self.lowtracerate.tip"))
    Buttons.Toggle(L("self.refillmemory.label"), Enhancements.RefillMemory, tip("self.refillmemory.tip"))
end

return Submenu.Create("self.title", SelfView)
