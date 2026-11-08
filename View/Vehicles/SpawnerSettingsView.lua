local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Vehicles = require("Features/Vehicles/Vehicles")

local SpawnerSettingsView = {}

local s_Distance = Ref.Field(Vehicles, "SpawnDistance")
local s_Mount = Ref.Field(Vehicles, "MountOnSpawn")
local s_Replace = Ref.Field(Vehicles, "ReplacePrevious")
local s_AddToGarage = Ref.Field(Vehicles, "AddToGarage")
local s_Preview = Ref.Field(Vehicles.Preview, "Enabled")
local s_BounceTempo = Ref.Field(Vehicles.Bounce, "Tempo")

local function View()
    Widgets.SliderFloat(L("vehicles.distance.label"), s_Distance, 3, 25, 0.5, "%.1f m")
    Widgets.Tip(L("vehicles.distance.tip"))
    Widgets.Toggle(L("vehicles.mountonspawn.label"), s_Mount)
    Widgets.Tip(L("vehicles.mountonspawn.tip"))
    Widgets.Toggle(L("vehicles.replaceprevious.label"), s_Replace)
    Widgets.Tip(L("vehicles.replaceprevious.tip"))
    Widgets.Toggle(L("vehicles.addtogarage.label"), s_AddToGarage)
    Widgets.Tip(L("vehicles.addtogarage.tip"))
    Widgets.Toggle(L("vehicles.preview.label"), s_Preview)
    Widgets.Tip(L("vehicles.preview.tip"))
    if Widgets.Button(L("vehicles.reload.label")) then Vehicles.ReloadCatalog() end
    Widgets.Tip(L("vehicles.reload.tip"))

    Widgets.Break(L("vehicles.effects"))
    Widgets.SliderInt(L("vehicles.bouncetempo.label"), s_BounceTempo, 60, 180, 5, "%d / min")
    Widgets.Tip(L("vehicles.bouncetempo.tip"))

    Widgets.Break(L("vehicles.controls.title"))
    local controls = Vehicles.Controls
    for _, action in ipairs(controls.Actions) do
        local key = "vehicles.controls." .. action:lower()
        if Widgets.KeyBind(L(key .. ".label"), controls.Binds[action]) then controls.Fill() end
        Widgets.Tip(L(key .. ".tip"))
    end
    if Widgets.Button(L("vehicles.controls.reset.label")) then controls.Reset(controls.Actions) end
    Widgets.Tip(L("vehicles.controls.reset.tip"))
end

SpawnerSettingsView.Menu = Submenu.Create("vehicles.settings.label", View)

return SpawnerSettingsView
