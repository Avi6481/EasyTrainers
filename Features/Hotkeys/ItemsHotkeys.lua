local Define = require("Features/Hotkeys/Define")
local Items = require("Features/Items/Items")

local Action = Define.Action
local Actions = Items.Actions

local GIVE = "hotkeys.names.give"

local function AddEddies()
    local amount = Actions.Eddies
    Items.Run(function() Actions.AddEddies(amount) end)
end

local function Kit(key, give)
    return function()
        local amount = Actions.KitQuantity
        Items.Run(function() Actions.Kit(key .. ".label", give, amount) end)
    end
end

local ItemsHotkeys = {
    Action("AddEddies", "items.eddies", AddEddies, { Silent = true, Note = "hotkeys.notes.addeddies" }),
    Action("Components", "items.kits.components", Kit("items.kits.components", Actions.GiveAllCraftingComponents), { Silent = true, Pattern = GIVE }),
    Action("UpgradeComponents", "items.kits.upgradecomponents", Kit("items.kits.upgradecomponents", Actions.GiveUpgradeComponents), { Silent = true, Pattern = GIVE }),
    Action("QuickhackComponents", "items.kits.quickhackcomponents", Kit("items.kits.quickhackcomponents", Actions.GiveQuickhackComponents), { Silent = true, Pattern = GIVE }),
    Action("MaxDocs", "items.kits.maxdocs", Kit("items.kits.maxdocs", Actions.GiveMaxDocs), { Silent = true, Pattern = GIVE }),
    Action("BounceBacks", "items.kits.bouncebacks", Kit("items.kits.bouncebacks", Actions.GiveBounceBacks), { Silent = true, Pattern = GIVE }),
    Action("Boosters", "items.kits.boosters", Kit("items.kits.boosters", Actions.GiveBoosters), { Silent = true, Pattern = GIVE })
}

return ItemsHotkeys
