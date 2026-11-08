local Logger = require("Core/Logger")

local Explosion = {}

local s_Records = {}
local s_Failed = false

local function Record(attack)
    local record = s_Records[attack]
    if record == nil then
        record = TweakDB:GetRecord(attack) or false
        s_Records[attack] = record
    end
    return record or nil
end

function Explosion.At(player, position, attack, duration)
    local record = position and Record(attack)
    if not record then return false end

    local effect = GetSingleton("gameAttack_GameEffect")
    if not effect then return false end

    local weapon = player:GetActiveWeapon()
    local ok, err = pcall(function()
        effect:SpawnExplosionAttack(record, weapon, player, player, Vector4.new(position.x, position.y, position.z, 1), duration or 0.05)
    end)
    if not ok and not s_Failed then
        s_Failed = true
        Logger.Log("Explosion failed: " .. tostring(err))
    end
    return ok
end

return Explosion
