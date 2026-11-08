local Define = require("Features/Hotkeys/Define")
local Vehicles = require("Features/Vehicles/Vehicles")

local Toggle, Slider, Action = Define.Toggle, Define.Slider, Define.Action

local VehiclesHotkeys = {
    Action("BringLast", "vehicles.bringlast", Vehicles.BringLast),
    Action("DespawnLast", "vehicles.despawnlast", Vehicles.DespawnLast),

    Toggle("GodMode", "vehicles.godmode", Vehicles.GodMode, nil, { Break = "vehicles.protection" }),
    Toggle("AutoRepair", "vehicles.autorepair", Vehicles.Repair, "Auto"),
    Action("RepairNow", "vehicles.repairnow", Vehicles.RepairNow, { Silent = true }),
    Toggle("StayOnBike", "vehicles.stayonbike", Vehicles.StayOnBike),

    Slider("Nitro", "vehicles.nitro", Vehicles.Nitro, "Strength", "%.0f", { Break = "vehicles.driving" }),
    Slider("BunnyHop", "vehicles.bunnyhop", Vehicles.BunnyHop, "Height", "%.1f m"),
    Toggle("InstantStop", "vehicles.instantstop", Vehicles.InstantStop),

    Action("Flip", "vehicles.flip", Vehicles.Flip, { Break = "vehicles.recovery" }),
    Toggle("AutoFlip", "vehicles.autoflip", Vehicles.AutoFlip),
    Action("Roof", "vehicles.roof", Vehicles.Roof),

    Slider("Bounce", "vehicles.bounce", Vehicles.Bounce, "Strength", "%.2fx", { Break = "vehicles.effects" }),
    Slider("RgbFade", "vehicles.lights.fade", Vehicles.Lights, "FadeSpeed", "%.2f", { Field = "Fade" }),
    Toggle("Performance", "vehicles.performance.enabled", Vehicles.Performance),
    Toggle("AirControl", "vehicles.performance.aircontrol", Vehicles.Performance, "AirControl"),
    Toggle("Speedometer", "vehicles.speedometer.enabled", Vehicles.Speedometer)
}

return VehiclesHotkeys
