local Notify = require("Utils/Notify")
local Entities = require("Features/WorldEditor/Entities")
local Physics = require("Features/WorldEditor/Physics")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Layout = require("Features/WorldEditor/Layout")
local Clipboard = require("Features/WorldEditor/Clipboard")
local Saves = require("Features/WorldEditor/Saves")

local Editing = {}

local function Count(key, count)
    return tip(key .. (count == 1 and ".one" or ".many"), { count = count })
end

function Editing.Attach(children, parent)
    local attached, lastName, lastChild, lastReason, loose = 0, nil, nil, nil, nil
    for _, child in ipairs(children) do
        Attachments.Detach(child.Entity)
        local taken = Layout.TakeOnto(child, parent, function(copy)
            if copy then
                Scene.Remove(child.Entity)
            else
                Notify.Warning(tip("notify.worldeditor.attach.copyfailed", { name = child.Name }))
            end
        end)

        if taken then
            attached, lastName = attached + 1, child.Name
        else
            local ok, reason = Attachments.Attach(child.Entity, parent.Entity, { Name = child.Name, Kind = child.Kind, ParentName = parent.Name })
            if ok then
                attached, lastName, lastChild = attached + 1, child.Name, child
                Scene.Add(child.Entity, child.Name, child.Kind)
                if taken == false then loose = child end
            else
                lastReason = reason
            end
        end
    end

    if attached == 0 then
        Notify.Warning(lastReason or L("notify.worldeditor.link.failed"))
        return 0, nil
    end
    Scene.Add(parent.Entity, parent.Name, parent.Kind)
    local child = attached == 1 and lastName or tip("notify.worldeditor.link.props", { count = attached })
    Notify.Success(tip("notify.worldeditor.link.attached", { child = child, parent = parent.Name }))
    if loose then Notify.Warning(tip("notify.worldeditor.attach.mapprop", { name = loose.Name })) end
    return attached, lastChild
end

function Editing.Detach(item)
    if Attachments.Detach(item.Entity) then
        Notify.Info(tip("notify.worldeditor.link.detached", { name = item.Name }))
        return true
    end
    return false
end

function Editing.DetachChildren(item)
    local detached = Attachments.DetachChildrenOf(item.Entity)
    if detached > 0 then Notify.Info(Count("notify.worldeditor.detach.done", detached)) end
    return detached
end

function Editing.Select(entity, name)
    if not Entities.IsValid(entity) then return end
    Selection.Select({ Entity = entity, DisplayName = name, Kind = Physics.Classify(entity) })
end

function Editing.Open(depth, entity, name)
    Scene.SetFocus(depth, entity, name)
    Editing.Select(entity, name)
end

function Editing.Place(entry)
    if PropSpawner.Place(entry) then Notify.Success(tip("notify.worldeditor.placed", { name = entry.Name })) end
end

function Editing.ApplyPose(depth, pose)
    Scene.ApplyPose(depth, pose)
end

function Editing.Duplicate(depth, mode)
    local focus = Scene.GetFocus(depth)
    if not focus then return end

    local original = focus.Entity
    local started = Layout.Duplicate(original, focus.Name, mode, function(records)
        local copy = records[1]
        if not copy or not copy.Entity then return end
        local current = Scene.GetFocus(depth)
        if current and Entities.Same(current.Entity, original) then
            Editing.Open(depth, copy.Entity, copy.Entry.Name)
            Notify.Success(tip("notify.worldeditor.scene.copiedediting", { name = focus.Name }))
        else
            Notify.Success(tip("notify.worldeditor.scene.copied", { name = focus.Name }))
        end
    end)
    if not started then Notify.Warning(tip("notify.worldeditor.scene.cantcopy", { name = focus.Name })) end
end

function Editing.CopyFocus(depth)
    local focus = Scene.GetFocus(depth)
    if focus then Clipboard.CopyItems({ focus }) end
end

function Editing.DetachFocus(depth)
    local focus = Scene.GetFocus(depth)
    if focus and Attachments.Detach(focus.Entity) then Notify.Info(tip("notify.worldeditor.scene.detached", { name = focus.Name })) end
end

function Editing.DeleteFocus(depth)
    local focus = Scene.GetFocus(depth)
    if not focus then return end
    if PropSpawner.Delete(focus.Entity) then
        Notify.Success(tip("notify.worldeditor.scene.deleted", { name = focus.Name }))
    elseif Scene.Remove(focus.Entity) then
        Notify.Info(tip("notify.worldeditor.scene.removed", { name = focus.Name }))
    end
    Scene.SetFocus(depth, nil)
end

function Editing.DetachAll()
    Notify.Info(Count("notify.worldeditor.scene.detachedall", Attachments.DetachAll()))
end

function Editing.DeleteAll()
    Notify.Info(Count("notify.worldeditor.scene.deletedall", PropSpawner.DeleteAll()))
end

function Editing.AddSelectionToScene()
    local added = 0
    for _, selected in ipairs(Selection.GetAll()) do
        if Scene.Add(selected.Entity, selected.Name, selected.Kind) then added = added + 1 end
    end
    if added == 0 then
        Notify.Warning(L("notify.worldeditor.scene.nothingnew"))
        return
    end
    Notify.Success(Count("notify.worldeditor.scene.added", added))
end

function Editing.Save(name, items)
    local save, skipped, failed = Saves.Save(name, items)
    if failed then
        Notify.Error(L("notify.worldeditor.saves.writefailed"))
        return
    end
    if not save then
        Notify.Warning(L("notify.worldeditor.saves.nothing"))
        return
    end
    local text = tip("notify.worldeditor.saves.saved", { name = save.Name, count = Saves.Count(save) })
    if skipped > 0 then text = text .. " " .. tip("notify.worldeditor.saves.skipped", { count = skipped }) end
    Notify.Success(text)
end

function Editing.SaveScene(name)
    Editing.Save(name, Scene.GetAll())
end

function Editing.SaveFocus(depth, name)
    local focus = Scene.GetFocus(depth)
    if focus then Editing.Save(name, { focus }) end
end

function Editing.Load(save, here)
    local spawned = Saves.Load(save, here)
    if spawned == 0 then
        Notify.Error(tip("notify.worldeditor.saves.loadfailed", { name = tostring(save.Name) }))
        return
    end
    Notify.Success(tip("notify.worldeditor.saves.loading", { name = tostring(save.Name), count = spawned }))
end

function Editing.DeleteSave(save)
    if Saves.Delete(save) then
        Notify.Success(tip("notify.worldeditor.saves.deleted", { name = tostring(save.Name) }))
        return
    end
    Notify.Error(L("notify.worldeditor.saves.writefailed"))
end

return Editing
