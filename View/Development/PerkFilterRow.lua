local Ref = require("Core/Ref")
local Widgets = require("Widgets/Widgets")
local PerkFilter = require("Features/Development/PerkFilter")

local PerkFilterRow = {}

local s_Mode = Ref.Choice(PerkFilter, "Mode", PerkFilter.Modes)
local s_Items = nil

local function Items()
    if s_Items then return s_Items end

    s_Items = {}
    for index, mode in ipairs(PerkFilter.Modes) do
        s_Items[index] = { Label = L("development.perkfilter.modes." .. mode:lower()), Tip = "" }
    end
    return s_Items
end

function PerkFilterRow.Draw()
    Widgets.Dropdown(L("development.perkfilter.label"), s_Mode, Items())
    Widgets.Tip(L("development.perkfilter.tip"))
end

function PerkFilterRow.Empty()
    Widgets.ValueRow(L("development.perkfilter.none"), "")
end

return PerkFilterRow
