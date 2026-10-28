local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Notification = require("UI/Panels/Notification/Notification")
local Inventory = require("Utils/Inventory")
local GeneralLoader = require("Utils/DataExtractors/GeneralLoader")
local Items = require("Features/Items")
local ItemsView = require("View/Items/ItemsView")

local State = Items.BrowserState

local SEARCH_LIMIT = 250
local ALL = "All"

local SORT = {
    Name = "Name",
    QualityHigh = "Quality: High to Low",
    QualityLow = "Quality: Low to High",
    OwnedHigh = "Owned: Most First"
}
local SORT_OPTIONS = { SORT.Name, SORT.QualityHigh, SORT.QualityLow, SORT.OwnedHigh }

local QUALITY_WEIGHT = {
    Common = 1, CommonPlus = 1.5, Uncommon = 2, UncommonPlus = 2.5, Rare = 3, RarePlus = 3.5,
    Epic = 4, EpicPlus = 4.5, Legendary = 5, LegendaryPlus = 5.5, LegendaryPlusPlus = 5.8, Iconic = 6
}

local CATEGORY_GROUPS = {
    { Name = "Consumables", Keys = { "Consumables" }, Tip = "Food, drinks, medicine, boosters, and inhalers." },
    { Name = "Crafting & Upgrades", Keys = { "CraftingMaterials" }, Tip = "Crafting, quickhack, upgrade, and attachment materials." },
    { Name = "Cyberware", Keys = { "Cyberware" }, Tip = "Operating systems, implants, optics, and other cyberware." },
    { Name = "Weapon Mods", Keys = { "WeaponMods" }, Tip = "Attachments and modifications for ranged and melee weapons." },
    { Name = "Skills & Progression", Keys = { "SkillShards", "CyberdeckShards" }, Tip = "Skill books, progression shards, and cyberdeck upgrades." },
    { Name = "Rewards & Currency", Keys = { "Reward" }, Tip = "Currency, reward containers, chips, and payout items." },
    { Name = "Quest Items", Keys = { "Quest" }, Tip = "Items tagged for missions and story progression." },
    { Name = "Readables", Keys = { "Readables" }, Tip = "Shards, fragments, and readable database items." },
    { Name = "Miscellaneous", Keys = { "Miscellaneous" }, Tip = "Junk, props, valuables, and novelty items." },
    { Name = "Advanced", Keys = { "Uncategorized" }, Tip = "Items whose game tags do not fit the curated categories." }
}

local s_Catalog = nil
local s_Quality = { index = 1 }
local s_Sort = { index = 1 }
local s_CraftableOnly = { value = false }
local s_Search = { value = "", capturing = false }
local s_Eddies = { value = 100000, min = 1000, max = 10000000, step = 10000 }
local s_KitQuantity = { value = 10, min = 1, max = 999, step = 1 }

local s_List = { Title = "", Key = nil, Source = nil, Category = nil, Group = nil }
local s_Cache = { Key = nil, Source = nil, Qualities = { ALL }, Quality = nil, Craftable = nil, Sort = nil, Result = nil }

local function Friendly(value)
    return (tostring(value or "Other"):gsub("_", " "):gsub("(%l)(%u)", "%1 %2"))
end

local function QualityKey(item)
    return tostring(item.quality or "Standard"):match("([^.]+)$")
end

local function QualityName(item)
    return Friendly(QualityKey(item))
end

local function QualityWeight(item)
    return QUALITY_WEIGHT[QualityKey(item)] or 0
end

local function ByName(a, b)
    return (a.name or a.id or ""):lower() < (b.name or b.id or ""):lower()
end

local function DrawControls()
    Buttons.Dropdown("Inventory Action", State.Action, State.Actions, "Choose whether selecting an item adds it to or removes it from your inventory.")
    Buttons.Int("Quantity", State.Quantity, "Amount applied each time you select an item.")
end

