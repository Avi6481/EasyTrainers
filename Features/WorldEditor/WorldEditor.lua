local Logger = require("Core/Logger")
local InputBlock = require("Core/InputBlock")
local State = require("Core/State")
local Landing = require("Utils/Landing")
local Notify = require("Utils/Notify")
local Vehicle = require("Utils/Vehicle")
local NoClip = require("Features/Self/NoClip")
local Timers = require("Features/WorldEditor/Timers")
local Controls = require("Features/WorldEditor/Controls")
local Entities = require("Features/WorldEditor/Entities")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Picker = require("Features/WorldEditor/Picker")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Selection = require("Features/WorldEditor/Selection")
local Grab = require("Features/WorldEditor/Grab")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local PropCatalog = require("Features/WorldEditor/PropCatalog")
local VehicleCatalog = require("Features/WorldEditor/VehicleCatalog")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Tracker = require("Features/WorldEditor/Tracker")
local Layout = require("Features/WorldEditor/Layout")
local Clipboard = require("Features/WorldEditor/Clipboard")
local ContextMenu = require("Features/WorldEditor/ContextMenu")
local History = require("Features/WorldEditor/History")
local Hud = require("Features/WorldEditor/Hud")
local Player = require("Features/WorldEditor/Player")
local GameHud = require("Features/WorldEditor/GameHud")

local WorldEditor = {
    Enabled = false
}

local OWNER = "WorldEditor"
local WATCH_TIME = 1
local MAX_DELTA = 0.1
local LANDING_GRACE = 3

local s_Active = false
local s_Adopted = false
local s_Started = false
local s_Queue = {}
local s_WatchUntil = 0
local s_LastClock = nil
local s_LandingUntil = 0
local s_CatalogQueued = false
local s_Failed = {}

local Safe = Entities.Safe

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

local function Delta()
    local now = os.clock()
    local delta = s_LastClock and math.min(MAX_DELTA, now - s_LastClock) or 0
    s_LastClock = now
    return delta
end

function WorldEditor.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function WorldEditor.Watching()
    return os.clock() < s_WatchUntil
end

function WorldEditor.Run(action)
    table.insert(s_Queue, action)
end

function WorldEditor.IsActive()
    return s_Active
end

function WorldEditor.LoadCatalog()
    if s_CatalogQueued or (PropCatalog.IsLoaded() and VehicleCatalog.IsLoaded()) then return end
    s_CatalogQueued = true
    WorldEditor.Run(PropCatalog.Load)
    WorldEditor.Run(VehicleCatalog.Load)
end

local function Hold(active)
    if not active then
        InputBlock.Release(OWNER)
        return
    end
    InputBlock.Hold(OWNER, Controls.BlockSpec(ContextMenu.IsOpen()))
end

local function IsMounted(player)
    local ok, vehicle = pcall(Game.GetMountedVehicle, player)
    return ok and vehicle ~= nil
end

local function Start(player)
    if IsMounted(player) then
        Notify.Warning(L("notify.worldeditor.leavevehicle"))
        return false
    end

    NoClip.Enabled = false
    if not FreeCam.Start(player) then
        Notify.Error(L("notify.worldeditor.nocamera"))
        return false
    end

    s_Active = true
    s_LandingUntil = 0
    Landing.Hold(OWNER, true)
    Inspector.Refresh(true)
    Player.SetHidden(Player.Hide)
    Logger.Log("WorldEditor: started")
    return true
end

local function Stop(blendTime)
    if not s_Active then return end

    ContextMenu.Forget()
    Grab.Drop()
    Selection.Clear()
    Player.SetHidden(false)
    FreeCam.Stop(blendTime)
    Hold(false)
    GameHud.SetHidden(false)
    Inspector.Clear()
    Hud.Clear()
    s_Active = false
    s_LandingUntil = os.clock() + LANDING_GRACE
    Logger.Log("WorldEditor: stopped")
end

