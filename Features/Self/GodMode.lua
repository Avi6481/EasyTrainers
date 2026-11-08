local StatModifiers = require("Utils/StatModifiers")

local GodMode = {
    Enabled = false
}

local OWNER = "GodMode"
local SOURCE = "EasyTrainer"

local s_Applied = nil

local function Build()
    return { { gamedataStatType.IsInvulnerable, gameStatModifierType.Additive, 1 } }
end

local function SetInvulnerable(player, enabled)
    local system = Game.GetGodModeSystem()
    if not system then return false, false end

    local entityID = player:GetEntityID()
    local source = CName.new(SOURCE)
    system:ClearGodMode(entityID, source)

    if enabled then system:AddGodMode(entityID, gameGodModeType.Invulnerable, source) end
end

function GodMode.Update(player)
    StatModifiers.Sync(OWNER, GodMode.Enabled, true, player:GetEntityID(), Build)

    if GodMode.Enabled == s_Applied then return end
    s_Applied = GodMode.Enabled

    SetInvulnerable(player, GodMode.Enabled)
end

function GodMode.Reset()
    s_Applied = nil
end

function GodMode.Shutdown(player)
    if s_Applied and player then SetInvulnerable(player, false) end
    s_Applied = nil
end

return GodMode
