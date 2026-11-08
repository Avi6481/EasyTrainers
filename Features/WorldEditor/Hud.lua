local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Scale = require("Style/Scale")
local KeyBind = require("Widgets/KeyBind/KeyBind")
local Controls = require("Features/WorldEditor/Controls")
local Physics = require("Features/WorldEditor/Physics")
local Entities = require("Features/WorldEditor/Entities")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Picker = require("Features/WorldEditor/Picker")
local Selection = require("Features/WorldEditor/Selection")
local Grab = require("Features/WorldEditor/Grab")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Clipboard = require("Features/WorldEditor/Clipboard")
local ContextMenu = require("Features/WorldEditor/ContextMenu")

local Hud = {
    ShowInfo = true,
    ShowCrosshair = true,
    ShowControls = true,
    ShowDebug = true,
    ShowGrabMarkers = true,
    ShowTargetBox = true,
    ShowAttachmentLinks = true
}

local MARGIN = 28
local LINE_GAP = 3
local COLUMN_GAP = 18
local LABEL_GAP = 6
local TITLE_GAP = 10
local CARD_WIDTH = 340
local CARD_PADDING = 12
local CARD_ACCENT = 3
local CARD_ROUNDING = 6
local CARD_ALPHA = 0.45
local CROSSHAIR_SIZE = 8
local CROSSHAIR_GAP = 4
local BRACKET_IDLE = 10
local BRACKET_LOCKED = 20
local BRACKET_LENGTH = 7
local LOCK_SPEED = 14
local FADE_SPEED = 10
local IDLE_COLOR = 0xB4C8C8C8
local SHADOW_COLOR = 0xC0000000
local MUTED_ALPHA = 0.75
local MARKER_SIZE = 6
local MARKER_ALPHA = 0.8
local LINK_ALPHA = 0.7
local SELECTION_TAG_WIDTH = 80
local SELECTION_TEXT_WIDTH = 300
local LINK_NAME_WIDTH = 180
local CHILD_COLOR = 0xFF8CE65A
local PARENT_COLOR = 0xFF3CC8FF
local PANEL_PADDING = 10
local PANEL_GAP = 8
local PANEL_ALPHA = 0.6
local BOX_ALPHA = 0.85
local COLLISION_REFRESH = 0.5
local STALE_TIME = 0.5
local PROJECT_LIMIT = 4
local EDGES = {
    { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 },
    { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }
}
local ARROWS = { Input.VK.Up, Input.VK.Left, Input.VK.Down, Input.VK.Right }

local s_Frame = nil
local s_Collision = { Hash = nil, Text = nil, Next = 0 }
local s_Lock = 0
local s_LockColor = IDLE_COLOR
local s_CardAlpha = 0
local s_Card = nil

local Safe = Entities.Safe

local function Segment(text, color, gap, sample, fit, fixed)
    return { Text = text, Color = color, Gap = gap or 0, Sample = sample, Fit = fit, Fixed = fixed }
end

local function Pairs(entries, sample)
    local row = {}
    for _, entry in ipairs(entries) do
        table.insert(row, Segment(entry[1], "Muted", LABEL_GAP))
        table.insert(row, Segment(entry[2], "Text", COLUMN_GAP, sample))
    end
    return row
end

local function Tagged(tag, color, text)
    return { Segment(tag, color, 0, nil, nil, SELECTION_TAG_WIDTH), Segment(text, "Text", 0, nil, SELECTION_TEXT_WIDTH) }
end

local function IsController()
    return State.Device.Device == State.Devices.Controller
end

local KeyText = Controls.KeyText
local PadText = Controls.PadText

local function Single(action, vk)
    local keys = Controls.Binding(action).Keys
    return #keys == 1 and keys[1] == vk
end

local function Joined(actions, separator)
    local parts, short = {}, true
    for _, action in ipairs(actions) do
        local text = KeyText(action)
        if not text then return nil end
        if #text > 1 then short = false end
        table.insert(parts, text)
    end
    return table.concat(parts, short and "" or separator)
end

local function MoveKeys()
    return Joined({ "Forward", "Left", "Back", "Right" }, " / ")
end

local function UpDownKeys()
    local up, down = KeyText("Up"), KeyText("Down")
    return up and down and (up .. " / " .. down) or nil
end

local function NudgeKeys()
    local actions = { "NudgeForward", "NudgeLeft", "NudgeBack", "NudgeRight" }
    local arrows = true
    for index, action in ipairs(actions) do
        if not Single(action, ARROWS[index]) then arrows = false end
    end
    if arrows then return L("worldeditor.hud.keys.arrows") end
    return Joined(actions, " / ")
end

