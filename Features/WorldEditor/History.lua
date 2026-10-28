local Notification = require("UI/Panels/Notification/Notification")
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Changes = require("Features/WorldEditor/Changes")
local Entities = require("Utils/Entities")

local History = {}

local LIMIT = 50
local STABLE_TIME = 0.75
local APPLY_TIMEOUT = 10.0
local POSITION_TOLERANCE = 0.02
local ROTATION_TOLERANCE = 0.9995

local s_Undo = {}
local s_Redo = {}
local s_Current = nil
local s_Applying = nil
local s_IsBusy = nil

local Hash = Entities.Hash
local IsValid = Entities.IsValid

local function Key(entity)
    local uid = PropSpawner.GetUid(entity)
    if uid then return "p" .. uid end
    local hash = Hash(entity)
    return hash and ("w" .. hash) or nil
end

local Pose = Entities.Pose

local function SamePose(a, b)
    if not a or not b then return a == b end
    local p, q = a.Position, b.Position
    if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 + (p.z - q.z) ^ 2 > POSITION_TOLERANCE ^ 2 then return false end
    local r, t = a.Rotation, b.Rotation
    return math.abs(r.i * t.i + r.j * t.j + r.k * t.k + r.r * t.r) >= ROTATION_TOLERANCE
end

local function SameKeys(a, b)
    for key in pairs(a) do
        if b[key] == nil then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function Differs(a, b)
    if not SameKeys(a.Props, b.Props) or not SameKeys(a.Entities, b.Entities) or #a.Links ~= #b.Links then return true end
    for uid, prop in pairs(a.Props) do
        local other = b.Props[uid]
        if prop.Attached ~= other.Attached then return true end
        if not prop.Attached and not SamePose(prop, other) then return true end
    end
    for key, pose in pairs(a.World) do
        if not SamePose(pose, b.World[key]) then return true end
    end
    local links = {}
    for _, link in ipairs(b.Links) do links[link.Child] = link end
    for _, link in ipairs(a.Links) do
        local other = links[link.Child]
        if not other or other.Parent ~= link.Parent or not SamePose(link, other) then return true end
    end
    return false
end

local function Capture()
    local state = { Props = {}, World = {}, Links = {}, Entities = {}, Names = {} }

    for _, item in ipairs(PropSpawner.Snapshot()) do
        if item.Uid then
            local attached = item.Entity ~= nil and Attachments.IsAttached(item.Entity)
            local position = { x = item.Pose.Position.x, y = item.Pose.Position.y, z = item.Pose.Position.z }
            state.Props[item.Uid] = { Entry = item.Entry, Position = position, Rotation = Rotation.FromQuaternion(item.Pose.Orientation), Attached = attached }
        end
    end

    for _, entry in ipairs(Scene.GetAll()) do
        if not entry.Placed then
            local key = Key(entry.Entity)
            local position, rotation = Pose(entry.Entity)
            if key and position then
                state.Entities[key], state.Names[key] = entry.Entity, entry.Name
                if not Attachments.IsAttached(entry.Entity) then state.World[key] = { Position = position, Rotation = rotation } end
            end
        end
    end

    for _, link in ipairs(Attachments.GetEntries()) do
        local child, parent = Key(link.Child), Key(link.Parent)
        if child and parent then
            if child:sub(1, 1) == "w" then state.Entities[child] = link.Child end
            if parent:sub(1, 1) == "w" then state.Entities[parent] = link.Parent end
            local position = { x = link.LocalPosition.x, y = link.LocalPosition.y, z = link.LocalPosition.z }
            table.insert(state.Links, { Child = child, Parent = parent, Position = position, Rotation = Rotation.Normalize(link.LocalRotation), ChildName = link.Name, ParentName = link.ParentName })
        end
    end
    return state
end

local function Push(stack, state)
    table.insert(stack, state)
    if #stack > LIMIT then table.remove(stack, 1) end
end

local function Commit(state)
    if s_Current then Push(s_Undo, s_Current) end
    s_Current = state
    s_Redo = {}
