local Draw = require("Core/Draw")

local SliderStyle = {}

SliderStyle.Shapes = {
    Track = "Track",
    Ring = "Ring",
    Chevron = "Chevron"
}

function SliderStyle.Initialize()
    SliderStyle.Shape = SliderStyle.Shapes.Chevron

    SliderStyle.ChevronSize = 3.5
    SliderStyle.ChevronThickness = 1.4
    SliderStyle.ChevronGap = 8
    SliderStyle.ChevronsOnSelectOnly = true
    SliderStyle.AlignWithToggles = true

    SliderStyle.UnderlineMinWidth = 52
    SliderStyle.UnderlineHeight = 2
    SliderStyle.UnderlineGap = 3
    SliderStyle.ValueLift = 0
    SliderStyle.ValueAlign = 0

    SliderStyle.RingRadius = 8
    SliderStyle.RingThickness = 1.8
    SliderStyle.RingDotRadius = 3
    SliderStyle.RingOff = Draw.RGBA(255, 255, 255, 30)

    SliderStyle.ValueSpeed = 18
    SliderStyle.ValueScale = 0.95
    SliderStyle.ValueGap = 10
    SliderStyle.DisabledAlpha = 0.4

    SliderStyle.ShowTrack = true
    SliderStyle.TrackHeight = 2
    SliderStyle.TrackBottom = 5
    SliderStyle.TrackOff = Draw.RGBA(255, 255, 255, 28)

    SliderStyle.ThumbRadius = 2.5
    SliderStyle.ThumbSelectedRadius = 3.5

    SliderStyle.DragEnabled = true
    SliderStyle.ClickValueToType = true
end

SliderStyle.Initialize()

return SliderStyle
