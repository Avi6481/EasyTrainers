local Draw = require("Core/Draw")

local ToggleStyle = {}

ToggleStyle.Shapes = {
    Switch = "Switch",
    Light = "Light",
    Orbit = "Orbit"
}

function ToggleStyle.Initialize()
    ToggleStyle.Shape = ToggleStyle.Shapes.Orbit

    ToggleStyle.SlideSpeed = 14
    ToggleStyle.HintGap = 10
    ToggleStyle.LabelBoost = 0.6

    ToggleStyle.TrackWidth = 32
    ToggleStyle.TrackHeight = 18
    ToggleStyle.KnobInset = 3

    ToggleStyle.TrackOff = Draw.RGBA(255, 255, 255, 22)
    ToggleStyle.TrackBorderOff = Draw.RGBA(255, 255, 255, 45)
    ToggleStyle.KnobOff = Draw.RGBA(160, 165, 175, 255)
    ToggleStyle.KnobOn = Draw.RGBA(255, 255, 255, 255)

    ToggleStyle.LightRadius = 4.5
    ToggleStyle.LightGlowRadius = 12
    ToggleStyle.LightGlowAlpha = 0.16
    ToggleStyle.LightGlowLayers = 6

    ToggleStyle.LightRingOff = Draw.RGBA(255, 255, 255, 60)
    ToggleStyle.LightCoreOff = Draw.RGBA(255, 255, 255, 12)

    ToggleStyle.OrbitSpeed = 9
    ToggleStyle.OrbitDotRadius = 3
    ToggleStyle.OrbitRingRadius = 7.5
    ToggleStyle.OrbitRingThickness = 1.4
    ToggleStyle.OrbitExitScale = 1.9
    ToggleStyle.OrbitDotOff = Draw.RGBA(255, 255, 255, 80)
end

ToggleStyle.Initialize()

return ToggleStyle
