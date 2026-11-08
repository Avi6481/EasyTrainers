local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Catalog = require("Features/Development/Catalog")
local Development = require("Features/Development/Development")
local Snapshot = require("Features/Development/Snapshot")
local PerkFilter = require("Features/Development/PerkFilter")
local PerkRow = require("View/Development/PerkRow")
local PerkFilterRow = require("View/Development/PerkFilterRow")

local PerkSearchView = {}

local s_State = {
    Query = ""
}

local s_Query = Ref.Field(s_State, "Query")
local s_Matches = {}
local s_MatchedQuery = nil
local s_MatchedRelic = nil

local function Matches()
    if s_MatchedQuery == s_State.Query and s_MatchedRelic == Snapshot.RelicUnlocked then return s_Matches end

    s_Matches = {}
    s_MatchedQuery = s_State.Query
    s_MatchedRelic = Snapshot.RelicUnlocked
    if s_State.Query == "" then return s_Matches end

    for _, perk in ipairs(Catalog.Perks) do
        if (Snapshot.RelicUnlocked or not perk.Attribute.Relic) and Widgets.SearchMatch(perk.Name, s_State.Query) then
            table.insert(s_Matches, perk)
        end
    end
    return s_Matches
end

local function View()
    Development.Watch()

    local matches = Snapshot.Ready and Matches() or {}
    Widgets.SearchRow(s_Query, L("development.search.placeholder"), #matches)
    PerkFilterRow.Draw()

    if not Snapshot.Ready then
        Widgets.ValueRow(L("development.loading"), "")
        return
    end

    if s_State.Query == "" then
        Widgets.ValueRow(L("development.search.empty"), "")
        return
    end

    if #matches == 0 then
        Widgets.ValueRow(L("development.search.none"), "")
        return
    end

    local shown = 0
    for _, perk in ipairs(matches) do
        if PerkFilter.Visible(perk) then
            PerkRow.Draw(perk)
            shown = shown + 1
        end
    end
    if shown == 0 then PerkFilterRow.Empty() end
end

PerkSearchView.Menu = Submenu.Create("development.search.title", View)

return PerkSearchView
