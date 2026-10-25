local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Notification = require("UI/Panels/Notification/Notification")
local Teleport = require("Utils/Teleport")
local TeleportLocations = require("Features/Teleports/TeleportLocations")
local AutoTeleport = require("Features/Teleports/AutoTeleport")
local Settings = require("Features/Teleports/TeleportViewStates")
local CustomTeleportView = require("View/Teleports/CustomTeleportView")
local TeleportMap = require("UI/Panels/Map/TeleportMap")
local Restrictions = require("Controls/Restrictions")

local s_Creator = { index = 1 }
local s_Parent = { index = 1 }
local s_Child = { index = 1 }
local s_Quick = { index = 1 }

local s_Creators = {}
local s_Parents = {}
local s_Children = {}
local s_QuickOptions = {}
local s_QuickLabels = {}

local s_KnownCount = -1
local s_FilterKey = nil
local s_Categories = {}
local s_CategoryCounts = {}
local s_CurrentCategory = ""
local s_MapCategory = nil

local function AllCreators() return L("teleport.creator_all") end
local function AllDistricts() return L("teleport.district_all") end
local function AllAreas() return L("teleport.area_all") end

local function FormatDistance(distance)
    if not distance then return "" end
    if distance >= 1000 then return string.format("%.2f km", distance / 1000) end
    return string.format("%d m", math.floor(distance))
end

local function UniqueSorted(first, values)
    local result = { first }
    local seen = { [first] = true }
    for _, value in ipairs(values) do
        if value and not seen[value] then
            seen[value] = true
            table.insert(result, value)
        end
    end
    table.sort(result, function(a, b)
        if a == first then return true end
        if b == first then return false end
        return a < b
    end)
    return result
end

