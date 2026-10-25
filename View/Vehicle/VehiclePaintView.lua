local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Notification = require("UI/Panels/Notification/Notification")
local VehiclePaint = require("Features/Vehicles/VehiclePaint")

local s_PrimaryHex = { value = "", capturing = false }
local s_SecondaryHex = { value = "", capturing = false }
local s_SaveName = { value = "", capturing = false }

local function Report(ok, message, success)
    if ok then
        if success then Notification.Success(success, 2) end
    else
        Notification.Error(message or "Something went wrong", 3)
    end
end

local function ShowSwatches(data, title, primary, secondary)
    if not data or not data.Visible or not (data.Selected or data.Hovered) then return end
    SidePanel.SubmitSwatches("paint-swatch", {
        Eyebrow = "PAINT PREVIEW",
        Title = title,
        Swatches = {
            { Label = "Primary", Value = VehiclePaint.ToHex(primary), Color = VehiclePaint.ToU32(primary) },
            { Label = "Secondary", Value = VehiclePaint.ToHex(secondary), Color = VehiclePaint.ToU32(secondary) }
        }
    })
end

local function PaintEntry(entry, tip)
    local primary, secondary = VehiclePaint.ColorOf(entry.Primary), VehiclePaint.ColorOf(entry.Secondary)
    local _, data = Buttons.OptionExtended(entry.Name, "", VehiclePaint.ToHex(primary), tip, function()
        local ok, message = VehiclePaint.ApplyPreset(entry)
        Report(ok, message, "Painted " .. entry.Name)
    end)
    ShowSwatches(data, entry.Name, primary, secondary)
end

local function HexField(label, color, ref)
    ref.value = VehiclePaint.ToHex(color)
    Buttons.Text(label, ref, "Type a hex color such as #FF0055 or F05.", function(value)
        if not VehiclePaint.FromHex(color, value) then Notification.Error("That is not a valid hex color", 2) end
    end)
end

local function PresetsView()
    for _, preset in ipairs(VehiclePaint.Presets) do
        PaintEntry(preset, "Paint the current vehicle with this color pair.")
    end
end

local PresetsMenu = Submenu.Create("Paint Presets", PresetsView)

local function DeleteSavedView()
    local saved = VehiclePaint.GetSaved()
    if #saved == 0 then
        Buttons.Option("No Saved Colors", "Save a color pair first.", function() end)
        return
    end

    for index, entry in ipairs(saved) do
        Buttons.OptionExtended(entry.Name, "", "DELETE", "Remove this saved color pair.", function()
            local name = VehiclePaint.DeleteSaved(index)
            if name then Notification.Info("Deleted " .. name, 2) end
        end)
    end
end

local DeleteSavedMenu = Submenu.Create("Delete Saved Colors", DeleteSavedView)

local function SavedColorsView()
    Buttons.Submenu("Delete Saved Colors", DeleteSavedMenu, "Remove color pairs you no longer want.")
    Buttons.Break("")
    Buttons.Text("Save Current Colors", s_SaveName, "Name the current primary and secondary colors and save them for later.", function(value)
        local name = VehiclePaint.SaveCurrent(value)
        s_SaveName.value = ""
        Notification.Success("Saved " .. name, 2)
    end)

    local saved = VehiclePaint.GetSaved()
    if #saved == 0 then return end

    Buttons.Break("Saved Colors")
    for _, entry in ipairs(saved) do
        PaintEntry(entry, "Paint the current vehicle with this saved color pair.")
    end
end

local SavedColorsMenu = Submenu.Create("Saved Colors", SavedColorsView)

local function PaintView()
    Buttons.Submenu("Paint Presets", PresetsMenu, "Pick from a set of Night City color pairs.")
    Buttons.Submenu("Saved Colors", SavedColorsMenu, "Save your own color pairs and paint with them later.")

    Buttons.Break("")
    Buttons.Color("Primary Color", VehiclePaint.Primary, "Main body color. Changes paint the current vehicle right away.")
    HexField("Primary Hex", VehiclePaint.Primary, s_PrimaryHex)
    Buttons.Color("Secondary Color", VehiclePaint.Secondary, "Accent color for trims and secondary panels.")
    HexField("Secondary Hex", VehiclePaint.Secondary, s_SecondaryHex)

    Buttons.Break("Paint Job")
    Buttons.Option("Apply Paint", "Paint the current vehicle using the game's CrystalCoat system.", function()
        local ok, message = VehiclePaint.Apply()
        Report(ok, message, "Paint applied")
    end)
    Buttons.Option("Swap Colors", "Swap the primary and secondary colors.", VehiclePaint.Swap)
    Buttons.Option("Randomize", "Roll a random color pair.", VehiclePaint.Randomize)
    Buttons.Option("Restore Factory Paint", "Remove the custom paint from the current vehicle.", function()
        local ok, message = VehiclePaint.Reset()
        Report(ok, message, "Factory paint restored")
    end)

    Buttons.Break("Settings")
    Buttons.Toggle("CrystalCoat on Any Vehicle (Beta)", VehiclePaint.AllVehicles, "Beta. Unlocks CrystalCoat paint for every vehicle, but some vehicles have no paint layer and will not change color. Leave it on to keep paint on cars that normally lack CrystalCoat.")
    Buttons.Toggle("Paint Rims", VehiclePaint.AffectRims, "Also recolor the wheel rims when the vehicle supports it.")

    VehiclePaint.ApplyEdits()
end

return Submenu.Create("Paint Shop", PaintView)