local function SubmitItemInfo(item, category, group)
    local owned = State.GetOwned(item.id)
    local description = State.GetDescription(item.id)
    SidePanel.SubmitInfo("item-record", {
        Eyebrow = item.quality and string.upper(QualityName(item)) or "ITEM DATABASE",
        Title = item.name or item.id or "Unknown Item",
        Icon = item.id,
        Rows = {
            { Label = "Category", Value = category or "Other" },
            { Label = "Group", Value = Friendly(group) },
            { Label = "Quality", Value = QualityName(item) },
            { Label = "Craftable", Value = item.isCraftable and "Yes" or "No" },
            { Label = "Owned", Value = owned > 0 and ("x" .. tostring(owned)) or "No" }
        },
        Description = (description ~= "" and (description .. "\n\n") or "") .. item.id
    }, { Width = 320 })
end

local function DrawItem(item, category, group)
    local owned = State.GetOwned(item.id)
    local value = (owned > 0 and ("x" .. tostring(owned) .. "  ") or "") .. State.GetSummary()
    local _, data = Buttons.OptionExtended(item.name or item.id, "", value,
        "Apply the selected inventory action to this item.", function()
            State.Apply(item)
            s_Cache.Result = nil
        end)
    if data and data.Visible and (data.Selected or data.Hovered) then SubmitItemInfo(item, category or item.category, group or item.group) end
end

local function BuildQualities(items)
    local qualities, seen = {}, {}
    for _, item in ipairs(items) do
        local key = QualityKey(item)
        if key ~= "Standard" and not seen[key] then
            seen[key] = true
            table.insert(qualities, item)
        end
    end
    table.sort(qualities, function(a, b)
        if QualityWeight(a) == QualityWeight(b) then return QualityName(a) < QualityName(b) end
        return QualityWeight(a) > QualityWeight(b)
    end)

    local names = { ALL }
    for _, item in ipairs(qualities) do table.insert(names, QualityName(item)) end
    return names
end

