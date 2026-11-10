local Notify = require("Utils/Notify")
local Arsenal = require("Features/Weapons/Arsenal")
local Raygun = require("Features/Weapons/Raygun")
local Specials = require("Features/Weapons/Specials")

local Management = {}

local function Counted(key, empty, count)
    if count > 0 then
        Notify.Success(tip("notify.weapons." .. key, { count = count }))
        return
    end
    Notify.Info(L("notify.weapons." .. empty))
end

function Management.GiveWall(player)
    Counted("givewall", "nothing", Arsenal.GiveWall(player))
end

function Management.GiveIconic(player)
    Counted("giveiconic", "nothing", Arsenal.GiveIconic(player))
end

function Management.RemoveAll(player)
    Counted("removeall", "noneremoved", Arsenal.RemoveAll(player))
end

Management.Specials = Specials.List
Management.SpecialName = Specials.Name

local s_SpecialActions = {}

function Management.GiveSpecial(special)
    local action = s_SpecialActions[special.Key]
    if action then return action end

    action = function()
        local name = Specials.Name(special)
        if Specials.Give(special) then
            Notify.Success(tip("notify.weapons.special", { name = name }))
            return
        end
        Notify.Error(tip("notify.weapons.specialfailed", { name = name }))
    end
    s_SpecialActions[special.Key] = action
    return action
end

function Management.GiveRaygun()
    if Raygun.Give() then
        Notify.Success(L("notify.weapons.raygun"))
        return
    end
    Notify.Error(L("notify.weapons.raygunfailed"))
end

return Management
