local Aim = require("Utils/Aim")
local Impulse = require("Utils/Impulse")

local GravityGun = {
    Enabled = false,
    Distance = 7
}

local THROW = 25
local PUPPET_MASS = 90
local PUSH_DELAY = 0.1
local REGRAB = 0.75

local s_Held = nil
local s_Shot = false
local s_Pending = nil
local s_NextGrab = 0

local function Ragdoll(entity)
    pcall(function() entity:QueueEvent(CreateForceRagdollEvent(CName.new("EasyTrainer"))) end)
end

local function Throw(target, direction, mass)
    local force = mass * THROW
    Impulse.Push(target, direction.x * force, direction.y * force, direction.z * force)
end

local function Release(direction, now)
    local held = s_Held
    s_Held = nil
    if not held then return end
    if direction then s_NextGrab = now + REGRAB end

    if Aim.IsPuppet(held) then
        Ragdoll(held)
        if direction then s_Pending = { Target = held, Direction = direction, At = now + PUSH_DELAY } end
        return
    end
    if direction then pcall(Throw, held, direction, Impulse.Mass(held)) end
end

local function Carry(player)
    local origin, direction = Aim.Ray(player)
    if not origin then return false end

    local distance = GravityGun.Distance
    local point = Vector4.new(origin.x + (direction.x * distance), origin.y + (direction.y * distance), origin.z + (direction.z * distance), 1)
    Game.GetTeleportationFacility():Teleport(s_Held, point, EulerAngles.new(0, 0, s_Held:GetWorldYaw()))
    return true
end

local function Pending(now)
    if not s_Pending or now < s_Pending.At then return end
    local pending = s_Pending
    s_Pending = nil
    pcall(Throw, pending.Target, pending.Direction, PUPPET_MASS)
end

function GravityGun.OnShot()
    if GravityGun.Enabled and s_Held then s_Shot = true end
end

function GravityGun.Update(player, now)
    Pending(now)
    if not GravityGun.Enabled or not Aim.Aiming(player) then
        s_Shot = false
        return Release(nil, now)
    end

    if s_Shot then
        s_Shot = false
        local _, direction = Aim.Ray(player)
        return Release(direction, now)
    end

    if not s_Held and now >= s_NextGrab then s_Held = Aim.Object(player) end
    if not s_Held then return end
    if not pcall(Carry, player) then Release(nil, now) end
end

function GravityGun.Reset()
    s_Held, s_Shot, s_Pending, s_NextGrab = nil, false, nil, 0
end

function GravityGun.Shutdown()
    Release(nil, os.clock())
end

return GravityGun
