local Logger = require("Core/Logger")
local Catalog = require("Features/Weapons/Catalog")
local GameText = require("Utils/GameText")
local Inventory = require("Utils/Inventory")
local Notify = require("Utils/Notify")
local Weapon = require("Utils/Weapon")

local Arsenal = {
    Action = "Add",
    Quantity = 1,
    Ready = false,
    Changes = 0,
    OwnedVersion = 0,
    Kinds = 0,
    Copies = 0,
    IconicOwned = 0,
    WallOwned = 0,
    Hands = false,
    Slots = { false, false, false, false }
}

Arsenal.ACTIONS = { "Add", "Remove" }
Arsenal.SLOTS = 4
Arsenal.MAX_QUANTITY = 50

local WATCH_TIME = 1
local OWNED_REFRESH = 1
local STATS_REFRESH = 0.5
local MISSING = "Label Not Found"
local STAT_KEYS = { "Damage", "Pellets", "FireRate", "Magazine", "Reload", "Range", "CritChance", "Headshot" }

local s_Owned = {}
local s_WatchUntil = 0
local s_NextOwned = 0
local s_NextStats = 0
local s_HandsKey = nil
local s_HandsCatalog = nil
local s_Focus = nil
local s_Stats = nil
local s_StatsFor = nil
local s_StatsSignature = nil
local s_Names = {}
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

local function Call(callback)
    local ok, result = pcall(callback)
    if ok then return result end
    return nil
end

local function Quantity()
    return math.max(1, math.min(Arsenal.MAX_QUANTITY, math.floor(tonumber(Arsenal.Quantity) or 1)))
end

local function EnsureCatalog()
    if not Catalog.Loaded then Catalog.Load() end
end

function Arsenal.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function Arsenal.Removing()
    return Arsenal.Action == "Remove"
end

function Arsenal.Summary()
    return (Arsenal.Removing() and "-" or "+") .. tostring(Quantity())
end

function Arsenal.Count(weapon)
    if not weapon then return 0 end
    return s_Owned[weapon.Id] or 0
end

function Arsenal.Focus(weapon)
    s_Focus = weapon
end

function Arsenal.Stats(weapon)
    if not weapon or s_StatsFor ~= weapon.Id or Arsenal.Count(weapon) == 0 then return nil end
    return s_Stats
end

function Arsenal.Give(weapon, count)
    return Inventory.Give(weapon.Id, count or 1)
end

function Arsenal.Remove(player, weapon, count)
    return Inventory.Remove(player, weapon.Id, count or 1)
end

local function Owned(player)
    local owned = {}
    local kinds, copies, iconic, wall = 0, 0, 0, 0
    for record, quantity in pairs(Inventory.Counts(player)) do
        local weapon = Catalog.ByRecord[record]
        if weapon then
            owned[record] = quantity
            kinds = kinds + 1
            copies = copies + quantity
            if weapon.Iconic then iconic = iconic + 1 end
            if weapon.Wall then wall = wall + 1 end
        end
    end

    local changed = not Arsenal.Ready or kinds ~= Arsenal.Kinds or copies ~= Arsenal.Copies
        or iconic ~= Arsenal.IconicOwned or wall ~= Arsenal.WallOwned
    s_Owned = owned
    Arsenal.Kinds = kinds
    Arsenal.Copies = copies
    Arsenal.IconicOwned = iconic
    Arsenal.WallOwned = wall
    Arsenal.Ready = true
    if changed then Arsenal.OwnedVersion = Arsenal.OwnedVersion + 1 end
end

local function NameOf(record)
    local name = s_Names[record]
    if name then return name end

    local data = TweakDB:GetRecord(record)
    local key = data and Call(function() return data:DisplayName() end)
    name = key and GameText.FromName(key, nil)
    if not name or name == "" or name == MISSING then name = record end
    s_Names[record] = name
    return name
end

