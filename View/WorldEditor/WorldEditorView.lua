local Buttons = require("UI/Options/Buttons")
local Input = require("Core/Input")
local Submenu = require("UI/Navigation/Submenu")
local Notification = require("UI/Panels/Notification/Notification")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local WorldEditor = require("Features/WorldEditor")

local FreeCam = WorldEditor.FreeCam
local Inspector = WorldEditor.Inspector
local Hud = WorldEditor.Hud
local Picker = WorldEditor.Picker
local Selection = WorldEditor.Selection
local Grab = WorldEditor.Grab
local PropSpawner = WorldEditor.PropSpawner
local Grabbables = WorldEditor.Grabbables
local Attachments = WorldEditor.Attachments
local Scene = WorldEditor.Scene
local Layout = WorldEditor.Layout
local Clipboard = WorldEditor.Clipboard
local Saves = WorldEditor.Saves
local Entities = require("Utils/Entities")
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")
local PropCatalog = require("Features/WorldEditor/PropCatalog")

local POSITION_WINDOW = 10

local s_Search = { value = "" }
local s_SearchResults = {}
local s_ListViews = {}
local s_CategoryViews = {}
local s_EditMenus = {}
local s_ChildMenus = {}
local s_EntitySaveName = { value = "", capturing = false }
local s_SaveName = { value = "", capturing = false }
local s_SaveFocus = nil

local s_Edit = {
    X = { value = 0, min = -10, max = 10, step = 0.02, unit = "m" },
    Y = { value = 0, min = -10, max = 10, step = 0.02, unit = "m" },
    Z = { value = 0, min = -10, max = 10, step = 0.02, unit = "m" },
    Yaw = { value = 0, min = -180, max = 180, step = 1, unit = "deg" },
    Pitch = { value = 0, min = -180, max = 180, step = 1, unit = "deg" },
    Roll = { value = 0, min = -180, max = 180, step = 1, unit = "deg" }
}

local function RequireEditor(action)
    return function()
        if not WorldEditor.IsActive() then
            Notification.Warning("Open the World Editor first.")
            return
        end
        action()
    end
end

local function UniqueLabels()
    local seen = {}
    return function(label)
        seen[label] = (seen[label] or 0) + 1
        if seen[label] == 1 then return label end
        return string.format("%s (%d)", label, seen[label])
    end
end

local function CameraSettingsView()
    Buttons.Float("Move Speed", FreeCam.MoveSpeed, "Base flying speed.")
    Buttons.Float("Fast Multiplier", FreeCam.FastMultiplier, "Speed multiplier while Fast is held.")
    Buttons.Float("Slow Multiplier", FreeCam.SlowMultiplier, "Speed multiplier while Slow is held.")
    Buttons.Int("Smoothing", FreeCam.Smoothing, "How much the camera eases in and out. 0 is instant.")
    Buttons.Float("Mouse Sensitivity", FreeCam.MouseSensitivity, "How far the camera turns per mouse movement.")
    Buttons.Int("Stick Look Speed", FreeCam.StickLookSpeed, "Turn speed at full right stick.")
    Buttons.Toggle("Invert Look", FreeCam.InvertLook, "Invert up and down look.")
    Buttons.Int("Field of View", FreeCam.FieldOfView, "Editor camera field of view.")
    Buttons.Float("Blend Time", FreeCam.BlendTime, "How long the camera blends between V and the editor. 0 is instant.")
    Buttons.Toggle("Mouse Wheel Speed", FreeCam.WheelAdjustsSpeed, "Use the mouse wheel to change fly speed.")
    Buttons.Int("Stick Deadzone", FreeCam.GamepadDeadzone, "Ignore left stick movement below this value.")
end

