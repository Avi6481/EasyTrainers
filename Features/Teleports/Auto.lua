local Markers = require("Features/Teleports/Markers")

local Auto = {}

local INTERVAL = 0.5
local SAME_SPOT = 1

local s_Next = 0
local s_Waypoint = { Was = false, Last = nil }
local s_Objective = { Was = false, Hash = nil, Pending = false }

local function Moved(first, second)
    if not first or not second then return true end
    local dx, dy = first.X - second.X, first.Y - second.Y
    return (dx * dx) + (dy * dy) > SAME_SPOT
end

local function Waypoint(enabled, player, go)
    if not enabled then
        s_Waypoint.Was = false
        return
    end

    local place = Markers.Waypoint()
    if not s_Waypoint.Was then
        s_Waypoint.Was = true
        s_Waypoint.Last = place
        return
    end
    if place and Moved(place, s_Waypoint.Last) then go(player, place, "Waypoint") end
    s_Waypoint.Last = place
end

local function Objective(enabled, player, go)
    if not enabled then
        s_Objective.Was = false
        return
    end

    local place, hash = Markers.Objective(player)
    if not s_Objective.Was then
        s_Objective.Was = true
        s_Objective.Hash = hash
        s_Objective.Pending = false
        return
    end
    if hash ~= s_Objective.Hash then
        s_Objective.Hash = hash
        s_Objective.Pending = hash ~= nil
    end
    if s_Objective.Pending and place then
        s_Objective.Pending = false
        go(player, place, "Objective")
    end
end

function Auto.Update(player, now, waypoint, objective, go)
    if not waypoint and not objective then
        s_Waypoint.Was = false
        s_Objective.Was = false
        return
    end
    if now < s_Next then return end
    s_Next = now + INTERVAL

    Waypoint(waypoint, player, go)
    Objective(objective, player, go)
end

return Auto
