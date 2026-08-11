local ConfigManager = require("Config/OptionConfig")
local VehicleViewStates = require("Features/Vehicles/VehicleViewStates")
local VehicleLightFade = require("Features/Vehicles/VehicleLightFade")
local VehicleSpeedometer = require("Features/Vehicles/VehicleSpeedometer")
local VehicleFreezeQuestTimer = require("Features/Vehicles/FreezeQuestTimer")
local Toggle = ConfigManager.DefineToggle

local function RegisterAllVehicleOptions()

    ConfigManager.RegisterAll({
        Toggle("toggle.spawner.deletelast", VehicleViewStates.deleteLastVehicle, true, {
            LabelKey = "vehiclelist.deletelast.label",
            TipKey = "vehiclelist.deletelast.tip",
            Category = "vehicle",
            Keywords = { "spawn", "delete", "last vehicle" },
        }),
        Toggle("toggle.spawner.mountonspawn", VehicleViewStates.mountOnSpawn, true, {
            LabelKey = "vehiclelist.mountonspawn.label",
            TipKey = "vehiclelist.mountonspawn.tip",
            Category = "vehicle",
            Keywords = { "spawn", "mount", "enter vehicle" },
        }),
        Toggle("toggle.spawner.preview", VehicleViewStates.previewVehicle, true, {
            LabelKey = "vehiclelist.previewvehicle.label",
            TipKey = "vehiclelist.previewvehicle.tip",
            Category = "vehicle",
            Keywords = { "spawn", "preview" },
        }),
        Toggle("toggle.vehicle.rgblights", VehicleLightFade.toggleRGBFade, false, {
            LabelKey = "vehiclelights.rgbfade.label",
            TipKey = "vehiclelights.rgbfade.tip",
            Category = "vehicle",
            Keywords = { "rgb", "lights", "color" },
        }),
        Toggle("toggle.vehicle.speedometer", VehicleSpeedometer.Enabled, true, {
            Label = "Vehicle Speedometer",
            Tip = "Show the analog speedometer while driving.",
            Category = "vehicle",
            Keywords = { "speed", "speedometer", "rpm", "gear" },
        }),
        Toggle("toggle.vehicle.speedometer.mph", VehicleSpeedometer.UseMPH, false, {
            Label = "Use MPH",
            Tip = "Display vehicle speed in miles per hour instead of kilometers per hour.",
            Category = "vehicle",
            Keywords = { "speed", "mph", "kph", "units" },
        }),
        Toggle("toggle.vehicle.speedometer.rpm", VehicleSpeedometer.ShowRPM, true, {
            Label = "Show RPM Gauge", Tip = "Show the smaller engine RPM gauge.",
            Category = "vehicle", Keywords = { "rpm", "gauge", "engine" },
        }),
        Toggle("toggle.vehicle.speedometer.automaticMax", VehicleSpeedometer.AutomaticMaxSpeed, true, {
            Label = "Automatic Maximum Speed", Tip = "Read the maximum speed from the mounted vehicle.",
            Category = "vehicle", Keywords = { "speedometer", "maximum", "automatic" },
        }),
        Toggle("toggle.vehicle.freezeQuestTimers", VehicleFreezeQuestTimer.toggleFreezeQuestTimer, false, {
            Label = "Freeze Vehicle Quest Timers", Tip = "Prevent timed vehicle objectives from counting down.",
            Category = "vehicle", Keywords = { "quest", "timer", "freeze" },
        }),
    })

end

return RegisterAllVehicleOptions
