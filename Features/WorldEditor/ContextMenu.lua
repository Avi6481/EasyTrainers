local Input = require("Core/Input")
local State = require("Core/State")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Scale = require("Style/Scale")
local Notify = require("Utils/Notify")
local Controls = require("Features/WorldEditor/Controls")
local Entities = require("Features/WorldEditor/Entities")
local Physics = require("Features/WorldEditor/Physics")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Picker = require("Features/WorldEditor/Picker")
local Inspector = require("Features/WorldEditor/Inspector")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Selection = require("Features/WorldEditor/Selection")
local Attachments = require("Features/WorldEditor/Attachments")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Scene = require("Features/WorldEditor/Scene")
local Changes = require("Features/WorldEditor/Changes")
local Clipboard = require("Features/WorldEditor/Clipboard")
local Layout = require("Features/WorldEditor/Layout")
local Editing = require("Features/WorldEditor/Editing")
local Grab = require("Features/WorldEditor/Grab")

local ContextMenu = {
    Handlers = {}
}

local OFFSET = 18
local EDGE = 12
local MIN_WIDTH = 200
local MAX_WIDTH = 360
local PADDING = 10
local ROW_PADDING = 5
local KEY_GAP = 28
local DIVIDER = 9
local HEADER_GAP = 4
local ACCENT = 3
local ROUNDING = 6
local PANEL_ALPHA = 0.92
local HOVER_ALPHA = 0.5
local DIVIDER_ALPHA = 0.35
local MUTED_ALPHA = 0.75
local SHADOW_COLOR = 0xC0000000
local PENDING_CHECK = 0.5
local TILT_LIMIT = 1
local UPRIGHT_LIFT = 0.5
local FOCUS_MIN = 3
local FOCUS_SCALE = 1.5
local PED_CENTER = 1.0

local s_Open = false
local s_Target = nil
local s_Subjects = {}
local s_Items = {}
local s_Index = 1
local s_Rect = nil
local s_Rows = {}
local s_LeftArmed = nil
local s_RightArmed = false
local s_Pending = nil
local s_NextCheck = 0

local function IsController()
    return State.Device.Device == State.Devices.Controller
end

local function Entry(target)
    return {
        Entity = target.Entity,
        EntityHash = target.EntityHash or Entities.Hash(target.Entity),
        Kind = target.Kind or "Prop",
        Name = target.DisplayName or target.Name or target.Record or target.ClassName or L("worldeditor.entity")
    }
end

local function AsTarget(entry)
    return { Entity = entry.Entity, EntityHash = entry.EntityHash, Kind = entry.Kind, DisplayName = entry.Name }
end

local function HasHash(list, hash)
    for _, entry in ipairs(list or {}) do
        if entry.EntityHash == hash then return true end
    end
    return false
end

local function Subjects(target)
    if Selection.Count() < 2 or not Selection.Contains(target.Entity) then return { target } end
    local list = {}
    for _, entry in ipairs(Selection.GetAll()) do table.insert(list, Entry(entry)) end
    return list
end

local function Scan(subjects)
    local copyable, placed = false, false
    for _, subject in ipairs(subjects) do
        if PropSpawner.IsPlaced(subject.Entity) then
            copyable, placed = true, true
        elseif not copyable and Clipboard.CanCopy(subject.Entity, subject.Name) then
            copyable = true
        end
    end
    return copyable, placed
end

local function CountLabel(key, count, values)
    values = values or {}
    values.count = count
    return tip("worldeditor.context." .. key .. (count > 1 and "many" or ""), values)
end

function ContextMenu.StartAttach(items)
    local pending = {}
    for _, item in ipairs(items or {}) do
        if item.Entity then table.insert(pending, Entry(item)) end
    end
    if #pending == 0 then
        Notify.Warning(L("notify.worldeditor.attach.nothing"))
        return
    end

    s_Pending = pending
    local controller = IsController()
    local name = #pending == 1 and pending[1].Name or tip("notify.worldeditor.link.props", { count = #pending })
    local key = controller and "notify.worldeditor.attach.pick.controller" or "notify.worldeditor.attach.pick.keyboard"
    Notify.Info(tip(key, { name = name, key = Controls.Text("Context", controller) }))
