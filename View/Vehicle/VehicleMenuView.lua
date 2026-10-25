local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Notification = require("UI/Panels/Notification/Notification")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local UIConfig = require("Config/UIConfig")
local VehicleLoader = require("Utils/DataExtractors/VehicleLoader")
local Vehicles = require("Features/Vehicles")
local VehicleListView = require("View/Vehicle/VehicleListView")
local VehicleLightView = require("View/Vehicle/VehicleLightView")
local VehiclePaintView = require("View/Vehicle/VehiclePaintView")

local Speedometer = Vehicles.VehicleSpeedometer
local Performance = Vehicles.VehiclePerformance
local Unlocking = Vehicles.VehicleUnlocking

local s_Faction = { index = 1 }
local s_Factions = nil

local function SaveColor(changed)
    if changed then UIConfig.Save() end
end

local function SpeedometerView()
    Buttons.Toggle("Show Speedometer", Speedometer.Enabled, "Show the analog gauges while driving.")
    Buttons.Toggle("Show RPM Gauge", Speedometer.ShowRPM, "Show the smaller engine RPM gauge.", UIConfig.Save)
    Buttons.Toggle("Use MPH", Speedometer.UseMPH, "Use miles per hour instead of kilometers per hour.")
    Buttons.Toggle("Hide Game Speedometer", Speedometer.HideGameSpeedometer, "Hide the game's own driving HUD speedometer while the analog gauges are on.", UIConfig.Save)
    Buttons.Dropdown("Screen Position", Speedometer.Position, Speedometer.Positions, "Choose where the driving gauges appear.", UIConfig.Save)
    Buttons.Toggle("Automatic Maximum Speed", Speedometer.AutomaticMaxSpeed, "Estimate the dial range from the mounted vehicle's highest gear speed.", UIConfig.Save)

    if Speedometer.AutomaticMaxSpeed.value then
        local detected = Speedometer.DetectedMaxSpeed
        Buttons.OptionExtended("Detected Maximum", "", detected and string.format("%.0f KM/H", detected) or "Manual fallback",
            "The dial range estimated from the mounted vehicle's drivetrain.")
    else
        Buttons.Int("Maximum Speed", Speedometer.MaxSpeed, "Maximum speed shown around the analog dial.", UIConfig.Save)
    end
    Buttons.Float("Gauge Scale", Speedometer.Scale, "Adjust the overall size of both gauges.", UIConfig.Save)

    Buttons.Break("Placement")
    Buttons.Option("How To Move", "Turn on the menu cursor (X by default) while driving, then drag the gauges anywhere on screen.", function() end)
    Buttons.Int("Horizontal Offset", Speedometer.OffsetX, "Move the selected position left or right.", UIConfig.Save)
    Buttons.Int("Vertical Offset", Speedometer.OffsetY, "Move the selected position up or down.", UIConfig.Save)
    Buttons.Option("Reset Gauge Position", "Return the selected preset to its default position.", function()
        Speedometer.OffsetX.value = 0
        Speedometer.OffsetY.value = 0
        UIConfig.Save()
    end)

    Buttons.Break("Gauge Colors")
    SaveColor(Buttons.ColorHex("Active Ring", Speedometer.Colors, "Active", "Filled speed and RPM ring color."))
    SaveColor(Buttons.ColorHex("Needles", Speedometer.Colors, "Needle", "Speed and RPM needle color."))
    SaveColor(Buttons.ColorHex("Dial Text", Speedometer.Colors, "Text", "Tick and gear text color."))
    SaveColor(Buttons.ColorHex("Secondary Text", Speedometer.Colors, "Muted", "Number and unit label color."))
    SaveColor(Buttons.ColorHex("Inactive Ring", Speedometer.Colors, "Ring", "Unfilled gauge ring color."))
end

local SpeedometerMenu = Submenu.Create("Speedometer", SpeedometerView)

local s_PresetName = { value = "", capturing = false }

local function Format(value, pattern)
    return value and string.format(pattern, value) or nil
end

local function Change(stock, tuned, pattern)
    if not stock then return nil end
    if not tuned or math.abs(tuned - stock) < 0.0001 then return string.format(pattern, stock) end
    return string.format(pattern .. "  >  " .. pattern, stock, tuned)
end

