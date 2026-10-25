local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Notification = require("UI/Panels/Notification/Notification")
local Items = require("Features/Items")

local State = Items.BrowserState

local function DrawItemControls()
    Buttons.Dropdown("Inventory Action", State.Action, State.Actions,
        "Choose whether selecting an item adds it to or removes it from your inventory.")
    Buttons.Int("Quantity", State.Quantity, "Amount applied each time you select an item.")
end

local function SubmitItemInfo(item, section)
    local description = State.GetDescription(item.id)
    SidePanel.SubmitInfo("essential-item", {
        Eyebrow = "ESSENTIAL ITEM",
        Title = item.name,
        Icon = item.id,
        Rows = {
            { Label = "Section", Value = section },
            { Label = "Group", Value = item.group or "Other" },
            { Label = "Owned", Value = tostring(State.GetOwned(item.id)) },
            { Label = "Action", Value = State.GetAction() .. " " .. tostring(State.Quantity.value) },
        },
        Description = (description ~= "" and (description .. "\n\n") or "") .. item.id,
    }, { Width = 310 })
end

local function DrawItemList(title, items)
    DrawItemControls()
    Buttons.Break(title .. "  /  " .. tostring(#items))

    local lastGroup
    for _, item in ipairs(items) do
        if item.group ~= lastGroup then
            Buttons.Break(item.group)
            lastGroup = item.group
        end
        local _, data = Buttons.OptionExtended(item.name, "", State.GetSummary(),
            "Apply the selected inventory action to this item.", function()
                State.Apply(item)
            end)
        if data and data.Visible and (data.Selected or data.Hovered) then SubmitItemInfo(item, title) end
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

local s_BulkQuantity = { value = 1, min = 1, max = 999, step = 1 }

local BULK_ACTIONS = {
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
    Buttons.Int("Quantity Per Item", s_BulkQuantity, "Amount of every item included in the selected kit.")
    Buttons.Break("Quick Kits")
    for _, entry in ipairs(BULK_ACTIONS) do
        Buttons.OptionExtended(entry.name, "", "+" .. tostring(s_BulkQuantity.value), entry.detail, function()
            entry.action(s_BulkQuantity.value)
            State.RefreshInventory()
            Notification.Success("Added " .. entry.name, 2)
        end)
    end
end

local RECIPE_ACTIONS = {
    { name = "Mod Recipes", detail = "Cyberware and weapon mod recipes", action = Items.ModRecipes.GiveAllModRecipes },
    { name = "Quickhack Recipes", detail = "All quickhack crafting recipes", action = Items.QuickhackRecipes.GiveAllQuickhackRecipes },
    { name = "Weapon Recipes", detail = "All weapon crafting recipes", action = Items.WeaponRecipes.GiveAllWeaponRecipes },
    { name = "Clothing Recipes", detail = "All clothing crafting recipes", action = Items.ClothingRecipes.GiveAllClothingRecipes },
    { name = "Grenade Recipes", detail = "All grenade crafting recipes", action = Items.GrenadeRecipes.GiveAllGrenadeRecipes },
}

local function RecipesView()
    for _, entry in ipairs(RECIPE_ACTIONS) do
        Buttons.Option(entry.name, entry.detail, function()
            entry.action()
            Notification.Success("Unlocked " .. entry.name, 2)
        end)
    end
end

local BulkMenu = Submenu.Create("Quick Kits", BulkView)
local CraftingMenu = Submenu.Create("Crafting Components", CraftingView)
local ConsumablesMenu = Submenu.Create("Health & Consumables", ConsumablesView)
local BuffsMenu = Submenu.Create("Boosters & Buffs", BuffsView)
local RecipesMenu = Submenu.Create("Crafting Recipes", RecipesView)

local function ItemsMainView()
    Buttons.Submenu("Quick Kits", BulkMenu, "Add complete groups of commonly used items.")
    Buttons.Submenu("Crafting Components", CraftingMenu, "Add or remove individual crafting components.")
    Buttons.Submenu("Health & Consumables", ConsumablesMenu, "Manage MaxDocs, Bounce Backs, and boosters.")
    Buttons.Submenu("Boosters & Buffs", BuffsMenu, "Manage temporary buff items and special consumables.")
    Buttons.Submenu("Crafting Recipes", RecipesMenu, "Unlock complete groups of crafting recipes.")
end

return Submenu.Create("Essentials", ItemsMainView)
