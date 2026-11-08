local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Weapons = require("Features/Weapons/Weapons")
local Catalog = require("Features/Weapons/Catalog")
local Arsenal = require("Features/Weapons/Arsenal")
local WeaponItemInfo = require("View/Weapons/WeaponItemInfo")

local WeaponItemsView = {}

local MIN_QUANTITY = 1
local SORTS = { "name", "tierhigh", "tierlow", "owned" }

local function ByName(first, second)
    if first.Order ~= second.Order then return first.Order < second.Order end
    return first.Id < second.Id
end

local SORTERS = {
    name = ByName,
    tierhigh = function(first, second)
        if first.Weight ~= second.Weight then return first.Weight > second.Weight end
        return ByName(first, second)
    end,
    tierlow = function(first, second)
        if first.Weight ~= second.Weight then return first.Weight < second.Weight end
        return ByName(first, second)
    end,
    owned = function(first, second)
        local left, right = Arsenal.Count(first), Arsenal.Count(second)
        if left ~= right then return left > right end
        return ByName(first, second)
    end
}

local s_Classes = { false }
for _, name in ipairs(Catalog.CLASSES) do table.insert(s_Classes, name) end

local s_Sort = { Index = 1 }
local s_SortRef = Ref.Field(s_Sort, "Index")
local s_ActionRef = Ref.Choice(Arsenal, "Action", Arsenal.ACTIONS)
local s_QuantityRef = Ref.Field(Arsenal, "Quantity")
local s_Search = { Query = "" }
local s_SearchRef = Ref.Field(s_Search, "Query")
local s_Items = {}
local s_Values = {}
local s_ValueSummary = nil
local s_TypePages = {}
local s_SlotLabels = nil
local s_Version = nil

local function Watch()
    Weapons.Watch()
    Arsenal.Watch()
end

local function Clear(page)
    page.List = nil
    page.TierItems = nil
    page.Result = nil
end

local function Fresh()
    if s_Version == Catalog.Version then return end
    s_Version = Catalog.Version
    for _, page in pairs(s_TypePages) do
        Clear(page)
        page.Badge = nil
    end
end

local function Loading()
    if Catalog.Loaded then
        Fresh()
        return false
    end
    Widgets.ValueRow(L("weapons.items.loading.label"), "")
    Widgets.Tip(L("weapons.items.loading.tip"))
    return true
end

local function Source(page)
    if page.Live and (page.SeenChanges ~= Arsenal.Changes or page.SeenReady ~= Arsenal.Ready or page.SeenVersion ~= Catalog.Version) then
        page.SeenChanges = Arsenal.Changes
        page.SeenReady = Arsenal.Ready
        page.SeenVersion = Catalog.Version
        page.List = nil
    end
    if page.List and page.ListVersion == Catalog.Version then return page.List end

    page.List = page.Build()
    page.ListVersion = Catalog.Version
    page.TierItems = nil
    page.Result = nil
    return page.List
end

local function TierOrder(first, second)
    local left, right = Catalog.Weight(first), Catalog.Weight(second)
    if left ~= right then return left > right end
    return first < second
end

local function Tiers(page, source)
    if page.TierItems then return page.TierItems end

    local selected = page.TierNames and page.TierNames[page.Tier - 1]
    local seen, names = {}, {}
    for _, weapon in ipairs(source) do
        if not seen[weapon.Tier] then
            seen[weapon.Tier] = true
            table.insert(names, weapon.Tier)
        end
    end
    table.sort(names, TierOrder)

    local items = { { Label = L("weapons.items.filters.all"), Tip = "" } }
    page.Tier = 1
    for index, name in ipairs(names) do
        items[index + 1] = { Label = name, Tip = "" }
        if name == selected then page.Tier = index + 1 end
    end
    page.TierNames = names
    page.TierItems = items
    return items
end

