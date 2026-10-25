local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Icons = require("UI/Core/Icons")
local Notification = require("UI/Panels/Notification/Notification")
local VehicleLoader = require("Utils/DataExtractors/VehicleLoader")
local Vehicles = require("Features/Vehicles")

local Spawning = Vehicles.VehicleSpawning
local Unlocking = Vehicles.VehicleUnlocking
local Preview = Vehicles.VehiclePreview
local ViewState = Vehicles.ViewStates

local VISIBILITY_OPTIONS = { "All Vehicles", "Unlocked Only", "Locked Only" }

local CLASS_ORDER = {
    ["Hypercars"] = 1,
    ["Sports"] = 2,
    ["Motorcycles"] = 3,
    ["Executive"] = 4,
    ["Economy"] = 5,
    ["SUV & Off-Road"] = 6,
    ["Utility & Pickups"] = 7,
    ["Police & Emergency"] = 8,
    ["Heavy & Special"] = 9,
    ["Other"] = 10
}

local s_Visibility = { index = 1 }
local s_SpawnDistance = { value = 7.0, min = 3.0, max = 25.0, step = 0.5, unit = "m" }
local s_Search = { value = "", capturing = false }
local s_Variants = {}
local s_Menus = {}
local s_Unlocked = {}
local s_ListCache = {}
local s_GarageRefs = {}

local function InvalidateLists()
    s_ListCache = {}
end

local function IsUnlocked(id)
    if s_Unlocked[id] == nil then s_Unlocked[id] = Unlocking.IsUnlocked(id) end
    return s_Unlocked[id]
end

local function GarageRef(id)
    local ref = s_GarageRefs[id] or {}
    ref.value = IsUnlocked(id)
    s_GarageRefs[id] = ref
    return ref
end

local function SetGarageAccess(vehicle, id, enabled)
    Unlocking.SetPlayerVehicleState(id, enabled)
    s_Unlocked[id] = nil
    InvalidateLists()

    if IsUnlocked(id) == enabled then return end
    Notification.Error("The game refused to change garage access for " .. (vehicle.displayName or id), 3)
end

local function CachedMenu(key, create)
    s_Menus[key] = s_Menus[key] or create()
    return s_Menus[key]
end

local function VariantRef(vehicle)
    s_Variants[vehicle.id] = s_Variants[vehicle.id] or { index = 1 }
    return s_Variants[vehicle.id]
end

local function SelectedVehicle(vehicle)
    local index = VariantRef(vehicle).index or 1
    local id = index == 1 and vehicle.id or vehicle.variants[index - 1]
    return VehicleLoader:GetById(id) or vehicle, id
end

local function CleanDescription(value)
    return (tostring(value or "No description available."):gsub('\\"', '"'):gsub("\\n", " "):gsub("\n", " "))
end

local function IconID(vehicle, selectedID)
    if Icons.Has(selectedID) then return selectedID end
    if Icons.Has(vehicle.id) then return vehicle.id end
    for _, id in ipairs(vehicle.variants or {}) do
        if Icons.Has(id) then return id end
    end
    return nil
end