local function Entry(record, previous)
    local weapon = Catalog.ByRecord[record]
    if previous and previous.Record == record and previous.Weapon == weapon then return previous end
    return { Record = record, Weapon = weapon, Name = weapon and weapon.Name or NameOf(record) }
end

local function EquipData(player)
    local container = Game.GetScriptableSystemsContainer()
    local system = container and container:Get("EquipmentSystem")
    return system and system:GetPlayerData(player) or nil
end

local function SlotRecord(data, index)
    local item = Call(function() return data:GetItemInEquipSlot(gamedataEquipmentArea.Weapon, index) end)
    local hash = item and Call(function() return item.id.hash end)
    if not item or hash == 0 then return nil end
    return Call(function() return TDBID.ToStringDEBUG(item.id) end)
end

local function Loadout(player)
    local data = EquipData(player)
    for index = 1, Arsenal.SLOTS do
        local record = data and SlotRecord(data, index - 1)
        Arsenal.Slots[index] = record and record ~= "" and Entry(record, Arsenal.Slots[index] or nil) or false
    end
end

local function Hands()
    local hand = Weapon.Right
    if hand.Key == s_HandsKey and s_HandsCatalog == Catalog.Version then return end
    s_HandsKey = hand.Key
    s_HandsCatalog = Catalog.Version
    Arsenal.Hands = hand.Record and Entry(hand.Record, Arsenal.Hands or nil) or false
end

local function Sync(player, now)
    s_NextOwned = now + OWNED_REFRESH
    Try("Weapon inventory", Owned, player)
    Try("Weapon loadout", Loadout, player)
end

function Arsenal.Refresh(player)
    if not player then return end
    Sync(player, os.clock())
    s_NextStats = 0
end

local function Stat(system, id, kind)
    local ok, value = pcall(function() return system:GetStatValue(id, gamedataStatType[kind]) end)
    if ok and type(value) == "number" then return value end
    return nil
end

local function StatsID(player, weapon)
    local hand = Weapon.Right
    if hand.Record == weapon.Id and hand.StatsID then return hand.StatsID end

    local data = Inventory.Find(player, weapon.Id)
    return data and data:GetStatsObjectID() or nil
end

local function Read(player, weapon)
    local system = Game.GetStatsSystem()
    local id = system and StatsID(player, weapon)
    if not id then return nil end

    local cycle = Stat(system, id, "CycleTime")
    local stats = {
        Damage = Stat(system, id, "DamagePerHit"),
        Pellets = math.max(1, Stat(system, id, "ProjectilesPerShot") or 1),
        FireRate = (cycle and cycle > 0) and (1 / cycle) or nil,
        Magazine = Stat(system, id, "MagazineCapacity"),
        Reload = Stat(system, id, "ReloadTime"),
        Range = Stat(system, id, "EffectiveRange"),
        CritChance = Stat(system, id, "CritChance"),
        Headshot = Stat(system, id, "HeadshotDamageMultiplier")
    }
    if stats.Damage and stats.FireRate then stats.DPS = stats.Damage * stats.FireRate * stats.Pellets end
    return stats
end

local function Signature(stats)
    if not stats then return "" end

    local parts = {}
    for index, key in ipairs(STAT_KEYS) do parts[index] = string.format("%.2f", stats[key] or -1) end
    return table.concat(parts, "|")
end

local function Stats(player, now)
    local weapon = s_Focus
    if not weapon then return end
    if weapon.Id ~= s_StatsFor then s_NextStats = 0 end
    if now < s_NextStats then return end
    s_NextStats = now + STATS_REFRESH

    local stats = (s_Owned[weapon.Id] or 0) > 0 and Read(player, weapon) or nil
    local signature = Signature(stats)
    if weapon.Id == s_StatsFor and signature == s_StatsSignature then return end

    s_Stats = stats
    s_StatsFor = weapon.Id
    s_StatsSignature = signature
end

