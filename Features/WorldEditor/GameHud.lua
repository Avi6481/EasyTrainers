local Logger = require("Core/Logger")

local GameHud = {
    Hide = true
}

local HUD_LAYER = "inkHUDLayer"

local s_Hidden = false
local s_Failed = false

local function InMenu()
    local ok, inMenu = pcall(function()
        local defs = Game.GetAllBlackboardDefs()
        local blackboard = Game.GetBlackboardSystem():Get(defs.UI_System)
        return blackboard ~= nil and blackboard:GetBool(defs.UI_System.IsInMenu)
    end)
    return ok and inMenu == true
end

function GameHud.InMenu()
    return InMenu()
end

function GameHud.SetHidden(hidden)
    if s_Hidden == hidden then return end

    local ok, err = pcall(function()
        Game.GetInkSystem():GetLayer(CName.new(HUD_LAYER)):GetVirtualWindow():SetVisible(not hidden)
    end)
    if not ok then
        if not s_Failed then Logger.Log("WorldEditor: failed to change game HUD visibility (" .. tostring(err) .. ")") end
        s_Failed = true
        return
    end
    s_Hidden = hidden
end

function GameHud.Forget()
    s_Hidden = false
end

return GameHud
