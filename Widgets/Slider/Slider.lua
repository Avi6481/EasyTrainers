local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Highlight = require("Widgets/Core/Highlight")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local Row = require("Widgets/Core/Row")
local TextField = require("Widgets/Core/TextField")
local Widget = require("Widgets/Core/Widget")
local Toggle = require("Widgets/Toggle/Toggle")
local ToggleStyle = require("Widgets/Toggle/ToggleStyle")
local SliderStyle = require("Widgets/Slider/SliderStyle")

local Slider = {}

local ACTION_ICON_SCALE = 0.6
local EDIT_LENGTH = 24

local s_DragId = nil
local s_FilterInt = false
local s_FilterNegative = false

local function Round(value)
    return math.floor(value + 0.5)
end

local function FormatValue(value, range)
    if range.IsInt then return string.format(range.Format, Round(value)) end
    return string.format(range.Format, value)
end

local function PlainValue(value, range)
    if range.IsInt then return string.format("%d", Round(value)) end
    return string.format("%g", value)
end

local function Snap(value, range)
    value = Animation.Clamp(value, range.Min, range.Max)

    if range.Step > 0 then
        value = range.Min + (Round((value - range.Min) / range.Step) * range.Step)
    end

    value = Animation.Clamp(value, range.Min, range.Max)
    if range.IsInt then return Round(value) end
    return value
end

local function Fraction(value, range)
    if range.Max <= range.Min then return 0 end
    return Animation.Clamp((value - range.Min) / (range.Max - range.Min), 0, 1)
end

local function NumberFilter(character, buffer)
    if character:match("^%d$") then return true end
    if character == "." and not s_FilterInt then return buffer:find(".", 1, true) == nil end
    if character == "-" and s_FilterNegative then return buffer == "" end
    return false
end

local function BeginEdit(id, value, range)
    s_FilterInt = range.IsInt
    s_FilterNegative = range.Min < 0
    TextField.Begin(id, PlainValue(value, range), EDIT_LENGTH, NumberFilter)
end

local function EndEdit()
    TextField.End()
end

local function UpdateEdit(value, range)
    local result = TextField.Update()
    if result == TextField.Result.None then return false, value end

    if result == TextField.Result.Cancelled then
        EndEdit()
        return false, value
    end

    local text = TextField.Text()
    EndEdit()

    local parsed = tonumber(text)
    if text == "" or parsed == nil then return false, value end

    local snapped = Animation.Clamp(parsed, range.Min, range.Max)
    if range.IsInt then snapped = Round(snapped) end
    if snapped == value then return false, value end

    return true, snapped
end

local function ArrowHint()
    return Icons.Get("ArrowLeft") .. " " .. Icons.Get("ArrowRight")
end

local function AdjustHint()
    local device = State.Device.Device

    if device == State.Devices.Controller then
        if not HighlightStyle.ShowControllerHint then return nil end
        return ArrowHint()
    end

    if device == State.Devices.Keyboard then
        if not HighlightStyle.ShowKeyboardHint then return nil end
        return ArrowHint()
    end

    if not HighlightStyle.ShowMouseHint then return nil end
    if State.Menu.Cursor then return "Drag" end
    return "Shift + Wheel"
end

local function MeasureLayout(data, text, hasToggle, editing)
    local padding = Scale.S(Layout.Padding)
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local chevronShape = SliderStyle.Shape == SliderStyle.Shapes.Chevron

    local layout = {}
    layout.Right = data.X + data.Width - padding
    local reserveToggle = hasToggle or (chevronShape and SliderStyle.AlignWithToggles)

    if SliderStyle.Shape == SliderStyle.Shapes.Ring then
        layout.Right = layout.Right - Scale.S(SliderStyle.RingRadius * 2) - Scale.S(SliderStyle.ValueGap)
    elseif reserveToggle then
        layout.Right = layout.Right - Toggle.ControlWidth() - Scale.S(SliderStyle.ValueGap)
    end

    local textWidth = Draw.TextSize(text, valueSize)
    if editing then textWidth = TextField.Width(nil, valueSize) end

    layout.ValueWidth = textWidth
    layout.ValueX = layout.Right - textWidth
    layout.ControlLeft = layout.ValueX
    layout.LeftChevronX = 0
    layout.RightChevronX = 0

    if chevronShape then
        local chevron = Scale.S(SliderStyle.ChevronSize)
        local gap = Scale.S(SliderStyle.ChevronGap)

        layout.ValueWidth = textWidth
        if not editing then layout.ValueWidth = math.max(textWidth, Scale.S(SliderStyle.UnderlineMinWidth)) end

        layout.RightChevronX = layout.Right - (chevron * 0.5)
        layout.ValueX = layout.Right - chevron - gap - layout.ValueWidth
        layout.LeftChevronX = layout.ValueX - gap - (chevron * 0.5)
        layout.ControlLeft = layout.ValueX - gap - chevron

        if not hasToggle and reserveToggle and not editing then
            local extra = Toggle.ControlWidth() + Scale.S(SliderStyle.ValueGap)

            layout.ValueWidth = layout.ValueWidth + extra
            layout.Right = layout.Right + extra
            layout.RightChevronX = layout.RightChevronX + extra
        end
    end

    layout.TrackX = data.X + padding
    layout.TrackWidth = data.Width - (padding * 2)
    layout.TrackY = data.Y + data.Height - Scale.S(SliderStyle.TrackBottom)
    return layout
