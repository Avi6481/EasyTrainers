local AimHelpers = require("Features/Weapons/Abilities/AimHelpers")

local GravityGun = {}

GravityGun.Enabled = { value = false }

local GRAB_DISTANCE = 7.0

local s_Held = nil

function GravityGun.Tick()
    if not GravityGun.Enabled.value then
        s_Held = nil
        return
    end

    local player = Game.GetPlayer()
    local targeting = Game.GetTargetingSystem()
    local teleport = Game.GetTeleportationFacility()
    if not player or not targeting or not teleport then return end

    if not player.isAiming then
        s_Held = nil
        return
    end

    if not s_Held then
        local target = targeting:GetLookAtObject(player, true, false)
        if target and not AimHelpers.IsPlayerOrMount(target) then s_Held = target end
    end
    if not s_Held then return end

    local direction, origin = AimHelpers.GetAimDirection(player, targeting)
    if not direction then
        s_Held = nil
        return
    end

    local target = Vector4.new(
        origin.x + direction.x * GRAB_DISTANCE,
        origin.y + direction.y * GRAB_DISTANCE,
        origin.z + direction.z * GRAB_DISTANCE,
        1.0
    )

    local held = s_Held
    local moved = pcall(function() teleport:Teleport(held, target, EulerAngles.new(0, 0, 0)) end)
    if not moved then s_Held = nil end
end

return GravityGun
