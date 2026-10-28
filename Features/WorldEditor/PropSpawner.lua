local Logger = require("Core/Logger")
local Physics = require("Utils/Physics")
local Notification = require("UI/Panels/Notification/Notification")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Selection = require("Features/WorldEditor/Selection")
local Grabbables = require("Features/WorldEditor/Grabbables")

local PropSpawner = {}

PropSpawner.PreviewEnabled = { value = true }
PropSpawner.PreviewDistance = { value = 4.0, min = 1.5, max = 20.0, step = 0.5, unit = "m" }
PropSpawner.PreviewSpin = { value = true }

local PREVIEW_DELAY = 0.3
local BROWSE_TIMEOUT = 0.25
local SPAWN_TIMEOUT = 8.0
local BOUNDS_WAIT = 3.0
local SPIN_SPEED = 35
local PLAYER_HEIGHT = 1.2
local POSITION_TOLERANCE = 0.01
local ROTATION_TOLERANCE = 0.9999
local MESH_TEMPLATE = "base\\environment\\ld_kit\\marker_blue_small.ent"
local MESH_APPEARANCE = "default"

local s_Preview = nil
local s_Requested = nil
local s_LastBrowse = 0
local s_Spin = 0
local s_Placed = {}
local s_MeshSupported = nil
local s_Info = {}
local s_IsBusy = nil
local s_OnReplaced = nil

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Hash(value)
    local direct = Safe(function() return value.hash end)
    if direct then return tostring(direct) end
    return Safe(function() return tostring(value:GetEntityID().hash) end)
end

local function Anchor()
    if FreeCam.IsReady() then
        local camera, forward = FreeCam.GetPosition(), FreeCam.GetForward()
        local distance = PropSpawner.PreviewDistance.value
        return { x = camera.x + forward.x * distance, y = camera.y + forward.y * distance, z = camera.z + forward.z * distance },
            FreeCam.GetRotation() + 180
    end

    local player = Game.GetPlayer()
    if not player then return nil end
    local position, forward = player:GetWorldPosition(), player:GetWorldForward()
    local distance = PropSpawner.PreviewDistance.value
    return { x = position.x + forward.x * distance, y = position.y + forward.y * distance, z = position.z + PLAYER_HEIGHT },
        player:GetWorldYaw() + 180
end

function PropSpawner.IsMesh(entry)
    return entry.Path:sub(-5):lower() == ".mesh"
end

function PropSpawner.CanSpawnMeshes()
    if s_MeshSupported == nil then
        s_MeshSupported = EasyWorldEditor ~= nil and Safe(function() return EasyWorldEditor.IsMeshSpawnSupported() end) == true
    end
    return s_MeshSupported
end

function PropSpawner.CanSpawn(entry)
    return not PropSpawner.IsMesh(entry) or PropSpawner.CanSpawnMeshes()
end

function PropSpawner.SetBusyCheck(check)
    s_IsBusy = check
end

function PropSpawner.SetReplaceListener(listener)
    s_OnReplaced = listener
end

local function IsBusy(entity)
    return s_IsBusy ~= nil and s_IsBusy(entity) == true
end

local function Info(entry)
    local info = s_Info[entry.Path]
    if not info then
        info = {}
        s_Info[entry.Path] = info
    end
    return info
end

local function LearnInfo(entry, entity, withoutEditorBox)
    local info = Info(entry)
    if info.GameObject == nil then info.GameObject = Physics.IsGameObject(entity) end
    if withoutEditorBox and info.OwnCollision == nil and not PropSpawner.IsMesh(entry) then
        info.OwnCollision = Physics.HasOwnCollision(entity)
    end
    if not info.Bounds then
        local bounds = Grabbables.GetBounds(entity)
        if bounds and bounds.Native then info.Bounds = bounds end
    end
    return info
end

local function WantsBox(entry, info)
    return PropSpawner.IsMesh(entry) or info.OwnCollision == false
end

local function BoxVectors(entry)
    local bounds = Info(entry).Bounds
    if not bounds then return Vector4.new(0, 0, 0, 0), Vector4.new(0, 0, 0, 0), false end
    return Vector4.new(bounds.Min.x, bounds.Min.y, bounds.Min.z, 0), Vector4.new(bounds.Max.x, bounds.Max.y, bounds.Max.z, 0), true
end

