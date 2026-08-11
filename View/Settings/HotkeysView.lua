local Buttons = require("UI").Buttons
local Bindings = require("Controls/Bindings")
local BindingsConfig = require("Config/BindingsConfig")
local Registry = require("UI/Registry/OptionRegistry")

local ensured = false
local function EnsureRegistered()
    if ensured then return end
    require("Features/Self/SelfConfig")()
    require("Features/Weapons/WeaponConfig")()
    require("Features/Vehicles/VehicleConfig")()
    require("Features/Teleports/TeleportConfig")()
    require("Features/World/WorldConfig")()
    Registry.RegisterHotkeyActions()
    ensured = true
end

local function HotkeysView()
    EnsureRegistered()
    local toggles = {}
    for _, entry in ipairs(Registry.GetAll()) do
        if entry.Kind == Registry.Kind.Toggle then table.insert(toggles, entry) end
    end
    Buttons.OptionExtended("Registered Toggles", "", tostring(#toggles),
        "Every registered toggle below can use a keyboard or controller binding.")
    Buttons.Option("Clear All Toggle Hotkeys", "Remove every optional toggle binding.", function()
        for _, entry in ipairs(toggles) do
            local action = Registry.GetHotkeyAction(entry)
            Bindings.Actions[action] = { keys = {}, btns = {} }
        end
        BindingsConfig.Save()
    end)

    local category
    for _, entry in ipairs(toggles) do
        if entry.Category ~= category then
            category = entry.Category
            local categoryLabel = tostring(category):gsub("^%l", string.upper)
            Buttons.Break("", categoryLabel)
        end
        local action = Registry.GetHotkeyAction(entry)
        Bindings.EnsureAction(action)
        Buttons.Bind(Registry.GetLabel(entry), action, Registry.GetTip(entry))
    end
end

return { title = "Toggle Hotkeys", view = HotkeysView }
