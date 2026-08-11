local Weapon = require("Utils/Weapon")
local Explosion = require("Utils/Explosion")

local ExplosiveBullets = {}
local cooldown = 0.1
local lastExplosionTime = -1

ExplosiveBullets.enabled = { value = false }

function ExplosiveBullets.Tick()
    if not ExplosiveBullets.enabled.value then return end
    if not Weapon.IsShootingRanged() then return end

    local currentTime = os.clock()
    if currentTime - lastExplosionTime < cooldown then return end

    local player = Game.GetPlayer()
    local targeting = Game.GetTargetingSystem()
    if not (player and targeting) then return end
    local lookAt = targeting:GetLookAtPosition(player, true, false)
    if not lookAt then return end

    if Explosion.SpawnAtPos(lookAt, "Attacks.LegendaryFragGrenade", player, player,
        player:GetActiveWeapon(), 3.0) then
        lastExplosionTime = currentTime
    end
end

return ExplosiveBullets
