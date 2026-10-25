local Logger = require("Core/Logger")
local Lifecycle = require("Core/Lifecycle")
local Vehicle = require("Utils/Vehicle")

local VehicleSpawning = {}

local DEFAULT_SEAT = "seat_front_left"
local NATIVE_TIMEOUT = 15.0
local NATIVE_ATTACHED = 4
local NATIVE_UPDATE_GRACE = 5.0
local NATIVE_TAG = "EasyTrainer"
local MOUNT_TIMEOUT = 10.0
local DESPAWN_TIMEOUT = 10.0
local SETTLE_DELAY = 0.3
local VERIFY_DELAY = 1.0
local MOUNT_ATTEMPTS = 3

local s_Spawned = {}
local s_PendingSpawns = {}
local s_PendingMounts = {}
local s_PendingDespawns = {}
local s_UpdateUntil = 0

local function SameID(a, b)
    return a ~= nil and b ~= nil and a.hash == b.hash
end

local function EntryID(entry)
    return type(entry) == "table" and entry.ID or entry
end

local function IsNativeAvailable()
    return EasyEntitySpawner ~= nil and EasyEntitySpawner.Spawn ~= nil
end

VehicleSpawning.IsNativeAvailable = IsNativeAvailable

local function FindEntity(entityID)
    if not entityID then return nil end
    local ok, entity = pcall(Game.FindEntityByID, entityID)
    if ok and entity then return entity end
    if not IsNativeAvailable() then return nil end
    ok, entity = pcall(EasyEntitySpawner.GetEntity, entityID)
    return ok and entity or nil
end

local function IsPlayerInside(entityID)
    local mounted = Vehicle.GetMountedVehicleSafe()
    return mounted ~= nil and SameID(mounted:GetEntityID(), entityID)
end

local function TryDespawn(entry)
    local entityID = EntryID(entry)
    local entity = FindEntity(entityID)
    if not entity then return false end

    if IsPlayerInside(entityID) then
        Vehicle.UnmountPlayer(true)
        return false
    end

    if type(entry) == "table" and entry.Native then
        pcall(EasyEntitySpawner.Despawn, entityID)
        s_UpdateUntil = os.clock() + NATIVE_UPDATE_GRACE
    else
        pcall(exEntitySpawner.Despawn, entity)
    end
    return true
end

local function RemoveFromList(list, entityID)
    for index = #list, 1, -1 do
        if SameID(EntryID(list[index]), entityID) then table.remove(list, index) end
    end
end

function VehicleSpawning.Forget(entityID)
    RemoveFromList(s_Spawned, entityID)
    RemoveFromList(s_PendingMounts, entityID)
end

function VehicleSpawning.Despawn(entry)
    local entityID = EntryID(entry)
    if not entityID then return end

    VehicleSpawning.Forget(entityID)
    if not TryDespawn(entry) then
        table.insert(s_PendingDespawns, { Entry = entry, Started = os.clock() })
    end
end

local function Track(entry, mount, previous)
    table.insert(s_Spawned, entry)
    if mount then
        table.insert(s_PendingMounts, { ID = entry.ID, Seat = DEFAULT_SEAT, Started = os.clock(), Next = 0, Attempts = 0, Previous = previous })
    elseif previous then
        VehicleSpawning.Despawn(previous)
    end
end

