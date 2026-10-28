local Cron = require("Core/cp2077-cet-kit/Cron")
local Force = require("Utils/Force")
local Rotation = require("Utils/Rotation")
local Entities = require("Utils/Entities")

local Physics = {}

local BODY_CLASSES = {
    entPhysicalMeshComponent = true,
    PhysicalMeshComponent = true,
    entColliderComponent = true,
    ColliderComponent = true
}
local COLLISION_CLASSES = {
    entColliderComponent = "Collider",
    ColliderComponent = "Collider",
    entPhysicalMeshComponent = "Physics Mesh",
    PhysicalMeshComponent = "Physics Mesh",
    entPhysicalSkinnedMeshComponent = "Physics Mesh"
}
local EDITOR_COLLIDER = "collision"
local GROUND_GROUPS = { "Static", "Terrain" }
local GROUND_REACH = 200
local GROUND_STARTS = { -0.02, 1.0 }
local GROUND_SKIPS = 4
local GROUND_SKIP_STEP = 0.05
local WAKE_IMPULSE = -0.01
local VEHICLE_WAKE_IMPULSE = -20
local VEHICLE_WAKE_INTERVAL = 0.08
local VEHICLE_WAKE_TICKS = 15
local REFRESH_DELAY = 0.1
local REFRESH_GAP = 0.05

local s_GroundNames = nil

local Safe = Entities.Safe

local function Is(object, method)
    return Safe(function() return object[method](object) end) == true
end

function Physics.Classify(entity)
    if Is(entity, "IsVehicle") then return "Vehicle" end
    if Is(entity, "IsPuppet") or Is(entity, "IsNPC") then return "Ped" end
    if Is(entity, "IsDevice") or Is(entity, "IsSensor") then return "Device" end
    if Is(entity, "IsItem") then return "Item" end

    local className = Safe(function() return Game.NameToString(entity:GetClassName()) end) or ""
    if className:find("Item", 1, true) then return "Item" end
    if className:find("vehicle", 1, true) then return "Vehicle" end
    return "Prop"
end

function Physics.GetBodies(entity)
    local bodies = {}
    if not EasyEntityTools then return bodies end

    local components = Safe(function() return EasyEntityTools.GetComponents(entity) end)
    for _, component in ipairs(type(components) == "table" and components or {}) do
        local className = Safe(function() return Game.NameToString(component:GetClassName()) end)
        if BODY_CLASSES[className] then
            local body = Safe(function() return component:CreatePhysicalBodyInterface(0) end)
            if body then table.insert(bodies, body) end
        end
    end
    return bodies
end

local function IsDynamic(component)
    local body = Safe(function() return component:CreatePhysicalBodyInterface(0) end)
    return body ~= nil and Safe(function() return body:IsSimulated() end) == true and Safe(function() return body:IsKinematic() end) ~= true
end

local function StaticCollision(entity)
    local list = {}
    local components = EasyEntityTools and Safe(function() return EasyEntityTools.GetComponents(entity) end)
    for _, component in ipairs(type(components) == "table" and components or {}) do
        local className = Safe(function() return Game.NameToString(component:GetClassName()) end)
        if BODY_CLASSES[className] and Safe(function() return component:IsEnabled() end) == true and not IsDynamic(component) then
            table.insert(list, component)
        end
    end
    return list
end

local IsAlive = Entities.IsValid

function Physics.RefreshCollision(entity)
    if not entity or Physics.IsGameObject(entity) then return end
    Cron.After(REFRESH_DELAY, function()
        if not IsAlive(entity) then return end
        local components = StaticCollision(entity)
        if #components == 0 then return end
        for _, component in ipairs(components) do Safe(function() component:Toggle(false) end) end
        Cron.After(REFRESH_GAP, function()
            if not IsAlive(entity) then return end
            for _, component in ipairs(components) do Safe(function() component:Toggle(true) end) end
        end)
    end)
end

