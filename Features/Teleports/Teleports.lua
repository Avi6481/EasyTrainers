local Logger = require("Core/Logger")
local Landing = require("Utils/Landing")
local Notify = require("Utils/Notify")
local Teleport = require("Utils/Teleport")
local MapPins = require("Features/Teleports/MapPins")
local Markers = require("Features/Teleports/Markers")
local Locations = require("Features/Teleports/Locations")
local Distances = require("Features/Teleports/Distances")
local Listing = require("Features/Teleports/Listing")
local Auto = require("Features/Teleports/Auto")
local Nearest = require("Features/Teleports/Nearest")
local Categories = require("Features/Teleports/Categories")

local Teleports = {
    SafeLanding = false,
    ShowUndiscovered = false,
    AutoWaypoint = false,
    AutoObjective = false,
    ForwardDistance = 5,
    SortBy = "Closest",
    District = "",
    Area = "",
    NearestType = Nearest.Default,
    ShowDistance = true,
    ShowPanel = true,
    ShowMap = true,
    Custom = {},
    Districts = {},
    Areas = {},
    Player = { X = 0, Y = 0, Known = false }
}

Teleports.Sorts = Listing.Sorts

local OWNER = "Teleport"
local WATCH_TIME = 1
local DISTANCE_INTERVAL = 1
local SAFE_LANDING = 4

local s_Queue = {}
local s_WatchUntil = 0
local s_Watching = false
local s_CollectedUndiscovered = nil
local s_NextDistance = 0
local s_LandingUntil = 0
local s_Failed = {}
local s_Remeasure = false
local s_AreaDistrict = nil

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

function Teleports.Distance(item)
    return Distances.Text(item)
end

local function AreaLists()
    return { MapPins.All, Locations.All }
end

local function SyncArea()
    if Teleports.District == s_AreaDistrict then return end
    if s_AreaDistrict ~= nil then Teleports.Area = "" end
    s_AreaDistrict = Teleports.District
    Teleports.Areas = Listing.Areas(AreaLists(), Teleports.District)
end

function Teleports.AreaList()
    SyncArea()
    return Teleports.Areas
end

function Teleports.Filtered(list)
    SyncArea()
    return Listing.Filter(list, Teleports.District, Teleports.Area)
end

function Teleports.List(list)
    return Listing.Sort(Teleports.Filtered(list), Teleports.SortBy)
end

function Teleports.Saved()
    local loose = Categories.Group(Teleports.Custom)
    return Listing.Sort(loose, Teleports.SortBy, true)
end

function Teleports.SavedGroups()
    local _, groups = Categories.Group(Teleports.Custom)
    return groups
end

function Teleports.SavedIn(category)
    return Listing.Sort(Categories.Spots(Teleports.Custom, category), Teleports.SortBy, true)
end

function Teleports.CategoryChoices(current)
    return Categories.Choices(current)
end

function Teleports.NearestTypes()
    return Nearest.Available()
end

function Teleports.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

local function Go(player, place)
    Teleport.To(player, place.X, place.Y, place.Z)
    if Teleports.SafeLanding then
        Landing.Hold(OWNER, true)
        s_LandingUntil = os.clock() + SAFE_LANDING
    end
end

function Teleports.To(place)
    table.insert(s_Queue, function(player) Go(player, place) end)
end

function Teleports.ToWaypoint()
    table.insert(s_Queue, function(player)
        local place = Markers.Waypoint()
        if not place then return Notify.Warning(L("teleports.waypoint.none")) end
        Go(player, place)
    end)
end

function Teleports.ToObjective()
    table.insert(s_Queue, function(player)
        local place = Markers.Objective(player)
        if not place then return Notify.Warning(L("teleports.objective.none")) end
        Go(player, place)
    end)
end

function Teleports.ToNearest()
    table.insert(s_Queue, function(player)
        if not MapPins.Ready then MapPins.Collect(Teleports.ShowUndiscovered) end
        if not Nearest.Valid(Teleports.NearestType) then Teleports.NearestType = Nearest.Default end

        local pin, section = Nearest.Find(Teleports.NearestType, player:GetWorldPosition())
        if not pin then return Notify.Warning(L("teleports.teleportto.none")) end
        Go(player, pin)
        Notify.Info(tip("teleports.teleportto.done", { name = pin.Name, type = section.Label }))
    end)
end

function Teleports.Forward()
    table.insert(s_Queue, function(player)
        local position = player:GetWorldPosition()
        local forward = player:GetWorldForward()
        local distance = Teleports.ForwardDistance
        Go(player, {
            X = position.x + (forward.x * distance),
            Y = position.y + (forward.y * distance),
            Z = position.z
        })
    end)