local function RotateKeys()
    if Single("Rotate", Input.VK.RButton) then return L("worldeditor.hud.keys.rightdrag") end
    local key = KeyText("Rotate")
    return key and tip("worldeditor.hud.keys.hold", { key = key }) or nil
end

local function KeyHints()
    local context = KeyText("Context") or "?"
    return {
        Detach = tip("worldeditor.hud.hints.detach", { key = KeyText("Detach") or "?" }),
        Options = tip("worldeditor.hud.hints.options", { key = context }),
        Release = tip("worldeditor.hud.hints.release", { key = KeyText("Detach") or "?" }),
        AttachHere = tip("worldeditor.hud.hints.attachhere", { key = context })
    }
end

local function PadHints()
    local context = PadText("Context") or "?"
    return {
        Detach = tip("worldeditor.hud.hints.paddetach", { key = context }),
        Options = tip("worldeditor.hud.hints.padoptions", { key = context }),
        Release = tip("worldeditor.hud.hints.padrelease", { key = context }),
        AttachHere = tip("worldeditor.hud.hints.padattachhere", { key = context })
    }
end

local function ShortcutRow()
    return {
        Segment(KeyText("Copy") or "?", "Accent", LABEL_GAP), Segment(L("worldeditor.hud.controls.copy"), "Muted", COLUMN_GAP),
        Segment(KeyText("Cut") or "?", "Accent", LABEL_GAP), Segment(L("worldeditor.hud.controls.cut"), "Muted", COLUMN_GAP),
        Segment(KeyText("Delete") or "?", "Accent", LABEL_GAP), Segment(L("worldeditor.hud.controls.delete"), "Muted")
    }
end

local function PendingRows(pending, hints)
    local rows = {}
    for _, entry in ipairs(pending) do table.insert(rows, Tagged(L("worldeditor.hud.tags.attaching"), CHILD_COLOR, entry.Name)) end
    table.insert(rows, { Segment(hints.AttachHere, "Accent") })
    return rows, PARENT_COLOR
end

local function SelectionRows()
    local hints = IsController() and PadHints() or KeyHints()
    local pending = ContextMenu.Pending()
    if pending then return PendingRows(pending, hints) end

    local selected = Selection.GetAll()
    if #selected == 0 then return {}, nil end
    local shortcuts = not IsController()

    if #selected == 1 then
        local only = selected[1]
        local rows = { Tagged(L("worldeditor.hud.tags.selected"), CHILD_COLOR, only.Name) }
        local entry = Attachments.GetByHash(only.EntityHash)
        if entry then
            table.insert(rows, Tagged(L("worldeditor.hud.tags.parent"), PARENT_COLOR, entry.ParentName))
            table.insert(rows, { Segment(hints.Detach, "Muted") })
        else
            table.insert(rows, { Segment(hints.Options, "Muted") })
        end
        if #Attachments.ChildrenOf(only.EntityHash) > 0 then table.insert(rows, { Segment(hints.Release, "Muted") }) end
        if not Scene.Contains(only.Entity) then table.insert(rows, { Segment(L("worldeditor.hud.hints.notinscene"), "Muted") }) end
        if shortcuts then table.insert(rows, ShortcutRow()) end
        return rows, CHILD_COLOR
    end

    local rows = {}
    for _, entry in ipairs(selected) do
        table.insert(rows, Tagged(L("worldeditor.hud.tags.selected"), CHILD_COLOR, entry.Name))
    end
    table.insert(rows, { Segment(hints.Options, "Muted") })
    if shortcuts then table.insert(rows, ShortcutRow()) end
    return rows, CHILD_COLOR
end

local function CameraRows()
    local camera = Inspector.Camera
    local status = "worldeditor.hud.status.starting"
    if Grab.IsHolding() then
        status = Grab.IsGrounded() and "worldeditor.hud.status.carryingground" or "worldeditor.hud.status.carrying"
    elseif FreeCam.IsReady() then
        status = "worldeditor.hud.status.freecam"
    end
    local rows = { { Segment(L("worldeditor.hud.title"), "Accent", TITLE_GAP), Segment(L(status), "Muted") } }

    if not camera then
        table.insert(rows, { Segment(L("worldeditor.hud.status.waiting"), "Muted") })
        return rows
    end

    table.insert(rows, Pairs({
        { "X", string.format("%.3f", camera.Position.x) },
        { "Y", string.format("%.3f", camera.Position.y) },
        { "Z", string.format("%.3f", camera.Position.z) }
    }, "-00000.000"))
    table.insert(rows, Pairs({
        { L("worldeditor.hud.yaw"), string.format("%.1f", camera.Yaw) },
        { L("worldeditor.hud.pitch"), string.format("%.1f", camera.Pitch) },
        { L("worldeditor.hud.speed"), string.format("%.1f m/s", FreeCam.MoveSpeed * FreeCam.SpeedMultiplier) }
    }, "000.0 m/s"))
    return rows
