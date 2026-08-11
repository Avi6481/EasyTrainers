local Logger = require("Core/Logger")
local utils = require("Utils/DataExtractors/DataUtils")

local VehicleLoader = {
    vehicles = {},
    indexById = {}
}

local function InferCategory(tags, id, displayName)
    local idLower = (id or ""):lower()
    local nameLower = (displayName or ""):lower()
    local all = table.concat(tags or {}, " "):lower() .. " " .. idLower .. " " .. nameLower

    if idLower:find("police") or idLower:find("border") or idLower:find("maxtac") then
        return "Police & Emergency"
    elseif all:find("motorcycle", 1, true) or all:find("sportbike", 1, true)
        or all:find("motorbike", 1, true) or idLower:find("_bike") then
        return "Motorcycles"
    elseif idLower:find("basilisk") or idLower:find("coach") or idLower:find("missile")
        or idLower:find("bmf") or idLower:find("panzer") then
        return "Heavy & Special"
    end

    if idLower:find("caliburn") or idLower:find("aerondight") or idLower:find("outlaw") then
        return "Hypercars"
    elseif idLower:find("standard25") or idLower:find("pickup") or idLower:find("columbus")
        or idLower:find("utility") or idLower:find("truck") or idLower:find("van") then
        return "Utility & Pickups"
    elseif idLower:find("alvarado") or idLower:find("cortes") or idLower:find("deleon")
        or idLower:find("delamain") or idLower:find("thrax") then
        return "Executive"
    elseif idLower:find("standard3") or idLower:find("mackinaw") or idLower:find("merrimac")
        or idLower:find("emperor") or all:find("offroad", 1, true) or all:find("nomad", 1, true) then
        return "SUV & Off-Road"
    elseif idLower:find("sport1") or idLower:find("sport2") or all:match("%f[%a]sport%f[%A]") then
        return "Sports"
    elseif idLower:find("standard1") or idLower:find("standard2") or idLower:find("maimai")
        or idLower:find("galena") or idLower:find("hella") or idLower:find("supron") then
        return "Economy"
    end

    if all:match("%f[%a]utility%d*%f[%A]") then
        return "Utility & Pickups"
    end

    return "Other"
end






local function InferFaction(record, id)
    local faction = nil
    local aff = utils.SafeCall(function() return record:Affiliation() end)
    if aff then
        local key = utils.SafeCall(function() return aff:LocalizedName() end)
        if key then
            local text = Game.GetLocalizedTextByKey(key)
            if text and text ~= "Label Not Found" and text ~= "No Affiliation" then
                faction = utils.EscapeString(text)
            end
        end
    end

    if not faction then
        local groups = {
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
            { "player", "Player" },
        }
        local idLower = id:lower()
        for _, group in ipairs(groups) do
            if idLower:find(group[1], 1, true) then
                faction = group[2]
                break
            end
        end
    end

    return faction or "No Affiliation"
end

local function GetVehicleInfoLore(record)
    local info = { description = "No Description Available", productionYear = nil }
    local ui = utils.SafeCall(function() return record:VehicleUIData() end)

    if ui then
        local rawDesc = utils.SafeCall(function() return ui:Info() end)
        if rawDesc then
            local text = Game.GetLocalizedText(rawDesc)
            if text and text ~= "Label Not Found" then
                info.description = utils.EscapeString(text)
            end
        end

        local year = utils.SafeCall(function() return ui:ProductionYear() end)
        if year then info.productionYear = tostring(year) end

        info.horsepower = tonumber(utils.SafeCall(function() return ui:Horsepower() end))
        info.mass = tonumber(utils.SafeCall(function() return ui:Mass() end))
        local driveLayout = utils.SafeCall(function() return ui:DriveLayout() end)
        if driveLayout then
            local text = Game.GetLocalizedText(driveLayout)
            if text and text ~= "Label Not Found" then info.driveLayout = utils.EscapeString(text) end
        end
    end

    return info
end

local function GetManufacturer(record)
    local mfr = utils.SafeCall(function() return record:Manufacturer() end)
    if mfr then
        local name = utils.SafeCall(function() return mfr:EnumName() end)
        if name and name ~= "" then
            return utils.EscapeString(name)
        end
    end
    return "Unlisted"
end

function VehicleLoader:AddVehicleToList(id)
    local listID = TweakDBID.new("Vehicle.vehicle_list.list")
    local currentList = TweakDB:GetFlat(listID)

    if type(currentList) ~= "table" then
        Logger.Log("VehicleLoader: Failed to read vehicle list.")
        return false
    end

    for _, existing in ipairs(currentList) do
        if existing.value == id then return false end
    end

    table.insert(currentList, TweakDBID.new(id))

    local success = TweakDB:SetFlat(listID, currentList)
    if not success then
        Logger.Log("VehicleLoader: Failed to update vehicle list.")
        return false
    end

    return true
end

-- This function fixes the issue where twin tone wasn't available for all vehicles when set into the list
function VehicleLoader:HandleTwinToneScan(this, wrappedMethod) -- Function taken from Make All Vehicles Unlockable - With TwinTone Fix Created by TheManualEnhancer
    if this.scannedObject ~= nil then
        local obj = this.scannedObject
        if obj and obj:IsVehicle() and obj:GetRecord() then
            local id = utils.SafeCall(function() return obj:GetRecord():GetID().value end)
                or utils.SafeCall(function() return obj:GetRecord():GetRecordID().value end)

            local vehicleSystem = Game.GetVehicleSystem()
            if id and vehicleSystem and not vehicleSystem:IsVehiclePlayerUnlocked(TweakDBID.new(id)) then
                this.twintoneAvailable = true
                return true
            end
        end
    end
    return wrappedMethod()
