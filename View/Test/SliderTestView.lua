local Logger = require("Core/Logger")
local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local SliderTestView = {}

local s_State = {
    Whole = 50,
    Percent = 75,
    Decimal = 0.5,
    Multiplier = 2,
    Negative = 0,
    Fine = 0.25,
    Speed = 2,
    SpeedOn = false,
    Amount = 1000,
    AmountOn = true,
    Count = 3,
    Scale = 1
}

local s_Whole = Ref.Field(s_State, "Whole")
local s_Percent = Ref.Field(s_State, "Percent")
local s_Decimal = Ref.Field(s_State, "Decimal")
local s_Multiplier = Ref.Field(s_State, "Multiplier")
local s_Negative = Ref.Field(s_State, "Negative")
local s_Fine = Ref.Field(s_State, "Fine")
local s_Speed = Ref.Field(s_State, "Speed")
local s_SpeedOn = Ref.Field(s_State, "SpeedOn")
local s_Amount = Ref.Field(s_State, "Amount")
local s_AmountOn = Ref.Field(s_State, "AmountOn")
local s_Count = Ref.Field(s_State, "Count")
local s_Scale = Ref.Field(s_State, "Scale")

function SliderTestView.Draw()
    Widgets.SliderInt("Whole Number", s_Whole, 0, 100, 1, "%d")
    Widgets.Tip("Steps by 1 from 0 to 100.")
    Widgets.SliderInt("Percent", s_Percent, 0, 100, 5, "%d%%")
    Widgets.Tip("Steps by 5 and shows a percent sign.")
    Widgets.SliderFloat("Decimal", s_Decimal, 0, 1, 0.05, "%.2f")
    Widgets.Tip("Steps by 0.05 from 0 to 1.")
    Widgets.SliderFloat("Multiplier", s_Multiplier, 1, 10, 0.5, "%.1fx")
    Widgets.Tip("Steps by 0.5 with an x suffix.")
    Widgets.SliderInt("Negative Range", s_Negative, -50, 50, 5, "%d")
    Widgets.Tip("Goes below zero.")
    Widgets.SliderFloat("Fine Steps", s_Fine, 0, 1, 0.01, "%.2f")
    Widgets.Tip("Steps by 0.01 for fine control.")

    Widgets.Break("With Toggles")
    Widgets.SliderFloat("Speed", s_Speed, 1.5, 5, 0.5, "%.1fx", s_SpeedOn)
    Widgets.Tip("A float slider with its own toggle, starts off.")
    Widgets.SliderInt("Amount", s_Amount, 250, 5000, 250, "%d", s_AmountOn)
    Widgets.Tip("A whole number slider with its own toggle, starts on.")

    Widgets.Break("Number Actions")
    if Widgets.NumberActionInt("Spawn Count", s_Count, 1, 10, 1, "%d") then
        Logger.Log("UI Test: Spawn Count fired with " .. s_State.Count)
    end
    Widgets.Tip("Pick a number, then press to fire it.")
    if Widgets.NumberActionFloat("Time Scale", s_Scale, 0.1, 2, 0.1, "%.1fx") then
        Logger.Log(string.format("UI Test: Time Scale fired with %.1f", s_State.Scale))
    end
    Widgets.Tip("Pick a value, then press to fire it.")
end

SliderTestView.Menu = Submenu.Create("Sliders", SliderTestView.Draw)

return SliderTestView
