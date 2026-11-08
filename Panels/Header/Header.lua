local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local HeaderStyle = require("Panels/Header/HeaderStyle")

local Header = {}

function Header.Draw()
    local menu = State.Menu
    local headerHeight = Scale.S(Layout.HeaderHeight)
    local padding = Scale.S(Layout.Padding)
    local fontSize = Scale.FontSize()
    local textY = menu.Y + ((headerHeight - fontSize) * 0.5)

    Draw.Text(menu.X + padding, textY, Style.Text, HeaderStyle.Title, fontSize)

    if HeaderStyle.ShowSubtitle and HeaderStyle.Subtitle ~= "" then
        local subtitleWidth = Draw.TextSize(HeaderStyle.Subtitle, fontSize)
        Draw.Text(menu.X + menu.Width - padding - subtitleWidth, textY, Style.TextDisabled, HeaderStyle.Subtitle, fontSize)
    end

    if HeaderStyle.ShowAccentLine then
        local lineHeight = Scale.S(HeaderStyle.AccentLineHeight)
        Draw.RectFilled(menu.X, menu.Y + headerHeight - lineHeight, menu.Width, lineHeight, Style.Accent)
    end
end

return Header
