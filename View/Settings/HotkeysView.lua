local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Bindings = require("Controls/Bindings")
local BindingsConfig = require("Config/BindingsConfig")
local Registry = require("UI/Registry/OptionRegistry")
local Weapons = require("Features/Weapons")

local s_Toggles = nil

local function GetToggles()
    if s_Toggles then return s_Toggles end

    s_Toggles = {}
    for _, entry in ipairs(Registry.GetAll()) do
        if Registry.IsHotkeyable(entry) then
            Bindings.EnsureAction(Registry.GetHotkeyAction(entry))
            table.insert(s_Toggles, entry)
        end
    end
    return s_Toggles
end

local function ClearAll()
    for _, entry in ipairs(GetToggles()) do
        Bindings.Actions[Registry.GetHotkeyAction(entry)] = { keys = {}, btns = {} }
    end
    BindingsConfig.Save()
end

local function HotkeysView()
    local toggles = GetToggles()
    Buttons.OptionExtended("Bindable Options", "", tostring(#toggles), "Every toggle below can use a keyboard or controller binding. Press Delete (or View on controller) while binding to clear just that one.")
    Buttons.Option("Clear All Toggle Hotkeys", "Remove every optional toggle binding.", ClearAll)

    Buttons.Break("Ability Keys")
    Buttons.Bind("Blackwall", Weapons.BlackwallForce.Action, "Blackwalls the NPC you're looking at. Default: B.")
    Buttons.Bind("Nitrous Boost", "NITRO", "Held to fire the nitrous boost.")

    local category = nil
    for _, entry in ipairs(toggles) do
        if entry.Category ~= category then
            category = entry.Category
            Buttons.Break((tostring(category):gsub("^%l", string.upper)))
        end
        Buttons.Bind(Registry.GetLabel(entry), Registry.GetHotkeyAction(entry), Registry.GetTip(entry))
    end
end

return Submenu.Create("Hotkeys", HotkeysView)
