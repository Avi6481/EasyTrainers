local ConfigManager = require("Config/OptionConfig")
local AutoTeleport = require("Features/Teleports/AutoTeleport")
local Settings = require("Features/Teleports/TeleportViewStates")
local Toggle = ConfigManager.DefineToggle

local function RegisterAllTelportOptions()

    ConfigManager.RegisterAll({
        Toggle("toggle.teleport.autowaypoint", AutoTeleport.toggleAutoWaypoint, false, {
            LabelKey = "teleport.autowaypoint.label", TipKey = "teleport.autowaypoint.tip",
            Keywords = { "map", "marker", "automatic" },
        }),
        Toggle("toggle.teleport.autoquest", AutoTeleport.toggleAutoQuest, false, {
            LabelKey = "teleport.autoquest.label", TipKey = "teleport.autoquest.tip",
            Keywords = { "mission", "objective", "automatic" },
        }),
        Toggle("view.teleport.showforward", Settings.showForward, true, {
            LabelKey = "teleport.showforward.label", TipKey = "teleport.showforward.tip",
            Keywords = { "forward", "layout" },
        }),
        Toggle("view.teleport.showquick", Settings.showQuick, true, {
            LabelKey = "teleport.showquick.label", TipKey = "teleport.showquick.tip",
            Keywords = { "quick", "layout" },
        }),
        Toggle("view.teleport.showquickdistance", Settings.showQuickDistance, true, {
            LabelKey = "teleport.showquickdistance.label", TipKey = "teleport.showquickdistance.tip",
            Keywords = { "quick", "distance", "layout" },
        }),
        Toggle("view.teleport.showcategorydistance", Settings.showCategoryDistance, true, {
            LabelKey = "teleport.showcategorydistance.label", TipKey = "teleport.showcategorydistance.tip",
            Keywords = { "category", "distance", "layout" },
        }),
        Toggle("view.teleport.showcreatorfilter", Settings.showCreatorFilter, false, {
            LabelKey = "teleport.showcreatorfilter.label", TipKey = "teleport.showcreatorfilter.tip",
            Keywords = { "author", "filter", "layout" },
        }),
        Toggle("view.teleport.showdistrictfilter", Settings.showDistrictFilter, true, {
            LabelKey = "teleport.showdistrictfilter.label", TipKey = "teleport.showdistrictfilter.tip",
            Keywords = { "area", "district", "filter", "layout" },
        }),
    })
end

return RegisterAllTelportOptions