local function RequireActive()
    if s_Active then return true end
    Notify.Warning(L("notify.worldeditor.openfirst"))
    return false
end

function WorldEditor.ResetCamera(player)
    if not RequireActive() then return end
    FreeCam.ResetToPlayer(player)
end

function WorldEditor.MovePlayerHere(player)
    if not RequireActive() then return end
    if not Player.MoveHere(player) then Notify.Error(L("notify.worldeditor.movefailed")) end
end

function WorldEditor.DetachSelection()
    local detached = 0
    for _, selected in ipairs(Selection.GetAll()) do
        if Attachments.Detach(selected.Entity) then detached = detached + 1 end
        detached = detached + Attachments.DetachChildrenOf(selected.Entity)
    end
    if detached == 0 then
        Notify.Warning(L("notify.worldeditor.detach.none"))
        return
    end
    Notify.Info(tip(detached == 1 and "notify.worldeditor.detach.done.one" or "notify.worldeditor.detach.done.many", { count = detached }))
end

function WorldEditor.GetIn(vehicle)
    local player = Game.GetPlayer()
    if not player then return end
    WorldEditor.Enabled = false
    Stop()
    local mounted = Safe(function() return Vehicle.Mount(player, vehicle) end)
    if not mounted then Notify.Warning(L("notify.worldeditor.getin.failed")) end
end

local SHORTCUTS = {
    { Action = "Copy", Run = Clipboard.Copy },
    { Action = "Cut", Run = Clipboard.Cut },
    { Action = "Paste", Run = Clipboard.Paste },
    { Action = "Delete", Run = Clipboard.DeleteSelection },
    { Action = "Detach", Run = WorldEditor.DetachSelection },
    { Action = "Undo", Run = History.Undo },
    { Action = "Redo", Run = History.Redo }
}

local function UpdateShortcuts()
    if State.Menu.Open or Controls.Blocked() or Grab.IsHolding() then return end
    for _, shortcut in ipairs(SHORTCUTS) do
        if Controls.Pressed(shortcut.Action) then shortcut.Run() end
    end
end

local function AdoptTracked()
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

local function UpdateEditor(player, delta)
    if not WorldEditor.Enabled then
        Stop()
        return
    end

    if not s_Active and not Start(player) then
        WorldEditor.Enabled = false
        return
    end

    if not FreeCam.IsActive() then
        WorldEditor.Enabled = false
        Stop()
        return
    end

    NoClip.Enabled = false
    local inMenu = GameHud.InMenu()
    Hold(not inMenu)
    GameHud.SetHidden(GameHud.Hide and not inMenu)
    if inMenu then
        ContextMenu.Close()
        Hud.Clear()
        return
    end

    FreeCam.Tick(delta)
    ContextMenu.Update()
    if not s_Active then return end
    Grab.Tick(delta)
    UpdateShortcuts()
    Player.UpdateFollow(player)
    Player.SetHidden(Player.Hide)
    Inspector.Refresh()
    Hud.Update()
end

local function UpdateLanding()
    if s_Active or s_LandingUntil == 0 or os.clock() < s_LandingUntil then return end
    s_LandingUntil = 0
    Landing.Hold(OWNER, false)
end

local function Watched()
    PropSpawner.CanSpawnMeshes()
    Scene.Refresh()
end

local function RunQueue(player)
    local queue = s_Queue
    s_Queue = {}
    for _, action in ipairs(queue) do Try("World editor action", action, player) end
end

