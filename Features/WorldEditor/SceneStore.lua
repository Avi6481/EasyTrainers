local Logger = require("Core/Logger")
local JsonHelper = require("Core/JsonHelper")
local Physics = require("Utils/Physics")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")

local SceneStore = {}

SceneStore.KeepProps = { value = true }

local FILE = "Config/JSON/WorldEditorScene.json"
local VERSION = 2
local SAVE_INTERVAL = 2.0
local RESTORE_DELAY = 3.0
local RESTORE_TIMEOUT = 20.0
local SEARCH_INTERVAL = 0.5
local SEARCH_RANGE = 250
local MATCH_DISTANCE = 5

local s_Ready = false
local s_RestoreAt = nil
local s_Pending = nil
local s_NextSave = 0
local s_LastSignature = nil
local s_Unspawned = {}

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Hash(entity)
    return entity and Safe(function() return tostring(entity:GetEntityID().hash) end)
end

local function Round(value)
    return math.floor(value * 1000 + 0.5) / 1000
end

local function Vector(vector)
    return { Round(vector.x), Round(vector.y), Round(vector.z) }
end

local function Quat(q)
    return { Round(q.i), Round(q.j), Round(q.k), Round(q.r) }
end

local function RecordName(entity)
    local id = Safe(function() return entity:GetRecordID() end)
    local text = id and Safe(function() return TDBID.ToStringDEBUG(id) end)
    if not text or text == "" then return nil end
    return text
end

local function ClassName(entity)
    return Safe(function() return Game.NameToString(entity:GetClassName()) end)
end

local function Describe(entity, name, kind)
    local position = Safe(function() return entity:GetWorldPosition() end)
    return {
        Id = EasyEntityTools and Safe(function() return EasyEntityTools.GetEntityIDString(entity) end) or nil,
        Record = RecordName(entity),
        Class = ClassName(entity),
        Kind = kind or Physics.Classify(entity),
        Name = name,
        Position = position and Vector(position) or nil
    }
end

local function Build()
    local props, indexByHash = {}, {}
    for _, item in ipairs(PropSpawner.Snapshot()) do
        table.insert(props, {
            Name = item.Entry.Name,
            Category = item.Entry.Category,
            Group = item.Entry.Group,
            Path = item.Entry.Path,
            Position = Vector(item.Pose.Position),
            Rotation = Quat(item.Pose.Orientation)
        })
        local hash = Hash(item.Entity)
        if hash then indexByHash[hash] = #props end
    end
    for _, prop in ipairs(s_Unspawned) do table.insert(props, prop) end

    local function Endpoint(entity, hash, name)
        local index = indexByHash[hash]
        if index then return { Prop = index } end
        return { World = Describe(entity, name) }
    end

    local links = {}
    for _, entry in ipairs(Attachments.GetEntries()) do
        table.insert(links, {
            Child = Endpoint(entry.Child, entry.ChildHash, entry.Name),
            Parent = Endpoint(entry.Parent, entry.ParentHash, entry.ParentName),
            ChildName = entry.Name,
            ParentName = entry.ParentName,
            Position = Vector(entry.LocalPosition),
            Rotation = Quat(entry.LocalRotation)
        })
    end

    local scene = {}
    for _, entry in ipairs(Scene.GetAll()) do
        if not entry.Placed then table.insert(scene, Describe(entry.Entity, entry.Name, entry.Kind)) end
    end
    return { Version = VERSION, Props = props, Links = links, Scene = scene }
end

local function EndpointKey(endpoint)
    if endpoint.Prop then return "p" .. endpoint.Prop end
    local world = endpoint.World or {}
    return "w" .. tostring(world.Id or world.Record or world.Class)
end

local function Signature(data)
    local parts = {}
    for _, prop in ipairs(data.Props) do
        table.insert(parts, prop.Path .. table.concat(prop.Position, ",") .. table.concat(prop.Rotation, ","))
    end
    for _, link in ipairs(data.Links) do
        table.insert(parts, EndpointKey(link.Child) .. ">" .. EndpointKey(link.Parent) .. table.concat(link.Position, ",") .. table.concat(link.Rotation, ","))
    end
    for _, entry in ipairs(data.Scene) do table.insert(parts, "s" .. tostring(entry.Id or entry.Record or entry.Class)) end
    return table.concat(parts, "|")
end

function SceneStore.Save(force)
    if not s_Ready or not SceneStore.KeepProps.value then return false end
    local data = Build()
    local signature = Signature(data)
    if not force and signature == s_LastSignature then return false end

    local ok, err = JsonHelper.Write(FILE, data)
    if not ok then
        Logger.Log("SceneStore: failed to save (" .. tostring(err) .. ")")
        return false
    end
    s_LastSignature = signature
    return true
end

local function Matches(entity, descriptor)
    if descriptor.Record then return RecordName(entity) == descriptor.Record end
    return descriptor.Class ~= nil and ClassName(entity) == descriptor.Class
end

local function FindById(descriptor)
    if not descriptor.Id or descriptor.Id == "" or not EasyEntityTools then return nil end
    local id = Safe(function() return EasyEntityTools.EntityIDFromString(descriptor.Id) end)
    local entity = id and Safe(function() return Game.FindEntityByID(id) end)
    if entity and Matches(entity, descriptor) then return entity end
    return nil
