local Logger = require("Core/Logger")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")
local Animation = require("UI/Widgets/Animation/Animation")
local WorldTime = require("Features/World/WorldTime")
local Physics = require("Utils/Physics")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Picker = require("Features/WorldEditor/Picker")
local Selection = require("Features/WorldEditor/Selection")
local Grab = require("Features/WorldEditor/Grab")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Clipboard = require("Features/WorldEditor/Clipboard")
local Entities = require("Utils/Entities")

local Hud = {}

Hud.ShowInfo = { value = true }
Hud.ShowCrosshair = { value = true }
Hud.ShowControls = { value = true }
Hud.ShowDebug = { value = true }
Hud.ShowGrabMarkers = { value = true }
Hud.ShowTargetBox = { value = true }
Hud.ShowAttachmentLinks = { value = true }

local MARGIN = 28
local LINE_GAP = 3
local COLUMN_GAP = 18
local CARD_WIDTH = 340
local CARD_PADDING = 12
local CARD_ACCENT = 3
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

local CONTROLS = {
    { "WASD", "Move" }, { "E / Q", "Up / Down" }, { "Shift", "Fast" }, { "Alt", "Slow" }, { "Wheel", "Speed" },
    { "Click", "Select" }, { "Hold", "Carry" }
}
local CONTROLS_SELECTED = {
    { "WASD", "Move" }, { "Arrows", "Nudge" }, { "Right Drag", "Turn / Tilt" }, { "Space", "Ground" }, { "Click", "Select" },
    { "Hold", "Carry" }
}
local CONTROLS_SELECTED_MENU = {
    { "WASD", "Move" }, { "Right Drag", "Turn / Tilt" }, { "Space", "Ground" }, { "Click", "Select" }, { "Hold", "Carry" }
}
local CONTROLS_HOLDING = {
    { "WASD", "Move" }, { "Wheel", "Distance" }, { "Right Drag", "Turn / Tilt" }, { "Hold Space", "Ground" }, { "Release", "Drop" }
}

local MARKER_SIZE = 6
local MARKER_ALPHA = 0.8
local LINK_ALPHA = 0.7
local SELECTION_TAG_WIDTH = 80
local SELECTION_TEXT_WIDTH = 300
local CHILD_COLOR = 0xFF8CE65A
local PANEL_PADDING = 10
local PANEL_GAP = 8
local PANEL_ALPHA = 0.6
local PARENT_COLOR = 0xFF3CC8FF
local BOX_ALPHA = 0.85
local EDGES = {
    { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 },
    { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }
}

local COLLISION_REFRESH = 0.5

local s_Collision = { Hash = nil, Text = nil, Next = 0 }
local s_ErrorLogged = false
local s_Lock = 0
local s_LockColor = IDLE_COLOR
local s_CardAlpha = 0
local s_Card = nil

local Safe = Entities.Safe

local function Muted(alpha)
    return Animation.WithAlpha(Style.TextDisabled, (alpha or 1) * MUTED_ALPHA)
end

local function ShadowText(drawList, x, y, color, text, alpha)
    alpha = alpha or 1
    Draw.Text(drawList, x + 1, y + 1, Animation.WithAlpha(SHADOW_COLOR, alpha), text)
    Draw.Text(drawList, x, y, Animation.WithAlpha(color, alpha), text)
end

local function TextWidth(text)
    return ImGui.CalcTextSize(text)
end

local function Segment(text, color, gap, width)
    return { Text = text, Color = color, Gap = gap or 0, Width = width }
end

