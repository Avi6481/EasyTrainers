local Logger = require("Core/Logger")
local Lifecycle = require("Core/Lifecycle")
local Input = require("Core/Input")
local Bindings = require("Controls/Bindings")
local State = require("Controls/State")
local StatusEffect = require("Utils/StatusEffect")
local Notification = require("UI/Panels/Notification/Notification")
local Teleport = require("Utils/Teleport")
local NoClip = require("Features/Self/Abilities/NoClip")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Hud = require("Features/WorldEditor/Hud")
local Selection = require("Features/WorldEditor/Selection")
local Grab = require("Features/WorldEditor/Grab")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Tracker = require("Features/WorldEditor/Tracker")
local Layout = require("Features/WorldEditor/Layout")
local Clipboard = require("Features/WorldEditor/Clipboard")
local Saves = require("Features/WorldEditor/Saves")
local History = require("Features/WorldEditor/History")

local WorldEditor = {}

WorldEditor.Enabled = { value = false }
WorldEditor.HideGameHud = { value = true }
WorldEditor.KeepPlayerNear = { value = false }
WorldEditor.HidePlayer = { value = true }
WorldEditor.FollowDistance = { value = 60, min = 20, max = 300, step = 10, unit = "m" }
WorldEditor.FreeCam = FreeCam
WorldEditor.Inspector = Inspector
WorldEditor.Hud = Hud
WorldEditor.Picker = require("Features/WorldEditor/Picker")
WorldEditor.Selection = Selection
WorldEditor.Grab = Grab
WorldEditor.PropSpawner = PropSpawner
WorldEditor.Grabbables = Grabbables
WorldEditor.Attachments = Attachments
WorldEditor.Scene = Scene
WorldEditor.Layout = Layout
WorldEditor.Clipboard = Clipboard
WorldEditor.Saves = Saves
WorldEditor.History = History

Grabbables.SetSource(PropSpawner.GetEntities)
Scene.SetPlacedSource(PropSpawner.GetPlaced, PropSpawner.IsPlaced)
PropSpawner.SetBusyCheck(function(entity)
    return Grab.IsMoving(entity) or Attachments.IsAttached(entity) or Scene.IsEditing(entity)
end)
History.SetBusyCheck(function()
    return Grab.IsBusy() or Scene.IsEditingAny() or Layout.IsBusy()
end)
PropSpawner.SetReplaceListener(function(old, new)
    Tracker.Replace(old, new)
    Attachments.Replace(old, new)
    Selection.Replace(old, new)
    Scene.Replace(old, new)
end)

local OWNER = "WorldEditor"
local HUD_LAYER = "inkHUDLayer"
local FOLLOW_INTERVAL = 0.5
local FOLLOW_BEHIND = 15
local GROUND_GROUPS = { "Static", "Terrain" }

local RESTRICTIONS = {
    "GameplayRestriction.NoMovement",
    "GameplayRestriction.NoCameraControl",
    "GameplayRestriction.NoJump",
    "GameplayRestriction.NoSprint",
    "GameplayRestriction.NoCombat",
    "GameplayRestriction.NoWeapons",
    "GameplayRestriction.NoZooming",
    "GameplayRestriction.NoScanning",
    "GameplayRestriction.NoRadialMenus",
    "GameplayRestriction.NoWorldInteractions",
    "GameplayRestriction.NoPhone",
    "GameplayRestriction.VehicleNoSummoning",
    "GameplayRestriction.NoHealing",
    "GameplayRestriction.NoFallDamage"
}

local s_Active = false
local s_GameHudHidden = false
local s_ToggleHeld = false
local s_LinkHeld = false
local s_Adopted = false
local s_ShortcutsHeld = {}
local s_NextFollow = 0
local s_HiddenPlayerParts = nil

local PLAYER_VISUAL_CLASSES = {
    entSkinnedMeshComponent = true,
    entMorphTargetSkinnedMeshComponent = true,
    entGarmentSkinnedMeshComponent = true,
    entMeshComponent = true
}