end

function ContextMenu.CancelAttach()
    if not s_Pending then return end
    s_Pending = nil
    Notify.Info(L("notify.worldeditor.attach.cancelled"))
end

function ContextMenu.Pending()
    return s_Pending
end

function ContextMenu.IsPending(hash)
    return HasHash(s_Pending, hash)
end

local Safe = Entities.Safe

local function Moved(target)
    Scene.Add(target.Entity, target.Name, target.Kind)
    Changes.Mark()
end

local function CanMove(target)
    if target.Kind ~= "Vehicle" or Physics.LeaveTraffic(target.Entity) then return true end
    Notify.Warning(L("notify.worldeditor.traffic.move"))
    return false
end

local function DropToGround(target)
    if not CanMove(target) then return end
    local _, rotation = Grabbables.GetPose(target.Entity)
    if Physics.SnapToGround(target.Entity, Grabbables.GetBottom(target.Entity, rotation)) then
        Moved(target)
    else
        Notify.Warning(tip("notify.worldeditor.context.noground", { name = target.Name }))
    end
end

local function IsTilted(entity)
    local angles = Safe(function() return entity:GetWorldOrientation():ToEulerAngles() end)
    return angles ~= nil and (math.abs(angles.pitch) > TILT_LIMIT or math.abs(angles.roll) > TILT_LIMIT)
end

local function Straighten(target)
    if not CanMove(target) then return end
    local entity = target.Entity
    local position = Safe(function() return entity:GetWorldPosition() end)
    local yaw = Safe(function() return entity:GetWorldYaw() end)
    if not position or not yaw then return end

    local vehicle = target.Kind == "Vehicle"
    local lift = vehicle and UPRIGHT_LIFT or 0
    if not Physics.Place(entity, Vector4.new(position.x, position.y, position.z + lift, 1.0), yaw) then return end
    Physics.RefreshCollision(entity)
    if vehicle then Safe(function() entity:PhysicsWakeUp() end) end
    Moved(target)
end

local function FlyTo(target)
    local position, rotation = Grabbables.GetPose(target.Entity)
    if not position then return end

    local bounds = Grabbables.GetBounds(target.Entity)
    local center = { x = position.x, y = position.y, z = position.z + (target.Kind == "Ped" and PED_CENTER or 0) }
    local size = 0
    if bounds then
        local middle = {
            x = (bounds.Min.x + bounds.Max.x) * 0.5,
            y = (bounds.Min.y + bounds.Max.y) * 0.5,
            z = (bounds.Min.z + bounds.Max.z) * 0.5
        }
        center = Grabbables.ToWorld(position, rotation, middle)
        size = math.sqrt((bounds.Max.x - bounds.Min.x) ^ 2 + (bounds.Max.y - bounds.Min.y) ^ 2 + (bounds.Max.z - bounds.Min.z) ^ 2)
    end
    FreeCam.Focus(center, math.max(FOCUS_MIN, size * FOCUS_SCALE))
end

local function Ragdoll(target)
    Safe(function() target.Entity:QueueEvent(CreateForceRagdollEvent(CName.new("EasyTrainer"))) end)
end

local function AddToScene(target)
    if Scene.Add(target.Entity, target.Name, target.Kind) then
        Notify.Success(tip("notify.worldeditor.scene.added.one", { count = 1 }))
    end
end

local function AttachHere(target)
    local pending = s_Pending
    if not pending then return end
    s_Pending = nil
    local attached, child = Editing.Attach(pending, target)
    if attached == 0 then
        s_Pending = pending
    elseif child then
        Selection.Select(AsTarget(child))
    end
end

