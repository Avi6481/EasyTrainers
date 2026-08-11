local UI = require("UI")
local Buttons = UI.Buttons
local Notification = UI.Notification
local VehicleFeatures = require("Features/Vehicles")
local VehicleListView = require("View/Vehicle/VehicleListView")
local VehicleLightView = require("View/Vehicle/VehicleLightView")
local VehicleLoader = require("Utils/DataExtractors/VehicleLoader")
local UIConfig = require("Config/UIConfig")

local Speedometer = VehicleFeatures.VehicleSpeedometer
local VehicleLights = VehicleFeatures.VehicleLightFade
local VehiclePreview = VehicleFeatures.VehiclePreview
local VehicleRepair = VehicleFeatures.VehicleRepair
local VehicleMount = VehicleFeatures.VehicleMountOnRoof
local VehicleMapTimer = VehicleFeatures.FreezeQuestTimer
local VehicleNitro = VehicleFeatures.VehicleNitro
local VehicleUnlocking = VehicleFeatures.VehicleUnlocking
local VehicleSpawning = VehicleFeatures.VehicleSpawning

local function SpeedometerView()
    Buttons.Toggle("Show Speedometer", Speedometer.Enabled, "Show the analog gauges while driving.")
    Buttons.Toggle("Show RPM Gauge", Speedometer.ShowRPM, "Show the smaller engine RPM gauge.", UIConfig.Save)
    Buttons.Toggle("Use MPH", Speedometer.UseMPH, "Use miles per hour instead of kilometers per hour.")
    Buttons.Dropdown("Screen Position", Speedometer.Position, Speedometer.Positions,
        "Choose where the driving gauges appear.", UIConfig.Save)
    Buttons.Toggle("Automatic Maximum Speed", Speedometer.AutomaticMaxSpeed,
        "Use the mounted vehicle's highest configured gear speed when available.", UIConfig.Save)
    if Speedometer.AutomaticMaxSpeed.value then
        local detected = Speedometer.DetectedMaxSpeed
        Buttons.OptionExtended("Detected Maximum", "", detected and string.format("%.0f KM/H", detected) or "Manual fallback",
            "The maximum speed read from the mounted vehicle's drivetrain profile.")
    else
        Buttons.Int("Maximum Speed", Speedometer.MaxSpeed, "Maximum speed shown around the analog dial.", UIConfig.Save)
    end
    Buttons.Float("Gauge Scale", Speedometer.Scale, "Adjust the overall size of both gauges.", UIConfig.Save)
    Buttons.Break("", "Placement Fine Tuning")
    Buttons.Int("Horizontal Offset", Speedometer.OffsetX, "Move the selected position left or right.", UIConfig.Save)
    Buttons.Int("Vertical Offset", Speedometer.OffsetY, "Move the selected position up or down.", UIConfig.Save)
    Buttons.Option("Reset Gauge Position", "Return the selected preset to its default position.", function()
        Speedometer.OffsetX.value = 0
        Speedometer.OffsetY.value = 0
        UIConfig.Save()
    end)
    Buttons.Break("", "Gauge Colors")
    if Buttons.ColorHex("Active Ring", Speedometer.Colors, "Active", "Filled speed and RPM ring color.") then UIConfig.Save() end
    if Buttons.ColorHex("Needles", Speedometer.Colors, "Needle", "Speed and RPM needle color.") then UIConfig.Save() end
    if Buttons.ColorHex("Dial Text", Speedometer.Colors, "Text", "Tick and gear text color.") then UIConfig.Save() end
    if Buttons.ColorHex("Secondary Text", Speedometer.Colors, "Muted", "Number and unit label color.") then UIConfig.Save() end
    if Buttons.ColorHex("Inactive Ring", Speedometer.Colors, "Ring", "Unfilled gauge ring color.") then UIConfig.Save() end
end

local speedometerMenu = { title = "Speedometer", view = SpeedometerView }
local factionRef = { index = 1 }
local factionList

local function GetFactions()
    local seen, result = {}, {}
    for _, vehicle in ipairs(VehicleLoader:GetAll()) do
        if vehicle.faction and not seen[vehicle.faction] then
            seen[vehicle.faction] = true
            table.insert(result, vehicle.faction)
        end
    end
    table.sort(result)
    return result
end

local function VehicleViewFunction()
    factionList = factionList or GetFactions()
    VehiclePreview.SetActive(false)

    Buttons.Submenu("Vehicle Spawner", VehicleListView, "Browse and spawn vehicles near the player.", function()
        VehicleFeatures.VehicleListStates.enableVehicleSpawnerMode = true
    end)
    Buttons.Submenu("Garage Manager", VehicleListView, "Choose which vehicles appear in the player garage.", function()
        VehicleFeatures.VehicleListStates.enableVehicleSpawnerMode = false
    end)
    Buttons.Submenu("Speedometer", speedometerMenu, "Configure the analog speed and RPM gauges.")

    Buttons.Break("", "Mounted Vehicle")
    Buttons.Option("Repair Mounted Vehicle", "Fully repair the vehicle you are currently driving.", VehicleRepair.RepairMounted)
    Buttons.Option("Move to Vehicle Roof", "Unmount and place the player on top of the mounted vehicle.", VehicleMount.MountOnRoof)
    Buttons.Option("Despawn Last Spawned Vehicle", "Remove the most recent vehicle spawned by EasyTrainer.", function()
        if VehicleSpawning.DespawnLast() then
            Notification.Success("Last spawned vehicle removed", 2)
        else
            Notification.Info("No EasyTrainer vehicle to remove", 2)
        end
    end)
    Buttons.Float("Nitrous Boost", VehicleNitro.multiplier,
        "Adjust the forward boost used while holding the nitrous input.")
    Buttons.Toggle("Freeze Vehicle Quest Timers", VehicleMapTimer.toggleFreezeQuestTimer,
        "Prevent timed vehicle objectives from counting down.")
    Buttons.Submenu("Vehicle Light Controls", VehicleLightView,
        "Adjust individual vehicle lights, colors, and strength.")
    Buttons.Toggle("RGB Light Fade", VehicleLights.toggleRGBFade,
        "Continuously cycle the mounted vehicle's light colors.")

    Buttons.Break("", "Fleet Management")
    Buttons.Dropdown("Selected Affiliation", factionRef, factionList,
        "Choose the faction affected by the affiliation actions.")
    Buttons.Option("Unlock Selected Affiliation", "Unlock every vehicle for the selected affiliation.", function()
        VehicleUnlocking.UnlockFaction(factionList[factionRef.index])
    end)
    Buttons.Option("Disable Selected Affiliation", "Remove every vehicle for the selected affiliation.", function()
        VehicleUnlocking.DisableFaction(factionList[factionRef.index])
    end)
    Buttons.Option("Unlock Player Vehicles", "Unlock all player-assigned vehicles.", VehicleUnlocking.UnlockAllPlayerVehicles)
    Buttons.Option("Disable Player Vehicles", "Disable all player-assigned vehicles.", VehicleUnlocking.DisableAllPlayerVehicles)
    Buttons.Option("Unlock Add-On Vehicles", "Unlock all detected add-on vehicles.", VehicleUnlocking.UnlockAllModded)
    Buttons.Option("Disable Add-On Vehicles", "Disable all detected add-on vehicles.", VehicleUnlocking.DisableAllModded)
end

return { title = "Vehicles", view = VehicleViewFunction }