function VehicleSpawning.SpawnVehicle(recordID, distance, mount, deleteLast)
    local player = Game.GetPlayer()
    if not player then return false end
    if not IsNativeAvailable() then
        Logger.Log("VehicleSpawning: EasyTrainerUtility is not loaded, cannot spawn " .. tostring(recordID))
        return false
    end

    local previous = deleteLast and s_Spawned[#s_Spawned] or nil
    if previous then VehicleSpawning.Forget(previous.ID) end

    local transform = Vehicle.GetSpawnTransform(player, distance)
    local ok, entityID = pcall(EasyEntitySpawner.Spawn, TweakDBID.new(recordID), transform, CName.new(NATIVE_TAG))
    if not ok or not entityID or entityID.hash == 0 then
        Logger.Log("VehicleSpawning: native spawn failed for " .. tostring(recordID) .. " (" .. tostring(entityID) .. ")")
        return false
    end

    table.insert(s_PendingSpawns, { ID = entityID, Record = recordID, Mount = mount, Previous = previous, Started = os.clock() })
    s_UpdateUntil = os.clock() + NATIVE_TIMEOUT
    return true
end

function VehicleSpawning.SpawnUntracked(recordID, distance)
    local player = Game.GetPlayer()
    if not player then return nil end

    local transform = Vehicle.GetSpawnTransform(player, distance)
    local ok, entityID = pcall(exEntitySpawner.SpawnRecord, TweakDBID.new(recordID), transform, "")
    if ok and entityID then return entityID end

    Logger.Log("VehicleSpawning: preview spawn failed for " .. tostring(recordID) .. " (" .. tostring(entityID) .. ")")
    return nil
end

function VehicleSpawning.IsSpawned(entityID)
    return FindEntity(entityID) ~= nil
end

function VehicleSpawning.GetEntity(entityID)
    return FindEntity(entityID)
end

local function StepSpawn(index, pending, now)
    local ok, state = pcall(EasyEntitySpawner.GetState, pending.ID)
    state = ok and state or -1

    if state < 0 or now - pending.Started > NATIVE_TIMEOUT then
        table.remove(s_PendingSpawns, index)
        Logger.Log(string.format("VehicleSpawning: spawn of %s stopped at state %d", pending.Record, state))
        if pending.Previous then VehicleSpawning.Despawn(pending.Previous) end
        return
    end

    if state ~= NATIVE_ATTACHED then return end

    table.remove(s_PendingSpawns, index)
    pcall(EasyEntitySpawnerVehicle.PrepareByID, pending.ID)
    Track({ ID = pending.ID, Record = pending.Record, Native = true }, pending.Mount, pending.Previous)
    Logger.Log("VehicleSpawning: spawned " .. pending.Record)
end

local function FinishMount(index, pending, mounted)
    table.remove(s_PendingMounts, index)
    if pending.Previous then VehicleSpawning.Despawn(pending.Previous) end
    Logger.Log("VehicleSpawning: " .. (mounted and "mounted player into spawned vehicle" or "gave up mounting spawned vehicle"))
end

local function StepMount(index, pending, now)
    if IsPlayerInside(pending.ID) then
        FinishMount(index, pending, true)
        return
    end

    if now - pending.Started > MOUNT_TIMEOUT or pending.Attempts >= MOUNT_ATTEMPTS then
        FinishMount(index, pending, false)
        return
    end

    if now < pending.Next then return end

    local entity = FindEntity(pending.ID)
    if not entity or not Vehicle.IsValidVehicle(entity) then return end

    if not pending.Found then
        pending.Found = true
        pending.Next = now + SETTLE_DELAY
        return
    end

    if Vehicle.GetMountedVehicleSafe() then Vehicle.UnmountPlayer(true) end

    pending.Attempts = pending.Attempts + 1
    Vehicle.MountPlayer(entity, pending.Seat)
    pending.Next = now + VERIFY_DELAY
end

local function StepDespawn(index, pending, now)
    if TryDespawn(pending.Entry) or now - pending.Started > DESPAWN_TIMEOUT then
        table.remove(s_PendingDespawns, index)
    end
end

local function ForEachPending(list, step, now)
    for index = #list, 1, -1 do
        local pending = list[index]
        if pending then step(index, pending, now) end
    end
end

function VehicleSpawning.HandlePending()
    local now = os.clock()
    if IsNativeAvailable() and (#s_PendingSpawns > 0 or now < s_UpdateUntil) then pcall(EasyEntitySpawner.Update) end
    if #s_PendingSpawns == 0 and #s_PendingMounts == 0 and #s_PendingDespawns == 0 then return end

    ForEachPending(s_PendingSpawns, StepSpawn, now)
    ForEachPending(s_PendingMounts, StepMount, now)
    ForEachPending(s_PendingDespawns, StepDespawn, now)
end

function VehicleSpawning.DespawnLast()
    local last = table.remove(s_Spawned)
    if not last then
        Logger.Log("VehicleSpawning: no vehicle to despawn")
        return false
    end

    VehicleSpawning.Despawn(last)
    return true
end

function VehicleSpawning.DespawnAll()
    local count = #s_Spawned
    while #s_Spawned > 0 do VehicleSpawning.Despawn(s_Spawned[#s_Spawned]) end
    return count
end

Lifecycle.Register("VehicleSpawning", {
    OnSessionEnd = function()
        s_Spawned = {}
        s_PendingSpawns = {}
        s_PendingMounts = {}
        s_PendingDespawns = {}
    end
})

return VehicleSpawning
