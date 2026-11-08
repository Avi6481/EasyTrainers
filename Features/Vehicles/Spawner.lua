local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")
local Vehicle = require("Utils/Vehicle")

local Spawner = {}

local TAG = "EasyTrainer"
local ATTACHED = 4
local SPAWN_TIMEOUT = 15
local MOUNT_TIMEOUT = 10
local MOUNT_ATTEMPTS = 3
local SETTLE_DELAY = 0.3
local RETRY_DELAY = 1
local DESPAWN_TIMEOUT = 10
local UPDATE_GRACE = 5

local s_Spawned = {}
local s_Spawning = {}
local s_Mounting = {}
local s_Despawning = {}
local s_UpdateUntil = 0

local function Available()
    return EasyEntitySpawner ~= nil and EasyEntitySpawner.Spawn ~= nil
end

Spawner.Available = Available

local function Same(first, second)
    return first ~= nil and second ~= nil and first.hash == second.hash
end

local function Find(id)
    local ok, entity = pcall(Game.FindEntityByID, id)
    if ok and entity then return entity end
    ok, entity = pcall(EasyEntitySpawner.GetEntity, id)
    if ok then return entity end
    return nil
end

local function Inside(player, id)
    local mounted = Vehicle.Mounted(player)
    return mounted ~= nil and Same(mounted:GetEntityID(), id)
end

local function Remove(list, id)
    for index = #list, 1, -1 do
        if Same(list[index].Id, id) then table.remove(list, index) end
    end
end

local function TryDespawn(player, id)
    if not Find(id) then return true end
    if Inside(player, id) then
        Vehicle.Unmount(player, true)
        return false
    end

    pcall(EasyEntitySpawner.Despawn, id)
    s_UpdateUntil = os.clock() + UPDATE_GRACE
    return true
end

function Spawner.Despawn(player, id)
    Remove(s_Spawned, id)
    Remove(s_Mounting, id)
    if not TryDespawn(player, id) then table.insert(s_Despawning, { Id = id, Started = os.clock() }) end
end

local function Start(record, label, transform, mount, previous, preview)
    if not Available() then
        Notify.Error(L("vehicles.spawner.missing"))
        return nil
    end

    local ok, id = pcall(EasyEntitySpawner.Spawn, record, transform, CName.new(TAG))
    if not ok or not id or id.hash == 0 then
        Logger.Log("Vehicles: couldn't spawn " .. label)
        Notify.Error(L("notify.vehicles.spawnfailed"))
        return nil
    end

    table.insert(s_Spawning, { Id = id, Label = label, Mount = mount, Previous = previous, Preview = preview, Started = os.clock() })
    s_UpdateUntil = os.clock() + SPAWN_TIMEOUT
    return id
end

function Spawner.Spawn(player, vehicle, distance, mount, replace)
    local previous = replace and s_Spawned[#s_Spawned] or nil
    if previous then Remove(s_Spawned, previous.Id) end
    return Start(TweakDBID.new(vehicle.Id), vehicle.Id, Vehicle.SpawnTransform(player, distance), mount, previous) ~= nil
end

function Spawner.SpawnAt(record, label, transform)
    return Start(record, label, transform, true, nil) ~= nil
end

function Spawner.SpawnPreview(player, vehicle, distance)
    return Start(TweakDBID.new(vehicle.Id), vehicle.Id, Vehicle.SpawnTransform(player, distance), false, nil, true)
end

function Spawner.Last()
    local last = s_Spawned[#s_Spawned]
    return last and Find(last.Id)
end

function Spawner.Owns(id)
    for _, entry in ipairs(s_Spawned) do
        if Same(entry.Id, id) then return true end
    end
    return false
end

local function Prepare(id)
    if not EasyVehicleTools then return end
    local entity = Find(id)
    if entity and EasyVehicleTools.IsInTraffic(entity) then EasyVehicleTools.LeaveTraffic(entity) end
end

local function StepSpawn(player, index, pending, now)
    local ok, state = pcall(EasyEntitySpawner.GetState, pending.Id)
    state = ok and state or -1

    if state < 0 or now - pending.Started > SPAWN_TIMEOUT then
        table.remove(s_Spawning, index)
        Logger.Log("Vehicles: spawn of " .. pending.Label .. " stopped at state " .. tostring(state))
        if not pending.Preview then Notify.Error(L("notify.vehicles.spawnfailed")) end
        return
    end
    if state ~= ATTACHED then return end

    table.remove(s_Spawning, index)
    pcall(Prepare, pending.Id)
    if pending.Preview then return end
    table.insert(s_Spawned, { Id = pending.Id })

    if pending.Mount then
        table.insert(s_Mounting, { Id = pending.Id, Previous = pending.Previous, Started = now, Next = now + SETTLE_DELAY, Attempts = 0 })
    elseif pending.Previous then
        Spawner.Despawn(player, pending.Previous.Id)
    end
end

local function FinishMount(player, index, pending)
    table.remove(s_Mounting, index)
    if pending.Previous then Spawner.Despawn(player, pending.Previous.Id) end
end

local function StepMount(player, index, pending, now)
    if Inside(player, pending.Id) or now - pending.Started > MOUNT_TIMEOUT or pending.Attempts >= MOUNT_ATTEMPTS then
        FinishMount(player, index, pending)
        return
    end
    if now < pending.Next then return end

    local entity = Find(pending.Id)
    if not Vehicle.IsVehicle(entity) then return end

    if Vehicle.Mounted(player) then Vehicle.Unmount(player, true) end
    pending.Attempts = pending.Attempts + 1
    pending.Next = now + RETRY_DELAY
    Vehicle.Mount(player, entity)
end

local function StepDespawn(player, index, pending, now)
    if TryDespawn(player, pending.Id) or now - pending.Started > DESPAWN_TIMEOUT then table.remove(s_Despawning, index) end
end

local function Each(list, step, player, now)
    for index = #list, 1, -1 do step(player, index, list[index], now) end
end

function Spawner.Update(player)
    if not Available() then return end

    local now = os.clock()
    if #s_Spawning > 0 or now < s_UpdateUntil then EasyEntitySpawner.Update() end
    if #s_Spawning == 0 and #s_Mounting == 0 and #s_Despawning == 0 then return end

    Each(s_Spawning, StepSpawn, player, now)
    Each(s_Mounting, StepMount, player, now)
    Each(s_Despawning, StepDespawn, player, now)
end

function Spawner.DespawnLast(player)
    local last = s_Spawned[#s_Spawned]
    if not last then return false end
    Spawner.Despawn(player, last.Id)
    return true
end

function Spawner.DespawnAll(player)
    local count = #s_Spawned
    while #s_Spawned > 0 do Spawner.Despawn(player, s_Spawned[#s_Spawned].Id) end
    return count
end

function Spawner.Count()
    return #s_Spawned
end

function Spawner.Reset()
    s_Spawned = {}
    s_Spawning = {}
    s_Mounting = {}
    s_Despawning = {}
end

return Spawner