end

local function UpdateDrag(data, layout, value, range)
    if not SliderStyle.DragEnabled or not State.Menu.Cursor then
        s_DragId = nil
        return false, value
    end

    local mouseX = Input.MousePos()

    if data.Hovered and Input.MousePressed(Input.Mouse.Left) and mouseX < layout.ControlLeft - Scale.S(SliderStyle.ValueGap) then
        s_DragId = data.Id
    end

    if s_DragId ~= data.Id then return false, value end

    if not Input.MouseDown(Input.Mouse.Left) then
        s_DragId = nil
        return false, value
    end

    local t = Animation.Clamp((mouseX - layout.TrackX) / math.max(1, layout.TrackWidth), 0, 1)
    local dragged = Snap(range.Min + (t * (range.Max - range.Min)), range)
    if dragged == value then return false, value end

    return true, dragged
end

local function DrawTrack(data, state, layout, fill, alpha)
    if not SliderStyle.ShowTrack then return end

    local height = Scale.S(SliderStyle.TrackHeight)
    local y = layout.TrackY - (height * 0.5)
    local fillWidth = layout.TrackWidth * fill
    local accent = Draw.ScaleAlpha(Style.Accent, alpha)

    Draw.RectFilled(layout.TrackX, y, layout.TrackWidth, height, Draw.ScaleAlpha(SliderStyle.TrackOff, alpha), height * 0.5)

    if fillWidth > 0.5 then
        Draw.RectFilled(layout.TrackX, y, fillWidth, height, accent, height * 0.5)
    end

    local thumb = Scale.S(Animation.Lerp(SliderStyle.ThumbRadius, SliderStyle.ThumbSelectedRadius, state.Select))
    Draw.CircleFilled(layout.TrackX + fillWidth, layout.TrackY, thumb, accent)
end

local function DrawChevronMark(cx, cy, size, left, color, thickness)
    local tip = cx + (size * 0.5)
    local back = cx - (size * 0.5)
    if left then
        tip = cx - (size * 0.5)
        back = cx + (size * 0.5)
    end

    Draw.Line(back, cy - size, tip, cy, color, thickness)
    Draw.Line(tip, cy, back, cy + size, color, thickness)
end

local function DrawChevronSlider(data, state, layout, text, fill, alpha)
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local textWidth, textHeight = Draw.TextSize(text, valueSize)

    local lineHeight = Scale.S(SliderStyle.UnderlineHeight)
    local lineGap = Scale.S(SliderStyle.UnderlineGap)
    local centerY = data.Y + (data.Height * 0.5)
    local top = centerY - (textHeight * 0.5) - Scale.S(SliderStyle.ValueLift)

    local textColor = Animation.LerpColor(Style.TextSoft, Style.Text, math.max(state.Select, state.Hover))
    local textX = layout.ValueX + ((layout.ValueWidth - textWidth) * Animation.Clamp(SliderStyle.ValueAlign, 0, 1))
    Draw.Text(textX, top, Draw.ScaleAlpha(textColor, alpha), text, valueSize)

    local lineY = top + textHeight + lineGap
    Draw.RectFilled(layout.ValueX, lineY, layout.ValueWidth, lineHeight, Draw.ScaleAlpha(SliderStyle.TrackOff, alpha), lineHeight * 0.5)

    local fillWidth = layout.ValueWidth * fill
    if fillWidth > 0.5 then
        Draw.RectFilled(layout.ValueX, lineY, fillWidth, lineHeight, Draw.ScaleAlpha(Style.Accent, alpha), lineHeight * 0.5)
    end

    local chevronAlpha = 1
    if SliderStyle.ChevronsOnSelectOnly then chevronAlpha = math.max(state.Select, state.Hover) end
    if chevronAlpha < 0.01 then return end

    local chevronColor = Draw.ScaleAlpha(Style.TextDisabled, chevronAlpha * alpha)
    local chevron = Scale.S(SliderStyle.ChevronSize)
    local thickness = Scale.S(SliderStyle.ChevronThickness)

    DrawChevronMark(layout.LeftChevronX, centerY, chevron, true, chevronColor, thickness)
    DrawChevronMark(layout.RightChevronX, centerY, chevron, false, chevronColor, thickness)
