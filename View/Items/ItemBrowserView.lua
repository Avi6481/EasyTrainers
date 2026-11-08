local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Items = require("Features/Items/Items")
local ItemInfo = require("View/Items/ItemInfo")

local ItemBrowserView = {}

local Catalog = Items.Catalog
local State = Items.BrowserState

local MIN_QUANTITY = 1
local SEARCH_LIMIT = 250
local OWNED_SORT = 4
local SORTS = { "name", "qualityhigh", "qualitylow", "owned" }
local ACTION_KEYS = { Add = "add", Remove = "remove", RemoveAll = "removeall" }

local function ByName(first, second)
    if first.Order ~= second.Order then return first.Order < second.Order end
    return first.Id < second.Id
end

local SORTERS = {
    name = ByName,
    qualityhigh = function(first, second)
        if first.Weight ~= second.Weight then return first.Weight > second.Weight end
        return ByName(first, second)
    end,
    qualitylow = function(first, second)
        if first.Weight ~= second.Weight then return first.Weight < second.Weight end
        return ByName(first, second)
    end,
    owned = function(first, second)
        local left, right = State.Count(first), State.Count(second)
        if left ~= right then return left > right end
        return ByName(first, second)
    end
}

local s_Sort = { Index = 1 }
local s_SortRef = Ref.Field(s_Sort, "Index")
local s_ActionRef = Ref.Choice(State, "Action", State.ACTIONS)
local s_QuantityRef = Ref.Field(State, "Quantity")
local s_Search = { Query = "" }
local s_SearchRef = Ref.Field(s_Search, "Query")
local s_Items = {}
local s_Values = {}
local s_ValueSummary = nil
local s_Categories = {}
local s_ListPages = {}
local s_Version = nil
local s_Progress = {}
local s_Counts = {}
local s_RecentHeading = nil
local s_RecentCount = nil

local function Watch()
    Items.Watch()
end

local function Clear(page)
    page.List = nil
    page.QualityItems = nil
    page.Result = nil
end

local function Fresh()
    if s_Version == Catalog.Version then return end
    s_Version = Catalog.Version
    s_Categories = {}
    for _, page in pairs(s_ListPages) do
        Clear(page)
        page.Badge = nil
        page.Tip = nil
    end
end

local function Count(value)
    local text = s_Counts[value]
    if text then return text end

    text = tostring(value)
    s_Counts[value] = text
    return text
end

local function Percent()
    local percent = math.floor((Catalog.Progress or 0) * 100)
    local text = s_Progress[percent]
    if not text then
        text = tostring(percent) .. "%"
        s_Progress[percent] = text
    end
    return text
end

local function Loading()
    if Catalog.Loaded then
        Fresh()
        return false
    end
    Widgets.ValueRow(L("items.loading.label"), Percent())
    Widgets.Tip(L("items.loading.tip"))
    return true
end

local function Stale(page)
    if not page.Live or not page.List then return false end
    if page.SeenChanges ~= State.Changes or page.SeenReady ~= State.Ready then return true end
    return #page.List == 0 and page.SeenOwned ~= State.OwnedVersion
end

local function Source(page)
    if Stale(page) then page.List = nil end
    if page.List and page.ListVersion == Catalog.Version then return page.List end

    page.List = page.Build()
    page.ListVersion = Catalog.Version
    page.SeenChanges = State.Changes
    page.SeenReady = State.Ready
    page.SeenOwned = State.OwnedVersion
    page.QualityItems = nil
    page.Result = nil
    return page.List
end

local function QualityOrder(first, second)
    if first.Weight ~= second.Weight then return first.Weight > second.Weight end
    return first.Name < second.Name
end

local function Qualities(page, source)
    if page.QualityItems then return page.QualityItems end

    local selected = page.QualityNames and page.QualityNames[page.Quality - 1]
    local seen, found = {}, {}
    for _, item in ipairs(source) do
        if item.Quality ~= Catalog.STANDARD and not seen[item.QualityName] then
            seen[item.QualityName] = true
            table.insert(found, { Name = item.QualityName, Weight = item.Weight })
        end
    end
    table.sort(found, QualityOrder)

    local items = { { Label = L("items.filters.all"), Tip = "" } }
    local names = {}
    page.Quality = 1
    for index, quality in ipairs(found) do
        names[index] = quality.Name
        items[index + 1] = { Label = quality.Name, Tip = "" }
        if quality.Name == selected then page.Quality = index + 1 end
    end
    page.QualityNames = names
    page.QualityItems = items
    return items
