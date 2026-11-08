local Inventory = require("Utils/Inventory")
local Notify = require("Utils/Notify")

local Ammo = {
    AddAmounts = {},
    RemoveAmounts = {}
}

Ammo.Types = {
    { Key = "handgun", Record = "Ammo.HandgunAmmo" },
    { Key = "shotgun", Record = "Ammo.ShotgunAmmo" },
    { Key = "rifle", Record = "Ammo.RifleAmmo" },
    { Key = "sniper", Record = "Ammo.SniperRifleAmmo" },
    { Key = "special", Record = "Ammo.Special" }
}

local DEFAULTS = { AddAmounts = 50, RemoveAmounts = 10 }
local RESTOCK = 100

local function Amounts(field)
    local amounts = Ammo[field]
    if type(amounts) ~= "table" then
        amounts = {}
        Ammo[field] = amounts
    end
    return amounts
end

function Ammo.Amount(field, kind)
    return tonumber(Amounts(field)[kind.Key]) or DEFAULTS[field]
end

function Ammo.SetAmount(field, kind, value)
    Amounts(field)[kind.Key] = value
end

function Ammo.Give(kind, count)
    return Inventory.Give(kind.Record, count)
end

function Ammo.Remove(player, kind, count)
    return Inventory.Remove(player, kind.Record, count)
end

function Ammo.GiveEach(count)
    local given = 0
    for _, kind in ipairs(Ammo.Types) do
        if Ammo.Give(kind, count) then given = given + 1 end
    end
    return given
end

function Ammo.Restock()
    Ammo.GiveEach(RESTOCK)
    Notify.Success(tip("notify.weapons.ammoeach", { count = RESTOCK }))
end

function Ammo.RemoveEach(player, count)
    local removed = 0
    for _, kind in ipairs(Ammo.Types) do removed = removed + Ammo.Remove(player, kind, count) end
    return removed
end

return Ammo