local function MoveSettingsView()
    Buttons.Float("Hold Delay", Grab.HoldDelay, "How long to hold Select before it picks the entity up.")
    Buttons.Float("Nudge Speed", Grab.NudgeSpeed, "How fast the arrow keys slide the selection.")
    Buttons.Float("Rotate Speed", Grab.RotateSpeed, "How fast Rotate turns and tilts the selection.")
    Buttons.Toggle("Keep Facing", Grab.KeepFacing, "Turn carried entities with the camera.")
    Buttons.Toggle("Stand Peds On Ground", Grab.SnapPedsToGround, "Drop peds onto the ground when released.")
    Buttons.Toggle("Outline Selection", Selection.Highlight, "Outline the selected entity.", Selection.RefreshHighlight)
end

local function HudSettingsView()
    Buttons.Toggle("Hide Game HUD", WorldEditor.HideGameHud, "Hide the game HUD while the editor is open.")
    Buttons.Toggle("Info", Hud.ShowInfo, "Show the camera readout and the target card.")
    Buttons.Toggle("Debug", Hud.ShowDebug, "Show game time, picking mode, and distance to V.")
    Buttons.Toggle("Crosshair", Hud.ShowCrosshair, "Show the crosshair. Its color changes with the target.")
    Buttons.Toggle("Controls Bar", Hud.ShowControls, "Show control hints along the bottom.")
    Buttons.Toggle("Grab Markers", Hud.ShowGrabMarkers, "Mark the center of each spawned prop in view.")
    Buttons.Toggle("Target Box", Hud.ShowTargetBox, "Draw a box around the target.")
    Buttons.Toggle("Attachment Links", Hud.ShowAttachmentLinks, "Draw a line from each attached prop to its parent.")
    Buttons.Int("Trace Distance", Inspector.TraceDistance, "How far the crosshair trace reaches.")
    Buttons.Int("Entity Search Range", Picker.SearchRange, "How far around V fallback picking looks.")
end

local function ControlsView()
    Buttons.Bind("Open Editor", "EDITOR_TOGGLE", "Open or close the World Editor from anywhere.")

    Buttons.Break("Camera")
    Buttons.Bind("Forward", "EDITOR_FORWARD", "Fly forward.")
    Buttons.Bind("Backward", "EDITOR_BACKWARD", "Fly backward.")
    Buttons.Bind("Left", "EDITOR_LEFT", "Fly left.")
    Buttons.Bind("Right", "EDITOR_RIGHT", "Fly right.")
    Buttons.Bind("Up", "EDITOR_UP", "Fly up.")
    Buttons.Bind("Down", "EDITOR_DOWN", "Fly down.")
    Buttons.Bind("Fast", "EDITOR_FAST", "Hold to fly, nudge, and rotate faster.")
    Buttons.Bind("Slow", "EDITOR_SLOW", "Hold to fly, nudge, and rotate slower.")

    Buttons.Break("Editing")
    Buttons.Bind("Select / Carry", "EDITOR_SELECT", "Press to select. Hold to carry, release to drop.")
    Buttons.Bind("Rotate", "EDITOR_ROTATE", "Hold and move the mouse or right stick to turn and tilt the selection.")
    Buttons.Bind("Multi-Select", "EDITOR_MULTI", "Hold while selecting to add to the selection. The last one is the parent.")
    Buttons.Bind("Attach / Detach", "EDITOR_LINK", "Attach the selection to the parent, or detach a single attached prop.")
    Buttons.Bind("Ground", "EDITOR_GROUND", "Hold while carrying to stay on the ground. Tap to drop the selection onto the ground.")
    Buttons.Bind("Nudge Forward", "EDITOR_ADJUST_FORWARD", "Slide the selection away from the camera, or push a carried prop out.")
    Buttons.Bind("Nudge Backward", "EDITOR_ADJUST_BACKWARD", "Slide the selection toward the camera, or pull a carried prop in.")
    Buttons.Bind("Nudge Left", "EDITOR_ADJUST_LEFT", "Slide the selection left.")
    Buttons.Bind("Nudge Right", "EDITOR_ADJUST_RIGHT", "Slide the selection right.")

    Buttons.Break("Shortcuts")
    Buttons.Bind("Copy", "EDITOR_COPY", "Copy the selection.")
    Buttons.Bind("Cut", "EDITOR_CUT", "Copy the selection, then delete it.")
    Buttons.Bind("Paste", "EDITOR_PASTE", "Paste at the crosshair.")
    Buttons.Bind("Delete", "EDITOR_DELETE", "Delete the selected props.")
    Buttons.Bind("Detach", "EDITOR_DETACH", "Detach the selection, or everything attached to it.")
    Buttons.Bind("Undo", "EDITOR_UNDO", "Undo the last change.")
    Buttons.Bind("Redo", "EDITOR_REDO", "Redo the last undone change.")
