local Layout = require("Style/Layout")

local ControlsHudStyle = {}

function ControlsHudStyle.Initialize()
    ControlsHudStyle.Enabled = true
    ControlsHudStyle.Height = 30
    ControlsHudStyle.Gap = 6
    ControlsHudStyle.Padding = 10
    ControlsHudStyle.Rounding = Layout.Rounding
    ControlsHudStyle.ItemSpacing = 16
    ControlsHudStyle.KeySpacing = 6
    ControlsHudStyle.KeyScale = 0.8
    ControlsHudStyle.IconScale = 0.62
    ControlsHudStyle.IconSpacing = 4
    ControlsHudStyle.KeyPaddingX = 6
    ControlsHudStyle.KeyPaddingY = 2
    ControlsHudStyle.KeyRounding = 4
    ControlsHudStyle.LabelScale = 0.88
end

ControlsHudStyle.Initialize()

return ControlsHudStyle
