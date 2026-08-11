local Self = require("Features/Self")
local Buttons = require("UI").Buttons
local Prevention = require("Utils").Prevention

local function NoClipView()
    Buttons.Toggle(L("self.noclip.label"), Self.NoClip.toggleNoClip, tip("self.noclip.tip"))
    Buttons.Break("", "Movement")
    Buttons.Float("Movement Speed", Self.NoClip.moveSpeed, "Horizontal noclip movement speed.")
    Buttons.Float("Vertical Speed", Self.NoClip.verticalSpeed, "Independent ascent and descent speed.")
    Buttons.Float("Boost Multiplier", Self.NoClip.boostMultiplier, "Speed multiplier while holding the boost control.")
    Buttons.Float("Precision Multiplier", Self.NoClip.precisionMultiplier,
        "Normal movement multiplier for precise positioning.")
    Buttons.Int("Gamepad Deadzone", Self.NoClip.gamepadDeadzone, "Minimum stick movement accepted by noclip.")
    Buttons.Break("", "Controls")
    Buttons.Bind("Move Forward", "NOCLIP_FORWARD", "Keyboard control used to move forward.")
    Buttons.Bind("Move Backward", "NOCLIP_BACKWARD", "Keyboard control used to move backward.")
    Buttons.Bind("Strafe Left", "NOCLIP_LEFT", "Keyboard control used to move left.")
    Buttons.Bind("Strafe Right", "NOCLIP_RIGHT", "Keyboard control used to move right.")
    Buttons.Bind("Ascend", "NOCLIP_UP", "Keyboard or controller control used to move upward.")
    Buttons.Bind("Descend", "NOCLIP_DOWN", "Keyboard or controller control used to move downward.")
    Buttons.Bind("Speed Boost", "NOCLIP_BOOST", "Keyboard or controller control used for boosted movement.")
end

local noClipMenu = { title = "Noclip", view = NoClipView }

local function SelfViewFunction()
    Buttons.Toggle(L("self.godmode.label"), Self.GodMode.enabled, tip("self.godmode.tip"))
    Buttons.Toggle(L("self.invisibility.label"), Self.Invisibility.enabled, tip("self.invisibility.tip"))
    Buttons.Toggle(L("self.superspeed.label"), Self.SuperSpeed.enabled, tip("self.superspeed.tip"))
    Buttons.Float(L("self.playerspeedmultiplier.label"), Self.StatModifiers.Movement.speedMultiplier, tip("self.playerspeedmultiplier.tip"))
    Buttons.Float(L("self.jumpheightmultiplier.label"), Self.StatModifiers.Movement.jumpMultiplier, tip("self.jumpheightmultiplier.tip"))
    Buttons.Toggle(L("self.quicksilversandevistan.label"), Self.StatModifiers.Movement.toggleQuicksilver, tip("self.quicksilversandevistan.tip"))
    Buttons.Submenu(L("self.noclip.label"), noClipMenu, tip("self.noclip.tip"))
    Buttons.Toggle(L("self.infinitejump.label"), Self.InfiniteJumps.enabled, tip("self.infinitejump.tip")) 
    -- Buttons.Toggle(L("self.infiniteairdash.label"), Self.InfiniteAirDash.enabled, tip("self.infiniteairdash.tip")) 

    Buttons.Break(L("self.wanted.label"))
    Buttons.Toggle(L("self.neverwanted.label"), Self.WantedLevel.tickNeverWanted, tip("self.neverwanted.tip"))
    Buttons.Int(L("self.wantedlevel.label"), Self.WantedLevel.heldWantedLevel, tip("self.wantedlevel.tip"), function()
        if not Self.WantedLevel.heldWantedLevel.enabled then
            Prevention.SetWantedLevel(Self.WantedLevel.heldWantedLevel.value or 0)
        end
    end)
    Buttons.Option(L("self.clearwanted.label"), tip("self.clearwanted.tip"), function()
        Self.WantedLevel.tickClearWanted.value = true
    end)

    Buttons.Break(L("self.healthdefense.label"))
    Buttons.Toggle(L("self.refillhealth.label"), Self.StatModifiers.Enhancements.toggleSetHealthFull, tip("self.refillhealth.tip"))
    Buttons.Toggle(L("self.healthregen.label"), Self.StatModifiers.Enhancements.toggleHealthRegen, tip("self.healthregen.tip"))
    Buttons.Toggle(L("self.armorboost.label"), Self.StatModifiers.Enhancements.toggleArmor, tip("self.armorboost.tip"))
    Buttons.Toggle(L("self.resistances.label"), Self.StatModifiers.Enhancements.toggleResistances, tip("self.resistances.tip"))
    Buttons.Toggle(L("self.combatregen.label"), Self.StatModifiers.Enhancements.toggleCombatRegen, tip("self.combatregen.tip"))
    Buttons.Toggle(L("self.nofalldamage.label"), Self.StatModifiers.Enhancements.toggleFallDamage, tip("self.nofalldamage.tip"))

    Buttons.Break(L("self.stealthhacking.label"))
    Buttons.Toggle(L("self.nonthreat.label"), Self.StatModifiers.Stealth.toggleDetection, tip("self.nonthreat.tip"))
    Buttons.Toggle(L("self.lowtracerate.label"), Self.StatModifiers.Stealth.toggleTrace, tip("self.lowtracerate.tip"))
    Buttons.Toggle(L("self.refillmemory.label"), Self.StatModifiers.Enhancements.toggleSetMemoryFull, tip("self.refillmemory.tip"))
end

local SelfView = { title = "self.title", view = SelfViewFunction }

return SelfView
