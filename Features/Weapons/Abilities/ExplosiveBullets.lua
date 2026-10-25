local Weapon = require("Utils/Weapon")
local Explosion = require("Utils/Explosion")
local StatModifiers = require("Utils/StatModifiers")

local ExplosiveBullets = {}

ExplosiveBullets.Enabled = { value = false }
ExplosiveBullets.Type = { index = 1 }
ExplosiveBullets.Damage = { value = 500, min = 0, max = 5000, step = 100, unit = "%" }
ExplosiveBullets.OnEnemies = { value = true }
ExplosiveBullets.OnSurfaces = { value = true }
ExplosiveBullets.Rate = { value = 25, min = 1, max = 25, step = 1, unit = "/s" }
ExplosiveBullets.Chance = { value = 100, min = 5, max = 100, step = 5, unit = "%" }

local TYPES = {
    { Label = "Explosive Rounds", Attack = "Attacks.BulletExplosion" },
    { Label = "Frag Grenade", Attack = "Attacks.LegendaryFragGrenade" },
    { Label = "Incendiary", Attack = "Attacks.LegendaryPlusIncendiaryGrenade" },
    { Label = "EMP", Attack = "Attacks.EMPGrenadeLegendary" },
    { Label = "Biohazard", Attack = "Attacks.LegendaryPlusBiotechGrenade" },
    { Label = "Rocket", Attack = "Attacks.RocketChargedExplosion" },
    { Label = "Missile Strike", Attack = "Attacks.PanzerMissileEffect" }
}

ExplosiveBullets.TypeOptions = {}
for _, entry in ipairs(TYPES) do table.insert(ExplosiveBullets.TypeOptions, entry.Label) end

local HIT_WINDOW = 0.05
local EFFECT_DURATION = 0.05

local s_DamageOwner = { Name = "ExplosiveBullets.Damage" }
local s_PendingShot = nil
local s_LastExplosion = -1

local function Attack()
    local entry = TYPES[ExplosiveBullets.Type.index or 1] or TYPES[1]
    return entry.Attack
end

local function Explode(position)
    local now = os.clock()
    if not position or now - s_LastExplosion < 1 / ExplosiveBullets.Rate.value then return end

    local player = Game.GetPlayer()
    if not player then return end
    if Explosion.SpawnAtPos(position, Attack(), player, player, player:GetActiveWeapon(), EFFECT_DURATION) then
        s_LastExplosion = now
    end
end

local function BuildDamage()
    local bonus = ExplosiveBullets.Damage.value
    return {
        { gamedataStatType.ExplosionDamagePercentBonus, gameStatModifierType.Additive, bonus },
        { gamedataStatType.GrenadeDamagePercentBonus, gameStatModifierType.Additive, bonus }
    }
end

function ExplosiveBullets.OnShot()
    if not ExplosiveBullets.Enabled.value or not Weapon.IsRangedEquipped() then return end
    if math.random(100) > ExplosiveBullets.Chance.value then return end
    s_PendingShot = os.clock()
end

function ExplosiveBullets.OnHit(hitEvent)
    if not ExplosiveBullets.Enabled.value or not s_PendingShot or not hitEvent then return end

    local ok, fromPlayerGun = pcall(function()
        local attack = hitEvent.attackData
        local instigator = attack:GetInstigator()
        return instigator ~= nil and instigator:IsPlayer() and attack:GetAttackType() == gamedataAttackType.Ranged
    end)
    if not ok or not fromPlayerGun then return end

    s_PendingShot = nil
    if ExplosiveBullets.OnEnemies.value then Explode(hitEvent.hitPosition) end
end

function ExplosiveBullets.Tick()
    local enabled = ExplosiveBullets.Enabled.value
    local player = Game.GetPlayer()
    if player then
        StatModifiers.Sync(s_DamageOwner, enabled and ExplosiveBullets.Damage.value > 0, ExplosiveBullets.Damage.value, player:GetEntityID(), BuildDamage)
    end

    if not enabled then
        s_PendingShot = nil
        return
    end
    if not s_PendingShot or os.clock() - s_PendingShot < HIT_WINDOW then return end
    s_PendingShot = nil

    local targeting = Game.GetTargetingSystem()
    if player and targeting and ExplosiveBullets.OnSurfaces.value then Explode(targeting:GetLookAtPosition(player, true, false)) end
end

return ExplosiveBullets
