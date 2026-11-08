local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Dev = require("Features/Development/Dev")
local Catalog = require("Features/Development/Catalog")
local Development = require("Features/Development/Development")
local Snapshot = require("Features/Development/Snapshot")
local Attributes = require("Features/Development/Attributes")
local Perks = require("Features/Development/Perks")
local PerkFilter = require("Features/Development/PerkFilter")
local PerkRow = require("View/Development/PerkRow")
local PerkFilterRow = require("View/Development/PerkFilterRow")

local AttributeView = {}

local TIERS = {
    [0] = "development.tiers.relic",
    [4] = "development.tiers.novice",
    [9] = "development.tiers.adept",
    [15] = "development.tiers.expert",
    [20] = "development.tiers.master"
}

local s_Menus = {}
local s_Values = {}
local s_Refs = {}

local function Key(attribute)
    return "development.attributes." .. attribute.Id:lower()
end

local function ValueRef(attribute)
    local ref = s_Refs[attribute.Id]
    if ref then return ref end

    s_Values[attribute.Id] = { Value = Dev.MIN_ATTRIBUTE }
    ref = Ref.Field(s_Values[attribute.Id], "Value")
    s_Refs[attribute.Id] = ref
    return ref
end

local function TierLabel(required)
    local key = TIERS[required]
    if not key then return tostring(required) end
    if required == 0 then return L(key) end
    return tip("development.tiers.format", { tier = key, level = required })
end

local function AttributeSlider(attribute)
    local ref = ValueRef(attribute)
    s_Values[attribute.Id].Value = Snapshot.Attributes[attribute.Id] or Dev.MIN_ATTRIBUTE

    if Widgets.SliderInt(L(Key(attribute) .. ".label"), ref, Dev.MIN_ATTRIBUTE, Dev.MAX_ATTRIBUTE, 1, "%d") then
        Development.Queue(Attributes.Set, attribute, ref.Value, Development.ForceBuy)
    end
    Widgets.Tip(L("development.attribute.tip"))
end

local function Actions(attribute)
    if Widgets.Button(L("development.maxall.label")) then
        Development.Queue(Perks.MaxAll, attribute, Development.ForceBuy)
    end
    Widgets.Tip(L(attribute.Relic and "development.maxall.relictip" or "development.maxall.tip"))

    if Widgets.HoldButton(L("development.sellall.label")) then
        Development.Queue(Perks.SellAll, attribute, Development.ForceBuy)
    end
    Widgets.Tip(L("development.sellall.tip"))

    PerkFilterRow.Draw()
end

local function PerkList(attribute)
    local tier = nil
    local shown = 0
    for _, perk in ipairs(Catalog.ByAttribute[attribute.Id] or {}) do
        if PerkFilter.Visible(perk) then
            if perk.Required ~= tier then
                tier = perk.Required
                Widgets.Break(TierLabel(tier))
            end
            PerkRow.Draw(perk)
            shown = shown + 1
        end
    end
    if shown == 0 then PerkFilterRow.Empty() end
end

local function View(attribute)
    Development.Watch()
    if not Snapshot.Ready then
        Widgets.ValueRow(L("development.loading"), "")
        return
    end

    if not attribute.Relic then AttributeSlider(attribute) end
    Actions(attribute)
    PerkList(attribute)
end

function AttributeView.Menu(attribute)
    local menu = s_Menus[attribute.Id]
    if menu then return menu end

    menu = Submenu.Create(Key(attribute) .. ".label", function() View(attribute) end)
    s_Menus[attribute.Id] = menu
    return menu
end

return AttributeView
