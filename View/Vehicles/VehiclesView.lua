local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Vehicles = require("Features/Vehicles/Vehicles")
local BrowserView = require("View/Vehicles/BrowserView")
local SpawnerSettingsView = require("View/Vehicles/SpawnerSettingsView")
local LightsView = require("View/Vehicles/LightsView")
local PaintView = require("View/Vehicles/PaintView")
local PerformanceView = require("View/Vehicles/PerformanceView")
local SpeedometerView = require("View/Vehicles/SpeedometerView")

local VehiclesView = {}

local s_GodMode = Ref.Field(Vehicles.GodMode, "Enabled")
local s_AutoRepair = Ref.Field(Vehicles.Repair, "Auto")
local s_StayOnBike = Ref.Field(Vehicles.StayOnBike, "Enabled")
local s_Nitro = Ref.Field(Vehicles.Nitro, "Enabled")
local s_NitroStrength = Ref.Field(Vehicles.Nitro, "Strength")
local s_BunnyHop = Ref.Field(Vehicles.BunnyHop, "Enabled")
local s_BunnyHeight = Ref.Field(Vehicles.BunnyHop, "Height")
local s_InstantStop = Ref.Field(Vehicles.InstantStop, "Enabled")
local s_AutoFlip = Ref.Field(Vehicles.AutoFlip, "Enabled")
local s_Bounce = Ref.Field(Vehicles.Bounce, "Enabled")
local s_BounceStrength = Ref.Field(Vehicles.Bounce, "Strength")

local function Link(key, menu)
    Widgets.SubmenuButton(L(key .. ".label"), menu)
    Widgets.Tip(L(key .. ".tip"))
end

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function Button(key, action, hold)
    local pressed
    if hold then
        pressed = Widgets.HoldButton(L(key .. ".label"))
    else
        pressed = Widgets.Button(L(key .. ".label"))
    end
    if pressed then action() end
    Widgets.Tip(L(key .. ".tip"))
end

local function Slider(key, ref, min, max, step, format, enabled)
    Widgets.SliderFloat(L(key .. ".label"), ref, min, max, step, format, enabled)
    Widgets.Tip(L(key .. ".tip"))
end

local function Links()
    Link("vehicles.settings", SpawnerSettingsView.Menu)
    Link("vehicles.spawner", BrowserView.Spawner)
    Link("vehicles.garage", BrowserView.Garage)
    Link("vehicles.paint", PaintView.Menu)
    Link("vehicles.performance", PerformanceView.Menu)
    Link("vehicles.speedometer", SpeedometerView.Menu)
    Link("vehicles.lights", LightsView.Menu)
end

local function Spawned()
    Button("vehicles.bringlast", Vehicles.BringLast)
    Button("vehicles.despawnlast", Vehicles.DespawnLast)
    Button("vehicles.despawnall", Vehicles.DespawnAll, true)
end

local function Protection()
    Widgets.Break(L("vehicles.protection"))
    Toggle("vehicles.godmode", s_GodMode)
    Toggle("vehicles.autorepair", s_AutoRepair)
    Button("vehicles.repairnow", Vehicles.RepairNow)
    Button("vehicles.restoreparts", Vehicles.RestoreParts, true)
    Toggle("vehicles.stayonbike", s_StayOnBike)
end

local function Driving()
    Widgets.Break(L("vehicles.driving"))
    Slider("vehicles.nitro", s_NitroStrength, 2, 40, 1, "%.0f", s_Nitro)
    Slider("vehicles.bunnyhop", s_BunnyHeight, 0.5, 10, 0.5, "%.1f m", s_BunnyHop)
    Toggle("vehicles.instantstop", s_InstantStop)
end

local function Recovery()
    Widgets.Break(L("vehicles.recovery"))
    Button("vehicles.flip", Vehicles.Flip)
    Toggle("vehicles.autoflip", s_AutoFlip)
    Button("vehicles.roof", Vehicles.Roof)
end

local function Effects()
    Widgets.Break(L("vehicles.effects"))
    Slider("vehicles.bounce", s_BounceStrength, 0.5, 3, 0.25, "%.2fx", s_Bounce)
end

local function View()
    Vehicles.Watch()

    Links()
    Widgets.Break("")
    Spawned()
    Protection()
    Driving()
    Recovery()
    Effects()
end

VehiclesView.Menu = Submenu.Create("vehicles.title", View)

return VehiclesView
