local Layout = require("Style/Layout")

local ButtonStyle = {}

function ButtonStyle.Initialize()
    ButtonStyle.SelectSpeed = 16
    ButtonStyle.HoverSpeed = 16
    ButtonStyle.PressSpeed = 30
    ButtonStyle.TextSlide = 4
    ButtonStyle.PressOffset = 0
    ButtonStyle.HoverAlpha = 0.47
    ButtonStyle.HoverRounding = Layout.Rounding
end

ButtonStyle.Initialize()

return ButtonStyle
