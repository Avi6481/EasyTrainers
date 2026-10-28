local Rotation = require("Utils/Rotation")

local Entities = {}

function Entities.Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local Safe = Entities.Safe

function Entities.IdHash(id)
    local hash = id and Safe(function() return id.hash end)
    return hash and tostring(hash) or nil
end

function Entities.Hash(entity)
    return entity and Safe(function() return tostring(entity:GetEntityID().hash) end)
end

function Entities.Same(a, b)
    local hash = Entities.Hash(a)
    return hash ~= nil and hash == Entities.Hash(b)
end

function Entities.IsValid(entity)
    local id = entity and Safe(function() return entity:GetEntityID() end)
    return id ~= nil and Safe(function() return Game.FindEntityByID(id) end) ~= nil
end

function Entities.Pose(entity)
    local position = Safe(function() return entity:GetWorldPosition() end)
    local orientation = Safe(function() return entity:GetWorldOrientation() end)
    if not position or not orientation then return nil end
    return { x = position.x, y = position.y, z = position.z }, Rotation.FromQuaternion(orientation)
end

return Entities
