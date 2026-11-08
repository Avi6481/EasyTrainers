local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Vehicles = require("Features/Vehicles/Vehicles")
local Catalog = require("Features/Vehicles/Catalog")
local Garage = require("Features/Vehicles/Garage")
local VehicleInfo = require("View/Vehicles/VehicleInfo")
local Notify = require("Utils/Notify")

local BrowserView = {}

local SPAWN = "Spawn"
local GARAGE = "Garage"
local MAX_MATCHES = 150
local FILTERS = { "All", "Unlocked", "Locked" }

local GROUPS = {
    { Key = "class", Field = "Class" },
    { Key = "manufacturer", Field = "Manufacturer" },
    { Key = "affiliation", Field = "Faction" }
}

local LISTS = {
    { Key = "all", Filter = function() return true end },
    { Key = "player", Filter = function(vehicle) return vehicle.Player end },
    { Key = "addons", Filter = function(vehicle) return vehicle.AddOn end }
}

local s_Filter = Ref.Choice(Vehicles, "GarageFilter", FILTERS)
local s_Search = { [SPAWN] = { Query = "" }, [GARAGE] = { Query = "" } }
local s_SearchRefs = { [SPAWN] = Ref.Field(s_Search[SPAWN], "Query"), [GARAGE] = Ref.Field(s_Search[GARAGE], "Query") }
local s_Matches = {}
local s_Lists = {}
local s_Groups = {}
local s_Menus = {}
local s_GarageRefs = setmetatable({}, { __mode = "k" })
local s_Affiliation = { Index = 1 }
local s_AffiliationRef = Ref.Field(s_Affiliation, "Index")
local s_FilterItems = nil
local s_AffiliationItems = nil
local s_GarageSeenUntil = 0
local s_Version = nil

local function Visible(vehicle, mode)
    if mode ~= GARAGE or Vehicles.GarageFilter == "All" then return true end
    return Garage.IsUnlocked(vehicle) == (Vehicles.GarageFilter == "Unlocked")
end

local function GarageRef(vehicle)
    local ref = s_GarageRefs[vehicle]
    if ref then return ref end

    ref = Ref.New(function() return Garage.IsUnlocked(vehicle) end, function(value) Vehicles.SetGarage(vehicle, value) end)
    s_GarageRefs[vehicle] = ref
    return ref
end

local function Single(vehicle, mode)
    if not Visible(vehicle, mode) then return end

    if mode == SPAWN then
        if Widgets.ValueRow(vehicle.Name, vehicle.Manufacturer, true) then Vehicles.Spawn(vehicle) end
        Widgets.Tip(L("vehicles.spawn.tip"))
        if Widgets.Selected() then Vehicles.WantPreview(vehicle) end
    else
        Widgets.Toggle(vehicle.Name, GarageRef(vehicle))
        Widgets.Tip(L("vehicles.garagerow.tip"))
    end
    Widgets.Info(VehicleInfo.Get, vehicle)
end

local function Rows(vehicles, mode)
    for _, vehicle in ipairs(vehicles) do
        Single(vehicle, mode)
        for _, variant in ipairs(vehicle.Variants) do Single(variant, mode) end
    end
end

local function List(key, filter)
    local list = s_Lists[key]
    if list then return list end

    list = {}
    for _, vehicle in ipairs(Catalog.Browsable) do
        if filter(vehicle) then table.insert(list, vehicle) end
    end
    s_Lists[key] = list
    return list
end

local function Store(key, title, view)
    local menu = Submenu.Create(title, view)
    s_Menus[key] = menu
    return menu
end

local function Fresh()
    if s_Version == Catalog.Version then return end
    s_Version = Catalog.Version
    s_Lists = {}
    s_Groups = {}
    s_Matches = {}
    s_AffiliationItems = nil
    for _, list in ipairs(LISTS) do list.Badge = nil end
end

local function Loading()
    if Catalog.Loaded then
        Fresh()
        return false
    end
    Widgets.ValueRow(L("vehicles.loading"), "")
    return true
end

local function ListView(mode, key, filter)
    Vehicles.Watch()
    if Loading() then return end
    Rows(List(key, filter), mode)
end

local function Order(field)
    if field == "Class" then
        local order = {}
        for index, name in ipairs(Catalog.CLASSES) do order[name] = index end
        return function(first, second) return (order[first.Name] or 99) < (order[second.Name] or 99) end
    end
    return function(first, second) return first.Name:lower() < second.Name:lower() end
end

local function Groups(field)
    local groups = s_Groups[field]
    if groups then return groups end

    local byName = {}
    groups = {}
    for _, vehicle in ipairs(Catalog.Browsable) do
        local name = vehicle[field]
        local group = byName[name]
        if not group then
            group = { Name = name, Count = 0 }
            byName[name] = group
            table.insert(groups, group)
        end
        group.Count = group.Count + 1
    end
    table.sort(groups, Order(field))
    for _, group in ipairs(groups) do group.Badge = tostring(group.Count) end
    s_Groups[field] = groups
    return groups
end

