local StatModifiers = require("Utils/StatModifiers")
local Explosion = require("Utils/Explosion")
local Aim = require("Utils/Aim")
local Weapon = require("Utils/Weapon")

local ExplosiveBullets = {
    Enabled = false,
    Type = 1,
    Damage = 500,
    Rate = 25,
    Chance = 100,
    OnEnemies = true,
    OnSurfaces = true
}

ExplosiveBullets.Types = {
    { Key = "rounds", Attack = "Attacks.BulletExplosion" },
    { Key = "frag", Attack = "Attacks.LegendaryFragGrenade" },
    { Key = "incendiary", Attack = "Attacks.LegendaryPlusIncendiaryGrenade" },
    { Key = "emp", Attack = "Attacks.EMPGrenadeLegendary" },
    { Key = "biohazard", Attack = "Attacks.LegendaryPlusBiotechGrenade" },
    { Key = "rocket", Attack = "Attacks.RocketChargedExplosion" },
    { Key = "missile", Attack = "Attacks.PanzerMissileEffect" }
}

local OWNER = "Weapons.ExplosiveBullets"
local HIT_WINDOW = 0.05

local s_Shot = nil
local s_Hit = nil
local s_LastExplosion = -1

local function Attack()
    local entry = ExplosiveBullets.Types[ExplosiveBullets.Type] or ExplosiveBullets.Types[1]
    return entry.Attack
end

local function DamageStats()
    local bonus = ExplosiveBullets.Damage
    return {
        { gamedataStatType.ExplosionDamagePercentBonus, gameStatModifierType.Additive, bonus },
        { gamedataStatType.GrenadeDamagePercentBonus, gameStatModifierType.Additive, bonus }
    }
end

local function Explode(player, position, now)
    if not position or now - s_LastExplosion < 1 / math.max(1, ExplosiveBullets.Rate) then return end
    if Explosion.At(player, position, Attack()) then s_LastExplosion = now end
end

function ExplosiveBullets.OnShot()
    if not ExplosiveBullets.Enabled or not Weapon.Ranged() then return end
    if math.random(100) > ExplosiveBullets.Chance then return end
    s_Shot = os.clock()
end

function ExplosiveBullets.OnHit(hitEvent)
    if not ExplosiveBullets.Enabled or not s_Shot then return end

    local attack = hitEvent.attackData
    local instigator = attack and attack:GetInstigator()
    if not instigator or not instigator:IsPlayer() then return end
    if EnumInt(attack:GetAttackType()) ~= EnumInt(gamedataAttackType.Ranged) then return end

    s_Shot = nil
    if not ExplosiveBullets.OnEnemies then return end
    local position = hitEvent.hitPosition
    s_Hit = { x = position.x, y = position.y, z = position.z }
end

function ExplosiveBullets.Update(player, now)
    local damage = ExplosiveBullets.Enabled and ExplosiveBullets.Damage > 0
    StatModifiers.Sync(OWNER, damage, ExplosiveBullets.Damage, player:GetEntityID(), DamageStats)

    if not ExplosiveBullets.Enabled then
        s_Shot, s_Hit = nil, nil
        return
    end

    if s_Hit then
        local hit = s_Hit
        s_Hit = nil
        Explode(player, hit, now)
        return
    end

    if not s_Shot or now - s_Shot < HIT_WINDOW then return end
    s_Shot = nil
    if ExplosiveBullets.OnSurfaces then Explode(player, Aim.Point(player), now) end
end

function ExplosiveBullets.Reset()
    s_Shot, s_Hit = nil, nil
end

return ExplosiveBullets