local function Visible(page)
    local source = Source(page)
    local tiers = Tiers(page, source)
    page.Tier = math.max(1, math.min(page.Tier, #tiers))
    if page.Result and page.ResultTier == page.Tier and page.ResultClass == page.Class and page.ResultSort == s_Sort.Index
        and page.ResultChanges == Arsenal.Changes and page.ResultReady == Arsenal.Ready then
        return page.Result
    end

    local tier = page.TierNames[page.Tier - 1]
    local class = s_Classes[page.Class]
    local result = {}
    for _, weapon in ipairs(source) do
        if (not tier or weapon.Tier == tier) and (not class or weapon.Class == class) then table.insert(result, weapon) end
    end
    table.sort(result, SORTERS[SORTS[s_Sort.Index]] or ByName)

    page.Result = result
    page.ResultTier = page.Tier
    page.ResultClass = page.Class
    page.ResultSort = s_Sort.Index
    page.ResultChanges = Arsenal.Changes
    page.ResultReady = Arsenal.Ready
    page.Heading = tip("weapons.items.count", { count = #result, title = page.Title })
    return result
end

local function ActionItems()
    if s_Items.Action then return s_Items.Action end

    s_Items.Action = {
        { Label = L("weapons.items.action.add"), Tip = L("weapons.items.action.addtip") },
        { Label = L("weapons.items.action.remove"), Tip = L("weapons.items.action.removetip") }
    }
    return s_Items.Action
end

local function ClassItems()
    if s_Items.Class then return s_Items.Class end

    local items = { { Label = L("weapons.items.filters.all"), Tip = "" } }
    for _, name in ipairs(Catalog.CLASSES) do
        table.insert(items, { Label = L("weapons.items.classes." .. name:lower()), Tip = "" })
    end
    s_Items.Class = items
    return items
end

local function SortItems()
    if s_Items.Sort then return s_Items.Sort end

    local items = {}
    for index, key in ipairs(SORTS) do items[index] = { Label = L("weapons.items.sort." .. key), Tip = "" } end
    s_Items.Sort = items
    return items
end

local function Values()
    local summary = Arsenal.Summary()
    if summary == s_ValueSummary then return end
    s_ValueSummary = summary
    s_Values = {}
end

local function Value(owned)
    local text = s_Values[owned]
    if text then return text end

    text = owned > 0 and ("x" .. tostring(owned) .. "  " .. s_ValueSummary) or s_ValueSummary
    s_Values[owned] = text
    return text
end

local function Empty(key)
    Widgets.ValueRow(L(key .. ".label"), "")
    Widgets.Tip(L(key .. ".tip"))
end

local function Row(weapon)
    if Widgets.ValueRow(weapon.Name, Value(Arsenal.Count(weapon)), true) then
        Weapons.Run(function(player) Arsenal.Apply(player, weapon) end)
    end
    Widgets.Tip(L("weapons.items.row.tip"))
    if Widgets.Selected() then Arsenal.Focus(weapon) end
    Widgets.Info(WeaponItemInfo.Get, weapon)
end

local function Body(page)
    Widgets.Dropdown(L("weapons.items.action.label"), s_ActionRef, ActionItems())
    Widgets.Tip(L("weapons.items.action.tip"))
    Widgets.SliderInt(L("weapons.items.quantity.label"), s_QuantityRef, MIN_QUANTITY, Arsenal.MAX_QUANTITY, 1)
    Widgets.Tip(L("weapons.items.quantity.tip"))

    Widgets.Dropdown(L("weapons.items.tier.label"), page.TierRef, Tiers(page, Source(page)))
    Widgets.Tip(L("weapons.items.tier.tip"))
    Widgets.Dropdown(L("weapons.items.class.label"), page.ClassRef, ClassItems())
    Widgets.Tip(L("weapons.items.class.tip"))
    Widgets.Dropdown(L("weapons.items.sort.label"), s_SortRef, SortItems())
    Widgets.Tip(L("weapons.items.sort.tip"))

    local weapons = Visible(page)
    local apply = Arsenal.Removing() and "weapons.items.applyall.remove" or "weapons.items.applyall.add"
    if Widgets.HoldButton(L(apply .. ".label")) then
        Weapons.Run(function(player) Arsenal.ApplyAll(player, weapons) end)
    end
    Widgets.Tip(L(apply .. ".tip"))

    Values()
    Widgets.Break(page.Heading)
    for _, weapon in ipairs(weapons) do Row(weapon) end
    if #weapons == 0 then Empty("weapons.items.none") end
end

local function ListView(page)
    Watch()
    if Loading() then return end
    Body(page)
end

local function NewPage(menuTitle, title, build, live)
    local page = { Title = title, Build = build, Live = live, Tier = 1, Class = 1 }
    page.TierRef = Ref.Field(page, "Tier")
    page.ClassRef = Ref.Field(page, "Class")
    if menuTitle then page.Menu = Submenu.Create(menuTitle, function() ListView(page) end) end
    return page
end

local function OwnedWeapons()
    local list = {}
    for _, weapon in ipairs(Catalog.All) do
        if Arsenal.Count(weapon) > 0 then table.insert(list, weapon) end
    end
    return list
end

local function Matches()
    local list = {}
    for _, weapon in ipairs(Catalog.All) do
        if Widgets.SearchMatch(weapon.Search, s_Search.Query) then table.insert(list, weapon) end
    end
    return list
end

local function TypePage(name)
    local page = s_TypePages[name]
    if page then return page end

    page = NewPage(name, name, function() return Catalog.ByType[name] or {} end)
    page.Tip = tip("weapons.items.types.row", { type = name })
    s_TypePages[name] = page
    return page
end

local function TypesView()
    Watch()
    if Loading() then return end

    for _, name in ipairs(Catalog.Types) do
        local page = TypePage(name)
        page.Badge = page.Badge or tostring(#(Catalog.ByType[name] or {}))
        Widgets.SubmenuButton(name, page.Menu, page.Badge)
        Widgets.Tip(page.Tip)
    end
    if #Catalog.Types == 0 then Empty("weapons.items.none") end
end

local s_TypesLink = { Key = "types", Count = function() return #Catalog.Types end }
s_TypesLink.Menu = Submenu.Create("weapons.items.types.label", TypesView)

local function ListLink(key, build, count, live)
    local link = { Key = key, Count = count, Live = live }
    link.Page = NewPage("weapons.items." .. key .. ".label", "weapons.items." .. key .. ".title", build, live)
    link.Menu = link.Page.Menu
    return link
end

local s_OwnedLink = ListLink("owned", OwnedWeapons, function() return Arsenal.Ready and Arsenal.Kinds or nil end, true)

local LINKS = {
    s_TypesLink,
    ListLink("iconic", function() return Catalog.Iconic end, function() return #Catalog.Iconic end),
    ListLink("wall", function() return Catalog.Wall end, function() return #Catalog.Wall end),
    s_OwnedLink,
    ListLink("all", function() return Catalog.All end, function() return #Catalog.All end)
}

local s_SearchPage = NewPage(nil, "weapons.items.results", Matches)

local function Badge(link)
    local count = link.Count()
    if count == nil then return nil end
    if link.BadgeCount ~= count then
        link.BadgeCount = count
        link.Badge = tostring(count)
    end
    return link.Badge
end

local function Links()
    for _, link in ipairs(LINKS) do
        local label = "weapons.items." .. link.Key
        if Widgets.SubmenuButton(L(label .. ".label"), link.Menu, Badge(link)) and link.Live then Clear(link.Page) end
        Widgets.Tip(L(label .. ".tip"))
    end
end

local function SlotLabels()
    if s_SlotLabels then return s_SlotLabels end

    s_SlotLabels = {}
    for index = 1, Arsenal.SLOTS do s_SlotLabels[index] = tip("weapons.items.loadout.slot", { slot = index }) end
    return s_SlotLabels
end

local function LoadoutRow(label, entry)
    if not entry then
        Widgets.ValueRow(label, L("weapons.items.loadout.empty"))
        Widgets.Tip(L("weapons.items.loadout.emptytip"))
        Widgets.Info(WeaponItemInfo.Slot, label)
        return
    end

    Widgets.ValueRow(label, entry.Name)
    Widgets.Tip(L("weapons.items.loadout.tip"))
    if not entry.Weapon then
        Widgets.Info(WeaponItemInfo.Unlisted, entry)
        return
    end
    if Widgets.Selected() then Arsenal.Focus(entry.Weapon) end
    Widgets.Info(WeaponItemInfo.Get, entry.Weapon)
end

local function Loadout()
    LoadoutRow(L("weapons.items.loadout.hands"), Arsenal.Hands)
    for index, label in ipairs(SlotLabels()) do
        local entry = Arsenal.Slots[index]
        if entry or index < Arsenal.SLOTS then LoadoutRow(label, entry) end
    end

    Widgets.ValueRow(L("weapons.items.loadout.owned.label"), Badge(s_OwnedLink) or "")
    Widgets.Tip(L("weapons.items.loadout.owned.tip"))
    Widgets.Info(WeaponItemInfo.Owned)
end

local function MainView()
    Watch()
    if s_SearchPage.Query ~= s_Search.Query then
        s_SearchPage.Query = s_Search.Query
        Clear(s_SearchPage)
    end

    local searching = s_Search.Query ~= ""
    Widgets.SearchRow(s_SearchRef, L("weapons.items.search.placeholder"), (searching and Catalog.Loaded) and #Source(s_SearchPage) or -1)
    Widgets.Tip(L("weapons.items.search.tip"))
    if Loading() then return end

    if searching then
        Body(s_SearchPage)
        return
    end

    Links()
    Widgets.Break(L("weapons.items.loadout.title"))
    Loadout()
end

WeaponItemsView.Menu = Submenu.Create("weapons.items.title", MainView)

return WeaponItemsView