function WorldEditor.Bind(store)
    store:Bind("WorldEditor.Controls", Controls, { "Binds" })
    store:Bind("WorldEditor.Camera", FreeCam, {
        "MoveSpeed", "FastMultiplier", "SlowMultiplier", "Smoothing", "MouseSensitivity", "StickLookSpeed", "InvertLook",
        "FieldOfView", "WheelAdjustsSpeed", "StickDeadzone", "BlendTime"
    })
    store:Bind("WorldEditor.Move", Grab, { "HoldDelay", "KeepFacing", "SnapPedsToGround", "NudgeSpeed", "RotateSpeed" })
    store:Bind("WorldEditor.Selection", Selection, { "Highlight" })
    store:Bind("WorldEditor.Spawning", PropSpawner, { "PreviewEnabled", "PreviewDistance", "PreviewSpin" })
    store:Bind("WorldEditor.Hud", Hud, {
        "ShowInfo", "ShowCrosshair", "ShowControls", "ShowDebug", "ShowGrabMarkers", "ShowTargetBox", "ShowAttachmentLinks"
    })
    store:Bind("WorldEditor.GameHud", GameHud, { "Hide" })
    store:Bind("WorldEditor.Player", Player, { "Hide", "Follow", "FollowDistance" })
    store:Bind("WorldEditor.Inspector", Inspector, { "TraceDistance" })
    store:Bind("WorldEditor.Picker", Picker, { "SearchRange" })
    Controls.Fill()
end

local function GrabbableEntities()
    local list = PropSpawner.GetEntities()
    for _, entry in ipairs(Attachments.GetEntries()) do
        if not PropSpawner.IsPlaced(entry.Child) then table.insert(list, entry.Child) end
    end
    return list
end

function WorldEditor.Initialize()
    Landing.Initialize()
    FreeCam.Initialize()
    ContextMenu.Handlers.GetIn = WorldEditor.GetIn

    Grabbables.SetSource(GrabbableEntities)
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

    Observe("PlayerPuppet", "OnAction", function(_, action) Try("World editor look", FreeCam.HandleAction, action) end)
    Override("ZoomLevelBaseDecisions", "ToZoomLevelAim", function(_, stateContext, scriptInterface, wrapped)
        if s_Active then return false end
        return wrapped(stateContext, scriptInterface)
    end)
end

function WorldEditor.Update(player)
    local delta = Delta()
    Try("World editor controls", Controls.Update)
    Try("World editor timers", Timers.Update)

    if not s_Adopted then
        s_Adopted = true
        Try("World editor adopt", AdoptTracked)
        Try("World editor rebase", History.Rebase)
    end
    if #s_Queue > 0 then RunQueue(player) end

    Try("Prop spawner", PropSpawner.Tick, delta)
    Try("World editor layout", Layout.Tick)
    Try("Attachments", Attachments.Tick)
    Try("World editor selection", Selection.Tick)
    Try("Scene", Scene.Tick)
    Try("World editor history", History.Tick)
    if WorldEditor.Watching() then Try("World editor menu", Watched) end
    Try("World editor", UpdateEditor, player, delta)
    UpdateLanding()
end

local function Forget()
    ContextMenu.Forget()
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
    Player.Forget()
    GameHud.Forget()
    Hud.Clear()
    if EasyWorldEditor then Safe(function() EasyWorldEditor.ResetSession() end) end
    s_Adopted = false
end

function WorldEditor.Reset()
    s_Queue = {}
    s_CatalogQueued = false
    WorldEditor.Enabled = false
    Try("World editor game HUD", GameHud.SetHidden, false)
    if s_Started then Try("World editor reset", Forget) end
    Try("World editor stop", Stop, 0)
    Hold(false)
    s_LandingUntil = 0
    Landing.Hold(OWNER, false)
    Timers.Clear()
    Controls.Clear()
    s_Started = true
end

function WorldEditor.Shutdown()
    s_Queue = {}
    s_CatalogQueued = false
    WorldEditor.Enabled = false
    Try("World editor stop", Stop, 0)
    Try("World editor options", ContextMenu.Forget)
    Hold(false)
    s_LandingUntil = 0
    Landing.Hold(OWNER, false)
    Try("World editor selection", Selection.Clear)
    Try("Attachments", Attachments.Shutdown)
    Try("Prop spawner", PropSpawner.Shutdown)
    Try("World editor timers", Timers.Flush)
    GameHud.SetHidden(false)
end

function WorldEditor.Draw()
    Hud.Draw()
end

return WorldEditor
