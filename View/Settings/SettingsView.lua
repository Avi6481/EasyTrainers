local InputBlock = require("Core/InputBlock")
local Language = require("Core/Language")
local Settings = require("Features/Settings/Settings")
local Hotkeys = require("Features/Hotkeys/Hotkeys")
local Theme = require("Style/Theme")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local FooterStyle = require("Panels/Footer/FooterStyle")
local Notification = require("Panels/Notification/Notification")
local HotkeysView = require("View/Settings/HotkeysView")
local TrainerEffectsView = require("View/Settings/TrainerEffectsView")
local ThemeView = require("View/Settings/ThemeView")
local LayoutView = require("View/Settings/LayoutView")
local NavigationView = require("View/Settings/NavigationView")
local BlockedControlsView = require("View/Settings/BlockedControlsView")
local NotificationsView = require("View/Settings/NotificationsView")
local LanguageView = require("View/Settings/LanguageView")
local AboutView = require("View/Settings/AboutView")

local SettingsView = {}

local s_Counts = {}
local s_ThemeKeys = {}
local s_LanguageCode = nil
local s_LanguageName = nil

local function Link(key, submenu, badge)
    Widgets.SubmenuButton(L(key .. ".label"), submenu, badge)
    Widgets.Tip(L(key .. ".tip"))
end

local function OnOff(enabled)
    return L(enabled and "hotkeys.info.on" or "hotkeys.info.off")
end

local function BoundCount()
    local count = #Hotkeys.Bound()
    if count == 0 then return nil end
    if not s_Counts[count] then s_Counts[count] = tostring(count) end
    return s_Counts[count]
end

local function ThemeName()
    local theme = Theme.List()[Theme.Index()]
    if not theme then return nil end
    if not s_ThemeKeys[theme.Id] then s_ThemeKeys[theme.Id] = "themes." .. theme.Id .. ".label" end
    return L(s_ThemeKeys[theme.Id])
end

local function LanguageName()
    local code = Language.GetCurrentCode()
    if s_LanguageCode ~= code then
        s_LanguageCode = code
        s_LanguageName = Language.GetCurrentName()
    end
    return s_LanguageName
end

local function Links()
    Link("settings.hotkeys", HotkeysView.Menu, BoundCount())
    Widgets.Info(HotkeysView.BoundInfo)
    Link("settings.effects", TrainerEffectsView.Menu, TrainerEffectsView.Count())
    Link("settings.theme", ThemeView.Menu, ThemeName())
    Link("settings.layout", LayoutView.Menu)
    Link("settings.navigation", NavigationView.Menu)
    Link("settings.blockedcontrols", BlockedControlsView.Menu, OnOff(InputBlock.Enabled))
    Link("settings.notifications", NotificationsView.Menu, OnOff(Notification.Style.Enabled))
    Link("settings.language", LanguageView.Menu, LanguageName())
    Link("settings.about", AboutView.Menu, FooterStyle.Version)
end

local function View()
    Links()

    Widgets.Break("")
    if Widgets.HoldButton(L("settings.reset.label")) then Settings.Reset() end
    Widgets.Tip(L("settings.reset.tip"))
end

SettingsView.Menu = Submenu.Create("settings.title", View)

return SettingsView