local function IsVisiblePart(component)
    local ok, visible = pcall(function()
        return PLAYER_VISUAL_CLASSES[Game.NameToString(component:GetClassName())] == true and component:IsEnabled()
    end)
    return ok and visible == true
end

local function SetPlayerHidden(hidden)
    if hidden and not s_HiddenPlayerParts then
        local player = Game.GetPlayer()
        if not player or not EasyEntityTools then return end
        local ok, components = pcall(function() return EasyEntityTools.GetComponents(player) end)
        if not ok or type(components) ~= "table" then return end

        s_HiddenPlayerParts = {}
        for _, component in ipairs(components) do
            if IsVisiblePart(component) then
                pcall(function() component:Toggle(false) end)
                table.insert(s_HiddenPlayerParts, component)
            end
        end
        Logger.Log(string.format("WorldEditor: hid %d of V's mesh components", #s_HiddenPlayerParts))
    elseif not hidden and s_HiddenPlayerParts then
        for _, component in ipairs(s_HiddenPlayerParts) do pcall(function() component:Toggle(true) end) end
        s_HiddenPlayerParts = nil
    end
end

function WorldEditor.RefreshPlayerVisibility()
    SetPlayerHidden(s_Active and WorldEditor.HidePlayer.value)
end

local function SetRestrictions(enabled)
    for _, effect in ipairs(RESTRICTIONS) do StatusEffect.Set(effect, enabled, OWNER) end
end

local function SetGameHudHidden(hidden)
    if s_GameHudHidden == hidden then return end

    local ok, err = pcall(function()
        Game.GetInkSystem():GetLayer(CName.new(HUD_LAYER)):GetVirtualWindow():SetVisible(not hidden)
    end)
    if not ok then
        Logger.Log("WorldEditor: failed to change game HUD visibility (" .. tostring(err) .. ")")
        return
    end
    s_GameHudHidden = hidden
end

local function IsMounted(player)
    local ok, vehicle = pcall(function() return Game.GetMountedVehicle(player) end)
    return ok and vehicle ~= nil
end

local function Start()
    local player = Game.GetPlayer()
    if not player then return false end

    if IsMounted(player) then
        Notification.Warning("Leave the vehicle before opening the World Editor.")
        return false
    end

    NoClip.Enabled.value = false
    if not FreeCam.Start() then
        Notification.Error("World Editor could not take the camera.")
        return false
    end

    SetRestrictions(true)
    s_Active = true
    Inspector.Refresh(true)
    SetPlayerHidden(WorldEditor.HidePlayer.value)
    Logger.Log("WorldEditor: started")
    return true
end

local function Stop()
    if not s_Active then return end

    Grab.Drop()
    Selection.Clear()
    SetPlayerHidden(false)
    FreeCam.Stop()
    SetRestrictions(false)
    SetGameHudHidden(false)
    Inspector.Clear()
    s_Active = false
    Logger.Log("WorldEditor: stopped")
end

local function UpdateToggleKey()
    local held = Bindings.IsActionDown("EDITOR_TOGGLE")
    if held and not s_ToggleHeld and not State.BindingKey and not State.TypingEnabled then
        WorldEditor.Enabled.value = not WorldEditor.Enabled.value
    end
    s_ToggleHeld = held
end

local function FollowPosition()
    local camera = FreeCam.GetPosition()
    local radians = math.rad((FreeCam.GetRotation()))
    local x = camera.x + math.sin(radians) * FOLLOW_BEHIND
    local y = camera.y - math.cos(radians) * FOLLOW_BEHIND
    local ground = Inspector.Raycast(Vector4.new(x, y, camera.z + 2, 1.0), Vector4.new(x, y, camera.z - 500, 1.0), GROUND_GROUPS)
    return Vector4.new(x, y, ground and ground.Position.z or camera.z - 2, 1.0)
end

local function UpdatePlayerFollow()
    if not WorldEditor.KeepPlayerNear.value or not FreeCam.IsReady() then return end

    local now = os.clock()
    if now < s_NextFollow then return end
    s_NextFollow = now + FOLLOW_INTERVAL

    local player = Game.GetPlayer()
    local camera = FreeCam.GetPosition()
    local origin = player:GetWorldPosition()
    local distance = math.sqrt((camera.x - origin.x) ^ 2 + (camera.y - origin.y) ^ 2)
    if distance < WorldEditor.FollowDistance.value then return end

    local yaw = FreeCam.GetRotation()
    Game.GetTeleportationFacility():Teleport(player, FollowPosition(), EulerAngles.new(0, 0, yaw))
    FreeCam.Rebase()
end

function WorldEditor.IsActive()
    return s_Active
end

function WorldEditor.TeleportPlayerToCamera()
    local player = Game.GetPlayer()
    if not FreeCam.IsReady() or not player then return false end

    local yaw = FreeCam.GetRotation()
    Teleport.TeleportEntity(player, FollowPosition(), EulerAngles.new(0, 0, yaw))
    FreeCam.Rebase()
    return true
end

function WorldEditor.ResetCamera()
    FreeCam.ResetToPlayer()
end

function WorldEditor.LinkSelection()
    local selected = Selection.GetAll()
    if #selected == 0 then
        Notification.Warning(Input.IsController() and "Select a prop, hold B and press RT on its parent, then press Y."
            or "Click a prop, Ctrl+click its parent, then press Enter.")
        return
    end

    if #selected == 1 then
        local only = selected[1]
        if Attachments.Detach(only.Entity) then
            Notification.Info(only.Name .. " detached.")
        else
            local pick = Input.IsController() and "Hold B and press RT on a parent for " or "Ctrl+click a parent for "
            Notification.Warning(pick .. only.Name .. ".")
        end
        return
    end

    local parent = selected[#selected]
    local attached, lastChild, lastReason = 0, nil, nil
    for index = 1, #selected - 1 do
        local child = selected[index]
        Attachments.Detach(child.Entity)
        local ok, reason = Attachments.Attach(child.Entity, parent.Entity, { Name = child.Name, Kind = child.Kind, ParentName = parent.Name })
        if ok then
            attached = attached + 1
            lastChild = child
            Scene.Add(child.Entity, child.Name, child.Kind)
        else
            lastReason = reason
        end
    end

    if attached == 0 then
        Notification.Warning(lastReason or "Couldn't attach those.")
        return
    end
    Scene.Add(parent.Entity, parent.Name, parent.Kind)
    Notification.Success(string.format("Attached %s to %s.", attached == 1 and lastChild.Name or (attached .. " props"), parent.Name))
    Selection.Select({ Entity = lastChild.Entity, Kind = lastChild.Kind, DisplayName = lastChild.Name, EntityHash = lastChild.EntityHash })
end

function WorldEditor.DetachSelection()
    local detached = 0
    for _, selected in ipairs(Selection.GetAll()) do
        if Attachments.Detach(selected.Entity) then detached = detached + 1 end
        detached = detached + Attachments.DetachChildrenOf(selected.Entity)
    end
    if detached == 0 then
        Notification.Warning("Select an attached prop or its parent first.")
        return
    end
    Notification.Info(string.format("Detached %d prop%s.", detached, detached == 1 and "" or "s"))
end

local function ShortcutsAllowed()
    return not State.MenuOpen and not State.BindingKey and not State.TypingEnabled and not State.MouseEnabled
end

local function UpdateLinkKey()
    local held = Bindings.IsActionDown("EDITOR_LINK")
    if held and not s_LinkHeld and ShortcutsAllowed() then WorldEditor.LinkSelection() end
    s_LinkHeld = held
end

local SHORTCUTS = {
    { Action = "EDITOR_COPY", Run = Clipboard.Copy },
    { Action = "EDITOR_CUT", Run = Clipboard.Cut },
    { Action = "EDITOR_PASTE", Run = Clipboard.Paste },
    { Action = "EDITOR_DELETE", Run = Clipboard.DeleteSelection },
    { Action = "EDITOR_DETACH", Run = WorldEditor.DetachSelection },
    { Action = "EDITOR_UNDO", Run = History.Undo },
    { Action = "EDITOR_REDO", Run = History.Redo }
}

local function UpdateShortcuts()
    local allowed = ShortcutsAllowed() and not Grab.IsHolding()
    for _, shortcut in ipairs(SHORTCUTS) do
        local held = Bindings.IsActionDown(shortcut.Action)
        if held and not s_ShortcutsHeld[shortcut.Action] and allowed then shortcut.Run() end
        s_ShortcutsHeld[shortcut.Action] = held
    end
end

local function AdoptTracked()
    s_Adopted = true
    local items = Tracker.Load()
    if #items == 0 then return end

    for _, item in ipairs(items) do
        local prop = item.Data.Prop
        if prop and prop.Entry then PropSpawner.Adopt(item.Entity, prop.Entry, prop.Uid, prop.Box) end
    end

    local links = {}
    for _, item in ipairs(items) do
        local scene = item.Data.Scene
        if scene then Scene.Add(item.Entity, scene.Name, scene.Kind) end
        if item.Data.Link then table.insert(links, item) end
    end

    local attached = 0
    for _, item in ipairs(links) do
        local link = item.Data.Link
        local parent = Tracker.FindById(link.Parent)
        if parent and link.Position and link.Rotation
            and Attachments.Attach(item.Entity, parent, { Name = link.Name, ParentName = link.ParentName }, link.Position, link.Rotation) then
            attached = attached + 1
        else
            Tracker.Set(item.Entity, "Link", nil)
        end
    end
    Logger.Log(string.format("WorldEditor: picked up %d tracked entities and %d attachments", #items, attached))
end

function WorldEditor.Tick(deltaTime)
    UpdateToggleKey()
    if not s_Adopted and Game.GetPlayer() then
        AdoptTracked()
        History.Rebase()
    end
    PropSpawner.Tick(deltaTime)
    Layout.Tick()
    Attachments.Tick()
    Selection.Tick()
    Scene.Tick()
    History.Tick()

    if not WorldEditor.Enabled.value then
        Stop()
        return
    end

    if not s_Active and not Start() then
        WorldEditor.Enabled.value = false
        return
    end

    if not FreeCam.IsActive() then
        WorldEditor.Enabled.value = false
        Stop()
        return
    end

    Input.UpdateDevice()
    FreeCam.Tick(deltaTime)
    Grab.Tick(deltaTime)
    UpdateLinkKey()
    UpdateShortcuts()
    UpdatePlayerFollow()
    Inspector.Refresh()
end

function WorldEditor.Render(deltaTime, gameMenuOpen)
    if not s_Active then return end

    SetGameHudHidden(WorldEditor.HideGameHud.value and not gameMenuOpen)
    if gameMenuOpen then return end
    Hud.Render(deltaTime)
end

Lifecycle.Register("WorldEditor", {
    OnSessionEnd = function()
        s_HiddenPlayerParts = nil
        Grab.Forget()
        Tracker.Forget()
        Layout.Forget()
        History.Forget()
        Attachments.Forget()
        Scene.Forget()
        PropSpawner.Forget()
        FreeCam.Forget()
        Inspector.Clear()
        Selection.Forget()
        if EasyWorldEditor then pcall(function() EasyWorldEditor.ResetSession() end) end
        WorldEditor.Enabled.value = false
        s_Active = false
        s_GameHudHidden = false
        s_Adopted = false
    end,
    OnShutdown = function()
        WorldEditor.Enabled.value = false
        Stop()
        Attachments.Shutdown()
        PropSpawner.Shutdown()
    end
})

return WorldEditor
