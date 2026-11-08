local Garage = require("Features/Vehicles/Garage")

local VehicleInfo = {}

local s_Docs = setmetatable({}, { __mode = "k" })

local function Row(doc, key, value)
    if value == nil or value == "" then return end
    table.insert(doc, { Kind = "Row", Label = L("vehicles.info." .. key), Value = tostring(value) })
end

local function Build(vehicle, unlocked)
    local doc = {
        { Kind = "Eyebrow", Text = vehicle.Manufacturer },
        { Kind = "Title", Text = vehicle.Name },
        { Kind = "Separator" }
    }
    local icon = vehicle.Icon or (vehicle.Parent and vehicle.Parent.Icon)
    if icon then table.insert(doc, { Kind = "Image", Image = icon }) end

    Row(doc, "class", vehicle.Class)
    Row(doc, "affiliation", vehicle.Faction)
    Row(doc, "year", vehicle.Year)
    Row(doc, "horsepower", vehicle.Horsepower and string.format("%d", vehicle.Horsepower))
    Row(doc, "mass", vehicle.Mass and string.format("%d kg", vehicle.Mass))
    Row(doc, "drive", vehicle.Drive)
    Row(doc, "source", L(vehicle.AddOn and "vehicles.info.addon" or "vehicles.info.basegame"))
    table.insert(doc, {
        Kind = "Row",
        Label = L("vehicles.info.paint"),
        Value = L(vehicle.Paintable and "vehicles.info.paintable" or "vehicles.info.notpaintable"),
        Tone = vehicle.Paintable and "Text" or "Soft"
    })
    table.insert(doc, {
        Kind = "Row",
        Label = L("vehicles.info.garage"),
        Value = L(unlocked and "vehicles.info.ingarage" or "vehicles.info.notingarage"),
        Tone = unlocked and "Strong" or "Soft"
    })

    if vehicle.Description then table.insert(doc, { Kind = "Text", Text = vehicle.Description, Tone = "Soft" }) end
    table.insert(doc, { Kind = "Text", Text = vehicle.Id, Tone = "Dim" })
    return doc
end

function VehicleInfo.Get(vehicle)
    local unlocked = Garage.IsUnlocked(vehicle)
    local cached = s_Docs[vehicle]
    if cached and cached.Unlocked == unlocked then return cached.Doc end

    cached = { Unlocked = unlocked, Doc = Build(vehicle, unlocked) }
    s_Docs[vehicle] = cached
    return cached.Doc
end

return VehicleInfo