local function BuildQuickOptions()
    s_QuickOptions = {}
    s_QuickLabels = {}

    local vendorPrefix = L("teleport.quick_closest_vendor")
    for category in pairs(TeleportLocations.GetVendors()) do
        table.insert(s_QuickOptions, { Kind = "vendor", Key = category, Label = vendorPrefix .. " " .. category })
    end

    local apartmentPrefix = L("teleport.quick_apartment")
    for _, apartment in ipairs(TeleportLocations.GetApartments()) do
        table.insert(s_QuickOptions, { Kind = "apartment", Key = apartment.name, Position = apartment.position, Label = apartmentPrefix .. ": " .. apartment.name })
    end

    table.sort(s_QuickOptions, function(a, b) return a.Label < b.Label end)
    for _, option in ipairs(s_QuickOptions) do table.insert(s_QuickLabels, option.Label) end
    s_Quick.index = math.max(1, math.min(s_Quick.index or 1, #s_QuickOptions))
end

local function BuildChildren()
    local parent = s_Parents[s_Parent.index or 1] or AllDistricts()
    local children = {}
    for _, location in ipairs(TeleportLocations.GetAll()) do
        if parent == AllDistricts() or location.parentDistrict == parent then
            table.insert(children, location.childDistrict or L("teleport.area_unknown"))
        end
    end
    s_Children = UniqueSorted(AllAreas(), children)
    s_Child.index = 1
end

local function RebuildViewData()
    local creators = {}
    local parents = {}
    for _, location in ipairs(TeleportLocations.GetAll()) do
        table.insert(creators, location.creator)
        table.insert(parents, location.parentDistrict or L("teleport.district_unknown"))
    end

    s_Creators = UniqueSorted(AllCreators(), creators)
    s_Parents = UniqueSorted(AllDistricts(), parents)
    s_Creator.index = 1
    s_Parent.index = 1
    BuildChildren()
    BuildQuickOptions()

    s_KnownCount = #TeleportLocations.GetAll()
    s_FilterKey = nil
end

local function Matches(location)
    local creator = s_Creators[s_Creator.index or 1]
    local parent = s_Parents[s_Parent.index or 1]
    local child = s_Children[s_Child.index or 1]

    if creator ~= AllCreators() and location.creator ~= creator then return false end
    if parent ~= AllDistricts() and location.parentDistrict ~= parent then return false end
    if child ~= AllAreas() and location.childDistrict ~= child then return false end
    return true
end

local function FilterCaption()
    local parent = s_Parents[s_Parent.index or 1]
    local child = s_Children[s_Child.index or 1]
    if child and child ~= AllAreas() then return child .. ", " .. tostring(parent) end
    if parent and parent ~= AllDistricts() then return parent end
    return "Night City"
end

local function RefreshCategories()
    local key = table.concat({ s_Creator.index, s_Parent.index, s_Child.index, s_KnownCount }, "|")
    if key == s_FilterKey and s_MapCategory == nil then return end
    s_FilterKey = key

    s_CategoryCounts = {}
    local matches = {}
    for _, location in ipairs(TeleportLocations.GetAll()) do
        if Matches(location) then
            s_CategoryCounts[location.category] = (s_CategoryCounts[location.category] or 0) + 1
            table.insert(matches, location)
        end
    end
    TeleportMap.SetPoints(matches, FilterCaption())
    s_MapCategory = nil

    local isPriority = {}
    for _, category in ipairs(TeleportLocations.GetPriority()) do isPriority[category] = true end

    local priority = {}
    local normal = {}
    for category in pairs(s_CategoryCounts) do
        table.insert(isPriority[category] and priority or normal, category)
    end
    table.sort(priority)
    table.sort(normal)

    s_Categories = priority
    for _, category in ipairs(normal) do table.insert(s_Categories, category) end
end

local function NearestVendor(category)
    local nearest = nil
    local nearestDistance = math.huge
    for _, vendor in ipairs(TeleportLocations.GetVendors()[category] or {}) do
        local distance = Teleport.DistanceFromPlayer(vendor.position)
        if distance < nearestDistance then nearest, nearestDistance = vendor, distance end
    end
    return nearest, nearest and nearestDistance or nil
end

local function QuickTarget(option)
    if option.Kind == "vendor" then
        local vendor, distance = NearestVendor(option.Key)
        return vendor and vendor.position, distance, vendor and vendor.name
    end
    return option.Position, Teleport.DistanceFromPlayer(option.Position), option.Key
end

local function DoQuickTeleport(option)
    local position, _, name = QuickTarget(option)
    if not position or not Teleport.TeleportEntity(Game.GetPlayer(), position) then return end

    if option.Kind == "vendor" then
        Notification.Info(L("teleport.quick_closest_vendor_notify") .. " " .. option.Key .. " (" .. name .. ")")
    else
        Notification.Info(L("teleport.quick_apartment_notify") .. ": " .. name)
    end
end

local function CategoryView()
    local refreshMap = s_MapCategory ~= s_CurrentCategory
    local points = refreshMap and {} or nil
    for _, location in ipairs(TeleportLocations.GetAll()) do
        if location.category == s_CurrentCategory and Matches(location) then
            if points then table.insert(points, location) end
            local distance = Settings.ShowCategoryDistance.value and FormatDistance(Teleport.DistanceFromPlayer(location.position)) or ""
            local _, data = Buttons.OptionExtended(location.name, "", distance ~= "" and distance or IconGlyphs.MapMarker, tip("teleport.teleportoption.tip", {
                creator = location.creator,
                category = location.category,
                district_parent = location.parentDistrict or "?",
                district_child = location.childDistrict or "?",
                location_name = location.name
            }), function()
                Teleport.TeleportEntity(Game.GetPlayer(), location.position)
            end)
            if data and data.Visible and (data.Selected or data.Hovered) then TeleportMap.Focus(location.position, location.name) end
        end
    end
    if points then
        s_MapCategory = s_CurrentCategory
        TeleportMap.SetPoints(points, s_CurrentCategory .. "  /  " .. FilterCaption())
    end
    if Settings.ShowMap.value then TeleportMap.Submit() end
end

local CategoryMenu = Submenu.Create("teleport.selectedteleports.label", CategoryView)

local function ReloadTeleports()
    TeleportLocations.Reload()
    RebuildViewData()
end

local function ClearRestrictions()
    local removed = Restrictions.RemoveStale() or 0
    Notification.Info(tip("teleport.clearrestrictions.done", { count = tostring(removed) }))
end

local function SettingsView()
    Buttons.Option(L("teleport.reloadteleports.label"), L("teleport.reloadteleports.tip"), ReloadTeleports)
    Buttons.Option(L("teleport.clearrestrictions.label"), L("teleport.clearrestrictions.tip"), ClearRestrictions)

    Buttons.Break(L("teleport.autoteleports.label"))
    Buttons.Toggle(L("teleport.autowaypoint.label"), AutoTeleport.Waypoint, L("teleport.autowaypoint.tip"))
    Buttons.Toggle(L("teleport.autoquest.label"), AutoTeleport.Quest, L("teleport.autoquest.tip"))

    Buttons.Break(L("teleport.settings.label"))
    Buttons.Toggle(L("teleport.showforward.label"), Settings.ShowForward, L("teleport.showforward.tip"))
    Buttons.Toggle(L("teleport.showquick.label"), Settings.ShowQuick, L("teleport.showquick.tip"))
    Buttons.Toggle(L("teleport.showquickdistance.label"), Settings.ShowQuickDistance, L("teleport.showquickdistance.tip"))
    Buttons.Toggle(L("teleport.showcategorydistance.label"), Settings.ShowCategoryDistance, L("teleport.showcategorydistance.tip"))
    Buttons.Toggle(L("teleport.showdistrictfilter.label"), Settings.ShowDistrictFilter, L("teleport.showdistrictfilter.tip"))
    Buttons.Toggle(L("teleport.showcreatorfilter.label"), Settings.ShowCreatorFilter, L("teleport.showcreatorfilter.tip"))
    Buttons.Toggle(L("teleport.showmap.label"), Settings.ShowMap, L("teleport.showmap.tip"))
end

local SettingsMenu = Submenu.Create("teleport.settingssubmenu.label", SettingsView)

local function DrawQuickCycler()
    local option = s_QuickOptions[s_Quick.index]
    local label = L("teleport.quickcycler.label")
    if Settings.ShowQuickDistance.value and option then
        local _, distance = QuickTarget(option)
        label = label .. " (" .. FormatDistance(distance) .. ")"
    end

    if Buttons.StringCyclerClick(label, s_Quick, s_QuickLabels, L("teleport.quickcycler.tip")) and option then
        DoQuickTeleport(option)
    end
end

local function LocationsView()
    if Settings.ShowCreatorFilter.value or Settings.ShowDistrictFilter.value then
        Buttons.Break(L("teleport.filters.label"))
        if Settings.ShowDistrictFilter.value then
            if Buttons.StringCycler(L("teleport.district.label"), s_Parent, s_Parents, L("teleport.district.tip")) then BuildChildren() end
            Buttons.StringCycler(L("teleport.area.label"), s_Child, s_Children, L("teleport.area.tip"))
        end
        if Settings.ShowCreatorFilter.value then
            Buttons.Dropdown(L("teleport.creator.label"), s_Creator, s_Creators, L("teleport.creator.tip"))
        end
    end

    Buttons.Break()
    RefreshCategories()
    if #s_Categories == 0 then
        Buttons.Option(L("teleport.selectedteleports.label"), "", function() end)
    end
    for _, category in ipairs(s_Categories) do
        Buttons.Submenu(category .. "  [" .. tostring(s_CategoryCounts[category]) .. "]", CategoryMenu,
            tip("teleport.categorysubmenu.tip", { category = category }), function() s_CurrentCategory = category end)
    end
    if Settings.ShowMap.value then TeleportMap.Submit() end
end

local function TeleportView()
    if s_KnownCount ~= #TeleportLocations.GetAll() then RebuildViewData() end

    Buttons.Submenu(L("teleport.customteleports.label"), CustomTeleportView, L("teleport.customteleportview.save.tip"))
    Buttons.Submenu(L("teleport.miscsubmenu.label"), SettingsMenu, L("teleport.miscsubmenu.tip"))
    Buttons.Break("")
    Buttons.Option(L("teleport.questmarker.label"), L("teleport.questmarker.tip"), Teleport.ToQuestMarker)
    Buttons.Option(L("teleport.waypointmarker.label"), L("teleport.waypointmarker.tip"), Teleport.ToWaypoint)

    if Settings.ShowForward.value then
        Buttons.Int(L("teleport.forwarddistance.label"), Settings.ForwardDistance, L("teleport.forwarddistance.tip"))
        Buttons.Option(L("teleport.teleportforward.label"), L("teleport.teleportforward.tip"), Settings.TeleportForward)
    end

    if Settings.ShowQuick.value then DrawQuickCycler() end

    LocationsView()
end

return Submenu.Create("teleport.title", TeleportView)