end


function VehicleLoader:GetVirtualDealerVariants(id)
    local data = TweakDB:GetFlat(id .. ".dealerVariants")
    if not data then return {} end

    local variants = {}

    if type(data) == "table" then
        for _, v in ipairs(data) do
            if type(v) == "string" then
                table.insert(variants, v)
            elseif type(v) == "userdata" and v.value then
                table.insert(variants, v.value)
            elseif type(v) == "table" then
                if v.value then
                    table.insert(variants, v.value)
                else
                    local asStr = tostring(v)
                    if asStr:find("Vehicle%.") then
                        table.insert(variants, asStr)
                    end
                end
            end
        end
    end

    if #variants > 0 then
        -- Logger.Log(string.format("[VehicleLoader] %s > %d variant(s) found", id, #variants))
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
    for _, varId in ipairs(variants) do
        if not self.indexById[varId] then
            local rec = TweakDB:GetRecord(varId)
            if rec then
                local displayName = utils.GetDisplayName(rec)
                local tags = utils.GetTags(rec)
                local lore = GetVehicleInfoLore(rec)
                local vdata = {
                    id = varId,
                    displayName = displayName,
                    manufacturer = GetManufacturer(rec),
                    category = InferCategory(tags, varId, displayName),
                    faction = InferFaction(rec, varId),
                    tags = tags,
                    description = lore.description,
                    productionYear = lore.productionYear,
                    horsepower = lore.horsepower,
                    mass = lore.mass,
                    driveLayout = lore.driveLayout,
                    variants = {},
                    isModded = true,
                    source = "Add-On"
                }

                table.insert(self.vehicles, vdata)
                self.indexById[varId] = vdata
            end
        end
    end
end


function VehicleLoader:LoadAll()
    self.vehicles = {}
    self.indexById = {}
    local records = TweakDB:GetRecords("gamedataVehicle_Record")
    if not records or #records == 0 then
        Logger.Log("VehicleLoader: No vehicle records found.")
        return
    end

    local injectedCount = 0
    local baseCount = 0
    local addOnCount = 0

    for _, rec in ipairs(records) do
        local id = utils.SafeCall(function() return rec:GetID().value end)
        if not id then goto continue end
        if self.indexById[id] then goto continue end

        local idLower = id:lower()

        local isVanilla = id:match("^Vehicle%.v_") ~= nil or id:match("^Vehicle%.vcd") ~= nil
        local isDealerVehicle = self:IsVirtualDealerVehicle(id)
        if not isVanilla and not isDealerVehicle then goto continue end
        local isModded = not isVanilla and isDealerVehicle

        local manufacturer = GetManufacturer(rec)
        local displayName = utils.GetDisplayName(rec)
        local tags = utils.GetTags(rec)
        local lore = GetVehicleInfoLore(rec)
        
        if idLower:find("_av_") or idLower:match("^vehicle%.av_") or idLower:match("_av$") then goto continue end

        if not isModded then -- Seems some modded vehicles were missed due to having "Unlisted" manufacturer or "Unknown" display name, so we'll just skip those checks for modded vehicles
            if manufacturer == "Unlisted" or displayName == "Unknown" then goto continue end
            if lore.productionYear and tostring(lore.productionYear):lower():find("lockey") then goto continue end
        elseif displayName == "Unknown" and not isDealerVehicle then
            goto continue
        end

        local category = InferCategory(tags, id, displayName)

        local variants = {}
        if isModded then
            table.insert(tags, "Modded Vehicle")
            table.insert(tags, "Add-On Vehicle")
            variants = self:GetVirtualDealerVariants(id)
        end

        -- Main data entry
        local data = {
            id = id,
            displayName = displayName,
            manufacturer = manufacturer,
            category = category,
            faction = InferFaction(rec, id),
            tags = tags,
            description = lore.description,
            productionYear = lore.productionYear,
            horsepower = lore.horsepower,
            mass = lore.mass,
            driveLayout = lore.driveLayout,
            variants = variants,
            isModded = isModded,
            source = isModded and "Add-On" or "Base Game"
        }

        if isModded and #variants > 0 then
            self:LoadVariantRecords(variants)
        end

        table.insert(self.vehicles, data)
        self.indexById[id] = data
        if isModded then addOnCount = addOnCount + 1 else baseCount = baseCount + 1 end

        if self:AddVehicleToList(id) then
            injectedCount = injectedCount + 1
        end

        ::continue::
    end

    local variantCount = math.max(0, #self.vehicles - baseCount - addOnCount)
    Logger.Log(string.format(
        "VehicleLoader: Loaded %d browsable vehicles (%d base, %d add-on), %d variants; added %d to vehicle list.",
        baseCount + addOnCount, baseCount, addOnCount, variantCount, injectedCount
    ))
end

function VehicleLoader:GetAll()
    return self.vehicles
end

function VehicleLoader:GetBrowsable()
    local variantIds, result = {}, {}
    for _, vehicle in ipairs(self.vehicles) do
        for _, variantId in ipairs(vehicle.variants or {}) do variantIds[variantId] = true end
    end
    for _, vehicle in ipairs(self.vehicles) do
        if not variantIds[vehicle.id] then table.insert(result, vehicle) end
    end
    return result
end

function VehicleLoader:GetById(id)
    return self.indexById[id]
end

function VehicleLoader:Filter(fn)
    local out = {}
    for _, v in ipairs(self.vehicles) do
        if fn(v) then table.insert(out, v) end
    end
    return out
end

return VehicleLoader
