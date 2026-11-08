local Draw = require("Core/Draw")

local Style = {}

function Style.Initialize()
    Style.Background = Draw.RGBA(26, 26, 26, 245)
    Style.BackgroundLight = Draw.RGBA(34, 34, 34, 245)
    Style.BackgroundDark = Draw.RGBA(16, 16, 16, 250)
    Style.Transparent = Draw.RGBA(0, 0, 0, 0)

    Style.Accent = Draw.RGBA(58, 110, 165, 255)
    Style.AccentHover = Draw.RGBA(76, 132, 190, 255)
    Style.AccentActive = Draw.RGBA(255, 20, 147, 255)

    Style.Text = Draw.RGBA(255, 255, 255, 255)
    Style.TextSoft = Draw.RGBA(255, 255, 255, 175)
    Style.TextDisabled = Draw.RGBA(120, 140, 160, 255)

    Style.Border = Draw.RGBA(80, 90, 110, 255)
    Style.Shadow = Draw.RGBA(0, 0, 0, 96)
end

Style.Initialize()

return Style