end

local function GameTime()
    local ok, text = pcall(function()
        local time = Game.GetTimeSystem():GetGameTime()
        return string.format("%02d:%02d:%02d", time:Hours(), time:Minutes(), time:Seconds())
    end)
    return ok and text or "--:--:--"
end

local function ActiveCameraText(camera)
    if not camera or not camera.ActiveError then return "-" end
    if camera.ActiveError < 1 then return L("worldeditor.hud.debug.editor") end
    return tip("worldeditor.hud.debug.off", { degrees = string.format("%.1f", camera.ActiveError) })
end

local function DebugRows()
    local player = Inspector.Player
    local lines = {
        GameTime(),
        tip("worldeditor.hud.debug.picking", { mode = L(Inspector.NativePicking and "worldeditor.hud.debug.native" or "worldeditor.hud.debug.estimate") }),
        tip("worldeditor.hud.debug.camera", { state = ActiveCameraText(Inspector.Camera) })
    }
    if player and player.CameraDistance then
        table.insert(lines, tip("worldeditor.hud.debug.distance", { distance = string.format("%.1f", player.CameraDistance) }))
    end

    local rows = {}
    for _, line in ipairs(lines) do table.insert(rows, { Segment(line, "Muted") }) end
    return rows
end

local function FormatVector(vector)
    if not vector then return "-" end
    return string.format("%.2f, %.2f, %.2f", vector.x, vector.y, vector.z)
end

local function SelectedCollision(entity)
    local hash = Safe(function() return tostring(entity:GetEntityID().hash) end)
    local now = os.clock()
    if hash ~= s_Collision.Hash or now >= s_Collision.Next then
        s_Collision = { Hash = hash, Text = Physics.DescribeCollision(entity), Next = now + COLLISION_REFRESH }
    end
    return s_Collision.Text
end

local function TargetRows(target)
    local rows = {}
    if target.Record then table.insert(rows, { L("worldeditor.hud.rows.record"), target.Record }) end
    if target.Appearance then table.insert(rows, { L("worldeditor.hud.rows.appearance"), target.Appearance }) end
    table.insert(rows, { L("worldeditor.hud.rows.class"), target.ClassName })
    if target.AttachedTo then table.insert(rows, { L("worldeditor.hud.rows.attachedto"), target.AttachedTo }) end
    if target.Collision then table.insert(rows, { L("worldeditor.hud.rows.collision"), target.Collision }) end
    if target.EntityHash then table.insert(rows, { L("worldeditor.hud.rows.entity"), target.EntityHash }) end
    table.insert(rows, { L("worldeditor.hud.rows.position"), FormatVector(target.Position) })
    return rows
end

local function SurfaceRows(hit)
    local rows = {}
    if hit.ObjectType then table.insert(rows, { L("worldeditor.hud.rows.object"), hit.ObjectType }) end
    if hit.Material then table.insert(rows, { L("worldeditor.hud.rows.material"), hit.Material }) end
    table.insert(rows, { L("worldeditor.hud.rows.group"), hit.Group })
    table.insert(rows, { L("worldeditor.hud.rows.position"), FormatVector(hit.Position) })
    table.insert(rows, { L("worldeditor.hud.rows.normal"), FormatVector(hit.Normal) })
    return rows
end

local function MapGeometryName(hit)
    local objectType = hit and hit.ObjectType
    if not objectType then return nil end
    local name = objectType:match("^world(.+)NodeInstance$")
    if not name then return nil end
    return (name:gsub("(%l)(%u)", "%1 %2"))
end

local function KindLabel(kind)
    return string.upper(L(Picker.Kind(kind).Key))
end

local function AttachedTo(selected)
    local entry = Attachments.GetByHash(selected.EntityHash)
    return entry and entry.ParentName or nil
end

