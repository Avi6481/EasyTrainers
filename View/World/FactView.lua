local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Notification = require("UI/Panels/Notification/Notification")
local GameFacts = require("Utils/Facts")
local WorldFacts = require("Features/World/WorldFacts")

local CATEGORIES = {
    { Key = "RomanceFlags", Label = "gamefacts.categories.romance" },
    { Key = "StoryOutcomeFlags", Label = "gamefacts.categories.storyoutcomes" },
    { Key = "SmartWeaponStates", Label = "gamefacts.categories.skippystates" },
    { Key = "GameplayToggles", Label = "gamefacts.categories.gameplaytoggles" },
    { Key = "WorldEventFlags", Label = "gamefacts.categories.worldevents" },
    { Key = "CensorshipFlags", Label = "gamefacts.categories.censorship" }
}

local s_Category = { index = 1, expanded = false }
local s_CategoryLabels = {}
local s_Toggles = {}
local s_LoadedCategories = {}

for _, category in ipairs(CATEGORIES) do table.insert(s_CategoryLabels, category.Label) end

local function LoadCategory(key)
    if s_LoadedCategories[key] then return end
    s_LoadedCategories[key] = true
    for _, entry in ipairs(GameFacts.FactFlags[key]) do
        s_Toggles[entry.id] = { value = WorldFacts.IsTrue(entry.id) }
    end
end

local function RelationshipView()
    for _, entry in ipairs(GameFacts.RelationshipTrackingFacts) do
        local value = WorldFacts.Get(entry.id)
        local display = value ~= nil and value ~= "" and tostring(value) or L("gamefacts.notavailable.label")
        Buttons.OptionExtended(entry.name, nil, display, L("gamefacts.relationshiptracking.label"))
    end
end

local RelationshipMenu = Submenu.Create("gamefacts.relationshiptracking.label", RelationshipView)

local function FactToggle(entry)
    local toggle = s_Toggles[entry.id]
    Buttons.Toggle(entry.name, toggle, entry.desc, function(enabled)
        WorldFacts.SetBool(entry.id, enabled)
        local key = enabled and "gamefacts.factnotification.enabled" or "gamefacts.factnotification.disabled"
        Notification.Info(tip(key, { name = entry.name }), 2)
    end)
end

local function FactView()
    Buttons.Submenu(L("gamefacts.relationshiptracking.label"), RelationshipMenu, "View the current relationship and story progression values.")
    Buttons.Break("")
    Buttons.Dropdown(L("gamefacts.category.label"), s_Category, s_CategoryLabels, L("gamefacts.category.tip"))

    local category = CATEGORIES[s_Category.index or 1]
    local entries = GameFacts.FactFlags[category.Key]
    LoadCategory(category.Key)

    Buttons.Break(L(category.Label) .. "  /  " .. tostring(#entries))
    for _, entry in ipairs(entries) do FactToggle(entry) end
end

return Submenu.Create("gamefacts.title", FactView)
