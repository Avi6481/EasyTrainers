local Draw = require("Core/Draw")
local Layout = require("Style/Layout")

local HighlightStyle = {}

function HighlightStyle.Initialize()
    HighlightStyle.SmoothTime = 0.085
    HighlightStyle.Fill = Draw.RGBA(255, 255, 255, 26)
    HighlightStyle.Border = Draw.RGBA(255, 255, 255, 40)
    HighlightStyle.BorderSize = 1
    HighlightStyle.Rounding = Layout.Rounding
    HighlightStyle.ShowAccent = true
    HighlightStyle.AccentWidth = 3
    HighlightStyle.ShowHint = true
    HighlightStyle.ShowMouseHint = true
    HighlightStyle.ShowKeyboardHint = true
    HighlightStyle.ShowControllerHint = true
    HighlightStyle.HintFadeSpeed = 16
    HighlightStyle.HintScale = 0.82
    HighlightStyle.HintIconScale = 0.82
    HighlightStyle.HintPaddingX = 6
    HighlightStyle.HintPaddingY = 2
    HighlightStyle.HintRounding = 4
end

HighlightStyle.Initialize()

return HighlightStyle
