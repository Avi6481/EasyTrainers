local UI = require("UI")
local Buttons = UI.Buttons
local SidePanel = UI.SidePanel
local Notification = UI.Notification
local VehicleFeatures = require("Features/Vehicles")
local VehicleLoader = require("Utils/DataExtractors/VehicleLoader")

local VehicleSpawning = VehicleFeatures.VehicleSpawning
local VehicleSystem = VehicleFeatures.VehicleUnlocking
local VehiclePreview = VehicleFeatures.VehiclePreview
local ViewState = VehicleFeatures.VehicleListStates

local visibility = { index = 1 }
local visibilityOptions = { "All Vehicles", "Unlocked Only", "Locked Only" }
local spawnDistance = { value = 7.0, min = 3.0, max = 25.0, step = 0.5 }
local search = { value = "", capturing = false }
local navigation

local classOrder = {
    ["Hypercars"] = 1,
    ["Sports"] = 2,
    ["Motorcycles"] = 3,
    ["Executive"] = 4,
    ["Economy"] = 5,
    ["SUV & Off-Road"] = 6,
    ["Utility & Pickups"] = 7,
    ["Police & Emergency"] = 8,
    ["Heavy & Special"] = 9,
    ["Other"] = 10,
}

local function IsFocused(data)
    return data and data.Visible and (data.Selected or data.Hovered)
end

local function CleanDescription(value)
    return tostring(value or "No description available.")
        :gsub('\\\"', '"'):gsub("\\n", " "):gsub("\n", " ")
end

local function SelectedVehicle(vehicle)
    local index = vehicle._variantRef and vehicle._variantRef.index or 1
    local id = index == 1 and vehicle.id or vehicle.variants[index - 1]
    return VehicleLoader:GetById(id) or vehicle, id
end

