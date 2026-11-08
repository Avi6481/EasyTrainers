local Logger = require("Core/Logger")

local StatModifiers = {}

local s_Applied = {}
local s_Dropped = {}

local function Create(entry)
    local modifier = RPGManager.CreateStatModifier(entry[1], entry[2], entry[3])
    if not modifier then
        Logger.Log(string.format("StatModifiers: failed to create %s %s %s", tostring(entry[1]), tostring(entry[2]), tostring(entry[3])))
    end
    return modifier
end

function StatModifiers.Remove(owner)
    local applied = s_Applied[owner]
    if not applied then return false end

    s_Applied[owner] = nil

    local stats = Game.GetStatsSystem()
    if not stats then return false end

    for _, modifier in ipairs(applied.Modifiers) do
        stats:RemoveModifier(applied.TargetID, modifier)
    end

    Logger.Log(string.format("StatModifiers: removed %d from %s", #applied.Modifiers, owner))
    return true
end

function StatModifiers.Add(owner, targetID, key, entries)
    StatModifiers.Remove(owner)

    local stats = Game.GetStatsSystem()
    if not stats or not targetID then return false end

    local modifiers = {}
    local applied = {}
    for _, entry in ipairs(entries) do
        local modifier = Create(entry)
        if modifier then
            stats:AddModifier(targetID, modifier)
            table.insert(modifiers, modifier)
            table.insert(applied, entry)
        end
    end

    s_Applied[owner] = { Owner = owner, TargetID = targetID, Key = key, Modifiers = modifiers, Entries = applied }
    Logger.Log(string.format("StatModifiers: applied %d to %s (%s)", #modifiers, owner, tostring(key)))
    return true
end

local function RemoveDropped()
    local owners = s_Dropped
    s_Dropped = {}
    for owner in pairs(owners) do StatModifiers.Remove(owner) end
end

function StatModifiers.Drop(owner)
    if s_Applied[owner] then s_Dropped[owner] = true end
end

function StatModifiers.Active()
    local list = {}
    for owner, applied in pairs(s_Applied) do
        if not s_Dropped[owner] then table.insert(list, applied) end
    end
    table.sort(list, function(first, second) return first.Owner < second.Owner end)
    return list
end

function StatModifiers.Sync(owner, enabled, key, targetID, build)
    if next(s_Dropped) then RemoveDropped() end

    local applied = s_Applied[owner]

    if not enabled then
        if applied then StatModifiers.Remove(owner) end
        return
    end

    if applied and applied.Key == key then return end
    StatModifiers.Add(owner, targetID, key, build())
end

function StatModifiers.RemoveAll()
    s_Dropped = {}
    local owners = {}
    for owner in pairs(s_Applied) do table.insert(owners, owner) end
    for _, owner in ipairs(owners) do StatModifiers.Remove(owner) end
    return #owners
end

return StatModifiers