local function SubmitPerformanceStats()
    local stats = Performance.GetStats()
    if not stats then return end

    local rows = {}
    for _, row in ipairs({
        { Label = "Top Speed", Value = Change(stats.StockTopSpeed, stats.TopSpeed, "%.0f km/h") },
        { Label = "Torque", Value = Change(stats.StockTorque, stats.Torque, "%.0f Nm") },
        { Label = "Mass", Value = Format(stats.Mass, "%.0f kg") },
        { Label = "Shift Time", Value = Change(stats.StockShift, stats.Shift, "%.2f s") },
        { Label = "Front Grip", Value = Change(stats.StockFrontGrip, stats.FrontGrip, "%.2f") },
        { Label = "Rear Grip", Value = Change(stats.StockRearGrip, stats.RearGrip, "%.2f") },
        { Label = "Steering", Value = Change(stats.StockSteering, stats.Steering, "%.0f°") },
        { Label = "Handbrake", Value = Change(stats.StockHandbrake, stats.Handbrake, "%.0f Nm") }
    }) do
        if row.Value then table.insert(rows, row) end
    end

    SidePanel.SubmitInfo("vehicle-performance", {
        Eyebrow = Performance.Enabled.value and "PERFORMANCE  /  TUNED" or "PERFORMANCE  /  STOCK",
        Title = stats.Name or "Current Vehicle",
        Rows = rows,
        Description = "Values on the right of the arrow are the tuned ones."
    }, { Width = 360 })
end

local function PerformancePresetsView()
    Buttons.Text("Save Current Tuning", s_PresetName, "Name the current tuning and save it as a preset.", function(value)
        Notification.Success("Saved " .. Performance.Presets.Save(value), 2)
        s_PresetName.value = ""
    end)

    local presets = Performance.Presets.List()
    if #presets == 0 then return end

    Buttons.Break("Saved Presets")
    for index, preset in ipairs(presets) do
        Buttons.Option(preset.Name, "Load this tuning preset.", function()
            Notification.Info("Loaded " .. Performance.Presets.Apply(index), 2)
        end)
    end

    Buttons.Break("Delete")
    for index, preset in ipairs(presets) do
        Buttons.OptionExtended(preset.Name, "", "DELETE", "Remove this tuning preset.", function()
            Notification.Info("Deleted " .. Performance.Presets.Delete(index), 2)
        end)
    end
end

local PerformancePresetsMenu = Submenu.Create("Tuning Presets", PerformancePresetsView)

local function PerformanceView()
    Buttons.Submenu("Tuning Presets", PerformancePresetsMenu, "Save and load your own tuning setups.")
    Buttons.Break("")
    Buttons.Toggle("Performance Tuning", Performance.Enabled, "Turn on the tuning below for the vehicle you drive. Turning it off restores stock behavior.")
    Buttons.Option("Reset to Stock", "Set every tuning value back to stock.", Performance.ResetValues)

    Buttons.Break("Engine")
    Buttons.Float("Engine Power", Performance.EnginePower, "Scale the engine's maximum torque.")
    Buttons.Float("Top Speed Bonus", Performance.TopSpeedBonus, "Raise the speed limit above the vehicle's stock top speed.")
    Buttons.Float("Extra Acceleration", Performance.Acceleration, "Extra push while you hold the throttle.")
    Buttons.Float("Gear Shift Speed", Performance.ShiftSpeed, "Shift gears faster.")

    Buttons.Break("Handling")
    Buttons.Float("Front Grip", Performance.FrontGrip, "Front tire friction. Lower it for more understeer.")
    Buttons.Float("Rear Grip", Performance.RearGrip, "Rear tire friction. Lower it below the front for easy drifts.")
    Buttons.Float("Steering Lock", Performance.SteeringLock, "How far the front wheels can turn.")
    Buttons.Float("Downforce", Performance.Downforce, "Push the car into the road as speed builds.")
    Buttons.Toggle("Air Control", Performance.AirControl, "Steer the vehicle while it is in the air.")

    Buttons.Break("Brakes")
    Buttons.Float("Extra Braking", Performance.Braking, "Extra stopping power while you hold the brake.")
    Buttons.Float("Handbrake Power", Performance.Handbrake, "Scale the handbrake's braking torque.")

    SubmitPerformanceStats()
end

local PerformanceMenu = Submenu.Create("Performance", PerformanceView)