local function SubmitVehicleInfo(vehicle)
    local selected = SelectedVehicle(vehicle)
    SidePanel.SubmitInfo("vehicle-record", {
        Eyebrow = vehicle.isModded and "ADD-ON VEHICLE" or "AUTOMOTIVE DATABASE",
        Title = selected.displayName or vehicle.displayName,
        Rows = {
            { Label = "Manufacturer", Value = selected.manufacturer or vehicle.manufacturer or "Unknown" },
            { Label = "Class", Value = selected.category or vehicle.category or "Other" },
            { Label = "Year", Value = selected.productionYear or vehicle.productionYear or "Unknown" },
            { Label = "Power", Value = selected.horsepower and tostring(math.floor(selected.horsepower)) .. " hp" or "Unknown" },
            { Label = "Mass", Value = selected.mass and tostring(math.floor(selected.mass)) or "Unknown" },
            { Label = "Drive", Value = selected.driveLayout or vehicle.driveLayout or "Unknown" },
            { Label = "Source", Value = vehicle.source or "Base Game" },
            { Label = "Variants", Value = tostring(1 + #(vehicle.variants or {})) },
        },
        Description = CleanDescription(selected.description or vehicle.description),
    }, { Width = 330 })
end

local function VariantOptions(vehicle)
    local result = { vehicle.displayName }
    for _, id in ipairs(vehicle.variants or {}) do
        local variant = VehicleLoader:GetById(id)
        table.insert(result, variant and variant.displayName or id)
    end
    return result
end

local function SpawnSelected(vehicle)
    local _, id = SelectedVehicle(vehicle)
    VehiclePreview.SetActive(false)
    local entity = VehicleSpawning.SpawnVehicle(id, spawnDistance.value,
        ViewState.mountOnSpawn.value, ViewState.deleteLastVehicle.value)
    if entity then Notification.Success("Spawned " .. (SelectedVehicle(vehicle).displayName or vehicle.displayName), 2) end
end

local function Preview(vehicle)
    if not ViewState.previewVehicle.value then return end
    local _, id = SelectedVehicle(vehicle)
    VehiclePreview.SetActive(true)
    VehiclePreview.Spawn(id)
end

local function GarageToggle(vehicle, enabled)
    local _, id = SelectedVehicle(vehicle)
    VehicleSystem.SetPlayerVehicleState(id, enabled)
end

local function VehicleDetailView(vehicle)
    vehicle._variantRef = vehicle._variantRef or { index = 1 }
    Buttons.Dropdown("Vehicle Variant", vehicle._variantRef, VariantOptions(vehicle),
        "Choose which appearance or dealer variant to use.")
    local selected = SelectedVehicle(vehicle)
    if ViewState.enableVehicleSpawnerMode then
        Buttons.Option("Spawn Selected Vehicle", "Spawn the selected variant near the player.", function()
            SpawnSelected(vehicle)
        end)
        Buttons.Option("Preview Selected Vehicle", "Show the selected variant in the world preview.", function()
            Preview(vehicle)
        end)
    else
        local state = { value = VehicleSystem.IsUnlocked(selected.id) }
        Buttons.GhostToggle("Garage Access", state, "Add or remove the selected variant from your garage.", function(value)
            GarageToggle(vehicle, value)
        end)
    end
    SubmitVehicleInfo(vehicle)
end

local function DetailMenu(vehicle)
    if not vehicle._detailsMenu then
        vehicle._detailsMenu = {
            title = vehicle.displayName,
            view = function() VehicleDetailView(vehicle) end,
        }
    end
    return vehicle._detailsMenu
end

local function DrawVehicle(vehicle)
    local hasVariants = #(vehicle.variants or {}) > 0
    if hasVariants then
        local opened, data = Buttons.Submenu(vehicle.displayName, DetailMenu(vehicle),
            tostring(1 + #vehicle.variants) .. " variants available")
        if opened then vehicle._variantRef = vehicle._variantRef or { index = 1 } end
        if IsFocused(data) then SubmitVehicleInfo(vehicle) Preview(vehicle) end
        return
    end

    if ViewState.enableVehicleSpawnerMode then
        local _, data = Buttons.OptionExtended(vehicle.displayName, "", "SPAWN",
            "Spawn this vehicle near the player.", function() SpawnSelected(vehicle) end)
        if IsFocused(data) then SubmitVehicleInfo(vehicle) Preview(vehicle) end
    else
        local state = { value = VehicleSystem.IsUnlocked(vehicle.id) }
        local _, data = Buttons.GhostToggle(vehicle.displayName, state,
            "Toggle whether this vehicle appears in your garage.", function(value)
                VehicleSystem.SetPlayerVehicleState(vehicle.id, value)
            end)
        if IsFocused(data) then SubmitVehicleInfo(vehicle) Preview(vehicle) end
    end
end

local function VisibilityMatches(vehicle)
    if ViewState.enableVehicleSpawnerMode then return true end
    local mode = visibilityOptions[visibility.index or 1]
    local unlocked = VehicleSystem.IsUnlocked(vehicle.id)
    if mode == "Unlocked Only" then return unlocked end
    if mode == "Locked Only" then return not unlocked end
    return true
end

local function DrawList(title, predicate)
    Buttons.Toggle("Vehicle Preview", ViewState.previewVehicle,
        "Preview the currently focused vehicle in front of the player.")
    if not ViewState.enableVehicleSpawnerMode then
        Buttons.Dropdown("Garage Filter", visibility, visibilityOptions,
            "Show all, unlocked, or locked vehicles.")
    end

    local vehicles = {}
    for _, vehicle in ipairs(VehicleLoader:GetBrowsable()) do
        if (not predicate or predicate(vehicle)) and VisibilityMatches(vehicle) then
            table.insert(vehicles, vehicle)
        end
    end
    table.sort(vehicles, function(a, b)
        return (a.displayName or a.id):lower() < (b.displayName or b.id):lower()
    end)
    Buttons.Break("", title .. "  /  " .. tostring(#vehicles))
    if #vehicles == 0 then
        Buttons.Option("No Matching Vehicles", "Adjust the current filter or refresh the vehicle database.")
        return
    end
    for _, vehicle in ipairs(vehicles) do DrawVehicle(vehicle) end
end

local function ListMenu(title, predicate)
    return { title = title, view = function() DrawList(title, predicate) end }
end

local function GroupValues(field, predicate)
    local counts = {}
    for _, vehicle in ipairs(VehicleLoader:GetBrowsable()) do
        if not predicate or predicate(vehicle) then
            local value = vehicle[field] or "Unknown"
            counts[value] = (counts[value] or 0) + 1
        end
    end
    local values = {}
    for value in pairs(counts) do table.insert(values, value) end
    table.sort(values, function(a, b)
        if field == "category" then
            local first, second = classOrder[a] or 999, classOrder[b] or 999
            if first ~= second then return first < second end
        end
        return a < b
    end)
    return values, counts
end

local function GroupView(title, field)
    local values, counts = GroupValues(field)
    for _, value in ipairs(values) do
        local current = value
        Buttons.Submenu(current .. "  [" .. tostring(counts[current]) .. "]",
            ListMenu(current, function(vehicle) return (vehicle[field] or "Unknown") == current end),
            "Browse vehicles in " .. current .. ".")
    end
end

local classMenu = { title = "Vehicle Classes", view = function() GroupView("Vehicle Classes", "category") end }
local manufacturerMenu = { title = "Manufacturers", view = function() GroupView("Manufacturers", "manufacturer") end }
local affiliationMenu = { title = "Affiliations", view = function() GroupView("Affiliations", "faction") end }
local allMenu = ListMenu("All Vehicles")
local playerMenu = ListMenu("Player Vehicles", function(vehicle)
    return vehicle.faction == "Player" or vehicle.id:lower():find("_player", 1, true) ~= nil
end)
local addOnMenu = ListMenu("Add-On Vehicles", function(vehicle) return vehicle.isModded end)

local function SearchView()
    Buttons.Text("Search Vehicles", search, "Search by vehicle name, manufacturer, or internal ID.")
    local term = (search.value or ""):lower()
    DrawList("Search Results", function(vehicle)
        if term == "" then return false end
        return (vehicle.displayName or ""):lower():find(term, 1, true)
            or (vehicle.manufacturer or ""):lower():find(term, 1, true)
            or (vehicle.id or ""):lower():find(term, 1, true)
    end)
end

local searchMenu = { title = "Search Vehicles", view = SearchView }

local function BuildNavigation()
    navigation = {
        { Label = "All Vehicles", Menu = allMenu, Tip = "Browse the complete vehicle database." },
        { Label = "By Class", Menu = classMenu, Tip = "Browse clean vehicle classes such as hypercars, sports, bikes, and utility." },
        { Label = "By Manufacturer", Menu = manufacturerMenu, Tip = "Browse vehicles by manufacturer." },
        { Label = "By Affiliation", Menu = affiliationMenu, Tip = "Browse faction, police, corpo, and player vehicles." },
        { Label = "Player Vehicles", Menu = playerMenu, Tip = "Browse vehicles intended for the player garage." },
        { Label = "Add-On Vehicles", Menu = addOnMenu, Tip = "Browse vehicles installed by other mods." },
        { Label = "Search Vehicles", Menu = searchMenu, Tip = "Find a vehicle by name, manufacturer, or ID." },
    }
end

local function VehicleMainView()
    VehiclePreview.SetActive(false)
    if ViewState.enableVehicleSpawnerMode then
        Buttons.Int("Spawn Distance", spawnDistance, "Distance in front of the player used for spawning.")
        Buttons.Toggle("Delete Previous Vehicle", ViewState.deleteLastVehicle,
            "Delete the previous spawned or mounted vehicle after spawning a new one.")
        Buttons.Toggle("Mount on Spawn", ViewState.mountOnSpawn,
            "Automatically enter the driver seat after spawning.")
    end
    Buttons.Toggle("Vehicle Preview", ViewState.previewVehicle,
        "Preview the focused vehicle before spawning or unlocking it.")
    Buttons.Break("", ViewState.enableVehicleSpawnerMode and "Vehicle Spawner" or "Garage Manager")

    if not navigation then BuildNavigation() end
    for _, entry in ipairs(navigation) do
        Buttons.Submenu(entry.Label, entry.Menu, entry.Tip)
    end
    Buttons.Option("Reload Vehicle Database", "Reload vehicle and add-on records from TweakDB.", function()
        VehicleLoader:LoadAll()
        navigation = nil
        Notification.Success("Vehicle database reloaded", 2)
    end)
end

return { title = "Vehicles", view = VehicleMainView }
