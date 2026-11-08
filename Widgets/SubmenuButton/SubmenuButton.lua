local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Submenu = require("Navigation/Submenu")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local Toggle = require("Widgets/Toggle/Toggle")

local SubmenuButton = {}

local BADGE_SCALE = 0.88

function SubmenuButton.Draw(label, submenu, badge)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    if data.Activated then Submenu.Open(submenu) end

    local padding = Scale.S(Layout.Padding)
    local controlWidth = Toggle.ControlWidth()
    local rowRight = data.X + data.Width - padding
    local columnCenter = rowRight - (controlWidth * 0.5)
    local badgeRight = rowRight - controlWidth - Scale.S(SliderStyle.ValueGap)
    local centerY = data.Y + (data.Height * 0.5)

    local badgeSize = Scale.FontSize() * BADGE_SCALE
    local badgeText = badge and tostring(badge) or ""
    local hasBadge = badgeText ~= ""
    local badgeWidth, badgeHeight = 0, 0
    if hasBadge then badgeWidth, badgeHeight = Draw.TextSize(badgeText, badgeSize) end
    local badgeX = badgeRight - badgeWidth

    if data.Selected then
        local left = rowRight - controlWidth
        if hasBadge then left = badgeX end
        Highlight.SetHint(Highlight.SelectHint(), rowRight - left + Scale.S(SliderStyle.ValueGap))
    end

    if not data.Visible then return data.Activated end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    local active = math.max(state.Select, state.Hover)

    if hasBadge then
        Draw.Text(badgeX, centerY - (badgeHeight * 0.5), Style.TextDisabled, badgeText, badgeSize)
    end

    local chevronColor = Animation.LerpColor(Style.TextDisabled, Style.Text, active * 0.7)
    local slide = Scale.S(2) * state.Select
    Draw.Chevron(columnCenter + slide, centerY, Scale.S(SliderStyle.ChevronSize), "Right", chevronColor, Scale.S(SliderStyle.ChevronThickness))

    return data.Activated
end

return SubmenuButton