local function CardContent()
    local holding = Grab.GetTarget()
    if holding then
        return {
            Label = tip("worldeditor.hud.card.carrying", { kind = KindLabel(holding.Kind) }),
            Title = holding.DisplayName or holding.Record or holding.ClassName,
            Distance = string.format("%.1f m", Grab.GetDistance()),
            Color = Picker.Kind(holding.Kind).Color,
            Rows = TargetRows(holding)
        }
    end

    local target = Inspector.Target
    if target then
        return {
            Label = KindLabel(target.Kind),
            Title = target.DisplayName or target.Record or target.ClassName,
            Distance = target.Distance and string.format("%.1f m", target.Distance),
            Color = Picker.Kind(target.Kind).Color,
            Rows = TargetRows(target)
        }
    end

    local selected = Selection.Get()
    if selected then
        return {
            Label = tip("worldeditor.hud.card.selected", { kind = KindLabel(selected.Kind) }),
            Title = selected.Name,
            Color = Picker.Kind(selected.Kind).Color,
            Rows = TargetRows({
                Record = selected.Record,
                Appearance = selected.Appearance,
                ClassName = selected.ClassName or L("worldeditor.unknown"),
                EntityHash = selected.EntityHash,
                Collision = SelectedCollision(selected.Entity),
                AttachedTo = AttachedTo(selected),
                Position = Selection.GetPosition()
            })
        }
    end

    local hit = Inspector.Hit
    local geometry = MapGeometryName(hit)
    if geometry then
        local rows = SurfaceRows(hit)
        table.insert(rows, 1, { L("worldeditor.hud.rows.selectable"), L("worldeditor.hud.rows.baked") })
        return {
            Label = L("worldeditor.hud.card.mapgeometry"),
            Title = geometry,
            Distance = string.format("%.1f m", hit.Distance),
            Color = Picker.Kinds.Surface.Color,
            Rows = rows
        }
    end

    if hit then
        return {
            Label = L("worldeditor.hud.card.surface"),
            Title = hit.ObjectType or hit.Material or hit.Group,
            Distance = string.format("%.1f m", hit.Distance),
            Color = Picker.Kinds.Surface.Color,
            Rows = SurfaceRows(hit)
        }
    end
    return nil
end

local function TargetColor()
    local holding = Grab.GetTarget()
    if holding then return Picker.Kind(holding.Kind).Color end
    local target = Inspector.Target
    if target then return Picker.Kind(target.Kind).Color end
    if Inspector.Hit then return Picker.Kinds.Surface.Color end
    return IDLE_COLOR
end

local function Projector(width, height)
    local system = Game.GetCameraSystem()
    return function(point)
        local ok, projected = pcall(function() return system:ProjectPoint(Vector4.new(point.x, point.y, point.z, 1.0)) end)
        if not ok or not projected then return nil end

        local x, y, w = projected.x, projected.y, projected.w
        if w and w ~= 0 then
            if w < 0 then return nil end
            x, y = x / w, y / w
        end
        if math.abs(x) > PROJECT_LIMIT or math.abs(y) > PROJECT_LIMIT then return nil end
        return width * 0.5 * (1 + x), height * 0.5 * (1 - y)
    end
end

local function FocusEntity()
    local holding = Grab.GetTarget()
    if holding then return holding.Entity, holding.Kind end
    local target = Inspector.Target
    if target and target.Entity then return target.Entity, target.Kind end
    return nil
end

local function BoxPoints(entity, project)
    local bounds = Grabbables.GetBounds(entity)
    local position, rotation = Grabbables.GetPose(entity)
    if not bounds or not position then return nil end

    local points = {}
    for index = 0, 7 do
        local corner = {
            x = (index % 2 == 1) and bounds.Max.x or bounds.Min.x,
            y = (math.floor(index / 2) % 2 == 1) and bounds.Max.y or bounds.Min.y,
            z = (math.floor(index / 4) % 2 == 1) and bounds.Max.z or bounds.Min.z
        }
        local x, y = project(Grabbables.ToWorld(position, rotation, corner))
        if not x then return nil end
        points[index + 1] = { x, y }
    end
    return points
end

local function AddLink(links, from, to, color, project)
    if not from or not to then return end
    local x1, y1 = project(from)
    local x2, y2 = project(to)
    if not x1 or not x2 then return end
    table.insert(links, { x1, y1, x2, y2, color })
end

local function Position(entity)
    return Safe(function() return entity:GetWorldPosition() end)
end

local function WorldOverlay(frame, project)
    local focus, kind = FocusEntity()
    local focusHash = focus and Safe(function() return tostring(focus:GetEntityID().hash) end)

    frame.Markers = {}
    if Hud.ShowGrabMarkers then
        for _, entry in ipairs(Grabbables.GetEntries()) do
            if entry.Hash ~= focusHash then
                local x, y = project(entry.Center)
                if x then table.insert(frame.Markers, { x, y }) end
            end
        end
    end

    if Hud.ShowTargetBox and focus and Grabbables.HasNativeBounds() then
        local points = BoxPoints(focus, project)
        if points then frame.Box = { Points = points, Color = Picker.Kind(kind).Color } end
    end

    frame.Links = {}
    if not Hud.ShowAttachmentLinks then return end
    local color = Draw.ScaleAlpha(Style.Accent, LINK_ALPHA)
    for _, entry in ipairs(Attachments.GetEntries()) do
        AddLink(frame.Links, Position(entry.Child), Position(entry.Parent), color, project)
    end

    local pending = ContextMenu.Pending()
    local target = Inspector.Target
    if not pending or not target or not target.Entity or ContextMenu.IsPending(target.EntityHash) then return end
    local pendingColor = Draw.ScaleAlpha(PARENT_COLOR, LINK_ALPHA)
    local parent = Position(target.Entity)
    for _, entry in ipairs(pending) do
        AddLink(frame.Links, Position(entry.Entity), parent, pendingColor, project)
    end