function Arsenal.Update(player, now)
    now = now or os.clock()
    if now >= s_WatchUntil or not player or not Catalog.Loaded then return end

    if s_Focus and not s_Focus.Resolved then Try("Weapon details", Catalog.Resolve, s_Focus) end
    if now >= s_NextOwned then Sync(player, now) end
    Try("Weapon in hands", Hands)
    Try("Weapon stats", Stats, player, now)
end

function Arsenal.Apply(player, weapon)
    local count = Quantity()
    if Arsenal.Removing() then
        local removed = Arsenal.Remove(player, weapon, count)
        if removed > 0 then
            Notify.Success(tip("notify.weapons.removed", { name = weapon.Name, count = removed }))
        else
            Notify.Info(tip("notify.weapons.notowned", { name = weapon.Name }))
        end
    elseif Arsenal.Give(weapon, count) then
        Notify.Success(tip("notify.weapons.added", { name = weapon.Name, count = count }))
    else
        Notify.Error(tip("notify.weapons.addfailed", { name = weapon.Name }))
    end
    Arsenal.Refresh(player)
end

local function Report(removing, done, failed)
    if removing then
        if done == 0 then
            Notify.Info(L("notify.weapons.nothingtoremove"))
            return
        end
        Notify.Success(tip("notify.weapons.removedmany", { count = done }))
        return
    end

    if failed > 0 then
        Notify.Warning(tip("notify.weapons.addedsome", { count = done, failed = failed }))
        return
    end
    Notify.Success(tip("notify.weapons.addedmany", { count = done }))
end

function Arsenal.ApplyAll(player, weapons)
    if not weapons or #weapons == 0 then
        Notify.Info(L("notify.weapons.nothingshown"))
        return
    end

    local count = Quantity()
    local removing = Arsenal.Removing()
    local done, failed = 0, 0
    if removing then
        local counts = {}
        for _, weapon in ipairs(weapons) do counts[weapon.Id] = count end
        done = Inventory.RemoveMany(player, counts)
    else
        for _, weapon in ipairs(weapons) do
            if Arsenal.Give(weapon, count) then
                done = done + count
            else
                failed = failed + 1
            end
        end
    end

    Arsenal.Refresh(player)
    Arsenal.Changes = Arsenal.Changes + 1
    Report(removing, done, failed)
end

local function GiveEach(player, weapons)
    local given = 0
    for _, weapon in ipairs(weapons) do
        if Arsenal.Give(weapon, 1) then given = given + 1 end
    end
    Arsenal.Refresh(player)
    Arsenal.Changes = Arsenal.Changes + 1
    return given
end

function Arsenal.GiveWall(player)
    EnsureCatalog()
    return GiveEach(player, Catalog.Wall)
end

function Arsenal.GiveIconic(player)
    EnsureCatalog()
    return GiveEach(player, Catalog.Iconic)
end

function Arsenal.RemoveAll(player)
    EnsureCatalog()
    local counts = {}
    for record, quantity in pairs(Inventory.Counts(player)) do
        if Catalog.ByRecord[record] then counts[record] = quantity end
    end

    local removed = Inventory.RemoveMany(player, counts)
    Arsenal.Refresh(player)
    Arsenal.Changes = Arsenal.Changes + 1
    return removed
end

function Arsenal.Reset()
    s_Owned = {}
    s_NextOwned = 0
    s_NextStats = 0
    s_HandsKey = nil
    s_HandsCatalog = nil
    s_Focus = nil
    s_Stats = nil
    s_StatsFor = nil
    s_StatsSignature = nil
    Arsenal.Ready = false
    Arsenal.Kinds = 0
    Arsenal.Copies = 0
    Arsenal.IconicOwned = 0
    Arsenal.WallOwned = 0
    Arsenal.Hands = false
    Arsenal.Slots = { false, false, false, false }
    Arsenal.OwnedVersion = Arsenal.OwnedVersion + 1
    Arsenal.Changes = Arsenal.Changes + 1
end

return Arsenal