local function QueueSpawn(template, mesh, entry, withBox)
    local boxMin, boxMax, hasBox = Vector4.new(0, 0, 0, 0), Vector4.new(0, 0, 0, 0), false
    if withBox then boxMin, boxMax, hasBox = BoxVectors(entry) end
    if mesh == "" and not hasBox then return false, false end

    local appearance = CName.new(MESH_APPEARANCE)
    local queued = Safe(function() return EasyWorldEditor.QueueMesh(template, mesh, appearance, boxMin, boxMax) end)
    if queued == nil and mesh ~= "" then
        queued = Safe(function() return EasyWorldEditor.QueueMesh(template, mesh, appearance) end)
        hasBox = false
    end
    return queued == true, queued == true and hasBox
end

local function ToOrientation(rotation)
    if type(rotation) == "number" then return EulerAngles.new(0, 0, rotation):ToQuat() end
    return rotation
end

local function SpawnAt(entry, position, rotation, withBox)
    local player = Game.GetPlayer()
    if not player or not PropSpawner.CanSpawn(entry) then return nil end

    local transform = player:GetWorldTransform()
    transform:SetPosition(transform, Vector4.new(position.x, position.y, position.z, 1.0))
    transform:SetOrientation(transform, ToOrientation(rotation))

    local template, queued, hasBox = entry.Path, false, false
    if PropSpawner.IsMesh(entry) then
        queued, hasBox = QueueSpawn(MESH_TEMPLATE, entry.Path, entry, withBox)
        if not queued then
            Logger.Log("PropSpawner: failed to queue mesh " .. entry.Path)
            return nil
        end
        template = MESH_TEMPLATE
    elseif withBox and EasyWorldEditor then
        queued, hasBox = QueueSpawn(entry.Path, "", entry, true)
    end

    local ok, entityID = pcall(exEntitySpawner.Spawn, template, transform)
    if not ok or not entityID then
        if queued then Safe(function() EasyWorldEditor.CancelMesh(template) end) end
        Logger.Log("PropSpawner: failed to spawn " .. entry.Path .. " (" .. tostring(entityID) .. ")")
        return nil
    end
    return entityID, hasBox
end

local function DespawnEntity(entity)
    if entity then Safe(function() exEntitySpawner.Despawn(entity) end) end
end

local function Orphan(id)
    if id then table.insert(s_Placed, { ID = id, Started = os.clock(), Orphaned = true }) end
end

local function ClearPreview()
    if not s_Preview then return end
    if s_Preview.Entity then
        DespawnEntity(s_Preview.Entity)
    else
        Orphan(s_Preview.ID)
    end
    s_Preview = nil
end

function PropSpawner.Browse()
    s_LastBrowse = os.clock()
end

function PropSpawner.Preview(entry)
    if not PropSpawner.PreviewEnabled.value then return end
    if s_Requested and s_Requested.Entry == entry then return end
    s_Requested = { Entry = entry, At = os.clock() }
end

function PropSpawner.GetPreviewEntry()
    return s_Preview and s_Preview.Entry or nil
end

function PropSpawner.GetPreviewEntity(entry)
    if not s_Preview or s_Preview.Entry ~= entry then return nil end
    return s_Preview.Entity, s_Preview.Held
end

local function SpawnPreview()
    if not s_Requested or os.clock() - s_Requested.At < PREVIEW_DELAY then return end
    if s_Preview and s_Preview.Entry == s_Requested.Entry then return end

    ClearPreview()
    local position, yaw = Anchor()
    if not position then return end

    local entityID = SpawnAt(s_Requested.Entry, position, yaw, false)
    if not entityID then return end
    s_Spin = 0
    s_Preview = { Entry = s_Requested.Entry, ID = entityID, Started = os.clock(), Yaw = yaw }
end

local function UpdatePreview(deltaTime)
    if not s_Preview then return end

    if not s_Preview.Entity then
        s_Preview.Entity = Safe(function() return Game.FindEntityByID(s_Preview.ID) end)
        if s_Preview.Entity then
            s_Preview.Held = Physics.Hold(s_Preview.Entity, "Prop")
        elseif os.clock() - s_Preview.Started > SPAWN_TIMEOUT then
            Logger.Log("PropSpawner: preview never appeared for " .. s_Preview.Entry.Path)
            s_Preview = nil
        end
        return
    end

    LearnInfo(s_Preview.Entry, s_Preview.Entity, true)
    local position, yaw = Anchor()
    if not position then return end
    if PropSpawner.PreviewSpin.value then s_Spin = (s_Spin + SPIN_SPEED * deltaTime) % 360 end
    s_Preview.Yaw = yaw + s_Spin
    Physics.Move(s_Preview.Held, Vector4.new(position.x, position.y, position.z, 1.0), s_Preview.Yaw)
