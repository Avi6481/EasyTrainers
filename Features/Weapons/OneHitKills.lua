local OneHitKills = {
    Enabled = false
}

local s_Targets = {}

function OneHitKills.OnHit(target, hitEvent)
    if not OneHitKills.Enabled or not target or target:IsPlayer() then return end

    local attack = hitEvent.attackData
    local instigator = attack and attack:GetInstigator()
    if instigator and instigator:IsPlayer() then table.insert(s_Targets, target) end
end

local function Protected(godMode, id)
    return godMode:HasGodMode(id, gameGodModeType.Immortal) or godMode:HasGodMode(id, gameGodModeType.Invulnerable)
end

local function Kill(player, pools, godMode, target)
    if target:IsDead() then return end

    local id = target:GetEntityID()
    if Protected(godMode, id) then return end
    pools:RequestSettingStatPoolValue(id, gamedataStatPoolType.Health, 0, player, false)
end

function OneHitKills.Update(player)
    if #s_Targets == 0 then return end

    local targets = s_Targets
    s_Targets = {}
    if not OneHitKills.Enabled then return end

    local pools = Game.GetStatPoolsSystem()
    local godMode = Game.GetGodModeSystem()
    if not pools or not godMode then return end
    for _, target in ipairs(targets) do pcall(Kill, player, pools, godMode, target) end
end

function OneHitKills.Reset()
    s_Targets = {}
end

return OneHitKills
