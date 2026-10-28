local AimHelpers = require("Features/Weapons/Abilities/AimHelpers")
local Physics = require("Utils/Physics")

local GravityGun = {}

GravityGun.Enabled = { value = false }

local GRAB_DISTANCE = 7.0

local s_Held = nil

local function Release()
    if not s_Held then return end
    Physics.Release(s_Held, { Ragdoll = true })
    s_Held = nil
end

function GravityGun.Tick()
    if not GravityGun.Enabled.value then
        Release()
        return
    end

    local player = Game.GetPlayer()
    local targeting = Game.GetTargetingSystem()
    if not player or not targeting then return end

    if not player.isAiming then
        Release()
        return
    end

    if not s_Held then
        local target = targeting:GetLookAtObject(player, true, false)
        if target and not AimHelpers.IsPlayerOrMount(target) then s_Held = Physics.Hold(target) end
    end
    if not s_Held then return end

    local direction, origin = AimHelpers.GetAimDirection(player, targeting)
    if not direction then
        Release()
        return
    end

    local target = Vector4.new(
        origin.x + direction.x * GRAB_DISTANCE,
        origin.y + direction.y * GRAB_DISTANCE,
        origin.z + direction.z * GRAB_DISTANCE,
        1.0
    )

    if not Physics.Move(s_Held, target, 0) then Release() end
end

return GravityGun
