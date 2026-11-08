local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local ButtonStyle = require("Widgets/Button/ButtonStyle")

local Row = {}

local s_States = {}

function Row.Animate(data)
    local select = data.Selected and 1 or 0
    local hover = (data.Hovered and not data.Selected) and 1 or 0
    local press = data.Held and 1 or 0

    local state = s_States[data.Id]
    if not state then
        state = { Select = select, Hover = hover, Press = press }
        s_States[data.Id] = state
        return state
    end

    local delta = Animation.Delta()
    state.Select = Animation.Animate(state.Select, select, ButtonStyle.SelectSpeed, delta)
    state.Hover = Animation.Animate(state.Hover, hover, ButtonStyle.HoverSpeed, delta)
    state.Press = Animation.Animate(state.Press, press, ButtonStyle.PressSpeed, delta)
    return state
end

function Row.Value(state, key, target, speed)
    local current = state[key]
    if current == nil then
        state[key] = target
        return target
    end

    current = Animation.Animate(current, target, speed, Animation.Delta())
    state[key] = current
    return current
end

function Row.DrawBackground(data, state)
    if state.Hover < 0.01 then return end
    local color = Draw.ScaleAlpha(Style.BackgroundLight, state.Hover * ButtonStyle.HoverAlpha)
    Draw.RectFilled(data.X, data.Y, data.Width, data.Height, color, Scale.S(ButtonStyle.HoverRounding))
end

local function Fit(state, label, width, size)
    if state.LabelText ~= label or state.LabelWidth ~= width or state.LabelSize ~= size then
        state.LabelText = label
        state.LabelWidth = width
        state.LabelSize = size
        state.LabelShown = Draw.FitText(label, width, size)
    end
    return state.LabelShown
end

function Row.DrawLabel(data, state, label, emphasis, right)
    local size = Scale.FontSize()
    local textX = data.X + Scale.S(Layout.Padding + (ButtonStyle.TextSlide * state.Select))
    local textY = data.Y + ((data.Height - size) * 0.5) + Scale.S(ButtonStyle.PressOffset * state.Press)
    local amount = math.max(state.Select, state.Hover, emphasis or 0)
    if right then label = Fit(state, label, math.floor(right - textX), size) end
    Draw.Text(textX, textY, Animation.LerpColor(Style.TextSoft, Style.Text, amount), label, size)
end

return Row
