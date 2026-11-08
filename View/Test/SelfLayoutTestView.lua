local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local SelfLayoutTestView = {}

local s_State = {
    GodMode = false,
    Undetectable = false,
    InfiniteStamina = false,
    SuperSpeed = 2,
    SuperSpeedOn = false,
    RunSpeed = 1.5,
    RunSpeedOn = false,
    JumpHeight = 2,
    JumpHeightOn = false,
    NeverWanted = false,
    WantedLevel = 1,
    HoldWanted = false,
    RefillHealth = false,
    CombatRegen = false,
    NoFallDamage = false,
    Armor = 1000,
    ArmorOn = false,
    Quicksilver = false,
    RefillRam = false
}

local s_Refs = {}
for key in pairs(s_State) do s_Refs[key] = Ref.Field(s_State, key) end

local function Toggle(label, key)
    Widgets.Toggle(label, s_Refs[key])
    Widgets.Tip("Local test value. Doesn't touch the game.")
end

local function SliderFloat(label, key, min, max, step, format)
    Widgets.SliderFloat(label, s_Refs[key], min, max, step, format, s_Refs[key .. "On"])
    Widgets.Tip("Local test value. Doesn't touch the game.")
end

local function SliderInt(label, key, enabledKey, min, max, step, format)
    Widgets.SliderInt(label, s_Refs[key], min, max, step, format, s_Refs[enabledKey])
    Widgets.Tip("Local test value. Doesn't touch the game.")
end

function SelfLayoutTestView.Draw()
    Toggle("God Mode", "GodMode")
    Toggle("Undetectable", "Undetectable")
    Toggle("Infinite Stamina", "InfiniteStamina")

    Widgets.Break("Movement")
    SliderFloat("Super Speed", "SuperSpeed", 1.5, 5, 0.5, "%.1fx")
    SliderFloat("Run Speed", "RunSpeed", 1, 5, 0.5, "%.1fx")
    SliderFloat("Jump Height", "JumpHeight", 1, 10, 0.5, "%.1fx")

    Widgets.Break("Wanted")
    Toggle("Never Wanted", "NeverWanted")
    SliderInt("Wanted Level", "WantedLevel", "HoldWanted", 1, 5, 1, "%d")
    Widgets.Button("Clear Wanted Level")
    Widgets.Tip("Does nothing here.")

    Widgets.Break("Health")
    Toggle("Refill Health", "RefillHealth")
    Toggle("Combat Regen", "CombatRegen")
    Toggle("No Fall Damage", "NoFallDamage")
    SliderInt("Armor", "Armor", "ArmorOn", 250, 5000, 250, "%d")

    Widgets.Break("Cyberware")
    Toggle("Quicksilver", "Quicksilver")
    Toggle("Refill RAM", "RefillRam")
end

SelfLayoutTestView.Menu = Submenu.Create("Self Layout", SelfLayoutTestView.Draw)

return SelfLayoutTestView
