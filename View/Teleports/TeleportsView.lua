local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Teleports = require("Features/Teleports/Teleports")
local MapPins = require("Features/Teleports/MapPins")
local Locations = require("Features/Teleports/Locations")
local MapPinsView = require("View/Teleports/MapPinsView")
local LocationsView = require("View/Teleports/LocationsView")
local TeleportSettingsView = require("View/Teleports/TeleportSettingsView")

local TeleportsView = {}

local MAX_MATCHES = 150
local MAX_NAME = 40

local GROUPS = {
    Locations = MapPins.SectionIds("Locations"),
    Vendors = MapPins.SectionIds("Vendors"),
    Activities = MapPins.SectionIds("Activities")
}

local s_State = {
    Query = "",
    Name = ""
}

local s_Query = Ref.Field(s_State, "Query")
local s_Name = Ref.Field(s_State, "Name")
local s_Matches = {}
local s_MatchedQuery = nil
local s_MatchedPins = nil
local s_MatchedLocations = 0
local s_Badges = {}
local s_NearestSource = nil
local s_NearestItems = {}
local s_Nearest = nil

local function Count(section)
    return MapPinsView.Count(section)
end

local function Badge(section, count)
    local badge = s_Badges[section.Id]
    if not badge or badge.Count ~= count then
        badge = { Count = count, Text = tostring(count) }
        s_Badges[section.Id] = badge
    end
    return badge.Text
end

local function Matches()
    local query = s_State.Query
    if s_MatchedQuery ~= query or s_MatchedPins ~= MapPins.All or s_MatchedLocations ~= #Locations.All then
        s_Matches = {}
        s_MatchedQuery = query
        s_MatchedPins = MapPins.All
        s_MatchedLocations = #Locations.All

        for _, pin in ipairs(MapPins.All) do
            if Widgets.SearchMatch(pin.Search, query) then table.insert(s_Matches, pin) end
        end
        for _, location in ipairs(Locations.All) do
            if Widgets.SearchMatch(location.Search, query) then table.insert(s_Matches, location) end
        end
    end
    return Teleports.List(s_Matches)
end

local function Results(matches)
    for index, match in ipairs(matches) do
        if index > MAX_MATCHES then
            Widgets.ValueRow(L("teleports.search.more"), "")
            return
        end
        if match.Creator then
            LocationsView.Row(match, match.Category)
        else
            MapPinsView.Row(match)
        end
    end
    if #matches == 0 then Widgets.ValueRow(L("teleports.search.none"), "") end
end

local function SectionOverview(section)
    return MapPinsView.Overview(section, section.Label, section.All)
end

local function SectionLinks(ids)
    for _, id in ipairs(ids) do
        local section = MapPins.Sections[id]
        local count = section and Count(section) or 0
        if count > 0 then
            Widgets.SubmenuButton(section.Label, MapPinsView.Menu(section), Badge(section, count))
            Widgets.Tip(L(section.Key and ("teleports.sections." .. section.Key .. ".tip") or "teleports.group.tip"))
            MapPinsView.Info(SectionOverview, section, true)
        end
    end
end

local function HasAny(ids)
    for _, id in ipairs(ids) do
        local section = MapPins.Sections[id]
        if section and Count(section) > 0 then return true end
    end
    return false
end

local function Group(key, ids)
    if not HasAny(ids) then return end
    Widgets.Break(L(key))
    SectionLinks(ids)
end

local function YourLocations()
    if Widgets.InputText(L("teleports.custom.save.label"), s_Name, MAX_NAME, L("teleports.custom.save.placeholder")) then
        Teleports.SaveHere(s_State.Name)
        s_State.Name = ""
    end
    Widgets.Tip(L("teleports.custom.save.tip"))

    for _, spot in ipairs(Teleports.Saved()) do MapPinsView.SpotRow(spot) end
end

local function SavedGroups()
    for _, group in ipairs(Teleports.SavedGroups()) do
        Widgets.Break(group.Name)
        for _, spot in ipairs(Teleports.SavedIn(group.Name)) do MapPinsView.SpotRow(spot) end
    end
end

local function NearestItems()
    local types = Teleports.NearestTypes()
    if s_NearestSource == types then return s_NearestItems end

    s_NearestSource = types
    s_NearestItems = {}
    for index, id in ipairs(types) do
        s_NearestItems[index] = { Label = MapPins.Sections[id].Label, Tip = "" }
    end
    s_Nearest = Ref.Choice(Teleports, "NearestType", types)
    return s_NearestItems
end

local function TeleportTo()
    if not MapPins.Ready then return end

    local items = NearestItems()
    if #items == 0 then return end
    if Widgets.Dropdown(L("teleports.teleportto.label"), s_Nearest, items, nil, true) then Teleports.ToNearest() end
    Widgets.Tip(L("teleports.teleportto.tip"))
end

local function View()
    Teleports.Watch()

    local searching = s_State.Query ~= ""
    local matches = searching and Matches() or nil
    Widgets.SearchRow(s_Query, L("teleports.search.placeholder"), matches and #matches or -1)
    if matches then
        Results(matches)
        return
    end

    Widgets.SubmenuButton(L("teleports.settings.label"), TeleportSettingsView.Menu)
    Widgets.Tip(L("teleports.settings.tip"))
    if Widgets.Button(L("teleports.waypoint.label")) then Teleports.ToWaypoint() end
    Widgets.Tip(L("teleports.waypoint.tip"))
    if Widgets.Button(L("teleports.objective.label")) then Teleports.ToObjective() end
    Widgets.Tip(L("teleports.objective.tip"))
    TeleportTo()

    Widgets.Break(L("teleports.locations"))
    YourLocations()
    if MapPins.Ready then
        SectionLinks(GROUPS.Locations)
    else
        Widgets.ValueRow(L("teleports.loading"), "")
    end
    SavedGroups()

    Group("teleports.vendors", GROUPS.Vendors)
    Group("teleports.activities", GROUPS.Activities)
    LocationsView.Creators()
end

TeleportsView.Menu = Submenu.Create("teleports.title", View)

return TeleportsView
