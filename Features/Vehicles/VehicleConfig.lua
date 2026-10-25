local OptionConfig = require("Config/OptionConfig")
local VehicleViewStates = require("Features/Vehicles/VehicleViewStates")
local VehicleLightFade = require("Features/Vehicles/VehicleLightFade")
local VehicleSpeedometer = require("Features/Vehicles/VehicleSpeedometer")
local FreezeQuestTimer = require("Features/Vehicles/FreezeQuestTimer")
local VehicleGodMode = require("Features/Vehicles/VehicleGodMode")
local VehicleNitro = require("Features/Vehicles/VehicleNitro")
local VehiclePaint = require("Features/Vehicles/VehiclePaint")
local VehiclePerformance = require("Features/Vehicles/VehiclePerformance")
local VehicleRepair = require("Features/Vehicles/VehicleRepair")

local function Toggle(id, ref, default, metadata)
    metadata.Category = "vehicle"
    return OptionConfig.DefineToggle(id, ref, default, metadata)
end

local function Number(id, ref, default, label)
    return { Id = id, Kind = OptionConfig.Registry.Kind.Number, Ref = ref, Default = default, Label = label, Category = "vehicle" }
end

local function RegisterAllVehicleOptions()
    OptionConfig.RegisterAll({
        OptionConfig.DefineButton("button.vehicle.repairmounted", VehicleRepair.RepairMounted, {
            Label = "Repair Mounted Vehicle", Tip = "Fully repair the vehicle you are currently driving.", Category = "vehicle", Keywords = { "repair", "fix", "damage" }
        }),
        Toggle("toggle.spawner.deletelast", VehicleViewStates.DeleteLastVehicle, true, {
            LabelKey = "vehiclelist.deletelast.label",
            TipKey = "vehiclelist.deletelast.tip",
            Keywords = { "spawn", "delete", "last vehicle" }
        }),
        Toggle("toggle.spawner.mountonspawn", VehicleViewStates.MountOnSpawn, true, {
            LabelKey = "vehiclelist.mountonspawn.label",
            TipKey = "vehiclelist.mountonspawn.tip",
            Keywords = { "spawn", "mount", "enter vehicle" }
        }),
        Toggle("toggle.spawner.preview", VehicleViewStates.PreviewVehicle, true, {
            LabelKey = "vehiclelist.previewvehicle.label",
            TipKey = "vehiclelist.previewvehicle.tip",
            Keywords = { "spawn", "preview" }
        }),
        Toggle("toggle.vehicle.rgblights", VehicleLightFade.Enabled, false, {
            LabelKey = "vehiclelights.rgbfade.label",
            TipKey = "vehiclelights.rgbfade.tip",
            Keywords = { "rgb", "lights", "color" }
        }),
        Toggle("toggle.vehicle.speedometer", VehicleSpeedometer.Enabled, false, {
            Label = "Vehicle Speedometer",
            Tip = "Show the analog speedometer while driving.",
            Keywords = { "speed", "speedometer", "rpm", "gear" }
        }),
        Toggle("toggle.vehicle.speedometer.mph", VehicleSpeedometer.UseMPH, false, {
            Label = "Use MPH",
            Tip = "Display vehicle speed in miles per hour instead of kilometers per hour.",
            Keywords = { "speed", "mph", "kph", "units" }
        }),
        Toggle("toggle.vehicle.speedometer.rpm", VehicleSpeedometer.ShowRPM, true, {
            Label = "Show RPM Gauge",
            Tip = "Show the smaller engine RPM gauge.",
            Keywords = { "rpm", "gauge", "engine" }
        }),
        Toggle("toggle.vehicle.speedometer.automaticMax", VehicleSpeedometer.AutomaticMaxSpeed, false, {
            Label = "Automatic Maximum Speed",
            Tip = "Estimate the dial range from the mounted vehicle's highest gear speed.",
            Keywords = { "speedometer", "maximum", "automatic" }
        }),
        Toggle("toggle.vehicle.godmode", VehicleGodMode.Enabled, false, {
            Label = "Invincible Vehicle",
            Tip = "Makes the vehicle you drive immune to damage from collisions and attacks.",
            Keywords = { "god", "invincible", "damage", "repair" }
        }),
        Toggle("toggle.vehicle.autorepair", VehicleRepair.AutoRepair, false, {
            Label = "Auto Repair",
            Tip = "Instantly fixes the vehicle you drive whenever it takes damage: health, dents, glass, and tires. Works without Invincible Vehicle.",
            Keywords = { "repair", "fix", "deform", "dents", "glass", "tires", "pristine" }
        }),
        { Id = "number.vehicle.nitro", Kind = OptionConfig.Registry.Kind.Number, Ref = VehicleNitro.Multiplier, Default = 1.5, Label = "Nitrous Boost", Category = "vehicle" },
        Toggle("toggle.vehicle.paint.allvehicles", VehiclePaint.AllVehicles, false, {
            Label = "CrystalCoat on Any Vehicle (Beta)",
            Tip = "Beta. Unlocks CrystalCoat paint for every vehicle, but some vehicles have no paint layer and will not change color.",
            Keywords = { "paint", "crystalcoat", "color" }
        }),
        Toggle("toggle.vehicle.paint.rims", VehiclePaint.AffectRims, false, {
            Label = "Paint Rims",
            Tip = "Also recolor the wheel rims when the vehicle supports it.",
            Keywords = { "paint", "rims", "wheels" }
        }),
        Toggle("toggle.vehicle.performance", VehiclePerformance.Enabled, false, {
            Label = "Performance Tuning",
            Tip = "Turn on the vehicle performance tuning below.",
            Keywords = { "performance", "tuning", "speed", "acceleration", "brakes" }
        }),
        Number("number.vehicle.performance.topspeedbonus", VehiclePerformance.TopSpeedBonus, 0, "Top Speed Bonus"),
        Number("number.vehicle.performance.extraacceleration", VehiclePerformance.Acceleration, 0, "Extra Acceleration"),
        Number("number.vehicle.performance.extrabraking", VehiclePerformance.Braking, 0, "Extra Braking"),
        Number("number.vehicle.performance.downforce", VehiclePerformance.Downforce, 0, "Downforce"),
        Number("number.vehicle.performance.enginepower", VehiclePerformance.EnginePower, 1.0, "Engine Power"),
        Number("number.vehicle.performance.shiftspeed", VehiclePerformance.ShiftSpeed, 1.0, "Gear Shift Speed"),
        Number("number.vehicle.performance.frontgrip", VehiclePerformance.FrontGrip, 1.0, "Front Grip"),
        Number("number.vehicle.performance.reargrip", VehiclePerformance.RearGrip, 1.0, "Rear Grip"),
        Number("number.vehicle.performance.steeringlock", VehiclePerformance.SteeringLock, 1.0, "Steering Lock"),
        Number("number.vehicle.performance.handbrake", VehiclePerformance.Handbrake, 1.0, "Handbrake Power"),
        Toggle("toggle.vehicle.performance.aircontrol", VehiclePerformance.AirControl, false, {
            Label = "Air Control",
            Tip = "Steer the vehicle while it is in the air.",
            Keywords = { "air", "control", "jump", "flip" }
        }),
        Toggle("toggle.vehicle.freezeQuestTimers", FreezeQuestTimer.Enabled, false, {
            Label = "Freeze Vehicle Quest Timers",
            Tip = "Prevent timed vehicle objectives from counting down.",
            Keywords = { "quest", "timer", "freeze" }
        })
    })
end

return RegisterAllVehicleOptions