end

local function DrawRing(data, fill, hasToggle, enabled, on, alpha)
    local radius = Scale.S(SliderStyle.RingRadius)
    local thickness = Scale.S(SliderStyle.RingThickness)
    local dotRadius = Scale.S(SliderStyle.RingDotRadius)

    local cx = data.X + data.Width - Scale.S(Layout.Padding) - radius
    local cy = data.Y + (data.Height * 0.5)

    local accent = Style.Accent
    local top = -math.pi * 0.5

    Draw.Circle(cx, cy, radius, SliderStyle.RingOff, thickness)

    if fill > 0.001 then
        Draw.Arc(cx, cy, radius, top, top + (fill * math.pi * 2), Draw.ScaleAlpha(accent, alpha), thickness)
    end

    if not hasToggle then return end

    if on > 0.01 and on < 0.99 then
        local pulseRadius = Animation.Lerp(radius * ToggleStyle.OrbitExitScale, radius, on)
        local pulseAlpha = on
        if enabled then
            pulseRadius = Animation.Lerp(dotRadius, radius, on)
            pulseAlpha = 1 - on
        end

        Draw.Circle(cx, cy, pulseRadius, Draw.ScaleAlpha(accent, pulseAlpha), Scale.S(ToggleStyle.OrbitRingThickness))
    end

    Draw.CircleFilled(cx, cy, dotRadius, Animation.LerpColor(ToggleStyle.OrbitDotOff, accent, on))
end

local function DrawValue(data, state, layout, text, editing, alpha)
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local centerY = data.Y + (data.Height * 0.5)

    if editing then
        TextField.DrawBox(layout.ValueX, centerY, layout.ValueWidth, valueSize)
        return
    end

    local color = Animation.LerpColor(Style.TextSoft, Style.Text, math.max(state.Select, state.Hover))
    local _, textHeight = Draw.TextSize(text, valueSize)
    Draw.Text(layout.ValueX, centerY - (textHeight * 0.5), Draw.ScaleAlpha(color, alpha), text, valueSize)
end

local function DrawActionIcon(data, state, icon)
    local rowRight = data.X + data.Width - Scale.S(Layout.Padding)
    local columnCenter = rowRight - (Toggle.ControlWidth() * 0.5)
    local centerY = data.Y + (data.Height * 0.5)
    local active = math.max(state.Select, state.Hover)

    local size = Scale.FontSize() * ACTION_ICON_SCALE
    local iconWidth, iconHeight = Draw.TextSize(icon, size)
    local color = Animation.LerpColor(Style.TextDisabled, Style.Text, active * 0.6)
    Draw.Text(columnCenter - (iconWidth * 0.5), centerY - (iconHeight * 0.5), color, icon, size)
end

