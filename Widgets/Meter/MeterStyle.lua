local Draw = require("Core/Draw")

local MeterStyle = {
    Pips = {}
}

function MeterStyle.Initialize()
    MeterStyle.Width = 84
    MeterStyle.Height = 5
    MeterStyle.Segments = 10
    MeterStyle.SegmentGap = 2
    MeterStyle.Rounding = 1.5
    MeterStyle.Empty = Draw.RGBA(255, 255, 255, 26)
    MeterStyle.FillSpeed = 12
    MeterStyle.ValueGap = 10
    MeterStyle.ValueScale = 0.95

    local pips = MeterStyle.Pips
    pips.Radius = 3.5
    pips.Gap = 6
    pips.RingThickness = 1.2
    pips.FillSpeed = 16
    pips.Empty = Draw.RGBA(255, 255, 255, 70)
    pips.LockedAlpha = 0.4
end

MeterStyle.Initialize()

return MeterStyle
