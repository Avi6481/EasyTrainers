local Logger = require("Core/Logger")
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")
local Tracker = require("Features/WorldEditor/Tracker")
local Changes = require("Features/WorldEditor/Changes")
local Entities = require("Utils/Entities")

local Attachments = {}

local MAX_DEPTH = 64
local CHECK_INTERVAL = 0.5

local s_List = {}
local s_NoSlot = nil
local s_NextCheck = 0

local Safe = Entities.Safe
local Hash = Entities.Hash
local IsValid = Entities.IsValid
local Pose = Entities.Pose

local function Relative(parentPosition, parentRotation, childPosition, childRotation)
    local inverse = Rotation.Conjugate(parentRotation)
    local offset = Rotation.Rotate(inverse, {
        x = childPosition.x - parentPosition.x,
        y = childPosition.y - parentPosition.y,
        z = childPosition.z - parentPosition.z
    })
    return offset, Rotation.Normalize(Rotation.Multiply(inverse, childRotation))
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

local function TrackLink(entry)
    Tracker.Set(entry.Child, "Link", {
        Parent = Tracker.IdString(entry.Parent),
        Name = entry.Name,
        ParentName = entry.ParentName,
        Position = { x = entry.LocalPosition.x, y = entry.LocalPosition.y, z = entry.LocalPosition.z },
        Rotation = { i = entry.LocalRotation.i, j = entry.LocalRotation.j, k = entry.LocalRotation.k, r = entry.LocalRotation.r }
    })
end

local function UpdateLocal(entry)
    local parentPosition, parentRotation = Pose(entry.Parent)
    local childPosition, childRotation = Pose(entry.Child)
    if not parentPosition or not childPosition then return false end
    entry.LocalPosition, entry.LocalRotation = Relative(parentPosition, parentRotation, childPosition, childRotation)
    return true
end

local function Root(entity)
    return EasyEntityTools and Safe(function() return EasyEntityTools.GetRootComponent(entity) end)
end

local function NoSlot()
    s_NoSlot = s_NoSlot or CName.new("None")
    return s_NoSlot
end

local function BindTarget(parent)
    local root = Root(parent)
    local name = root and Safe(function() return root:GetName() end)
    local text = name and Safe(function() return Game.NameToString(name) end)
    if not text or text == "" or text == "None" then return nil end
    return name, text
end

local function ApplyLocal(entry)
    local root = Root(entry.Child)
    if not root then return false end
    local position = entry.LocalPosition
    return pcall(function()
        root:SetLocalTransform(Vector4.new(position.x, position.y, position.z, 1.0), Rotation.ToQuaternion(entry.LocalRotation))
    end)
end

local function Bind(entry)
    local target = BindTarget(entry.Parent)
    if not target then return false end
    local bound = pcall(function()
        EntityGameInterface.BindToComponent(entry.Child:GetEntity(), entry.Parent:GetEntity(), target, NoSlot(), true)
    end)
    return bound and ApplyLocal(entry)
end

local function Unbind(entity)
    local position, rotation = Pose(entity)
    local unbound = pcall(function() EntityGameInterface.UnbindTransform(entity:GetEntity()) end)
    if unbound and position then Physics.Place(entity, Vector4.new(position.x, position.y, position.z, 1.0), rotation) end
    return unbound
end

local function Release(entry)
    Physics.RestoreCollision(entry.Collision)
    Physics.Release(entry.Held, {})
end

local function Hold(entry, kind)
    entry.Held = Physics.Hold(entry.Child, kind)
    entry.Collision = Physics.DisableCollision(entry.Child)
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
    ApplyLocal(entry)
    TrackLink(entry)
    Changes.Mark()
    return true
end

function Attachments.Attach(child, parent, names, localPosition, localRotation)
    local childHash, parentHash = Hash(child), Hash(parent)
    if not childHash or not parentHash then return false, "Couldn't read those entities." end
    if childHash == parentHash then return false, "A prop can't be attached to itself." end
    if WouldLoop(childHash, parentHash) then return false, "That would attach the prop to something already attached to it." end
    if FindIndex(childHash) then return false, "That prop is already attached. Detach it first." end

    local _, targetName = BindTarget(parent)
    if not targetName then return false, "The game can't attach things to that entity." end

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

    Hold(entry, names.Kind)
    if not Bind(entry) then
        Release(entry)
        return false, "The game couldn't attach those."
    end

    table.insert(s_List, entry)
    TrackLink(entry)
    Changes.Mark()
    Logger.Log(string.format("WorldEditor Attachments: bound %s to %s (%s)", entry.Name, entry.ParentName, targetName))
    return true
end

local function Remove(index)
    local entry = table.remove(s_List, index)
    Unbind(entry.Child)
    Release(entry)
    Tracker.Set(entry.Child, "Link", nil)
    Changes.Mark()
    return entry
end

function Attachments.Detach(child)
    local index = FindIndex(Hash(child))
    if not index then return false end
    local entry = Remove(index)
    Logger.Log("WorldEditor Attachments: unbound " .. entry.Name)
    return true
end

function Attachments.DetachChildrenOf(parent)
    local hash = Hash(parent)
    local removed = 0
    if not hash then return removed end
    for index = #s_List, 1, -1 do
        if s_List[index].ParentHash == hash and Attachments.Detach(s_List[index].Child) then removed = removed + 1 end
    end
    return removed
end

function Attachments.Unlink(entity)
    Attachments.DetachChildrenOf(entity)
    Attachments.Detach(entity)
end

function Attachments.HasChildren(parent)
    local hash = Hash(parent)
    for _, entry in ipairs(s_List) do
        if entry.ParentHash == hash then return true end
    end
    return false
end

function Attachments.DetachAll()
    local removed = #s_List
    for index = #s_List, 1, -1 do Remove(index) end
    return removed
end

function Attachments.BeginMove(entity)
    local entry = Attachments.Get(entity)
    if not entry or entry.Moving then return end
    entry.Moving = true
    Unbind(entry.Child)
end

function Attachments.EndMove(entity)
    local entry = Attachments.Get(entity)
    if not entry or not entry.Moving then return end
    entry.Moving = false
    if UpdateLocal(entry) and Bind(entry) then
        TrackLink(entry)
        return
    end
    Remove(FindIndex(entry.ChildHash))
end

function Attachments.Replace(old, new)
    local oldHash, newHash = Hash(old), Hash(new)
    if not oldHash or not newHash then return end
    for _, entry in ipairs(s_List) do
        if entry.ChildHash == oldHash then
            entry.Child, entry.ChildHash = new, newHash
            Hold(entry)
            if not entry.Moving then Bind(entry) end
        end
        if entry.ParentHash == oldHash then
            entry.Parent, entry.ParentHash = new, newHash
            if not entry.Moving then Bind(entry) end
            TrackLink(entry)
        end
    end
end

function Attachments.Tick()
    local now = os.clock()
    if now < s_NextCheck then return end
    s_NextCheck = now + CHECK_INTERVAL

    for index = #s_List, 1, -1 do
        local entry = s_List[index]
        if not IsValid(entry.Child) then
            table.remove(s_List, index)
        elseif not entry.Moving and not IsValid(entry.Parent) then
            Remove(index)
        end
    end
end

function Attachments.Shutdown()
    for _, entry in ipairs(s_List) do Release(entry) end
    s_List = {}
end

function Attachments.Forget()
    s_List = {}
end

return Attachments
