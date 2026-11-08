local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Highlight = require("Widgets/Core/Highlight")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local Sheet = require("Panels/Sheet/Sheet")

local HoldButton = {
    Style = {}
}

local s_HoldId = nil
local s_Progress = 0
local s_Latched = false

function HoldButton.InitializeStyle()
    local style = HoldButton.Style
    style.HoldTime = 0.8
    style.DrainSpeed = 3
    style.Fill = Draw.RGBA(220, 72, 72, 70)
end

HoldButton.InitializeStyle()

local function HoldInputDown(data)
    if Input.KeyDown(Input.VK.Return) or Input.KeyDown(Input.VK.Numpad5) or Input.ButtonDown(Input.Button.A) then return true end
    if not Input.MouseDown(Input.Mouse.Left) then return false end
    if State.Menu.Cursor then return data.Hovered end
    return true
end

local function HoldHint()
    local device = State.Device.Device
    if device == State.Devices.Controller then return HighlightStyle.ShowControllerHint and "Hold A" or nil end
    if device == State.Devices.Keyboard then return HighlightStyle.ShowKeyboardHint and "Hold Enter" or nil end
    return HighlightStyle.ShowMouseHint and "Hold Click" or nil
end

function HoldButton.Draw(label, holdTime)
    local style = HoldButton.Style
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local duration = (holdTime and holdTime > 0) and holdTime or style.HoldTime
    local blocked = Sheet.SheetVisible() or Navigation.State.Editing or not State.Menu.Open
    local down = data.Selected and not blocked and HoldInputDown(data)
    local fired = false

    if not down and s_HoldId == data.Id then s_Latched = false end

    if down and not s_Latched and (s_HoldId == data.Id or s_Progress <= 0) then
        s_HoldId = data.Id
        s_Progress = s_Progress + (State.Time.Delta / math.max(0.05, duration))

        if s_Progress >= 1 then
            s_Progress = 1
            s_Latched = true
            fired = true
        end
    elseif s_HoldId == data.Id then
        s_Progress = math.max(0, s_Progress - (State.Time.Delta * style.DrainSpeed))
        if s_Progress <= 0 and not s_Latched then s_HoldId = nil end
    end

    if data.Selected then Highlight.SetHint(HoldHint()) end

    if not data.Visible then return fired end

    Row.DrawBackground(data, state)

    local progress = s_HoldId == data.Id and s_Progress or 0
    if progress > 0.001 then
        Draw.PushClip(data.X, data.Y, data.Width * progress, data.Height)
        Draw.RectFilled(data.X, data.Y, data.Width, data.Height, style.Fill, Scale.S(HighlightStyle.Rounding))
        Draw.PopClip()
    end

    Row.DrawLabel(data, state, label)
    return fired
end

return HoldButton
