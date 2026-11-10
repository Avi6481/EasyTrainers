local GameText = require("Utils/GameText")
local Inventory = require("Utils/Inventory")

local Specials = {}

Specials.List = {
    { Key = "stout", Record = "Items.Preset_Dildo_Stout_Legendary", Fallback = "Stout's Toy" },
    { Key = "rebecca", Record = "Items.Preset_Carnage_Edgerunners_Legendary", Fallback = "Guts" },
    { Key = "king", Record = "Items.Preset_Burya_King", Fallback = "King's Burya" },
    { Key = "witcher", Record = "Items.Preset_Sword_Witcher", Fallback = "Witcher Sword" },
    { Key = "sihil", Record = "Items.Preset_Sword_Sihil", Fallback = "Sihil" }
}

local MISSING = "Label Not Found"

local s_Names = {}

function Specials.Name(special)
    local name = s_Names[special.Key]
    if name then return name end

    local ok, display = pcall(function()
        local record = TweakDBInterface.GetItemRecord(TweakDBID.new(special.Record))
        return record and record:DisplayName() or nil
    end)
    name = ok and display and GameText.FromName(display, nil) or nil
    if not name or name == "" or name == MISSING then name = special.Fallback end
    s_Names[special.Key] = name
    return name
end

function Specials.Give(special)
    return Inventory.Give(special.Record, 1)
end

return Specials
