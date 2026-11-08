local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local ToggleStyle = require("Widgets/Toggle/ToggleStyle")

local Toggle = {}

function Toggle.ControlWidth()
    if ToggleStyle.Shape == ToggleStyle.Shapes.Light then return Scale.S(ToggleStyle.LightRadius * 2) end
    if ToggleStyle.Shape == ToggleStyle.Shapes.Orbit then return Scale.S(ToggleStyle.OrbitRingRadius * 2) end
    return Scale.S(ToggleStyle.TrackWidth)
end

local function DrawOrbit(data, on, value)
    local dotRadius = Scale.S(ToggleStyle.OrbitDotRadius)
    local ringRadius = Scale.S(ToggleStyle.OrbitRingRadius)

    local cx = data.X + data.Width - Scale.S(Layout.Padding) - ringRadius
    local cy = data.Y + (data.Height * 0.5)

    local accent = Style.Accent

    local radius = Animation.Lerp(ringRadius * ToggleStyle.OrbitExitScale, ringRadius, on)
    if value then radius = Animation.Lerp(dotRadius, ringRadius, on) end

    if on > 0.01 then
        Draw.Circle(cx, cy, radius, Draw.WithAlpha(accent, on), Scale.S(ToggleStyle.OrbitRingThickness))
    end

    Draw.CircleFilled(cx, cy, dotRadius, Animation.LerpColor(ToggleStyle.OrbitDotOff, accent, on))
end

local function DrawSwitch(data, on)
    local width = Scale.S(ToggleStyle.TrackWidth)
    local height = Scale.S(ToggleStyle.TrackHeight)
    local inset = Scale.S(ToggleStyle.KnobInset)
    local radius = height * 0.5

    local x = data.X + data.Width - Scale.S(Layout.Padding) - width
    local y = data.Y + ((data.Height - height) * 0.5)

    local track = Animation.LerpColor(ToggleStyle.TrackOff, Style.Accent, on)
    local border = Animation.LerpColor(ToggleStyle.TrackBorderOff, Style.Accent, on)
    Draw.RectFilled(x, y, width, height, track, radius)
    Draw.Rect(x, y, width, height, border, radius)

    local knobRadius = radius - inset
    local knobX = Animation.Lerp(x + inset + knobRadius, x + width - inset - knobRadius, on)

    Draw.CircleFilled(knobX, y + radius, knobRadius, Animation.LerpColor(ToggleStyle.KnobOff, ToggleStyle.KnobOn, on))
end

local function DrawLight(data, on)
    local radius = Scale.S(ToggleStyle.LightRadius)
    local glowRadius = Scale.S(ToggleStyle.LightGlowRadius)

    local cx = data.X + data.Width - Scale.S(Layout.Padding) - radius
    local cy = data.Y + (data.Height * 0.5)

    local accent = Style.Accent
    local layers = math.max(1, ToggleStyle.LightGlowLayers)

    if on > 0.01 then
        for layer = layers, 1, -1 do
            local t = layer / layers
            local layerRadius = Animation.Lerp(radius, glowRadius, t)
            local alpha = ToggleStyle.LightGlowAlpha * on * (1 - t)

            Draw.CircleFilled(cx, cy, layerRadius, Draw.WithAlpha(accent, alpha))
        end
    end

    local core = Animation.LerpColor(ToggleStyle.LightCoreOff, accent, on)
    local ring = Animation.LerpColor(ToggleStyle.LightRingOff, accent, on)

    Draw.CircleFilled(cx, cy, radius, core)
    Draw.Circle(cx, cy, radius, ring, 1)
end

function Toggle.Animate(state, value)
    local speed = ToggleStyle.SlideSpeed
    if ToggleStyle.Shape == ToggleStyle.Shapes.Orbit then speed = ToggleStyle.OrbitSpeed end
    return Row.Value(state, "Toggle", value and 1 or 0, speed)
end

function Toggle.DrawControl(data, on, value)
    if ToggleStyle.Shape == ToggleStyle.Shapes.Light then
        DrawLight(data, on)
    elseif ToggleStyle.Shape == ToggleStyle.Shapes.Orbit then
        DrawOrbit(data, on, value)
    else
        DrawSwitch(data, on)
    end
end

function Toggle.Draw(label, ref)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)
    Widget.Bindable(data, label, Widget.Kinds.Toggle)

    if data.Activated then ref.Value = not ref.Value end

    local on = Toggle.Animate(state, ref.Value)

    if data.Selected then
        Highlight.SetHint(Highlight.SelectHint(), Toggle.ControlWidth() + Scale.S(ToggleStyle.HintGap))
    end

    if not data.Visible then return data.Activated end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label, on * ToggleStyle.LabelBoost)
    Toggle.DrawControl(data, on, ref.Value)

    return data.Activated
end

return Toggle
