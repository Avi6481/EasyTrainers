local Logger = require("Core/Logger")
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")

local Attachments = {}

Attachments.LagCompensation = { value = true }

local MAX_DEPTH = 64

local s_List = {}
local s_IsBusy = nil

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Hash(entity)
    return entity and Safe(function() return tostring(entity:GetEntityID().hash) end)
end

local function IsValid(entity)
    local id = entity and Safe(function() return entity:GetEntityID() end)
    return id ~= nil and Safe(function() return Game.FindEntityByID(id) end) ~= nil
end

local function Pose(entity)
    local position = Safe(function() return entity:GetWorldPosition() end)
    local orientation = Safe(function() return entity:GetWorldOrientation() end)
    if not position or not orientation then return nil end
    return { x = position.x, y = position.y, z = position.z }, Rotation.FromQuaternion(orientation)
end

local function Relative(parentPosition, parentRotation, childPosition, childRotation)
    local inverse = Rotation.Conjugate(parentRotation)
    local offset = Rotation.Rotate(inverse, {
        x = childPosition.x - parentPosition.x,
        y = childPosition.y - parentPosition.y,
        z = childPosition.z - parentPosition.z
    })
    return offset, Rotation.Normalize(Rotation.Multiply(inverse, childRotation))
end

local function Compose(parentPosition, parentRotation, localPosition, localRotation)
    local offset = Rotation.Rotate(parentRotation, localPosition)
    local position = { x = parentPosition.x + offset.x, y = parentPosition.y + offset.y, z = parentPosition.z + offset.z }
    return position, Rotation.Normalize(Rotation.Multiply(parentRotation, localRotation))
end

local function FindIndex(hash)
    for index, entry in ipairs(s_List) do
        if entry.ChildHash == hash then return index end
    end
    return nil
end

local function WouldLoop(childHash, parentHash)
    local current = parentHash
    for _ = 1, MAX_DEPTH do
        if not current then return false end
        if current == childHash then return true end
        local index = FindIndex(current)
        current = index and s_List[index].ParentHash or nil
    end
    return true
end

local function IsBusy(entity)
    return s_IsBusy ~= nil and s_IsBusy(entity) == true
end

local function UpdateLocal(entry)
    local parentPosition, parentRotation = Pose(entry.Parent)
    local childPosition, childRotation = Pose(entry.Child)
    if not parentPosition or not childPosition then return false end
    entry.LocalPosition, entry.LocalRotation = Relative(parentPosition, parentRotation, childPosition, childRotation)
    return true
end

local function Release(entry)
    Physics.RestoreCollision(entry.Collision)
    Physics.Release(entry.Held, {})
end

function Attachments.SetBusyCheck(check)
    s_IsBusy = check
end

function Attachments.Get(entity)
    local index = FindIndex(Hash(entity))
    return index and s_List[index] or nil
end

function Attachments.IsAttached(entity)
    return Attachments.Get(entity) ~= nil
end

function Attachments.GetEntries()
    return s_List
end

function Attachments.Count()
    return #s_List
end

function Attachments.GetLocal(child)
    local entry = Attachments.Get(child)
    if not entry then return nil end
    return entry.LocalPosition, entry.LocalRotation
end

function Attachments.SetLocal(child, position, rotation)
    local entry = Attachments.Get(child)
    if not entry then return false end
    if position then entry.LocalPosition = { x = position.x, y = position.y, z = position.z } end
    if rotation then entry.LocalRotation = Rotation.Normalize(rotation) end
    return true
end

function Attachments.Attach(child, parent, names, localPosition, localRotation)
    local childHash, parentHash = Hash(child), Hash(parent)
    if not childHash or not parentHash then return false, "Couldn't read those entities." end
    if childHash == parentHash then return false, "A prop can't be attached to itself." end
    if WouldLoop(childHash, parentHash) then return false, "That would attach the prop to something already attached to it." end
    if FindIndex(childHash) then return false, "That prop is already attached. Detach it first." end

    names = names or {}
    local entry = {
        Child = child,
        ChildHash = childHash,
        Parent = parent,
        ParentHash = parentHash,
        Name = names.Name or "Prop",
        ParentName = names.ParentName or "Entity"
    }
    if localPosition and localRotation then
        entry.LocalPosition = { x = localPosition.x, y = localPosition.y, z = localPosition.z }
        entry.LocalRotation = Rotation.Normalize(localRotation)
    elseif not UpdateLocal(entry) then
        return false, "Couldn't read those entities' positions."
    end

    entry.Held = Physics.Hold(child, names.Kind)
    entry.Collision = Physics.DisableCollision(child)
    table.insert(s_List, entry)
    Logger.Log(string.format("WorldEditor Attachments: attached %s to %s", entry.Name, entry.ParentName))
    return true
end

function Attachments.Detach(child)
    local index = FindIndex(Hash(child))
    if not index then return false end
    local entry = table.remove(s_List, index)
    Release(entry)
    Logger.Log("WorldEditor Attachments: detached " .. entry.Name)
    return true
end

function Attachments.DetachAll()
    local removed = #s_List
    for index = #s_List, 1, -1 do Release(table.remove(s_List, index)) end
    return removed
end

function Attachments.Replace(old, new)
    local oldHash, newHash = Hash(old), Hash(new)
    if not oldHash or not newHash then return end
    for _, entry in ipairs(s_List) do
        if entry.ParentHash == oldHash then entry.Parent, entry.ParentHash = new, newHash end
        if entry.ChildHash == oldHash then entry.Child, entry.ChildHash = new, newHash end
    end
end

local function Lead(parent, position, deltaTime)
    if not Attachments.LagCompensation.value then return position end
    local velocity = Safe(function() return parent:GetLinearVelocity() end)
    if not velocity then return position end
    local step = deltaTime or 0
    return { x = position.x + velocity.x * step, y = position.y + velocity.y * step, z = position.z + velocity.z * step }
end

function Attachments.Tick(deltaTime)
    for index = #s_List, 1, -1 do
        local entry = s_List[index]
        if not IsValid(entry.Child) then
            table.remove(s_List, index)
        elseif not IsValid(entry.Parent) then
            Release(table.remove(s_List, index))
        elseif IsBusy(entry.Child) then
            entry.Moving = true
        else
            if entry.Moving then
                entry.Moving = false
                UpdateLocal(entry)
            end
            local parentPosition, parentRotation = Pose(entry.Parent)
            if parentPosition then
                local position, rotation = Compose(parentPosition, parentRotation, entry.LocalPosition, entry.LocalRotation)
                position = Lead(entry.Parent, position, deltaTime)
                Physics.Place(entry.Child, Vector4.new(position.x, position.y, position.z, 1.0), rotation)
            end
        end
    end
end

function Attachments.Forget()
    s_List = {}
end

return Attachments
