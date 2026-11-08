local Aim = require("Utils/Aim")
local Impulse = require("Utils/Impulse")
local Weapon = require("Utils/Weapon")

local ForceGun = {
    Enabled = false,
    Power = 30
}

local PUPPET_MASS = 90
local PUSH_DELAY = 0.1
local COOLDOWN = 0.15
local DUAL_WIELD = 2

local s_Shot = false
local s_Pending = nil
local s_LastPush = -1

local function Push(target, direction, mass, scale)
    local force = mass * ForceGun.Power * scale
    Impulse.Push(target, direction.x * force, direction.y * force, direction.z * force)
end

function ForceGun.OnShot()
    if ForceGun.Enabled then s_Shot = true end
end

local function Pending(now)
    if not s_Pending or now < s_Pending.At then return end
    local pending = s_Pending
    s_Pending = nil
    pcall(Push, pending.Target, pending.Direction, PUPPET_MASS, pending.Scale)
end

function ForceGun.Update(player, now)
    if not ForceGun.Enabled then
        s_Shot, s_Pending = false, nil
        return
    end

    Pending(now)
    if not s_Shot then return end
    s_Shot = false
    if now - s_LastPush < COOLDOWN then return end

    local target = Aim.Object(player)
    local _, direction = Aim.Ray(player)
    if not target or not direction then return end
    s_LastPush = now

    local scale = Weapon.DualWielding() and DUAL_WIELD or 1
    if Aim.IsPuppet(target) then
        target:QueueEvent(CreateForceRagdollEvent(CName.new("EasyTrainer")))
        s_Pending = { Target = target, Direction = direction, Scale = scale, At = now + PUSH_DELAY }
        return
    end
    Push(target, direction, Impulse.Mass(target), scale)
end

function ForceGun.Reset()
    s_Shot, s_Pending = false, nil
end

return ForceGun
