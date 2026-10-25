local Logger = require("Core/Logger")

local StatusEffect = {}

local TAG = "EasyTrainer.StatusEffect"

local s_Owners = {}

local function GetContext()
    local system = Game.GetStatusEffectSystem()
    local player = Game.GetPlayer()
    if not system or not player then return nil, nil end
    return system, player
end

local function Apply(effect)
    local system, player = GetContext()
    if not system then return false end

    local entityID = player:GetEntityID()
    system:ApplyStatusEffect(entityID, effect, TweakDBID.new(TAG), entityID, 1, Vector4.new(0, 0, 0, 0), false)
    return true
end

local function Remove(effect)
    local system, player = GetContext()
    if not system then return false end

    system:RemoveStatusEffect(player:GetEntityID(), effect)
    return true
end

local function IsOwned(effect)
    return s_Owners[effect] ~= nil and next(s_Owners[effect]) ~= nil
end

function StatusEffect.Set(effect, enable, owner)
    owner = owner or "Default"
    local owners = s_Owners[effect]

    if enable then
        if owners and owners[owner] then return end
        local first = not IsOwned(effect)
        if first and not Apply(effect) then return end

        s_Owners[effect] = owners or {}
        s_Owners[effect][owner] = true
        if first then Logger.Log("StatusEffect: applied " .. tostring(effect) .. " for " .. owner) end
        return
    end

    if not owners or not owners[owner] then return end
    owners[owner] = nil
    if IsOwned(effect) then return end

    s_Owners[effect] = nil
    Remove(effect)
    Logger.Log("StatusEffect: removed " .. tostring(effect) .. " for " .. owner)
end

function StatusEffect.Reapply(effect, owner)
    if not s_Owners[effect] or not s_Owners[effect][owner] then
        StatusEffect.Set(effect, true, owner)
        return
    end

    if not StatusEffect.Has(effect) then Apply(effect) end
end

function StatusEffect.Has(effect)
    local system, player = GetContext()
    if not system then return false end
    return system:HasStatusEffect(player:GetEntityID(), effect)
end

function StatusEffect.GetOwnedEffects()
    local effects = {}
    for effect in pairs(s_Owners) do
        if IsOwned(effect) then table.insert(effects, effect) end
    end
    table.sort(effects)
    return effects
end

function StatusEffect.RemoveUnowned(effects)
    local removed = 0
    for _, effect in ipairs(effects or {}) do
        if not IsOwned(effect) and StatusEffect.Has(effect) and Remove(effect) then
            removed = removed + 1
            Logger.Log("StatusEffect: removed saved trainer effect " .. tostring(effect))
        end
    end
    return removed
end

local function Key(id)
    return id and (tostring(id.hash) .. ":" .. tostring(id.length)) or ""
end

function StatusEffect.RemoveStale(effects)
    local system, player = GetContext()
    if not system then return nil end

    local wanted = {}
    for _, effect in ipairs(effects or {}) do wanted[Key(TweakDBID.new(effect))] = effect end
    local tag, legacy = Key(TweakDBID.new(TAG)), Key(player:GetRecordID())

    local ok, applied = pcall(function() return system:GetAppliedEffects(player:GetEntityID()) end)
    if not ok or type(applied) ~= "table" then return nil end

    local removed = 0
    for _, entry in ipairs(applied) do
        local effect = wanted[Key(entry:GetRecord():GetID())]
        local instigator = Key(entry:GetInstigatorStaticDataID())
        if effect and not IsOwned(effect) and (instigator == tag or instigator == legacy) and Remove(effect) then
            removed = removed + 1
            Logger.Log("StatusEffect: removed stale trainer effect " .. effect)
        end
    end
    return removed
end

function StatusEffect.ClearAll()
    for effect in pairs(s_Owners) do
        Remove(effect)
        Logger.Log("StatusEffect: cleared " .. tostring(effect))
    end
    s_Owners = {}
end

function StatusEffect.Forget()
    s_Owners = {}
end

return StatusEffect
