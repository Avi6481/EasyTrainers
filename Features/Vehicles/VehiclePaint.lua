local Logger = require("Core/Logger")
local Lifecycle = require("Core/Lifecycle")
local JsonHelper = require("Core/JsonHelper")
local Vehicle = require("Utils/Vehicle")

local VehiclePaint = {}

VehiclePaint.AllVehicles = { value = false }
VehiclePaint.AffectRims = { value = false }
VehiclePaint.Primary = { Red = 226, Green = 44, Blue = 92, Alpha = 255 }
VehiclePaint.Secondary = { Red = 20, Green = 20, Blue = 24, Alpha = 255 }

VehiclePaint.Presets = {
    { Name = "Arasaka Red", Primary = { 190, 20, 30 }, Secondary = { 15, 15, 15 } },
    { Name = "Night City Neon", Primary = { 0, 240, 255 }, Secondary = { 255, 0, 170 } },
    { Name = "Samurai Chrome", Primary = { 210, 214, 220 }, Secondary = { 200, 30, 40 } },
    { Name = "Militech Olive", Primary = { 92, 98, 64 }, Secondary = { 40, 40, 36 } },
    { Name = "Kiroshi Gold", Primary = { 230, 180, 60 }, Secondary = { 25, 22, 18 } },
    { Name = "Netrunner Violet", Primary = { 120, 40, 220 }, Secondary = { 10, 10, 30 } },
    { Name = "Afterlife Black", Primary = { 12, 12, 14 }, Secondary = { 230, 210, 40 } },
    { Name = "Pacifica Teal", Primary = { 20, 160, 150 }, Secondary = { 240, 240, 235 } },
    { Name = "Valentino Pink", Primary = { 255, 105, 180 }, Secondary = { 255, 215, 0 } },
    { Name = "Nomad Sand", Primary = { 196, 160, 110 }, Secondary = { 90, 60, 40 } }
}

local ALL_VEHICLES_FACT = "vvc_visual_customization_for_all_vehicles"
local SAVED_PATH = "Config/JSON/PaintColors.json"
local EDIT_APPLY_DELAY = 0.4

local s_FactApplied = false
local s_Synced = false
local s_Saved = nil
local s_SeenKey = nil
local s_EditedAt = nil

local function SetFact(value)
    local quests = Game.GetQuestsSystem()
    if quests then quests:SetFactStr(ALL_VEHICLES_FACT, value) end
end

local function Clamp(value)
    return math.max(0, math.min(255, math.floor((tonumber(value) or 0) + 0.5)))
end

function VehiclePaint.SetColor(target, red, green, blue)
    target.Red, target.Green, target.Blue, target.Alpha = Clamp(red), Clamp(green), Clamp(blue), 255
end

function VehiclePaint.ToHex(color)
    return string.format("#%02X%02X%02X", Clamp(color.Red), Clamp(color.Green), Clamp(color.Blue))
end

function VehiclePaint.ToU32(color)
    return ImGui.ColorConvertFloat4ToU32({ Clamp(color.Red) / 255, Clamp(color.Green) / 255, Clamp(color.Blue) / 255, 1 })
end