end

local function WithPaste(controls)
    if Clipboard.Count() == 0 then return controls end
    table.insert(controls, { KeyText("Paste") or "?", tip("worldeditor.hud.controls.paste", { count = Clipboard.Count() }) })
    return controls
end

local function Add(controls, label, key)
    if label then table.insert(controls, { label, L(key) }) end
end

local function MenuControls(controller)
    if controller then
        return {
            { L("worldeditor.hud.keys.dpadupdown"), L("worldeditor.hud.controls.move") },
            { KeyBind.ButtonName(Input.Button.A), L("worldeditor.hud.controls.choose") },
            { KeyBind.ButtonName(Input.Button.B), L("worldeditor.hud.controls.close") }
        }
    end
    return {
        { L("worldeditor.hud.keys.choose"), L("worldeditor.hud.controls.choose") },
        { L("worldeditor.hud.keys.close"), L("worldeditor.hud.controls.close") }
    }
end

local function PadControls()
    local select = PadText("Select")
    local rotate = PadText("Rotate")
    local ground = PadText("Ground")
    local context = PadText("Context")
    local turn = rotate and tip("worldeditor.hud.keys.padturn", { key = rotate })
    local controls = { { L("worldeditor.hud.keys.leftstick"), L("worldeditor.hud.controls.move") } }

    if Grab.IsHolding() then
        if Grab.CanNudge() then Add(controls, L("worldeditor.hud.keys.dpadupdown"), "worldeditor.hud.controls.distance") end
        Add(controls, turn, "worldeditor.hud.controls.turn")
        Add(controls, ground and tip("worldeditor.hud.keys.hold", { key = ground }), "worldeditor.hud.controls.ground")
        Add(controls, select and tip("worldeditor.hud.keys.release", { key = select }), "worldeditor.hud.controls.drop")
        return controls
    end

    if ContextMenu.Pending() then
        Add(controls, L("worldeditor.hud.keys.rightstick"), "worldeditor.hud.controls.look")
        Add(controls, context, "worldeditor.hud.controls.pickparent")
        return controls
    end

    local selected = Selection.GetAll()
    if #selected > 1 then
        Add(controls, context, "worldeditor.hud.controls.options")
        Add(controls, select, "worldeditor.hud.controls.selectone")
        return controls
    end

    if #selected == 0 then
        local up, down = PadText("Up"), PadText("Down")
        Add(controls, L("worldeditor.hud.keys.rightstick"), "worldeditor.hud.controls.look")
        Add(controls, up and down and (up .. " / " .. down), "worldeditor.hud.controls.updown")
        Add(controls, PadText("Fast"), "worldeditor.hud.controls.fast")
        Add(controls, PadText("Slow"), "worldeditor.hud.controls.slow")
    else
        if Grab.CanNudge() then Add(controls, L("worldeditor.hud.keys.dpad"), "worldeditor.hud.controls.nudge") end
        Add(controls, turn, "worldeditor.hud.controls.turn")
        Add(controls, ground, "worldeditor.hud.controls.ground")
    end
    Add(controls, select, "worldeditor.hud.controls.select")
    Add(controls, select and tip("worldeditor.hud.keys.hold", { key = select }), "worldeditor.hud.controls.carry")
    Add(controls, context, "worldeditor.hud.controls.options")
    return controls
end