end

local s_CameraSettingsView = Submenu.Create("Camera", CameraSettingsView)
local s_MoveSettingsView = Submenu.Create("Select & Move", MoveSettingsView)
local s_HudSettingsView = Submenu.Create("HUD", HudSettingsView)
local s_ControlsView = Submenu.Create("Controls", ControlsView)

local s_SettingsView = Submenu.Create("Settings", function()
    Buttons.Submenu("Camera", s_CameraSettingsView, "Speed, smoothing, look, and field of view.")
    Buttons.Submenu("Select & Move", s_MoveSettingsView, "Carry, nudge, and rotate settings.")
    Buttons.Submenu("HUD", s_HudSettingsView, "Choose what the editor overlay shows.")
    Buttons.Submenu("Controls", s_ControlsView, "Rebind World Editor keys.")

    Buttons.Break("Spawning")
    Buttons.Toggle("Live Preview", PropSpawner.PreviewEnabled, "Preview the hovered prop in front of the camera.")
    Buttons.Float("Preview Distance", PropSpawner.PreviewDistance, "How far in front of the camera the preview floats.")
    Buttons.Toggle("Spin Preview", PropSpawner.PreviewSpin, "Slowly spin the preview.")

    Buttons.Break("Player")
    Buttons.Toggle("Hide V", WorldEditor.HidePlayer, "Hide V while the editor is open.", WorldEditor.RefreshPlayerVisibility)
    Buttons.Toggle("Bring V Along", WorldEditor.KeepPlayerNear, "Move V behind the camera when it flies far away, so the world keeps loading.")
    Buttons.Int("Bring Along Distance", WorldEditor.FollowDistance, "How far the camera can get from V before V follows.")
end)

local function PropSize(bounds)
    if not bounds or not bounds.Native then return nil end
    return string.format("%.2f x %.2f x %.2f m", bounds.Max.x - bounds.Min.x, bounds.Max.y - bounds.Min.y, bounds.Max.z - bounds.Min.z)
end

local function ClassName(entity)
    if not entity then return nil end
    local ok, name = pcall(function() return Game.NameToString(entity:GetClassName()) end)
    return ok and name or nil
end

