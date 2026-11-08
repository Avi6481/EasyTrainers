local Logger = require("Core/Logger")
local Inventory = require("Utils/Inventory")
local Notify = require("Utils/Notify")
local Catalog = require("Features/Items/Catalog")

local ItemBrowserState = {
    Action = "Add",
    Quantity = 1,
    Ready = false,
    Changes = 0,
    OwnedVersion = 0,
    Kinds = 0,
    Copies = 0,
    Recent = {}
}

ItemBrowserState.ACTIONS = { "Add", "Remove", "RemoveAll" }
ItemBrowserState.MAX_QUANTITY = 999

local RECENT_LIMIT = 20
local PROTECTED_MONEY = "Items.money"
local OWNED_REFRESH = 1
local EVERY = math.huge

local s_Owned = {}
local s_OwnedItems = {}
local s_OwnedCatalog = nil
local s_NextOwned = 0
local s_Focus = nil
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

local function Quantity()
    return math.max(1, math.min(ItemBrowserState.MAX_QUANTITY, math.floor(tonumber(ItemBrowserState.Quantity) or 1)))
end

local function Remember(item)
    item = Catalog.ByRecord[item.Id] or item
    local recent = ItemBrowserState.Recent
    for index, entry in ipairs(recent) do
        if entry.Id == item.Id then
            table.remove(recent, index)
            break
        end
    end
    table.insert(recent, 1, item)
    if #recent > RECENT_LIMIT then table.remove(recent) end
end

function ItemBrowserState.Removing()
    return ItemBrowserState.Action ~= "Add"
end

function ItemBrowserState.Summary()
    if ItemBrowserState.Action == "RemoveAll" then return "-ALL" end
    return (ItemBrowserState.Removing() and "-" or "+") .. tostring(Quantity())
end

function ItemBrowserState.Count(item)
    if not item then return 0 end
    return s_Owned[item.Id] or 0
end

function ItemBrowserState.Focus(item)
    s_Focus = item
end

function ItemBrowserState.OwnedItems()
    return s_OwnedItems
end

local function OwnedList()
    local list = {}
    for record in pairs(s_Owned) do table.insert(list, Catalog.Lookup(record)) end
    return list
end

local function Owned(player)
    local owned = Inventory.Counts(player)
    local kinds, copies, changed = 0, 0, not ItemBrowserState.Ready
    for record, quantity in pairs(owned) do
        kinds = kinds + 1
        copies = copies + quantity
        if s_Owned[record] ~= quantity then changed = true end
    end
    for record in pairs(s_Owned) do
        if not owned[record] then changed = true end
    end

    s_Owned = owned
    ItemBrowserState.Kinds = kinds
    ItemBrowserState.Copies = copies
    ItemBrowserState.Ready = true

    local rebuild = Catalog.Loaded and (changed or s_OwnedCatalog ~= Catalog.Version)
    if rebuild then
        s_OwnedItems = OwnedList()
        s_OwnedCatalog = Catalog.Version
    end
    if changed or rebuild then ItemBrowserState.OwnedVersion = ItemBrowserState.OwnedVersion + 1 end
end

local function Sync(player, now)
    s_NextOwned = now + OWNED_REFRESH
    Try("Item inventory", Owned, player)
end

function ItemBrowserState.Refresh(player)
    if not player then return end
    Sync(player, os.clock())
end

function ItemBrowserState.Update(player, now)
    now = now or os.clock()
    if not player then return end

    if s_Focus and not s_Focus.Resolved then Try("Item details", Catalog.Resolve, s_Focus) end
    if now >= s_NextOwned then Sync(player, now) end
end

local function Removed(item, removed)
    if removed > 0 then
        Notify.Success(tip("notify.items.removed", { name = item.Name, count = removed }))
    else
        Notify.Info(tip("notify.items.notowned", { name = item.Name }))
    end
end

function ItemBrowserState.Apply(player, item)
    if not item or not item.Id then return end

    local action = ItemBrowserState.Action
    if action == "Add" then
        local count = Quantity()
        if Inventory.Give(item.Id, count) then
            Notify.Success(tip("notify.items.added", { name = item.Name, count = count }))
        else
            Notify.Error(tip("notify.items.addfailed", { name = item.Name }))
        end
    else
        Removed(item, Inventory.Remove(player, item.Id, action == "RemoveAll" and EVERY or Quantity()))
    end

    Remember(item)
    ItemBrowserState.Refresh(player)
end

local function Report(removing, done, failed)
    if removing then
        if done == 0 then
            Notify.Info(L("notify.items.nothingtoremove"))
            return
        end
        Notify.Success(tip("notify.items.removedmany", { count = done }))
        return
    end

    if failed > 0 then
        Notify.Warning(tip("notify.items.addedsome", { count = done, failed = failed }))
        return
    end
    Notify.Success(tip("notify.items.addedmany", { count = done }))
end

local function Protected(item)
    return item.Category == "quest" or item.Id == PROTECTED_MONEY
end

function ItemBrowserState.ApplyAll(player, items)
    if not items or #items == 0 then
        Notify.Info(L("notify.items.nothingshown"))
        return
    end

    local removing = ItemBrowserState.Removing()
    local count = ItemBrowserState.Action == "RemoveAll" and EVERY or Quantity()
    local applied = {}
    local done, failed = 0, 0
    if removing then
        local counts = {}
        for _, item in ipairs(items) do
            if not Protected(item) then
                counts[item.Id] = count
                if (s_Owned[item.Id] or 0) > 0 then table.insert(applied, item) end
            end
        end
        done = Inventory.RemoveMany(player, counts)
    else
        for _, item in ipairs(items) do
            if Inventory.Give(item.Id, count) then
                done = done + count
                table.insert(applied, item)
            else
                failed = failed + 1
            end
        end
    end

    for index = math.min(#applied, RECENT_LIMIT), 1, -1 do Remember(applied[index]) end
    ItemBrowserState.Refresh(player)
    ItemBrowserState.Changes = ItemBrowserState.Changes + 1
    Report(removing, done, failed)
end

function ItemBrowserState.Reset()
    s_Owned = {}
    s_OwnedItems = {}
    s_OwnedCatalog = nil
    s_NextOwned = 0
    s_Focus = nil
    ItemBrowserState.Ready = false
    ItemBrowserState.Kinds = 0
    ItemBrowserState.Copies = 0
    ItemBrowserState.OwnedVersion = ItemBrowserState.OwnedVersion + 1
    ItemBrowserState.Changes = ItemBrowserState.Changes + 1
end

return ItemBrowserState
