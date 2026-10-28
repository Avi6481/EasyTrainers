local Buttons = require("UI/Options/Buttons")
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
local Clipboard = WorldEditor.Clipboard
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")
local PropCatalog = require("Features/WorldEditor/PropCatalog")

local s_Search = { value = "" }
local s_SearchResults = {}
local s_ListViews = {}
local s_CategoryViews = {}

local function RequireEditor(action)
    return function()
        if not WorldEditor.IsActive() then
            Notification.Warning("Open the World Editor first.")
            return
        end
        action()
    end
end

local function CameraSettingsView()
    Buttons.Float("Move Speed", FreeCam.MoveSpeed, "Base flying speed of the editor camera.")
    Buttons.Float("Fast Multiplier", FreeCam.FastMultiplier, "Speed multiplier while the fast key is held.")
    Buttons.Float("Slow Multiplier", FreeCam.SlowMultiplier, "Speed multiplier while the slow key is held.")
    Buttons.Int("Smoothing", FreeCam.Smoothing, "How quickly the camera eases into and out of movement. Zero moves instantly.")
    Buttons.Float("Mouse Sensitivity", FreeCam.MouseSensitivity, "How far the camera turns for each mouse movement.")
    Buttons.Int("Stick Look Speed", FreeCam.StickLookSpeed, "How fast the right stick turns the camera at full tilt.")
    Buttons.Toggle("Invert Look", FreeCam.InvertLook, "Flip up and down for mouse and right stick look.")
    Buttons.Int("Field of View", FreeCam.FieldOfView, "Field of view of the editor camera.")
    Buttons.Float("Blend Time", FreeCam.BlendTime, "How long the view glides between V and the editor camera when it opens and closes. Zero switches instantly.")
    Buttons.Toggle("Mouse Wheel Speed", FreeCam.WheelAdjustsSpeed, "Scroll the mouse wheel to change the move speed while flying.")
    Buttons.Int("Stick Deadzone", FreeCam.GamepadDeadzone, "Ignore small left stick movement below this value.")
end

local function MoveSettingsView()
    Buttons.Float("Hold Delay", Grab.HoldDelay, "How long the button has to be held before a click turns into carrying.")
    Buttons.Float("Nudge Speed", Grab.NudgeSpeed, "How fast the nudge keys slide the selected entity. The fast and slow keys still apply.")
    Buttons.Float("Rotate Speed", Grab.RotateSpeed, "How fast entities turn and tilt while rotating. Hold the slow key for fine turns.")
    Buttons.Toggle("Keep Facing", Grab.KeepFacing, "Turn carried entities with the camera so they keep facing the same way relative to you.")
    Buttons.Toggle("Stand Peds On Ground", Grab.SnapPedsToGround, "Put dropped peds straight onto the ground instead of leaving them where they were let go.")
    Buttons.Toggle("Outline Selection", Selection.Highlight, "Draw an outline around the selected entity.", Selection.RefreshHighlight)
    Buttons.Toggle("Lead Attached Props", Attachments.LagCompensation, "Move attached props ahead by the parent's speed, so they don't trail behind fast cars.")
end

local function SpawnSettingsView()
    Buttons.Toggle("Live Preview", PropSpawner.PreviewEnabled, "Show the highlighted prop floating in front of the camera before you place it.")
    Buttons.Float("Preview Distance", PropSpawner.PreviewDistance, "How far in front of the camera the preview floats.")
    Buttons.Toggle("Spin Preview", PropSpawner.PreviewSpin, "Slowly turn the preview so you can see it from every side.")
    Buttons.Toggle("Keep Props After Reload", WorldEditor.SceneStore.KeepProps, "Save placed props and their attachments, and put them back after loading a save or reloading mods.")
end

local function PlayerSettingsView()
    Buttons.Toggle("Hide V", WorldEditor.HidePlayer, "Make V invisible while the editor is open. V comes back when it closes.", WorldEditor.RefreshPlayerVisibility)
    Buttons.Toggle("Bring V Along", WorldEditor.KeepPlayerNear, "V stays frozen where you left them by default. Turn this on to move V onto the ground behind the camera when it flies far away, so the world keeps loading around you.")
    Buttons.Int("Bring Along Distance", WorldEditor.FollowDistance, "How far the camera can get from V before V is moved behind it.")
end

