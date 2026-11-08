local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local Scene = require("Features/WorldEditor/Scene")
local Attachments = require("Features/WorldEditor/Attachments")
local Editing = require("Features/WorldEditor/Editing")

local SceneView = {}

local POSITION_WINDOW = 10
local POSITION_STEP = 0.02
local MAX_NAME = 40
local AXES = { "X", "Y", "Z" }
local AXIS_KEYS = {
    Local = { X = "worldeditor.edit.offsetx", Y = "worldeditor.edit.offsety", Z = "worldeditor.edit.offsetz" },
    World = { X = "worldeditor.edit.positionx", Y = "worldeditor.edit.positiony", Z = "worldeditor.edit.positionz" }
}
local ANGLES = {
    { Field = "Pitch", Key = "worldeditor.edit.pitch" },
    { Field = "Roll", Key = "worldeditor.edit.roll" },
    { Field = "Yaw", Key = "worldeditor.edit.yaw" }
}

local s_Edit = { X = 0, Y = 0, Z = 0, Yaw = 0, Pitch = 0, Roll = 0 }
local s_EditRefs = {}
for key in pairs(s_Edit) do s_EditRefs[key] = Ref.Field(s_Edit, key) end

local s_Names = { Entity = "" }
local s_EntityName = Ref.Field(s_Names, "Entity")
local s_EditMenus = {}
local s_ChildMenus = {}

local EntityView
local ChildrenView

local function Pressed(key)
    local pressed = Widgets.Button(L(key .. ".label"))
    Widgets.Tip(L(key .. ".tip"))
    return pressed
end

local function UniqueLabels()
    local seen = {}
    return function(label)
        seen[label] = (seen[label] or 0) + 1
        if seen[label] == 1 then return label end
        return string.format("%s (%d)", label, seen[label])
    end
end

local function Indent(depth)
    if depth == 0 then return "" end
    return string.rep("    ", depth - 1) .. "  - "
end

local function EditMenu(depth)
    if not s_EditMenus[depth] then
        s_EditMenus[depth] = Submenu.Create("worldeditor.edit.title", function() EntityView(depth) end)
    end
    return s_EditMenus[depth]
end

local function ChildMenu(depth)
    if not s_ChildMenus[depth] then
        s_ChildMenus[depth] = Submenu.Create("worldeditor.edit.attachedprops.label", function() ChildrenView(depth) end)
    end
    return s_ChildMenus[depth]
end

local function Open(depth, entity, name, hash)
    Scene.SetFocus(depth, entity, name, hash)
    EditMenu(depth).Title = name
    WorldEditor.Run(function() Editing.Select(entity, name) end)
end

local function EntityRow(depth, entity, name, hash, label)
    if Widgets.SubmenuButton(label, EditMenu(depth)) then Open(depth, entity, name, hash) end
    Widgets.Tip(L("worldeditor.scene.row.tip"))
end

local function Empty(key)
    Widgets.ValueRow(L(key .. ".label"), "")
    Widgets.Tip(L(key .. ".tip"))
end

local function Transform(depth, pose)
    for key in pairs(s_Edit) do s_Edit[key] = pose[key] end

    local keys = pose.Local and AXIS_KEYS.Local or AXIS_KEYS.World
    local changed = false
    for _, axis in ipairs(AXES) do
        local key = keys[axis]
        local center = pose.Local and 0 or pose[axis]
        local moved = Widgets.SliderFloat(L(key .. ".label"), s_EditRefs[axis], center - POSITION_WINDOW, center + POSITION_WINDOW, POSITION_STEP, "%.2f m")
        Widgets.Tip(L(key .. ".tip"))
        changed = moved or changed
    end

    Widgets.Break(L("worldeditor.edit.rotation"))
    for _, angle in ipairs(ANGLES) do
        local turned = Widgets.SliderFloat(L(angle.Key .. ".label"), s_EditRefs[angle.Field], -180, 180, 1, "%.0f deg")
        Widgets.Tip(L(angle.Key .. ".tip"))
        changed = turned or changed
    end

    if not changed then return end
    local values = {}
    for key, value in pairs(s_Edit) do values[key] = value end
    WorldEditor.Run(function() Editing.ApplyPose(depth, values) end)
