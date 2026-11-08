local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local HighlightStyle = require("Widgets/Core/HighlightStyle")

local Highlight = {}

local s_Y = 0
local s_Velocity = 0
local s_Placed = false
local s_NextHint = ""
local s_Hint = ""
local s_HintAlpha = 0
local s_NextHintInset = 0
local s_HintInset = 0
local s_HoldFrames = 0

local function UpdateHint()
    if s_NextHint ~= "" then
        s_Hint = s_NextHint
        s_HintInset = Animation.Animate(s_HintInset, s_NextHintInset, HighlightStyle.HintFadeSpeed, State.Time.Delta)
    end

    local target = s_NextHint == "" and 0 or 1
    s_HintAlpha = Animation.Animate(s_HintAlpha, target, HighlightStyle.HintFadeSpeed, State.Time.Delta)
    s_NextHint = ""
    s_NextHintInset = 0
end

local function SplitHint(text, textSize, iconSize)
    local runs = {}
    local index = 1
    while index <= #text do
        local icon = text:byte(index) >= 0x80
        local finish = index
        while finish <= #text and (text:byte(finish) >= 0x80) == icon do
            finish = finish + 1
        end

        local part = text:sub(index, finish - 1)
        local size = icon and iconSize or textSize
        local width, height = Draw.TextSize(part, size)
        table.insert(runs, { Text = part, Size = size, Width = width, Height = height })
        index = finish
    end
    return runs
end

local function DrawHint(x, y, w, h)
    if not HighlightStyle.ShowHint or s_Hint == "" or s_HintAlpha < 0.01 then return end

    local textSize = Scale.FontSize() * HighlightStyle.HintScale
    local iconSize = Scale.FontSize() * HighlightStyle.HintIconScale
    local runs = SplitHint(s_Hint, textSize, iconSize)

    local contentWidth = 0
    for _, run in ipairs(runs) do contentWidth = contentWidth + run.Width end

    local padX = Scale.S(HighlightStyle.HintPaddingX)
    local padY = Scale.S(HighlightStyle.HintPaddingY)
    local _, lineHeight = Draw.TextSize("Ag", textSize)
    local boxW = contentWidth + (padX * 2)
    local boxH = lineHeight + (padY * 2)
    local boxX = x + w - Scale.S(Layout.Padding) - s_HintInset - boxW
    local boxY = y + ((h - boxH) * 0.5)
    local centerY = boxY + (boxH * 0.5)

    Draw.Rect(boxX, boxY, boxW, boxH, Draw.ScaleAlpha(Style.Border, s_HintAlpha), Scale.S(HighlightStyle.HintRounding))

    local color = Draw.ScaleAlpha(Style.TextDisabled, s_HintAlpha)
    local cursor = boxX + padX
    for _, run in ipairs(runs) do
        Draw.Text(cursor, centerY - (run.Height * 0.5), color, run.Text, run.Size)
        cursor = cursor + run.Width
    end
end

local s_HintWidths = {}

function Highlight.HintWidth(text)
    if not HighlightStyle.ShowHint or not text or text == "" then return 0 end

    local textSize = Scale.FontSize() * HighlightStyle.HintScale
    local cached = s_HintWidths[text]
    if cached and cached.Size == textSize then return cached.Width end

    local width = Scale.S(HighlightStyle.HintPaddingX) * 2
    for _, run in ipairs(SplitHint(text, textSize, Scale.FontSize() * HighlightStyle.HintIconScale)) do
        width = width + run.Width
    end
    s_HintWidths[text] = { Size = textSize, Width = width }
    return width
end

function Highlight.ResetHighlight()
    s_Placed = false
    s_Velocity = 0
    s_HintAlpha = 0
    s_HoldFrames = 1
end

function Highlight.SetHint(text, rightInset)
    s_NextHint = text or ""
    s_NextHintInset = rightInset or 0
end

function Highlight.SelectHint()
    local device = State.Device.Device
    if device == State.Devices.Controller then return HighlightStyle.ShowControllerHint and "A" or nil end
    if device == State.Devices.Keyboard then return HighlightStyle.ShowKeyboardHint and "Enter" or nil end
    return HighlightStyle.ShowMouseHint and "Click" or nil
end

function Highlight.DrawHighlight()
    local nav = Navigation.State
    UpdateHint()

    if s_HoldFrames > 0 then
        s_HoldFrames = s_HoldFrames - 1
        return
    end

    if nav.Total <= 0 or not Navigation.IsSelectable(nav.Current) then
        s_Placed = false
        return
    end

    local content = Navigation.Content()
    local height = Scale.S(Layout.OptionHeight)
    local rounding = Scale.S(HighlightStyle.Rounding)
    local target = Navigation.RowY(nav.Current)

    if not s_Placed then
        s_Y = target
        s_Velocity = 0
        s_Placed = true
    end

    s_Y, s_Velocity = Animation.SmoothDamp(s_Y, target, s_Velocity, HighlightStyle.SmoothTime, State.Time.Delta)

    Draw.RectFilled(content.X, s_Y, content.Width, height, HighlightStyle.Fill, rounding)
    if HighlightStyle.ShowAccent then
        Draw.LeftAccent(content.X, s_Y, height, Style.Accent, rounding, Scale.S(HighlightStyle.AccentWidth))
    end
    if HighlightStyle.BorderSize > 0 then
        Draw.Rect(content.X, s_Y, content.Width, height, HighlightStyle.Border, rounding, 0, HighlightStyle.BorderSize)
    end

    DrawHint(content.X, s_Y, content.Width, height)
end

return Highlight
