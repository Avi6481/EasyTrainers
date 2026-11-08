local Entities = require("Features/WorldEditor/Entities")
local Physics = require("Features/WorldEditor/Physics")
local Rotation = require("Features/WorldEditor/Rotation")
local Tracker = require("Features/WorldEditor/Tracker")
local Changes = require("Features/WorldEditor/Changes")
local Attachments = require("Features/WorldEditor/Attachments")

local Scene = {}

Scene.Rows = {}

local EDIT_SETTLE = 0.5

local s_Added = {}
local s_Edited = {}
local s_PlacedList = nil
local s_IsPlaced = nil
local s_Focus = {}

local Safe = Entities.Safe
local Hash = Entities.Hash
local IsValid = Entities.IsValid

local function Find(hash)
    for index, entry in ipairs(s_Added) do
        if entry.Hash == hash then return index end
    end
    return nil
end

local function IsPlaced(entity)
    return s_IsPlaced ~= nil and s_IsPlaced(entity) ~= nil
end

function Scene.SetPlacedSource(list, check)
    s_PlacedList, s_IsPlaced = list, check
end

function Scene.Add(entity, name, kind)
    local hash = Hash(entity)
    if not hash or Find(hash) or IsPlaced(entity) then return false end
    table.insert(s_Added, { Entity = entity, Hash = hash, Name = name or L("worldeditor.entity"), Kind = kind or "Prop" })
    Tracker.Set(entity, "Scene", { Name = name or L("worldeditor.entity"), Kind = kind or "Prop" })
    Changes.Mark()
    return true
end

function Scene.Remove(entity)
    local index = Find(Hash(entity))
    if not index then return false end
    table.remove(s_Added, index)
    Tracker.Set(entity, "Scene", nil)
    Changes.Mark()
    return true
end

function Scene.Contains(entity)
    local hash = Hash(entity)
    return hash ~= nil and (Find(hash) ~= nil or IsPlaced(entity))
end

function Scene.GetAll()
    local list = {}
    for _, placed in ipairs(s_PlacedList and s_PlacedList() or {}) do
        table.insert(list, { Entity = placed.Entity, Hash = placed.Hash, Name = placed.Name, Kind = "Prop", Placed = true })
    end
    for _, entry in ipairs(s_Added) do
        table.insert(list, { Entity = entry.Entity, Hash = entry.Hash, Name = entry.Name, Kind = entry.Kind, Placed = false })
    end
    return list
end

function Scene.Count()
    return #(s_PlacedList and s_PlacedList() or {}) + #s_Added
end

function Scene.Replace(old, new)
    local oldHash, newHash = Hash(old), Hash(new)
    if not oldHash then return end
    local index = Find(oldHash)
    if index then s_Added[index].Entity, s_Added[index].Hash = new, newHash end
    if s_Edited[oldHash] then s_Edited[newHash or oldHash] = s_Edited[oldHash] end
    for _, focus in pairs(s_Focus) do
        if focus.Hash == oldHash then focus.Entity, focus.Hash = new, newHash end
    end
end

function Scene.SetFocus(depth, entity, name, hash)
    if not entity then
        s_Focus[depth] = nil
        return
    end
    s_Focus[depth] = { Entity = entity, Hash = hash or Hash(entity), Name = name or L("worldeditor.entity") }
end

function Scene.GetFocus(depth)
    local focus = s_Focus[depth]
    if focus and focus.Valid == false then return nil end
    return focus
end

function Scene.Touch(entity)
    local hash = Hash(entity)
    if hash then s_Edited[hash] = os.clock() end
    Changes.Mark()
end

function Scene.IsEditingAny()
    local now = os.clock()
    for _, at in pairs(s_Edited) do
        if now - at < EDIT_SETTLE then return true end
    end
    return false
end

function Scene.GetName(entity)
    local hash = Hash(entity)
    local index = hash and Find(hash)
    return index and s_Added[index].Name or nil
end

function Scene.IsEditing(entity)
    local hash = Hash(entity)
    local at = hash and s_Edited[hash]
    return at ~= nil and os.clock() - at < EDIT_SETTLE
end

local function Angles(orientation)
    local angles = orientation and Safe(function() return orientation:ToEulerAngles() end)
    if not angles then return 0, 0, 0 end
    return angles.yaw or 0, angles.pitch or 0, angles.roll or 0
end

local function RefreshFocus(focus)
    focus.Valid = IsValid(focus.Entity)
    if not focus.Valid then return end

    local link = Attachments.GetByHash(focus.Hash)
    focus.Link = link
    focus.Children = #Attachments.ChildrenOf(focus.Hash)
    focus.Placed = IsPlaced(focus.Entity)

    local position, orientation
    if link then
        position = link.LocalPosition
        orientation = Rotation.ToQuaternion(link.LocalRotation)
    else
        position = Safe(function() return focus.Entity:GetWorldPosition() end)
        orientation = Safe(function() return focus.Entity:GetWorldOrientation() end)
    end
    if not position then
        focus.Pose = nil
        return
    end

    local yaw, pitch, roll = Angles(orientation)
    focus.Pose = { X = position.x, Y = position.y, Z = position.z, Yaw = yaw, Pitch = pitch, Roll = roll, Local = link ~= nil }
end

local function BuildRows()
    local entries = Scene.GetAll()
    local byHash, rows, seen = {}, {}, {}
    for _, entry in ipairs(entries) do
        entry.Hash = entry.Hash or Hash(entry.Entity)
        if entry.Hash then byHash[entry.Hash] = entry end
    end

    local function Add(entity, name, depth, hash)
        if not hash or seen[hash] then return end
        seen[hash] = true
        local known = byHash[hash]
        table.insert(rows, { Entity = entity, Hash = hash, Name = known and known.Name or name, Depth = depth })
        for _, link in ipairs(Attachments.GetEntries()) do
            if link.ParentHash == hash then Add(link.Child, link.Name, depth + 1, link.ChildHash) end
        end
    end

    for _, entry in ipairs(entries) do
        local link = entry.Hash and Attachments.GetByHash(entry.Hash)
        if not link or not byHash[link.ParentHash] then Add(entry.Entity, entry.Name, 0, entry.Hash) end
    end
    return rows
end

function Scene.Refresh()
    Scene.Rows = BuildRows()
    for _, focus in pairs(s_Focus) do RefreshFocus(focus) end
end

function Scene.ApplyPose(depth, pose)
    local focus = s_Focus[depth]
    if not focus or not IsValid(focus.Entity) then return end

    local entity = focus.Entity
    local orientation = EulerAngles.new(pose.Roll, pose.Pitch, pose.Yaw):ToQuat()
    Scene.Touch(entity)
    if Attachments.GetByHash(focus.Hash) then
        Attachments.SetLocal(entity, { x = pose.X, y = pose.Y, z = pose.Z }, Rotation.FromQuaternion(orientation))
    else
        Physics.Place(entity, Vector4.new(pose.X, pose.Y, pose.Z, 1.0), orientation)
    end
    RefreshFocus(focus)
end

function Scene.Tick()
    for index = #s_Added, 1, -1 do
        if not IsValid(s_Added[index].Entity) then table.remove(s_Added, index) end
    end
    local now = os.clock()
    for hash, at in pairs(s_Edited) do
        if now - at >= EDIT_SETTLE then s_Edited[hash] = nil end
    end
end

function Scene.Forget()
    s_Added = {}
    s_Edited = {}
    s_Focus = {}
    Scene.Rows = {}
end

return Scene
