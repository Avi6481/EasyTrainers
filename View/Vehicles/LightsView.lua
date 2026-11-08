local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Vehicles = require("Features/Vehicles/Vehicles")

local LightsView = {}

local BLACK = { R = 0, G = 0, B = 0, A = 1 }

local s_State = Vehicles.Lights

local s_Strength = Ref.Field(s_State, "Strength")
local s_SingleStrength = Ref.Field(s_State, "SingleStrength")
local s_Kind = Ref.Field(s_State, "Kind")
local s_Fade = Ref.Field(Vehicles.Lights, "Fade")
local s_FadeSpeed = Ref.Field(Vehicles.Lights, "FadeSpeed")
local s_Items = nil

local function Items()
    if s_Items then return s_Items end

    s_Items = {}
    for index, kind in ipairs(Vehicles.Lights.Types) do
        s_Items[index] = { Label = L("vehicles.lights.types." .. kind:lower()), Tip = "" }
    end
    return s_Items
end

local function Kind()
    return Vehicles.Lights.Types[s_State.Kind] or Vehicles.Lights.Types[1]
end

local function AllChanged(color)
    Vehicles.LightColor(nil, color)
end

local function SingleChanged(color)
    Vehicles.LightColor(Kind(), color)
end

local function Button(key, action)
    if Widgets.Button(L("vehicles.lights." .. key .. ".label")) then action() end
    Widgets.Tip(L("vehicles.lights." .. key .. ".tip"))
end

local function View()
    Widgets.ColorPicker(L("vehicles.lights.all.label"), s_State.AllColor, false, AllChanged)
    Widgets.Tip(L("vehicles.lights.all.tip"))
    if Widgets.SliderFloat(L("vehicles.lights.strength.label"), s_Strength, 0, 5, 0.1, "%.1fx") then
        Vehicles.LightStrength(s_State.Strength)
    end
    Widgets.Tip(L("vehicles.lights.strength.tip"))
    Widgets.SliderFloat(L("vehicles.lights.fade.label"), s_FadeSpeed, 0.05, 1, 0.05, "%.2f", s_Fade)
    Widgets.Tip(L("vehicles.lights.fade.tip"))
    Button("off", function() Vehicles.LightColor(nil, BLACK) end)
    Button("reset", Vehicles.LightReset)

    Widgets.Break(L("vehicles.lights.single"))
    Widgets.Dropdown(L("vehicles.lights.kind.label"), s_Kind, Items())
    Widgets.Tip(L("vehicles.lights.kind.tip"))
    Widgets.ColorPicker(L("vehicles.lights.color.label"), s_State.SingleColor, false, SingleChanged)
    Widgets.Tip(L("vehicles.lights.color.tip"))
    if Widgets.SliderFloat(L("vehicles.lights.singlestrength.label"), s_SingleStrength, 0, 5, 0.1, "%.1fx") then
        Vehicles.LightStrength(s_State.SingleStrength, Kind())
    end
    Widgets.Tip(L("vehicles.lights.singlestrength.tip"))
    Button("on", function() Vehicles.LightSwitch(Kind(), true) end)
    Button("switchoff", function() Vehicles.LightSwitch(Kind(), false) end)
    Button("resetone", function() Vehicles.LightResetOne(Kind()) end)
end

LightsView.Menu = Submenu.Create("vehicles.lights.label", View)

return LightsView