local function SliderCore(label, value, range, enabled, actionIcon, action)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local hasToggle = enabled ~= nil
    if hasToggle then Widget.Bindable(data, label, Widget.Kinds.Slider) end
    if action then Widget.Bindable(data, label, Widget.Kinds.Action) end
    local reserve = hasToggle or action
    local editing = TextField.Active(data.Id)
    local changed = false
    local fired = false

    local layout = MeasureLayout(data, FormatValue(value, range), reserve, editing)
    local mouseX = Input.MousePos()

    if editing then
        if not data.Selected then
            EndEdit()
        else
            changed, value = UpdateEdit(value, range)
        end
    else
        local chevrons = SliderStyle.Shape == SliderStyle.Shapes.Chevron
        local valueRight = layout.Right
        if chevrons then valueRight = layout.ValueX + layout.ValueWidth end

        local keyActivate = data.Activated and not data.Clicked
        local clickToggle = data.Clicked and hasToggle and mouseX > layout.Right
        local clickValue = data.Clicked and SliderStyle.ClickValueToType and mouseX >= layout.ValueX and mouseX <= valueRight
        local clickLeft = chevrons and data.Clicked and mouseX >= layout.ControlLeft and mouseX < layout.ValueX
        local clickRight = chevrons and data.Clicked and mouseX > valueRight and mouseX <= layout.Right

        if clickLeft or clickRight then
            local direction = -1
            if clickRight then direction = 1 end

            local stepped = Snap(value + (direction * range.Step), range)
            changed = stepped ~= value
            value = stepped
        elseif (keyActivate or (data.Clicked and mouseX > layout.Right)) and action then
            fired = true
        elseif (keyActivate or clickToggle) and hasToggle then
            enabled.Value = not enabled.Value
            changed = true
        elseif (keyActivate and not hasToggle) or clickValue or (data.Selected and Navigation.State.EditPressed) then
            BeginEdit(data.Id, value, range)
        end

        local adjust = 0
        if data.Selected then adjust = Navigation.State.Adjust end

        if adjust ~= 0 then
            local adjusted = Snap(value + (adjust * range.Step), range)
            changed = changed or adjusted ~= value
            value = adjusted
        end

        local dragged = false
        dragged, value = UpdateDrag(data, layout, value, range)
        changed = dragged or changed
    end

    editing = TextField.Active(data.Id)
    local text = FormatValue(value, range)
    layout = MeasureLayout(data, text, reserve, editing)

    if data.Selected then
        local inset = (data.X + data.Width - Scale.S(Layout.Padding)) - layout.ControlLeft + Scale.S(SliderStyle.ValueGap)
        local hint = nil
        if editing then
            hint = "Enter"
        elseif action then
            hint = Highlight.SelectHint()
        else
            hint = AdjustHint()
        end
        Highlight.SetHint(hint, inset)
    end

    local on = 1
    if hasToggle then on = Toggle.Animate(state, enabled.Value) end

    local fill = Row.Value(state, "Fill", Fraction(value, range), SliderStyle.ValueSpeed)
    local alpha = Animation.Lerp(SliderStyle.DisabledAlpha, 1, on)

    if not data.Visible then return changed, value, fired end

    local emphasis = 0
    if hasToggle then emphasis = on * ToggleStyle.LabelBoost end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, emphasis)

    if SliderStyle.Shape == SliderStyle.Shapes.Chevron then
        if editing then
            DrawValue(data, state, layout, text, editing, alpha)
        else
            DrawChevronSlider(data, state, layout, text, fill, alpha)
        end

        if hasToggle then
            Toggle.DrawControl(data, on, enabled.Value)
        elseif action then
            DrawActionIcon(data, state, actionIcon)
        end

        return changed, value, fired
    end

    DrawValue(data, state, layout, text, editing, alpha)

    if SliderStyle.Shape == SliderStyle.Shapes.Ring then
        DrawRing(data, fill, hasToggle, hasToggle and enabled.Value, on, alpha)
        return changed, value, fired
    end

    DrawTrack(data, state, layout, fill, alpha)

    if hasToggle then
        Toggle.DrawControl(data, on, enabled.Value)
    elseif action then
        DrawActionIcon(data, state, actionIcon)
    end

    return changed, value, fired
end

local function IntRange(min, max, step, format)
    return { Min = min, Max = max, Step = step or 1, IsInt = true, Format = format or "%d" }
end

local function FloatRange(min, max, step, format)
    return { Min = min, Max = max, Step = step or 0.1, IsInt = false, Format = format or "%.1f" }
end

function Slider.Int(label, ref, min, max, step, format, enabled)
    local changed, value = SliderCore(label, ref.Value, IntRange(min, max, step, format), enabled, nil, false)
    ref.Value = Round(value)
    return changed
end

function Slider.Float(label, ref, min, max, step, format, enabled)
    local changed, value = SliderCore(label, ref.Value, FloatRange(min, max, step, format), enabled, nil, false)
    ref.Value = value
    return changed
end

function Slider.NumberActionInt(label, ref, min, max, step, format, icon)
    local _, value, fired = SliderCore(label, ref.Value, IntRange(min, max, step, format), nil, icon or Icons.Get("Play"), true)
    ref.Value = Round(value)
    return fired
end

function Slider.NumberActionFloat(label, ref, min, max, step, format, icon)
    local _, value, fired = SliderCore(label, ref.Value, FloatRange(min, max, step, format), nil, icon or Icons.Get("Play"), true)
    ref.Value = value
    return fired
end

return Slider
