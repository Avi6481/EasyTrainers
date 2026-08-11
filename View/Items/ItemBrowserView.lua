local UI = require("UI")
local Buttons = UI.Buttons
local SidePanel = UI.SidePanel
local Notification = UI.Notification
local GeneralLoader = require("Utils/DataExtractors/GeneralLoader")
local Items = require("Features/Items")
local ItemsView = require("View/Items/ItemsView")

local State = Items.BrowserState
local initialized = false
local categorized = {}
local filters = {
    Quality = { index = 1 },
    CraftableOnly = { value = false },
}
local search = { value = "", capturing = false }

local categoryGroups = {
    { Name = "Cyberware", Keys = { "Cyberware" }, Tip = "Operating systems, implants, optics, and other cyberware." },
    { Name = "Consumables", Keys = { "Consumables" }, Tip = "Food, drinks, medicine, boosters, and inhalers." },
    { Name = "Crafting & Upgrades", Keys = { "CraftingMaterials" }, Tip = "Crafting, quickhack, upgrade, and attachment materials." },
    { Name = "Weapon Mods", Keys = { "WeaponMods" }, Tip = "Attachments and modifications for ranged and melee weapons." },
    { Name = "Skills & Progression", Keys = { "SkillShards", "CyberdeckShards" }, Tip = "Skill books, progression shards, and cyberdeck upgrades." },
    { Name = "Rewards & Currency", Keys = { "Reward" }, Tip = "Currency, reward containers, chips, and payout items." },
    { Name = "Quest Items", Keys = { "Quest" }, Tip = "Items tagged for missions and story progression." },
    { Name = "Readables", Keys = { "Readables" }, Tip = "Shards, fragments, and readable database items." },
    { Name = "Miscellaneous", Keys = { "Miscellaneous" }, Tip = "Junk, props, valuables, and novelty items." },
    { Name = "Advanced", Keys = { "Uncategorized" }, Tip = "Items whose game tags do not fit the curated categories." },
}

local function Friendly(value)
    value = tostring(value or "Other"):gsub("_", " ")
    value = value:gsub("(%l)(%u)", "%1 %2")
    return value
end

local function QualityName(value)
    return Friendly(tostring(value or "Standard"):match("([^.]+)$"))
end

local function IsFocused(data)
    return data and data.Visible and (data.Selected or data.Hovered)
end

local function EnsureInitialized(force)
    if initialized and not force then return end
    if force or #GeneralLoader:GetAll() == 0 then GeneralLoader:LoadAll() end
    categorized = GeneralLoader:Categorize()
    initialized = true
end

local function DrawControls()
    Buttons.Dropdown("Inventory Action", State.Action, State.Actions,
        "Choose whether selecting an item adds it to or removes it from your inventory.")
    Buttons.Int("Quantity", State.Quantity, "Amount applied each time you select an item.")
end

local function SubmitItemInfo(item, category, group)
    SidePanel.SubmitInfo("item-record", {
        Eyebrow = "ITEM DATABASE",
        Title = item.name or item.id or "Unknown Item",
        Rows = {
            { Label = "Category", Value = category or "Other" },
            { Label = "Group", Value = Friendly(group) },
            { Label = "Quality", Value = QualityName(item.quality) },
            { Label = "Owned", Value = tostring(State.GetOwned(item.id)) },
            { Label = "Action", Value = State.GetAction() .. " " .. tostring(State.Quantity.value) },
        },
        Description = item.id,
    }, { Width = 320 })
end

local function DrawItem(item, category, group, right)
    local _, data = Buttons.OptionExtended(item.name or item.id, "", right or State.GetSummary(),
        "Apply the selected inventory action to this item.", function()
            State.Apply(item)
        end)
    if IsFocused(data) then SubmitItemInfo(item, category, group) end
end

local function Sorted(items)
    local result = {}
    for _, item in ipairs(items or {}) do table.insert(result, item) end
    table.sort(result, function(a, b)
        return (a.name or a.id or ""):lower() < (b.name or b.id or ""):lower()
    end)
    return result
end

