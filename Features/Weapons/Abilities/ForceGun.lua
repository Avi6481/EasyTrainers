local Force = require("Utils/Force")
local Weapon = require("Utils/Weapon")
local AimHelpers = require("Features/Weapons/Abilities/AimHelpers")

local ForceGun = {}

ForceGun.Enabled = { value = false }

local LAUNCH_POWER = 25000.0

local s_Target = nil

function ForceGun.Tick()
    if not ForceGun.Enabled.value then
        s_Target = nil
        return
    end

    local player = Game.GetPlayer()
    local targeting = Game.GetTargetingSystem()
    if not player or not targeting then return end

    if player.isAiming and not s_Target then
        local target = targeting:GetLookAtObject(player, true, false)
        if target and not AimHelpers.IsPlayerOrMount(target) then s_Target = target end
    end

    if not s_Target or not Weapon.IsPlayerShooting() then return end

    local direction = AimHelpers.GetAimDirection(player, targeting)
    if direction then
        pcall(Force.ApplyImpulse, s_Target, Vector3.new(
            direction.x * LAUNCH_POWER,
            direction.y * LAUNCH_POWER,
            direction.z * LAUNCH_POWER
        ))
    end
    s_Target = nil
end

return ForceGun
