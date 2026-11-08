local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Teleports = require("Features/Teleports/Teleports")
local Locations = require("Features/Teleports/Locations")
local MapPinsView = require("View/Teleports/MapPinsView")

local LocationsView = {}

local s_Menus = {}
local s_Badges = setmetatable({}, { __mode = "k" })

local function Info(location)
    if location.Doc and location.DocMap == Teleports.ShowMap then return location.Doc end

    location.DocMap = Teleports.ShowMap
    location.Doc = {
        { Kind = "Eyebrow", Text = location.Category },
        { Kind = "Title", Text = location.Name },
        { Kind = "Separator" },
        { Kind = "Row", Label = L("teleports.info.district"), Value = location.District },
        { Kind = "Row", Label = L("teleports.info.area"), Value = location.Area }
    }
    if location.Place then
        table.insert(location.Doc, { Kind = "Row", Label = L("teleports.info.place"), Value = location.Place })
    end
    table.insert(location.Doc, { Kind = "Text", Text = tip("teleports.info.by", { creator = location.Creator }), Tone = "Soft" })
    if Teleports.ShowMap then
        table.insert(location.Doc, { Kind = "Map", Focus = location, Player = Teleports.Player })
    end
    return location.Doc
end

function LocationsView.Row(location, fallback)
    if Widgets.ValueRow(location.Name, MapPinsView.Value(location, fallback), true) then Teleports.To(location) end
    Widgets.Tip(L("teleports.pin.tip"))
    MapPinsView.Info(Info, location)
end

local function CategoryView(category)
    Teleports.Watch()

    local locations = Teleports.List(category.Locations)
    local spots = Teleports.SavedIn(category.Name)
    if #locations + #spots == 0 then
        Widgets.ValueRow(L("teleports.none"), "")
        return
    end
    for _, spot in ipairs(spots) do MapPinsView.SpotRow(spot) end
    for _, location in ipairs(locations) do LocationsView.Row(location, location.Area) end
end

local function CategoryMenu(category)
    local key = category.Creator .. "/" .. category.Name
    local menu = s_Menus[key]
    if menu then return menu end

    menu = Submenu.Create(category.Name, function() CategoryView(category) end)
    s_Menus[key] = menu
    return menu
end

local function CategoryOverview(category)
    return MapPinsView.Overview(category, category.Name, category.Locations)
end

local function Badge(category, count)
    local badge = s_Badges[category]
    if not badge or badge.Count ~= count then
        badge = { Count = count, Text = tostring(count) }
        s_Badges[category] = badge
    end
    return badge.Text
end

local function Count(category)
    return #Teleports.Filtered(category.Locations) + #Teleports.SavedIn(category.Name)
end

local function Shown(creator)
    for _, category in ipairs(creator.Categories) do
        if Count(category) > 0 then return true end
    end
    return false
end

function LocationsView.Creators()
    if not Locations.Loaded then return end

    for _, creator in ipairs(Locations.Creators) do
        if Shown(creator) then
            Widgets.Break(creator.Name)
            for _, category in ipairs(creator.Categories) do
                local count = Count(category)
                if count > 0 then
                    Widgets.SubmenuButton(category.Name, CategoryMenu(category), Badge(category, count))
                    MapPinsView.Info(CategoryOverview, category, true)
                end
            end
        end
    end
end

return LocationsView
