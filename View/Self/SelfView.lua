local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Self = require("Features/Self/Self")
local NoClipView = require("View/Self/NoClipView")

local SelfView = {}

local s_GodMode = Ref.Field(Self.GodMode, "Enabled")
local s_Undetectable = Ref.Field(Self.Undetectable, "Enabled")
local s_Invisibility = Ref.Field(Self.Invisibility, "Enabled")
local s_LowTrace = Ref.Field(Self.LowTrace, "Enabled")
local s_InfiniteStamina = Ref.Field(Self.InfiniteStamina, "Enabled")
local s_InfiniteOxygen = Ref.Field(Self.InfiniteOxygen, "Enabled")
local s_SuperSpeed = Ref.Field(Self.SuperSpeed, "Speed")
local s_SuperSpeedOn = Ref.Field(Self.SuperSpeed, "Enabled")
local s_RunSpeed = Ref.Field(Self.RunSpeed, "Multiplier")
local s_RunSpeedOn = Ref.Field(Self.RunSpeed, "Enabled")
local s_JumpHeight = Ref.Field(Self.JumpHeight, "Multiplier")
local s_JumpHeightOn = Ref.Field(Self.JumpHeight, "Enabled")
local s_InfiniteJumps = Ref.Field(Self.InfiniteJumps, "Enabled")
local s_NeverWanted = Ref.Field(Self.NeverWanted, "Enabled")
local s_WantedLevel = Ref.Field(Self.WantedLevel, "Level")
local s_HoldWanted = Ref.Field(Self.WantedLevel, "Hold")
local s_RefillHealth = Ref.Field(Self.RefillHealth, "Enabled")
local s_CombatRegen = Ref.Field(Self.CombatRegen, "Enabled")
local s_NoFallDamage = Ref.Field(Self.NoFallDamage, "Enabled")
local s_Armor = Ref.Field(Self.Armor, "Amount")
local s_ArmorOn = Ref.Field(Self.Armor, "Enabled")
local s_Quicksilver = Ref.Field(Self.Quicksilver, "Enabled")
local s_RefillRam = Ref.Field(Self.RefillRam, "Enabled")

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function Button(key, action)
    if Widgets.Button(L(key .. ".label")) then action() end
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
    Widgets.SubmenuButton(L("noclip.title"), NoClipView.Menu)
    Widgets.Tip(L("noclip.tip"))

    Toggle("self.godmode", s_GodMode)
    Toggle("self.undetectable", s_Undetectable)
    Toggle("self.invisibility", s_Invisibility)
    Toggle("self.lowtrace", s_LowTrace)
    Button("self.loseenemies", Self.LoseEnemies.Request)
    Toggle("self.infinitestamina", s_InfiniteStamina)
    Toggle("self.infiniteoxygen", s_InfiniteOxygen)

    Widgets.Break(L("self.movement"))
    SliderFloat("self.superspeed", s_SuperSpeed, 1.5, 5, 0.5, "%.1fx", s_SuperSpeedOn)
    SliderFloat("self.runspeed", s_RunSpeed, 1, 5, 0.5, "%.1fx", s_RunSpeedOn)
    SliderFloat("self.jumpheight", s_JumpHeight, 1, 10, 0.5, "%.1fx", s_JumpHeightOn)
    Toggle("self.infinitejumps", s_InfiniteJumps)

    Widgets.Break(L("self.wanted"))
    Toggle("self.neverwanted", s_NeverWanted)
    SliderInt("self.wantedlevel", s_WantedLevel, 1, 5, 1, "%d", s_HoldWanted)
    Button("self.clearwanted", Self.WantedLevel.Clear)

    Widgets.Break(L("self.health"))
    Button("self.fullrestore", Self.FullRestore.Request)
    Button("self.clearstatuseffects", Self.ClearStatusEffects.Request)
    Toggle("self.refillhealth", s_RefillHealth)
    Toggle("self.combatregen", s_CombatRegen)
    Toggle("self.nofalldamage", s_NoFallDamage)
    SliderInt("self.armor", s_Armor, 250, 5000, 250, "%d", s_ArmorOn)

    Widgets.Break(L("self.cyberware"))
    Toggle("self.quicksilver", s_Quicksilver)
    Toggle("self.refillram", s_RefillRam)
end

SelfView.Menu = Submenu.Create("self.title", View)

return SelfView
