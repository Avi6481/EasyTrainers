local Logger = require("Core/Logger")
local Inventory = require("Utils/Inventory")
local Notify = require("Utils/Notify")
local CraftingComponents = require("Features/Items/ItemsCraftingComponents")
local Consumables = require("Features/Items/ItemsConsumables")
local ItemBuffs = require("Features/Items/ItemBuffs")
local ClothingRecipes = require("Features/Items/ItemClothingRecipes")
local GrenadeRecipes = require("Features/Items/ItemGrenadeRecipes")
local ModRecipes = require("Features/Items/ItemModRecipes")
local QuickhackRecipes = require("Features/Items/ItemQuickhackRecipes")
local WeaponRecipes = require("Features/Items/ItemWeaponRecipes")

local ItemActions = {
    KitQuantity = 10,
    BulkQuantity = 1,
    Eddies = 100000
}

ItemActions.MAX_QUANTITY = 999
ItemActions.MIN_EDDIES = 10000
ItemActions.MAX_EDDIES = 10000000
ItemActions.EDDIES_STEP = 10000

local MONEY = "Items.money"

local function Give(id, amount)
    if not TweakDB:GetRecord(id) then return false end
    return Inventory.Give(id, amount)
end

local function GiveAll(list, amount)
    amount = amount or 1
    local given, failed = 0, 0
    for _, data in ipairs(list) do
        if Give(data.Id, amount) then
            given = given + 1
        else
            failed = failed + 1
        end
    end
    return given, failed
end

local function GiveByGroup(list, group, amount)
    amount = amount or 1
    local given, failed = 0, 0
    for _, data in ipairs(list) do
        if data.Group == group then
            if Give(data.Id, amount) then
                given = given + 1
            else
                failed = failed + 1
            end
        end
    end
    return given, failed
end

function ItemActions.GiveAllCraftingComponents(amount)
    return GiveAll(CraftingComponents, amount)
end

function ItemActions.GiveItemComponents(amount)
    return GiveByGroup(CraftingComponents, "ItemComponent", amount)
end

function ItemActions.GiveQuickhackComponents(amount)
    return GiveByGroup(CraftingComponents, "QuickhackComponent", amount)
end

function ItemActions.GiveUpgradeComponents(amount)
    return GiveByGroup(CraftingComponents, "UpgradeComponent", amount)
end

function ItemActions.GiveSpecialComponents(amount)
    return GiveByGroup(CraftingComponents, "Special", amount)
end

function ItemActions.GiveAllConsumables(amount)
    return GiveAll(Consumables, amount)
end

function ItemActions.GiveMaxDocs(amount)
    return GiveByGroup(Consumables, "MaxDoc", amount)
end

function ItemActions.GiveBounceBacks(amount)
    return GiveByGroup(Consumables, "BounceBack", amount)
end

function ItemActions.GiveBoosters(amount)
    return GiveByGroup(Consumables, "Booster", amount)
end

function ItemActions.GiveAllBuffs(amount)
    return GiveAll(ItemBuffs, amount)
end

function ItemActions.GiveBuffsByGroup(group, amount)
    return GiveByGroup(ItemBuffs, group, amount)
end

function ItemActions.UnlockAllRecipes()
    local seen = {}
    local unlocked, known, failed = 0, 0, 0
    for _, unlock in ipairs({
        ModRecipes.GiveAllModRecipes,
        QuickhackRecipes.GiveAllQuickhackRecipes,
        WeaponRecipes.GiveAllWeaponRecipes,
        ClothingRecipes.GiveAllClothingRecipes,
        GrenadeRecipes.GiveAllGrenadeRecipes
    }) do
        local added, had, missed = unlock(seen)
        unlocked = unlocked + added
        known = known + had
        failed = failed + missed
    end
    return unlocked, known, failed
end

function ItemActions.Kit(name, give, amount)
    local given, failed = give(amount)
    if given == 0 then
        Notify.Error(tip("notify.items.addfailed", { name = name }))
        return
    end
    if failed > 0 then
        Notify.Warning(tip("notify.items.kitsome", { name = name, count = amount, failed = failed }))
        return
    end
    Notify.Success(tip("notify.items.added", { name = name, count = amount }))
end

function ItemActions.Recipes(unlock)
    local unlocked, known, failed = unlock()
    if failed > 0 then Logger.Log(string.format("Items: %d recipe records couldn't be unlocked", failed)) end
    if unlocked > 0 then
        Notify.Success(tip("notify.items.recipes.unlocked", { count = unlocked }))
    elseif known > 0 then
        Notify.Info(L("notify.items.recipes.known"))
    else
        Notify.Error(L("notify.items.recipes.failed"))
    end
end

function ItemActions.AddEddies(amount)
    if Inventory.Give(MONEY, amount) then
        Notify.Success(tip("notify.items.eddies", { count = amount }))
    else
        Notify.Error(L("notify.items.eddiesfailed"))
    end
end

return ItemActions
