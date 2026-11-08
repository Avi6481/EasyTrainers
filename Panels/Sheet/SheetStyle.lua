local Draw = require("Core/Draw")

local SheetStyle = {}

function SheetStyle.Initialize()
    SheetStyle.SlideTime = 0.11
    SheetStyle.Margin = 8
    SheetStyle.MaxHeight = 0.72
    SheetStyle.TitleHeight = 40
    SheetStyle.RowHeight = 30
    SheetStyle.Padding = 6
    SheetStyle.UseMenuBackground = true
    SheetStyle.Fill = Draw.RGBA(32, 32, 34, 252)
    SheetStyle.DimAlpha = 0.55
    SheetStyle.ShowAccentLine = true
    SheetStyle.AccentLineHeight = 2
    SheetStyle.ShowCount = true
    SheetStyle.DotRadius = 2.5
    SheetStyle.CurrentRingRadius = 6
    SheetStyle.DotOff = Draw.RGBA(255, 255, 255, 60)
    SheetStyle.DetailScale = 0.86
end

SheetStyle.Initialize()

return SheetStyle
