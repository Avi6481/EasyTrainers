local Explosion = require("Utils/Explosion")
local Weapon = require("Utils/Weapon")

local ExplosiveKnives = {
    Enabled = false
}

local ATTACK = "Attacks.LegendaryFragGrenade"
local COOLDOWN = 0.1
local DURATION = 3

local s_Hits = {}
local s_LastExplosion = -1

function ExplosiveKnives.OnProjectileHit(eventData)
    if not ExplosiveKnives.Enabled or Weapon.Ranged() then return end

    for _, hit in ipairs(eventData.hitInstances or {}) do
        local position = hit and hit.position
        if position then table.insert(s_Hits, { x = position.x, y = position.y, z = position.z }) end
    end
end

function ExplosiveKnives.Update(player, now)
    if #s_Hits == 0 then return end

    local hits = s_Hits
    s_Hits = {}
    if not ExplosiveKnives.Enabled or now - s_LastExplosion < COOLDOWN then return end

    for _, position in ipairs(hits) do Explosion.At(player, position, ATTACK, DURATION) end
    s_LastExplosion = now
end

function ExplosiveKnives.Reset()
    s_Hits = {}
end

return ExplosiveKnives
