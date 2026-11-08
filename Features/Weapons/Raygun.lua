local Inventory = require("Utils/Inventory")

local Raygun = {}

local RECORD = "Items.Preset_Lexington_Toygun"

function Raygun.Give()
    return Inventory.Give(RECORD, 1)
end

return Raygun
