local Notify = require("Utils/Notify")
local Arsenal = require("Features/Weapons/Arsenal")
local Raygun = require("Features/Weapons/Raygun")

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

function Management.GiveRaygun()
    if Raygun.Give() then
        Notify.Success(L("notify.weapons.raygun"))
        return
    end
    Notify.Error(L("notify.weapons.raygunfailed"))
end

return Management