local function BuildQualities(items)
    local result, seen = { "All" }, {}
    for _, item in ipairs(items) do
        local name = QualityName(item.quality)
        if name ~= "Standard" and not seen[name] then
            seen[name] = true
            table.insert(result, name)
        end
    end
    table.sort(result, function(a, b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a < b
    end)
    return result
end

local function ItemListView(context)
    local qualities = BuildQualities(context.Items)
    filters.Quality.index = math.min(filters.Quality.index or 1, #qualities)

    DrawControls()
    Buttons.Dropdown("Quality", filters.Quality, qualities, "Limit this list to a specific item quality.")
    Buttons.Toggle("Craftable Only", filters.CraftableOnly, "Only show records marked as craftable.")

    local visible = {}
    local selectedQuality = qualities[filters.Quality.index or 1]
    for _, item in ipairs(context.Items) do
        local qualityMatches = selectedQuality == "All" or QualityName(item.quality) == selectedQuality
        local craftableMatches = not filters.CraftableOnly.value or item.isCraftable
        if qualityMatches and craftableMatches then table.insert(visible, item) end
    end

    Buttons.Break("", Friendly(context.Group) .. "  /  " .. tostring(#visible))
    for _, item in ipairs(Sorted(visible)) do
        DrawItem(item, context.Category, context.Group, QualityName(item.quality))
    end
end

local function CollectSubcategories(group)
    local result = {}
    for _, key in ipairs(group.Keys) do
        for name, items in pairs(categorized[key] or {}) do
            if #items > 0 then
                local bucket = result[name] or {}
                for _, item in ipairs(items) do table.insert(bucket, item) end
                result[name] = bucket
            end
        end
    end
    return result
end

local function CategoryView(group)
    local subcategories = CollectSubcategories(group)
    local names = {}
    for name, items in pairs(subcategories) do
        if #items > 0 then table.insert(names, name) end
    end
    table.sort(names, function(a, b) return Friendly(a) < Friendly(b) end)

    for _, name in ipairs(names) do
        local currentName = name
        local items = subcategories[currentName]
        local menu = {
            title = Friendly(currentName),
            view = function()
                ItemListView({ Category = group.Name, Group = currentName, Items = items })
            end,
        }
        Buttons.Submenu(Friendly(currentName), menu, tostring(#items) .. " available items")
    end
end

local function CatalogView()
    for _, group in ipairs(categoryGroups) do
        local current = group
        local subcategories = CollectSubcategories(current)
        local count = 0
        for _, items in pairs(subcategories) do count = count + #items end
        if count > 0 then
            local menu = { title = current.Name, view = function() CategoryView(current) end }
            Buttons.Submenu(current.Name, menu, current.Tip)
        end
    end
end

local function SearchView()
    DrawControls()
    Buttons.Text("Search Name or Item ID", search,
        "Searches both the display name and the internal item ID.")

    local term = (search.value or ""):lower()
    local results = {}
    if term ~= "" then
        for _, item in ipairs(GeneralLoader:GetAll()) do
            local name = (item.name or ""):lower()
            local id = (item.id or ""):lower()
            if name:find(term, 1, true) or id:find(term, 1, true) then
                table.insert(results, item)
            end
        end
    end
    results = Sorted(results)
    Buttons.Break("", term == "" and "Enter a name or item ID" or (tostring(#results) .. " Results"))
    for index, item in ipairs(results) do
        if index > 250 then break end
        DrawItem(item, "Search", "Results", QualityName(item.quality))
    end
end

local function InventoryView()
    DrawControls()
    Buttons.Option("Refresh Inventory", "Refresh item quantities from your current inventory.", function()
        State.RefreshInventory()
        Notification.Info("Inventory refreshed", 2)
    end)

    local owned = State.GetInventory()
    table.sort(owned, function(a, b) return (a.name or a.id):lower() < (b.name or b.id):lower() end)
    Buttons.Break("", "Owned Items  /  " .. tostring(#owned))
    for _, entry in ipairs(owned) do
        local item = GeneralLoader:GetById(entry.id) or entry
        item.name = item.name or entry.name
        DrawItem(item, "Inventory", "Owned", "x" .. tostring(entry.quantity or 1))
    end
end

local catalogMenu = { title = "Item Catalog", view = CatalogView }
local searchMenu = { title = "Search Items", view = SearchView }
local inventoryMenu = { title = "My Inventory", view = InventoryView }

local function ItemMainView()
    EnsureInitialized()
    DrawControls()
    Buttons.Break("", "Browse & Manage")
    Buttons.Submenu("Essentials", ItemsView, "Quick kits, crafting components, consumables, buffs, and recipes.")
    Buttons.Submenu("Browse Catalog", catalogMenu, "Browse a curated item catalog by purpose and type.")
    Buttons.Submenu("Search Items", searchMenu, "Find an item by its display name or internal ID.")
    Buttons.Submenu("My Inventory", inventoryMenu, "Review, add, or remove items you currently own.", function()
        State.Action.index = 2
        State.RefreshInventory()
    end)
    Buttons.Break("", "Quick Add")
    Buttons.OptionExtended("Crafting Component Kit", "", "+" .. tostring(State.Quantity.value),
        "Add every standard crafting component using the selected quantity.", function()
            Items.Actions.GiveAllCraftingComponents(State.Quantity.value)
            State.RefreshInventory()
            Notification.Success("Crafting component kit added", 2)
        end)
    Buttons.OptionExtended("MaxDoc Kit", "", "+" .. tostring(State.Quantity.value),
        "Add every MaxDoc tier using the selected quantity.", function()
            Items.Actions.GiveMaxDocs(State.Quantity.value)
            State.RefreshInventory()
            Notification.Success("MaxDoc kit added", 2)
        end)
    Buttons.Break("", "Database")
    Buttons.Option("Reload Item Database", "Rebuild the item catalog from the current game records.", function()
        EnsureInitialized(true)
        State.RefreshInventory()
        Notification.Success("Item database reloaded", 2)
    end)
end

return { title = "Items", view = ItemMainView }
