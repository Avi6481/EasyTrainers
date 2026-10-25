local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Restrictions = require("Controls/Restrictions")
local Notification = require("UI/Panels/Notification/Notification")

local s_Refs = {}
local s_Menus = {}

local function Ref(mode, effect)
    s_Refs[mode] = s_Refs[mode] or {}
    local ref = s_Refs[mode][effect] or {}
    ref.value = Restrictions.Blocked[mode][effect] == true
    s_Refs[mode][effect] = ref
    return ref
end

local function ModeView(mode)
    Buttons.Option("Reset to Defaults", "Restore the default blocked controls for this mode.", function() Restrictions.ResetMode(mode.Id) end)

    Buttons.Break("Blocked Controls")
    for _, entry in ipairs(Restrictions.Catalog) do
        Buttons.GhostToggle(entry.Label, Ref(mode.Id, entry.Id), "Block " .. entry.Label:lower() .. " in this mode.", function(value)
            Restrictions.SetBlocked(mode.Id, entry.Id, value)
        end)
    end
end

local function ModeMenu(mode)
    s_Menus[mode.Id] = s_Menus[mode.Id] or Submenu.Create(mode.Label, function() ModeView(mode) end)
    return s_Menus[mode.Id]
end

local function ClearStuck()
    local removed = Restrictions.RemoveStale()
    if removed == nil then
        Notification.Error("Load into the game first", 2)
    elseif removed == 0 then
        Notification.Info("No stuck restrictions found", 2)
    else
        Notification.Success("Cleared " .. tostring(removed) .. " stuck restrictions", 2)
    end
end

local function BlockedControlsView()
    for _, mode in ipairs(Restrictions.Modes) do
        Buttons.Submenu(mode.Label, ModeMenu(mode), mode.Tip)
    end

    Buttons.Break("Troubleshooting")
    Buttons.Option("Clear Stuck Restrictions", "Removes trainer restrictions left behind in a save, such as blocked fast travel, phone calls, or movement.", ClearStuck)
end

return Submenu.Create("Blocked Controls", BlockedControlsView)
