local Inventory = require("Utils").Inventory
local Notification = require("UI").Notification

local ItemBrowserState = {
    Action = { index = 1 },
    Actions = { "Add", "Remove", "Remove All" },
    Quantity = { value = 1, min = 1, max = 999, step = 1 },
    Owned = nil,
    InventoryItems = nil,
}

function ItemBrowserState.RefreshInventory()
    ItemBrowserState.InventoryItems = Inventory.GetAllItems() or {}
    ItemBrowserState.Owned = {}
    for _, item in ipairs(ItemBrowserState.InventoryItems) do
        ItemBrowserState.Owned[item.id] = (ItemBrowserState.Owned[item.id] or 0) + (item.quantity or 1)
    end
    return ItemBrowserState.Owned
end

function ItemBrowserState.GetInventory()
    if not ItemBrowserState.InventoryItems then ItemBrowserState.RefreshInventory() end
    return ItemBrowserState.InventoryItems
end

function ItemBrowserState.GetOwned(id)
    if not ItemBrowserState.Owned then ItemBrowserState.RefreshInventory() end
    return ItemBrowserState.Owned[id] or 0
end

function ItemBrowserState.GetAction()
    return ItemBrowserState.Actions[ItemBrowserState.Action.index or 1]
end

function ItemBrowserState.GetSummary(quantity)
    if ItemBrowserState.GetAction() == "Remove All" then return "-ALL" end
    local prefix = ItemBrowserState.GetAction() == "Remove" and "-" or "+"
    return prefix .. tostring(quantity or ItemBrowserState.Quantity.value)
end

function ItemBrowserState.Apply(item, quantity)
    if not item or not item.id then return false end
    local action = ItemBrowserState.GetAction()
    local amount = action == "Remove All" and ItemBrowserState.GetOwned(item.id)
        or quantity or ItemBrowserState.Quantity.value
    local name = item.name or item.displayName or item.id
    local removing = action ~= "Add"
    if amount < 1 then
        Notification.Error("You do not own " .. name, 2)
        return false
    end
    local success = removing and Inventory.RemoveItem(item.id, amount) or Inventory.GiveItem(item.id, amount)

    if success then
        local owned = ItemBrowserState.GetOwned(item.id)
        local updated = math.max(0, owned + (removing and -amount or amount))
        ItemBrowserState.Owned[item.id] = updated

        local found
        for index, entry in ipairs(ItemBrowserState.InventoryItems or {}) do
            if entry.id == item.id then
                found = true
                if updated == 0 then
                    table.remove(ItemBrowserState.InventoryItems, index)
                else
                    entry.quantity = updated
                end
                break
            end
        end
        if not found and updated > 0 then
            table.insert(ItemBrowserState.InventoryItems, {
                id = item.id,
                name = item.name or item.displayName or item.id,
                quantity = updated,
            })
        end
        Notification.Success(string.format("%s %dx %s", removing and "Removed" or "Added", amount, name), 2)
    else
        Notification.Error(string.format("Could not %s %s", removing and "remove" or "add", name), 2)
    end
    return success
end

return ItemBrowserState