local function HudSettingsView()
    Buttons.Toggle("Hide Game HUD", WorldEditor.HideGameHud, "Hide the game's own HUD while the editor is open.")
    Buttons.Toggle("Info", Hud.ShowInfo, "Show the camera readout in the top left and the target card in the bottom right.")
    Buttons.Toggle("Debug", Hud.ShowDebug, "Show frame rate, game time, picking mode, and camera status in the top right.")
    Buttons.Toggle("Crosshair", Hud.ShowCrosshair, "Show the center crosshair. It changes color with what it is pointing at.")
    Buttons.Toggle("Controls Bar", Hud.ShowControls, "Show the control hints along the bottom of the screen.")
    Buttons.Toggle("Grab Markers", Hud.ShowGrabMarkers, "Mark the center of every spawned prop in view, so you can see where to aim to grab it.")
    Buttons.Toggle("Target Box", Hud.ShowTargetBox, "Draw a box around whatever the crosshair is on.")
    Buttons.Toggle("Attachment Links", Hud.ShowAttachmentLinks, "Draw a line from each attached prop to what it is attached to.")
    Buttons.Int("Trace Distance", Inspector.TraceDistance, "How far the cursor trace reaches from the camera.")
    Buttons.Int("Entity Search Range", Picker.SearchRange, "How far around V the fallback picking looks for peds, vehicles, devices, and props.")
end

local function ControlsView()
    Buttons.Bind("Open Editor", "EDITOR_TOGGLE", "Key or button that opens and closes the World Editor from anywhere.")

    Buttons.Break("Camera")
    Buttons.Bind("Forward", "EDITOR_FORWARD", "Key used to fly the camera forward.")
    Buttons.Bind("Backward", "EDITOR_BACKWARD", "Key used to fly the camera backward.")
    Buttons.Bind("Left", "EDITOR_LEFT", "Key used to fly the camera left.")
    Buttons.Bind("Right", "EDITOR_RIGHT", "Key used to fly the camera right.")
    Buttons.Bind("Up", "EDITOR_UP", "Keyboard or controller control used to fly straight up.")
    Buttons.Bind("Down", "EDITOR_DOWN", "Keyboard or controller control used to fly straight down.")
    Buttons.Bind("Fast", "EDITOR_FAST", "Hold to fly, nudge, and rotate faster.")
    Buttons.Bind("Slow", "EDITOR_SLOW", "Hold to fly, nudge, and rotate slower for precise placement.")

    Buttons.Break("Moving Things")
    Buttons.Bind("Select / Carry", "EDITOR_SELECT", "Click an entity to select it. Hold to pick it up and carry it, then release to drop it.")
    Buttons.Bind("Rotate", "EDITOR_ROTATE", "Hold and move the mouse or right stick. Left and right turns the entity, up and down tips it forward and back.")
    Buttons.Bind("Multi-Select", "EDITOR_MULTI", "Hold while clicking to add or remove entities from the selection. The last one you add is the parent.")
    Buttons.Bind("Attach / Detach", "EDITOR_LINK", "Attach the green selected entities to the orange parent. With one attached prop selected, detach it. Works while the trainer menu is closed.")
    Buttons.Bind("Copy", "EDITOR_COPY", "Copy the selected props you placed. Works while the trainer menu is closed.")
    Buttons.Bind("Cut", "EDITOR_CUT", "Copy the selected props you placed, then delete them. Works while the trainer menu is closed.")
    Buttons.Bind("Paste", "EDITOR_PASTE", "Place the copied props where the crosshair is pointing. Works while the trainer menu is closed.")
    Buttons.Bind("Delete", "EDITOR_DELETE", "Delete the selected props you placed. Works while the trainer menu is closed.")
    Buttons.Bind("Ground", "EDITOR_GROUND", "Hold while carrying to keep the entity on the ground. Tap with something selected to drop it onto the ground.")
    Buttons.Bind("Nudge Forward", "EDITOR_ADJUST_FORWARD", "Slide the selected entity away from the camera. Works while the trainer menu is closed.")
    Buttons.Bind("Nudge Backward", "EDITOR_ADJUST_BACKWARD", "Slide the selected entity toward the camera. Works while the trainer menu is closed.")
    Buttons.Bind("Nudge Left", "EDITOR_ADJUST_LEFT", "Slide the selected entity to the left. Works while the trainer menu is closed.")
    Buttons.Bind("Nudge Right", "EDITOR_ADJUST_RIGHT", "Slide the selected entity to the right. Works while the trainer menu is closed.")
end

local s_CameraSettingsView = Submenu.Create("Camera", CameraSettingsView)
local s_MoveSettingsView = Submenu.Create("Select & Move", MoveSettingsView)
local s_SpawnSettingsView = Submenu.Create("Spawning", SpawnSettingsView)
local s_PlayerSettingsView = Submenu.Create("Player", PlayerSettingsView)
local s_HudSettingsView = Submenu.Create("HUD", HudSettingsView)
local s_ControlsView = Submenu.Create("Controls", ControlsView)

