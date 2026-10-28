local Physics = require("Utils/Physics")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Picker = require("Features/WorldEditor/Picker")
local Grabbables = require("Features/WorldEditor/Grabbables")

local Inspector = {}

Inspector.TraceDistance = { value = 200, min = 10, max = 1000, step = 10, unit = "m" }

Inspector.Camera = nil
Inspector.Hit = nil
Inspector.Target = nil
Inspector.Player = nil
Inspector.NativePicking = false

local REFRESH_INTERVAL = 0.1
local RESOLVE_TOLERANCE = 0.5
local COLLISION_GROUPS = {
    "Static", "Dynamic", "Vehicle", "Terrain", "Water", "Destructible", "Debris", "Interaction", "Shooting", "NPCTraceObstacle"
}
local GROUP_KINDS = { Vehicle = "Vehicle", Dynamic = "Prop" }

local s_NextRefresh = 0
local s_GroupNames = {}
local s_NativeChecked = false

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Copy(vector)
    if not vector then return nil end
    return { x = vector.x, y = vector.y, z = vector.z }
end

local function Distance(a, b)
    if not a or not b then return nil end
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function NameString(name)
    if name == nil then return nil end
    local text = Safe(function() return Game.NameToString(name) end) or tostring(name)
    if text == "" or text == "None" then return nil end
    return text
end

local function AngleBetween(a, b)
    local dot = a.x * b.x + a.y * b.y + a.z * b.z
    return math.deg(math.acos(math.max(-1, math.min(1, dot))))
end

local function ReadCamera(player)
    local activeForward = Copy(Safe(function() return Game.GetCameraSystem():GetActiveCameraForward() end))

    if FreeCam.IsReady() then
        local yaw, pitch = FreeCam.GetRotation()
        local forward = FreeCam.GetForward()
        return {
            Position = FreeCam.GetPosition(),
            Forward = forward,
            Yaw = yaw,
            Pitch = pitch,
            ActiveError = activeForward and AngleBetween(forward, activeForward) or nil
        }
    end

    if not activeForward then return nil end
    local origin = player:GetWorldPosition()
    local yaw, pitch = FreeCam.AnglesFromForward(activeForward)
    return { Position = { x = origin.x, y = origin.y, z = origin.z + 1.7 }, Forward = activeForward, Yaw = yaw, Pitch = pitch }
end

local function GroupName(group)
    s_GroupNames[group] = s_GroupNames[group] or CName.new(group)
    return s_GroupNames[group]
end

local function NativeSupported()
    if not s_NativeChecked then
        s_NativeChecked = true
        Inspector.NativePicking = EasyWorldPicker ~= nil and Safe(function() return EasyWorldPicker.IsSupported() end) == true
    end
    return Inspector.NativePicking
end

function Inspector.RaycastAll(from, to, groups)
    local system = Game.GetSpatialQueriesSystem()
    local hits = {}
    for _, group in ipairs(groups or COLLISION_GROUPS) do
        local ok, success, result = pcall(function()
            return system:SyncRaycastByCollisionGroup(from, to, GroupName(group), false, false)
        end)
        if ok and success and result then
            local position = Copy(result.position)
            local hitDistance = Distance(from, position)
            if hitDistance then
                table.insert(hits, {
                    Position = position,
                    Normal = Copy(result.normal),
                    Material = NameString(result.material),
                    Group = group,
                    Distance = hitDistance,
                    Trace = result
                })
            end
        end
    end
    table.sort(hits, function(a, b) return a.Distance < b.Distance end)
    return hits
end

function Inspector.Raycast(from, to, groups)
    return Inspector.RaycastAll(from, to, groups)[1]
end

local function Trace(camera)
    local origin = camera.Position
    local distance = Inspector.TraceDistance.value
    local from = Vector4.new(origin.x, origin.y, origin.z, 1.0)
    local to = Vector4.new(origin.x + camera.Forward.x * distance, origin.y + camera.Forward.y * distance,
        origin.z + camera.Forward.z * distance, 1.0)
    return Inspector.RaycastAll(from, to)
end

local function RecordName(object)
    local id = Safe(function() return object:GetRecordID() end)
    if not id then return nil end
    local text = Safe(function() return TDBID.ToStringDEBUG(id) end)
    if not text or text == "" then return nil end
    return text
