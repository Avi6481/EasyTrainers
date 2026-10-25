local Weapon = require("Utils/Weapon")
local Teleport = require("Utils/Teleport")

local TeleportShot = {}

TeleportShot.Enabled = { value = false }

local COOLDOWN = 0.5
local MAX_DISTANCE = 250.0

local s_LastTeleport = -1

function TeleportShot.Tick()
    if not TeleportShot.Enabled.value or not Weapon.IsShootingRanged() then return end

    local now = os.clock()
    if now - s_LastTeleport < COOLDOWN then return end

    local player = Game.GetPlayer()
    local targeting = Game.GetTargetingSystem()
    if not player or not targeting or player:GetMountedVehicle() then return end

    local lookAt = targeting:GetLookAtPosition(player, true, false)
    if not lookAt then return end

    local distance = Teleport.DistanceFromPlayer(lookAt)
    if distance < 1.0 or distance > MAX_DISTANCE then return end

    Teleport.TeleportEntity(player, Vector4.new(lookAt.x, lookAt.y, lookAt.z, 1.0), player:GetWorldOrientation():ToEulerAngles())
    s_LastTeleport = now
end

return TeleportShot
