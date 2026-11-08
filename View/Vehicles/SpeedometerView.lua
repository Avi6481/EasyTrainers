local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Speedometer = require("Features/Vehicles/Speedometer")

local SpeedometerView = {}

local KEY = "vehicles.speedometer."

local COLORS = {
    { "activecolor", "ActiveColor" },
    { "needlecolor", "NeedleColor" },
    { "textcolor", "TextColor" },
    { "mutedcolor", "MutedColor" },
    { "ringcolor", "RingColor" }
}

local s_Enabled = Ref.Field(Speedometer, "Enabled")
local s_ShowRpm = Ref.Field(Speedometer, "ShowRpm")
local s_UseMph = Ref.Field(Speedometer, "UseMph")
local s_HideGame = Ref.Field(Speedometer, "HideGameSpeedometer")
local s_AutoMax = Ref.Field(Speedometer, "AutoMax")
local s_MaxSpeed = Ref.Field(Speedometer, "MaxSpeed")
local s_Scale = Ref.Field(Speedometer, "Scale")
local s_Position = Ref.Choice(Speedometer, "Position", Speedometer.Positions)
local s_OffsetX = Ref.Field(Speedometer, "OffsetX")
local s_OffsetY = Ref.Field(Speedometer, "OffsetY")
local s_Positions = nil

local function Label(name)
    return L(KEY .. name .. ".label")
end

local function Tip(name)
    Widgets.Tip(L(KEY .. name .. ".tip"))
end

local function Toggle(name, ref)
    Widgets.Toggle(Label(name), ref)
    Tip(name)
end

local function SliderInt(name, ref, min, max, step, format)
    Widgets.SliderInt(Label(name), ref, min, max, step, format)
    Tip(name)
end

local function Positions()
    if s_Positions then return s_Positions end

    s_Positions = {}
    for index, position in ipairs(Speedometer.Positions) do
        s_Positions[index] = { Label = L(KEY .. "positions." .. position:lower()), Tip = "" }
    end
    return s_Positions
end

local function MaxSpeed()
    if not Speedometer.AutoMax then
        SliderInt("maxspeed", s_MaxSpeed, 160, 500, 20, "%d km/h")
        return
    end

    local detected = Speedometer.DetectedMax()
    Widgets.ValueRow(Label("detected"), detected and string.format("%d km/h", detected) or L(KEY .. "detected.none"))
    Tip("detected")
end

local function View()
    Toggle("enabled", s_Enabled)
    Toggle("rpm", s_ShowRpm)
    Toggle("mph", s_UseMph)
    Toggle("hidegame", s_HideGame)
    Toggle("automax", s_AutoMax)
    MaxSpeed()
    Widgets.SliderFloat(Label("scale"), s_Scale, 0.7, 1.4, 0.05, "%.2fx")
    Tip("scale")

    Widgets.Break(L(KEY .. "placement"))
    Widgets.ValueRow(L(KEY .. "howtomove.label"), "")
    Widgets.Tip(L(KEY .. "howtomove.tip"))
    Widgets.Dropdown(Label("position"), s_Position, Positions())
    Tip("position")
    SliderInt("offsetx", s_OffsetX, -4000, 4000, 5, "%d px")
    SliderInt("offsety", s_OffsetY, -4000, 4000, 5, "%d px")
    if Widgets.Button(Label("resetposition")) then Speedometer.ResetPosition() end
    Tip("resetposition")

    Widgets.Break(L(KEY .. "colors"))
    for _, entry in ipairs(COLORS) do
        Widgets.ColorPicker(Label(entry[1]), Speedometer[entry[2]], false)
        Tip(entry[1])
    end
end

SpeedometerView.Menu = Submenu.Create("vehicles.speedometer.label", View)

return SpeedometerView