local function PropRows(entry, entity, held, pending)
    local size = PropSize(entity and Grabbables.GetBounds(entity)) or pending
    if PropSpawner.IsMesh(entry) then
        return {
            { Label = "Group", Value = entry.Group },
            { Label = "Type", Value = PropSpawner.CanSpawnMeshes() and "Mesh" or "Mesh, needs EasyTrainerUtility update" },
            { Label = "Size", Value = size },
            { Label = "Collision", Value = "Editor box" }
        }
    end

    local physics = held and (#held.Bodies > 0 and "Dynamic" or "Static")
    return {
        { Label = "Group", Value = entry.Group },
        { Label = "Type", Value = ClassName(entity) or pending },
        { Label = "Size", Value = size },
        { Label = "Physics", Value = physics or pending }
    }
end

local function SubmitPropInfo(entry)
    local entity, held = PropSpawner.GetPreviewEntity(entry)
    local pending = PropSpawner.PreviewEnabled.value and "Loading" or "Live Preview is off"

    SidePanel.SubmitInfo("prop-record", {
        Eyebrow = string.upper(entry.Category),
        Title = entry.Name,
        Rows = PropRows(entry, entity, held, pending),
        Description = entry.Path
    }, { Width = 330 })
end

local function PropOption(entry)
    local _, data = Buttons.Option(entry.Name, "Place this prop in front of the camera.", function()
        if PropSpawner.Place(entry) then Notification.Info("Placed " .. entry.Name .. ".") end
    end)
    if data and data.Visible and (data.Selected or data.Hovered) then
        PropSpawner.Preview(entry)
        SubmitPropInfo(entry)
    end
end

local function GroupSubmenu(category, group)
    local key = category.Name .. "/" .. group.Name
    if not s_ListViews[key] then
        s_ListViews[key] = Submenu.Create(group.Name, function()
            PropSpawner.Browse()
            for _, entry in ipairs(group.Props) do PropOption(entry) end
        end)
    end
    return s_ListViews[key]
end

local function CategorySubmenu(category)
    if not s_CategoryViews[category.Name] then
        s_CategoryViews[category.Name] = Submenu.Create(category.Name, function()
            if #category.Groups == 1 then
                PropSpawner.Browse()
                for _, entry in ipairs(category.Groups[1].Props) do PropOption(entry) end
                return
            end
            for _, group in ipairs(category.Groups) do
                Buttons.Submenu(group.Name, GroupSubmenu(category, group), string.format("%d props.", #group.Props))
            end
        end)
    end
    return s_CategoryViews[category.Name]
end

local s_SearchView = Submenu.Create("Search Results", function()
    PropSpawner.Browse()
    if #s_SearchResults == 0 then
        Buttons.OptionExtended("No matching props.", "", s_Search.value, "Try a shorter search.")
        return
    end
    for _, entry in ipairs(s_SearchResults) do PropOption(entry) end
end)

local s_SpawnPropsView = Submenu.Create("Spawn Props", function()
    Buttons.Text("Search Props", s_Search, "Search props by name, like chair, barrel, or neon.", function(text)
        s_SearchResults = PropCatalog.Search(text)
    end)
    Buttons.Submenu(string.format("Search Results (%d)", #s_SearchResults), s_SearchView, "Props matching the search.")

    Buttons.Break(string.format("Categories (%d)", PropCatalog.Count()))
    for _, category in ipairs(PropCatalog.GetCategories()) do
        Buttons.Submenu(category.Name, CategorySubmenu(category), string.format("%d props.", category.Count))
    end
end)

local function SetAngles(angles)
    s_Edit.Yaw.value = angles and angles.yaw or 0
    s_Edit.Pitch.value = angles and angles.pitch or 0
    s_Edit.Roll.value = angles and angles.roll or 0
end

local function SetAxis(ref, value, window)
    ref.value = value
    if window then
        ref.min, ref.max = value - window, value + window
    else
        ref.min, ref.max = -POSITION_WINDOW, POSITION_WINDOW
    end
end

local function EditedOrientation()
    return EulerAngles.new(s_Edit.Roll.value, s_Edit.Pitch.value, s_Edit.Yaw.value):ToQuat()
end

local function SyncLocal(entity)
    local position, rotation = Attachments.GetLocal(entity)
    if not position then return false end
    SetAxis(s_Edit.X, position.x)
    SetAxis(s_Edit.Y, position.y)
    SetAxis(s_Edit.Z, position.z)
    local ok, angles = pcall(function() return Rotation.ToQuaternion(rotation):ToEulerAngles() end)
    SetAngles(ok and angles or nil)
    return true
end

local function SyncWorld(entity)
    local ok, position = pcall(function() return entity:GetWorldPosition() end)
    if not ok or not position then return false end
    SetAxis(s_Edit.X, position.x, POSITION_WINDOW)
    SetAxis(s_Edit.Y, position.y, POSITION_WINDOW)
    SetAxis(s_Edit.Z, position.z, POSITION_WINDOW)
    local okAngles, angles = pcall(function() return entity:GetWorldOrientation():ToEulerAngles() end)
    SetAngles(okAngles and angles or nil)
    return true
end

local function ApplyLocal(entity)
    Scene.Touch(entity)
    Attachments.SetLocal(entity, { x = s_Edit.X.value, y = s_Edit.Y.value, z = s_Edit.Z.value }, Rotation.FromQuaternion(EditedOrientation()))
end

local function ApplyWorld(entity)
    Scene.Touch(entity)
    Physics.Place(entity, Vector4.new(s_Edit.X.value, s_Edit.Y.value, s_Edit.Z.value, 1.0), EditedOrientation())
end

local function TransformOptions(entity, attached)
    local apply = attached and function() ApplyLocal(entity) end or function() ApplyWorld(entity) end
    if attached then
        Buttons.Float("Offset X", s_Edit.X, "Move it left or right relative to the parent.", apply)
        Buttons.Float("Offset Y", s_Edit.Y, "Move it forward or backward relative to the parent.", apply)
        Buttons.Float("Offset Z", s_Edit.Z, "Move it up or down relative to the parent.", apply)
    else
        Buttons.Float("Position X", s_Edit.X, "Move it along the world X axis.", apply)
        Buttons.Float("Position Y", s_Edit.Y, "Move it along the world Y axis.", apply)
        Buttons.Float("Position Z", s_Edit.Z, "Move it up or down.", apply)
    end

    Buttons.Break("Rotation")
    Buttons.Float("Pitch", s_Edit.Pitch, "Rotate it around its side-to-side axis.", apply)
    Buttons.Float("Roll", s_Edit.Roll, "Rotate it around its front-to-back axis.", apply)
    Buttons.Float("Yaw", s_Edit.Yaw, "Rotate it around its vertical axis.", apply)
end

local EntityView
local ChildrenView

local function EditMenu(depth)
    if not s_EditMenus[depth] then
        s_EditMenus[depth] = Submenu.Create("Edit", function() EntityView(depth) end)
    end
    return s_EditMenus[depth]
end

local function ChildMenu(depth)
    if not s_ChildMenus[depth] then
        s_ChildMenus[depth] = Submenu.Create("Attached Props", function() ChildrenView(depth) end)
    end
    return s_ChildMenus[depth]
end

local function OpenEntity(depth, entity, name)
    Scene.SetFocus(depth, entity, name)
    EditMenu(depth).Title = name
    Selection.Select({ Entity = entity, DisplayName = name, Kind = Physics.Classify(entity) })
end

local function Indent(depth)
    if depth == 0 then return "" end
    return string.rep("    ", depth - 1) .. "  - "
end

local function EntityRow(depth, entity, name, label)
    Buttons.Submenu(label, EditMenu(depth), "Edit, copy, or save it.", function()
        OpenEntity(depth, entity, name)
    end)
end

local function Children(entity)
    local hash = Entities.Hash(entity)
    local children = {}
    for _, link in ipairs(Attachments.GetEntries()) do
        if link.ParentHash == hash then table.insert(children, link) end
    end
    return children
end

local function SaveItems(name, items)
    local save, skipped = Saves.Save(name, items)
    if not save then
        Notification.Warning("Nothing here can be saved. Only listed props and vehicles can.")
        return
    end
    local note = skipped > 0 and string.format(" Skipped %d.", skipped) or ""
    Notification.Success(string.format("Saved %s (%d props).%s", save.Name, Saves.Count(save), note))
end

local function Duplicate(depth, focus, mode)
    local original = focus.Entity
    local started = Layout.Duplicate(original, focus.Name, mode, function(records)
        local copy = records[1]
        if not copy or not copy.Entity then return end
        local current = Scene.GetFocus(depth)
        if current and Entities.Same(current.Entity, original) then
            OpenEntity(depth, copy.Entity, copy.Entry.Name)
            Notification.Info("Copied " .. focus.Name .. ". Now editing the copy.")
        else
            Notification.Info("Copied " .. focus.Name .. ".")
        end
    end)
    if not started then Notification.Warning(focus.Name .. " can't be copied. Only listed props and vehicles can.") end
end

local function DeleteFocus(depth, focus)
    if PropSpawner.Delete(focus.Entity) then
        Notification.Info("Deleted " .. focus.Name .. ".")
    elseif Scene.Remove(focus.Entity) then
        Notification.Info("Removed " .. focus.Name .. " from the scene.")
    end
    Scene.SetFocus(depth, nil)
end

ChildrenView = function(depth)
    local focus = Scene.GetFocus(depth)
    local children = focus and Children(focus.Entity) or {}
    if #children == 0 then
        Buttons.OptionExtended("No props are attached.", "", "", "Attach something to it first.")
        return
    end
    local label = UniqueLabels()
    for _, child in ipairs(children) do EntityRow(depth + 1, child.Child, child.Name, label(child.Name)) end
end

EntityView = function(depth)
    local focus = Scene.GetFocus(depth)
    if not focus then
        Buttons.OptionExtended("This entity is no longer available.", "", "", "Go back to the scene.")
        return
    end

    local entity = focus.Entity
    local link = Attachments.Get(entity)
    local children = #Children(entity)
    EditMenu(depth).Title = focus.Name

    if link then
        Buttons.Submenu("Attached To " .. link.ParentName, EditMenu(depth + 1), "Open the parent.", function()
            OpenEntity(depth + 1, link.Parent, link.ParentName)
        end)
    end
    if children > 0 then
        Buttons.Submenu(string.format("Attached Props (%d)", children), ChildMenu(depth), "Props attached to this one.")
    end
    if link or children > 0 then Buttons.Break(link and "Offset" or "Position") end

    if link then SyncLocal(entity) else SyncWorld(entity) end
    TransformOptions(entity, link ~= nil)

    Buttons.Break("Copy")
    if link then
        Buttons.Option("Copy To Parent", "Copy it onto the same parent, then edit the copy.", function() Duplicate(depth, focus, "Parent") end)
    else
        Buttons.Option("Duplicate", "Copy it in place, then edit the copy.", function() Duplicate(depth, focus) end)
    end
    Buttons.Option("Copy As Child", "Copy it and attach the copy to this one, then edit the copy.", function() Duplicate(depth, focus, "Child") end)
    Buttons.Option("Copy To Clipboard", "Copy it and its attachments for Paste.", function() Clipboard.CopyItems({ focus }) end)

    Buttons.Break("Save")
    Buttons.Text("Save As", s_EntitySaveName, "Save it and its attachments to Saved Scenes.", function(value)
        SaveItems(value, { focus })
        s_EntitySaveName.value = ""
    end)

    Buttons.Break()
    if link then
        Buttons.Option("Detach", "Detach it and leave it where it is.", function()
            if Attachments.Detach(entity) then Notification.Info("Detached " .. focus.Name .. ".") end
        end)
    end
    if PropSpawner.IsPlaced(entity) then
        Buttons.Option("Delete", "Delete this prop.", function() DeleteFocus(depth, focus) end)
    else
        Buttons.Option("Remove From Scene", "Remove it from the scene. It stays in the world.", function() DeleteFocus(depth, focus) end)
    end
end

local function SceneRows(entries)
    local byHash, rows, seen = {}, {}, {}
    for _, entry in ipairs(entries) do
        local hash = Entities.Hash(entry.Entity)
        if hash then byHash[hash] = entry end
    end

    local function Add(entity, name, depth)
        local hash = Entities.Hash(entity)
        if not hash or seen[hash] then return end
        seen[hash] = true
        local known = byHash[hash]
        table.insert(rows, { Entity = entity, Name = known and known.Name or name, Depth = depth })
        for _, link in ipairs(Attachments.GetEntries()) do
            if link.ParentHash == hash then Add(link.Child, link.Name, depth + 1) end
        end
    end

    for _, entry in ipairs(entries) do
        local link = Attachments.Get(entry.Entity)
        if not link or not byHash[link.ParentHash] then Add(entry.Entity, entry.Name, 0) end
    end
    return rows
end

local s_SceneView = Submenu.Create("Scene", function()
    local rows = SceneRows(Scene.GetAll())
    if #rows == 0 then
        Buttons.OptionExtended("Nothing is in the scene yet.", "", "", "Spawn a prop or move something in the world to add it.")
        return
    end

    local label = UniqueLabels()
    for _, row in ipairs(rows) do EntityRow(1, row.Entity, row.Name, label(Indent(row.Depth) .. row.Name)) end

    Buttons.Break("Cleanup")
    Buttons.Option("Detach All", "Detach every attached prop.", function()
        Notification.Info(string.format("Detached %d props.", Attachments.DetachAll()))
    end)
    Buttons.Option("Delete All Placed", "Delete every placed prop.", function()
        Notification.Info(string.format("Deleted %d props.", PropSpawner.DeleteAll()))
    end)
end)

local function AddSelectionToScene()
    local added = 0
    for _, selected in ipairs(Selection.GetAll()) do
        if Scene.Add(selected.Entity, selected.Name, selected.Kind) then added = added + 1 end
    end
    if added == 0 then Notification.Warning("Nothing new to add.") end
end

local s_SelectionView = Submenu.Create("Selection", function()
    Buttons.Option("Attach", "Attach the selection to the parent, the last one picked.", WorldEditor.LinkSelection)
    Buttons.Option("Detach", "Detach the selection, or everything attached to it.", WorldEditor.DetachSelection)
    Buttons.Option("Copy", "Copy the selection and its attachments.", Clipboard.Copy)
    Buttons.Option("Cut", "Copy the selection, then delete it.", Clipboard.Cut)
    Buttons.Option(string.format("Paste (%d)", Clipboard.Count()), "Paste at the crosshair, or in front of V with the editor closed.", Clipboard.Paste)
    Buttons.Option("Delete", "Delete the selected props. Map entities are left alone.", Clipboard.DeleteSelection)
    Buttons.Option("Add To Scene", "Add the selection to the scene.", AddSelectionToScene)
    Buttons.Option("Clear Selection", "Deselect everything.", Selection.Clear)

    local selected = Selection.GetAll()
    Buttons.Break(string.format("Selected (%d)", #selected))
    if #selected == 0 then
        Buttons.OptionExtended("Nothing is selected.", "", "", "Select something in the editor or pick it from Scene.")
        return
    end
    local label = UniqueLabels()
    local pick = Input.IsController() and "Hold B and press RT on a parent to attach it." or "Ctrl+click a parent to attach it."
    local tip = #selected > 1 and "Attach puts this onto the parent." or pick
    for index, entry in ipairs(selected) do
        local parent = #selected > 1 and index == #selected
        Buttons.OptionExtended(label(entry.Name), "", parent and "PARENT" or "", parent and "Attach puts the others onto this one." or tip)
    end
end)

local function LoadSave(save, here)
    local spawned = Saves.Load(save, here)
    if spawned == 0 then
        Notification.Error("Couldn't load " .. save.Name .. ".")
        return
    end
    Notification.Info(string.format("Loading %s (%d props).", save.Name, spawned))
end

local s_SaveView = Submenu.Create("Saved Scene", function()
    local save = s_SaveFocus
    if not save then
        Buttons.OptionExtended("This save was deleted.", "", "", "Go back to Saved Scenes.")
        return
    end

    Buttons.Option("Load", "Spawn it where it was saved.", function() LoadSave(save, false) end)
    Buttons.Option("Load Here", "Spawn it at the crosshair, or in front of V with the editor closed.", function() LoadSave(save, true) end)
    Buttons.OptionExtended("Props", "", tostring(Saves.Count(save)), "Props and vehicles in this save.")

    Buttons.Break()
    Buttons.Option("Delete Save", "Delete this save. Spawned props stay.", function()
        if Saves.Delete(save) then Notification.Info("Deleted " .. save.Name .. ".") end
        s_SaveFocus = nil
    end)
end)

local s_SavesView = Submenu.Create("Saved Scenes", function()
    Buttons.Text("Save Scene As", s_SaveName, "Save the whole scene. An existing name gets replaced.", function(value)
        SaveItems(value, Scene.GetAll())
        s_SaveName.value = ""
    end)

    local saves = Saves.List()
    if #saves == 0 then return end
    local label = UniqueLabels()
    Buttons.Break(string.format("Saves (%d)", #saves))
    for _, save in ipairs(saves) do
        local name = tostring(save.Name)
        Buttons.Submenu(label(name), s_SaveView, string.format("%d props.", Saves.Count(save)), function()
            s_SaveFocus = save
            s_SaveView.Title = name
        end)
    end
end)

local HOW_TO = {
    {
        "Fly",
        Keyboard = "WASD to move, E and Q for up and down. Shift is fast, Alt is slow, and the wheel sets speed.",
        Controller = "Left stick to move and right stick to look. RB and LB for up and down. L3 is fast and R3 is slow."
    },
    { "Spawn", All = "Hover a prop in Spawn Props to preview it. Select it to place it." },
    { "Select", Keyboard = "Click anything to select it.", Controller = "Aim at anything and press RT to select it." },
    {
        "Carry",
        Keyboard = "Hold click to carry. The wheel sets distance and Space keeps it on the ground.",
        Controller = "Hold RT to carry. D-pad up and down set distance and holding X keeps it on the ground."
    },
    { "Ground", Controller = "Tap X to drop the selection onto the ground." },
    { "Rotate", Keyboard = "Hold right click and move the mouse to turn and tilt.", Controller = "Hold LT and move the right stick to turn and tilt." },
    { "Nudge", Keyboard = "With the menu closed, the arrow keys slide the selection.", Controller = "With the menu closed, the D-pad slides the selection." },
    {
        "Attach",
        Keyboard = "Click a prop, Ctrl+click its parent, then press Enter with the menu closed.",
        Controller = "Select a prop, hold B and press RT on its parent, then press Y with the menu closed."
    },
    {
        "Detach",
        Keyboard = "Select an attached prop and press Backspace. On a parent, Backspace detaches everything on it.",
        Controller = "Select an attached prop and press Y with the menu closed."
    },
    { "Scene", All = "Pick anything in Scene to edit it from the menu, even with the editor closed." },
    { "Copies", All = "Copy To Parent copies a prop onto the same parent. Copy As Child attaches the copy to the prop." },
    { "Map Entities", All = "Cars and props already in the world join the scene when you move or attach them." },
    {
        "Copy And Paste",
        Keyboard = "Ctrl+C, Ctrl+X, and Ctrl+V copy, cut, and paste. Delete removes the selection.",
        Controller = "Copy, cut, paste, and delete from the Selection menu."
    },
    { "Save", All = "Save the scene from Saved Scenes, or one prop and its attachments with Save As." },
    { "Undo", Keyboard = "Ctrl+Z to undo and Ctrl+Y to redo.", Controller = "Undo and Redo are on the World Editor page." }
}

local s_HowToView = Submenu.Create("How To", function()
    local device = Input.IsController() and "Controller" or "Keyboard"
    for _, line in ipairs(HOW_TO) do
        local text = line.All or line[device]
        if text then Buttons.OptionExtended(line[1], "", "", text) end
    end
end)

local function WorldEditorView()
    Buttons.Toggle("World Editor", WorldEditor.Enabled, "Fly a free camera and edit the world. Player controls are blocked while it's open.")
    Buttons.Submenu("Spawn Props", s_SpawnPropsView, "Browse and place props.")
    Buttons.Submenu(string.format("Scene (%d)", Scene.Count()), s_SceneView, "Edit, copy, or save what you placed or moved.")
    Buttons.Submenu(string.format("Selection (%d)", Selection.Count()), s_SelectionView, "Attach, copy, paste, or delete the selection.")
    Buttons.Submenu("Saved Scenes", s_SavesView, "Save and load scenes.")

    Buttons.Break()
    Buttons.Option("Undo", "Undo the last change.", WorldEditor.History.Undo)
    Buttons.Option("Redo", "Redo the last undone change.", WorldEditor.History.Redo)
    Buttons.Option("Reset Camera", "Move the camera back to V.", RequireEditor(WorldEditor.ResetCamera))
    Buttons.Option("Move V Here", "Move V behind the camera.", RequireEditor(WorldEditor.TeleportPlayerToCamera))

    Buttons.Break()
    Buttons.Submenu("Settings", s_SettingsView, "Camera, movement, spawning, HUD, and controls.")
    Buttons.Submenu("How To", s_HowToView, "How every editor control works.")
end

return Submenu.Create("World Editor", WorldEditorView)