end

local function SettleOrphans()
    local now = os.clock()
    for index = #s_Placed, 1, -1 do
        local record = s_Placed[index]
        if record.Orphaned then
            local entity = Safe(function() return Game.FindEntityByID(record.ID) end)
            if entity then DespawnEntity(entity) end
            if entity or now - record.Started > SPAWN_TIMEOUT then table.remove(s_Placed, index) end
        end
    end
end

function PropSpawner.Place(entry)
    if s_Preview and s_Preview.Entry == entry and s_Preview.Entity then
        local record = s_Preview
        s_Preview = nil
        s_Requested = nil
        local static = #record.Held.Bodies == 0
        Physics.Release(record.Held, {})
        if static then Physics.SnapToGround(record.Entity, Grabbables.GetBottom(record.Entity)) end
        record.Held = nil
        record.FoundAt = os.clock()
        table.insert(s_Placed, record)
        Selection.Select({ Entity = record.Entity, Kind = "Prop", DisplayName = entry.Name, ClassName = "Spawned Prop" })
        return true
    end

    if not PropSpawner.CanSpawn(entry) then
        Notification.Warning("Mesh props need the latest EasyTrainerUtility.")
        return false
    end

    local position, yaw = Anchor()
    if not position then return false end
    local entityID, hasBox = SpawnAt(entry, position, yaw, WantsBox(entry, Info(entry)))
    if not entityID then
        Notification.Error("Couldn't spawn " .. entry.Name .. ".")
        return false
    end
    table.insert(s_Placed, { Entry = entry, ID = entityID, Started = os.clock(), SnapOnSpawn = true, Box = hasBox })
    return true
end

local function ReadPose(entity)
    local position = Safe(function() return entity:GetWorldPosition() end)
    local orientation = Safe(function() return entity:GetWorldOrientation() end)
    if not position or not orientation then return nil end
    return { Position = position, Orientation = orientation }
end

local function SamePose(a, b)
    if not a or not b then return false end
    local p, q = a.Position, b.Position
    if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 + (p.z - q.z) ^ 2 > POSITION_TOLERANCE ^ 2 then return false end
    local r, s = a.Orientation, b.Orientation
    return math.abs(r.i * s.i + r.j * s.j + r.k * s.k + r.r * s.r) >= ROTATION_TOLERANCE
end

local function DropReplacement(record)
    if not record.Replacement then return end
    local entity = Safe(function() return Game.FindEntityByID(record.Replacement.ID) end)
    if entity then DespawnEntity(entity) else Orphan(record.Replacement.ID) end
    record.Replacement = nil
end

local function StartRespawn(record, withBox)
    local pose = ReadPose(record.Entity)
    if not pose then return end

    local entityID, hasBox = SpawnAt(record.Entry, pose.Position, pose.Orientation, withBox)
    if not entityID then
        record.RespawnFailed = true
        return
    end
    record.Replacement = { ID = entityID, Started = os.clock(), Box = hasBox, Pose = pose }
end

local function FinishRespawn(record)
    local replacement = record.Replacement
    local entity = Safe(function() return Game.FindEntityByID(replacement.ID) end)
    if not entity then
        if os.clock() - replacement.Started > SPAWN_TIMEOUT then
            record.Replacement = nil
            record.RespawnFailed = true
        end
        return
    end

    local old = record.Entity
    if IsBusy(old) or not SamePose(ReadPose(old), replacement.Pose) then
        DropReplacement(record)
        return
    end

    record.Entity, record.ID, record.Box, record.Pose, record.Replacement = entity, replacement.ID, replacement.Box, replacement.Pose, nil
    if s_OnReplaced then s_OnReplaced(old, entity) end
    DespawnEntity(old)
end

local function UpdateRecord(record)
    local info = LearnInfo(record.Entry, record.Entity, not record.Box)
    if info.GameObject or record.RespawnFailed then return end

    if record.Replacement then
        FinishRespawn(record)
        return
    end
    if IsBusy(record.Entity) then return end

    local wantsBox = WantsBox(record.Entry, info)
    if wantsBox and not info.Bounds and os.clock() - (record.FoundAt or 0) < BOUNDS_WAIT then return end

    local moved = not SamePose(ReadPose(record.Entity), record.Pose)
    local missingBox = wantsBox and info.Bounds ~= nil and not record.Box
    if moved or missingBox then StartRespawn(record, wantsBox) end