local function CollisionKinds(entity)
    local kinds, editorBox = {}, false
    local components = EasyEntityTools and Safe(function() return EasyEntityTools.GetComponents(entity) end)
    for _, component in ipairs(type(components) == "table" and components or {}) do
        local className = Safe(function() return Game.NameToString(component:GetClassName()) end)
        local kind = COLLISION_CLASSES[className]
        if kind then
            local name = Safe(function() return Game.NameToString(component:GetName()) end)
            if name == EDITOR_COLLIDER and kind == "Collider" then
                editorBox = true
            else
                kinds[kind] = true
            end
        end
    end
    return kinds, editorBox, components ~= nil
end

function Physics.DisableCollision(entity)
    local restore = {}
    local components = EasyEntityTools and Safe(function() return EasyEntityTools.GetComponents(entity) end)
    for _, component in ipairs(type(components) == "table" and components or {}) do
        local kind = COLLISION_CLASSES[Safe(function() return Game.NameToString(component:GetClassName()) end)]
        if kind == "Collider" and Safe(function() return component:IsEnabled() end) == true then
            Safe(function() component:Toggle(false) end)
            table.insert(restore, { Component = component, Toggled = true })
        elseif kind == "Physics Mesh" and Safe(function() component:ToggleCollision(false); return true end) then
            table.insert(restore, { Component = component, Toggled = false })
        end
    end
    return restore
end

function Physics.RestoreCollision(restore)
    for _, entry in ipairs(restore or {}) do
        if entry.Toggled then
            Safe(function() entry.Component:Toggle(true) end)
        else
            Safe(function() entry.Component:ToggleCollision(true) end)
        end
    end
end

function Physics.HasOwnCollision(entity)
    local kinds, _, known = CollisionKinds(entity)
    if not known then return nil end
    return next(kinds) ~= nil
end

function Physics.DescribeCollision(entity)
    local kinds, editorBox, known = CollisionKinds(entity)
    if not known then return nil end
    local parts = {}
    if editorBox then table.insert(parts, "Editor Box") end
    for _, kind in ipairs({ "Collider", "Physics Mesh" }) do
        if kinds[kind] then table.insert(parts, kind) end
    end
    if #parts == 0 then return "None" end
    return table.concat(parts, ", ")
end

function Physics.IsInTraffic(entity)
    return Safe(function() return entity:IsInTrafficPhysicsState() end) == true
end

function Physics.LeaveTraffic(entity)
    if not Physics.IsInTraffic(entity) then return true end
    if not EasyVehicleTools then return false end
    return Safe(function() return EasyVehicleTools.LeaveTraffic(entity) end) == true
end

function Physics.Hold(entity, kind)
    local held = { Entity = entity, Kind = kind or Physics.Classify(entity), Bodies = {} }
    if held.Kind == "Vehicle" then Physics.LeaveTraffic(entity) end
    for _, body in ipairs(Physics.GetBodies(entity)) do
        local wasKinematic = Safe(function() return body:IsKinematic() end) == true
        if Safe(function() return body:IsSimulated() end) == true then
            Safe(function() body:SetIsKinematic(true) end)
            table.insert(held.Bodies, { Body = body, WasKinematic = wasKinematic })
        end
    end
    return held
end

function Physics.IsGameObject(entity)
    return Safe(function() return entity:IsA("gameObject") end) == true
end

local function SetWorldTransform(entity, position, orientation)
    return EasyEntityTools ~= nil and Safe(function() return EasyEntityTools.SetWorldTransform(entity, position, orientation) end) == true
end

local function ToQuaternion(rotation)
    if type(rotation) == "number" then return EulerAngles.new(0, 0, rotation):ToQuat() end
    if type(rotation) == "table" then return Rotation.ToQuaternion(rotation) end
    return rotation
end

function Physics.Place(entity, position, rotation)
    local orientation = ToQuaternion(rotation)
    if Physics.IsGameObject(entity) then
        return pcall(function() Game.GetTeleportationFacility():Teleport(entity, position, orientation:ToEulerAngles()) end)
    end

    if SetWorldTransform(entity, position, orientation) then return true end

    local root = EasyEntityTools and Safe(function() return EasyEntityTools.GetRootComponent(entity) end)
    if not root then return false end
    return pcall(function() root:SetLocalTransform(position, orientation) end)
