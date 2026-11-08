local GameText = require("Utils/GameText")
local Logger = require("Core/Logger")

local Catalog = {
    Loaded = false,
    Injected = false,
    Version = 0,
    All = {},
    Browsable = {},
    ById = {},
    ByKey = {},
    Original = {}
}

Catalog.CLASSES = {
    "Hypercars", "Sports", "Motorcycles", "Executive", "Economy",
    "SUV & Off-Road", "Utility & Pickups", "Police & Emergency", "Heavy & Special", "Other"
}

local GARAGE_LIST = "Vehicle.vehicle_list.list"
local ICONS = "Assets/Icons/VehicleIcons"
local NO_AFFILIATION = "No Affiliation"
local UNLISTED = "Unlisted"

local FACTIONS = {
    { "maxtac", "Maxtac" },
    { "tyger", "Tyger Claws" },
    { "maelstrom", "Maelstrom" },
    { "voodoo", "Voodoo Boys" },
    { "netwatch", "NetWatch" },
    { "militech", "Militech" },
    { "barghest", "Barghest" },
    { "valentino", "Valentinos" },
    { "scavenger", "Scavs" },
    { "sixth", "Sixth Street" },
    { "arasaka", "Arasaka" },
    { "animal", "Animals" },
    { "nomad", "Nomads" },
    { "ncpd", "Police" },
    { "mox", "Moxes" },
    { "player", "Player" }
}

local function Call(callback)
    local ok, result = pcall(callback)
    if ok then return result end
    return nil
end

local function Key(id)
    return tostring(id.hash) .. ":" .. tostring(id.length)
end

Catalog.Key = Key

local function TypeName(record)
    local kind = Call(function() return record:Type() end)
    return kind and Call(function() return kind:EnumName() end) or nil
end

local function Has(text, ...)
    for _, word in ipairs({ ... }) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function Class(record, id, name, tags)
    local lower = id:lower()
    local all = table.concat(tags, " "):lower() .. " " .. lower .. " " .. name:lower()
    local kind = TypeName(record)

    if Has(lower, "police", "border", "maxtac") then return "Police & Emergency" end
    if kind == "Bike" or Has(all, "motorcycle", "sportbike", "motorbike") or Has(lower, "_bike") then return "Motorcycles" end
    if kind == "Panzer" or Has(lower, "basilisk", "coach", "missile", "bmf", "panzer") then return "Heavy & Special" end
    if Has(lower, "caliburn", "aerondight", "outlaw") then return "Hypercars" end
    if Has(lower, "standard25", "pickup", "columbus", "utility", "truck", "van") then return "Utility & Pickups" end
    if Has(lower, "alvarado", "cortes", "deleon", "delamain", "thrax") then return "Executive" end
    if Has(lower, "standard3", "mackinaw", "merrimac", "emperor") or Has(all, "offroad", "nomad") then return "SUV & Off-Road" end
    if Has(lower, "sport1", "sport2") or all:match("%f[%a]sport%f[%A]") then return "Sports" end
    if Has(lower, "standard1", "standard2", "maimai", "galena", "hella", "supron") then return "Economy" end
    if all:match("%f[%a]utility%d*%f[%A]") then return "Utility & Pickups" end
    return "Other"
end

local function Faction(record, id)
    local affiliation = Call(function() return record:Affiliation() end)
    local key = affiliation and Call(function() return affiliation:LocalizedName() end)
    local name = key and GameText.FromName(key, nil)
    if name and name ~= "" and name ~= NO_AFFILIATION and name ~= "Label Not Found" then return name end

    local lower = id:lower()
    for _, pattern in ipairs(FACTIONS) do
        if lower:find(pattern[1], 1, true) then return pattern[2] end
    end
    return NO_AFFILIATION
end

local function Manufacturer(record)
    local manufacturer = Call(function() return record:Manufacturer() end)
    local name = manufacturer and Call(function() return manufacturer:EnumName() end)
    if not name or name == "" then return UNLISTED end
    return name
end

local function Name(record)
    local key = Call(function() return record:DisplayName() end)
    local name = key and GameText.FromName(key, nil)
    if not name or name == "" or name == "Label Not Found" then return nil end
    return name
end

local function Tags(record)
    local tags = {}
    for _, tag in ipairs(Call(function() return record:Tags() end) or {}) do
        local value = Call(function() return tag.value end)
        if value then table.insert(tags, value) end
    end
    return tags
end

local s_Icons = nil
local s_Listed = nil

local function Icons()
    if s_Icons then return s_Icons end

    local ok, manifest = pcall(require, ICONS)
    s_Icons = { Sheets = {}, Parts = {} }
    if ok and type(manifest) == "table" then s_Icons = manifest end
    return s_Icons
end

local function Icon(record)
    local icon = Call(function() return record:Icon() end)
    local part = icon and Call(function() return Game.NameToString(icon:AtlasPartName()) end)
    local entry = part and Icons().Parts[part]
    if not entry then return nil end

    return {
        Sheet = Icons().Sheets[entry[1]],
        U0 = entry[2],
        V0 = entry[3],
        U1 = entry[4],
        V1 = entry[5],
        Width = entry[6],
        Height = entry[7]
    }
end

local function Lore(record)
    local ui = Call(function() return record:VehicleUIData() end)
    if not ui then return {} end

    local year = Call(function() return ui:ProductionYear() end)
    return {
        Description = GameText.Get(Call(function() return ui:Info() end), nil),
        Drive = GameText.Get(Call(function() return ui:DriveLayout() end), nil),
        Horsepower = tonumber(Call(function() return ui:Horsepower() end)),
        Mass = tonumber(Call(function() return ui:Mass() end)),
        Year = year and tostring(year) or nil
    }
