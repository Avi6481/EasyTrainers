local Repair = require("Features/Vehicles/Repair")

local GodMode = {
    Enabled = false
}

local SOURCE = "EasyTrainer"

local s_Protected = nil

local function Set(id, enable)
    local system = Game.GetGodModeSystem()
    if enable then
        system:AddGodMode(id, gameGodModeType.Invulnerable, CName.new(SOURCE))
    else
        system:RemoveGodMode(id, gameGodModeType.Invulnerable, CName.new(SOURCE))
    end
end

local function Release()
    if s_Protected then Set(s_Protected, false) end
    s_Protected = nil
end

function GodMode.Update(vehicle)
    if not GodMode.Enabled or not vehicle then
        if s_Protected and not GodMode.Enabled then Release() end
        return
    end

    local id = vehicle:GetEntityID()
    if s_Protected and s_Protected.hash == id.hash then return end

    Release()
    Set(id, true)
    Repair.Fix(vehicle)
    s_Protected = id
end

function GodMode.Reset()
    s_Protected = nil
end

function GodMode.Shutdown()
    Release()
end

return GodMode
