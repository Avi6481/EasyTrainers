local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Items = require("Features/Items/Items")
local ItemBrowserView = require("View/Items/ItemBrowserView")
local EssentialsView = require("View/Items/EssentialsView")

local ItemsView = {}

local Actions = Items.Actions

local MIN_QUANTITY = 1

local s_EddiesRef = Ref.Field(Actions, "Eddies")
local s_KitRef = Ref.Field(Actions, "KitQuantity")

local KITS = {
    { Key = "components", Action = Actions.GiveAllCraftingComponents },
    { Key = "upgradecomponents", Action = Actions.GiveUpgradeComponents },
    { Key = "quickhackcomponents", Action = Actions.GiveQuickhackComponents },
    { Key = "maxdocs", Action = Actions.GiveMaxDocs },
    { Key = "bouncebacks", Action = Actions.GiveBounceBacks },
    { Key = "boosters", Action = Actions.GiveBoosters }
}

local function Link(key, menu, badge)
    local pressed = Widgets.SubmenuButton(L("items." .. key .. ".label"), menu, badge)
    Widgets.Tip(L("items." .. key .. ".tip"))
    return pressed
end

local function Links()
    Link("catalog", ItemBrowserView.CatalogMenu, ItemBrowserView.Badge("catalog"))
    if Link("owned", ItemBrowserView.OwnedMenu, ItemBrowserView.Badge("owned")) then ItemBrowserView.OpenOwned() end
    Link("recent", ItemBrowserView.RecentMenu, ItemBrowserView.Badge("recent"))
    Link("essentials", EssentialsView.Menu)
end

local function QuickAdd()
    Widgets.Break(L("items.quickadd"))

    if Widgets.NumberActionInt(L("items.eddies.label"), s_EddiesRef, Actions.MIN_EDDIES, Actions.MAX_EDDIES, Actions.EDDIES_STEP, "%d") then
        local amount = Actions.Eddies
        Items.Run(function() Actions.AddEddies(amount) end)
    end
    Widgets.Tip(L("items.eddies.tip"))

    Widgets.SliderInt(L("items.kits.quantity.label"), s_KitRef, MIN_QUANTITY, Actions.MAX_QUANTITY, 1)
    Widgets.Tip(L("items.kits.quantity.tip"))

    local amount = Actions.KitQuantity
    for _, entry in ipairs(KITS) do EssentialsView.Kit(entry, amount) end

    if Widgets.HoldButton(L("items.recipes.all.label")) then
        Items.Run(function() Actions.Recipes(Actions.UnlockAllRecipes) end)
    end
    Widgets.Tip(L("items.recipes.all.tip"))
end

local function Database()
    Widgets.Break(L("items.database.title"))
    if Widgets.Button(L("items.database.reload.label")) then Items.Catalog.Reload() end
    Widgets.Tip(L("items.database.reload.tip"))
end

local function View()
    Items.Watch()
    if ItemBrowserView.Search() then return end

    Links()
    QuickAdd()
    Database()
end

ItemsView.Menu = Submenu.Create("items.title", View)

return ItemsView
