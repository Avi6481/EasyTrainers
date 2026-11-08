local Layout = require("Style/Layout")

local Scale = {}

function Scale.Initialize()
    Scale.Auto = true
    Scale.Manual = 1
    Scale.BaseHeight = 1080
    Scale.Min = 0.75
    Scale.Max = 3
    Scale.Current = 1
    Scale.TextScale = 1
end

Scale.Initialize()

local function TargetScale()
    local target = Scale.Manual
    if Scale.Auto and Scale.BaseHeight > 0 then
        local _, height = GetDisplayResolution()
        if height and height > 0 then target = height / Scale.BaseHeight end
    end
    return math.max(Scale.Min, math.min(Scale.Max, target))
end

function Scale.Update(onRescale)
    local target = TargetScale()
    if math.abs(target - Scale.Current) < 0.001 then return end

    local ratio = target / Scale.Current
    Scale.Current = target
    if onRescale then onRescale(ratio) end
end

function Scale.S(value)
    return value * Scale.Current
end

function Scale.FontSize()
    return Layout.FontSize * Scale.Current * Scale.TextScale
end

return Scale