end

function PropSpawner.Snapshot()
    local list = {}
    for _, record in ipairs(s_Placed) do
        if record.Entry and not record.Orphaned then
            local pose = record.Entity and ReadPose(record.Entity)
            if pose then record.LastPose = pose end
            pose = pose or record.LastPose
            if pose then table.insert(list, { Entry = record.Entry, Entity = record.Entity, Pose = pose }) end
        end
    end
    return list
end

function PropSpawner.SpawnSaved(entry, position, orientation)
    if not PropSpawner.CanSpawn(entry) then return nil end
    local pose = { Position = position, Orientation = orientation }
    local entityID = SpawnAt(entry, position, orientation, WantsBox(entry, Info(entry)))
    if not entityID then return nil end
    local record = { Entry = entry, ID = entityID, Started = os.clock(), Pose = pose, LastPose = pose }
    table.insert(s_Placed, record)
    return record
end

function PropSpawner.GetPlaced()
    local placed = {}
    for _, record in ipairs(s_Placed) do
        if record.Entity and record.Entry and not record.Orphaned then
            table.insert(placed, { Entity = record.Entity, Name = record.Entry.Name })
        end
    end
    return placed
end

function PropSpawner.GetEntities()
    local entities = {}
    for _, record in ipairs(s_Placed) do
        if record.Entity and not record.Orphaned then table.insert(entities, record.Entity) end
    end
    return entities
end

function PropSpawner.Count()
    local count = 0
    for _, record in ipairs(s_Placed) do
        if not record.Orphaned then count = count + 1 end
    end
    return count
end

function PropSpawner.IsPlaced(entity)
    local hash = entity and Hash(entity)
    if not hash then return nil end
    for index, record in ipairs(s_Placed) do
        if not record.Orphaned and Hash(record.ID) == hash then return index end
    end
    return nil
end

function PropSpawner.GetEntry(entity)
    local index = PropSpawner.IsPlaced(entity)
    return index and s_Placed[index].Entry or nil
end

function PropSpawner.Delete(entity)
    local index = PropSpawner.IsPlaced(entity)
    if not index then return false end
    local record = table.remove(s_Placed, index)
    local selected = Selection.Get()
    if selected and Hash(selected.Entity) == Hash(entity) then Selection.Clear() end
    DropReplacement(record)
    DespawnEntity(record.Entity or Safe(function() return Game.FindEntityByID(record.ID) end))
    return true
end

function PropSpawner.DeleteLast()
    for index = #s_Placed, 1, -1 do
        local record = s_Placed[index]
        if not record.Orphaned then
            local entity = record.Entity or Safe(function() return Game.FindEntityByID(record.ID) end)
            if entity then return PropSpawner.Delete(entity) end
            table.remove(s_Placed, index)
        end
    end
    return false
end

function PropSpawner.DeleteAll()
    local removed = 0
    Selection.Clear()
    for index = #s_Placed, 1, -1 do
        local record = s_Placed[index]
        if not record.Orphaned then
            DropReplacement(record)
            local entity = record.Entity or Safe(function() return Game.FindEntityByID(record.ID) end)
            if entity then
                DespawnEntity(entity)
                table.remove(s_Placed, index)
                removed = removed + 1
            else
                record.Orphaned = true
            end
        end
    end
    return removed
end

function PropSpawner.Tick(deltaTime)
    if s_Preview or s_Requested then
        if os.clock() - s_LastBrowse > BROWSE_TIMEOUT or not PropSpawner.PreviewEnabled.value then
            ClearPreview()
            s_Requested = nil
        else
            SpawnPreview()
            UpdatePreview(deltaTime)
        end
    end

    for _, record in ipairs(s_Placed) do
        if not record.Orphaned then
            if not record.Entity then
                record.Entity = Safe(function() return Game.FindEntityByID(record.ID) end)
                if record.Entity then
                    record.FoundAt = os.clock()
                    if record.SnapOnSpawn then Physics.SnapToGround(record.Entity, Grabbables.GetBottom(record.Entity)) end
                end
            elseif record.Entry then
                UpdateRecord(record)
            end
        end
    end
    SettleOrphans()
end

function PropSpawner.Shutdown()
    ClearPreview()
    s_Requested = nil
    PropSpawner.DeleteAll()
end

function PropSpawner.Forget()
    s_Preview = nil
    s_Requested = nil
    s_Placed = {}
end

return PropSpawner