local function SubmitVehicleInfo(vehicle)
    local selected, selectedID = SelectedVehicle(vehicle)
    SidePanel.SubmitInfo("vehicle-record", {
        Eyebrow = vehicle.isModded and "ADD-ON VEHICLE" or "AUTOMOTIVE DATABASE",
        Title = selected.displayName or vehicle.displayName,
        Icon = IconID(vehicle, selectedID),
        IconHeight = 170,
        Rows = {
            { Label = "Manufacturer", Value = selected.manufacturer or "Unknown" },
            { Label = "Class", Value = selected.category or "Other" },
            { Label = "Affiliation", Value = selected.faction or "No Affiliation" },
            { Label = "Year", Value = selected.productionYear or "Unknown" },
            { Label = "Power", Value = selected.horsepower and tostring(math.floor(selected.horsepower)) .. " hp" or "Unknown" },
            { Label = "Mass", Value = selected.mass and tostring(math.floor(selected.mass)) .. " kg" or "Unknown" },
            { Label = "Drive", Value = selected.driveLayout or "Unknown" },
            { Label = "Source", Value = vehicle.source or "Base Game" },
            { Label = "Variants", Value = tostring(1 + #(vehicle.variants or {})) }
        },
        Description = CleanDescription(selected.description or vehicle.description)
    }, { Width = 330 })
end

local function VariantOptions(vehicle)
    local options = { vehicle.displayName }
    for _, id in ipairs(vehicle.variants or {}) do
        local variant = VehicleLoader:GetById(id)
        table.insert(options, variant and variant.displayName or id)
    end
    return options
end

local function SpawnSelected(vehicle)
    local selected, id = SelectedVehicle(vehicle)
    Preview.SetActive(false)
    if Spawning.SpawnVehicle(id, s_SpawnDistance.value, ViewState.MountOnSpawn.value, ViewState.DeleteLastVehicle.value) then
        Notification.Success("Spawned " .. (selected.displayName or vehicle.displayName), 2)
    else
        Notification.Error("Could not spawn " .. (selected.displayName or vehicle.displayName), 3)
    end
end

local function ShowPreview(vehicle)
    if not ViewState.PreviewVehicle.value then return end
    local _, id = SelectedVehicle(vehicle)
    Preview.SetActive(true)
    Preview.Spawn(id)
end

local function OnFocus(data, vehicle)
    if not data or not data.Visible or not (data.Selected or data.Hovered) then return end
    SubmitVehicleInfo(vehicle)
    ShowPreview(vehicle)
end

local function DetailView(vehicle)
    Buttons.Dropdown("Vehicle Variant", VariantRef(vehicle), VariantOptions(vehicle), "Choose which appearance or dealer variant to use.")

    if ViewState.SpawnerMode then
        Buttons.Option("Spawn Selected Vehicle", "Spawn the selected variant near the player.", function() SpawnSelected(vehicle) end)
    else
        local _, id = SelectedVehicle(vehicle)
        Buttons.GhostToggle("Garage Access", GarageRef(id), "Add or remove the selected variant from your garage.", function(value)
            SetGarageAccess(vehicle, id, value)
        end)
    end

    SubmitVehicleInfo(vehicle)
    ShowPreview(vehicle)
end

local function DrawVehicle(vehicle)
    if #(vehicle.variants or {}) > 0 then
        local menu = CachedMenu("detail:" .. vehicle.id, function()
            return Submenu.Create(vehicle.displayName, function() DetailView(vehicle) end)
        end)
        local _, data = Buttons.Submenu(vehicle.displayName, menu, tostring(1 + #vehicle.variants) .. " variants available")
        OnFocus(data, vehicle)
        return
    end

    local data
    if ViewState.SpawnerMode then
        data = select(2, Buttons.OptionExtended(vehicle.displayName, "", "SPAWN", "Spawn this vehicle near the player.", function()
            SpawnSelected(vehicle)
        end))
    else
        data = select(2, Buttons.GhostToggle(vehicle.displayName, GarageRef(vehicle.id), "Toggle whether this vehicle appears in your garage.", function(value)
            SetGarageAccess(vehicle, vehicle.id, value)
        end))
    end
    OnFocus(data, vehicle)
end

local function VisibilityMatches(vehicle)
    if ViewState.SpawnerMode then return true end
    local mode = VISIBILITY_OPTIONS[s_Visibility.index or 1]
    if mode == "Unlocked Only" then return IsUnlocked(vehicle.id) end
    if mode == "Locked Only" then return not IsUnlocked(vehicle.id) end
    return true
end

local function ByName(a, b)
    return (a.displayName or a.id):lower() < (b.displayName or b.id):lower()
end

local function BuildList(predicate)
    local list = { All = {}, Grouped = {}, Single = {} }
    for _, vehicle in ipairs(VehicleLoader:GetBrowsable()) do
        if (not predicate or predicate(vehicle)) and VisibilityMatches(vehicle) then
            table.insert(list.All, vehicle)
            table.insert(#(vehicle.variants or {}) > 0 and list.Grouped or list.Single, vehicle)
        end
    end
    table.sort(list.All, ByName)
    table.sort(list.Grouped, ByName)
    table.sort(list.Single, ByName)
    return list
end

local function CachedList(key, predicate)
    local cacheKey = table.concat({ key, tostring(ViewState.SpawnerMode), tostring(s_Visibility.index) }, "|")
    s_ListCache[cacheKey] = s_ListCache[cacheKey] or BuildList(predicate)
    return s_ListCache[cacheKey]
end

local function SortGroups(field)
    return function(a, b)
        if field == "category" then
            local first, second = CLASS_ORDER[a] or 999, CLASS_ORDER[b] or 999
            if first ~= second then return first < second end
        end
        return a < b
    end
end

local function GroupBy(vehicles, field)
    local counts = {}
    local keys = {}
    for _, vehicle in ipairs(vehicles) do
        local key = vehicle[field] or "Other"
        if not counts[key] then
            counts[key] = 0
            table.insert(keys, key)
        end
        counts[key] = counts[key] + 1
    end
    table.sort(keys, SortGroups(field))
    return keys, counts
end

local function DrawEmpty()
    Buttons.Option("No Matching Vehicles", "Adjust the garage filter or reload the vehicle database.", function() end)
end

local function DrawList(key, title, predicate)
    local list = CachedList(key, predicate)
    if #list.All == 0 then
        DrawEmpty()
        return
    end

    for _, vehicle in ipairs(list.Grouped) do DrawVehicle(vehicle) end
    if #list.Grouped > 0 and #list.Single > 0 then Buttons.Break(title) end
    for _, vehicle in ipairs(list.Single) do DrawVehicle(vehicle) end
end

local function ListMenu(key, title, predicate)
    return CachedMenu("list:" .. key, function()
        return Submenu.Create(title, function() DrawList(key, title, predicate) end)
    end)
end

local function GroupView(field)
    local list = CachedList("all")
    if #list.All == 0 then
        DrawEmpty()
        return
    end

    local values, counts = GroupBy(list.All, field)
    for _, value in ipairs(values) do
        local menu = ListMenu(field .. "/" .. value, value, function(vehicle) return (vehicle[field] or "Other") == value end)
        Buttons.Submenu(value .. "  [" .. tostring(counts[value]) .. "]", menu, "Browse vehicles in " .. value .. ".")
    end
end

local function GroupMenu(title, field)
    return Submenu.Create(title, function() GroupView(field) end)
end

local function IsPlayerVehicle(vehicle)
    return vehicle.faction == "Player" or vehicle.id:lower():find("_player", 1, true) ~= nil
end

local function MatchesSearch(vehicle, term)
    return (vehicle.displayName or ""):lower():find(term, 1, true)
        or (vehicle.manufacturer or ""):lower():find(term, 1, true)
        or (vehicle.id or ""):lower():find(term, 1, true)
end

local function SearchView()
    Buttons.Text("Search Vehicles", s_Search, "Search by vehicle name, manufacturer, or internal ID.")
    local term = (s_Search.value or ""):lower()
    if term == "" then return end

    DrawList("search:" .. term, "Results", function(vehicle) return MatchesSearch(vehicle, term) end)
end

local NAVIGATION = {
    { Label = "All Vehicles", Tip = "Browse the complete vehicle database.", Menu = ListMenu("all", "All Vehicles") },
    { Label = "By Class", Tip = "Browse vehicle classes such as hypercars, sports, bikes, and utility.", Menu = GroupMenu("Vehicle Classes", "category") },
    { Label = "By Manufacturer", Tip = "Browse vehicles by manufacturer.", Menu = GroupMenu("Manufacturers", "manufacturer") },
    { Label = "By Affiliation", Tip = "Browse faction, police, corpo, and player vehicles.", Menu = GroupMenu("Affiliations", "faction") },
    { Label = "Player Vehicles", Tip = "Browse the vehicles V can own in the base game.", Menu = ListMenu("player", "Player Vehicles", IsPlayerVehicle) },
    { Label = "Add-On Vehicles", Tip = "Browse vehicles installed by other mods.", Menu = ListMenu("addons", "Add-On Vehicles", function(vehicle) return vehicle.isModded end) },
    { Label = "Search Vehicles", Tip = "Find a vehicle by name, manufacturer, or ID.", Menu = Submenu.Create("Search Vehicles", SearchView) }
}

local function ReloadDatabase()
    VehicleLoader:LoadAll()
    s_Unlocked = {}
    s_Menus = {}
    InvalidateLists()
    Notification.Success("Vehicle database reloaded", 2)
end

local function DespawnAll()
    local count = Spawning.DespawnAll()
    Notification.Info(string.format("Removed %d spawned vehicles", count), 2)
end

local function VehicleListView()
    Preview.SetActive(false)

    for _, entry in ipairs(NAVIGATION) do
        Buttons.Submenu(entry.Label, entry.Menu, entry.Tip, function()
            s_Unlocked = {}
            InvalidateLists()
        end)
    end

    if ViewState.SpawnerMode then
        Buttons.Break("Vehicle Spawner")
        Buttons.Float("Spawn Distance", s_SpawnDistance, "Distance in front of the player used for spawning.")
        Buttons.Toggle("Delete Previous Vehicle", ViewState.DeleteLastVehicle, "Remove the previously spawned vehicle when a new one spawns.")
        Buttons.Toggle("Mount on Spawn", ViewState.MountOnSpawn, "Enter the driver seat as soon as the vehicle spawns.")
        Buttons.Option("Despawn All Spawned Vehicles", "Remove every vehicle spawned by EasyTrainer this session.", DespawnAll)
    else
        Buttons.Break("Garage Manager")
        Buttons.Dropdown("Garage Filter", s_Visibility, VISIBILITY_OPTIONS, "Show all, unlocked, or locked vehicles in every list.")
    end
    Buttons.Toggle("Vehicle Preview", ViewState.PreviewVehicle, "Preview the focused vehicle in front of the player.")
    Buttons.Option("Reload Vehicle Database", "Reload vehicle and add-on records from TweakDB.", ReloadDatabase)
end

return Submenu.Create("Vehicles", VehicleListView)
