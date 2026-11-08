local Impulse = {}

local DEFAULT_MASS = 1500

function Impulse.Mass(vehicle)
    local ok, mass = pcall(function() return vehicle:GetTotalMass() end)
    if ok and type(mass) == "number" and mass > 0 then return mass end
    return DEFAULT_MASS
end

function Impulse.PushAt(entity, position, x, y, z)
    local event = PhysicalImpulseEvent.new()
    event.worldImpulse = Vector3.new(x, y, z)
    event.worldPosition = Vector3.new(position.x, position.y, position.z)
    event.radius = 1
    entity:QueueEvent(event)
end

function Impulse.Push(entity, x, y, z)
    Impulse.PushAt(entity, entity:GetWorldPosition(), x, y, z)
end

return Impulse