end

local function FindNearby(descriptor)
    local saved = descriptor.Position
    local player = Game.GetPlayer()
    if not saved or not player then return nil end

    local nearby = Safe(function() return player:GetEntitiesAroundObject(SEARCH_RANGE, TargetSearchQuery.new().searchFilter) end)
    local best, bestDistance = nil, MATCH_DISTANCE
    for _, entity in ipairs(type(nearby) == "table" and nearby or {}) do
        local position = Safe(function() return entity:GetWorldPosition() end)
        if position and Matches(entity, descriptor) then
            local distance = math.sqrt((position.x - saved[1]) ^ 2 + (position.y - saved[2]) ^ 2 + (position.z - saved[3]) ^ 2)
            if distance <= bestDistance then best, bestDistance = entity, distance end
        end
    end
    return best
end

local function FindWorld(descriptor, search)
    if descriptor.Found then return descriptor.Found end
    descriptor.Found = FindById(descriptor) or (search and FindNearby(descriptor)) or nil
    return descriptor.Found
end

local function Upgrade(data)
    if data.Version == VERSION then return data end
    local links = {}
    for _, link in ipairs(data.Attachments or {}) do
        table.insert(links, { Child = { Prop = link.Child }, Parent = { Prop = link.Parent }, Position = link.Position, Rotation = link.Rotation })
    end
    return { Version = VERSION, Props = data.Props or {}, Links = links, Scene = {} }
end

local function Restore()
    s_Ready = true
    if not SceneStore.KeepProps.value then return end

    local data = JsonHelper.ReadOptional(FILE)
    if type(data) ~= "table" or type(data.Props) ~= "table" then return end
    data = Upgrade(data)

    local records = {}
    s_Unspawned = {}
    for index, prop in ipairs(data.Props) do
        local entry = { Name = prop.Name, Category = prop.Category, Group = prop.Group, Path = prop.Path }
        local position = { x = prop.Position[1], y = prop.Position[2], z = prop.Position[3] }
        local orientation = Quaternion.new(prop.Rotation[1], prop.Rotation[2], prop.Rotation[3], prop.Rotation[4])
        records[index] = PropSpawner.SpawnSaved(entry, position, orientation)
        if not records[index] then table.insert(s_Unspawned, prop) end
    end

    if #data.Props + #data.Links + #data.Scene == 0 then return end
    s_Pending = { Records = records, Links = data.Links, Scene = data.Scene, Started = os.clock(), NextSearch = 0 }
    s_LastSignature = nil
    Logger.Log(string.format("SceneStore: restoring %d props, %d attachments, %d scene entities", #data.Props, #data.Links, #data.Scene))
end

local function Resolve(endpoint, search)
    if endpoint.Prop then
        local record = s_Pending.Records[endpoint.Prop]
        return record and record.Entity or nil, record ~= nil
    end
    if endpoint.World then return FindWorld(endpoint.World, search), true end
    return nil, false
end

local function FinishRestore()
    local pending = s_Pending
    local now = os.clock()
    local search = now >= pending.NextSearch
    if search then pending.NextSearch = now + SEARCH_INTERVAL end

    for index = #pending.Links, 1, -1 do
        local link = pending.Links[index]
        local child, childKnown = Resolve(link.Child, search)
        local parent, parentKnown = Resolve(link.Parent, search)
        if not childKnown or not parentKnown then
            table.remove(pending.Links, index)
        elseif child and parent then
            local position = { x = link.Position[1], y = link.Position[2], z = link.Position[3] }
            local rotation = { i = link.Rotation[1], j = link.Rotation[2], k = link.Rotation[3], r = link.Rotation[4] }
            Attachments.Attach(child, parent, { Name = link.ChildName, ParentName = link.ParentName }, position, rotation)
            if link.Child.World then Scene.Add(child, link.ChildName, link.Child.World.Kind) end
            if link.Parent.World then Scene.Add(parent, link.ParentName, link.Parent.World.Kind) end
            table.remove(pending.Links, index)
        end
    end

    for index = #pending.Scene, 1, -1 do
        local descriptor = pending.Scene[index]
        local entity = FindWorld(descriptor, search)
        if entity then
            Scene.Add(entity, descriptor.Name, descriptor.Kind)
            table.remove(pending.Scene, index)
        end
    end

    local done = #pending.Links == 0 and #pending.Scene == 0
    if done or now - pending.Started > RESTORE_TIMEOUT then
        if not done then Logger.Log(string.format("SceneStore: gave up on %d attachments and %d scene entities", #pending.Links, #pending.Scene)) end
        s_Pending = nil
    end
end

function SceneStore.Tick()
    local now = os.clock()
    if not s_Ready then
        if not Game.GetPlayer() then return end
        s_RestoreAt = s_RestoreAt or now + RESTORE_DELAY
        if now >= s_RestoreAt then Restore() end
        return
    end

    if s_Pending then
        FinishRestore()
        return
    end

    if now >= s_NextSave then
        s_NextSave = now + SAVE_INTERVAL
        SceneStore.Save(false)
    end
end

function SceneStore.Forget()
    s_Ready = false
    s_RestoreAt = nil
    s_Pending = nil
end

return SceneStore
