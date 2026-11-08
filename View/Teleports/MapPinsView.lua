local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Teleports = require("Features/Teleports/Teleports")
local MapPins = require("Features/Teleports/MapPins")

local MapPinsView = {}

local s_Menus = {}
local s_Overviews = setmetatable({}, { __mode = "k" })
local s_SpotDocs = setmetatable({}, { __mode = "k" })

function MapPinsView.Info(build, value, map)
    if not Teleports.ShowPanel or (map and not Teleports.ShowMap) then return end
    Widgets.Info(build, value)
end

function MapPinsView.Value(item, fallback)
    if Teleports.ShowDistance then return Teleports.Distance(item) end
    return fallback or ""
end

local function PinInfo(pin)
    if pin.Doc and pin.DocMap == Teleports.ShowMap then return pin.Doc end

    pin.DocMap = Teleports.ShowMap
    pin.Doc = {
        { Kind = "Eyebrow", Text = pin.Kind },
        { Kind = "Title", Text = pin.Name },
        { Kind = "Separator" }
    }
    if pin.District then
        table.insert(pin.Doc, { Kind = "Row", Label = L("teleports.info.district"), Value = pin.District })
    end
    if pin.Area and pin.Area ~= pin.Name then
        table.insert(pin.Doc, { Kind = "Row", Label = L("teleports.info.area"), Value = pin.Area })
    end
    table.insert(pin.Doc, {
        Kind = "Row",
        Label = L("teleports.info.status"),
        Value = L("teleports.info." .. pin.Status),
        Tone = pin.Status == "undiscovered" and "Soft" or "Text"
    })
    if Teleports.ShowMap then table.insert(pin.Doc, { Kind = "Map", Focus = pin, Player = Teleports.Player }) end
    return pin.Doc
end

function MapPinsView.Overview(owner, title, list)
    local points = Teleports.Filtered(list)
    local cached = s_Overviews[owner]
    if cached and cached.Points == points then return cached.Doc end

    cached = {
        Points = points,
        Doc = {
            { Kind = "Eyebrow", Text = L("teleports.info.map") },
            { Kind = "Title", Text = title },
            { Kind = "Separator" },
            { Kind = "Map", Points = points, Player = Teleports.Player }
        }
    }
    s_Overviews[owner] = cached
    return cached.Doc
end

function MapPinsView.Row(pin)
    if Widgets.ValueRow(pin.Name, MapPinsView.Value(pin, pin.Tag), true) then Teleports.To(pin) end
    Widgets.Tip(L("teleports.pin.tip"))
    MapPinsView.Info(PinInfo, pin)
end

local function SpotInfo(spot)
    local cached = s_SpotDocs[spot]
    if cached and cached.Name == spot.Name and cached.Category == spot.Category and cached.X == spot.X and cached.Y == spot.Y
        and cached.Map == Teleports.ShowMap then
        return cached.Doc
    end

    local category = spot.Category or ""
    cached = {
        Name = spot.Name,
        Category = spot.Category,
        X = spot.X,
        Y = spot.Y,
        Map = Teleports.ShowMap,
        Doc = {
            { Kind = "Eyebrow", Text = category ~= "" and category or L("teleports.custom.eyebrow") },
            { Kind = "Title", Text = spot.Name }
        }
    }
    if cached.Map then
        table.insert(cached.Doc, { Kind = "Separator" })
        table.insert(cached.Doc, { Kind = "Map", Focus = spot, Player = Teleports.Player })
    end
    s_SpotDocs[spot] = cached
    return cached.Doc
end

function MapPinsView.SpotRow(spot)
    if Widgets.ValueRow(spot.Name, MapPinsView.Value(spot), true) then Teleports.To(spot) end
    Widgets.Tip(L("teleports.pin.tip"))
    MapPinsView.Info(SpotInfo, spot)
end

function MapPinsView.Count(section)
    return #Teleports.Filtered(section.All) + #Teleports.SavedIn(section.Label)
end

local function SectionView(sectionId)
    Teleports.Watch()

    local section = MapPins.Ready and MapPins.Sections[sectionId]
    local pins = section and Teleports.List(section.All)
    local spots = section and Teleports.SavedIn(section.Label)
    if not pins or #pins + #spots == 0 then
        Widgets.ValueRow(L(MapPins.Ready and "teleports.none" or "teleports.loading"), "")
        return
    end
    for _, spot in ipairs(spots) do MapPinsView.SpotRow(spot) end
    for _, pin in ipairs(pins) do MapPinsView.Row(pin) end
end

function MapPinsView.Menu(section)
    local menu = s_Menus[section.Id]
    if menu then return menu end

    menu = Submenu.Create(section.Label, function() SectionView(section.Id) end)
    s_Menus[section.Id] = menu
    return menu
end

return MapPinsView
