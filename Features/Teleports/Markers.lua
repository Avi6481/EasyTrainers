local Markers = {}

local function Nearest(positions, origin)
    local best, bestDistance = nil, math.huge
    for _, position in ipairs(positions) do
        local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
        local distance = (dx * dx) + (dy * dy) + (dz * dz)
        if distance < bestDistance then
            best = position
            bestDistance = distance
        end
    end
    if not best then return nil end
    return { X = best.x, Y = best.y, Z = best.z }
end

function Markers.Waypoint()
    local system = Game.GetMappinSystem()
    local pin = system:GetMappin(system:GetManuallyTrackedMappinID())
    if not pin or not pin:IsPlayerTracked() then return nil end

    local position = pin:GetWorldPosition()
    return { X = position.x, Y = position.y, Z = position.z }
end

function Markers.Objective(player)
    local journal = Game.GetJournalManager()
    local tracked = journal and journal:GetTrackedEntry()
    if not tracked then return nil, nil end

    local hash = journal:GetEntryHash(tracked)
    local found, positions = Game.GetMappinSystem():GetQuestMappinPositionsByObjective(hash)
    if not found or type(positions) ~= "table" then return nil, hash end
    return Nearest(positions, player:GetWorldPosition()), hash
end

return Markers