end

function Teleports.Capture()
    table.insert(s_Queue, function()
        local read, added, total = MapPins.Capture()
        Notify.Info(tip("teleports.capture.done", { read = read, added = added, total = total }))
        s_Watching = false
    end)
end

function Teleports.SaveHere(name)
    table.insert(s_Queue, function(player)
        local position = player:GetWorldPosition()
        if not name or name == "" then name = tip("teleports.custom.default", { count = #Teleports.Custom + 1 }) end
        table.insert(Teleports.Custom, {
            Name = name,
            X = position.x,
            Y = position.y,
            Z = position.z,
            Category = ""
        })
        s_Remeasure = true
    end)
end

function Teleports.MoveHere(spot)
    table.insert(s_Queue, function(player)
        local position = player:GetWorldPosition()
        spot.X = position.x
        spot.Y = position.y
        spot.Z = position.z
        s_Remeasure = true
    end)
end

function Teleports.Delete(spot)
    for index, saved in ipairs(Teleports.Custom) do
        if saved == spot then
            table.remove(Teleports.Custom, index)
            return
        end
    end
end

function Teleports.Bind(store)
    store:Bind("Teleports", Teleports, {
        "SafeLanding", "ShowUndiscovered", "AutoWaypoint", "AutoObjective", "ForwardDistance", "SortBy", "District", "Area",
        "NearestType", "ShowDistance", "ShowPanel", "ShowMap", "Custom"
    })
end

function Teleports.Initialize()
    if not Nearest.Valid(Teleports.NearestType) then Teleports.NearestType = Nearest.Default end
    Landing.Initialize()
end

local function RunQueue(player)
    local queue = s_Queue
    s_Queue = {}
    for _, action in ipairs(queue) do Try("Teleport", action, player) end
end

local function Match(list, value, same)
    for _, item in ipairs(list) do
        if item == value or (same and same(item, value)) then return item end
    end
    return ""
end

local function Districts()
    local lists = AreaLists()
    local districts = Listing.Districts(lists)
    Teleports.Districts = districts
    if #districts == 0 then return end

    if Teleports.District ~= "" then Teleports.District = Match(districts, Teleports.District) end
    s_AreaDistrict = Teleports.District

    local areas = Listing.Areas(lists, Teleports.District)
    Teleports.Areas = areas
    if Teleports.Area ~= "" then Teleports.Area = Match(areas, Teleports.Area, Listing.SameArea) end
end

local function Measure(player)
    local position = player:GetWorldPosition()
    Teleports.Player.X = position.x
    Teleports.Player.Y = position.y
    Teleports.Player.Known = true
    Distances.Update(position, { Teleports.Custom, MapPins.All, Locations.All }, s_Remeasure)
end

local function Watched(player, now)
    if not s_Watching or s_CollectedUndiscovered ~= Teleports.ShowUndiscovered then
        s_Watching = true
        s_CollectedUndiscovered = Teleports.ShowUndiscovered
        s_Remeasure = true
        Try("Map pins", MapPins.Collect, Teleports.ShowUndiscovered)
    end
    if not Locations.Loaded then
        s_Remeasure = true
        Try("Locations", Locations.Load)
    end
    if s_Remeasure then Try("Districts", Districts) end

    if s_Remeasure or now >= s_NextDistance then
        s_NextDistance = now + DISTANCE_INTERVAL
        Try("Distances", Measure, player)
        s_Remeasure = false
    end
end

local function AutoGo(player, place, kind)
    Go(player, place)
    if kind == "Objective" then Notify.Info(L("teleports.autoobjective.done")) end
end

function Teleports.Update(player)
    local now = os.clock()
    Try("Auto teleport", Auto.Update, player, now, Teleports.AutoWaypoint, Teleports.AutoObjective, AutoGo)

    if s_LandingUntil > 0 and now >= s_LandingUntil then
        s_LandingUntil = 0
        Landing.Hold(OWNER, false)
    end

    if #s_Queue > 0 then RunQueue(player) end

    if now < s_WatchUntil then
        Watched(player, now)
    elseif s_Watching then
        s_Watching = false
    end
end

function Teleports.Reset()
    s_Queue = {}
    s_Watching = false
    s_LandingUntil = 0
    Landing.Hold(OWNER, false)
    MapPins.Clear()
    Distances.Reset()
end

function Teleports.Shutdown()
    s_Queue = {}
    Landing.Hold(OWNER, false)
end

return Teleports