end

local function Visible(page)
    local source = Source(page)
    local qualities = Qualities(page, source)
    page.Quality = math.max(1, math.min(page.Quality, #qualities))
    if page.Result and page.ResultQuality == page.Quality and page.ResultCraftable == page.Craftable and page.ResultSort == s_Sort.Index
        and page.ResultChanges == State.Changes and page.ResultReady == State.Ready then
        return page.Result
    end

    local quality = page.QualityNames[page.Quality - 1]
    local craftable = page.Craftable
    local result = {}
    for _, item in ipairs(source) do
        if (not quality or item.QualityName == quality) and (not craftable or item.Craftable) then table.insert(result, item) end
    end
    table.sort(result, SORTERS[SORTS[s_Sort.Index]] or ByName)

    page.Result = result
    page.ResultQuality = page.Quality
    page.ResultCraftable = page.Craftable
    page.ResultSort = s_Sort.Index
    page.ResultChanges = State.Changes
    page.ResultReady = State.Ready
    page.Heading = tip("items.count", { count = #result, title = page.Title })
    return result
end

local function ActionItems()
    if s_Items.Action then return s_Items.Action end

    local items = {}
    for index, action in ipairs(State.ACTIONS) do
        local key = "items.action." .. ACTION_KEYS[action]
        items[index] = { Label = L(key .. ".label"), Tip = L(key .. ".tip") }
    end
    s_Items.Action = items
    return items
end

local function SortItems()
    if s_Items.Sort then return s_Items.Sort end

    local items = {}
    for index, key in ipairs(SORTS) do items[index] = { Label = L("items.sort." .. key), Tip = "" } end
    s_Items.Sort = items
    return items
end

local function Values()
    local summary = State.Summary()
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

function ItemBrowserView.Controls()
    Widgets.Dropdown(L("items.action.label"), s_ActionRef, ActionItems())
    Widgets.Tip(L("items.action.tip"))
    Widgets.SliderInt(L("items.quantity.label"), s_QuantityRef, MIN_QUANTITY, State.MAX_QUANTITY, 1)
    Widgets.Tip(L("items.quantity.tip"))
end

function ItemBrowserView.Row(item, info)
    Values()
    if Widgets.ValueRow(item.Name, Value(State.Count(item)), true) then
        Items.Run(function(player) State.Apply(player, item) end)
    end
    Widgets.Tip(L("items.row.tip"))
    if Widgets.Selected() then State.Focus(item) end
    Widgets.Info(info or ItemInfo.Get, item)
end

local function Body(page)
    ItemBrowserView.Controls()
    Widgets.Dropdown(L("items.quality.label"), page.QualityRef, Qualities(page, Source(page)))
    Widgets.Tip(L("items.quality.tip"))
    Widgets.Toggle(L("items.craftable.label"), page.CraftableRef)
    Widgets.Tip(L("items.craftable.tip"))
    Widgets.Dropdown(L("items.sort.label"), s_SortRef, SortItems())
    Widgets.Tip(L("items.sort.tip"))

    local items = Visible(page)
    local apply = "items.applyall." .. ACTION_KEYS[State.Action]
    if Widgets.HoldButton(L(apply .. ".label")) then
        Items.Run(function(player) State.ApplyAll(player, items) end)
    end
    Widgets.Tip(L(apply .. ".tip"))

    Widgets.Break(page.Heading)
    for _, item in ipairs(items) do ItemBrowserView.Row(item) end
    if #items == 0 then Empty("items.none") end
end

local function ListView(page)
    Watch()
    if Loading() then return end
    Body(page)
end

local function NewPage(menuTitle, title, build, live)
    local page = { Title = title, Build = build, Live = live, Quality = 1, Craftable = false }
    page.QualityRef = Ref.Field(page, "Quality")
    page.CraftableRef = Ref.Field(page, "Craftable")
    if menuTitle then page.Menu = Submenu.Create(menuTitle, function() ListView(page) end) end
    return page
end

local function ListItems(key)
    local list = Catalog.List(key)
    return list and list.Items or {}
end

local function CategoryItems(key)
    local category = Catalog.Category(key)
    return category and category.All or {}
end

local function ListPage(key, label)
    local page = s_ListPages[key]
    if page then return page end

    page = NewPage(label, label, function() return ListItems(key) end)
    s_ListPages[key] = page
    return page
end

local function EveryPage(category)
    local key = "every:" .. category.Key
    local page = s_ListPages[key]
    if page then return page end

    page = NewPage(category.Label, category.Label, function() return CategoryItems(category.Key) end)
    s_ListPages[key] = page
    return page
end

local function CategoryView(entry)
    Watch()
    if Loading() then return end

    local category = Catalog.Category(entry.Key)
    if not category then
        Empty("items.none")
        return
    end

    Widgets.SubmenuButton(entry.EveryLabel, EveryPage(category).Menu, entry.Badge)
    Widgets.Tip(L("items.catalog.every.tip"))
    for _, list in ipairs(category.Lists) do
        local page = ListPage(list.Key, list.Label)
        page.Badge = page.Badge or Count(#list.Items)
        page.Tip = page.Tip or tip("items.catalog.list.tip", { count = #list.Items })
        Widgets.SubmenuButton(L(list.Label), page.Menu, page.Badge)
        Widgets.Tip(page.Tip)
    end
end

local function CategoryEntry(category)
    local entry = s_Categories[category.Key]
    if entry then return entry end

    entry = {
        Key = category.Key,
        Badge = Count(#category.All),
        EveryLabel = tip("items.catalog.every.label", { category = category.Label })
    }
    entry.Menu = Submenu.Create(category.Label, function() CategoryView(entry) end)
    s_Categories[category.Key] = entry
    return entry
end

local function CatalogView()
    Watch()
    if Loading() then return end

    for _, category in ipairs(Catalog.Categories) do
        local entry = CategoryEntry(category)
        Widgets.SubmenuButton(L(category.Label), entry.Menu, entry.Badge)
        Widgets.Tip(L(category.Tip))
    end
    if #Catalog.Categories == 0 then Empty("items.none") end
end

ItemBrowserView.CatalogMenu = Submenu.Create("items.catalog.title", CatalogView)

local s_OwnedPage = NewPage("items.owned.title", "items.owned.title", State.OwnedItems, true)
ItemBrowserView.OwnedMenu = s_OwnedPage.Menu

function ItemBrowserView.OpenOwned()
    State.Action = "Remove"
    s_Sort.Index = OWNED_SORT
    Clear(s_OwnedPage)
    Items.Run(function(player) State.Refresh(player) end)
end

local function RecentView()
    Watch()
    ItemBrowserView.Controls()

    local recent = State.Recent
    if #recent == 0 then
        Widgets.Break("")
        Empty("items.recent.none")
        return
    end

    if s_RecentCount ~= #recent then
        s_RecentCount = #recent
        s_RecentHeading = tip("items.recent.count", { count = #recent })
    end
    Widgets.Break(s_RecentHeading)
    for _, item in ipairs(recent) do ItemBrowserView.Row(item) end
end

ItemBrowserView.RecentMenu = Submenu.Create("items.recent.title", RecentView)

local function Matches()
    local list = {}
    local query = s_Search.Query
    for _, item in ipairs(Catalog.All) do
        if Widgets.SearchMatch(item.Search, query) then
            table.insert(list, item)
            if #list >= SEARCH_LIMIT then break end
        end
    end
    return list
end

local s_SearchPage = NewPage(nil, "items.results", Matches)

function ItemBrowserView.Badge(kind)
    if kind == "catalog" then return Catalog.Loaded and Count(#Catalog.All) or nil end
    if kind == "owned" then return State.Ready and Count(State.Kinds) or nil end
    if kind == "recent" then return #State.Recent > 0 and Count(#State.Recent) or nil end
    return nil
end

function ItemBrowserView.Search()
    if s_SearchPage.Query ~= s_Search.Query then
        s_SearchPage.Query = s_Search.Query
        Clear(s_SearchPage)
    end

    local searching = s_Search.Query ~= ""
    Widgets.SearchRow(s_SearchRef, L("items.search.placeholder"), (searching and Catalog.Loaded) and #Source(s_SearchPage) or -1)
    Widgets.Tip(L("items.search.tip"))
    if Loading() then return searching end
    if not searching then return false end

    Body(s_SearchPage)
    return true
end

return ItemBrowserView