local function KeyboardControls()
    local controls = {}
    Add(controls, MoveKeys(), "worldeditor.hud.controls.move")

    if Grab.IsHolding() then
        Add(controls, L("worldeditor.hud.keys.wheel"), "worldeditor.hud.controls.distance")
        Add(controls, RotateKeys(), "worldeditor.hud.controls.turn")
        local ground = KeyText("Ground")
        Add(controls, ground and tip("worldeditor.hud.keys.hold", { key = ground }), "worldeditor.hud.controls.ground")
        Add(controls, L("worldeditor.hud.keys.releaseclick"), "worldeditor.hud.controls.drop")
        return controls
    end

    local context = KeyText("Context")
    if ContextMenu.Pending() then
        Add(controls, context, "worldeditor.hud.controls.pickparent")
        return controls
    end

    local selected = Selection.GetAll()
    if #selected == 0 then
        Add(controls, UpDownKeys(), "worldeditor.hud.controls.updown")
        Add(controls, KeyText("Fast"), "worldeditor.hud.controls.fast")
        Add(controls, KeyText("Slow"), "worldeditor.hud.controls.slow")
        Add(controls, L("worldeditor.hud.keys.wheel"), "worldeditor.hud.controls.speed")
        Add(controls, KeyText("Select"), "worldeditor.hud.controls.select")
        Add(controls, L("worldeditor.hud.keys.holdclick"), "worldeditor.hud.controls.carry")
        Add(controls, context, "worldeditor.hud.controls.options")
        return WithPaste(controls)
    end

    if #selected > 1 then
        controls = {}
        Add(controls, context, "worldeditor.hud.controls.options")
        Add(controls, KeyText("Select"), "worldeditor.hud.controls.selectone")
        return WithPaste(controls)
    end

    if Grab.CanNudge() then Add(controls, NudgeKeys(), "worldeditor.hud.controls.nudge") end
    Add(controls, RotateKeys(), "worldeditor.hud.controls.turn")
    Add(controls, KeyText("Ground"), "worldeditor.hud.controls.ground")
    Add(controls, KeyText("Select"), "worldeditor.hud.controls.select")
    Add(controls, L("worldeditor.hud.keys.holdclick"), "worldeditor.hud.controls.carry")

    local hash = selected[1].EntityHash
    if Attachments.GetByHash(hash) or #Attachments.ChildrenOf(hash) > 0 then Add(controls, KeyText("Detach"), "worldeditor.hud.controls.detach") end
    Add(controls, context, "worldeditor.hud.controls.options")
    return WithPaste(controls)
end

function Hud.Update()
    local width, height = GetDisplayResolution()
    local frame = { At = os.clock() }

    if Hud.ShowInfo then
        frame.Camera = CameraRows()
        frame.Selection, frame.Accent = SelectionRows()
        frame.Card = CardContent()
    end
    if Hud.ShowDebug then frame.Debug = DebugRows() end
    if Hud.ShowCrosshair then
        frame.Locked = Inspector.Target ~= nil or Grab.IsHolding()
        frame.TargetColor = TargetColor()
    end
    if Hud.ShowControls then
        local controller = IsController()
        if ContextMenu.IsOpen() then
            frame.Controls = MenuControls(controller)
        else
            frame.Controls = controller and PadControls() or KeyboardControls()
        end
    end

    WorldOverlay(frame, Projector(width, height))
    s_Frame = frame
end

function Hud.Clear()
    s_Frame = nil
    s_Card = nil
    s_CardAlpha = 0
    s_Lock = 0
    s_LockColor = IDLE_COLOR
end

local function Color(token)
    if token == "Accent" then return Style.Accent end
    if token == "Text" then return Style.Text end
    if token == "Muted" then return Draw.ScaleAlpha(Style.TextDisabled, MUTED_ALPHA) end
    return token
end

local function ShadowText(x, y, color, text, size, alpha)
    alpha = alpha or 1
    Draw.Text(x + 1, y + 1, Draw.ScaleAlpha(SHADOW_COLOR, alpha), text, size)
    Draw.Text(x, y, Draw.ScaleAlpha(color, alpha), text, size)
end

local function Prepare(row, size)
    for _, segment in ipairs(row) do
        segment.Shown = segment.Fit and Draw.FitText(segment.Text, Scale.S(segment.Fit), size) or segment.Text
        local width = Draw.TextSize(segment.Shown, size)
        if segment.Sample then width = math.max(width, (Draw.TextSize(segment.Sample, size))) end
        if segment.Fixed then width = math.max(width, Scale.S(segment.Fixed)) end
        segment.Width = width
    end
end