local function VisibleItems()
    if s_Cache.Key ~= s_List.Key then
        local source = s_List.Source and s_List.Source() or {}
        s_Cache.Key, s_Cache.Source, s_Cache.Qualities, s_Cache.Result = s_List.Key, source, BuildQualities(source), nil
        s_Quality.index = 1
    end

    s_Quality.index = math.min(s_Quality.index or 1, #s_Cache.Qualities)
    local quality = s_Cache.Qualities[s_Quality.index]
    local craftable = s_CraftableOnly.value
    local sort = SORT_OPTIONS[s_Sort.index or 1]
    if s_Cache.Result and s_Cache.Quality == quality and s_Cache.Craftable == craftable and s_Cache.Sort == sort then return s_Cache.Result end

    local result = {}
    for _, item in ipairs(s_Cache.Source) do
        if (quality == ALL or QualityName(item) == quality) and (not craftable or item.isCraftable) then
            table.insert(result, item)
        end
    end

    table.sort(result, function(a, b)
        if sort == SORT.OwnedHigh then
            local left, right = State.GetOwned(a.id), State.GetOwned(b.id)
            if left ~= right then return left > right end
        elseif sort == SORT.QualityHigh or sort == SORT.QualityLow then
            local left, right = QualityWeight(a), QualityWeight(b)
            if left ~= right then
                if sort == SORT.QualityHigh then return left > right end
                return left < right
            end
        end
        return ByName(a, b)
    end)

    s_Cache.Quality, s_Cache.Craftable, s_Cache.Sort, s_Cache.Result = quality, craftable, sort, result
    return result
end

local function ApplyToAll(items)
    local applied = 0
    local removing = State.GetAction() ~= "Add"
    for _, item in ipairs(items) do
        if (not removing or State.GetOwned(item.id) > 0) and State.Apply(item, nil, true) then applied = applied + 1 end
    end
    State.RefreshInventory()
    s_Cache.Result = nil
    Notification.Success(State.GetAction() .. ": " .. tostring(applied) .. " items", 2)
end

local function ListView()
    DrawControls()
    VisibleItems()
    Buttons.Dropdown("Quality", s_Quality, s_Cache.Qualities, "Only show items of this quality.")
    Buttons.Toggle("Craftable Only", s_CraftableOnly, "Only show records marked as craftable.")
    Buttons.Dropdown("Sort", s_Sort, SORT_OPTIONS, "Order the list by name, quality, or how many you own.")

    local items = VisibleItems()
    Buttons.Option(State.GetAction() .. " Every Item Shown", "Apply the inventory action to every item in the filtered list below.", function()
        ApplyToAll(items)
    end)

    Buttons.Break(tostring(#items) .. " " .. s_List.Title)
    for _, item in ipairs(items) do DrawItem(item, s_List.Category, s_List.Group) end
    if #items == 0 then Buttons.Break("No items match these filters") end
end

local ListMenu = Submenu.Create("Items", ListView)

local function OpenList(title, key, source, category, group)
    return function()
        s_List.Title, s_List.Key, s_List.Source, s_List.Category, s_List.Group = title, key, source, category, group
        s_CraftableOnly.value = false
        State.RefreshInventory()
    end
end

local function BuildGroup(group, categorized)
    local merged = {}
    for _, key in ipairs(group.Keys) do
        for name, items in pairs(categorized[key] or {}) do
            merged[name] = merged[name] or {}
            for _, item in ipairs(items) do
                item.category, item.group = group.Name, name
                table.insert(merged[name], item)
            end
        end
    end

    local lists, all = {}, {}
    for name, items in pairs(merged) do
        if #items > 0 then
            table.insert(lists, { Name = name, Items = items })
            for _, item in ipairs(items) do table.insert(all, item) end
        end
    end
    table.sort(lists, function(a, b) return Friendly(a.Name) < Friendly(b.Name) end)

    local entry = { Group = group, Lists = lists, All = all }
    entry.Menu = Submenu.Create(group.Name, function()
        Buttons.Submenu("Everything in " .. group.Name, ListMenu, tostring(#all) .. " items in one list.",
            OpenList(group.Name, "group:" .. group.Name, function() return all end, group.Name, "All"))
        for _, list in ipairs(lists) do
            Buttons.Submenu(Friendly(list.Name), ListMenu, tostring(#list.Items) .. " items.",
                OpenList(Friendly(list.Name), "list:" .. group.Name .. ":" .. list.Name, function() return list.Items end, group.Name, list.Name))
        end
    end)
    return entry
end

local function BuildCatalog(force)
    if force or #GeneralLoader:GetAll() == 0 then GeneralLoader:LoadAll() end

    local categorized = GeneralLoader:Categorize()
    s_Catalog = {}
    for _, group in ipairs(CATEGORY_GROUPS) do
        local built = BuildGroup(group, categorized)
        if #built.All > 0 then table.insert(s_Catalog, built) end
    end
    s_Cache.Key = nil
end

local function CatalogView()
    for _, entry in ipairs(s_Catalog or {}) do
        Buttons.Submenu(entry.Group.Name, entry.Menu, entry.Group.Tip)
    end
end

local CatalogMenu = Submenu.Create("Browse Catalog", CatalogView)

local function SearchResults()
    local term = (s_Search.value or ""):lower()
    if term == "" then return {} end

    local results = {}
    for _, item in ipairs(GeneralLoader:GetAll()) do
        if (item.name or ""):lower():find(term, 1, true) or (item.id or ""):lower():find(term, 1, true) then
            table.insert(results, item)
            if #results >= SEARCH_LIMIT then break end
        end
    end
    return results
end

local function SearchView()
    Buttons.Text("Search Name or Item ID", s_Search, "Searches both the display name and the internal item ID.")
    local term = s_Search.value or ""
    if s_List.Key ~= "search:" .. term then OpenList("Results", "search:" .. term, SearchResults, "Search", "Results")() end
    if term == "" then
        Buttons.Break("Type a name or item ID")
        return
    end
    ListView()
end

local SearchMenu = Submenu.Create("Search Items", SearchView)

local function OwnedItems()
    local items = {}
    for _, entry in ipairs(State.GetInventory()) do
        table.insert(items, GeneralLoader:GetById(entry.id) or entry)
    end
    return items
end

local function RecentView()
    DrawControls()
    if #State.Recent == 0 then
        Buttons.Break("Items you add or remove show up here")
        return
    end
    Buttons.Break("Last " .. tostring(#State.Recent) .. " Items")
    for _, item in ipairs(State.Recent) do DrawItem(GeneralLoader:GetById(item.id) or item) end
end

local RecentMenu = Submenu.Create("Recently Used", RecentView)

local function Kit(label, tipText, give)
    Buttons.OptionExtended(label, "", "+" .. tostring(s_KitQuantity.value), tipText, function()
        give(s_KitQuantity.value)
        State.RefreshInventory()
        Notification.Success("Added " .. label, 2)
    end)
end

local function UnlockAllRecipes()
    Items.ModRecipes.GiveAllModRecipes()
    Items.QuickhackRecipes.GiveAllQuickhackRecipes()
    Items.WeaponRecipes.GiveAllWeaponRecipes()
    Items.ClothingRecipes.GiveAllClothingRecipes()
    Items.GrenadeRecipes.GiveAllGrenadeRecipes()
    Notification.Success("Unlocked every crafting recipe", 2)
end

local function ItemBrowserView()
    if not s_Catalog then BuildCatalog(false) end

    Buttons.Submenu("Search Items", SearchMenu, "Find any item by name or ID, with its picture in the side panel.")
    Buttons.Submenu("Browse Catalog", CatalogMenu, "Browse every item by purpose and type, with quality and sort filters.")
    Buttons.Submenu("My Inventory", ListMenu, "Review, add, or remove items you currently own.", function()
        State.Action.index = 2
        s_Sort.index = 4
        OpenList("Owned Items", "owned:" .. tostring(os.time()), OwnedItems, "Inventory", "Owned")()
    end)
    Buttons.Submenu("Recently Used", RecentMenu, "The last items you added or removed this session.")
    Buttons.Submenu("Essentials", ItemsView, "Hand-picked components, consumables, buffs, and recipe groups.")

    Buttons.Break("Quick Add")
    Buttons.IntClick("Add Eddies", s_Eddies, "Pick an amount, then select to add that many eddies.", function(amount)
        Inventory.GiveItem("Items.money", amount)
        Notification.Success("Added " .. tostring(amount) .. " eddies", 2)
    end)
    Buttons.Int("Kit Quantity", s_KitQuantity, "Amount of every item included in each kit below.")
    Kit("Crafting Components", "Every item, quickhack, and upgrade component tier.", Items.Actions.GiveAllCraftingComponents)
    Kit("Upgrade Components", "Every upgrade component tier.", Items.Actions.GiveUpgradeComponents)
    Kit("Quickhack Components", "Every quickhack component tier.", Items.Actions.GiveQuickhackComponents)
    Kit("MaxDocs", "Every MaxDoc tier.", Items.Actions.GiveMaxDocs)
    Kit("Bounce Backs", "Every Bounce Back tier.", Items.Actions.GiveBounceBacks)
    Kit("Boosters", "Capacity, health, oxygen, memory, and stamina boosters.", Items.Actions.GiveBoosters)
    Buttons.Option("Unlock Every Crafting Recipe", "Unlocks mod, quickhack, weapon, clothing, and grenade recipes.", UnlockAllRecipes)

    Buttons.Break("Database")
    Buttons.Option("Reload Item Database", "Rebuild the item catalog from the current game records.", function()
        BuildCatalog(true)
        State.RefreshInventory()
        Notification.Success("Item database reloaded", 2)
    end)
end

return Submenu.Create("Inventory", ItemBrowserView)
