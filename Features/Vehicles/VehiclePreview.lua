local Logger = require("Core/Logger")
local Lifecycle = require("Core/Lifecycle")
local Teleport = require("Utils/Teleport")
local VehicleSpawning = require("Features/Vehicles/VehicleSpawning")
local State = require("Controls/State")

local VehiclePreview = {}

local DISTANCE = 13.0
local SPIN_SPEED = 30.0
local SPAWN_TIMEOUT = 8.0
local SPAWN_DELAY = 0.35
local HEIGHT_OFFSET = 0.7

local s_EntityID = nil
local s_RecordID = nil
local s_RequestedID = nil
local s_RequestedAt = 0
local s_Rotation = 0.0
local s_SpawnWait = 0.0
local s_Active = false

local function IsShowing()
    return s_Active and State.IsMenuOpen()
end

local function Despawn()
    if s_EntityID then VehicleSpawning.Despawn(s_EntityID) end
    s_EntityID = nil
    s_RecordID = nil
    s_Rotation = 0
    s_SpawnWait = 0
end

function VehiclePreview.Clear()
    Despawn()
    s_RequestedID = nil
end

function VehiclePreview.SetActive(active)
    s_Active = active
    if not active then VehiclePreview.Clear() end
end

function VehiclePreview.Spawn(recordID)
    if not IsShowing() or s_RequestedID == recordID then return end
    s_RequestedID = recordID
    s_RequestedAt = os.clock()
end

local function SpawnRequested()
    if not s_RequestedID or s_RequestedID == s_RecordID then return end
    if os.clock() - s_RequestedAt < SPAWN_DELAY then return end

    Despawn()
    s_RecordID = s_RequestedID
    s_EntityID = VehicleSpawning.SpawnUntracked(s_RecordID, DISTANCE)
    if not s_EntityID then Logger.Log("VehiclePreview: failed to spawn " .. tostring(s_RecordID)) end
end

local function WaitForSpawn(deltaTime)
    if VehicleSpawning.IsSpawned(s_EntityID) then
        s_SpawnWait = 0
        return true
    end

    s_SpawnWait = s_SpawnWait + deltaTime
    if s_SpawnWait >= SPAWN_TIMEOUT then
        Logger.Log("VehiclePreview: timed out spawning " .. tostring(s_RecordID))
        Despawn()
    end
    return false
end

function VehiclePreview.Update(deltaTime)
    if not IsShowing() then
        if s_EntityID or s_RequestedID then VehiclePreview.Clear() end
        return
    end

    SpawnRequested()
    if not s_EntityID or not Game.GetPlayer() then return end
    if not WaitForSpawn(deltaTime) then return end

    local entity = VehicleSpawning.GetEntity(s_EntityID)
    local position = entity and Teleport.GetForwardOffset(DISTANCE) or nil
    if not position then return end

    position.z = position.z + HEIGHT_OFFSET
    s_Rotation = (s_Rotation + SPIN_SPEED * deltaTime) % 360
    Teleport.TeleportEntity(entity, position, EulerAngles.new(0, 0, s_Rotation))
end

Lifecycle.Register("VehiclePreview", {
    OnSessionEnd = function()
        s_EntityID = nil
        s_RecordID = nil
        s_RequestedID = nil
    end,
    OnShutdown = VehiclePreview.Clear
})

return VehiclePreview
