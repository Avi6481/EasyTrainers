local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local Weapons = require("Features/Weapons/Weapons")

local AmmoView = {}

local Ammo = Weapons.Ammo

local REMOVE_EACH = 25
local KEY = "weapons.ammo."

local s_Rows = nil

local function Rows()
    if s_Rows then return s_Rows end

    s_Rows = {}
    for _, kind in ipairs(Ammo.Types) do
        local name = L(KEY .. "types." .. kind.Key)
        table.insert(s_Rows, {
            Kind = kind,
            Name = name,
            Add = Ref.New(function() return Ammo.Amount("AddAmounts", kind) end, function(value) Ammo.SetAmount("AddAmounts", kind, value) end),
            Remove = Ref.New(function() return Ammo.Amount("RemoveAmounts", kind) end, function(value) Ammo.SetAmount("RemoveAmounts", kind, value) end),
            AddTip = tip(KEY .. "addtip", { ammo = name }),
            RemoveTip = tip(KEY .. "removetip", { ammo = name })
        })
    end
    return s_Rows
end

local function GiveEach()
    Weapons.Run(Ammo.Restock)
end

local function Removed(count)
    if count > 0 then
        Notify.Success(tip("notify.weapons.ammoremoved", { count = count }))
    else
        Notify.Info(L("notify.weapons.noammo"))
    end
end

local function RemoveEach()
    Weapons.Run(function(player) Removed(Ammo.RemoveEach(player, REMOVE_EACH)) end)
end

local function Give(row)
    local count = row.Add.Value
    Weapons.Run(function()
        if Ammo.Give(row.Kind, count) then Notify.Success(tip("notify.weapons.ammogiven", { count = count, ammo = row.Name })) end
    end)
end

local function Remove(row)
    local count = row.Remove.Value
    Weapons.Run(function(player) Removed(Ammo.Remove(player, row.Kind, count)) end)
end

local function View()
    if Widgets.Button(L(KEY .. "giveeach.label")) then GiveEach() end
    Widgets.Tip(L(KEY .. "giveeach.tip"))
    if Widgets.Button(L(KEY .. "removeeach.label")) then RemoveEach() end
    Widgets.Tip(L(KEY .. "removeeach.tip"))

    local rows = Rows()
    Widgets.Break(L(KEY .. "add"))
    for _, row in ipairs(rows) do
        if Widgets.NumberActionInt(row.Name, row.Add, 1, 999, 10, "%d") then Give(row) end
        Widgets.Tip(row.AddTip)
    end

    Widgets.Break(L(KEY .. "remove"))
    for _, row in ipairs(rows) do
        if Widgets.NumberActionInt(row.Name, row.Remove, 1, 999, 10, "%d") then Remove(row) end
        Widgets.Tip(row.RemoveTip)
    end
end

AmmoView.Menu = Submenu.Create("weapons.ammo.label", View)

return AmmoView
