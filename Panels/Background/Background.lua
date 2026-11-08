local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")

local Background = {}

function Background.Draw()
    local menu = State.Menu
    Draw.RectFilled(menu.X, menu.Y, menu.Width, menu.Height, Style.Background, Scale.S(Layout.Rounding))
end

return Background
