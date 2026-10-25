local Teleport = require("Utils/Teleport")

local TeleportViewStates = {
    ForwardDistance = { value = 2, min = 1, max = 25 },
    ShowForward = { value = true },
    ShowQuick = { value = true },
    ShowQuickDistance = { value = true },
    ShowCategoryDistance = { value = true },
    ShowCreatorFilter = { value = false },
    ShowDistrictFilter = { value = true },
    ShowMap = { value = true }
}

function TeleportViewStates.TeleportForward()
    return Teleport.TeleportEntity(Game.GetPlayer(), Teleport.GetForwardOffset(TeleportViewStates.ForwardDistance.value))
end

return TeleportViewStates
