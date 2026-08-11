local Buttons = require("UI").Buttons

local AppearanceView = require("View/Settings/AppearanceView")
local NavigationView = require("View/Settings/NavigationView")
local NotificationView = require("View/Settings/NotificationView")
local TranslationsView = require("View/Settings/TranslationsView")
local AboutView = require("View/Settings/AboutView")
local HotkeysView = require("View/Settings/HotkeysView")

local Bindings = require("Controls/Bindings")
local NavigationConfig = require("Config/NavigationConfig")
local UIConfig = require("Config/UIConfig")
local BindingsConfig = require("Config/BindingsConfig")
local OptionConfig = require("Config/OptionConfig")

local function DrawSettings()
    Buttons.Submenu(L("settingsmenu.navigation.label"), NavigationView, tip("settingsmenu.navigation.tip"))
    Buttons.Submenu("Toggle Hotkeys", HotkeysView, "Assign persistent keyboard or controller hotkeys to registered toggles.")
    Buttons.Submenu(L("settingsmenu.translations.label"), TranslationsView, tip("settingsmenu.translations.tip"))

    Buttons.Break(L("settingsmenu.ui.label"), "")
    Buttons.Submenu("Appearance", AppearanceView, "Layout and colors for the consolidated interface.")
    Buttons.Submenu(L("settingsmenu.notifications.label"), NotificationView, tip("settingsmenu.notifications.tip"))
    Buttons.Submenu("About", AboutView, "Version, credits, and project information.")

    Buttons.Break("Configuration", "")
    Buttons.Option(L("settingsmenu.saveall.label"), tip("settingsmenu.saveall.tip"), function()
        UIConfig.Save()
        NavigationConfig.Save()
        BindingsConfig.Save()
        OptionConfig.Save()
    end)
    Buttons.Option(L("settingsmenu.resetall.label"), tip("settingsmenu.resetall.tip"), function()
        NavigationConfig.Reset()
        Bindings.ResetAll()
    end)
end

return { title = "settingsmenu.title", view = DrawSettings }