end

local function EntityHash(object)
    local id = Safe(function() return object:GetEntityID() end)
    if not id then return nil end
    return Safe(function() return tostring(id.hash) end)
end

local function DescribeEntity(object, kind, camera)
    local position = Copy(Safe(function() return object:GetWorldPosition() end))
    local angles = Safe(function() return object:GetWorldOrientation():ToEulerAngles() end)
    local displayName = Safe(function() return object:GetDisplayName() end)
    return {
        Entity = object,
        Kind = kind,
        ClassName = NameString(Safe(function() return object:GetClassName() end)) or "Unknown",
        DisplayName = displayName ~= "" and displayName or nil,
        Record = RecordName(object),
        Appearance = NameString(Safe(function() return object:GetCurrentAppearanceName() end)),
        EntityHash = EntityHash(object),
        Collision = Physics.DescribeCollision(object),
        Position = position,
        Yaw = angles and angles.yaw or nil,
        Distance = Distance(camera.Position, position)
    }
end

local function IsPlayer(entity)
    return Safe(function() return entity:IsPlayer() end) == true
end

local function ResolveNative(camera, hits)
    local nearest = hits[1]
    if not nearest then return nil end
    nearest.ObjectType = NameString(Safe(function() return EasyWorldPicker.GetTraceObjectType(nearest.Trace) end))

    for _, hit in ipairs(hits) do
        if hit.Distance > nearest.Distance + RESOLVE_TOLERANCE then break end
        local entity = Safe(function() return EasyWorldPicker.GetTraceEntity(hit.Trace) end)
        if entity and not IsPlayer(entity) then
            local target = DescribeEntity(entity, Picker.Classify(entity), camera)
            target.Group = hit.Group
            return target
        end
    end
    return nil
end

local function ReadTarget(camera, hits)
    if NativeSupported() then return ResolveNative(camera, hits) end

    local hit = hits[1]
    local entity, kind = Picker.Pick(camera.Position, camera.Forward, hit and hit.Distance)
    if entity then return DescribeEntity(entity, kind, camera) end

    local groupKind = hit and GROUP_KINDS[hit.Group]
    if groupKind then return { Kind = groupKind, ClassName = "Unresolved", Position = hit.Position, Distance = hit.Distance } end
    return nil
end

local function SameEntity(a, b)
    local hashA = Safe(function() return tostring(a:GetEntityID().hash) end)
    local hashB = Safe(function() return tostring(b:GetEntityID().hash) end)
    return hashA ~= nil and hashA == hashB
end

local function PickByBounds(camera, hits, target)
    local nearest = hits[1]
    local limit = nearest and (nearest.Distance + RESOLVE_TOLERANCE) or Inspector.TraceDistance.value
    local entity, distance = Grabbables.Pick(camera.Position, camera.Forward, limit)
    if not entity then return target end
    if target and target.Entity and SameEntity(target.Entity, entity) then return target end
    if target and target.Distance and target.Distance < distance then return target end

    local picked = DescribeEntity(entity, Picker.Classify(entity), camera)
    picked.Distance = distance
    return picked
end

local function ReadPlayer(player, camera)
    local position = Copy(player:GetWorldPosition())
    return {
        Position = position,
        Yaw = Safe(function() return player:GetWorldYaw() end) or 0,
        CameraDistance = Distance(camera.Position, position)
    }
end

function Inspector.Refresh(force)
    local now = os.clock()
    if not force and now < s_NextRefresh then return end
    s_NextRefresh = now + REFRESH_INTERVAL

    local player = Game.GetPlayer()
    local camera = player and ReadCamera(player) or nil
    if not camera then
        Inspector.Clear()
        return
    end

    Inspector.Camera = camera
    Inspector.Player = ReadPlayer(player, camera)
    local hits = Trace(camera)
    Inspector.Hit = hits[1]
    Grabbables.Refresh(camera.Position)
    Inspector.Target = PickByBounds(camera, hits, ReadTarget(camera, hits))
end

function Inspector.Clear()
    Inspector.Camera = nil
    Inspector.Hit = nil
    Inspector.Target = nil
    Inspector.Player = nil
    Picker.Clear()
    Grabbables.Clear()
end

return Inspector