local s_SettingsView = Submenu.Create("Settings", function()
    Buttons.Submenu("Camera", s_CameraSettingsView, "Camera speed, smoothing, look, field of view, and blend time.")
    Buttons.Submenu("Select & Move", s_MoveSettingsView, "Carry, nudge, and rotate speeds, plus selection outline.")
    Buttons.Submenu("Spawning", s_SpawnSettingsView, "Live preview options for the prop list.")
    Buttons.Submenu("Player", s_PlayerSettingsView, "Hide V and choose whether V follows the camera.")
    Buttons.Submenu("HUD", s_HudSettingsView, "Choose what the editor overlay shows.")
    Buttons.Submenu("Controls", s_ControlsView, "Rebind every World Editor key and button.")
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
            { Label = "Collision", Value = "Box around the prop" }
        }
    end

    local physics = held and (#held.Bodies > 0 and "Falls and tips over" or "Stays where placed")
    return {
        { Label = "Group", Value = entry.Group },
        { Label = "Type", Value = ClassName(entity) or pending },
        { Label = "Size", Value = size },
        { Label = "Physics", Value = physics or pending }
    }
end

local function SubmitPropInfo(entry)
    local entity, held = PropSpawner.GetPreviewEntity(entry)
    local pending = PropSpawner.PreviewEnabled.value and "Loading" or "Turn on Live Preview"

    SidePanel.SubmitInfo("prop-record", {
        Eyebrow = string.upper(entry.Category),
        Title = entry.Name,
        Rows = PropRows(entry, entity, held, pending),
        Description = entry.Path
    }, { Width = 330 })
end

local function PropOption(entry)
    local _, data = Buttons.Option(entry.Name, "Select to place it in front of the camera.", function()
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
        Buttons.OptionExtended("No Matches", "", s_Search.value, "Nothing in the prop list matches that search.")
        return
    end
    for _, entry in ipairs(s_SearchResults) do PropOption(entry) end
end)

local s_SpawnPropsView = Submenu.Create("Spawn Props", function()
    Buttons.Text("Search", s_Search, "Type part of a prop name, like chair, barrel, or neon.", function(text)
        s_SearchResults = PropCatalog.Search(text)
    end)
    Buttons.Submenu(string.format("Search Results (%d)", #s_SearchResults), s_SearchView, "Props matching the search.")

    Buttons.Break(string.format("Categories (%d props)", PropCatalog.Count()))
    for _, category in ipairs(PropCatalog.GetCategories()) do
        Buttons.Submenu(category.Name, CategorySubmenu(category), string.format("%d props.", category.Count))
    end
end)

local POSITION_WINDOW = 10

local s_Edit = {
    X = { value = 0, min = -10, max = 10, step = 0.02, unit = "m" },
    Y = { value = 0, min = -10, max = 10, step = 0.02, unit = "m" },
    Z = { value = 0, min = -10, max = 10, step = 0.02, unit = "m" },
    Yaw = { value = 0, min = -180, max = 180, step = 1, unit = "deg" },
    Pitch = { value = 0, min = -180, max = 180, step = 1, unit = "deg" },
    Roll = { value = 0, min = -180, max = 180, step = 1, unit = "deg" }
}

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
    Attachments.SetLocal(entity, { x = s_Edit.X.value, y = s_Edit.Y.value, z = s_Edit.Z.value }, Rotation.FromQuaternion(EditedOrientation()))
end

local function ApplyWorld(entity)
    Scene.Touch(entity)
    Physics.Place(entity, Vector4.new(s_Edit.X.value, s_Edit.Y.value, s_Edit.Z.value, 1.0), EditedOrientation())
end

local function TransformOptions(entity, attached)
    local apply = attached and function() ApplyLocal(entity) end or function() ApplyWorld(entity) end
    local frame = attached and "relative to what it is attached to" or "in the world"
    Buttons.Float("X", s_Edit.X, "Move it along X " .. frame .. ".", apply)
    Buttons.Float("Y", s_Edit.Y, "Move it along Y " .. frame .. ".", apply)
    Buttons.Float("Z", s_Edit.Z, "Move it up and down " .. frame .. ".", apply)
    Buttons.Float("Yaw", s_Edit.Yaw, "Turn it " .. frame .. ".", apply)
    Buttons.Float("Pitch", s_Edit.Pitch, "Tip it forward and back " .. frame .. ".", apply)
    Buttons.Float("Roll", s_Edit.Roll, "Tip it side to side " .. frame .. ".", apply)
end

local function DeleteFocus(focus)
    if PropSpawner.Delete(focus.Entity) then
        Notification.Info("Deleted " .. focus.Name .. ".")
    elseif Scene.Remove(focus.Entity) then
        Notification.Info(focus.Name .. " removed from the scene. It is still in the world.")
    end
    Scene.SetFocus(nil)
end

local s_EditView = Submenu.Create("Edit", function()
    local focus = Scene.GetFocus()
    if not focus then
        Buttons.OptionExtended("Gone", "", "", "This entity no longer exists. Go back to the scene list.")
        return
    end

    local entity = focus.Entity
    local entry = Attachments.Get(entity)
    Buttons.Option("Select In World", "Select it so you can carry, nudge, and rotate it with the editor camera.", function()
        Selection.Select({ Entity = entity, DisplayName = focus.Name })
    end)

    if entry then
        SyncLocal(entity)
        Buttons.Break("Offset From " .. entry.ParentName)
        TransformOptions(entity, true)
        Buttons.Option("Detach", "Let go of it so it stays where it is.", function()
            Attachments.Detach(entity)
            Notification.Info(focus.Name .. " detached.")
        end)
    else
        SyncWorld(entity)
        Buttons.Break("Position")
        TransformOptions(entity, false)
    end

    Buttons.Break("")
    local placed = PropSpawner.IsPlaced(entity) ~= nil
    Buttons.Option(placed and "Delete" or "Remove From Scene", placed and "Despawn this prop." or "Take it off this list. It stays in the world.", function()
        DeleteFocus(focus)
    end)
end)

local function EntryLabel(entry)
    local link = Attachments.Get(entry.Entity)
    if link then return entry.Name .. "  >  " .. link.ParentName end
    return entry.Name
end

local s_SceneView = Submenu.Create("Scene", function()
    Buttons.Option("Add Selection To Scene", "Put the selected world entities on this list so you can edit them here.", function()
        local added = 0
        for _, selected in ipairs(Selection.GetAll()) do
            if Scene.Add(selected.Entity, selected.Name, selected.Kind) then added = added + 1 end
        end
        if added == 0 then Notification.Warning("Select something in the world that isn't on the list yet.") end
    end)
    Buttons.Option("Attach Selection", "Attach the green selected entities to the orange one, the last one you Ctrl+clicked.", WorldEditor.LinkSelection)
    Buttons.Option("Copy Selection", "Copy the selected props you placed, with the attachments between them.", Clipboard.Copy)
    Buttons.Option("Cut Selection", "Copy the selected props you placed, then delete them.", Clipboard.Cut)
    Buttons.Option(string.format("Paste (%d)", Clipboard.Count()), "Place the copied props where the crosshair is pointing.", RequireEditor(Clipboard.Paste))
    Buttons.Option("Delete Selection", "Delete the selected props you placed. Map entities are left alone.", Clipboard.DeleteSelection)

    local entries = Scene.GetAll()
    local seen = {}
    Buttons.Break(string.format("In Scene (%d)", #entries))
    for _, entry in ipairs(entries) do
        local label = EntryLabel(entry)
        seen[label] = (seen[label] or 0) + 1
        if seen[label] > 1 then label = string.format("%s (%d)", label, seen[label]) end
        Buttons.Submenu(label, s_EditView, "Edit its position, rotation, and attachment.", function()
            Scene.SetFocus(entry.Entity, entry.Name)
        end)
    end

    Buttons.Break("")
    Buttons.Option("Detach All", "Let go of every attached prop.", function()
        Notification.Info(string.format("Detached %d props.", Attachments.DetachAll()))
    end)
    Buttons.Option("Delete Last Placed", "Remove the most recently placed prop.", PropSpawner.DeleteLast)
    Buttons.Option("Delete All Placed", "Remove every prop placed from the prop list.", function()
        Notification.Info(string.format("Removed %d props.", PropSpawner.DeleteAll()))
    end)
end)

local function WorldEditorView()
    Buttons.Toggle("World Editor", WorldEditor.Enabled, "Detach the camera from V and fly around freely with the editor HUD. Player controls are blocked while it is open.")
    Buttons.Submenu("Spawn Props", s_SpawnPropsView, "Search or browse the prop list, preview props in front of the camera, and place them.")
    Buttons.Submenu(string.format("Scene (%d)", #Scene.GetAll()), s_SceneView, "Everything you placed or added. Edit positions, rotations, and attachment offsets.")
    Buttons.Option("Clear Selection", "Deselect everything.", Selection.Clear)
    Buttons.Option("Reset Camera", "Bring the camera back to V's head.", RequireEditor(WorldEditor.ResetCamera))
    Buttons.Option("Move V Here", "Put V on the ground just behind the camera.", RequireEditor(WorldEditor.TeleportPlayerToCamera))
    Buttons.Submenu("Settings", s_SettingsView, "Camera, moving, spawning, player, HUD, and control settings.")
end

return Submenu.Create("World Editor", WorldEditorView)
