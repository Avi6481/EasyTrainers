local Aim = require("Utils/Aim")
local Teleport = require("Utils/Teleport")
local Weapon = require("Utils/Weapon")

local TeleportGun = {
    Enabled = false,
    Range = 250
}

local COOLDOWN = 0.5
local MIN_DISTANCE = 1

local s_LastTeleport = -1

function TeleportGun.Update(player, now)
    if not TeleportGun.Enabled or not Weapon.Shooting() then return end
    if now - s_LastTeleport < COOLDOWN then return end

    local ok, vehicle = pcall(Game.GetMountedVehicle, player)
    if ok and vehicle then return end

    local point = Aim.Point(player)
    if not point then return end

    local distance = Aim.Distance(player, point)
    if distance < MIN_DISTANCE or distance > TeleportGun.Range then return end

    s_LastTeleport = now
    Teleport.To(player, point.x, point.y, point.z)
end

return TeleportGun
