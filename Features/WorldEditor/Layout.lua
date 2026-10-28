local Entities = require("Utils/Entities")
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local PropCatalog = require("Features/WorldEditor/PropCatalog")
local Attachments = require("Features/WorldEditor/Attachments")
local Changes = require("Features/WorldEditor/Changes")

local Layout = {}

local SPAWN_TIMEOUT = 10.0
local AHEAD_OF_PLAYER = 5.0
local IDENTITY = { i = 0, j = 0, k = 0, r = 1 }

local s_Jobs = {}

local Safe = Entities.Safe
local Hash = Entities.Hash

local function CopyVector(vector)
    return { x = vector.x, y = vector.y, z = vector.z }
end

local function Appearance(entity)
    local name = Safe(function() return Game.NameToString(entity:GetCurrentAppearanceName()) end)
    if not name or name == "" or name == "None" then return nil end
    return name
end

local function RecordName(entity)
    local id = Safe(function() return entity:GetRecordID() end)
    local text = id and Safe(function() return TDBID.ToStringDEBUG(id) end)
    if not text or text == "" then return nil end
    return text
end

local function PlainEntry(entry)
    return {
        Name = entry.Name,
        Category = entry.Category,
        Group = entry.Group,
        Path = entry.Path,
        Record = entry.Record,
        Appearance = entry.Appearance
    }
end

local function WorldEntry(entity, name)
    if Physics.Classify(entity) == "Vehicle" then
        local record = RecordName(entity)
        if record then return { Name = name or "Vehicle", Category = "Vehicles", Group = "Copied", Record = record, Appearance = Appearance(entity) } end
    end

    local hash = EasyEntityTools and Safe(function() return EasyEntityTools.GetTemplatePathHash(entity) end)
    local catalog = PropCatalog.FindByTemplateHash(hash)
    if not catalog then return nil end
    return { Name = catalog.Name, Category = catalog.Category, Group = catalog.Group, Path = catalog.Path, Appearance = Appearance(entity) }
end

function Layout.EntryOf(entity, name)
    return PropSpawner.GetEntry(entity) or WorldEntry(entity, name)
end

function Layout.WithChildren(items)
    local list, seen = {}, {}
    local function Add(entity, name)
        local hash = Hash(entity)
        if not hash or seen[hash] then return end
        seen[hash] = true
        table.insert(list, { Entity = entity, Name = name })
        for _, link in ipairs(Attachments.GetEntries()) do
            if link.ParentHash == hash then Add(link.Child, link.Name) end
        end
    end
    for _, item in ipairs(items) do Add(item.Entity, item.Name) end
    return list
end

function Layout.Capture(items)
    local layout, indexByHash, skipped = { Items = {}, Links = {} }, {}, 0
    for _, item in ipairs(items) do
        local hash = Hash(item.Entity)
        local entry = hash and Layout.EntryOf(item.Entity, item.Name)
        local position, rotation = nil, nil
        if entry then position, rotation = Entities.Pose(item.Entity) end
        if position then
            table.insert(layout.Items, { Entry = PlainEntry(entry), Position = position, Rotation = rotation })
            indexByHash[hash] = #layout.Items
        else
            skipped = skipped + 1
        end
    end

    for _, link in ipairs(Attachments.GetEntries()) do
        local child, parent = indexByHash[link.ChildHash], indexByHash[link.ParentHash]
        if child and parent then
            table.insert(layout.Links, {
                Child = child,
                Parent = parent,
                Position = CopyVector(link.LocalPosition),
                Rotation = Rotation.Normalize(link.LocalRotation)
            })
        end
    end
    return layout, skipped
end

local function Spawnable(item)
    local entry = type(item) == "table" and item.Entry
    return type(entry) == "table" and (entry.Path ~= nil or entry.Record ~= nil)
        and type(item.Position) == "table" and type(item.Rotation) == "table"
end