local function Build()
    local items, divider = {}, false
    local controller = IsController()
    local target, subjects, pending = s_Target, s_Subjects, s_Pending
    local point = Layout.Target()

    local function Add(label, run, action)
        table.insert(items, {
            Label = label,
            Run = run,
            Key = action and not controller and Controls.KeyText(action) or nil,
            Divider = divider and #items > 0
        })
        divider = false
    end

    local function Group()
        divider = true
    end

    if not target then
        if Clipboard.Count() > 0 and point then
            Add(CountLabel("paste", Clipboard.Count()), function() Clipboard.PasteAt(point) end, "Paste")
        end
        if pending then Add(L("worldeditor.context.cancelattach"), ContextMenu.CancelAttach) end
        if Selection.Count() > 0 then Add(L("worldeditor.context.clearselection"), Selection.Clear) end
        return items
    end

    local count = #subjects
    local selected = Selection.Contains(target.Entity)
    local function Shortcut(action)
        return selected and action or nil
    end

    if pending and not HasHash(pending, target.EntityHash) then
        Add(CountLabel("attachhere", #pending, { name = pending[1].Name }), function() AttachHere(target) end)
    end
    if pending then
        Add(L("worldeditor.context.cancelattach"), ContextMenu.CancelAttach)
    else
        Add(CountLabel("attach", count), function() ContextMenu.StartAttach(subjects) end)
    end

    local link = Attachments.GetByHash(target.EntityHash)
    if link then Add(tip("worldeditor.context.detach", { name = link.ParentName }), function() Editing.Detach(target) end) end
    local children = #Attachments.ChildrenOf(target.EntityHash)
    if children > 0 then
        Add(tip("worldeditor.context.detachchildren", { count = children }), function() Editing.DetachChildren(target) end)
    end

    Group()
    if not link then
        Add(L("worldeditor.context.droptoground"), function() DropToGround(target) end)
        if IsTilted(target.Entity) then Add(L("worldeditor.context.straighten"), function() Straighten(target) end) end
    end
    Add(L("worldeditor.context.flyto"), function() FlyTo(target) end)
    if target.Kind == "Vehicle" and not link and ContextMenu.Handlers.GetIn then
        Add(L("worldeditor.context.getin"), function() ContextMenu.Handlers.GetIn(target.Entity) end)
    end
    if target.Kind == "Ped" then Add(L("worldeditor.context.ragdoll"), function() Ragdoll(target) end) end

    Group()
    local copyable, placed = Scan(subjects)
    if copyable then Add(CountLabel("copy", count), function() Clipboard.CopyItems(subjects) end, Shortcut("Copy")) end
    if placed then Add(CountLabel("cut", count), function() Clipboard.CutItems(subjects) end, Shortcut("Cut")) end
    if Clipboard.Count() > 0 and point then
        Add(CountLabel("paste", Clipboard.Count()), function() Clipboard.PasteAt(point) end, "Paste")
    end
    if count == 1 and copyable then
        Add(L("worldeditor.context.duplicate"), function()
            if Layout.Duplicate(target.Entity, target.Name, "Parent", Layout.SelectRoot) then
                Notify.Success(tip("notify.worldeditor.scene.copied", { name = target.Name }))
            else
                Notify.Warning(tip("notify.worldeditor.scene.cantcopy", { name = target.Name }))
            end
        end)
    end

    Group()
    if not Scene.Contains(target.Entity) then Add(L("worldeditor.context.addscene"), function() AddToScene(target) end) end
    if selected then
        if Selection.Count() > 1 then Add(L("worldeditor.context.removeselection"), function() Selection.Toggle(AsTarget(target)) end) end
    elseif Selection.Count() > 0 then
        Add(L("worldeditor.context.addselection"), function() Selection.Toggle(AsTarget(target)) end)
    end
    if placed then Add(CountLabel("delete", count), function() Clipboard.DeleteItems(subjects) end, Shortcut("Delete")) end
    return items
end

function ContextMenu.IsOpen()
    return s_Open
end

function ContextMenu.Close()
    if not s_Open then return end
    s_Open = false
    s_Target = nil
    s_Subjects = {}
    s_Items = {}
    s_Rect = nil
    s_Rows = {}
    s_LeftArmed = nil
    s_RightArmed = false
    Controls.Paused = false
    State.PopupCursor = false
end

local function Open()
    local target = Inspector.Target
    s_Target = target and target.Entity and Entry(target) or nil
    s_Subjects = s_Target and Subjects(s_Target) or {}
    s_Items = Build()
    if #s_Items == 0 then
        s_Target = nil
        s_Subjects = {}
        return
    end

    s_Open = true
    s_Index = 1
    s_Rect = nil
    s_Rows = {}
    s_LeftArmed = nil
    s_RightArmed = false
    Controls.Paused = true
    State.PopupCursor = not IsController()
end

local function Run(index)
    local item = s_Items[index]
    ContextMenu.Close()
    if item and item.Run then item.Run() end
end

local function Move(step)
    s_Index = ((s_Index - 1 + step) % #s_Items) + 1
end

local function Hovered()
    if not s_Rect then return nil end
    local x, y = Input.MousePos()
    if x < s_Rect.X or x >= s_Rect.X + s_Rect.W then return nil end
    for index, row in ipairs(s_Rows) do
        if y >= row.Top and y < row.Bottom then return index end
    end
    return nil
end

local function Inside()
    return s_Rect ~= nil and Input.MouseIn(s_Rect.X, s_Rect.Y, s_Rect.W, s_Rect.H)
end

local function UpdateMouse()
    local hovered = Hovered()
    if hovered and Input.MouseMoved() then s_Index = hovered end

    if Input.MousePressed(Input.Mouse.Left) then s_LeftArmed = hovered or (Inside() and -1 or 0) end
    if Input.MouseReleased(Input.Mouse.Left) and s_LeftArmed then
        local armed = s_LeftArmed
        s_LeftArmed = nil
        if armed == 0 then
            ContextMenu.Close()
        elseif armed > 0 and Hovered() == armed then
            Run(armed)
        end
        return
    end

    if Input.MousePressed(Input.Mouse.Right) then s_RightArmed = true end
    if Input.MouseReleased(Input.Mouse.Right) and s_RightArmed then ContextMenu.Close() end
end

local function UpdateInput()
    if Input.KeyPressed(Input.VK.Escape) or Input.ButtonPressed(Input.Button.B) then
        ContextMenu.Close()
        return
    end
    if Input.KeyPressed(Input.VK.Up) or Input.ButtonPressed(Input.Button.DpadUp) then Move(-1) end
    if Input.KeyPressed(Input.VK.Down) or Input.ButtonPressed(Input.Button.DpadDown) then Move(1) end
    if Input.KeyPressed(Input.VK.Return) or Input.ButtonPressed(Input.Button.A) then
        Run(s_Index)
        return
    end
    if State.PopupCursor then UpdateMouse() end
end

local function CheckPending()
    if not s_Pending then return end
    local now = os.clock()
    if now < s_NextCheck then return end
    s_NextCheck = now + PENDING_CHECK

    for index = #s_Pending, 1, -1 do
        if not Entities.IsValid(s_Pending[index].Entity) then table.remove(s_Pending, index) end
    end
    if #s_Pending == 0 then s_Pending = nil end
end

function ContextMenu.Update()
    CheckPending()
    if not s_Open then
        if State.Menu.Open or Grab.IsHolding() or Controls.Blocked() then return end
        if Controls.Pressed("Context") then Open() end
        return
    end

    if State.Menu.Open or State.OverlayOpen or (s_Target and not Entities.IsValid(s_Target.Entity)) then
        ContextMenu.Close()
        return
    end
    UpdateInput()
end

function ContextMenu.Forget()
    ContextMenu.Close()
    s_Pending = nil
end

local function ShadowText(x, y, color, text, size)
    Draw.Text(x + 1, y + 1, SHADOW_COLOR, text, size)
    Draw.Text(x, y, color, text, size)
end

local function TextWidth(text, size)
    return (Draw.TextSize(text, size))
end

local function Header(size)
    if not s_Target then return nil end
    local kind = Picker.Kind(s_Target.Kind)
    local count = #s_Subjects
    local note = count > 1 and tip("worldeditor.context.selected", { count = count }) or nil
    return {
        Label = string.upper(L(kind.Key)),
        Title = s_Target.Name,
        Note = note,
        NoteWidth = note and TextWidth(note, size) or 0,
        Color = kind.Color
    }
end

local function MeasureWidth(header, size)
    local keyGap = Scale.S(KEY_GAP)
    local width = Scale.S(MIN_WIDTH)
    for _, item in ipairs(s_Items) do
        item.KeyWidth = item.Key and TextWidth(item.Key, size) or 0
        width = math.max(width, TextWidth(item.Label, size) + (item.Key and keyGap + item.KeyWidth or 0))
    end
    if header then
        width = math.max(width, TextWidth(header.Label, size) + (header.Note and keyGap + header.NoteWidth or 0))
        width = math.max(width, TextWidth(header.Title, size))
    end
    return math.min(width, Scale.S(MAX_WIDTH))
end

local function Place(panelWidth, panelHeight, width, height)
    local offset, edge = Scale.S(OFFSET), Scale.S(EDGE)
    local x, y = width * 0.5 + offset, height * 0.5 + offset
    if x + panelWidth > width - edge then x = width * 0.5 - offset - panelWidth end
    if y + panelHeight > height - edge then y = math.max(edge, height - edge - panelHeight) end
    return x, y
end

function ContextMenu.Draw(width, height, size, lineHeight)
    if not s_Open then return end

    local padding = Scale.S(PADDING)
    local rowPadding = Scale.S(ROW_PADDING)
    local accent = Scale.S(ACCENT)
    local dividerHeight = Scale.S(DIVIDER)
    local rowHeight = lineHeight + rowPadding * 2
    local header = Header(size)
    local contentWidth = MeasureWidth(header, size)

    local headerHeight = header and (lineHeight * 2 + Scale.S(HEADER_GAP) + dividerHeight) or 0
    local itemsHeight = 0
    for _, item in ipairs(s_Items) do itemsHeight = itemsHeight + rowHeight + (item.Divider and dividerHeight or 0) end

    local panelWidth = contentWidth + padding * 2 + accent
    local panelHeight = headerHeight + itemsHeight + padding * 2
    local x, y = Place(panelWidth, panelHeight, width, height)
    local left = x + accent + padding
    local right = x + panelWidth - padding
    local muted = Draw.ScaleAlpha(Style.TextDisabled, MUTED_ALPHA)
    local dividerColor = Draw.ScaleAlpha(Style.TextDisabled, DIVIDER_ALPHA)
    local rounding = Scale.S(ROUNDING)

    Draw.RectFilled(x, y, panelWidth, panelHeight, Draw.ScaleAlpha(Style.BackgroundDark, PANEL_ALPHA), rounding)
    Draw.LeftAccent(x, y, panelHeight, header and header.Color or Style.Accent, rounding, accent)

    local cursorY = y + padding
    if header then
        ShadowText(left, cursorY, header.Color, header.Label, size)
        if header.Note then ShadowText(right - header.NoteWidth, cursorY, muted, header.Note, size) end
        cursorY = cursorY + lineHeight + Scale.S(HEADER_GAP)
        ShadowText(left, cursorY, Style.Text, Draw.FitText(header.Title, contentWidth, size), size)
        cursorY = cursorY + lineHeight
        local middle = cursorY + dividerHeight * 0.5
        Draw.Line(left, middle, right, middle, dividerColor, 1)
        cursorY = cursorY + dividerHeight
    end

    s_Rows = {}
    for index, item in ipairs(s_Items) do
        if item.Divider then
            local middle = cursorY + dividerHeight * 0.5
            Draw.Line(left, middle, right, middle, dividerColor, 1)
            cursorY = cursorY + dividerHeight
        end
        if index == s_Index then
            Draw.RectFilled(x + accent, cursorY, panelWidth - accent, rowHeight, Draw.ScaleAlpha(Style.Accent, HOVER_ALPHA), 0)
        end
        local labelWidth = contentWidth - (item.Key and Scale.S(KEY_GAP) + item.KeyWidth or 0)
        ShadowText(left, cursorY + rowPadding, Style.Text, Draw.FitText(item.Label, labelWidth, size), size)
        if item.Key then ShadowText(right - item.KeyWidth, cursorY + rowPadding, muted, item.Key, size) end
        s_Rows[index] = { Top = cursorY, Bottom = cursorY + rowHeight }
        cursorY = cursorY + rowHeight
    end

    s_Rect = { X = x, Y = y, W = panelWidth, H = panelHeight }
end

return ContextMenu