end

local function Flush()
    if not Changes.MarkedAt() then return end
    Changes.Clear()
    local state = Capture()
    if not s_Current then
        s_Current = state
    elseif Differs(state, s_Current) then
        Commit(state)
    end
end

local function Resolve(key, entities)
    if key:sub(1, 1) == "p" then
        local record = PropSpawner.FindUid(tonumber(key:sub(2)))
        return record and record.Entity or nil
    end
    local entity = entities[key]
    if entity and IsValid(entity) then return entity end
    return nil
end

local function Apply(target)
    Changes.Mute(true)
    Selection.Clear()
    Attachments.DetachAll()

    local current = {}
    for _, item in ipairs(PropSpawner.Snapshot()) do
        if item.Uid then current[item.Uid] = true end
    end
    for uid in pairs(current) do
        if not target.Props[uid] then PropSpawner.DeleteUid(uid) end
    end

    for uid, prop in pairs(target.Props) do
        local record = PropSpawner.FindUid(uid)
        if not record then
            PropSpawner.SpawnSaved(prop.Entry, prop.Position, Rotation.ToQuaternion(prop.Rotation), uid)
        elseif record.Entity and not prop.Attached then
            Physics.Place(record.Entity, Vector4.new(prop.Position.x, prop.Position.y, prop.Position.z, 1.0), prop.Rotation)
        end
    end

    for _, entry in ipairs(Scene.GetAll()) do
        if not entry.Placed then
            local key = Key(entry.Entity)
            if key and not target.Entities[key] then Scene.Remove(entry.Entity) end
        end
    end
    for key, entity in pairs(target.Entities) do
        if IsValid(entity) then
            Scene.Add(entity, target.Names[key])
            local pose = target.World[key]
            if pose then Physics.Place(entity, Vector4.new(pose.Position.x, pose.Position.y, pose.Position.z, 1.0), pose.Rotation) end
        end
    end

    local links = {}
    for _, link in ipairs(target.Links) do table.insert(links, link) end
    s_Applying = { Links = links, Entities = target.Entities, Started = os.clock() }
end

local function FinishApply()
    local applying = s_Applying
    for index = #applying.Links, 1, -1 do
        local link = applying.Links[index]
        local child, parent = Resolve(link.Child, applying.Entities), Resolve(link.Parent, applying.Entities)
        if child and parent then
            Attachments.Attach(child, parent, { Name = link.ChildName, ParentName = link.ParentName }, link.Position, link.Rotation)
            table.remove(applying.Links, index)
        end
    end
    if #applying.Links == 0 or os.clock() - applying.Started > APPLY_TIMEOUT then
        s_Applying = nil
        s_Current = Capture()
        Changes.Mute(false)
        Changes.Clear()
    end
end

local function Step(from, to, label)
    if s_Applying then return end
    Flush()
    local target = table.remove(from)
    if not target then
        Notification.Info("Nothing to " .. label .. ".")
        return
    end
    Push(to, s_Current)
    s_Current = target
    Apply(target)
    Notification.Info(string.format("%s (%d left).", label == "undo" and "Undone" or "Redone", #from))
end

function History.Undo()
    Step(s_Undo, s_Redo, "undo")
end

function History.Redo()
    Step(s_Redo, s_Undo, "redo")
end

function History.CanUndo()
    return #s_Undo > 0
end

function History.CanRedo()
    return #s_Redo > 0
end

function History.SetBusyCheck(check)
    s_IsBusy = check
end

function History.Rebase()
    s_Current = Capture()
    Changes.Clear()
end

function History.Tick()
    if s_Applying then
        FinishApply()
        return
    end

    local marked = Changes.MarkedAt()
    if not marked or os.clock() - marked < STABLE_TIME or (s_IsBusy and s_IsBusy()) then return end
    Flush()
end

function History.Forget()
    s_Undo, s_Redo = {}, {}
    s_Current, s_Applying = nil, nil
    Changes.Mute(false)
    Changes.Clear()
end

return History
