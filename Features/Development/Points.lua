local Dev = require("Features/Development/Dev")

local Points = {}

function Points.Set(point, value)
    local data = Dev.Data()
    if not data then return end

    local pointType = Dev.PointType(point)
    local delta = math.max(0, value) - data:GetDevPoints(pointType)
    if delta == 0 then return end

    data:AddDevelopmentPoints(delta, pointType)
    data:UpdateUIBB()
end

return Points
