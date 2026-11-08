local Physics = require("Features/WorldEditor/Physics")
local Entities = require("Features/WorldEditor/Entities")

local Picker = {
    SearchRange = 120
}

Picker.Kinds = {
    Ped = { Key = "worldeditor.kinds.ped", Color = 0xFF5C5CFF, Radius = 0.6, Height = 1.8 },
    Vehicle = { Key = "worldeditor.kinds.vehicle", Color = 0xFFFFBE50, Radius = 2.4, Height = 1.5 },
    Device = { Key = "worldeditor.kinds.device", Color = 0xFF3CC8FF, Radius = 0.7, Height = 0 },
    Item = { Key = "worldeditor.kinds.item", Color = 0xFFFF78B4, Radius = 0.5, Height = 0 },
    Prop = { Key = "worldeditor.kinds.prop", Color = 0xFF8CE65A, Radius = 0.8, Height = 0 },
    Surface = { Key = "worldeditor.kinds.surface", Color = 0xFFE6E6E6 }
}

Picker.Classify = Physics.Classify

local CANDIDATE_INTERVAL = 0.5
local OCCLUSION_MARGIN = 0.75

local s_Candidates = {}
local s_NextCandidates = 0

local Safe = Entities.Safe

function Picker.Kind(kind)
    return Picker.Kinds[kind] or Picker.Kinds.Prop
end

local function RefreshCandidates(player)
    local now = os.clock()
    if now < s_NextCandidates then return end
    s_NextCandidates = now + CANDIDATE_INTERVAL

    local entities = Safe(function()
        return player:GetEntitiesAroundObject(Picker.SearchRange, TargetSearchQuery.new().searchFilter)
    end)

    s_Candidates = {}
    for _, entity in ipairs(type(entities) == "table" and entities or {}) do
        table.insert(s_Candidates, { Entity = entity, Kind = Picker.Classify(entity) })
    end
end

local function RaySphere(origin, direction, center, radius)
    local toX, toY, toZ = center.x - origin.x, center.y - origin.y, center.z - origin.z
    local along = toX * direction.x + toY * direction.y + toZ * direction.z
    if along < 0 then return nil end

    local closestSq = (toX * toX + toY * toY + toZ * toZ) - along * along
    local radiusSq = radius * radius
    if closestSq > radiusSq then return nil end
    return along - math.sqrt(radiusSq - closestSq)
end

local function TestCandidate(candidate, origin, direction)
    local kind = Picker.Kind(candidate.Kind)
    local position = Safe(function() return candidate.Entity:GetWorldPosition() end)
    if not position then return nil end

    local radius = kind.Radius
    local best = nil
    local steps = kind.Height > 0 and math.max(1, math.ceil(kind.Height / radius)) or 0
    for step = 0, steps do
        local height = steps > 0 and (kind.Height * step / steps) or 0
        local distance = RaySphere(origin, direction, { x = position.x, y = position.y, z = position.z + height }, radius)
        if distance and (not best or distance < best) then best = distance end
    end
    return best
end

function Picker.Pick(origin, direction, blockedDistance, onlyKind)
    local player = Game.GetPlayer()
    if not player then return nil end
    RefreshCandidates(player)

    local nearest, nearestDistance = nil, nil
    for _, candidate in ipairs(s_Candidates) do
        local distance = (not onlyKind or candidate.Kind == onlyKind) and TestCandidate(candidate, origin, direction)
        local visible = distance and (not blockedDistance or distance <= blockedDistance + OCCLUSION_MARGIN)
        if visible and (not nearestDistance or distance < nearestDistance) then
            nearest, nearestDistance = candidate, distance
        end
    end
    if not nearest then return nil end
    return nearest.Entity, nearest.Kind, nearestDistance
end

function Picker.Clear()
    s_Candidates = {}
    s_NextCandidates = 0
end

return Picker
