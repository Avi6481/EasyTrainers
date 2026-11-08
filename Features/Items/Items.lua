local Logger = require("Core/Logger")

local Items = {}

Items.Catalog = require("Features/Items/Catalog")
Items.BrowserState = require("Features/Items/ItemBrowserState")
Items.Actions = require("Features/Items/ItemActions")
Items.CraftingComponents = require("Features/Items/ItemsCraftingComponents")
Items.Consumables = require("Features/Items/ItemsConsumables")
Items.Buffs = require("Features/Items/ItemBuffs")
Items.ClothingRecipes = require("Features/Items/ItemClothingRecipes")
Items.GrenadeRecipes = require("Features/Items/ItemGrenadeRecipes")
Items.ModRecipes = require("Features/Items/ItemModRecipes")
Items.QuickhackRecipes = require("Features/Items/ItemQuickhackRecipes")
Items.WeaponRecipes = require("Features/Items/ItemWeaponRecipes")

local WATCH_TIME = 1

local s_Queue = {}
local s_WatchUntil = 0
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

function Items.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function Items.Watching()
    return os.clock() < s_WatchUntil
end

function Items.Run(action)
    table.insert(s_Queue, action)
end

function Items.Bind(store)
    store:Bind("Items.Browser", Items.BrowserState, { "Quantity" })
    store:Bind("Items.Actions", Items.Actions, { "KitQuantity", "BulkQuantity", "Eddies" })
end

function Items.Initialize()
end

local function RunQueue(player)
    local queue = s_Queue
    s_Queue = {}
    for _, action in ipairs(queue) do Try("Item action", action, player) end
end

function Items.Update(player)
    if #s_Queue > 0 then RunQueue(player) end
    if not Items.Watching() then return end

    if not Items.Catalog.Loaded then Try("Item catalog", Items.Catalog.Step) end
    Try("Item browser", Items.BrowserState.Update, player, os.clock())
end

function Items.Reset()
    s_Queue = {}
    Try("Item browser", Items.BrowserState.Reset)
end

function Items.Shutdown()
    s_Queue = {}
end

return Items