local function GetFactions()
    local seen = {}
    local factions = {}
    for _, vehicle in ipairs(VehicleLoader:GetAll()) do
        if vehicle.faction and not seen[vehicle.faction] then
            seen[vehicle.faction] = true
            table.insert(factions, vehicle.faction)
        end
    end
    table.sort(factions)
    return factions
end

local function SelectedFaction()
    return s_Factions[s_Faction.index or 1]
end

local function DespawnLast()
    if Vehicles.VehicleSpawning.DespawnLast() then
        Notification.Success("Last spawned vehicle removed", 2)
    else
        Notification.Info("No EasyTrainer vehicle to remove", 2)
    end
end

local function VehicleView()
    s_Factions = s_Factions or GetFactions()
    Vehicles.VehiclePreview.SetActive(false)

    Buttons.Submenu("Vehicle Spawner", VehicleListView, "Browse and spawn vehicles near the player.", function()
        Vehicles.ViewStates.SpawnerMode = true
    end)
    Buttons.Submenu("Garage Manager", VehicleListView, "Choose which vehicles appear in the player garage.", function()
        Vehicles.ViewStates.SpawnerMode = false
    end)
    Buttons.Submenu("Paint Shop", VehiclePaintView, "Paint any vehicle with any color, with presets, hex input, and live preview.")
    Buttons.Submenu("Vehicle Light Controls", VehicleLightView, "Adjust individual vehicle lights, colors, and strength.")
    Buttons.Submenu("Speedometer", SpeedometerMenu, "Configure the analog speed and RPM gauges.")
    Buttons.Submenu("Performance", PerformanceMenu, "Tune top speed, acceleration, braking, gear shifts, and grip.")

    Buttons.Break("Mounted Vehicle")
    Buttons.Toggle("Invincible Vehicle", Vehicles.VehicleGodMode.Enabled, "Makes the vehicle you drive immune to damage from collisions and attacks.")
    Buttons.Toggle("Auto Repair", Vehicles.VehicleRepair.AutoRepair, "Instantly fixes the vehicle you drive whenever it takes damage: health, dents, glass, and tires. Works without Invincible Vehicle.")
    Buttons.Option("Repair Mounted Vehicle", "Fully repair the vehicle you are currently driving.", Vehicles.VehicleRepair.RepairMounted)
    Buttons.Option("Move to Vehicle Roof", "Unmount and place the player on top of the mounted vehicle.", Vehicles.VehicleMountOnRoof.MountOnRoof)
    Buttons.Option("Despawn Last Spawned Vehicle", "Remove the most recent vehicle spawned by EasyTrainer.", DespawnLast)
    Buttons.Float("Nitrous Boost", Vehicles.VehicleNitro.Multiplier, "Select to enable, left and right adjust the boost strength.")
    Buttons.Bind("Nitrous Key", "NITRO", "Control held to fire the nitrous boost.")
    Buttons.Toggle("RGB Light Fade", Vehicles.VehicleLightFade.Enabled, "Continuously cycle the mounted vehicle's light colors.")
    Buttons.Toggle("Freeze Vehicle Quest Timers", Vehicles.FreezeQuestTimer.Enabled, "Prevent timed vehicle objectives from counting down.")

    Buttons.Break("Fleet Management")
    Buttons.Dropdown("Selected Affiliation", s_Faction, s_Factions, "Choose the faction affected by the affiliation actions.")
    Buttons.Option("Unlock Selected Affiliation", "Unlock every vehicle for the selected affiliation.", function()
        Unlocking.UnlockFaction(SelectedFaction())
    end)
    Buttons.Option("Disable Selected Affiliation", "Remove every vehicle for the selected affiliation.", function()
        Unlocking.DisableFaction(SelectedFaction())
    end)
    Buttons.Option("Unlock Player Vehicles", "Unlock all player-assigned vehicles.", Unlocking.UnlockAllPlayerVehicles)
    Buttons.Option("Disable Player Vehicles", "Disable all player-assigned vehicles.", Unlocking.DisableAllPlayerVehicles)
    Buttons.Option("Unlock Add-On Vehicles", "Unlock all detected add-on vehicles and their variants.", Unlocking.UnlockAllModded)
    Buttons.Option("Disable Add-On Vehicles", "Disable all detected add-on vehicles and their variants.", Unlocking.DisableAllModded)
end

return Submenu.Create("Vehicles", VehicleView)