local function RowWidth(row)
    local width = 0
    for index, segment in ipairs(row) do
        width = width + (segment.Width or TextWidth(segment.Text)) + (index < #row and segment.Gap or 0)
    end
    return width
end

local function DrawPanel(drawList, rows, x, y, lineHeight, rightAligned, accent)
    if #rows == 0 then return y end
    local inset = accent and CARD_ACCENT or 0
    local width = 0
    for _, row in ipairs(rows) do width = math.max(width, RowWidth(row)) end

    local step = lineHeight + LINE_GAP
    local panelWidth = width + PANEL_PADDING * 2 + inset
    local panelHeight = #rows * step - LINE_GAP + PANEL_PADDING * 2
    local left = rightAligned and (x - panelWidth) or x
    Draw.RectFilled(drawList, left, y, panelWidth, panelHeight, Animation.WithAlpha(Style.BackgroundDark, PANEL_ALPHA), 6)
    if accent then Draw.LeftAccent(drawList, left, y, panelHeight, accent, 6, CARD_ACCENT) end

    local cursorY = y + PANEL_PADDING
    for _, row in ipairs(rows) do
        local cursorX = rightAligned and (left + panelWidth - PANEL_PADDING - RowWidth(row)) or (left + PANEL_PADDING + inset)
        for _, segment in ipairs(row) do
            ShadowText(drawList, cursorX, cursorY, segment.Color, segment.Text)
            cursorX = cursorX + (segment.Width or TextWidth(segment.Text)) + segment.Gap
        end
        cursorY = cursorY + step
    end
    return y + panelHeight
end

local function Pairs(entries, valueWidth)
    local row = {}
    for _, entry in ipairs(entries) do
        table.insert(row, Segment(entry[1], Muted(), 6))
        table.insert(row, Segment(entry[2], Style.Text, COLUMN_GAP, valueWidth))
    end
    return row
end

local function GameTime()
    local time = WorldTime.GetTime()
    return string.format("%02d:%02d:%02d", time.hours, time.minutes, time.seconds)
end

local function FormatVector(vector)
    if not vector then return "-" end
    return string.format("%.2f, %.2f, %.2f", vector.x, vector.y, vector.z)
end

local function Tagged(tag, color, text)
    return { Segment(tag, color, 0, SELECTION_TAG_WIDTH), Segment(Draw.FitText(text, SELECTION_TEXT_WIDTH), Style.Text) }
end

local function ShortcutRow()
    return {
        Segment("Ctrl+C", Style.Accent, 6), Segment("Copy", Muted(), COLUMN_GAP),
        Segment("Ctrl+X", Style.Accent, 6), Segment("Cut", Muted(), COLUMN_GAP),
        Segment("Del", Style.Accent, 6), Segment("Delete", Muted())
    }
end

local function SelectionRows()
    local selected = Selection.GetAll()
    if #selected == 0 then return {}, nil end

    if #selected == 1 then
        local only = selected[1]
        local rows = { Tagged("SELECTED", CHILD_COLOR, only.Name) }
        local entry = Attachments.Get(only.Entity)
        if entry then
            table.insert(rows, Tagged("PARENT", PARENT_COLOR, entry.ParentName))
            table.insert(rows, { Segment("Backspace to detach. Edit its offset in Scene.", Muted()) })
        else
            table.insert(rows, { Segment("Ctrl+click what it goes on to attach it.", Muted()) })
        end
        if Attachments.HasChildren(only.Entity) then table.insert(rows, { Segment("Backspace lets go of everything attached to it.", Muted()) }) end
        if not Scene.Contains(only.Entity) then table.insert(rows, { Segment("Not in Scene yet. Moving it adds it.", Muted()) }) end
        table.insert(rows, ShortcutRow())
        return rows, CHILD_COLOR
    end

    local rows = {}
    for index, entry in ipairs(selected) do
        local parent = index == #selected
        table.insert(rows, Tagged(parent and "PARENT" or "CHILD", parent and PARENT_COLOR or CHILD_COLOR, entry.Name))
    end
    local hint = Grab.CanNudge() and "Enter to attach the children to the parent." or "Close the menu, then press Enter to attach."
    table.insert(rows, { Segment(hint, Style.Accent) })
    table.insert(rows, ShortcutRow())
    return rows, PARENT_COLOR
end

local function DrawCameraInfo(drawList, lineHeight)
    local camera = Inspector.Camera
    local status = Grab.IsHolding() and (Grab.IsGrounded() and "CARRYING ON GROUND" or "CARRYING")
        or (FreeCam.IsReady() and "FREE CAM" or "STARTING")
    local rows = { { Segment("WORLD EDITOR", Style.Accent, 10), Segment(status, Muted()) } }

    if camera then
        local numberWidth = TextWidth("-00000.000")
        table.insert(rows, Pairs({
            { "X", string.format("%.3f", camera.Position.x) },
            { "Y", string.format("%.3f", camera.Position.y) },
            { "Z", string.format("%.3f", camera.Position.z) }
        }, numberWidth))
        table.insert(rows, Pairs({
            { "Yaw", string.format("%.1f", camera.Yaw) },
            { "Pitch", string.format("%.1f", camera.Pitch) },
            { "Speed", string.format("%.1f m/s", FreeCam.MoveSpeed.value * FreeCam.SpeedMultiplier) }
        }, TextWidth("000.0 m/s")))
    else
        table.insert(rows, { Segment("Waiting for camera", Muted()) })
    end

    local bottom = DrawPanel(drawList, rows, MARGIN, MARGIN, lineHeight, false, nil)
    local selectionRows, accent = SelectionRows()
    DrawPanel(drawList, selectionRows, MARGIN, bottom + PANEL_GAP, lineHeight, false, accent)
end

local function ActiveCameraText(camera)
    if not camera or not camera.ActiveError then return "-" end
    if camera.ActiveError < 1 then return "Editor" end
    return string.format("Off %.1f deg", camera.ActiveError)
end

local function DrawDebug(drawList, screenWidth, lineHeight)
    local player = Inspector.Player
    local lines = {
        GameTime(),
        "Picking " .. (Inspector.NativePicking and "Native" or "Estimate"),
        "Camera " .. ActiveCameraText(Inspector.Camera)
    }
    if player and player.CameraDistance then table.insert(lines, string.format("V %.1f m away", player.CameraDistance)) end

    local rows = {}
    for _, line in ipairs(lines) do table.insert(rows, { Segment(line, Muted()) }) end
    DrawPanel(drawList, rows, screenWidth - MARGIN, MARGIN, lineHeight, true, nil)
end

local function SelectedCollision(entity)
    local hash = Safe(function() return tostring(entity:GetEntityID().hash) end)
    local now = os.clock()
    if hash ~= s_Collision.Hash or now >= s_Collision.Next then
        s_Collision = { Hash = hash, Text = Physics.DescribeCollision(entity), Next = now + COLLISION_REFRESH }
    end
    return s_Collision.Text
end

local function AttachedTo(entity)
    local entry = entity and Attachments.Get(entity)
    return entry and entry.ParentName or nil
end

local function TargetRows(target)
    local rows = {}
    if target.Record then table.insert(rows, { "Record", target.Record }) end
    if target.Appearance then table.insert(rows, { "Appearance", target.Appearance }) end
    table.insert(rows, { "Class", target.ClassName })
    if target.AttachedTo then table.insert(rows, { "Attached To", target.AttachedTo }) end
    if target.Collision then table.insert(rows, { "Collision", target.Collision }) end
    if target.EntityHash then table.insert(rows, { "Entity", target.EntityHash }) end
    table.insert(rows, { "Position", FormatVector(target.Position) })
    return rows
end

local function SurfaceRows(hit)
    local rows = {}
    if hit.ObjectType then table.insert(rows, { "Object", hit.ObjectType }) end
    if hit.Material then table.insert(rows, { "Material", hit.Material }) end
    table.insert(rows, { "Group", hit.Group })
    table.insert(rows, { "Position", FormatVector(hit.Position) })
    table.insert(rows, { "Normal", FormatVector(hit.Normal) })
    return rows
end

local function MapGeometryName(hit)
    local objectType = hit and hit.ObjectType
    if not objectType then return nil end
    local name = objectType:match("^world(.+)NodeInstance$")
    if not name then return nil end
    return (name:gsub("(%l)(%u)", "%1 %2"))
end

local function CardContent()
    local holding = Grab.GetTarget()
    if holding then
        local kind = Picker.Kinds[holding.Kind] or Picker.Kinds.Prop
        return {
            Label = "CARRYING " .. string.upper(kind.Label),
            Title = holding.DisplayName or holding.Record or holding.ClassName,
            Distance = string.format("%.1f m", Grab.GetDistance()),
            Color = kind.Color,
            Rows = TargetRows(holding)
        }
    end

    local target = Inspector.Target
    if target then
        local kind = Picker.Kinds[target.Kind]
        return {
            Label = string.upper(kind.Label),
            Title = target.DisplayName or target.Record or target.ClassName,
            Distance = target.Distance and string.format("%.1f m", target.Distance),
            Color = kind.Color,
            Rows = TargetRows(target)
        }
    end

    local selected = Selection.Get()
    if selected then
        local kind = Picker.Kinds[selected.Kind] or Picker.Kinds.Prop
        return {
            Label = "SELECTED " .. string.upper(kind.Label),
            Title = selected.Name,
            Color = kind.Color,
            Rows = TargetRows({
                Record = selected.Record,
                Appearance = selected.Appearance,
                ClassName = selected.ClassName or "Unknown",
                EntityHash = selected.EntityHash,
                Collision = SelectedCollision(selected.Entity),
                AttachedTo = AttachedTo(selected.Entity),
                Position = Selection.GetPosition()
            })
        }
    end

    local hit = Inspector.Hit
    local geometry = MapGeometryName(hit)
    if geometry then
        local rows = SurfaceRows(hit)
        table.insert(rows, 1, { "Selectable", "No, baked into the map" })
        return {
            Label = "MAP GEOMETRY",
            Title = geometry,
            Distance = string.format("%.1f m", hit.Distance),
            Color = Picker.Kinds.Surface.Color,
            Rows = rows
        }
    end

    if hit then
        return {
            Label = "SURFACE",
            Title = hit.ObjectType or hit.Material or hit.Group,
            Distance = string.format("%.1f m", hit.Distance),
            Color = Picker.Kinds.Surface.Color,
            Rows = SurfaceRows(hit)
        }
    end
    return nil
end

local function DrawCard(drawList, screenWidth, screenHeight, lineHeight, deltaTime)
    local content = CardContent()
    s_CardAlpha = Animation.Animate(s_CardAlpha, content and 1 or 0, FADE_SPEED, deltaTime)
    if content then s_Card = content end
    if s_CardAlpha < 0.02 or not s_Card then return end

    local card = s_Card
    local alpha = s_CardAlpha
    local height = CARD_PADDING * 2 + (lineHeight + LINE_GAP) * (2 + #card.Rows) + 4
    local x = screenWidth - MARGIN - CARD_WIDTH
    local y = screenHeight - MARGIN - height

    Draw.RectFilled(drawList, x, y, CARD_WIDTH, height, Animation.WithAlpha(Style.BackgroundDark, 0.45 * alpha), 6)
    Draw.LeftAccent(drawList, x, y, height, Animation.WithAlpha(card.Color, alpha), 6, CARD_ACCENT)

    local contentX = x + CARD_PADDING + CARD_ACCENT
    local contentWidth = CARD_WIDTH - CARD_PADDING * 2 - CARD_ACCENT
    local cursorY = y + CARD_PADDING

    ShadowText(drawList, contentX, cursorY, card.Color, card.Label, alpha)
    if card.Distance then ShadowText(drawList, contentX + contentWidth - TextWidth(card.Distance), cursorY, Muted(), card.Distance, alpha) end
    cursorY = cursorY + lineHeight + LINE_GAP

    ShadowText(drawList, contentX, cursorY, Style.Text, Draw.FitText(card.Title or "-", contentWidth), alpha)
    cursorY = cursorY + lineHeight + LINE_GAP + 4

    local labelWidth = contentWidth * 0.3
    for _, row in ipairs(card.Rows) do
        ShadowText(drawList, contentX, cursorY, Muted(), row[1], alpha)
        ShadowText(drawList, contentX + labelWidth, cursorY, Style.Text, Draw.FitText(row[2], contentWidth - labelWidth), alpha)
        cursorY = cursorY + lineHeight + LINE_GAP
    end
end

local function TargetColor()
    local holding = Grab.GetTarget()
    if holding then return (Picker.Kinds[holding.Kind] or Picker.Kinds.Prop).Color end
    local target = Inspector.Target
    if target then return Picker.Kinds[target.Kind].Color end
    if Inspector.Hit then return Picker.Kinds.Surface.Color end
    return IDLE_COLOR
end

local function DrawBrackets(drawList, centerX, centerY, size, color, shadow)
    for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        local x, y = centerX + corner[1] * size, centerY + corner[2] * size
        local endX, endY = x - corner[1] * BRACKET_LENGTH, y - corner[2] * BRACKET_LENGTH
        Draw.Line(drawList, x + 1, y + 1, endX + 1, y + 1, shadow, 3)
        Draw.Line(drawList, x + 1, y + 1, x + 1, endY + 1, shadow, 3)
        Draw.Line(drawList, x, y, endX, y, color, 2)
        Draw.Line(drawList, x, y, x, endY, color, 2)
    end
end

local function DrawCrosshair(drawList, screenWidth, screenHeight, deltaTime)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.5
    local locked = Inspector.Target ~= nil or Grab.IsHolding()
    s_Lock = Animation.Animate(s_Lock, locked and 1 or 0, LOCK_SPEED, deltaTime)
    s_LockColor = Animation.LerpColor(s_LockColor, TargetColor(), math.min(1, LOCK_SPEED * (deltaTime or 0)))

    local color = s_LockColor
    local shadow = Style.Shadow
    local gap = CROSSHAIR_GAP + s_Lock * 2
    local reach = gap + CROSSHAIR_SIZE * (1 - s_Lock * 0.4)

    for _, line in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        local x1, y1 = centerX + line[1] * gap, centerY + line[2] * gap
        local x2, y2 = centerX + line[1] * reach, centerY + line[2] * reach
        Draw.Line(drawList, x1 + 1, y1 + 1, x2 + 1, y2 + 1, shadow, 3)
        Draw.Line(drawList, x1, y1, x2, y2, color, 2)
    end
    Draw.RectFilled(drawList, centerX - 1, centerY - 1, 2, 2, color, 0)

    if s_Lock < 0.02 then return end
    DrawBrackets(drawList, centerX, centerY, BRACKET_IDLE + (BRACKET_LOCKED - BRACKET_IDLE) * s_Lock,
        Animation.WithAlpha(color, s_Lock), Animation.WithAlpha(shadow, s_Lock))
end

local function Project(point, screenWidth, screenHeight)
    local ok, projected = pcall(function()
        return Game.GetCameraSystem():ProjectPoint(Vector4.new(point.x, point.y, point.z, 1.0))
    end)
    if not ok or not projected then return nil end

    local x, y, w = projected.x, projected.y, projected.w
    if w and w ~= 0 then
        if w < 0 then return nil end
        x, y = x / w, y / w
    end
    if math.abs(x) > 4 or math.abs(y) > 4 then return nil end
    return screenWidth * 0.5 * (1 + x), screenHeight * 0.5 * (1 - y)
end

local function DrawBox(drawList, entity, color, screenWidth, screenHeight)
    local bounds = Grabbables.GetBounds(entity)
    local position, rotation = Grabbables.GetPose(entity)
    if not bounds or not position then return end

    local corners = {}
    for index = 0, 7 do
        local corner = {
            x = (index % 2 == 1) and bounds.Max.x or bounds.Min.x,
            y = (math.floor(index / 2) % 2 == 1) and bounds.Max.y or bounds.Min.y,
            z = (math.floor(index / 4) % 2 == 1) and bounds.Max.z or bounds.Min.z
        }
        local sx, sy = Project(Grabbables.ToWorld(position, rotation, corner), screenWidth, screenHeight)
        if not sx then return end
        corners[index + 1] = { sx, sy }
    end

    local edgeColor = Animation.WithAlpha(color, BOX_ALPHA)
    for _, edge in ipairs(EDGES) do
        local a, b = corners[edge[1]], corners[edge[2]]
        Draw.Line(drawList, a[1] + 1, a[2] + 1, b[1] + 1, b[2] + 1, SHADOW_COLOR, 2.5)
        Draw.Line(drawList, a[1], a[2], b[1], b[2], edgeColor, 1.5)
    end
end

local function DrawMarker(drawList, x, y, color)
    local points = { { x, y - MARKER_SIZE }, { x + MARKER_SIZE, y }, { x, y + MARKER_SIZE }, { x - MARKER_SIZE, y } }
    for index = 1, 4 do
        local a, b = points[index], points[index % 4 + 1]
        Draw.Line(drawList, a[1] + 1, a[2] + 1, b[1] + 1, b[2] + 1, SHADOW_COLOR, 3)
        Draw.Line(drawList, a[1], a[2], b[1], b[2], color, 2)
    end
    Draw.RectFilled(drawList, x - 1, y - 1, 2, 2, color, 0)
end

local function FocusEntity()
    local holding = Grab.GetTarget()
    if holding then return holding.Entity, holding.Kind end
    local target = Inspector.Target
    if target and target.Entity then return target.Entity, target.Kind end
    return nil
end

local function DrawLink(drawList, from, to, color, screenWidth, screenHeight)
    local x1, y1 = Project(from, screenWidth, screenHeight)
    local x2, y2 = Project(to, screenWidth, screenHeight)
    if not x1 or not x2 then return end
    Draw.Line(drawList, x1 + 1, y1 + 1, x2 + 1, y2 + 1, SHADOW_COLOR, 2.5)
    Draw.Line(drawList, x1, y1, x2, y2, color, 1.5)
    DrawMarker(drawList, x2, y2, color)
end

local function DrawAttachmentLinks(drawList, screenWidth, screenHeight)
    local color = Animation.WithAlpha(Style.Accent, LINK_ALPHA)
    for _, entry in ipairs(Attachments.GetEntries()) do
        local child = Safe(function() return entry.Child:GetWorldPosition() end)
        local parent = Safe(function() return entry.Parent:GetWorldPosition() end)
        if child and parent then DrawLink(drawList, child, parent, color, screenWidth, screenHeight) end
    end

    local selected = Selection.GetAll()
    if #selected < 2 then return end
    local pending = Animation.WithAlpha(PARENT_COLOR, LINK_ALPHA)
    local parent = Safe(function() return selected[#selected].Entity:GetWorldPosition() end)
    for index = 1, #selected - 1 do
        local child = Safe(function() return selected[index].Entity:GetWorldPosition() end)
        if child and parent then DrawLink(drawList, child, parent, pending, screenWidth, screenHeight) end
    end
end

local function DrawWorldOverlay(drawList, screenWidth, screenHeight)
    local focus, kind = FocusEntity()
    local focusHash = focus and Safe(function() return tostring(focus:GetEntityID().hash) end)

    if Hud.ShowGrabMarkers.value then
        local color = Animation.WithAlpha(Picker.Kinds.Prop.Color, MARKER_ALPHA)
        for _, entry in ipairs(Grabbables.GetEntries()) do
            if entry.Hash ~= focusHash then
                local x, y = Project(entry.Center, screenWidth, screenHeight)
                if x then DrawMarker(drawList, x, y, color) end
            end
        end
    end

    if Hud.ShowTargetBox.value and focus and Grabbables.HasNativeBounds() then
        DrawBox(drawList, focus, (Picker.Kinds[kind] or Picker.Kinds.Prop).Color, screenWidth, screenHeight)
    end

    if Hud.ShowAttachmentLinks.value then DrawAttachmentLinks(drawList, screenWidth, screenHeight) end
end

local function WithPaste(controls)
    if Clipboard.Count() == 0 then return controls end
    local list = {}
    for _, control in ipairs(controls) do table.insert(list, control) end
    table.insert(list, { "Ctrl+V", "Paste " .. Clipboard.Count() })
    return list
end

local function CurrentControls()
    if Grab.IsHolding() then return CONTROLS_HOLDING end
    local selected = Selection.GetAll()
    if #selected == 0 then return WithPaste(CONTROLS) end

    if #selected > 1 then
        return WithPaste({ { "Enter", "Attach To " .. Draw.FitText(selected[#selected].Name, 180) }, { "Ctrl+Click", "Add / Remove" }, { "Click", "Select One" } })
    end

    local controls = {}
    for _, control in ipairs(Grab.CanNudge() and CONTROLS_SELECTED or CONTROLS_SELECTED_MENU) do table.insert(controls, control) end
    if Attachments.IsAttached(selected[1].Entity) or Attachments.HasChildren(selected[1].Entity) then
        table.insert(controls, { "Backspace", "Detach" })
    end
    if not Attachments.IsAttached(selected[1].Entity) then table.insert(controls, { "Ctrl+Click", "Pick Parent" }) end
    return WithPaste(controls)
end

local function DrawControls(drawList, screenWidth, screenHeight, lineHeight)
    local row = {}
    for _, control in ipairs(CurrentControls()) do
        table.insert(row, Segment(control[1], Style.Accent, 6))
        table.insert(row, Segment(control[2], Muted(), COLUMN_GAP))
    end

    local width = RowWidth(row) + PANEL_PADDING * 2
    local height = lineHeight + PANEL_PADDING * 2
    DrawPanel(drawList, { row }, (screenWidth - width) * 0.5, screenHeight - MARGIN - height, lineHeight, false, nil)
end

local function DrawContents(deltaTime, screenWidth, screenHeight)
    local drawList = ImGui.GetWindowDrawList()
    local lineHeight = ImGui.GetTextLineHeight()

    DrawWorldOverlay(drawList, screenWidth, screenHeight)

    if Hud.ShowCrosshair.value then DrawCrosshair(drawList, screenWidth, screenHeight, deltaTime) end
    if Hud.ShowInfo.value then
        DrawCameraInfo(drawList, lineHeight)
        DrawCard(drawList, screenWidth, screenHeight, lineHeight, deltaTime)
    end
    if Hud.ShowDebug.value then DrawDebug(drawList, screenWidth, lineHeight) end
    if Hud.ShowControls.value then DrawControls(drawList, screenWidth, screenHeight, lineHeight) end
end

function Hud.Render(deltaTime)

    local screenWidth, screenHeight = GetDisplayResolution()
    ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)
    ImGui.SetNextWindowSize(screenWidth, screenHeight, ImGuiCond.Always)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    ImGui.Begin("##EasyTrainerWorldEditorHud", ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoSavedSettings
        + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar
        + ImGuiWindowFlags.NoScrollWithMouse + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoFocusOnAppearing
        + ImGuiWindowFlags.NoBringToFrontOnFocus)

    Layout.ApplyFontScale()
    local ok, err = pcall(DrawContents, deltaTime, screenWidth, screenHeight)
    if not ok and not s_ErrorLogged then
        s_ErrorLogged = true
        Logger.Log("WorldEditor HUD: " .. tostring(err))
    end

    ImGui.End()
    ImGui.PopStyleVar()
    ImGui.PopStyleColor()
end

return Hud
