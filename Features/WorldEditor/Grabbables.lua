local Rotation = require("Utils/Rotation")
local Entities = require("Utils/Entities")

local Grabbables = {}

Grabbables.Range = { value = 60, min = 10, max = 200, step = 5, unit = "m" }

local BOUNDS_INTERVAL = 1.0
local FALLBACK_HALF_SIZE = 0.35

local s_Source = nil
local s_Entries = {}
local s_Bounds = {}

local Safe = Entities.Safe
local Hash = Entities.Hash

local Rotate = Rotation.Rotate
local Conjugate = Rotation.Conjugate

local function FetchBounds(entity)
    local bounds = EasyWorldEditor and Safe(function() return EasyWorldEditor.GetVisualBounds(entity) end)
    if type(bounds) == "table" and #bounds >= 2 then
        return { Min = { x = bounds[1].x, y = bounds[1].y, z = bounds[1].z }, Max = { x = bounds[2].x, y = bounds[2].y, z = bounds[2].z }, Native = true }
    end
    local size = FALLBACK_HALF_SIZE
    return { Min = { x = -size, y = -size, z = 0 }, Max = { x = size, y = size, z = size * 2 } }
end

function Grabbables.GetBounds(entity)
    local hash = Hash(entity)
    if not hash then return nil end
    local now = os.clock()
    local cached = s_Bounds[hash]
    if not cached or now >= cached.Next then
        cached = { Bounds = FetchBounds(entity), Next = now + BOUNDS_INTERVAL }
        s_Bounds[hash] = cached
    end
    return cached.Bounds
end

function Grabbables.GetBottom(entity, rotation)
    local bounds = Grabbables.GetBounds(entity)
    if not bounds then return 0 end
    if not rotation then return bounds.Min.z end

    local lowest = math.huge
    for index = 0, 7 do
        local corner = {
            x = (index % 2 == 1) and bounds.Max.x or bounds.Min.x,
            y = (math.floor(index / 2) % 2 == 1) and bounds.Max.y or bounds.Min.y,
            z = (math.floor(index / 4) % 2 == 1) and bounds.Max.z or bounds.Min.z
        }
        lowest = math.min(lowest, Rotate(rotation, corner).z)
    end
    return lowest
end

function Grabbables.GetPose(entity)
    local position = Safe(function() return entity:GetWorldPosition() end)
    local orientation = Safe(function() return entity:GetWorldOrientation() end)
    if not position or not orientation then return nil end
    return { x = position.x, y = position.y, z = position.z }, { i = orientation.i, j = orientation.j, k = orientation.k, r = orientation.r }
end

function Grabbables.SetSource(source)
    s_Source = source
end

function Grabbables.Refresh(cameraPosition)
    s_Entries = {}
    if not s_Source or not cameraPosition then return end

    local range = Grabbables.Range.value
    for _, entity in ipairs(s_Source() or {}) do
        local position, rotation = Grabbables.GetPose(entity)
        if position then
            local dx, dy, dz = position.x - cameraPosition.x, position.y - cameraPosition.y, position.z - cameraPosition.z
            if dx * dx + dy * dy + dz * dz <= range * range then
                local bounds = Grabbables.GetBounds(entity)
                local localCenter = {
                    x = (bounds.Min.x + bounds.Max.x) * 0.5,
                    y = (bounds.Min.y + bounds.Max.y) * 0.5,
                    z = (bounds.Min.z + bounds.Max.z) * 0.5
                }
                local offset = Rotate(rotation, localCenter)
                table.insert(s_Entries, {
                    Entity = entity,
                    Hash = Hash(entity),
                    Bounds = bounds,
                    Position = position,
                    Rotation = rotation,
                    Center = { x = position.x + offset.x, y = position.y + offset.y, z = position.z + offset.z }
                })
            end
        end
    end
end

local function RayBox(origin, direction, entry)
    local inverse = Conjugate(entry.Rotation)
    local o = Rotate(inverse, { x = origin.x - entry.Position.x, y = origin.y - entry.Position.y, z = origin.z - entry.Position.z })
    local d = Rotate(inverse, direction)

    local near, far = -math.huge, math.huge
    for _, axis in ipairs({ "x", "y", "z" }) do
        local minimum, maximum = entry.Bounds.Min[axis], entry.Bounds.Max[axis]
        if math.abs(d[axis]) < 1e-6 then
            if o[axis] < minimum or o[axis] > maximum then return nil end
        else
            local t1, t2 = (minimum - o[axis]) / d[axis], (maximum - o[axis]) / d[axis]
            if t1 > t2 then t1, t2 = t2, t1 end
            near, far = math.max(near, t1), math.min(far, t2)
            if near > far then return nil end
        end
    end
    if far < 0 then return nil end
    return math.max(near, 0)
end

function Grabbables.Pick(origin, direction, maxDistance)
    local best, bestDistance = nil, nil
    for _, entry in ipairs(s_Entries) do
        local distance = RayBox(origin, direction, entry)
        if distance and distance <= maxDistance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = entry, distance
        end
    end
    if not best then return nil end
    return best.Entity, bestDistance
end

function Grabbables.ToWorld(position, rotation, point)
    local offset = Rotate(rotation, point)
    return { x = position.x + offset.x, y = position.y + offset.y, z = position.z + offset.z }
end

function Grabbables.HasNativeBounds()
    return EasyWorldEditor ~= nil and Safe(function() return EasyWorldEditor.GetVisualBounds ~= nil end) == true
end

function Grabbables.GetEntries()
    return s_Entries
end

function Grabbables.Clear()
    s_Entries = {}
    s_Bounds = {}
end

return Grabbables
