local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Teleports = require("Features/Teleports/Teleports")

local TeleportSettingsView = {}

local MAX_NAME = 40

local s_SafeLanding = Ref.Field(Teleports, "SafeLanding")
local s_ShowUndiscovered = Ref.Field(Teleports, "ShowUndiscovered")
local s_AutoWaypoint = Ref.Field(Teleports, "AutoWaypoint")
local s_AutoObjective = Ref.Field(Teleports, "AutoObjective")
local s_ForwardDistance = Ref.Field(Teleports, "ForwardDistance")
local s_SortBy = Ref.Choice(Teleports, "SortBy", Teleports.Sorts)
local s_ShowDistance = Ref.Field(Teleports, "ShowDistance")
local s_ShowPanel = Ref.Field(Teleports, "ShowPanel")
local s_ShowMap = Ref.Field(Teleports, "ShowMap")
local s_Spots = setmetatable({}, { __mode = "k" })
local s_SortItems = nil
local s_DistrictSource = nil
local s_DistrictItems = nil
local s_District = nil
local s_AreaSource = nil
local s_AreaItems = nil
local s_Area = nil

local function SortItems()
    if s_SortItems then return s_SortItems end

    s_SortItems = {}
    for index, sort in ipairs(Teleports.Sorts) do
        local key = "teleports.sorts." .. sort:lower()
        s_SortItems[index] = { Label = L(key .. ".label"), Tip = L(key .. ".tip") }
    end
    return s_SortItems
end

local function DistrictItems()
    if s_DistrictSource == Teleports.Districts then return s_DistrictItems end

    s_DistrictSource = Teleports.Districts
    local values = { "" }
    s_DistrictItems = { { Label = L("teleports.district.all"), Tip = "" } }
    for _, district in ipairs(Teleports.Districts) do
        table.insert(values, district)
        table.insert(s_DistrictItems, { Label = district, Tip = "" })
    end
    s_District = Ref.Choice(Teleports, "District", values)
    return s_DistrictItems
end

local function AreaItems()
    local areas = Teleports.AreaList()
    if s_AreaSource == areas then return s_AreaItems end

    s_AreaSource = areas
    local values = { "" }
    s_AreaItems = { { Label = L("teleports.area.all"), Tip = "" } }
    for _, area in ipairs(areas) do
        table.insert(values, area)
        table.insert(s_AreaItems, { Label = area, Tip = "" })
    end
    s_Area = Ref.Choice(Teleports, "Area", values)
    return s_AreaItems
end

local function CategoryItems(entry, spot)
    local values = Teleports.CategoryChoices(spot.Category)
    if entry.CategorySource == values then return entry.CategoryItems end

    entry.CategorySource = values
    entry.CategoryItems = { { Label = L("teleports.spot.category.none"), Tip = "" } }
    for index = 2, #values do entry.CategoryItems[index] = { Label = values[index], Tip = "" } end
    entry.Category = Ref.Choice(spot, "Category", values)
    return entry.CategoryItems
end

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function SpotView(spot)
    Teleports.Watch()

    local entry = s_Spots[spot]

    Widgets.InputText(L("teleports.spot.name.label"), entry.Name, MAX_NAME, L("teleports.spot.name.placeholder"))
    Widgets.Tip(L("teleports.spot.name.tip"))

    local categories = CategoryItems(entry, spot)
    Widgets.Dropdown(L("teleports.spot.category.label"), entry.Category, categories)
    Widgets.Tip(L("teleports.spot.category.tip"))

    if Widgets.Button(L("teleports.spot.teleport.label")) then Teleports.To(spot) end
    Widgets.Tip(L("teleports.spot.teleport.tip"))

    if Widgets.HoldButton(L("teleports.spot.movehere.label")) then Teleports.MoveHere(spot) end
    Widgets.Tip(L("teleports.spot.movehere.tip"))

    if Widgets.HoldButton(L("teleports.spot.delete.label")) then
        Teleports.Delete(spot)
        Submenu.Close()
    end
    Widgets.Tip(L("teleports.spot.delete.tip"))
end

local function SpotMenu(spot)
    local entry = s_Spots[spot]
    if entry then return entry.Menu end

    entry = { Name = Ref.Field(spot, "Name") }
    entry.Menu = Submenu.Create("teleports.spot.title", function() SpotView(spot) end)
    s_Spots[spot] = entry
    return entry.Menu
end

local function List()
    Widgets.Break(L("teleports.list"))
    Widgets.Dropdown(L("teleports.sortby.label"), s_SortBy, SortItems())
    Widgets.Tip(L("teleports.sortby.tip"))
    local districts = DistrictItems()
    Widgets.Dropdown(L("teleports.district.label"), s_District, districts)
    Widgets.Tip(L("teleports.district.tip"))
    local areas = AreaItems()
    Widgets.Dropdown(L("teleports.area.label"), s_Area, areas)
    Widgets.Tip(L("teleports.area.tip"))
    Toggle("teleports.showdistance", s_ShowDistance)
    Toggle("teleports.showundiscovered", s_ShowUndiscovered)

    Widgets.Break(L("teleports.panel"))
    Toggle("teleports.showpanel", s_ShowPanel)
    Toggle("teleports.showmap", s_ShowMap)
end

local function Saved()
    Widgets.Break(L("teleports.custom.title"))
    if #Teleports.Custom == 0 then
        Widgets.ValueRow(L("teleports.custom.none"), "")
        return
    end
    for _, spot in ipairs(Teleports.Custom) do
        Widgets.SubmenuButton(spot.Name, SpotMenu(spot))
        Widgets.Tip(L("teleports.custom.edittip"))
    end
end

local function View()
    Teleports.Watch()

    if Widgets.NumberActionFloat(L("teleports.forward.label"), s_ForwardDistance, 1, 100, 1, "%.0f m") then Teleports.Forward() end
    Widgets.Tip(L("teleports.forward.tip"))
    Toggle("teleports.autowaypoint", s_AutoWaypoint)
    Toggle("teleports.autoobjective", s_AutoObjective)
    Toggle("teleports.safelanding", s_SafeLanding)
    List()
    Saved()

    Widgets.Break(L("teleports.debug"))
    if Widgets.Button(L("teleports.capture.label")) then Teleports.Capture() end
    Widgets.Tip(L("teleports.capture.tip"))
end

TeleportSettingsView.Menu = Submenu.Create("teleports.settings.label", View)

return TeleportSettingsView
