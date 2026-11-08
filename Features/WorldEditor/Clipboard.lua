local State = require("Core/State")
local Notify = require("Utils/Notify")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Layout = require("Features/WorldEditor/Layout")

local Clipboard = {}

local s_Layout = nil

local function Count(key, count)
    return tip(key .. (count == 1 and ".one" or ".many"), { count = count })
end

local function IsController()
    return State.Device.Device == State.Devices.Controller
end

function Clipboard.Count()
    return s_Layout and #s_Layout.Items or 0
end

function Clipboard.CanCopy(entity, name)
    return Layout.EntryOf(entity, name) ~= nil
end

function Clipboard.CopyItems(items)
    local layout, skipped = Layout.Capture(Layout.WithChildren(items))
    if #layout.Items == 0 then
        Notify.Warning(L("notify.worldeditor.copy.none"))
        return false
    end

    s_Layout = layout
    local text = Count("notify.worldeditor.copy.done", #layout.Items)
    if skipped > 0 then text = text .. " " .. Count("notify.worldeditor.copy.skipped", skipped) end
    Notify.Info(text)
    return true
end

function Clipboard.Copy()
    return Clipboard.CopyItems(Selection.GetAll())
end

function Clipboard.CutItems(items)
    items = Layout.WithChildren(items)
    if not Clipboard.CopyItems(items) then return end
    local kept = 0
    for _, item in ipairs(items) do
        if not PropSpawner.Delete(item.Entity) then kept = kept + 1 end
    end
    Selection.Clear()
    if kept > 0 then Notify.Info(L("notify.worldeditor.cut.kept")) end
end

function Clipboard.Cut()
    Clipboard.CutItems(Selection.GetAll())
end

function Clipboard.DeleteItems(items)
    local removed, skipped = 0, 0
    local entities = {}
    for _, item in ipairs(items) do table.insert(entities, item.Entity) end
    for _, entity in ipairs(entities) do
        if PropSpawner.Delete(entity) then removed = removed + 1 else skipped = skipped + 1 end
    end
    Selection.Clear()
    if removed == 0 then
        Notify.Warning(L("notify.worldeditor.delete.none"))
        return
    end
    local text = Count("notify.worldeditor.delete.done", removed)
    if skipped > 0 then text = text .. " " .. L("notify.worldeditor.delete.kept") end
    Notify.Success(text)
end

function Clipboard.DeleteSelection()
    Clipboard.DeleteItems(Selection.GetAll())
end

function Clipboard.PasteAt(target)
    if not s_Layout then
        Notify.Warning(L(IsController() and "notify.worldeditor.paste.empty.controller" or "notify.worldeditor.paste.empty.keyboard"))
        return
    end
    if not target then return end

    local spawned = Layout.Spawn(s_Layout, Layout.OffsetTo(s_Layout, target), { OnDone = Layout.SelectRoot })
    if spawned == 0 then
        Notify.Error(L("notify.worldeditor.paste.failed"))
        return
    end
    Notify.Success(Count("notify.worldeditor.paste.done", spawned))
end

function Clipboard.Paste()
    Clipboard.PasteAt(Layout.Target())
end

return Clipboard