function VehiclePaint.FromHex(target, text)
    local hex = tostring(text or ""):gsub("^%s*#?", ""):gsub("%s+$", "")
    if #hex == 3 then hex = hex:gsub("(%x)", "%1%1") end
    if not hex:match("^%x%x%x%x%x%x$") then return false end

    VehiclePaint.SetColor(target, tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
    return true
end

function VehiclePaint.ColorOf(values)
    return { Red = values[1], Green = values[2], Blue = values[3], Alpha = 255 }
end

function VehiclePaint.LoadPreset(preset)
    VehiclePaint.SetColor(VehiclePaint.Primary, preset.Primary[1], preset.Primary[2], preset.Primary[3])
    VehiclePaint.SetColor(VehiclePaint.Secondary, preset.Secondary[1], preset.Secondary[2], preset.Secondary[3])
end

function VehiclePaint.Randomize()
    VehiclePaint.SetColor(VehiclePaint.Primary, math.random(0, 255), math.random(0, 255), math.random(0, 255))
    VehiclePaint.SetColor(VehiclePaint.Secondary, math.random(0, 255), math.random(0, 255), math.random(0, 255))
end

function VehiclePaint.Swap()
    local primary = VehiclePaint.Primary
    local red, green, blue = primary.Red, primary.Green, primary.Blue
    VehiclePaint.SetColor(primary, VehiclePaint.Secondary.Red, VehiclePaint.Secondary.Green, VehiclePaint.Secondary.Blue)
    VehiclePaint.SetColor(VehiclePaint.Secondary, red, green, blue)
end

local function BuildTemplate()
    local data = GenericTemplatePersistentData.new()
    data.primaryColorDefined = true
    data.primaryColorR = Clamp(VehiclePaint.Primary.Red)
    data.primaryColorG = Clamp(VehiclePaint.Primary.Green)
    data.primaryColorB = Clamp(VehiclePaint.Primary.Blue)
    data.secondaryColorDefined = true
    data.secondaryColorR = Clamp(VehiclePaint.Secondary.Red)
    data.secondaryColorG = Clamp(VehiclePaint.Secondary.Green)
    data.secondaryColorB = Clamp(VehiclePaint.Secondary.Blue)

    local template = VehicleVisualCustomizationTemplate.new()
    template.hasUniqueTemplate = false
    template.genericData = data
    return template
end

local function IsPaintAllowed(vehicle)
    local ok, allowed = pcall(function() return vehicle:GetVehicleComponent():GetIsVehicleVisualCustomizationEnabled() end)
    return ok and allowed
end

local function SendToVehicle(vehicle, template, reset)
    local event = NewVehicleVisualCustomizationEvent.new()
    event.template = template
    event.reset = reset
    vehicle:QueueEvent(event)
end

local function MountedPaintable()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then return nil, "Get in a vehicle first" end
    if not IsPaintAllowed(vehicle) then return nil, "Turn on CrystalCoat on Any Vehicle to paint this car" end
    return vehicle
end

function VehiclePaint.Apply()
    local vehicle, message = MountedPaintable()
    if not vehicle then return false, message end

    local ok, err = pcall(function()
        vehicle:GetVehiclePS():SetVehicleVisualCustomizationnBlockedByDamage(false)
        SendToVehicle(vehicle, BuildTemplate(), false)
    end)

    if not ok then
        Logger.Log("VehiclePaint: apply failed (" .. tostring(err) .. ")")
        return false, "The game refused the paint job"
    end
    return true
end

local function ColorKey()
    return VehiclePaint.ToHex(VehiclePaint.Primary) .. VehiclePaint.ToHex(VehiclePaint.Secondary)
end

function VehiclePaint.ApplyPreset(preset)
    VehiclePaint.LoadPreset(preset)
    s_SeenKey, s_EditedAt = ColorKey(), nil
    return VehiclePaint.Apply()
end

function VehiclePaint.ApplyEdits()
    local key = ColorKey()
    if key ~= s_SeenKey then
        if s_SeenKey then s_EditedAt = os.clock() end
        s_SeenKey = key
    end

    if not s_EditedAt or os.clock() - s_EditedAt < EDIT_APPLY_DELAY then return end
    s_EditedAt = nil
    VehiclePaint.Apply()
end

function VehiclePaint.Reset()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then return false, "Get in a vehicle first" end

    local ok = pcall(SendToVehicle, vehicle, VehicleVisualCustomizationTemplate.new(), true)
    return ok, ok and nil or "Could not reset the paint"
end

local function LoadSaved()
    if s_Saved then return s_Saved end
    local data = JsonHelper.LoadOrCreate(SAVED_PATH, { Saved = {} })
    s_Saved = type(data) == "table" and type(data.Saved) == "table" and data.Saved or {}
    return s_Saved
end

local function WriteSaved()
    JsonHelper.Write(SAVED_PATH, { Saved = LoadSaved() })
end

function VehiclePaint.GetSaved()
    return LoadSaved()
end

function VehiclePaint.SaveCurrent(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = VehiclePaint.ToHex(VehiclePaint.Primary) .. " / " .. VehiclePaint.ToHex(VehiclePaint.Secondary) end

    local primary, secondary = VehiclePaint.Primary, VehiclePaint.Secondary
    table.insert(LoadSaved(), {
        Name = name,
        Primary = { primary.Red, primary.Green, primary.Blue },
        Secondary = { secondary.Red, secondary.Green, secondary.Blue }
    })
    WriteSaved()
    return name
end

function VehiclePaint.DeleteSaved(index)
    local saved = LoadSaved()
    if not saved[index] then return nil end
    local removed = table.remove(saved, index)
    WriteSaved()
    return removed.Name
end

function VehiclePaint.Tick()
    local wanted = VehiclePaint.AllVehicles.value
    if s_Synced and wanted == s_FactApplied then return end
    if not Game.GetPlayer() then return end

    SetFact(wanted and 1 or 0)
    s_FactApplied = wanted
    s_Synced = true
end

Lifecycle.Register("VehiclePaint", {
    OnSessionEnd = function() s_Synced = false end
})

return VehiclePaint