local function GroupView(mode, field)
    Vehicles.Watch()
    if Loading() then return end

    for _, group in ipairs(Groups(field)) do
        group.Keys = group.Keys or {}
        group.Keys[mode] = group.Keys[mode] or (mode .. ":" .. field .. ":" .. group.Name)
        local key = group.Keys[mode]
        local menu = s_Menus[key] or Store(key, group.Name, function()
            ListView(mode, field .. ":" .. group.Name, function(vehicle) return vehicle[field] == group.Name end)
        end)
        Widgets.SubmenuButton(group.Name, menu, group.Badge)
        Widgets.Tip(L("vehicles.groups.tip"))
    end
end

local function Matches(mode)
    local query = s_Search[mode].Query
    local cached = s_Matches[mode]
    if cached and cached.Query == query then return cached.List end

    local list = {}
    for _, vehicle in ipairs(Catalog.All) do
        if Widgets.SearchMatch(vehicle.Search, query) then
            table.insert(list, vehicle)
            if #list == MAX_MATCHES then break end
        end
    end
    s_Matches[mode] = { Query = query, List = list }
    return list
end

local function Results(mode)
    local matches = Matches(mode)
    for _, vehicle in ipairs(matches) do Single(vehicle, mode) end
    if #matches == 0 then Widgets.ValueRow(L("vehicles.browse.none"), "") end
    if #matches == MAX_MATCHES then Widgets.ValueRow(L("vehicles.browse.more"), "") end
end

local function Items(keys, prefix)
    local items = {}
    for index, key in ipairs(keys) do items[index] = { Label = L(prefix .. key:lower()), Tip = "" } end
    return items
end

local function Affiliations()
    if s_AffiliationItems then return s_AffiliationItems end

    s_AffiliationItems = {}
    for index, group in ipairs(Groups("Faction")) do s_AffiliationItems[index] = { Label = group.Name, Tip = "" } end
    return s_AffiliationItems
end

local function SelectedAffiliation()
    local item = Affiliations()[s_Affiliation.Index]
    return item and item.Label
end

local function FleetButton(key, predicate, enable)
    if Widgets.HoldButton(L("vehicles.fleet." .. key .. ".label")) then Vehicles.SetGarageMany(predicate, enable) end
    Widgets.Tip(L("vehicles.fleet." .. key .. ".tip"))
end

local function IsPlayer(vehicle) return vehicle.Player end
local function IsAddOn(vehicle) return vehicle.AddOn end
local function InAffiliation(vehicle) return vehicle.Faction == SelectedAffiliation() end

local function Fleet()
    s_FilterItems = s_FilterItems or Items(FILTERS, "vehicles.filters.")

    Widgets.Break(L("vehicles.garage.break"))
    Widgets.Dropdown(L("vehicles.garage.filter.label"), s_Filter, s_FilterItems)
    Widgets.Tip(L("vehicles.garage.filter.tip"))
    FleetButton("addplayer", IsPlayer, true)
    FleetButton("removeplayer", IsPlayer, false)
    FleetButton("addaddons", IsAddOn, true)
    FleetButton("removeaddons", IsAddOn, false)

    Widgets.Dropdown(L("vehicles.fleet.affiliation.label"), s_AffiliationRef, Affiliations())
    Widgets.Tip(L("vehicles.fleet.affiliation.tip"))
    FleetButton("addaffiliation", InAffiliation, true)
    FleetButton("removeaffiliation", InAffiliation, false)
end

local function Link(mode, entry, badge, view)
    entry.Keys = entry.Keys or {}
    entry.Keys[mode] = entry.Keys[mode] or (mode .. ":" .. entry.Key)
    local label = "vehicles.browse." .. entry.Key
    local key = entry.Keys[mode]
    local menu = s_Menus[key] or Store(key, label .. ".label", function() view(mode, entry) end)
    Widgets.SubmenuButton(L(label .. ".label"), menu, badge)
    Widgets.Tip(L(label .. ".tip"))
end

local function ListEntry(mode, entry)
    ListView(mode, entry.Key, entry.Filter)
end

local function GroupEntry(mode, entry)
    GroupView(mode, entry.Field)
end

local function Links(mode)
    for _, list in ipairs(LISTS) do
        list.Badge = list.Badge or tostring(#List(list.Key, list.Filter))
        Link(mode, list, list.Badge, ListEntry)
        if list.Key == "all" then
            for _, group in ipairs(GROUPS) do Link(mode, group, nil, GroupEntry) end
        end
    end
end

local function RootView(mode)
    Vehicles.Watch()
    if mode == GARAGE then
        local now = os.clock()
        if now > s_GarageSeenUntil then Notify.Warning(L("notify.vehicles.garagesave"), 6) end
        s_GarageSeenUntil = now + 1
    end

    local searching = s_Search[mode].Query ~= ""
    Widgets.SearchRow(s_SearchRefs[mode], L("vehicles.browse.placeholder"), (searching and Catalog.Loaded) and #Matches(mode) or -1)
    if Loading() then return end

    if searching then
        Results(mode)
        return
    end

    Links(mode)
    if mode == GARAGE then Fleet() end
end

BrowserView.Spawner = Submenu.Create("vehicles.spawner.title", function() RootView(SPAWN) end)
BrowserView.Garage = Submenu.Create("vehicles.garage.title", function() RootView(GARAGE) end)

return BrowserView