end

function Physics.Move(held, position, rotation)
    return Physics.Place(held.Entity, position, rotation)
end

local function GroundNames()
    if not s_GroundNames then
        s_GroundNames = {}
        for _, group in ipairs(GROUND_GROUPS) do table.insert(s_GroundNames, CName.new(group)) end
    end
    return s_GroundNames
end

local SameEntity = Entities.Same

local function IsIgnored(result, ignore)
    if not ignore or not EasyWorldPicker then return false end
    local entity = Safe(function() return EasyWorldPicker.GetTraceEntity(result) end)
    return entity ~= nil and SameEntity(entity, ignore)
end

local function CastDown(system, x, y, z, group, ignore)
    for _ = 1, GROUND_SKIPS do
        local from = Vector4.new(x, y, z, 1.0)
        local to = Vector4.new(x, y, z - GROUND_REACH, 1.0)
        local ok, success, result = pcall(function() return system:SyncRaycastByCollisionGroup(from, to, group, false, false) end)
        if not ok or not success or not result then return nil end
        if not IsIgnored(result, ignore) then return result.position.z end
        z = result.position.z - GROUND_SKIP_STEP
    end
    return nil
end

function Physics.FindGround(position, ignore)
    local system = Game.GetSpatialQueriesSystem()
    local best = nil
    for _, group in ipairs(GroundNames()) do
        local z = CastDown(system, position.x, position.y, position.z, group, ignore)
        if z and (not best or z > best) then best = z end
    end
    return best
end

function Physics.GroundBelow(position, ignore)
    for _, lift in ipairs(GROUND_STARTS) do
        local ground = Physics.FindGround({ x = position.x, y = position.y, z = position.z + lift }, ignore)
        if ground then return ground end
    end
    return nil
end

function Physics.SnapToGround(entity, bottom)
    local position = Safe(function() return entity:GetWorldPosition() end)
    if not position then return false end

    bottom = bottom or 0
    local ground = Physics.GroundBelow({ x = position.x, y = position.y, z = position.z + bottom }, entity)
    if not ground then return false end
    local orientation = Safe(function() return entity:GetWorldOrientation() end) or (Safe(function() return entity:GetWorldYaw() end) or 0)
    local placed = Physics.Place(entity, Vector4.new(position.x, position.y, ground - bottom, 1.0), orientation)
    if placed then Physics.RefreshCollision(entity) end
    return placed
end

local function WakeBodies(held)
    for _, entry in ipairs(held.Bodies) do
        Safe(function() entry.Body:SetIsKinematic(entry.WasKinematic) end)
        if not entry.WasKinematic then
            Safe(function() entry.Body:AddLinearImpulse(Vector4.new(0, 0, WAKE_IMPULSE, 0), true) end)
        end
    end
    if #held.Bodies == 0 then Safe(function() Force.ApplyImpulse(held.Entity, Vector3.new(0, 0, WAKE_IMPULSE)) end) end
end

local function WakeVehicle(held)
    if Physics.IsInTraffic(held.Entity) then return end
    local vehicle = held.Entity
    local ticks = 0
    Cron.Every(VEHICLE_WAKE_INTERVAL, function(timer)
        ticks = ticks + 1
        Safe(function() vehicle:PhysicsWakeUp() end)
        Safe(function() Force.ApplyImpulse(vehicle, Vector3.new(0, 0, VEHICLE_WAKE_IMPULSE)) end)
        if ticks >= VEHICLE_WAKE_TICKS then Cron.Halt(timer) end
    end)
end

function Physics.Release(held, options)
    if not held then return end
    options = options or {}

    WakeBodies(held)
    if not options.KeepCollision then Physics.RefreshCollision(held.Entity) end
    if held.Kind == "Vehicle" then WakeVehicle(held) end
    if held.Kind ~= "Ped" then return end

    if options.Ragdoll then
        Safe(function() held.Entity:QueueEvent(CreateForceRagdollEvent(CName.new("EasyTrainer"))) end)
    elseif options.SnapToGround then
        Physics.SnapToGround(held.Entity)
    end
end

return Physics
