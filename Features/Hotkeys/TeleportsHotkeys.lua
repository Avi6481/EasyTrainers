local Define = require("Features/Hotkeys/Define")
local Teleports = require("Features/Teleports/Teleports")

local Toggle, Action = Define.Toggle, Define.Action

local TeleportsHotkeys = {
    Action("ToWaypoint", "teleports.waypoint", Teleports.ToWaypoint),
    Action("ToObjective", "teleports.objective", Teleports.ToObjective),
    Action("ToNearest", "teleports.tonearest", Teleports.ToNearest, { Silent = true }),
    Action("Forward", "teleports.forward", Teleports.Forward),
    Action("SaveHere", "teleports.custom.save", Teleports.SaveHere, { Note = "hotkeys.notes.savehere" }),
    Toggle("AutoWaypoint", "teleports.autowaypoint", Teleports, "AutoWaypoint"),
    Toggle("AutoObjective", "teleports.autoobjective", Teleports, "AutoObjective"),
    Toggle("SafeLanding", "teleports.safelanding", Teleports, "SafeLanding")
}

return TeleportsHotkeys