end

local function Vanilla(id)
    return id:match("^Vehicle%.v_") ~= nil or id:match("^Vehicle%.vcd") ~= nil
end

local function Aerial(lower)
    return lower:find("_av_", 1, true) ~= nil or lower:match("^vehicle%.av_") ~= nil or lower:match("_av$") ~= nil
end

local function Dealer(id)
    local price = TweakDB:GetFlat(id .. ".dealerPrice")
    local variants = TweakDB:GetFlat(id .. ".dealerVariants")
    local part = TweakDB:GetFlat(id .. ".dealerPartName")
    return (type(price) == "number" and price > 0)
        or (type(variants) == "table" and #variants > 0)
        or (type(part) == "string" and part ~= "")
end

local function DealerVariants(id)
    local variants = {}
    local data = TweakDB:GetFlat(id .. ".dealerVariants")
    for _, value in ipairs(type(data) == "table" and data or {}) do
        local variant = type(value) == "string" and value or Call(function() return value.value end)
        if variant then table.insert(variants, variant) end
    end
    return variants
end

local function RecordId(record)
    return Call(function() return record:GetID().value end)
end

local function ReadGarageList()
    local list = TweakDB:GetFlat(TweakDBID.new(GARAGE_LIST))
    local listed = {}
    local original = {}
    for _, id in ipairs(type(list) == "table" and list or {}) do
        local value = Call(function() return id.value end)
        if value then listed[value] = true end
        original[Key(id)] = true
    end
    return type(list) == "table" and list or nil, listed, original
end

local function Build(id, record, name, addOn)
    local tags = Tags(record)
    local lore = Lore(record)
    local manufacturer = Manufacturer(record)
    local faction = Faction(record, id)

    local vehicle = {
        Id = id,
        Key = Key(TweakDBID.new(id)),
        Name = name,
        Manufacturer = manufacturer,
        Class = Class(record, id, name, tags),
        Faction = faction,
        Year = lore.Year,
        Horsepower = lore.Horsepower,
        Mass = lore.Mass,
        Drive = lore.Drive,
        Description = lore.Description,
        AddOn = addOn,
        Icon = Icon(record),
        Paintable = Call(function() return record:HasVisualCustomization() end) == true,
        Player = faction == "Player" or id:lower():find("_player", 1, true) ~= nil,
        Variants = {}
    }
    vehicle.Search = table.concat({ name, manufacturer, id }, " "):lower()
    return vehicle
end

local function Wanted(id, record, listed)
    if Catalog.ById[id] or Aerial(id:lower()) then return false end

    if Vanilla(id) then
        if Manufacturer(record) == UNLISTED then return false end
        local year = Lore(record).Year
        return not (year and year:lower():find("lockey", 1, true))
    end
    return Dealer(id) or listed[id] == true
end

local function Add(vehicle)
    table.insert(Catalog.All, vehicle)
    Catalog.ById[vehicle.Id] = vehicle
    Catalog.ByKey[vehicle.Key] = vehicle
end

local function AddVariants(vehicle)
    for _, variantId in ipairs(DealerVariants(vehicle.Id)) do
        local record = not Catalog.ById[variantId] and TweakDB:GetRecord(variantId)
        local name = record and Name(record)
        if name then
            local variant = Build(variantId, record, name, true)
            variant.Parent = vehicle
            table.insert(vehicle.Variants, variant)
            Add(variant)
        end
    end
end

local function Inject(list)
    if not list then return 0 end

    local present = {}
    for _, id in ipairs(list) do
        local value = Call(function() return id.value end)
        if value then present[value] = true end
    end

    local added = 0
    for _, vehicle in ipairs(Catalog.All) do
        if not present[vehicle.Id] then
            table.insert(list, TweakDBID.new(vehicle.Id))
            present[vehicle.Id] = true
            added = added + 1
        end
    end
    if added > 0 then TweakDB:SetFlat(TweakDBID.new(GARAGE_LIST), list) end
    return added
end

local function ByName(first, second)
    return first.Name:lower() < second.Name:lower()
end

function Catalog.Load()
    Catalog.Loaded = true
    Catalog.All = {}
    Catalog.Browsable = {}
    Catalog.ById = {}
    Catalog.ByKey = {}

    local list, listed, original = ReadGarageList()
    if not s_Listed then
        s_Listed = listed
        Catalog.Original = original
    end
    listed = s_Listed
    for _, record in ipairs(TweakDB:GetRecords("gamedataVehicle_Record") or {}) do
        local id = RecordId(record)
        local name = id and Wanted(id, record, listed) and Name(record)
        if name then
            local vehicle = Build(id, record, name, not Vanilla(id))
            Add(vehicle)
            table.insert(Catalog.Browsable, vehicle)
            if vehicle.AddOn then AddVariants(vehicle) end
        end
    end

    table.sort(Catalog.Browsable, ByName)
    local injected = Inject(list)
    Catalog.Injected = Catalog.Injected or injected > 0
    Catalog.Version = Catalog.Version + 1

    local addOns = 0
    for _, vehicle in ipairs(Catalog.Browsable) do
        if vehicle.AddOn then addOns = addOns + 1 end
    end
    Logger.Log(string.format("Vehicles: %d vehicles (%d add-on), %d in total with variants, %d added to the garage list",
        #Catalog.Browsable, addOns, #Catalog.All, injected))
end

function Catalog.IsOriginal(record)
    return Catalog.Original[Key(record)] == true
end

return Catalog
