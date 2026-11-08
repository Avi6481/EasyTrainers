local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Items = require("Features/Items/Items")
local ItemBrowserView = require("View/Items/ItemBrowserView")
local ItemInfo = require("View/Items/ItemInfo")

local EssentialsView = {}

local Actions = Items.Actions

local MIN_QUANTITY = 1

local s_BulkRef = Ref.Field(Actions, "BulkQuantity")
local s_Values = {}
local s_Groups = {}

local BULK_ACTIONS = {
    { Key = "allcomponents", Action = Actions.GiveAllCraftingComponents },
    { Key = "itemcomponents", Action = Actions.GiveItemComponents },
    { Key = "quickhackcomponents", Action = Actions.GiveQuickhackComponents },
    { Key = "upgradecomponents", Action = Actions.GiveUpgradeComponents },
    { Key = "allconsumables", Action = Actions.GiveAllConsumables },
    { Key = "maxdocs", Action = Actions.GiveMaxDocs },
    { Key = "bouncebacks", Action = Actions.GiveBounceBacks },
    { Key = "boosters", Action = Actions.GiveBoosters },
    { Key = "allbuffs", Action = Actions.GiveAllBuffs }
}

local RECIPE_ACTIONS = {
    { Key = "mods", Action = Items.ModRecipes.GiveAllModRecipes },
    { Key = "quickhacks", Action = Items.QuickhackRecipes.GiveAllQuickhackRecipes },
    { Key = "weapons", Action = Items.WeaponRecipes.GiveAllWeaponRecipes },
    { Key = "clothing", Action = Items.ClothingRecipes.GiveAllClothingRecipes },
    { Key = "grenades", Action = Items.GrenadeRecipes.GiveAllGrenadeRecipes }
}

local function Section(key, list)
    local title = "items.essentials." .. key .. ".label"
    return { Title = title, Items = list, Info = ItemInfo.Section(title) }
end

local CRAFTING = Section("crafting", Items.CraftingComponents)
local CONSUMABLES = Section("consumables", Items.Consumables)
local BUFFS = Section("buffs", Items.Buffs)

local function Amount(value)
    local text = s_Values[value]
    if text then return text end

    text = "+" .. tostring(value)
    s_Values[value] = text
    return text
end

local function GroupLabel(group)
    local key = s_Groups[group]
    if not key then
        key = "items.essentials.groups." .. group:lower()
        s_Groups[group] = key
    end
    return L(key)
end

local function DrawItemList(section)
    Items.Watch()
    ItemBrowserView.Controls()

    local lastGroup
    for _, item in ipairs(section.Items) do
        if item.Group ~= lastGroup then
            Widgets.Break(GroupLabel(item.Group))
            lastGroup = item.Group
        end
        ItemBrowserView.Row(item, section.Info)
    end
end

function EssentialsView.Kit(entry, amount)
    local key = "items.kits." .. entry.Key
    if Widgets.ValueRow(L(key .. ".label"), Amount(amount), true) then
        Items.Run(function() Actions.Kit(key .. ".label", entry.Action, amount) end)
    end
    Widgets.Tip(L(key .. ".tip"))
end

local function BulkView()
    Widgets.SliderInt(L("items.essentials.kits.quantity.label"), s_BulkRef, MIN_QUANTITY, Actions.MAX_QUANTITY, 1)
    Widgets.Tip(L("items.essentials.kits.quantity.tip"))

    Widgets.Break(L("items.essentials.kits.label"))
    local amount = Actions.BulkQuantity
    for _, entry in ipairs(BULK_ACTIONS) do EssentialsView.Kit(entry, amount) end
end

local function RecipesView()
    for _, entry in ipairs(RECIPE_ACTIONS) do
        local key = "items.recipes." .. entry.Key
        if Widgets.Button(L(key .. ".label")) then
            Items.Run(function() Actions.Recipes(entry.Action) end)
        end
        Widgets.Tip(L(key .. ".tip"))
    end
end

local BulkMenu = Submenu.Create("items.essentials.kits.label", BulkView)
local CraftingMenu = Submenu.Create(CRAFTING.Title, function() DrawItemList(CRAFTING) end)
local ConsumablesMenu = Submenu.Create(CONSUMABLES.Title, function() DrawItemList(CONSUMABLES) end)
local BuffsMenu = Submenu.Create(BUFFS.Title, function() DrawItemList(BUFFS) end)
local RecipesMenu = Submenu.Create("items.essentials.recipes.label", RecipesView)

local function Link(key, menu)
    Widgets.SubmenuButton(L("items.essentials." .. key .. ".label"), menu)
    Widgets.Tip(L("items.essentials." .. key .. ".tip"))
end

local function View()
    Link("kits", BulkMenu)
    Link("crafting", CraftingMenu)
    Link("consumables", ConsumablesMenu)
    Link("buffs", BuffsMenu)
    Link("recipes", RecipesMenu)
end

EssentialsView.Menu = Submenu.Create("items.essentials.label", View)

return EssentialsView
