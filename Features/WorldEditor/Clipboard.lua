local Rotation = require("Utils/Rotation")
local Notification = require("UI/Panels/Notification/Notification")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Attachments = require("Features/WorldEditor/Attachments")

local Clipboard = {}

local PASTE_TIMEOUT = 10.0

local s_Items = {}
local s_Links = {}
local s_Pending = nil

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Hash(entity)
    return entity and Safe(function() return tostring(entity:GetEntityID().hash) end)
end

local function Plural(count, word)
    return count == 1 and ("1 " .. word) or (count .. " " .. word .. "s")
end

function Clipboard.Count()
    return #s_Items
end

function Clipboard.Copy()
    local items, indexByHash, skipped = {}, {}, 0
    for _, selected in ipairs(Selection.GetAll()) do
        local entry = PropSpawner.GetEntry(selected.Entity)
        local position = entry and Safe(function() return selected.Entity:GetWorldPosition() end)
        local orientation = entry and Safe(function() return selected.Entity:GetWorldOrientation() end)
        if position and orientation then
            table.insert(items, {
                Entry = entry,
                Position = { x = position.x, y = position.y, z = position.z },
                Rotation = Rotation.FromQuaternion(orientation)
            })
            indexByHash[Hash(selected.Entity)] = #items
        else
            skipped = skipped + 1
        end
    end

    if #items == 0 then
        Notification.Warning("Select props you placed to copy them. Map entities can't be copied yet.")
        return 0
    end

    local links = {}
    for _, link in ipairs(Attachments.GetEntries()) do
        local child, parent = indexByHash[link.ChildHash], indexByHash[link.ParentHash]
        if child and parent then
            table.insert(links, { Child = child, Parent = parent, Position = link.LocalPosition, Rotation = link.LocalRotation })
        end
    end

    s_Items, s_Links = items, links
    local note = skipped > 0 and string.format(" Skipped %s that weren't placed by you.", Plural(skipped, "entity")) or ""
    Notification.Info("Copied " .. Plural(#items, "prop") .. "." .. note)
    return #items
end

function Clipboard.Cut()
    local selected = {}
    for _, entry in ipairs(Selection.GetAll()) do table.insert(selected, entry.Entity) end
    if Clipboard.Copy() == 0 then return end
    for _, entity in ipairs(selected) do PropSpawner.Delete(entity) end
    Selection.Clear()
end

function Clipboard.DeleteSelection()
    local removed, skipped = 0, 0
    local selected = {}
    for _, entry in ipairs(Selection.GetAll()) do table.insert(selected, entry.Entity) end
    for _, entity in ipairs(selected) do
        if PropSpawner.Delete(entity) then removed = removed + 1 else skipped = skipped + 1 end
    end
    Selection.Clear()
    if removed == 0 then
        Notification.Warning("Only props you placed can be deleted.")
        return
    end
    local note = skipped > 0 and " Map entities were left alone." or ""
    Notification.Info("Deleted " .. Plural(removed, "prop") .. "." .. note)
end

local function PasteTarget()
    local hit = Inspector.Hit
    if hit and hit.Position then return hit.Position end
    local camera, forward = FreeCam.GetPosition(), FreeCam.GetForward()
    local distance = PropSpawner.PreviewDistance.value
    return { x = camera.x + forward.x * distance, y = camera.y + forward.y * distance, z = camera.z + forward.z * distance }
end

local function Anchor()
    local x, y, z = 0, 0, math.huge
    for _, item in ipairs(s_Items) do
        x, y, z = x + item.Position.x, y + item.Position.y, math.min(z, item.Position.z)
    end
    return { x = x / #s_Items, y = y / #s_Items, z = z }
end

function Clipboard.Paste()
    if #s_Items == 0 then
        Notification.Warning("Nothing copied yet. Select props and press Ctrl+C.")
        return
    end
    if not FreeCam.IsReady() then
        Notification.Warning("Open the World Editor first.")
        return
    end

    local target, anchor = PasteTarget(), Anchor()
    local offset = { x = target.x - anchor.x, y = target.y - anchor.y, z = target.z - anchor.z }
    local records = {}
    for index, item in ipairs(s_Items) do
        local position = { x = item.Position.x + offset.x, y = item.Position.y + offset.y, z = item.Position.z + offset.z }
        records[index] = PropSpawner.SpawnSaved(item.Entry, position, Rotation.ToQuaternion(item.Rotation))
    end

    local links = {}
    for _, link in ipairs(s_Links) do table.insert(links, link) end
    s_Pending = { Records = records, Links = links, Started = os.clock() }
    Notification.Info("Pasted " .. Plural(#s_Items, "prop") .. ".")
end

local function AllSpawned(records)
    for _, record in pairs(records) do
        if not record.Entity then return false end
    end
    return true
end

local function FinishPaste()
    local pending = s_Pending
    if not AllSpawned(pending.Records) then
        if os.clock() - pending.Started > PASTE_TIMEOUT then s_Pending = nil end
        return
    end

    for _, link in ipairs(pending.Links) do
        local child, parent = pending.Records[link.Child], pending.Records[link.Parent]
        if child and parent then
            Attachments.Attach(child.Entity, parent.Entity, { Name = child.Entry.Name, ParentName = parent.Entry.Name }, link.Position, link.Rotation)
        end
    end

    local children = {}
    for _, link in ipairs(pending.Links) do children[link.Child] = true end
    for index, record in pairs(pending.Records) do
        if not children[index] then
            Selection.Select({ Entity = record.Entity, DisplayName = record.Entry.Name, Kind = "Prop" })
            break
        end
    end
    s_Pending = nil
end

function Clipboard.Tick()
    if s_Pending then FinishPaste() end
end

function Clipboard.Forget()
    s_Pending = nil
end

return Clipboard
