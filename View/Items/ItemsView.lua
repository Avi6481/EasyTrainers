local UI = require("UI")
local Buttons = UI.Buttons
local SidePanel = UI.SidePanel
local Notification = UI.Notification
local Items = require("Features/Items")

local State = Items.BrowserState

local function IsFocused(data)
    return data and data.Visible and (data.Selected or data.Hovered)
end

local function DrawItemControls()
    Buttons.Dropdown("Inventory Action", State.Action, State.Actions,
        "Choose whether selecting an item adds it to or removes it from your inventory.")
    Buttons.Int("Quantity", State.Quantity, "Amount applied each time you select an item.")
end

local function SubmitItemInfo(item, section)
    SidePanel.SubmitInfo("essential-item", {
        Eyebrow = "ESSENTIAL ITEM",
        Title = item.name,
        Rows = {
            { Label = "Section", Value = section },
            { Label = "Group", Value = item.group or "Other" },
            { Label = "Owned", Value = tostring(State.GetOwned(item.id)) },
            { Label = "Action", Value = State.GetAction() .. " " .. tostring(State.Quantity.value) },
        },
        Description = item.id,
    }, { Width = 310 })
end

local function DrawItemList(title, items)
    DrawItemControls()
    Buttons.Break("", title .. "  /  " .. tostring(#items))

    local lastGroup
    for _, item in ipairs(items) do
        if item.group ~= lastGroup then
            Buttons.Break("", item.group)
            lastGroup = item.group
        end
        local _, data = Buttons.OptionExtended(item.name, "", State.GetSummary(),
            "Apply the selected inventory action to this item.", function()
                State.Apply(item)
            end)
        if IsFocused(data) then SubmitItemInfo(item, title) end
    end
end

local function CraftingView()
    DrawItemList("Crafting Components", Items.CraftingComponents)
end

local function ConsumablesView()
    DrawItemList("Health & Consumables", Items.Consumables)
end

local function BuffsView()
    DrawItemList("Boosters & Buffs", Items.Buffs)
end

local bulkQuantity = { value = 1, min = 1, max = 999, step = 1 }

local bulkActions = {
    { name = "All Crafting Components", detail = "Every standard crafting component", action = Items.Actions.GiveAllCraftingComponents },
    { name = "Item Components", detail = "All item component tiers", action = Items.Actions.GiveItemComponents },
    { name = "Quickhack Components", detail = "All quickhack component tiers", action = Items.Actions.GiveQuickhackComponents },
    { name = "Upgrade Components", detail = "All upgrade component tiers", action = Items.Actions.GiveUpgradeComponents },
    { name = "All Consumables", detail = "MaxDocs, Bounce Backs, and boosters", action = Items.Actions.GiveAllConsumables },
    { name = "MaxDocs", detail = "Every MaxDoc tier", action = Items.Actions.GiveMaxDocs },
    { name = "Bounce Backs", detail = "Every Bounce Back tier", action = Items.Actions.GiveBounceBacks },
    { name = "Boosters", detail = "All standard boosters", action = Items.Actions.GiveBoosters },
    { name = "All Buff Items", detail = "Black-market, booster, and food buffs", action = Items.Actions.GiveAllBuffs },
}

local function BulkView()
    Buttons.Int("Quantity Per Item", bulkQuantity, "Amount of every item included in the selected kit.")
    Buttons.Break("", "Quick Kits")
    for _, entry in ipairs(bulkActions) do
        local current = entry
        Buttons.OptionExtended(current.name, "", "+" .. tostring(bulkQuantity.value), current.detail, function()
            current.action(bulkQuantity.value)
            State.RefreshInventory()
            Notification.Success("Added " .. current.name, 2)
        end)
    end
end

local recipeActions = {
    { name = "Mod Recipes", detail = "Cyberware and weapon mod recipes", action = Items.ModRecipes.GiveAllModRecipes },
    { name = "Quickhack Recipes", detail = "All quickhack crafting recipes", action = Items.QuickhackRecipes.GiveAllQuickhackRecipes },
    { name = "Weapon Recipes", detail = "All weapon crafting recipes", action = Items.WeaponRecipes.GiveAllWeaponRecipes },
    { name = "Clothing Recipes", detail = "All clothing crafting recipes", action = Items.ClothingRecipes.GiveAllClothingRecipes },
    { name = "Grenade Recipes", detail = "All grenade crafting recipes", action = Items.GrenadeRecipes.GiveAllGrenadeRecipes },
}

local function RecipesView()
    for _, entry in ipairs(recipeActions) do
        local current = entry
        Buttons.Option(current.name, current.detail, function()
            current.action()
            Notification.Success("Unlocked " .. current.name, 2)
        end)
    end
end

local bulkMenu = { title = "Quick Kits", view = BulkView }
local craftingMenu = { title = "Crafting Components", view = CraftingView }
local consumablesMenu = { title = "Health & Consumables", view = ConsumablesView }
local buffsMenu = { title = "Boosters & Buffs", view = BuffsView }
local recipesMenu = { title = "Crafting Recipes", view = RecipesView }

local function ItemsMainView()
    Buttons.Submenu("Quick Kits", bulkMenu, "Add complete groups of commonly used items.")
    Buttons.Submenu("Crafting Components", craftingMenu, "Add or remove individual crafting components.")
    Buttons.Submenu("Health & Consumables", consumablesMenu, "Manage MaxDocs, Bounce Backs, and boosters.")
    Buttons.Submenu("Boosters & Buffs", buffsMenu, "Manage temporary buff items and special consumables.")
    Buttons.Submenu("Crafting Recipes", recipesMenu, "Unlock complete groups of crafting recipes.")
end

return { title = "Essentials", view = ItemsMainView }
