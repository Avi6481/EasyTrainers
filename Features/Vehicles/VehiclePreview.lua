local Logger = require("Core/Logger")
local Teleport = require("Utils").Teleport
local VehicleSpawning = require("Features/Vehicles/VehicleSpawning")
local State = require("Controls/State")

local VehiclePreview = {}

local previewID, previewDBID = nil, nil
local rotation, distance, spinSpeed = 0.0, 13.0, 30.0
local spawnWait, spawnTimeout = 0.0, 8.0
local active = false

function VehiclePreview.SetActive(flag)
    active = flag
    if not flag then
        VehiclePreview.Clear()
    end
end

function VehiclePreview.Spawn(tweakDBIDStr)
    if not active or not State.IsMenuOpen() then
        VehiclePreview.Clear()
        return
    end

    if previewDBID == tweakDBIDStr then
        return
    end

    VehiclePreview.Clear()
    previewDBID = tweakDBIDStr

    local entityID = VehicleSpawning.SpawnVehicle(tweakDBIDStr, distance, false, false)
    if not entityID then
        Logger.Log("VehiclePreview: failed to spawn " .. tostring(tweakDBIDStr))
        return
    end

    previewID = entityID
    rotation = 0
    spawnWait = 0
    -- Logger.Log("VehiclePreview: spawned preview " .. tostring(entityID))
end

function VehiclePreview.Update(deltaTime)
    if not active or not State.IsMenuOpen() then
        VehiclePreview.Clear()
        return
    end

    if not previewID then return end

    local des = Game.GetDynamicEntitySystem()
    local player = Game.GetPlayer()
    if not (des and player) then return end
    if not des:IsSpawned(previewID) then
        spawnWait = spawnWait + deltaTime
        if spawnWait >= spawnTimeout then
            des:DeleteEntity(previewID)
            VehicleSpawning.Forget(previewID)
            previewID, rotation, spawnWait = nil, 0, 0
            Logger.Log("VehiclePreview: timed out spawning " .. tostring(previewDBID))
        end
        return
    end
    spawnWait = 0

    local ent = des:GetEntity(previewID)
    if not ent then return end

    local pos = Teleport.GetForwardOffset(distance)
    if not pos then return end

    pos.z = pos.z + 0.7
    rotation = (rotation + spinSpeed * deltaTime) % 360
    local facing = EulerAngles.new(0, 0, rotation)

    Teleport.TeleportEntity(ent, pos, facing)
end

function VehiclePreview.Clear()
    if previewID then
        local des = Game.GetDynamicEntitySystem()
        if des then des:DeleteEntity(previewID) end
        VehicleSpawning.Forget(previewID)
        -- Logger.Log("VehiclePreview: cleared preview " .. tostring(previewID))
    end
    previewID, previewDBID, rotation, spawnWait = nil, nil, 0, 0
end

return VehiclePreview
