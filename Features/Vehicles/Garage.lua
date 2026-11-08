local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")
local Catalog = require("Features/Vehicles/Catalog")

local Garage = {
    Ready = false
}

local s_Unlocked = {}

function Garage.Refresh()
    local ok, list = pcall(function() return Game.GetVehicleSystem():GetPlayerUnlockedVehicles() end)
    if not ok or type(list) ~= "table" then return end

    local unlocked = {}
    for _, vehicle in ipairs(list) do unlocked[Catalog.Key(vehicle.recordID)] = true end
    s_Unlocked = unlocked
    Garage.Ready = true
end

function Garage.IsUnlocked(vehicle)
    return s_Unlocked[vehicle.Key] == true
end

local function Apply(system, vehicle, enable)
    system:EnablePlayerVehicle(vehicle.Id, enable, not enable)
    if enable then
        s_Unlocked[vehicle.Key] = true
    else
        s_Unlocked[vehicle.Key] = nil
    end
end

function Garage.Set(vehicle, enable)
    Apply(Game.GetVehicleSystem(), vehicle, enable)
    Logger.Log("Vehicles: " .. (enable and "added " or "removed ") .. vehicle.Id .. (enable and " to" or " from") .. " the garage")
end

function Garage.SetMany(predicate, enable)
    local system = Game.GetVehicleSystem()
    local count = 0
    for _, vehicle in ipairs(Catalog.Browsable) do
        if predicate(vehicle) then
            Apply(system, vehicle, enable)
            for _, variant in ipairs(vehicle.Variants) do Apply(system, variant, enable) end
            count = count + 1
        end
    end
    Logger.Log(string.format("Vehicles: %s %d vehicles", enable and "added" or "removed", count))
    Notify.Success(tip(enable and "notify.vehicles.garageadded" or "notify.vehicles.garageremoved", { count = count }))
    return count
end

function Garage.Clear()
    s_Unlocked = {}
    Garage.Ready = false
end

return Garage
