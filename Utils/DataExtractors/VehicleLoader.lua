local Logger = require("Core/Logger")
local DataUtils = require("Utils/DataExtractors/DataUtils")

local VehicleLoader = {
    vehicles = {},
    indexById = {}
}

local LABEL_NOT_FOUND = "Label Not Found"

local FACTION_PATTERNS = {
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

local function GetTypeName(record)
    local typeRecord = DataUtils.SafeCall(function() return record:Type() end)
    return typeRecord and DataUtils.SafeCall(function() return typeRecord:EnumName() end) or nil
end

local function InferCategory(record, tags, id, displayName)
    local idLower = (id or ""):lower()
    local all = table.concat(tags or {}, " "):lower() .. " " .. idLower .. " " .. (displayName or ""):lower()
    local typeName = GetTypeName(record)

    if idLower:find("police") or idLower:find("border") or idLower:find("maxtac") then return "Police & Emergency" end
    if typeName == "Bike" or all:find("motorcycle", 1, true) or all:find("sportbike", 1, true)
        or all:find("motorbike", 1, true) or idLower:find("_bike") then
        return "Motorcycles"
    end
    if typeName == "Panzer" or idLower:find("basilisk") or idLower:find("coach") or idLower:find("missile")
        or idLower:find("bmf") or idLower:find("panzer") then
        return "Heavy & Special"
    end

    if idLower:find("caliburn") or idLower:find("aerondight") or idLower:find("outlaw") then return "Hypercars" end
    if idLower:find("standard25") or idLower:find("pickup") or idLower:find("columbus")
        or idLower:find("utility") or idLower:find("truck") or idLower:find("van") then
        return "Utility & Pickups"
    end
    if idLower:find("alvarado") or idLower:find("cortes") or idLower:find("deleon")
        or idLower:find("delamain") or idLower:find("thrax") then
        return "Executive"
    end
    if idLower:find("standard3") or idLower:find("mackinaw") or idLower:find("merrimac")
        or idLower:find("emperor") or all:find("offroad", 1, true) or all:find("nomad", 1, true) then
        return "SUV & Off-Road"
    end
    if idLower:find("sport1") or idLower:find("sport2") or all:match("%f[%a]sport%f[%A]") then return "Sports" end
    if idLower:find("standard1") or idLower:find("standard2") or idLower:find("maimai")
        or idLower:find("galena") or idLower:find("hella") or idLower:find("supron") then
        return "Economy"
    end
    if all:match("%f[%a]utility%d*%f[%A]") then return "Utility & Pickups" end

    return "Other"
end

local function LocalizedOrNil(key, localize)
    if not key then return nil end
    local text = localize(key)
    if not text or text == LABEL_NOT_FOUND then return nil end
    return DataUtils.EscapeString(text)
end

local function InferFaction(record, id)
    local affiliation = DataUtils.SafeCall(function() return record:Affiliation() end)
    local key = affiliation and DataUtils.SafeCall(function() return affiliation:LocalizedName() end) or nil
    local faction = LocalizedOrNil(key, Game.GetLocalizedTextByKey)
    if faction and faction ~= "No Affiliation" then return faction end

    local idLower = id:lower()
    for _, pattern in ipairs(FACTION_PATTERNS) do
        if idLower:find(pattern[1], 1, true) then return pattern[2] end
    end
    return "No Affiliation"
end

local function GetLore(record)
    local lore = { description = "No Description Available" }
    local ui = DataUtils.SafeCall(function() return record:VehicleUIData() end)
    if not ui then return lore end

    lore.description = LocalizedOrNil(DataUtils.SafeCall(function() return ui:Info() end), Game.GetLocalizedText) or lore.description
    lore.driveLayout = LocalizedOrNil(DataUtils.SafeCall(function() return ui:DriveLayout() end), Game.GetLocalizedText)
    lore.horsepower = tonumber(DataUtils.SafeCall(function() return ui:Horsepower() end))
    lore.mass = tonumber(DataUtils.SafeCall(function() return ui:Mass() end))

    local year = DataUtils.SafeCall(function() return ui:ProductionYear() end)
    if year then lore.productionYear = tostring(year) end

    return lore
end

local function GetManufacturer(record)
    local manufacturer = DataUtils.SafeCall(function() return record:Manufacturer() end)
    local name = manufacturer and DataUtils.SafeCall(function() return manufacturer:EnumName() end) or nil
    if not name or name == "" then return "Unlisted" end
    return DataUtils.EscapeString(name)
end

local function BuildVehicle(id, record, displayName, tags, isModded, variants)
    local lore = GetLore(record)
    return {
        id = id,
        displayName = displayName,
        manufacturer = GetManufacturer(record),
        category = InferCategory(record, tags, id, displayName),
        faction = InferFaction(record, id),
        tags = tags,
        description = lore.description,
        productionYear = lore.productionYear,
        horsepower = lore.horsepower,
        mass = lore.mass,
        driveLayout = lore.driveLayout,
        variants = variants or {},
        isModded = isModded,
        source = isModded and "Add-On" or "Base Game"
    }
end

function VehicleLoader:AddVehicleToList(id)
    local listID = TweakDBID.new("Vehicle.vehicle_list.list")
    local list = TweakDB:GetFlat(listID)
    if type(list) ~= "table" then
        Logger.Log("VehicleLoader: failed to read vehicle list")
        return false
    end

    for _, existing in ipairs(list) do
        if existing.value == id then return false end
    end

    table.insert(list, TweakDBID.new(id))
    if not TweakDB:SetFlat(listID, list) then
        Logger.Log("VehicleLoader: failed to update vehicle list")
        return false
    end
    return true
end

-- Function taken from Make All Vehicles Unlockable - With TwinTone Fix Created by TheManualEnhancer
function VehicleLoader:HandleTwinToneScan(this, wrappedMethod)
    local scanned = this.scannedObject
    if not scanned or not scanned:IsVehicle() or not scanned:GetRecord() then return wrappedMethod() end

    local id = DataUtils.SafeCall(function() return scanned:GetRecord():GetID().value end)
        or DataUtils.SafeCall(function() return scanned:GetRecord():GetRecordID().value end)

    local vehicleSystem = Game.GetVehicleSystem()
    if id and vehicleSystem and not vehicleSystem:IsVehiclePlayerUnlocked(TweakDBID.new(id)) then
        this.twintoneAvailable = true
        return true
    end
    return wrappedMethod()
end

function VehicleLoader:GetVirtualDealerVariants(id)
    local data = TweakDB:GetFlat(id .. ".dealerVariants")
    if type(data) ~= "table" then return {} end

    local variants = {}
    for _, value in ipairs(data) do
        if type(value) == "string" then
            table.insert(variants, value)
        elseif (type(value) == "userdata" or type(value) == "table") and value.value then
            table.insert(variants, value.value)
        elseif type(value) == "table" and tostring(value):find("Vehicle%.") then
            table.insert(variants, tostring(value))
        end
    end
    return variants
end

function VehicleLoader:IsVirtualDealerVehicle(id)
    if not id then return false end

    local price = TweakDB:GetFlat(id .. ".dealerPrice")
    local variants = TweakDB:GetFlat(id .. ".dealerVariants")
    local partName = TweakDB:GetFlat(id .. ".dealerPartName")

    return (type(price) == "number" and price > 0)
        or (type(variants) == "table" and #variants > 0)
        or (type(partName) == "string" and partName ~= "")
end

function VehicleLoader:LoadVariantRecords(variants)
    for _, variantID in ipairs(variants) do
        local record = not self.indexById[variantID] and TweakDB:GetRecord(variantID) or nil
        if record then
            local vehicle = BuildVehicle(variantID, record, DataUtils.GetDisplayName(record), DataUtils.GetTags(record), true)
            table.insert(self.vehicles, vehicle)
            self.indexById[variantID] = vehicle
        end
    end
end

local function IsAerialVehicle(idLower)
    return idLower:find("_av_", 1, true) or idLower:match("^vehicle%.av_") or idLower:match("_av$")
end

function VehicleLoader:ShouldLoad(id, record)
    if not id or self.indexById[id] then return false end

    local isVanilla = id:match("^Vehicle%.v_") ~= nil or id:match("^Vehicle%.vcd") ~= nil
    local isDealer = self:IsVirtualDealerVehicle(id)
    if not isVanilla and not isDealer then return false end
    if IsAerialVehicle(id:lower()) then return false end

    if not isVanilla then return true end

    if GetManufacturer(record) == "Unlisted" or DataUtils.GetDisplayName(record) == "Unknown" then return false end
    local lore = GetLore(record)
    return not (lore.productionYear and lore.productionYear:lower():find("lockey", 1, true))
end

function VehicleLoader:LoadAll()
    self.vehicles = {}
    self.indexById = {}

    local records = TweakDB:GetRecords("gamedataVehicle_Record")
    if not records or #records == 0 then
        Logger.Log("VehicleLoader: no vehicle records found")
        return
    end

    local injectedCount = 0
    local baseCount = 0
    local addOnCount = 0

    for _, record in ipairs(records) do
        local id = DataUtils.SafeCall(function() return record:GetID().value end)
        if self:ShouldLoad(id, record) then
            local isModded = id:match("^Vehicle%.v_") == nil and id:match("^Vehicle%.vcd") == nil
            local tags = DataUtils.GetTags(record)
            local variants = {}

            if isModded then
                table.insert(tags, "Modded Vehicle")
                table.insert(tags, "Add-On Vehicle")
                variants = self:GetVirtualDealerVariants(id)
            end

            local vehicle = BuildVehicle(id, record, DataUtils.GetDisplayName(record), tags, isModded, variants)
            if #variants > 0 then self:LoadVariantRecords(variants) end

            table.insert(self.vehicles, vehicle)
            self.indexById[id] = vehicle

            if isModded then
                addOnCount = addOnCount + 1
            else
                baseCount = baseCount + 1
            end

            if self:AddVehicleToList(id) then injectedCount = injectedCount + 1 end
        end
    end

    Logger.Log(string.format(
        "VehicleLoader: loaded %d browsable vehicles (%d base, %d add-on), %d variants, added %d to vehicle list",
        baseCount + addOnCount, baseCount, addOnCount, math.max(0, #self.vehicles - baseCount - addOnCount), injectedCount
    ))
end

function VehicleLoader:GetAll()
    return self.vehicles
end

function VehicleLoader:GetBrowsable()
    local variantIDs = {}
    for _, vehicle in ipairs(self.vehicles) do
        for _, variantID in ipairs(vehicle.variants or {}) do variantIDs[variantID] = true end
    end

    local result = {}
    for _, vehicle in ipairs(self.vehicles) do
        if not variantIDs[vehicle.id] then table.insert(result, vehicle) end
    end
    return result
end

function VehicleLoader:GetById(id)
    return self.indexById[id]
end

function VehicleLoader:Filter(predicate)
    local result = {}
    for _, vehicle in ipairs(self.vehicles) do
        if predicate(vehicle) then table.insert(result, vehicle) end
    end
    return result
end

return VehicleLoader
