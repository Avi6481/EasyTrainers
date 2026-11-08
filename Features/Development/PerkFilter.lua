local Snapshot = require("Features/Development/Snapshot")

local PerkFilter = {
    Mode = "All"
}

PerkFilter.Modes = { "All", "Active", "Inactive" }

function PerkFilter.Visible(perk)
    if PerkFilter.Mode == "All" then return true end
    return (Snapshot.Level(perk) > 0) == (PerkFilter.Mode == "Active")
end

return PerkFilter