local function RowWidth(row)
    local width = 0
    for index, segment in ipairs(row) do
        width = width + segment.Width + (index < #row and Scale.S(segment.Gap) or 0)
    end
    return width
end

local function DrawPanel(rows, x, y, size, lineHeight, rightAligned, accent)
    if not rows or #rows == 0 then return y end
    local padding = Scale.S(PANEL_PADDING)
    local inset = accent and Scale.S(CARD_ACCENT) or 0
    local width = 0
    for _, row in ipairs(rows) do
        Prepare(row, size)
        width = math.max(width, RowWidth(row))
    end

    local step = lineHeight + Scale.S(LINE_GAP)
    local panelWidth = width + padding * 2 + inset
    local panelHeight = #rows * step - Scale.S(LINE_GAP) + padding * 2
    local left = rightAligned and (x - panelWidth) or x
    local rounding = Scale.S(CARD_ROUNDING)
    Draw.RectFilled(left, y, panelWidth, panelHeight, Draw.ScaleAlpha(Style.BackgroundDark, PANEL_ALPHA), rounding)
    if accent then Draw.LeftAccent(left, y, panelHeight, accent, rounding, Scale.S(CARD_ACCENT)) end

    local cursorY = y + padding
    for _, row in ipairs(rows) do
        local cursorX = rightAligned and (left + panelWidth - padding - RowWidth(row)) or (left + padding + inset)
        for _, segment in ipairs(row) do
            ShadowText(cursorX, cursorY, Color(segment.Color), segment.Shown, size)
            cursorX = cursorX + segment.Width + Scale.S(segment.Gap)
        end
        cursorY = cursorY + step
    end
    return y + panelHeight
end

local function DrawCard(frame, width, height, size, lineHeight, delta)
    local content = frame.Card
    s_CardAlpha = Animation.Animate(s_CardAlpha, content and 1 or 0, FADE_SPEED, delta)
    if content then s_Card = content end
    if s_CardAlpha < 0.02 or not s_Card then return end

    local card = s_Card
    local alpha = s_CardAlpha
    local padding = Scale.S(CARD_PADDING)
    local accent = Scale.S(CARD_ACCENT)
    local gap = Scale.S(LINE_GAP)
    local cardWidth = Scale.S(CARD_WIDTH)
    local cardHeight = padding * 2 + (lineHeight + gap) * (2 + #card.Rows) + Scale.S(4)
    local x = width - Scale.S(MARGIN) - cardWidth
    local y = height - Scale.S(MARGIN) - cardHeight
    local rounding = Scale.S(CARD_ROUNDING)

    Draw.RectFilled(x, y, cardWidth, cardHeight, Draw.ScaleAlpha(Style.BackgroundDark, CARD_ALPHA * alpha), rounding)
    Draw.LeftAccent(x, y, cardHeight, Draw.ScaleAlpha(card.Color, alpha), rounding, accent)

    local contentX = x + padding + accent
    local contentWidth = cardWidth - padding * 2 - accent
    local cursorY = y + padding

    ShadowText(contentX, cursorY, card.Color, card.Label, size, alpha)
    if card.Distance then
        ShadowText(contentX + contentWidth - Draw.TextSize(card.Distance, size), cursorY, Color("Muted"), card.Distance, size, alpha)
    end
    cursorY = cursorY + lineHeight + gap

    ShadowText(contentX, cursorY, Style.Text, Draw.FitText(card.Title or "-", contentWidth, size), size, alpha)
    cursorY = cursorY + lineHeight + gap + Scale.S(4)

    local labelWidth = contentWidth * 0.3
    for _, row in ipairs(card.Rows) do
        ShadowText(contentX, cursorY, Color("Muted"), row[1], size, alpha)
        ShadowText(contentX + labelWidth, cursorY, Style.Text, Draw.FitText(row[2], contentWidth - labelWidth, size), size, alpha)
        cursorY = cursorY + lineHeight + gap
    end
end

local function DrawBrackets(centerX, centerY, extent, color, shadow)
    local length = Scale.S(BRACKET_LENGTH)
    for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        local x, y = centerX + corner[1] * extent, centerY + corner[2] * extent
        local endX, endY = x - corner[1] * length, y - corner[2] * length
        Draw.Line(x + 1, y + 1, endX + 1, y + 1, shadow, 3)
        Draw.Line(x + 1, y + 1, x + 1, endY + 1, shadow, 3)
        Draw.Line(x, y, endX, y, color, 2)
        Draw.Line(x, y, x, endY, color, 2)
    end
end

local function DrawCrosshair(frame, width, height, delta)
    local centerX, centerY = width * 0.5, height * 0.5
    s_Lock = Animation.Animate(s_Lock, frame.Locked and 1 or 0, LOCK_SPEED, delta)
    s_LockColor = Animation.LerpColor(s_LockColor, frame.TargetColor or IDLE_COLOR, math.min(1, LOCK_SPEED * delta))

    local color = s_LockColor
    local shadow = Style.Shadow
    local gap = Scale.S(CROSSHAIR_GAP) + s_Lock * Scale.S(2)
    local reach = gap + Scale.S(CROSSHAIR_SIZE) * (1 - s_Lock * 0.4)

    for _, line in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        local x1, y1 = centerX + line[1] * gap, centerY + line[2] * gap
        local x2, y2 = centerX + line[1] * reach, centerY + line[2] * reach
        Draw.Line(x1 + 1, y1 + 1, x2 + 1, y2 + 1, shadow, 3)
        Draw.Line(x1, y1, x2, y2, color, 2)
    end
    Draw.RectFilled(centerX - 1, centerY - 1, 2, 2, color, 0)

    if s_Lock < 0.02 then return end
    local extent = Scale.S(BRACKET_IDLE + (BRACKET_LOCKED - BRACKET_IDLE) * s_Lock)
    DrawBrackets(centerX, centerY, extent, Draw.ScaleAlpha(color, s_Lock), Draw.ScaleAlpha(shadow, s_Lock))
end

local function DrawMarker(x, y, color)
    local size = Scale.S(MARKER_SIZE)
    local points = { { x, y - size }, { x + size, y }, { x, y + size }, { x - size, y } }
    for index = 1, 4 do
        local a, b = points[index], points[index % 4 + 1]
        Draw.Line(a[1] + 1, a[2] + 1, b[1] + 1, b[2] + 1, SHADOW_COLOR, 3)
        Draw.Line(a[1], a[2], b[1], b[2], color, 2)
    end
    Draw.RectFilled(x - 1, y - 1, 2, 2, color, 0)
end

local function DrawWorldOverlay(frame)
    local markerColor = Draw.ScaleAlpha(Picker.Kinds.Prop.Color, MARKER_ALPHA)
    for _, marker in ipairs(frame.Markers or {}) do DrawMarker(marker[1], marker[2], markerColor) end

    local box = frame.Box
    if box then
        local edgeColor = Draw.ScaleAlpha(box.Color, BOX_ALPHA)
        for _, edge in ipairs(EDGES) do
            local a, b = box.Points[edge[1]], box.Points[edge[2]]
            Draw.Line(a[1] + 1, a[2] + 1, b[1] + 1, b[2] + 1, SHADOW_COLOR, 2.5)
            Draw.Line(a[1], a[2], b[1], b[2], edgeColor, 1.5)
        end
    end

    for _, link in ipairs(frame.Links or {}) do
        Draw.Line(link[1] + 1, link[2] + 1, link[3] + 1, link[4] + 1, SHADOW_COLOR, 2.5)
        Draw.Line(link[1], link[2], link[3], link[4], link[5], 1.5)
        DrawMarker(link[3], link[4], link[5])
    end
end

local function DrawControls(frame, width, height, size, lineHeight)
    local controls = frame.Controls
    if not controls or #controls == 0 then return end

    local row = {}
    for index, control in ipairs(controls) do
        table.insert(row, Segment(control[1], "Accent", LABEL_GAP))
        table.insert(row, Segment(control[2], "Muted", index < #controls and COLUMN_GAP or 0))
    end
    Prepare(row, size)

    local padding = Scale.S(PANEL_PADDING)
    local panelWidth = RowWidth(row) + padding * 2
    local panelHeight = lineHeight + padding * 2
    DrawPanel({ row }, (width - panelWidth) * 0.5, height - Scale.S(MARGIN) - panelHeight, size, lineHeight, false, nil)
end

local function DrawContents(frame, width, height, delta)
    local size = Scale.FontSize()
    local _, lineHeight = Draw.TextSize("Ag", size)
    local margin = Scale.S(MARGIN)

    DrawWorldOverlay(frame)
    if frame.TargetColor then DrawCrosshair(frame, width, height, delta) end
    if frame.Camera then
        local bottom = DrawPanel(frame.Camera, margin, margin, size, lineHeight, false, nil)
        DrawPanel(frame.Selection, margin, bottom + Scale.S(PANEL_GAP), size, lineHeight, false, frame.Accent)
        DrawCard(frame, width, height, size, lineHeight, delta)
    end
    if frame.Debug then DrawPanel(frame.Debug, width - margin, margin, size, lineHeight, true, nil) end
    DrawControls(frame, width, height, size, lineHeight)
    ContextMenu.Draw(width, height, size, lineHeight)
end

function Hud.Draw()
    local frame = s_Frame
    if not frame or os.clock() - frame.At > STALE_TIME then return end

    local width, height = GetDisplayResolution()
    local previous = Draw.GetAlpha()
    Draw.SetAlpha(1)

    local ok, err = true, nil
    if Draw.BeginWindow("##EasyTrainerWorldEditorHud", 0, 0, width, height) then
        ok, err = pcall(DrawContents, frame, width, height, Animation.Delta())
    end
    Draw.EndWindow()
    Draw.SetAlpha(previous)

    if not ok then error(err, 0) end
end

return Hud
