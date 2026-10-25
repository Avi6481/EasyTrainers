local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Notification = require("UI/Panels/Notification/Notification")
local StatusEffect = require("Utils/StatusEffect")
local StatModifiers = require("Utils/StatModifiers")
local Bindings = require("Controls/Bindings")
local NavigationConfig = require("Config/NavigationConfig")
local UIConfig = require("Config/UIConfig")
local BindingsConfig = require("Config/BindingsConfig")
local OptionConfig = require("Config/OptionConfig")

local AppearanceView = require("View/Settings/AppearanceView")
local NavigationView = require("View/Settings/NavigationView")
local NotificationView = require("View/Settings/NotificationView")
local TranslationsView = require("View/Settings/TranslationsView")
local AboutView = require("View/Settings/AboutView")
local HotkeysView = require("View/Settings/HotkeysView")
local BlockedControlsView = require("View/Settings/BlockedControlsView")

local function SaveAll()
    UIConfig.Save()
    NavigationConfig.Save()
    BindingsConfig.Save()
    OptionConfig.Save()
end

local function ResetAll()
    NavigationConfig.Reset()
    Bindings.ResetAll()
end

local function ClearTrainerEffects()
    StatusEffect.ClearAll()
    local count = StatModifiers.RemoveAll()
    Notification.Success(string.format("Removed trainer effects and %d modifier groups", count), 3)
end

local function SettingsView()
    Buttons.Submenu(L("settingsmenu.navigation.label"), NavigationView, tip("settingsmenu.navigation.tip"))
    Buttons.Submenu("Hotkeys", HotkeysView, "Assign keyboard or controller hotkeys to toggles and one-shot actions like Repair Vehicle or Clear Wanted Level.")
    Buttons.Submenu("Blocked Controls", BlockedControlsView, "Choose which game controls are blocked while the menu is open, closed, in mouse mode, or typing.")
    Buttons.Submenu(L("settingsmenu.translations.label"), TranslationsView, tip("settingsmenu.translations.tip"))
    Buttons.Submenu("Appearance", AppearanceView, "Layout and colors for the menu.")
    Buttons.Submenu(L("settingsmenu.notifications.label"), NotificationView, tip("settingsmenu.notifications.tip"))
    Buttons.Submenu("About", AboutView, "Version, credits, and project information.")

    Buttons.Break("Configuration")
    Buttons.Option(L("settingsmenu.saveall.label"), tip("settingsmenu.saveall.tip"), SaveAll)
    Buttons.Option(L("settingsmenu.resetall.label"), tip("settingsmenu.resetall.tip"), ResetAll)

    Buttons.Break("Save Safety")
    Buttons.Option("Clear Trainer Effects", "Removes every status effect and stat modifier the trainer applied. Toggles that are still on apply again on the next frame.", ClearTrainerEffects)
end

return Submenu.Create("settingsmenu.title", SettingsView)