local function Anchor(layout)
    local x, y, z = 0, 0, math.huge
    for _, item in ipairs(layout.Items) do
        x, y, z = x + item.Position.x, y + item.Position.y, math.min(z, item.Position.z)
    end
    return { x = x / #layout.Items, y = y / #layout.Items, z = z }
end

function Layout.Target()
    if FreeCam.IsReady() then
        local hit = Inspector.Hit
        if hit and hit.Position then return hit.Position end
        local camera, forward = FreeCam.GetPosition(), FreeCam.GetForward()
        local distance = PropSpawner.PreviewDistance.value
        return { x = camera.x + forward.x * distance, y = camera.y + forward.y * distance, z = camera.z + forward.z * distance }
    end

    local player = Game.GetPlayer()
    if not player then return nil end
    local position, forward = player:GetWorldPosition(), player:GetWorldForward()
    return { x = position.x + forward.x * AHEAD_OF_PLAYER, y = position.y + forward.y * AHEAD_OF_PLAYER, z = position.z }
end

function Layout.OffsetTo(layout, target)
    local anchor = Anchor(layout)
    return { x = target.x - anchor.x, y = target.y - anchor.y, z = target.z - anchor.z }
end

function Layout.Spawn(layout, offset, options)
    offset = offset or { x = 0, y = 0, z = 0 }
    local records, spawned = {}, 0
    for index, item in ipairs(layout.Items) do
        if Spawnable(item) then
            local position = { x = item.Position.x + offset.x, y = item.Position.y + offset.y, z = item.Position.z + offset.z }
            records[index] = PropSpawner.SpawnSaved(item.Entry, position, Rotation.ToQuaternion(item.Rotation))
            if records[index] then spawned = spawned + 1 end
        end
    end
    if spawned == 0 then return 0 end

    table.insert(s_Jobs, { Layout = layout, Records = records, Started = os.clock(), Options = options or {} })
    Changes.Mark()
    return spawned
end

function Layout.Duplicate(entity, name, mode, onDone)
    if not Layout.EntryOf(entity, name) then return false end
    local layout = Layout.Capture(Layout.WithChildren({ { Entity = entity, Name = name } }))

    local onto = nil
    local link = Attachments.Get(entity)
    if mode == "Parent" and link then
        onto = { Parent = link.Parent, ParentName = link.ParentName, Position = link.LocalPosition, Rotation = link.LocalRotation }
    elseif mode == "Child" then
        onto = { Parent = entity, ParentName = name, Position = { x = 0, y = 0, z = 0 }, Rotation = IDENTITY }
    end
    return Layout.Spawn(layout, nil, { Onto = onto, OnDone = onDone }) > 0
end

function Layout.SelectRoot(records, layout)
    local children = {}
    for _, link in ipairs(layout.Links) do children[link.Child] = true end
    for index = 1, #layout.Items do
        local record = records[index]
        if record and record.Entity and not children[index] then
            Selection.Select({ Entity = record.Entity, DisplayName = record.Entry.Name, Kind = Physics.Classify(record.Entity) })
            return record
        end
    end
    return nil
end

local function Ready(job)
    for _, record in pairs(job.Records) do
        if not record.Entity then return false end
    end
    return true
end

local function Link(job)
    local records = job.Records
    for _, link in ipairs(job.Layout.Links) do
        local child, parent = records[link.Child], records[link.Parent]
        if child and child.Entity and parent and parent.Entity then
            Attachments.Attach(child.Entity, parent.Entity, { Name = child.Entry.Name, ParentName = parent.Entry.Name }, link.Position, link.Rotation)
        end
    end

    local onto, root = job.Options.Onto, records[1]
    if onto and root and root.Entity and Entities.IsValid(onto.Parent) then
        Attachments.Attach(root.Entity, onto.Parent, { Name = root.Entry.Name, ParentName = onto.ParentName }, onto.Position, onto.Rotation)
    end

    Changes.Mark()
    if job.Options.OnDone then job.Options.OnDone(records, job.Layout) end
end

function Layout.IsBusy()
    return #s_Jobs > 0
end

function Layout.Tick()
    local now = os.clock()
    for index = #s_Jobs, 1, -1 do
        local job = s_Jobs[index]
        if Ready(job) or now - job.Started > SPAWN_TIMEOUT then
            table.remove(s_Jobs, index)
            Link(job)
        end
    end
end

function Layout.Forget()
    s_Jobs = {}
end

return Layout