end

local function CopyRows(depth, link)
    Widgets.Break(L("worldeditor.edit.copy"))
    if link then
        if Pressed("worldeditor.edit.copytoparent") then WorldEditor.Run(function() Editing.Duplicate(depth, "Parent") end) end
    elseif Pressed("worldeditor.edit.duplicate") then
        WorldEditor.Run(function() Editing.Duplicate(depth) end)
    end
    if Pressed("worldeditor.edit.copyaschild") then WorldEditor.Run(function() Editing.Duplicate(depth, "Child") end) end
    if Pressed("worldeditor.edit.copytoclipboard") then WorldEditor.Run(function() Editing.CopyFocus(depth) end) end
end

local function SaveRow(depth)
    Widgets.Break(L("worldeditor.edit.save"))
    if Widgets.InputText(L("worldeditor.edit.saveas.label"), s_EntityName, MAX_NAME, L("worldeditor.saves.placeholder")) then
        local name = s_Names.Entity
        s_Names.Entity = ""
        WorldEditor.Run(function() Editing.SaveFocus(depth, name) end)
    end
    Widgets.Tip(L("worldeditor.edit.saveas.tip"))
end

local function RemoveRows(depth, focus, link)
    Widgets.Break("")
    if link and Pressed("worldeditor.edit.detach") then WorldEditor.Run(function() Editing.DetachFocus(depth) end) end
    if Pressed(focus.Placed and "worldeditor.edit.delete" or "worldeditor.edit.remove") then
        WorldEditor.Run(function() Editing.DeleteFocus(depth) end)
    end
end

EntityView = function(depth)
    WorldEditor.Watch()

    local focus = Scene.GetFocus(depth)
    if not focus then
        Empty("worldeditor.edit.gone")
        return
    end

    EditMenu(depth).Title = focus.Name
    local link = focus.Link
    local children = focus.Children or 0

    if link then
        if Widgets.SubmenuButton(tip("worldeditor.edit.attachedto.label", { name = link.ParentName }), EditMenu(depth + 1)) then
            Open(depth + 1, link.Parent, link.ParentName, link.ParentHash)
        end
        Widgets.Tip(L("worldeditor.edit.attachedto.tip"))
    end
    if children > 0 then
        Widgets.SubmenuButton(L("worldeditor.edit.attachedprops.label"), ChildMenu(depth), tostring(children))
        Widgets.Tip(L("worldeditor.edit.attachedprops.tip"))
    end
    if link or children > 0 then Widgets.Break(L(link and "worldeditor.edit.offset.title" or "worldeditor.edit.position.title")) end

    if not focus.Pose then
        Empty("worldeditor.edit.loading")
        return
    end

    Transform(depth, focus.Pose)
    CopyRows(depth, link)
    SaveRow(depth)
    RemoveRows(depth, focus, link)
end

ChildrenView = function(depth)
    WorldEditor.Watch()

    local focus = Scene.GetFocus(depth)
    local children = focus and Attachments.ChildrenOf(focus.Hash) or {}
    if #children == 0 then
        Empty("worldeditor.edit.nochildren")
        return
    end

    local label = UniqueLabels()
    for _, child in ipairs(children) do EntityRow(depth + 1, child.Child, child.Name, child.ChildHash, label(child.Name)) end
end

local function View()
    WorldEditor.Watch()

    local rows = Scene.Rows
    if #rows == 0 then
        Empty("worldeditor.scene.empty")
        return
    end

    local label = UniqueLabels()
    for _, row in ipairs(rows) do EntityRow(1, row.Entity, row.Name, row.Hash, label(Indent(row.Depth) .. row.Name)) end

    Widgets.Break(L("worldeditor.scene.cleanup"))
    if Pressed("worldeditor.scene.detachall") then WorldEditor.Run(Editing.DetachAll) end
    if Widgets.HoldButton(L("worldeditor.scene.deleteall.label")) then WorldEditor.Run(Editing.DeleteAll) end
    Widgets.Tip(L("worldeditor.scene.deleteall.tip"))
end

SceneView.Menu = Submenu.Create("worldeditor.scene.label", View)

return SceneView
