local Notification = require("UI/Panels/Notification/Notification")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Layout = require("Features/WorldEditor/Layout")

local Clipboard = {}

local s_Layout = nil

local function Plural(count, word)
    return count == 1 and ("1 " .. word) or (count .. " " .. word .. "s")
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
        Notification.Warning("Only listed props and vehicles can be copied.")
        return false
    end

    s_Layout = layout
    local note = skipped > 0 and string.format(" Skipped %s that can't be copied.", Plural(skipped, "entity")) or ""
    Notification.Info("Copied " .. Plural(#layout.Items, "prop") .. "." .. note)
    return true
end

function Clipboard.Copy()
    return Clipboard.CopyItems(Selection.GetAll())
end

function Clipboard.Cut()
    local items = Layout.WithChildren(Selection.GetAll())
    if not Clipboard.CopyItems(items) then return end
    local kept = 0
    for _, item in ipairs(items) do
        if not PropSpawner.Delete(item.Entity) then kept = kept + 1 end
    end
    Selection.Clear()
    if kept > 0 then Notification.Info("Map entities were copied and left in place.") end
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

function Clipboard.Paste()
    if not s_Layout then
        Notification.Warning("Nothing copied yet. Select props and press Ctrl+C.")
        return
    end
    local target = Layout.Target()
    if not target then return end

    local spawned = Layout.Spawn(s_Layout, Layout.OffsetTo(s_Layout, target), { OnDone = Layout.SelectRoot })
    if spawned == 0 then
        Notification.Error("Couldn't paste those props.")
        return
    end
    Notification.Info("Pasted " .. Plural(spawned, "prop") .. ".")
end

return Clipboard
