local OptionConfig = require("Config/OptionConfig")
local AutoTeleport = require("Features/Teleports/AutoTeleport")
local ViewStates = require("Features/Teleports/TeleportViewStates")
local Teleport = require("Utils/Teleport")

local function Action(id, action, key, keywords)
    return OptionConfig.DefineButton(id, action, { LabelKey = key .. ".label", TipKey = key .. ".tip", Category = "teleport", Keywords = keywords })
end

local function Toggle(id, ref, default, key, keywords)
    return OptionConfig.DefineToggle(id, ref, default, {
        LabelKey = key .. ".label",
        TipKey = key .. ".tip",
        Keywords = keywords
    })
end

local function RegisterAllTeleportOptions()
    OptionConfig.RegisterAll({
        {
            Id = "number.teleport.forwarddistance",
            Kind = OptionConfig.Registry.Kind.Number,
            Ref = ViewStates.ForwardDistance,
            Default = 2,
            Category = "teleport",
            LabelKey = "teleport.forwarddistance.label",
            TipKey = "teleport.forwarddistance.tip"
        },
        Action("button.teleport.forward", ViewStates.TeleportForward, "teleport.teleportforward", { "forward", "blink" }),
        Action("button.teleport.waypoint", Teleport.ToWaypoint, "teleport.waypointmarker", { "map", "marker" }),
        Action("button.teleport.quest", Teleport.ToQuestMarker, "teleport.questmarker", { "mission", "objective" }),
        Toggle("toggle.teleport.autowaypoint", AutoTeleport.Waypoint, false, "teleport.autowaypoint", { "map", "marker", "automatic" }),
        Toggle("toggle.teleport.autoquest", AutoTeleport.Quest, false, "teleport.autoquest", { "mission", "objective", "automatic" }),
        Toggle("view.teleport.showforward", ViewStates.ShowForward, true, "teleport.showforward", { "forward", "layout" }),
        Toggle("view.teleport.showquick", ViewStates.ShowQuick, true, "teleport.showquick", { "quick", "layout" }),
        Toggle("view.teleport.showquickdistance", ViewStates.ShowQuickDistance, true, "teleport.showquickdistance", { "quick", "distance", "layout" }),
        Toggle("view.teleport.showcategorydistance", ViewStates.ShowCategoryDistance, true, "teleport.showcategorydistance", { "category", "distance", "layout" }),
        Toggle("view.teleport.showcreatorfilter", ViewStates.ShowCreatorFilter, false, "teleport.showcreatorfilter", { "author", "filter", "layout" }),
        Toggle("view.teleport.showdistrictfilter", ViewStates.ShowDistrictFilter, true, "teleport.showdistrictfilter", { "area", "district", "filter", "layout" }),
        Toggle("view.teleport.showmap", ViewStates.ShowMap, true, "teleport.showmap", { "map", "minimap", "layout" })
    })
end

return RegisterAllTeleportOptions
